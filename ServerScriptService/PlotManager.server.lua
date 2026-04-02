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
