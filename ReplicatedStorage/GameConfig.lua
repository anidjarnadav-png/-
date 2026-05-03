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
	DeathLobbyReturnSec    = 15,    -- after death, players are sent back to the lobby
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
	BaseSize               = Vector3.new(800, 4, 800),
	BaseColor              = Color3.fromRGB(86, 140, 70),
	BeachColor             = Color3.fromRGB(230, 210, 160),
	WaterSize              = Vector3.new(2400, 2, 2400),
	WaterColor             = Color3.fromRGB(40, 100, 160),
	WaterY                 = -2,
	NumTrees               = 160,
	NumRocks               = 80,
	NumHills               = 12,
	CrashClearRadius       = 30,
}

-- ====== Animal Spawning ======
-- Spawn cap rises over round time. Spawn weights shift toward higher-level animals.
GameConfig.AnimalSpawning = {
	MaxAlive               = 24,
	SpawnInterval          = 3.5,
	MinDistanceFromPlayer  = 60,
	MaxDistanceFromPlayer  = 220,
	-- Time-thresholds (seconds since round start) -> {dog, wolf, bear, lion} weights
	WeightStages = {
		{ time = 0,    weights = {55, 25, 12, 8 } },  -- lions 8% from the start
		{ time = 60,   weights = {35, 30, 22, 13} },
		{ time = 150,  weights = {20, 30, 30, 20} },
		{ time = 300,  weights = {12, 25, 33, 30} },
		{ time = 480,  weights = {8,  20, 32, 40} },
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
GameConfig.DataStoreVersion = 2

-- ====== Misc ======
GameConfig.Debug            = false

return GameConfig
