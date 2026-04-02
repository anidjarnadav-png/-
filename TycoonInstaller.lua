-- Tycoon Game Installer - Paste this entire script into the Roblox Studio Command Bar and press Enter
-- View > Command Bar  (if not visible)

do
  local s = Instance.new('ModuleScript')
  s.Name = 'GameConfig'
  s.Source = [=[
-- GameConfig.lua
-- Place in: ReplicatedStorage > ModuleScript named "GameConfig"

local GameConfig = {}

-- Currency settings
GameConfig.CURRENCY_NAME = "Cash"
GameConfig.STARTING_CASH = 0

-- Dropper settings (cash per drop, interval in seconds)
GameConfig.DROPPERS = {
	{name = "Basic Dropper",    cashPerDrop = 1,   interval = 2.0, cost = 0},
	{name = "Silver Dropper",   cashPerDrop = 5,   interval = 2.0, cost = 100},
	{name = "Gold Dropper",     cashPerDrop = 15,  interval = 1.5, cost = 500},
	{name = "Diamond Dropper",  cashPerDrop = 50,  interval = 1.0, cost = 2000},
	{name = "Rainbow Dropper",  cashPerDrop = 200, interval = 0.8, cost = 10000},
}

-- Upgrade buttons (buildings/machines to purchase)
GameConfig.UPGRADES = {
	{id = "upgrade_1", name = "Upgrade 1", description = "Double your income",  cost = 250,   multiplier = 2},
	{id = "upgrade_2", name = "Upgrade 2", description = "Triple your income",  cost = 1500,  multiplier = 3},
	{id = "upgrade_3", name = "Upgrade 3", description = "5x your income",      cost = 8000,  multiplier = 5},
	{id = "upgrade_4", name = "Upgrade 4", description = "10x your income",     cost = 50000, multiplier = 10},
}

-- Plot settings
GameConfig.NUM_PLOTS = 4
GameConfig.PLOT_SIZE = Vector3.new(100, 1, 100)
GameConfig.PLOT_SPACING = 120

-- DataStore name
GameConfig.DATASTORE_NAME = "TycoonData_v1"

-- Team colors for plots
GameConfig.TEAM_COLORS = {
	BrickColor.new("Bright red"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Bright green"),
	BrickColor.new("Bright yellow"),
}

return GameConfig

]=]
  local parent = game:GetService('ReplicatedStorage')
  -- Remove old version if exists
  local old = parent:FindFirstChild('GameConfig')
  if old then old:Destroy() end
  s.Parent = parent
  print('Installed: GameConfig -> ' .. parent.Name)
end

do
  local s = Instance.new('Script')
  s.Name = 'DataManager'
  s.Source = [=[
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

]=]
  local parent = game:GetService('ServerScriptService')
  -- Remove old version if exists
  local old = parent:FindFirstChild('DataManager')
  if old then old:Destroy() end
  s.Parent = parent
  print('Installed: DataManager -> ' .. parent.Name)
end

do
  local s = Instance.new('Script')
  s.Name = 'PlotManager'
  s.Source = [=[
-- PlotManager.server.lua
-- Place in: ServerScriptService > Script named "PlotManager"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- Wait for DataManager to be ready
local function waitForDataManager()
	local attempts = 0
	while not _G.DataManager and attempts < 100 do
		task.wait(0.1)
		attempts = attempts + 1
	end
	return _G.DataManager
end

local DataManager = waitForDataManager()

-- Track which plot belongs to which player
local plotOwners = {}    -- plot -> player
local playerPlots = {}   -- player.UserId -> plot

-- -------------------------------------------------------
-- Build plots in Workspace
-- -------------------------------------------------------
local function buildPlots()
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if plotsFolder then return plotsFolder end  -- already built

	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace

	for i = 1, GameConfig.NUM_PLOTS do
		local plot = Instance.new("Model")
		plot.Name = "Plot_" .. i
		plot.Parent = plotsFolder

		-- Base platform
		local base = Instance.new("Part")
		base.Name = "Base"
		base.Anchored = true
		base.Size = GameConfig.PLOT_SIZE
		base.Position = Vector3.new((i - 1) * GameConfig.PLOT_SPACING, 0, 0)
		base.BrickColor = BrickColor.new("Medium stone grey")
		base.TopSurface = Enum.SurfaceType.Smooth
		base.Parent = plot
		plot.PrimaryPart = base

		-- Boundary walls (visual only, not collidable)
		local wallThickness = 1
		local halfX = GameConfig.PLOT_SIZE.X / 2
		local halfZ = GameConfig.PLOT_SIZE.Z / 2
		local wallHeight = 10
		local wallPositions = {
			{Vector3.new(base.Position.X, wallHeight / 2, base.Position.Z + halfZ), Vector3.new(GameConfig.PLOT_SIZE.X, wallHeight, wallThickness)},
			{Vector3.new(base.Position.X, wallHeight / 2, base.Position.Z - halfZ), Vector3.new(GameConfig.PLOT_SIZE.X, wallHeight, wallThickness)},
			{Vector3.new(base.Position.X + halfX, wallHeight / 2, base.Position.Z), Vector3.new(wallThickness, wallHeight, GameConfig.PLOT_SIZE.Z)},
			{Vector3.new(base.Position.X - halfX, wallHeight / 2, base.Position.Z), Vector3.new(wallThickness, wallHeight, GameConfig.PLOT_SIZE.Z)},
		}
		for _, wallData in ipairs(wallPositions) do
			local wall = Instance.new("Part")
			wall.Anchored = true
			wall.CanCollide = false
			wall.Transparency = 0.7
			wall.Size = wallData[2]
			wall.Position = wallData[1]
			wall.BrickColor = GameConfig.TEAM_COLORS[i]
			wall.Parent = plot
		end

		-- "CLAIM" sign above the plot
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PlotSign"
		billboard.Size = UDim2.new(0, 200, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 6, 0)
		billboard.AlwaysOnTop = false
		billboard.Parent = base

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = "CLAIM PLOT " .. i
		label.Parent = billboard

		-- Collector part (where money is collected)
		local collector = Instance.new("Part")
		collector.Name = "Collector"
		collector.Anchored = true
		collector.Size = Vector3.new(8, 1, 8)
		collector.Position = base.Position + Vector3.new(0, 1, -30)
		collector.BrickColor = GameConfig.TEAM_COLORS[i]
		collector.TopSurface = Enum.SurfaceType.Smooth
		collector.Parent = plot

		local collectorLabel = Instance.new("BillboardGui")
		collectorLabel.Size = UDim2.new(0, 150, 0, 40)
		collectorLabel.StudsOffset = Vector3.new(0, 2, 0)
		collectorLabel.Parent = collector
		local cLabel = Instance.new("TextLabel")
		cLabel.Size = UDim2.new(1, 0, 1, 0)
		cLabel.BackgroundTransparency = 1
		cLabel.TextColor3 = Color3.new(1, 1, 0)
		cLabel.TextStrokeTransparency = 0
		cLabel.Font = Enum.Font.GothamBold
		cLabel.TextScaled = true
		cLabel.Text = "COLLECTOR"
		cLabel.Parent = collectorLabel

		-- Dropper position (where money orbs will spawn)
		local dropperBase = Instance.new("Part")
		dropperBase.Name = "DropperBase"
		dropperBase.Anchored = true
		dropperBase.Size = Vector3.new(6, 2, 6)
		dropperBase.Position = base.Position + Vector3.new(0, 2, 20)
		dropperBase.BrickColor = BrickColor.new("Dark grey")
		dropperBase.Parent = plot

		-- A simple conveyor belt (visual, represented as a part)
		local belt = Instance.new("Part")
		belt.Name = "ConveyorBelt"
		belt.Anchored = true
		belt.Size = Vector3.new(4, 0.5, 50)
		belt.Position = base.Position + Vector3.new(0, 1.25, -5)
		belt.BrickColor = BrickColor.new("Black")
		belt.TopSurface = Enum.SurfaceType.Smooth
		belt.Parent = plot

		-- Attribute to track plot index
		plot:SetAttribute("PlotIndex", i)
		plot:SetAttribute("Owner", "")
	end

	return plotsFolder
end

local plotsFolder = buildPlots()

-- -------------------------------------------------------
-- Assign a plot to a joining player
-- -------------------------------------------------------
local function assignPlot(player)
	for i = 1, GameConfig.NUM_PLOTS do
		local plot = plotsFolder:FindFirstChild("Plot_" .. i)
		if plot and not plotOwners[plot] then
			plotOwners[plot] = player
			playerPlots[player.UserId] = plot

			-- Update plot sign
			local base = plot:FindFirstChild("Base")
			if base then
				local billboard = base:FindFirstChild("PlotSign")
				if billboard then
					local label = billboard:FindFirstChildOfClass("TextLabel")
					if label then
						label.Text = player.Name .. "'s Tycoon"
					end
				end
			end

			-- Color plot base to player's team color
			local base2 = plot:FindFirstChild("Base")
			if base2 then
				base2.BrickColor = GameConfig.TEAM_COLORS[i]
			end

			plot:SetAttribute("Owner", player.Name)
			return plot
		end
	end
	return nil  -- No free plots
end

local function releasePlot(player)
	local plot = playerPlots[player.UserId]
	if not plot then return end

	plotOwners[plot] = nil
	playerPlots[player.UserId] = nil

	-- Reset plot appearance
	local idx = plot:GetAttribute("PlotIndex")
	local base = plot:FindFirstChild("Base")
	if base then
		base.BrickColor = BrickColor.new("Medium stone grey")
		local billboard = base:FindFirstChild("PlotSign")
		if billboard then
			local label = billboard:FindFirstChildOfClass("TextLabel")
			if label then
				label.Text = "CLAIM PLOT " .. idx
			end
		end
	end

	-- Remove all purchased items
	for _, obj in ipairs(plot:GetChildren()) do
		if obj:GetAttribute("Purchased") then
			obj:Destroy()
		end
	end

	plot:SetAttribute("Owner", "")
end

-- Public API
local PlotManager = {}

function PlotManager.GetPlot(player)
	return playerPlots[player.UserId]
end

function PlotManager.GetOwner(plot)
	return plotOwners[plot]
end

-- Player lifecycle
Players.PlayerAdded:Connect(function(player)
	task.wait(1)  -- Short wait for DataManager to load player data first
	local plot = assignPlot(player)
	if plot then
		-- Teleport player to their plot
		player.CharacterAdded:Connect(function(character)
			task.wait(0.5)
			local base = plot:FindFirstChild("Base")
			if base and character:FindFirstChild("HumanoidRootPart") then
				character.HumanoidRootPart.CFrame = CFrame.new(base.Position + Vector3.new(0, 5, 0))
			end
		end)
		-- Handle already loaded character
		if player.Character then
			local base = plot:FindFirstChild("Base")
			if base and player.Character:FindFirstChild("HumanoidRootPart") then
				player.Character.HumanoidRootPart.CFrame = CFrame.new(base.Position + Vector3.new(0, 5, 0))
			end
		end
	else
		warn("No free plots for " .. player.Name)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	releasePlot(player)
end)

_G.PlotManager = PlotManager

]=]
  local parent = game:GetService('ServerScriptService')
  -- Remove old version if exists
  local old = parent:FindFirstChild('PlotManager')
  if old then old:Destroy() end
  s.Parent = parent
  print('Installed: PlotManager -> ' .. parent.Name)
end

do
  local s = Instance.new('Script')
  s.Name = 'MainGame'
  s.Source = [=[
-- MainGame.server.lua
-- Place in: ServerScriptService > Script named "MainGame"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- Wait for managers to be ready
local function waitForGlobal(name)
	local attempts = 0
	while not _G[name] and attempts < 200 do
		task.wait(0.1)
		attempts = attempts + 1
	end
	return _G[name]
end

local DataManager = waitForGlobal("DataManager")
local PlotManager = waitForGlobal("PlotManager")

-- RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyDropperEvent  = Instance.new("RemoteEvent"); buyDropperEvent.Name  = "BuyDropper";  buyDropperEvent.Parent  = remotes
local buyUpgradeEvent  = Instance.new("RemoteEvent"); buyUpgradeEvent.Name  = "BuyUpgrade";  buyUpgradeEvent.Parent  = remotes
local notifyEvent      = Instance.new("RemoteEvent"); notifyEvent.Name      = "Notify";      notifyEvent.Parent      = remotes

-- Active dropper coroutines: player.UserId -> list of thread handles
local dropperThreads = {}

-- -------------------------------------------------------
-- Money Orbs
-- -------------------------------------------------------
local function spawnOrb(plot, cashValue)
	local dropperBase = plot:FindFirstChild("DropperBase")
	if not dropperBase then return end

	local orb = Instance.new("Part")
	orb.Name = "MoneyOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(1.5, 1.5, 1.5)
	orb.Position = dropperBase.Position + Vector3.new(0, 3, 0)
	orb.BrickColor = BrickColor.new("Bright green")
	orb.Material = Enum.Material.Neon
	orb:SetAttribute("CashValue", cashValue)
	orb.Parent = plot

	-- Simple label on orb
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 50, 0, 20)
	gui.StudsOffset = Vector3.new(0, 1.2, 0)
	gui.Parent = orb
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,1,0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.new(1,1,0)
	lbl.TextStrokeTransparency = 0
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Text = "$" .. cashValue
	lbl.Parent = gui

	-- Destroy after 10 seconds if not collected
	game:GetService("Debris"):AddItem(orb, 10)
end

-- -------------------------------------------------------
-- Collector touch detection
-- -------------------------------------------------------
local function setupCollector(plot, player)
	local collector = plot:FindFirstChild("Collector")
	if not collector then return end

	collector.Touched:Connect(function(hit)
		if hit.Name ~= "MoneyOrb" then return end
		local cashValue = hit:GetAttribute("CashValue")
		if not cashValue then return end

		-- Verify this orb belongs to this plot
		if hit.Parent ~= plot then return end

		hit:Destroy()
		DataManager.AddCash(player, cashValue)
	end)
end

-- -------------------------------------------------------
-- Start droppers for a player
-- -------------------------------------------------------
local function startDroppers(player)
	local plot = PlotManager.GetPlot(player)
	if not plot then return end

	-- Stop any existing dropper threads
	if dropperThreads[player.UserId] then
		for _, thread in ipairs(dropperThreads[player.UserId]) do
			task.cancel(thread)
		end
	end
	dropperThreads[player.UserId] = {}

	local ownedDroppers = DataManager.GetOwnedDroppers(player)

	for _, dropperIdx in ipairs(ownedDroppers) do
		local cfg = GameConfig.DROPPERS[dropperIdx]
		if not cfg then continue end

		-- Calculate cash with upgrade multipliers
		local function getCashAmount()
			local base = cfg.cashPerDrop
			for _, upgrade in ipairs(GameConfig.UPGRADES) do
				if DataManager.HasUpgrade(player, upgrade.id) then
					base = base * upgrade.multiplier
				end
			end
			return base
		end

		local thread = task.spawn(function()
			while true do
				task.wait(cfg.interval)
				-- Check player still connected
				if not Players:FindFirstChild(player.Name) then break end
				local currentPlot = PlotManager.GetPlot(player)
				if not currentPlot then break end
				spawnOrb(currentPlot, getCashAmount())
			end
		end)

		table.insert(dropperThreads[player.UserId], thread)
	end
end

-- -------------------------------------------------------
-- Purchase button system
-- -------------------------------------------------------
local function createUpgradeButton(plot, upgrade, player)
	local base = plot:FindFirstChild("Base")
	if not base then return end

	local button = Instance.new("Part")
	button.Name = "UpgradeButton_" .. upgrade.id
	button.Anchored = true
	button.Size = Vector3.new(6, 1, 6)
	-- Space buttons along the plot
	local idx = 0
	for i, u in ipairs(GameConfig.UPGRADES) do
		if u.id == upgrade.id then idx = i break end
	end
	button.Position = base.Position + Vector3.new(-30 + (idx-1)*20, 1, 10)
	button.BrickColor = BrickColor.new("Bright blue")
	button.Parent = plot

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 200, 0, 60)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.Parent = button
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,1,0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.new(1,1,1)
	lbl.TextStrokeTransparency = 0
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Text = upgrade.name .. "\n$" .. upgrade.cost
	lbl.Parent = gui

	button.Touched:Connect(function(hit)
		local character = hit.Parent
		local touchPlayer = Players:GetPlayerFromCharacter(character)
		if touchPlayer ~= player then return end
		if DataManager.HasUpgrade(player, upgrade.id) then
			notifyEvent:FireClient(player, "Already owned: " .. upgrade.name)
			return
		end
		local success = DataManager.SpendCash(player, upgrade.cost)
		if success then
			DataManager.AddUpgrade(player, upgrade.id)
			button.BrickColor = BrickColor.new("Bright green")
			lbl.Text = upgrade.name .. "\n✓ OWNED"
			notifyEvent:FireClient(player, "Purchased: " .. upgrade.name .. "!")
			startDroppers(player) -- Restart droppers with new multiplier
		else
			notifyEvent:FireClient(player, "Not enough cash! Need $" .. upgrade.cost)
		end
	end)
end

local function createDropperButton(plot, dropperIdx, player)
	local base = plot:FindFirstChild("Base")
	if not base then return end

	local cfg = GameConfig.DROPPERS[dropperIdx]
	if not cfg or cfg.cost == 0 then return end  -- Skip free basic dropper

	local button = Instance.new("Part")
	button.Name = "DropperButton_" .. dropperIdx
	button.Anchored = true
	button.Size = Vector3.new(6, 1, 6)
	button.Position = base.Position + Vector3.new(-30 + (dropperIdx-2)*15, 1, -10)
	button.BrickColor = BrickColor.new("Bright orange")
	button.Parent = plot

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 220, 0, 60)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.Parent = button
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,1,0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.new(1,1,1)
	lbl.TextStrokeTransparency = 0
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Text = cfg.name .. "\n$" .. cfg.cost .. "/drop"
	lbl.Parent = gui

	if DataManager.HasDropper(player, dropperIdx) then
		button.BrickColor = BrickColor.new("Bright green")
		lbl.Text = cfg.name .. "\n✓ ACTIVE"
	end

	button.Touched:Connect(function(hit)
		local character = hit.Parent
		local touchPlayer = Players:GetPlayerFromCharacter(character)
		if touchPlayer ~= player then return end
		if DataManager.HasDropper(player, dropperIdx) then
			notifyEvent:FireClient(player, "Already have: " .. cfg.name)
			return
		end
		local success = DataManager.SpendCash(player, cfg.cost)
		if success then
			DataManager.AddDropper(player, dropperIdx)
			button.BrickColor = BrickColor.new("Bright green")
			lbl.Text = cfg.name .. "\n✓ ACTIVE"
			notifyEvent:FireClient(player, "Purchased: " .. cfg.name .. "!")
			startDroppers(player)
		else
			notifyEvent:FireClient(player, "Not enough cash! Need $" .. cfg.cost)
		end
	end)
