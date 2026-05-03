-- IslandBuilder.server.lua
-- Place in: ServerScriptService as Script named "IslandBuilder"
-- Builds a detailed island: real Terrain (grass, sand, rock), varied trees,
-- clustered rocks, hills, lobby platform, and ready pad. Procedural with a
-- fixed RNG seed so the layout is identical every server run.

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

local function inCrashClear(x, z)
	local r = GameConfig.Island.CrashClearRadius
	return (x*x + z*z) <= (r*r)
end

-- ====== Terrain base ======
local function clearTerrain()
	local terrain = Workspace.Terrain
	-- Clear a generous region so we can lay down a fresh island.
	local cfg = GameConfig.Island
	local size = Vector3.new(cfg.WaterSize.X + 200, 200, cfg.WaterSize.Z + 200)
	local region = Region3.new(
		Vector3.new(-size.X/2, -50, -size.Z/2),
		Vector3.new( size.X/2, 100,  size.Z/2)
	):ExpandToGrid(4)
	terrain:FillRegion(region, 4, Enum.Material.Air)
end

local function buildTerrainBase()
	local terrain = Workspace.Terrain
	local cfg = GameConfig.Island
	local sx, sy, sz = cfg.BaseSize.X, cfg.BaseSize.Y, cfg.BaseSize.Z

	-- Grass plateau
	local grassRegion = Region3.new(
		Vector3.new(-sx/2, 0,    -sz/2),
		Vector3.new( sx/2, sy + 1, sz/2)
	):ExpandToGrid(4)
	terrain:FillRegion(grassRegion, 4, Enum.Material.Grass)

	-- Sand ring (beach) along the perimeter
	local beachT = 32
	local strips = {
		Region3.new(Vector3.new(-sx/2,         0, -sz/2),         Vector3.new( sx/2, sy + 1, -sz/2 + beachT)),
		Region3.new(Vector3.new(-sx/2,         0,  sz/2 - beachT),Vector3.new( sx/2, sy + 1,  sz/2)),
		Region3.new(Vector3.new(-sx/2,         0, -sz/2),         Vector3.new(-sx/2 + beachT, sy + 1, sz/2)),
		Region3.new(Vector3.new( sx/2 - beachT,0, -sz/2),         Vector3.new( sx/2, sy + 1,  sz/2)),
	}
	for _, r in ipairs(strips) do
		terrain:FillRegion(r:ExpandToGrid(4), 4, Enum.Material.Sand)
	end

	-- Water filling around the island, lower than land.
	local wsx, wsz = cfg.WaterSize.X, cfg.WaterSize.Z
	local waterRegion = Region3.new(
		Vector3.new(-wsx/2, cfg.WaterY - 4, -wsz/2),
		Vector3.new( wsx/2, cfg.WaterY + 0.5,  wsz/2)
	):ExpandToGrid(4)
	terrain:FillRegion(waterRegion, 4, Enum.Material.Water)

	-- Re-fill the island area to clear any water that leaked in.
	terrain:FillRegion(grassRegion, 4, Enum.Material.Grass)
	for _, r in ipairs(strips) do
		terrain:FillRegion(r:ExpandToGrid(4), 4, Enum.Material.Sand)
	end
end

local function buildTerrainHills(rng)
	local terrain = Workspace.Terrain
	local cfg = GameConfig.Island
	local size = cfg.BaseSize
	local maxR = math.min(size.X, size.Z) / 2 - 60

	for i = 1, cfg.NumHills do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist  = rng:NextNumber(80, maxR - 40)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		local r = rng:NextNumber(20, 38)
		local h = rng:NextNumber(14, 26)
		-- Stack two FillBalls of different materials for layered look
		terrain:FillBall(Vector3.new(x, size.Y + h * 0.4, z), r, Enum.Material.Rock)
		terrain:FillBall(Vector3.new(x, size.Y + h * 0.6, z), r * 0.85, Enum.Material.Grass)
	end
end

