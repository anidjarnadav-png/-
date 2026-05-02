-- GameConfig.lua
-- Place in: ReplicatedStorage as ModuleScript named "GameConfig"
-- Central configuration for Island Survival.
-- Edit numbers here to balance the game.

local GameConfig = {}

-- ====== Owner / Admin ======
GameConfig.Owners = { 4373365238, 9766152626 }

-- ====== Robux Product IDs ======
GameConfig.Products = {
	REVIVE   = 3584581312, -- 15 Robux, one-time per round
	SHOTGUN  = 3584585480, -- 20 Robux, permanent unlock
}

-- ====== Lobby & Round ======
GameConfig.Lobby = {
	CountdownSeconds       = 10,
	MaxPlayers             = 5,
	ReadyPadSize           = Vector3.new(20, 1, 20),
	ReadyPadColor          = Color3.fromRGB(255, 140, 0),
	PlatformSize           = Vector3.new(80, 4, 80),
	PlatformColor          = Color3.fromRGB(140, 180, 220),
	SpawnHeight            = 350, -- studs above the island
}

GameConfig.Round = {
	XPPerSecond            = 10,    -- +10 XP every 10s -> 1 XP/s
	XPTickInterval         = 1.0,
	StartingWeapon         = "Stick",
	StartingHP             = 100,
}

-- ====== Plane ======
GameConfig.Plane = {
	StartOffset            = Vector3.new(-1500, 250, 0),  -- spawn far to the west
	CrashTarget            = Vector3.new(0, 12, 0),       -- crash near island center
	FlightSeconds          = 9,
	BodyColor              = Color3.fromRGB(200, 200, 210),
	WingColor              = Color3.fromRGB(180, 180, 195),
	EjectionSpread         = 25,
}

-- ====== Island ======
GameConfig.Island = {
	Seed                   = 12345,
	BaseSize               = Vector3.new(500, 4, 500),
	BaseColor              = Color3.fromRGB(86, 140, 70),
	BeachColor             = Color3.fromRGB(230, 210, 160),
	WaterSize              = Vector3.new(2000, 2, 2000),
	WaterColor             = Color3.fromRGB(40, 100, 160),
	WaterY                 = -2,
	NumTrees               = 80,
	NumRocks               = 40,
	NumHills               = 6,
	CrashClearRadius       = 30,
}

-- ====== Animal Spawning ======
-- Spawn cap rises over round time. Spawn weights shift toward higher-level animals.
GameConfig.AnimalSpawning = {
	MaxAlive               = 18,
	SpawnInterval          = 4.0,
	MinDistanceFromPlayer  = 60,
	MaxDistanceFromPlayer  = 180,
	-- Time-thresholds (seconds since round start) -> {dog, wolf, bear, lion} weights
	WeightStages = {
		{ time = 0,    weights = {70, 25, 5,  0 } },
		{ time = 60,   weights = {50, 35, 13, 2 } },
		{ time = 180,  weights = {30, 35, 25, 10} },
		{ time = 360,  weights = {15, 30, 35, 20} },
		{ time = 600,  weights = {5,  20, 40, 35} },
	},
}

-- ====== Plane Upgrades (XP-based, session-only) ======
GameConfig.PlaneUpgrades = {
	Speed = {
		Display = "מהירות",
		Levels  = { 50, 150, 400 },     -- prices in XP
		Effect  = { 1.0, 1.2, 1.45, 1.75 }, -- WalkSpeed multiplier per owned level (0..3)
	},
	HP = {
		Display = "בריאות",
		Levels  = { 50, 150, 400 },
		Effect  = { 100, 130, 170, 220 }, -- MaxHealth absolute values
	},
}

-- ====== Damage Scaling ======
GameConfig.DamageScale = {
	UnderLeveledMultiplier = 0.30, -- weapon level < animal level
	HeadshotMultiplier     = 1.5,
}

-- ====== DataStore ======
GameConfig.DataStoreName    = "IslandSurvival_v1"
GameConfig.DataStoreVersion = 1

-- ====== Misc ======
GameConfig.Debug            = false

return GameConfig