end

-- -------------------------------------------------------
-- Initialize tycoon for a player
-- -------------------------------------------------------
local function initTycoon(player)
	task.wait(1.5)  -- Wait for plot assignment
	local plot = PlotManager.GetPlot(player)
	if not plot then return end

	-- Setup collector
	setupCollector(plot, player)

	-- Create upgrade buttons
	for _, upgrade in ipairs(GameConfig.UPGRADES) do
		createUpgradeButton(plot, upgrade, player)
	end

	-- Create dropper purchase buttons
	for i = 2, #GameConfig.DROPPERS do
		createDropperButton(plot, i, player)
	end

	-- Restore already-owned upgrade button states
	for _, upgrade in ipairs(GameConfig.UPGRADES) do
		if DataManager.HasUpgrade(player, upgrade.id) then
			local btn = plot:FindFirstChild("UpgradeButton_" .. upgrade.id)
			if btn then
				btn.BrickColor = BrickColor.new("Bright green")
				local gui = btn:FindFirstChildOfClass("BillboardGui")
				if gui then
					local lbl = gui:FindFirstChildOfClass("TextLabel")
					if lbl then lbl.Text = upgrade.name .. "\n✓ OWNED" end
				end
			end
		end
	end

	-- Restore dropper button states
	for i = 2, #GameConfig.DROPPERS do
		if DataManager.HasDropper(player, i) then
			local btn = plot:FindFirstChild("DropperButton_" .. i)
			if btn then
				btn.BrickColor = BrickColor.new("Bright green")
				local cfg = GameConfig.DROPPERS[i]
				local gui = btn:FindFirstChildOfClass("BillboardGui")
				if gui then
					local lbl = gui:FindFirstChildOfClass("TextLabel")
					if lbl then lbl.Text = cfg.name .. "\n✓ ACTIVE" end
				end
			end
		end
	end

	-- Start dropper loops
	startDroppers(player)

	-- Welcome message
	notifyEvent:FireClient(player, "Welcome to your Tycoon! Walk on the buttons to buy upgrades.")