-- ====== Trees ======
local function buildPineTree(parent, x, z, rng)
	local trunkH = rng:NextNumber(10, 14)
	local trunkR = 0.7
	local baseY  = GameConfig.Island.BaseSize.Y
	makePart{
		Name="Trunk", Shape=Enum.PartType.Cylinder,
		Size=Vector3.new(trunkH, trunkR*2, trunkR*2),
		CFrame=CFrame.new(x, baseY + trunkH/2, z) * CFrame.Angles(0, 0, math.pi/2),
		Color=Color3.fromRGB(85, 55, 30), Material=Enum.Material.Wood,
		Parent=parent,
	}
	-- Triangular foliage stack
	local topY = baseY + trunkH
	for i = 0, 3 do
		local ratio = 1 - i * 0.22
		local h = 3 - i * 0.4
		makePart{
			Name="Pine", Shape=Enum.PartType.Block,
			Size=Vector3.new(5 * ratio, h, 5 * ratio),
			Position=Vector3.new(x, topY + i * 2, z),
			Color=Color3.fromRGB(20 + rng:NextInteger(0, 20), 90 + rng:NextInteger(0, 30), 50),
			Material=Enum.Material.LeafyGrass, Parent=parent,
			Orientation=Vector3.new(0, rng:NextInteger(0, 360), 0),
		}
	end
end

local function buildOakTree(parent, x, z, rng)
	local trunkH = rng:NextNumber(8, 13)
	local trunkR = 1.2
	local baseY  = GameConfig.Island.BaseSize.Y
	makePart{
		Name="Trunk", Shape=Enum.PartType.Cylinder,
		Size=Vector3.new(trunkH, trunkR*2, trunkR*2),
		CFrame=CFrame.new(x, baseY + trunkH/2, z) * CFrame.Angles(0, 0, math.pi/2),
		Color=Color3.fromRGB(95, 60, 30), Material=Enum.Material.Wood,
		Parent=parent,
	}
	local topY = baseY + trunkH
	-- Big leafy crown of overlapping spheres
	for i = 1, 6 do
		local off = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1, 3), rng:NextNumber(-3, 3))
		local r = rng:NextNumber(3, 5)
		makePart{
			Name="Leaves", Shape=Enum.PartType.Ball,
			Size=Vector3.new(r * 2, r * 2, r * 2),
			Position=Vector3.new(x + off.X, topY + 1 + off.Y, z + off.Z),
			Color=Color3.fromRGB(40 + rng:NextInteger(0, 40), 110 + rng:NextInteger(0, 40), 40),
			Material=Enum.Material.LeafyGrass, Parent=parent,
		}
	end
end

local function buildPalmTree(parent, x, z, rng)
	local trunkH = rng:NextNumber(12, 18)
	local trunkR = 0.6
	local baseY = GameConfig.Island.BaseSize.Y
	-- Trunk leans slightly
	local lean = rng:NextNumber(-0.2, 0.2)
	local trunkCF = CFrame.new(x, baseY + trunkH/2, z)
		* CFrame.Angles(lean, rng:NextNumber(0, math.pi*2), 0)
	makePart{
		Name="Trunk", Shape=Enum.PartType.Cylinder,
		Size=Vector3.new(trunkH, trunkR*2, trunkR*2),
		CFrame=trunkCF * CFrame.Angles(0, 0, math.pi/2),
		Color=Color3.fromRGB(150, 110, 70), Material=Enum.Material.Wood,
		Parent=parent,
	}
	-- Fronds at top
	local topPos = trunkCF.Position + Vector3.new(0, trunkH/2, 0)
	for i = 1, 7 do
		local angle = (i / 7) * math.pi * 2
		local frond = makePart{
			Name="Frond", Shape=Enum.PartType.Block,
			Size=Vector3.new(0.4, 0.6, 7),
			CFrame=CFrame.new(topPos)
				* CFrame.Angles(0, angle, math.rad(20))
				* CFrame.new(0, 0, -3.5),
			Color=Color3.fromRGB(50 + rng:NextInteger(0,30), 140 + rng:NextInteger(0,30), 60),
			Material=Enum.Material.LeafyGrass, Parent=parent,
		}
	end
	-- Coconuts
	for i = 1, rng:NextInteger(2, 4) do
		local angle = rng:NextNumber(0, math.pi * 2)
		makePart{
			Name="Coconut", Shape=Enum.PartType.Ball,
			Size=Vector3.new(0.7, 0.7, 0.7),
			Position=topPos + Vector3.new(math.cos(angle) * 0.8, -0.3, math.sin(angle) * 0.8),
			Color=Color3.fromRGB(80, 50, 30), Material=Enum.Material.SmoothPlastic,
			Parent=parent,
		}
	end
end

