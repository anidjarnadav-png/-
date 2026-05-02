-- IslandBuilder.server.lua
-- Place in: ServerScriptService as Script named "IslandBuilder"
-- Builds the island, water, lobby platform, and ready pad. Procedural with a
-- fixed RNG seed so the layout is the same every server run.

local Workspace        = game:GetService("Workspace")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local IslandBuilder = {}

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function ensureFolder(name, parent)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	else
		f:ClearAllChildren()
	end
	return f
end

-- Returns true if (x,z) is inside crash clearing.
local function inCrashClear(x, z)
	local r = GameConfig.Island.CrashClearRadius
	return (x*x + z*z) <= (r*r)
end

local function buildBase(parent)
	local cfg = GameConfig.Island
	local base = makePart{
		Name     = "IslandBase",
		Size     = cfg.BaseSize,
		Position = Vector3.new(0, cfg.BaseSize.Y/2, 0),
		Color    = cfg.BaseColor,
		Material = Enum.Material.Grass,
		Parent   = parent,
	}
	-- Beach ring (rectangular sand strip on edges)
	local beachThickness = 30
	local size = cfg.BaseSize
	local strips = {
		{ Vector3.new(size.X, 1, beachThickness),  Vector3.new(0, size.Y + 0.5,  size.Z/2 - beachThickness/2) },
		{ Vector3.new(size.X, 1, beachThickness),  Vector3.new(0, size.Y + 0.5, -size.Z/2 + beachThickness/2) },
		{ Vector3.new(beachThickness, 1, size.Z),  Vector3.new( size.X/2 - beachThickness/2, size.Y + 0.5, 0) },
		{ Vector3.new(beachThickness, 1, size.Z),  Vector3.new(-size.X/2 + beachThickness/2, size.Y + 0.5, 0) },
	}
	for _, s in ipairs(strips) do
		makePart{
			Name="Beach", Size=s[1], Position=s[2], Color=cfg.BeachColor,
			Material=Enum.Material.Sand, Parent=parent,
		}
	end
end

local function buildWater(parent)
	local cfg = GameConfig.Island
	makePart{
		Name        = "Water",
		Size        = cfg.WaterSize,
		Position    = Vector3.new(0, cfg.WaterY, 0),
		Color       = cfg.WaterColor,
		Material    = Enum.Material.Water,
		Transparency= 0.2,
		CanCollide  = false,
		Parent      = parent,
	}
end

local function buildHills(parent, rng)
	local cfg = GameConfig.Island
	local size = cfg.BaseSize
	local maxR = math.min(size.X, size.Z) / 2 - 40
	for i = 1, cfg.NumHills do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist  = rng:NextNumber(80, maxR - 40)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		local h = rng:NextNumber(15, 35)
		local r = rng:NextNumber(25, 50)
		makePart{
			Name     = "Hill",
			Shape    = Enum.PartType.Ball,
			Size     = Vector3.new(r*2, h*2, r*2),
			Position = Vector3.new(x, size.Y - h*0.5, z),
			Color    = Color3.fromRGB(70, 120, 60),
			Material = Enum.Material.Grass,
			Parent   = parent,
		}
	end
end

local function buildTree(parent, x, z, rng)
	local trunkH = rng:NextNumber(8, 14)
	local trunkR = 1.0
	local baseY  = GameConfig.Island.BaseSize.Y
	local trunk = makePart{
		Name     = "Trunk",
		Shape    = Enum.PartType.Cylinder,
		Size     = Vector3.new(trunkH, trunkR*2, trunkR*2),
		CFrame   = CFrame.new(x, baseY + trunkH/2, z) * CFrame.Angles(0, 0, math.pi/2),
		Color    = Color3.fromRGB(95, 60, 30),
		Material = Enum.Material.Wood,
		Parent   = parent,
	}
	local leafR = rng:NextNumber(3, 5)
	local topY  = baseY + trunkH
	for i = 1, 3 do
		local off = Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(0, 3), rng:NextNumber(-1.5, 1.5))
		makePart{
			Name     = "Leaves",
			Shape    = Enum.PartType.Ball,
			Size     = Vector3.new(leafR*2, leafR*2, leafR*2),
			Position = Vector3.new(x + off.X, topY + off.Y, z + off.Z),
			Color    = Color3.fromRGB(40 + rng:NextInteger(0,30), 110 + rng:NextInteger(0,30), 40),
			Material = Enum.Material.Grass,
			Parent   = parent,
		}
	end
end

local function buildTrees(parent, rng)
	local cfg = GameConfig.Island
	local size = cfg.BaseSize
	local placed = 0
	local attempts = 0
	while placed < cfg.NumTrees and attempts < cfg.NumTrees * 10 do
		attempts = attempts + 1
		local x = rng:NextNumber(-size.X/2 + 40, size.X/2 - 40)
		local z = rng:NextNumber(-size.Z/2 + 40, size.Z/2 - 40)
		if not inCrashClear(x, z) then
			buildTree(parent, x, z, rng)
			placed = placed + 1
		end
	end
end

