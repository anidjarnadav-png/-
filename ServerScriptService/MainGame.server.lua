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