end

Players.PlayerAdded:Connect(function(player)
	initTycoon(player)
end)

Players.PlayerRemoving:Connect(function(player)
	if dropperThreads[player.UserId] then
		for _, thread in ipairs(dropperThreads[player.UserId]) do
			pcall(task.cancel, thread)
		end
		dropperThreads[player.UserId] = nil
	end
end)

]=]
  local parent = game:GetService('ServerScriptService')
  -- Remove old version if exists
  local old = parent:FindFirstChild('MainGame')
  if old then old:Destroy() end
  s.Parent = parent
  print('Installed: MainGame -> ' .. parent.Name)
end

do
  local s = Instance.new('LocalScript')
  s.Name = 'CashGui'
  s.Source = [=[
-- CashGui.lua
-- Place in: StarterGui > ScreenGui named "CashGui"
-- Then inside the ScreenGui add a LocalScript and paste this code.
-- (Or place directly as a LocalScript inside StarterGui)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateCashEvent = remotes:WaitForChild("UpdateCash")
local notifyEvent = remotes:WaitForChild("Notify")

-- -------------------------------------------------------
-- Build the ScreenGui
-- -------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TycoonHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player.PlayerGui

-- Cash Frame (top center)
local cashFrame = Instance.new("Frame")
cashFrame.Name = "CashFrame"
cashFrame.Size = UDim2.new(0, 260, 0, 60)
cashFrame.Position = UDim2.new(0.5, -130, 0, 10)
cashFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
cashFrame.BackgroundTransparency = 0.3
cashFrame.BorderSizePixel = 0
cashFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = cashFrame

local cashIcon = Instance.new("TextLabel")
cashIcon.Size = UDim2.new(0, 40, 1, 0)
cashIcon.Position = UDim2.new(0, 5, 0, 0)
cashIcon.BackgroundTransparency = 1
cashIcon.Text = "$"
cashIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
cashIcon.Font = Enum.Font.GothamBold
cashIcon.TextScaled = true
cashIcon.Parent = cashFrame

local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLabel"
cashLabel.Size = UDim2.new(1, -50, 1, 0)
cashLabel.Position = UDim2.new(0, 45, 0, 0)
cashLabel.BackgroundTransparency = 1
cashLabel.Text = "0"
cashLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
cashLabel.Font = Enum.Font.GothamBold
cashLabel.TextScaled = true
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Parent = cashFrame

-- Notification Frame (bottom center)
local notifFrame = Instance.new("Frame")
notifFrame.Name = "NotifFrame"
notifFrame.Size = UDim2.new(0, 400, 0, 50)
notifFrame.Position = UDim2.new(0.5, -200, 1, -80)
notifFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
notifFrame.BackgroundTransparency = 1
notifFrame.BorderSizePixel = 0
notifFrame.Parent = screenGui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 8)
notifCorner.Parent = notifFrame

local notifLabel = Instance.new("TextLabel")
notifLabel.Name = "NotifLabel"
notifLabel.Size = UDim2.new(1, -20, 1, 0)
notifLabel.Position = UDim2.new(0, 10, 0, 0)
notifLabel.BackgroundTransparency = 1
notifLabel.Text = ""
notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
notifLabel.Font = Enum.Font.Gotham
notifLabel.TextScaled = true
notifLabel.Parent = notifFrame

-- -------------------------------------------------------
-- Format large numbers: 1500 -> "1.5K", 2000000 -> "2M"
-- -------------------------------------------------------
local function formatCash(amount)
	if amount >= 1e9 then
		return string.format("%.1fB", amount / 1e9)
	elseif amount >= 1e6 then
		return string.format("%.1fM", amount / 1e6)
	elseif amount >= 1e3 then
		return string.format("%.1fK", amount / 1e3)
	else
		return tostring(math.floor(amount))
	end
end

-- -------------------------------------------------------
-- Cash update handler
-- -------------------------------------------------------
local currentCash = 0

updateCashEvent.OnClientEvent:Connect(function(newCash)
	local old = currentCash
	currentCash = newCash
	cashLabel.Text = formatCash(newCash)

	-- Flash green on increase, red on decrease
	if newCash > old then
		TweenService:Create(cashLabel, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(100, 255, 100)}):Play()
		task.wait(0.15)
		TweenService:Create(cashLabel, TweenInfo.new(0.3), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	elseif newCash < old then
		TweenService:Create(cashLabel, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 80, 80)}):Play()
		task.wait(0.15)
		TweenService:Create(cashLabel, TweenInfo.new(0.3), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end
end)