local function buildRocks(parent, rng)
	local cfg = GameConfig.Island
	local size = cfg.BaseSize
	for i = 1, cfg.NumRocks do
		local x = rng:NextNumber(-size.X/2 + 30, size.X/2 - 30)
		local z = rng:NextNumber(-size.Z/2 + 30, size.Z/2 - 30)
		if inCrashClear(x, z) then
			-- pull rock outward away from crash zone
			local d = math.sqrt(x*x + z*z)
			if d < 0.0001 then x, z = 40, 0 else
				x = x / d * (cfg.CrashClearRadius + 20)
				z = z / d * (cfg.CrashClearRadius + 20)
			end
		end
		local s = rng:NextNumber(3, 8)
		makePart{
			Name     = "Rock",
			Shape    = rng:NextNumber() < 0.5 and Enum.PartType.Ball or Enum.PartType.Block,
			Size     = Vector3.new(s, s*0.8, s),
			Position = Vector3.new(x, cfg.BaseSize.Y + s*0.3, z),
			Color    = Color3.fromRGB(120, 120, 130),
			Material = Enum.Material.Slate,
			Parent   = parent,
			Orientation = Vector3.new(rng:NextNumber(-15,15), rng:NextNumber(0,360), rng:NextNumber(-15,15)),
		}
	end
end

local function buildLobby(parent)
	local cfg = GameConfig.Lobby
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = parent

	local platform = makePart{
		Name      = "Platform",
		Size      = cfg.PlatformSize,
		Position  = Vector3.new(0, cfg.SpawnHeight, 0),
		Color     = cfg.PlatformColor,
		Material  = Enum.Material.SmoothPlastic,
		Parent    = lobbyFolder,
	}
	-- Wall ring so players don't fall off
	local wallH = 6
	local wallT = 2
	local s = cfg.PlatformSize
	local walls = {
		{ Vector3.new(s.X, wallH, wallT), Vector3.new(0, cfg.SpawnHeight + wallH/2 + s.Y/2,  s.Z/2) },
		{ Vector3.new(s.X, wallH, wallT), Vector3.new(0, cfg.SpawnHeight + wallH/2 + s.Y/2, -s.Z/2) },
		{ Vector3.new(wallT, wallH, s.Z), Vector3.new( s.X/2, cfg.SpawnHeight + wallH/2 + s.Y/2, 0) },
		{ Vector3.new(wallT, wallH, s.Z), Vector3.new(-s.X/2, cfg.SpawnHeight + wallH/2 + s.Y/2, 0) },
	}
	for _, w in ipairs(walls) do
		makePart{
			Name="Wall", Size=w[1], Position=w[2],
			Color=Color3.fromRGB(80, 110, 150), Transparency=0.5,
			Material=Enum.Material.Glass, Parent=lobbyFolder,
		}
	end

	-- Ready pad
	local pad = makePart{
		Name      = "ReadyPad",
		Size      = cfg.ReadyPadSize,
		Position  = Vector3.new(0, cfg.SpawnHeight + s.Y/2 + cfg.ReadyPadSize.Y/2, 0),
		Color     = cfg.ReadyPadColor,
		Material  = Enum.Material.Neon,
		Parent    = lobbyFolder,
	}
	-- Floating sign over the pad
	local sign = Instance.new("BillboardGui")
	sign.Name = "ReadyLabel"
	sign.Size = UDim2.new(0, 240, 0, 60)
	sign.StudsOffset = Vector3.new(0, 6, 0)
	sign.AlwaysOnTop = true
	sign.Adornee = pad
	sign.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = "עלו כאן כדי להתחיל"
	label.Parent = sign

	-- SpawnLocation in the lobby
	local existing = Workspace:FindFirstChildWhichIsA("SpawnLocation")
	if existing then existing:Destroy() end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, cfg.SpawnHeight + s.Y/2 + 0.5, -25)
	spawn.BrickColor = BrickColor.new("Medium blue")
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobbyFolder

	IslandBuilder.LobbyPlatform = platform
	IslandBuilder.ReadyPad      = pad
	IslandBuilder.LobbySpawn    = spawn
end

function IslandBuilder.GetCrashPosition()
	local cfg = GameConfig.Island
	return Vector3.new(0, cfg.BaseSize.Y + 4, 0)
end

function IslandBuilder.Build()
	local world = ensureFolder("IslandWorld", Workspace)

	local rng = Random.new(GameConfig.Island.Seed)
	buildWater(world)
	buildBase(world)
	buildHills(world, rng)
	buildTrees(world, rng)
	buildRocks(world, rng)
	buildLobby(world)

	-- nice sky/lighting tweak
	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 14
	lighting.Brightness = 2
	local atmos = lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmos.Density = 0.3
	atmos.Color   = Color3.fromRGB(199, 199, 199)
	atmos.Decay   = Color3.fromRGB(106, 112, 125)
	atmos.Glare   = 0.2
	atmos.Haze    = 1.5
	atmos.Parent  = lighting

	print("[IslandBuilder] World built.")
	return world
end

_G.IslandBuilder = IslandBuilder
print("[IslandBuilder] Ready.")
