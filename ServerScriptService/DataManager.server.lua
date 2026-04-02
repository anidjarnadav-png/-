-- DataManager.server.lua
-- Place in: ServerScriptService > Script named "DataManager"

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local dataStore = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)

-- RemoteEvents for client-server communication
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local updateCashEvent = remotes:FindFirstChild("UpdateCash")
if not updateCashEvent then
	updateCashEvent = Instance.new("RemoteEvent")
	updateCashEvent.Name = "UpdateCash"
	updateCashEvent.Parent = remotes
end

local getCashFunction = remotes:FindFirstChild("GetCash")
if not getCashFunction then
	getCashFunction = Instance.new("RemoteFunction")
	getCashFunction.Name = "GetCash"
	getCashFunction.Parent = remotes
end

-- In-memory player data
local playerData = {}

local function getDefaultData()
	return {
		cash = GameConfig.STARTING_CASH,
		ownedUpgrades = {},
		ownedDroppers = {1}, -- Start with basic dropper unlocked
	}
end

local function loadData(player)
	local success, data = pcall(function()
		return dataStore:GetAsync("player_" .. player.UserId)
	end)

	if success and data then
		playerData[player.UserId] = data
	else
		playerData[player.UserId] = getDefaultData()
		if not success then
			warn("Failed to load data for " .. player.Name .. ": " .. tostring(data))
		end
	end

	-- Notify client of starting cash
	updateCashEvent:FireClient(player, playerData[player.UserId].cash)
end

local function saveData(player)
	if not playerData[player.UserId] then return end

	local success, err = pcall(function()
		dataStore:SetAsync("player_" .. player.UserId, playerData[player.UserId])
	end)

	if not success then
		warn("Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

-- Public API
local DataManager = {}

function DataManager.GetCash(player)
	local data = playerData[player.UserId]
	return data and data.cash or 0
end

function DataManager.AddCash(player, amount)
	local data = playerData[player.UserId]
	if not data then return end
	data.cash = data.cash + amount
	updateCashEvent:FireClient(player, data.cash)
end

function DataManager.SpendCash(player, amount)
	local data = playerData[player.UserId]
	if not data then return false end
	if data.cash < amount then return false end
	data.cash = data.cash - amount
	updateCashEvent:FireClient(player, data.cash)
	return true
end

function DataManager.HasUpgrade(player, upgradeId)
	local data = playerData[player.UserId]
	if not data then return false end
	for _, id in ipairs(data.ownedUpgrades) do
		if id == upgradeId then return true end
	end
	return false
end

function DataManager.AddUpgrade(player, upgradeId)
	local data = playerData[player.UserId]
	if not data then return end
	table.insert(data.ownedUpgrades, upgradeId)
end

function DataManager.HasDropper(player, dropperIndex)
	local data = playerData[player.UserId]
	if not data then return false end
	for _, idx in ipairs(data.ownedDroppers) do
		if idx == dropperIndex then return true end
	end
	return false
end

function DataManager.AddDropper(player, dropperIndex)
	local data = playerData[player.UserId]
	if not data then return end
	table.insert(data.ownedDroppers, dropperIndex)
end

function DataManager.GetOwnedDroppers(player)
	local data = playerData[player.UserId]
	return data and data.ownedDroppers or {1}
end

-- RemoteFunction handler
getCashFunction.OnServerInvoke = function(player)
	return DataManager.GetCash(player)
end

-- Player lifecycle
Players.PlayerAdded:Connect(function(player)
	loadData(player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player.UserId] = nil
end)

-- Auto-save every 60 seconds
game:GetService("RunService").Heartbeat:Connect(function()
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)

-- Save on server close
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

-- Make DataManager accessible to other scripts
_G.DataManager = DataManager