-- -------------------------------------------------------
-- Notification handler
-- -------------------------------------------------------
local notifQueue = {}
local isShowingNotif = false

local function showNextNotif()
	if isShowingNotif or #notifQueue == 0 then return end
	isShowingNotif = true

	local msg = table.remove(notifQueue, 1)
	notifLabel.Text = msg

	-- Fade in
	TweenService:Create(notifFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.2}):Play()
	TweenService:Create(notifLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()

	task.wait(2.5)

	-- Fade out
	TweenService:Create(notifFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
	TweenService:Create(notifLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	task.wait(0.3)

	isShowingNotif = false
	showNextNotif()
end

notifLabel.TextTransparency = 1

notifyEvent.OnClientEvent:Connect(function(message)
	table.insert(notifQueue, message)
	task.spawn(showNextNotif)
end)

]=]
  local parent = game:GetService('StarterGui')
  -- Remove old version if exists
  local old = parent:FindFirstChild('CashGui')
  if old then old:Destroy() end
  s.Parent = parent
  print('Installed: CashGui -> ' .. parent.Name)
end

do
  local s = Instance.new('LocalScript')
  s.Name = 'TycoonClient'
  s.Source = [=[
-- LocalScript.client.lua
-- Place in: StarterPlayerScripts > LocalScript named "TycoonClient"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getCashFunction = remotes:WaitForChild("GetCash")

-- Request initial cash on join
task.spawn(function()
	task.wait(2)
	-- The server fires UpdateCash on load, but request it manually in case it was missed
	local cash = getCashFunction:InvokeServer()
	-- UpdateCash event will handle displaying it; this is just a fallback trigger
end)

-- Optional: proximity prompt helper text
-- Show button names when player gets close to a button
local camera = workspace.CurrentCamera

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Find all buttons near the player and highlight them
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return end

	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("Owner") ~= player.Name then continue end
		for _, obj in ipairs(plot:GetChildren()) do
			if obj:IsA("BasePart") and (obj.Name:find("Button") or obj.Name == "Collector") then
				local dist = (obj.Position - root.Position).Magnitude
				if dist < 8 then
					obj.Material = Enum.Material.Neon
				else
					obj.Material = Enum.Material.SmoothPlastic
				end
			end
		end
	end
end)

]=]
  local parent = game:GetService('StarterPlayer').StarterPlayerScripts
  -- Remove old version if exists
  local old = parent:FindFirstChild('TycoonClient')
  if old then old:Destroy() end
  s.Parent = parent
  print('Installed: TycoonClient -> ' .. parent.Name)
end

print('=== Tycoon Game installed! Press Play to test. ===')