local function buildTrees(parent, rng)
	local cfg = GameConfig.Island
	local size = cfg.BaseSize
	local placed = 0
	local attempts = 0
	while placed < cfg.NumTrees and attempts < cfg.NumTrees * 12 do
		attempts = attempts + 1
		local x = rng:NextNumber(-size.X/2 + 50, size.X/2 - 50)
		local z = rng:NextNumber(-size.Z/2 + 50, size.Z/2 - 50)
		if inCrashClear(x, z) then continue end
		-- Trees on the beach (within ~30 of edge) are palms, otherwise pine/oak.
		local distFromEdge = math.min(size.X/2 - math.abs(x), size.Z/2 - math.abs(z))
		local roll = rng:NextNumber()
		if distFromEdge < 40 then
			buildPalmTree(parent, x, z, rng)
		elseif roll < 0.55 then
			buildPineTree(parent, x, z, rng)
		else
			buildOakTree(parent, x, z, rng)
		end
		placed = placed + 1
	end
end

-- ====== Rocks (clustered) ======
local function buildRockCluster(parent, cx, cz, rng)
	local count = rng:NextInteger(2, 5)
	local baseY = GameConfig.Island.BaseSize.Y
	for i = 1, count do
		local off = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local s = rng:NextNumber(2.5, 6.5)
		makePart{
			Name="Rock",
			Shape = (rng:NextNumber() < 0.4) and Enum.PartType.Ball or Enum.PartType.Block,
			Size=Vector3.new(s, s * rng:NextNumber(0.6, 1.0), s),
			Position=Vector3.new(cx + off.X, baseY + s * 0.3, cz + off.Z),
			Color=Color3.fromRGB(110 + rng:NextInteger(0,30), 110 + rng:NextInteger(0,30), 120 + rng:NextInteger(0,20)),
			Material=Enum.Material.Slate,
			Orientation=Vector3.new(rng:NextNumber(-25,25), rng:NextNumber(0,360), rng:NextNumber(-25,25)),
			Parent=parent,
		}
	end
end

local function buildRocks(parent, rng)
	local cfg = GameConfig.Island
	local size = cfg.BaseSize
	local clusters = math.floor(cfg.NumRocks / 3)
	for i = 1, clusters do
		local x = rng:NextNumber(-size.X/2 + 40, size.X/2 - 40)
		local z = rng:NextNumber(-size.Z/2 + 40, size.Z/2 - 40)
		if inCrashClear(x, z) then
			-- push outward
			local d = math.sqrt(x*x + z*z)
			if d < 0.0001 then x, z = 50, 0 else
				x = x / d * (cfg.CrashClearRadius + 25)
				z = z / d * (cfg.CrashClearRadius + 25)
			end
		end
		buildRockCluster(parent, x, z, rng)
	end
end

-- ====== Bushes (small green parts for ground variety) ======
local function buildBushes(parent, rng)
	local cfg = GameConfig.Island
	local size = cfg.BaseSize
	for i = 1, 60 do
		local x = rng:NextNumber(-size.X/2 + 35, size.X/2 - 35)
		local z = rng:NextNumber(-size.Z/2 + 35, size.Z/2 - 35)
		if inCrashClear(x, z) then continue end
		local s = rng:NextNumber(1.2, 2.2)
		makePart{
			Name="Bush", Shape=Enum.PartType.Ball,
			Size=Vector3.new(s * 2, s, s * 2),
			Position=Vector3.new(x, cfg.BaseSize.Y + s * 0.3, z),
			Color=Color3.fromRGB(50 + rng:NextInteger(0,30), 130 + rng:NextInteger(0,40), 50),
			Material=Enum.Material.LeafyGrass, Parent=parent,
		}
	end
end

-- ====== Lobby ======
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
	-- Decorative trim
	local trim = makePart{
		Name="Trim", Size=Vector3.new(cfg.PlatformSize.X + 4, 1, cfg.PlatformSize.Z + 4),
		Position=Vector3.new(0, cfg.SpawnHeight - cfg.PlatformSize.Y/2 - 0.5, 0),
		Color=Color3.fromRGB(70, 100, 140), Material=Enum.Material.Metal,
		Parent=lobbyFolder,
	}
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

	-- Real Terrain for the ground.
	pcall(clearTerrain)
	pcall(buildTerrainBase)
	pcall(function() buildTerrainHills(rng) end)

	-- Decorative meshes / parts on top of terrain.
	buildTrees(world, rng)
	buildRocks(world, rng)
	buildBushes(world, rng)
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

	print("[IslandBuilder] World built (Terrain + decoration).")
	return world
end

_G.IslandBuilder = IslandBuilder
print("[IslandBuilder] Ready.")
