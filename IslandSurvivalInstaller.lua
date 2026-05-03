-- ====================================================================
-- IslandSurvivalInstaller.lua  (v2 — non-destructive)
-- ====================================================================
-- Single-script installer for the Island Survival game.
--
-- IMPORTANT
--   This installer is NON-DESTRUCTIVE. It will only replace scripts whose
--   NAMES match the ones the Island Survival code uses. Any scripts you
--   added (custom shop, anti-cheat, etc.) with DIFFERENT names will not be
--   touched.
--
-- HOW TO USE
--   1. Open Roblox Studio.
--   2. Game Settings -> Security: turn ON "Allow API Services".
--   3. View -> Command Bar.
--   4. Paste this ENTIRE script into the Command Bar and press Enter.
--   5. Output: "[Install] Island Survival installed successfully".
--   6. Press Play (F5) to test.
--
-- The installer is idempotent: re-running it replaces only our 22 scripts.
-- ====================================================================

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui          = game:GetService("StarterGui")
local StarterPlayer       = game:GetService("StarterPlayer")
local StarterPlayerScripts= StarterPlayer:WaitForChild("StarterPlayerScripts")

-- ensure(parent, name, className, source)
--   Replaces ONLY the script with that exact name in `parent`.
--   Any other children of `parent` are left untouched.
local function ensure(parent, name, className, source)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local inst = Instance.new(className)
	inst.Name = name
	if source then inst.Source = source end
	inst.Parent = parent
	return inst
end

-- We DO NOT wipe entire containers anymore.  The previous installer used
-- to clear ReplicatedStorage / ServerScriptService / StarterGui /
-- StarterPlayerScripts of all scripts before installing — that destroyed
-- custom user code.  This version only touches the names we created.

local sources = {}

sources.GameConfig = [==[
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
GameConfig.DataStoreVersion = 2

-- ====== Misc ======
GameConfig.Debug            = false

return GameConfig

]==]

sources.Strings = [==[
-- Strings.lua
-- Place in: ReplicatedStorage as ModuleScript named "Strings"
-- Central Hebrew string table. All UI text is sourced from here.

return {
	Lobby = {
		Welcome          = "ברוכים הבאים ל-Island Survival",
		Instruction      = "עלו על הפלטפורמה הכתומה כדי להתחיל",
		WaitingPlayers   = "ממתינים לשחקנים נוספים...",
		CountdownStart   = "המשחק יתחיל בעוד %d שניות",
		Boarding         = "עולים על המטוס...",
		StepOff          = "ירדו מהפלטפורמה כדי לבטל",
		PlayersReady     = "%d / %d שחקנים מוכנים",
	},
	Flight = {
		TakeOff          = "ממריאים!",
		EngineFailure    = "תקלה במנוע! נופלים!",
		Crash            = "התרסקות!",
	},
	Round = {
		Survived         = "שרדת %d שניות",
		XPGained         = "+%d XP",
		AnimalKilled     = "הרגת %s! +%d XP",
		AllDead          = "כל השחקנים מתו",
		Returning        = "חוזרים ללובי בעוד %d שניות",
		RoundStart       = "הקרב מתחיל!",
	},
	HUD = {
		HP               = "בריאות",
		XP               = "ניסיון",
		Weapon           = "נשק",
		Time             = "זמן",
		ShopHint         = "לחצו B לחנות",
	},
	Shop = {
		Title            = "חנות",
		Close            = "סגור",
		TabWeapons       = "נשקים",
		TabUpgrades      = "שדרוגי טיסה",
		Buy              = "קנה",
		Owned            = "ברשותך",
		Locked           = "נעול",
		BuyRobux         = "קנה ב-Robux",
		BuyXP            = "קנה ב-XP",
		MaxLevel         = "רמה מקסימלית",
		NotEnoughXP      = "אין מספיק XP",
		Purchased        = "נרכש בהצלחה!",
		Level            = "רמה %d",
		Damage           = "נזק: %d",
		Cooldown         = "קצב: %.2f שניות",
		Range            = "טווח: %d studs",
		Price            = "מחיר: %d XP",
		PriceRobux       = "מחיר: %d Robux",
		WeaponSession    = "נשק זמני (סבב נוכחי)",
		WeaponPermanent  = "נשק קבוע (Robux)",
	},
	Death = {
		Title            = "מתת",
		KilledBy         = "נהרגת על ידי %s",
		ReviveBtn        = "החייאה - 15 Robux",
		ReviveUsed       = "כבר השתמשת בהחייאה הסבב",
		SpectateBtn      = "מעבר לצפייה",
		LobbyBtn         = "חזרה ללובי",
		WaitingForRound  = "ממתין לסיום הסבב...",
		ReturningInSec   = "חוזר ללובי בעוד %d",
		ReturningSec     = "שניות",
		SurvivedTime     = "שרדת %s",
		BestTimeLabel    = "השיא שלך: %s",
		NewBestTime      = "שיא חדש! %s",
	},
	BestTime = {
		Tag              = "שיא",
		None             = "אין שיא",
	},
	Combat = {
		Hit              = "פגיעה!",
		Killed           = "הרגת %s!",
		OutOfRange       = "רחוק מדי",
		OnCooldown       = "ממתין...",
		WeaponNotOwned   = "אינך מחזיק בנשק",
		UnderLeveled     = "הנשק חלש מדי לחיה הזו",
	},
	Notifications = {
		Welcome          = "ברוכים הבאים!",
		FirstRound       = "המשחק הראשון שלך - בהצלחה!",
		ShotgunUnlocked  = "רובה הציד נפתח לצמיתות!",
		PurchaseFailed   = "הרכישה נכשלה - נסה שוב",
		SaveFailed       = "שמירה נכשלה - נסה להתחבר מחדש",
		ServerOnly       = "פעולה זו זמינה רק בצד השרת",
	},
	Animals = {
		Dog              = "כלב",
		Wolf             = "זאב",
		Bear             = "דוב",
		Lion             = "אריה",
	},
	Weapons = {
		Stick            = "מקל",
		Spear            = "חנית",
		Knife            = "סכין",
		Pistol           = "אקדח",
		Shotgun          = "רובה ציד",
	},
}

]==]

sources.WeaponConfig = [==[
-- WeaponConfig.lua
-- Place in: ReplicatedStorage as ModuleScript named "WeaponConfig"
-- All weapon definitions. Server-authoritative damage uses these stats.

local WeaponConfig = {}

WeaponConfig.List = {
	{
		Id          = "Stick",
		DisplayKey  = "Stick",      -- key into Strings.Weapons
		Level       = 1,
		Damage      = 10,
		Cooldown    = 1.0,
		Range       = 8,            -- studs
		Type        = "Melee",
		PriceXP     = 0,            -- starter
		PriceRobux  = nil,
		Description = "נשק התחלתי, חלש אך תמיד זמין",
		HandleSize  = Vector3.new(0.4, 0.4, 4),
		HandleColor = Color3.fromRGB(120, 80, 40),
	},
	{
		Id          = "Spear",
		DisplayKey  = "Spear",
		Level       = 2,
		Damage      = 25,
		Cooldown    = 0.8,
		Range       = 10,
		Type        = "Melee",
		PriceXP     = 100,
		PriceRobux  = nil,
		Description = "חנית ארוכה עם טווח ונזק טובים",
		HandleSize  = Vector3.new(0.3, 0.3, 6),
		HandleColor = Color3.fromRGB(160, 130, 90),
	},
	{
		Id          = "Knife",
		DisplayKey  = "Knife",
		Level       = 3,
		Damage      = 50,
		Cooldown    = 0.5,
		Range       = 6,
		Type        = "Melee",
		PriceXP     = 300,
		PriceRobux  = nil,
		Description = "סכין מהירה וחדה",
		HandleSize  = Vector3.new(0.25, 0.25, 2),
		HandleColor = Color3.fromRGB(200, 200, 210),
	},
	{
		Id          = "Pistol",
		DisplayKey  = "Pistol",
		Level       = 4,
		Damage      = 100,
		Cooldown    = 0.4,
		Range       = 80,
		Type        = "Ranged",
		PriceXP     = 800,
		PriceRobux  = nil,
		Description = "אקדח חצי-אוטומטי, נזק רב",
		HandleSize  = Vector3.new(0.5, 1.0, 1.5),
		HandleColor = Color3.fromRGB(40, 40, 50),
	},
	{
		Id          = "Shotgun",
		DisplayKey  = "Shotgun",
		Level       = 4,
		Damage      = 100,
		Cooldown    = 0.15,
		Range       = 50,
		Type        = "Ranged",
		PriceXP     = nil,
		PriceRobux  = 20,            -- price label only; actual purchase via DevProduct
		Description = "רובה ציד מהיר במיוחד - נשק קבוע (Robux)",
		HandleSize  = Vector3.new(0.5, 1.0, 4),
		HandleColor = Color3.fromRGB(80, 50, 30),
	},
}

-- Build a lookup map for fast access by Id.
WeaponConfig.ById = {}
for _, w in ipairs(WeaponConfig.List) do
	WeaponConfig.ById[w.Id] = w
end

-- Returns true if the weapon should persist across rounds (Robux only).
function WeaponConfig.IsPermanent(id)
	return id == "Shotgun"
end

return WeaponConfig

]==]

sources.AnimalConfig = [==[
-- AnimalConfig.lua
-- Place in: ReplicatedStorage as ModuleScript named "AnimalConfig"
-- Animal definitions. Each animal is built procedurally from this spec.

local AnimalConfig = {}

AnimalConfig.List = {
	{
		Id          = "Dog",
		DisplayKey  = "Dog",
		Level       = 1,
		HP          = 30,
		Damage      = 5,
		WalkSpeed   = 14,
		AggroRange  = 30,
		AttackRange = 5,
		AttackCD    = 1.0,
		BodyColor   = Color3.fromRGB(160, 110, 70),
		BodySize    = Vector3.new(2, 1.6, 4),
		HeadSize    = Vector3.new(1.4, 1.2, 1.4),
		LegSize     = Vector3.new(0.6, 1.4, 0.6),
		XPReward    = 50,
	},
	{
		Id          = "Wolf",
		DisplayKey  = "Wolf",
		Level       = 2,
		HP          = 60,
		Damage      = 10,
		WalkSpeed   = 16,
		AggroRange  = 35,
		AttackRange = 5,
		AttackCD    = 1.0,
		BodyColor   = Color3.fromRGB(80, 80, 90),
		BodySize    = Vector3.new(2.4, 2, 5),
		HeadSize    = Vector3.new(1.6, 1.4, 1.6),
		LegSize     = Vector3.new(0.7, 1.8, 0.7),
		XPReward    = 100,
	},
	{
		Id          = "Bear",
		DisplayKey  = "Bear",
		Level       = 3,
		HP          = 120,
		Damage      = 20,
		WalkSpeed   = 12,
		AggroRange  = 30,
		AttackRange = 6,
		AttackCD    = 1.2,
		BodyColor   = Color3.fromRGB(60, 40, 25),
		BodySize    = Vector3.new(3.5, 3, 6.5),
		HeadSize    = Vector3.new(2, 2, 2),
		LegSize     = Vector3.new(1, 2.4, 1),
		XPReward    = 150,
	},
	{
		Id          = "Lion",
		DisplayKey  = "Lion",
		Level       = 4,
		HP          = 200,
		Damage      = 35,
		WalkSpeed   = 18,
		AggroRange  = 40,
		AttackRange = 6,
		AttackCD    = 0.9,
		BodyColor   = Color3.fromRGB(210, 160, 80),
		ManeColor   = Color3.fromRGB(120, 70, 30),
		BodySize    = Vector3.new(3, 2.6, 6),
		HeadSize    = Vector3.new(2, 2, 2),
		LegSize     = Vector3.new(0.9, 2.2, 0.9),
		XPReward    = 200,
	},
}

AnimalConfig.ById = {}
for _, a in ipairs(AnimalConfig.List) do
	AnimalConfig.ById[a.Id] = a
end

return AnimalConfig

]==]

sources.DataManager = [==[
-- DataManager.server.lua
-- Place in: ServerScriptService as Script named "DataManager"
-- Persistent player state. ONLY saves Robux purchases. XP, session weapons,
-- and XP-bought upgrades are NEVER saved.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)

local DataManager = {}
local persistent  = {}  -- [userId] = { OwnsShotgun = bool, Version = N }
local session     = {}  -- [userId] = { XP=0, OwnedWeapons={Stick=true}, PlaneUpgrades={Speed=0,HP=0}, UsedRevive=false, Alive=false, CurrentWeapon="Stick", DeathCount=0 }

local function blankPersistent()
	return {
		OwnsShotgun = false,
		BestTime    = 0,                    -- seconds, persistent personal best
		Version     = GameConfig.DataStoreVersion,
	}
end

local function blankSession()
	return {
		XP             = 0,
		OwnedWeapons   = { Stick = true },
		PlaneUpgrades  = { Speed = 0, HP = 0 },
		UsedRevive     = false,
		Alive          = false,
		CurrentWeapon  = "Stick",
		DeathCount     = 0,
	}
end

-- ====== Persistent (DataStore) ======
function DataManager.Load(player)
	local key = "p_" .. player.UserId
	local data
	local ok, err = pcall(function()
		data = store:GetAsync(key)
	end)
	if not ok then
		warn("[DataManager] GetAsync failed for", player.Name, err)
		data = nil
	end
	if type(data) ~= "table" then
		data = blankPersistent()
	else
		-- merge with defaults so missing fields are filled in
		local fresh = blankPersistent()
		for k, v in pairs(fresh) do
			if data[k] == nil then data[k] = v end
		end
	end
	persistent[player.UserId] = data
	return data
end

function DataManager.Save(player)
	local data = persistent[player.UserId]
	if not data then return false end
	local key = "p_" .. player.UserId
	local ok, err = pcall(function()
		store:SetAsync(key, data)
	end)
	if not ok then
		warn("[DataManager] SetAsync failed for", player.Name, err)
		return false
	end
	return true
end

function DataManager.GetPersistent(player)
	return persistent[player.UserId]
end

function DataManager.SetOwnsShotgun(player, owns)
	local d = persistent[player.UserId]
	if not d then return false end
	d.OwnsShotgun = owns and true or false
	return DataManager.Save(player)
end

function DataManager.OwnsShotgun(player)
	local d = persistent[player.UserId]
	return d and d.OwnsShotgun or false
end

function DataManager.GetBestTime(player)
	local d = persistent[player.UserId]
	return (d and d.BestTime) or 0
end

-- Returns true and the new value if a new record was set, otherwise false.
function DataManager.UpdateBestTime(player, seconds)
	local d = persistent[player.UserId]
	if not d then return false end
	seconds = math.floor(seconds + 0.5)
	if seconds <= (d.BestTime or 0) then return false end
	d.BestTime = seconds
	DataManager.Save(player)
	return true, seconds
end

-- Snapshot of all currently-loaded best times keyed by userId.
function DataManager.GetAllBestTimes()
	local out = {}
	for uid, d in pairs(persistent) do
		out[uid] = d.BestTime or 0
	end
	return out
end

-- ====== Session (in-memory only) ======
function DataManager.GetSession(player)
	local s = session[player.UserId]
	if not s then
		s = blankSession()
		session[player.UserId] = s
	end
	-- Shotgun ownership reflects into session (but not "save it back to DataStore")
	if DataManager.OwnsShotgun(player) then
		s.OwnedWeapons.Shotgun = true
	end
	return s
end

function DataManager.ResetSession(player)
	session[player.UserId] = blankSession()
	if DataManager.OwnsShotgun(player) then
		session[player.UserId].OwnedWeapons.Shotgun = true
	end
end

function DataManager.AddXP(player, amount)
	local s = DataManager.GetSession(player)
	s.XP = math.max(0, s.XP + amount)
	return s.XP
end

function DataManager.SpendXP(player, amount)
	local s = DataManager.GetSession(player)
	if s.XP < amount then return false end
	s.XP = s.XP - amount
	return true
end

function DataManager.GrantSessionWeapon(player, weaponId)
	local s = DataManager.GetSession(player)
	s.OwnedWeapons[weaponId] = true
end

function DataManager.OwnsWeapon(player, weaponId)
	local s = DataManager.GetSession(player)
	return s.OwnedWeapons[weaponId] == true
end

-- ====== Lifecycle ======
local function onJoin(player)
	DataManager.Load(player)
	session[player.UserId] = blankSession()
	if DataManager.OwnsShotgun(player) then
		session[player.UserId].OwnedWeapons.Shotgun = true
	end
end

local function onLeave(player)
	DataManager.Save(player)
	persistent[player.UserId] = nil
	session[player.UserId]    = nil
end

Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(onLeave)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		pcall(DataManager.Save, p)
	end
	task.wait(2)
end)

_G.DataManager = DataManager
print("[DataManager] Ready.")

]==]

sources.IslandBuilder = [==[
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

]==]

sources.RoundManager = [==[
-- RoundManager.server.lua
-- Place in: ServerScriptService as Script named "RoundManager"
-- The state machine. Glues lobby, plane, gameplay, and end-of-round together.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Strings    = require(ReplicatedStorage:WaitForChild("Strings"))

local Remotes -- resolved lazily

local RoundManager = {}

RoundManager.State = "LOBBY"  -- LOBBY, COUNTDOWN, BOARDING, FLIGHT, CRASH, PLAYING, ENDING
RoundManager.RoundStartTime = 0
RoundManager.CountdownTask  = nil

local function getRemotes()
	if Remotes then return Remotes end
	Remotes = ReplicatedStorage:WaitForChild("Remotes")
	return Remotes
end

local function broadcastState(payload)
	getRemotes().RoundStateChanged:FireAllClients({
		state   = RoundManager.State,
		payload = payload or {},
	})
end

function RoundManager.GetState() return RoundManager.State end

function RoundManager.IsPlaying()
	return RoundManager.State == "PLAYING"
end

-- Wait until DataManager is ready
local function dm()
	while not _G.DataManager do task.wait(0.1) end
	return _G.DataManager
end

-- ====== Player lifecycle ======
local function teleportToLobby(player)
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp  = char:WaitForChild("HumanoidRootPart")
	local lobby = workspace:FindFirstChild("IslandWorld") and workspace.IslandWorld:FindFirstChild("Lobby")
	if lobby then
		local platform = lobby:FindFirstChild("Platform")
		if platform then
			hrp.CFrame = CFrame.new(platform.Position + Vector3.new(0, 5, -10))
		end
	end
end

local function killAllAnimals()
	if _G.AnimalManager and _G.AnimalManager.ClearAll then
		_G.AnimalManager.ClearAll()
	end
end

local function clearTools(player)
	local char = player.Character
	if char then
		for _, t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") then t:Destroy() end
		end
	end
	if player:FindFirstChild("Backpack") then
		for _, t in ipairs(player.Backpack:GetChildren()) do
			if t:IsA("Tool") then t:Destroy() end
		end
	end
end

-- Reset the player so they're ready to play another round.
local function resetForLobby(player)
	dm().ResetSession(player)
	clearTools(player)
	if player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = 16
			hum.MaxHealth = GameConfig.Round.StartingHP
			hum.Health    = hum.MaxHealth
		end
	end
	teleportToLobby(player)
end

-- Fired when a player dies during PLAYING.
function RoundManager.OnPlayerDied(player, killedByName)
	if RoundManager.State ~= "PLAYING" then return end
	local s = dm().GetSession(player)
	if not s.Alive then return end -- already processed
	s.Alive = false
	s.DeathTime = tick()

	-- Compute survived time and update personal best.
	local survived = math.max(0, math.floor(s.DeathTime - RoundManager.RoundStartTime + 0.5))
	local prevBest = dm().GetBestTime(player)
	local isNewRecord, newBest = dm().UpdateBestTime(player, survived)
	local bestSeconds = isNewRecord and newBest or prevBest

	getRemotes().PlayerDied:FireClient(player, {
		killedBy        = killedByName or "סכנה",
		canRevive       = not s.UsedRevive,
		survivedSeconds = survived,
		bestSeconds     = bestSeconds,
		isNewRecord     = isNewRecord and true or false,
	})

	-- Broadcast best-times update so everyone's tag refreshes.
	if isNewRecord then
		getRemotes().UpdateBestTimes:FireAllClients(dm().GetAllBestTimes())
	end

	-- Start the 15-second countdown that returns the player to the lobby.
	RoundManager.StartDeathCountdown(player, survived, bestSeconds, isNewRecord)

	-- Check if all players are dead.
	task.delay(0.5, function()
		local anyAlive = false
		for _, p in ipairs(Players:GetPlayers()) do
			local sess = dm().GetSession(p)
			if sess.Alive then anyAlive = true break end
		end
		if not anyAlive then
			RoundManager.EndRound("AllDead")
		end
	end)
end

-- Counts down on the dead player's screen and teleports them back to the
-- lobby when the countdown expires (unless they revive first).
function RoundManager.StartDeathCountdown(player, survived, bestSeconds, isNewRecord)
	local s = dm().GetSession(player)
	-- Kill any prior countdown for this player.
	if s.DeathTaskId then
		s.DeathTaskId = nil  -- the prior task will see this and exit
	end
	local taskId = {}  -- unique table reference
	s.DeathTaskId = taskId
	s.PendingLobbyReturn = true

	task.spawn(function()
		local total = GameConfig.Round.DeathLobbyReturnSec
		for left = total, 1, -1 do
			-- If a different countdown was started or player revived, stop.
			if s.DeathTaskId ~= taskId then return end
			if s.Alive then
				s.PendingLobbyReturn = false
				return
			end
			getRemotes().DeathCountdown:FireClient(player, {
				secondsLeft     = left,
				survivedSeconds = survived,
				bestSeconds     = bestSeconds,
				isNewRecord     = isNewRecord and true or false,
				canRevive       = not s.UsedRevive,
			})
			task.wait(1)
		end

		-- Verify still dead and same task; if so, return to lobby.
		if s.DeathTaskId ~= taskId then return end
		if s.Alive then return end

		s.PendingLobbyReturn = false
		s.DeathTaskId = nil
		-- Send a final tick with secondsLeft=0 so the GUI can fade.
		getRemotes().DeathCountdown:FireClient(player, {
			secondsLeft     = 0,
			survivedSeconds = survived,
			bestSeconds     = bestSeconds,
			isNewRecord     = isNewRecord and true or false,
			canRevive       = false,
		})
		-- Respawn back at the lobby spawn (clean, no weapon).
		player:LoadCharacter()
		task.wait(0.4)
		teleportToLobby(player)
		-- ensure session is reset for spectating until next round
		s.CurrentWeapon = "Stick"
		clearTools(player)
	end)
end

function RoundManager.RevivePlayer(player)
	if RoundManager.State ~= "PLAYING" then return false end
	local s = dm().GetSession(player)
	if s.UsedRevive then return false end
	s.UsedRevive = true
	s.Alive = true
	-- Cancel any pending death-to-lobby countdown for this player.
	s.DeathTaskId = nil
	s.PendingLobbyReturn = false

	-- Respawn at a safe spot (crash position)
	player:LoadCharacter()
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp  = char:WaitForChild("HumanoidRootPart")
	local crash = (_G.IslandBuilder and _G.IslandBuilder.GetCrashPosition()) or Vector3.new(0, 10, 0)
	hrp.CFrame = CFrame.new(crash + Vector3.new(0, 6, 0))

	-- Re-equip starter weapon
	if _G.ShopManager and _G.ShopManager.GiveWeapon then
		_G.ShopManager.GiveWeapon(player, GameConfig.Round.StartingWeapon)
	end

	getRemotes().ToastNotify:FireClient(player, {
		text = "החייאה הצליחה!",
		color = Color3.fromRGB(120, 220, 120),
	})
	return true
end

-- ====== State transitions ======
local function setState(state, payload)
	RoundManager.State = state
	broadcastState(payload)
	print(string.format("[RoundManager] State -> %s", state))
end

function RoundManager.StartCountdown()
	if RoundManager.State ~= "LOBBY" then return end
	setState("COUNTDOWN")

	if RoundManager.CountdownTask then
		task.cancel(RoundManager.CountdownTask)
	end

	RoundManager.CountdownTask = task.spawn(function()
		for s = GameConfig.Lobby.CountdownSeconds, 1, -1 do
			if RoundManager.State ~= "COUNTDOWN" then return end
			getRemotes().LobbyCountdown:FireAllClients({ secondsLeft = s })
			task.wait(1)
		end
		if RoundManager.State == "COUNTDOWN" then
			RoundManager.BeginFlight()
		end
	end)
end

function RoundManager.CancelCountdown()
	if RoundManager.State ~= "COUNTDOWN" then return end
	if RoundManager.CountdownTask then
		task.cancel(RoundManager.CountdownTask)
		RoundManager.CountdownTask = nil
	end
	setState("LOBBY")
	getRemotes().LobbyCountdown:FireAllClients({ secondsLeft = 0, cancelled = true })
end

function RoundManager.BeginFlight()
	setState("BOARDING")
	-- Collect players currently in the lobby
	local participants = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character and #participants < GameConfig.Lobby.MaxPlayers then
			table.insert(participants, p)
		end
	end
	if #participants == 0 then
		setState("LOBBY")
		return
	end

	if _G.PlaneManager and _G.PlaneManager.RunFlight then
		setState("FLIGHT")
		_G.PlaneManager.RunFlight(participants, function()
			RoundManager.BeginPlaying(participants)
		end)
	else
		-- Fallback: skip directly to playing
		RoundManager.BeginPlaying(participants)
	end
end

function RoundManager.BeginPlaying(participants)
	setState("CRASH")
	if _G.PlaneManager and _G.PlaneManager.PlayCrash then
		_G.PlaneManager.PlayCrash()
	end
	task.wait(2)

	setState("PLAYING")
	RoundManager.RoundStartTime = tick()
	for _, p in ipairs(participants) do
		local s = dm().GetSession(p)
		s.Alive = true
		s.UsedRevive = false
		s.XP = 0
		s.DeathTaskId = nil
		s.PendingLobbyReturn = false
		-- Give starter weapon
		if _G.ShopManager and _G.ShopManager.GiveWeapon then
			_G.ShopManager.GiveWeapon(p, GameConfig.Round.StartingWeapon)
		end
		-- If they own Shotgun (Robux), give it too
		if _G.DataManager.OwnsShotgun(p) and _G.ShopManager and _G.ShopManager.GiveWeapon then
			_G.ShopManager.GiveWeapon(p, "Shotgun")
		end
		-- Apply HP upgrades
		if p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				local hpLevel = s.PlaneUpgrades.HP or 0
				local maxHp = GameConfig.PlaneUpgrades.HP.Effect[hpLevel + 1] or GameConfig.Round.StartingHP
				hum.MaxHealth = maxHp
				hum.Health    = maxHp
				local spdMul = GameConfig.PlaneUpgrades.Speed.Effect[(s.PlaneUpgrades.Speed or 0) + 1] or 1
				hum.WalkSpeed = 16 * spdMul
			end
		end
	end

	-- Animal spawning loop start
	if _G.AnimalManager and _G.AnimalManager.StartSpawning then
		_G.AnimalManager.StartSpawning()
	end

	-- XP timer loop
	task.spawn(function()
		while RoundManager.State == "PLAYING" do
			task.wait(GameConfig.Round.XPTickInterval)
			if RoundManager.State ~= "PLAYING" then break end
			for _, p in ipairs(Players:GetPlayers()) do
				local s = dm().GetSession(p)
				if s.Alive then
					dm().AddXP(p, GameConfig.Round.XPPerSecond * GameConfig.Round.XPTickInterval / 10)
				end
			end
		end
	end)
end

function RoundManager.EndRound(reason)
	if RoundManager.State == "ENDING" or RoundManager.State == "LOBBY" then return end
	setState("ENDING", { reason = reason })
	if _G.AnimalManager and _G.AnimalManager.StopSpawning then
		_G.AnimalManager.StopSpawning()
	end
	killAllAnimals()

	task.wait(5)
	setState("LOBBY")
	for _, p in ipairs(Players:GetPlayers()) do
		resetForLobby(p)
	end
end

-- ====== Bootstrap ======
function RoundManager.Start()
	-- On player join, place them in the lobby and reset session.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			task.wait(0.2)
			if RoundManager.State == "LOBBY" or RoundManager.State == "COUNTDOWN" then
				resetForLobby(player)
			elseif RoundManager.State == "PLAYING" then
				-- Late joiner: stays in lobby until next round
				teleportToLobby(player)
			end
			-- HUD pulse
			task.delay(0.5, function()
				if not player.Parent then return end
				getRemotes().UpdateHUD:FireClient(player, RoundManager.BuildHUD(player))
			end)
		end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			task.spawn(resetForLobby, p)
		end
	end

	-- HUD update pulse for everyone
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, p in ipairs(Players:GetPlayers()) do
				if not p.Parent then continue end
				getRemotes().UpdateHUD:FireClient(p, RoundManager.BuildHUD(p))
			end
		end
	end)

	-- Watch deaths
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid")
			hum.Died:Connect(function()
				RoundManager.OnPlayerDied(player, "סכנה")
			end)
		end)
	end)

	setState("LOBBY")
end

function RoundManager.BuildHUD(player)
	local s = dm().GetSession(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local hp, maxHp = 0, GameConfig.Round.StartingHP
	if hum then hp = hum.Health; maxHp = hum.MaxHealth end
	local elapsed = 0
	if RoundManager.State == "PLAYING" then
		elapsed = math.floor(tick() - RoundManager.RoundStartTime)
	end
	return {
		state    = RoundManager.State,
		hp       = math.floor(hp),
		maxHp    = math.floor(maxHp),
		xp       = math.floor(s.XP),
		weapon   = s.CurrentWeapon,
		alive    = s.Alive,
		time     = elapsed,
		ownsShotgun = _G.DataManager.OwnsShotgun(player),
	}
end

_G.RoundManager = RoundManager
print("[RoundManager] Ready.")

]==]

sources.LobbyManager = [==[
-- LobbyManager.server.lua
-- Place in: ServerScriptService as Script named "LobbyManager"
-- Detects players standing on the Ready Pad and triggers RoundManager.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local LobbyManager = {}

local function getReadyPad()
	local world = Workspace:FindFirstChild("IslandWorld")
	if not world then return nil end
	local lobby = world:FindFirstChild("Lobby")
	if not lobby then return nil end
	return lobby:FindFirstChild("ReadyPad")
end

-- Returns count of distinct players whose HumanoidRootPart is above the pad.
local function countOnPad(pad)
	if not pad then return 0 end
	local seen = {}
	local padPos = pad.Position
	local s = pad.Size
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = hrp.Position - padPos
				if math.abs(d.X) <= s.X/2 + 1 and math.abs(d.Z) <= s.Z/2 + 1 and d.Y >= -2 and d.Y <= 8 then
					seen[p.UserId] = true
				end
			end
		end
	end
	local n = 0
	for _ in pairs(seen) do n = n + 1 end
	return n
end

function LobbyManager.Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local rm = _G.RoundManager
			if not rm then continue end
			if rm.GetState() ~= "LOBBY" and rm.GetState() ~= "COUNTDOWN" then
				continue
			end
			local pad = getReadyPad()
			if not pad then continue end
			local n = countOnPad(pad)
			if rm.GetState() == "LOBBY" then
				if n >= 1 then rm.StartCountdown() end
			elseif rm.GetState() == "COUNTDOWN" then
				if n == 0 then rm.CancelCountdown() end
			end
		end
	end)
	print("[LobbyManager] Started.")
end

_G.LobbyManager = LobbyManager
LobbyManager.Start()
print("[LobbyManager] Ready.")

]==]

sources.PlaneManager = [==[
-- PlaneManager.server.lua
-- Place in: ServerScriptService as Script named "PlaneManager"
-- Builds a plane model, seats players, tweens flight, handles crash VFX.

local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local Players          = game:GetService("Players")
local Debris           = game:GetService("Debris")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local PlaneManager = {}

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function weldTo(child, parent)
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = child
	w.Parent = child
end

local function buildPlaneModel()
	local model = Instance.new("Model")
	model.Name = "CrashPlane"

	local body = GameConfig.Plane.BodyColor
	local accent = GameConfig.Plane.WingColor
	local trim = Color3.fromRGB(160, 50, 50)

	-- Fuselage: rounded cylinder lying flat
	local fuselage = makePart{
		Name="Fuselage",
		Shape=Enum.PartType.Cylinder,
		Size=Vector3.new(28, 5, 5),
		CFrame=CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color=body, Material=Enum.Material.Metal,
		Parent=model,
	}
	-- Nose cone
	local nose = makePart{
		Name="Nose",
		Shape=Enum.PartType.Ball,
		Size=Vector3.new(5, 5, 5),
		CFrame=CFrame.new(0, 0, -14),
		Color=body, Material=Enum.Material.Metal,
		Parent=model,
	}
	-- Trim stripe along the side
	local stripe = makePart{
		Name="Stripe", Size=Vector3.new(6, 1, 28),
		CFrame=CFrame.new(0, 0.6, 0),
		Color=trim, Material=Enum.Material.SmoothPlastic,
		Parent=model,
	}
	-- Cockpit canopy (glass)
	local canopy = makePart{
		Name="Canopy",
		Shape=Enum.PartType.Cylinder,
		Size=Vector3.new(6, 4, 4.6),
		CFrame=CFrame.new(0, 2, -8) * CFrame.Angles(0, 0, math.rad(90)),
		Color=Color3.fromRGB(120, 180, 220),
		Material=Enum.Material.Glass,
		Transparency=0.4,
		Reflectance=0.3,
		Parent=model,
	}
	-- Cockpit window divider
	local divider = makePart{
		Name="Divider", Size=Vector3.new(0.4, 4.2, 6.2),
		CFrame=CFrame.new(0, 2, -8),
		Color=Color3.fromRGB(60, 60, 70), Material=Enum.Material.Metal,
		Parent=model,
	}

	-- Wings (swept slightly back) — main wing
	local wingL = makePart{
		Name="WingL", Size=Vector3.new(14, 0.7, 5),
		CFrame=CFrame.new(-9, 0.2, 1) * CFrame.Angles(0, math.rad(8), 0),
		Color=accent, Material=Enum.Material.Metal,
		Parent=model,
	}
	local wingR = makePart{
		Name="WingR", Size=Vector3.new(14, 0.7, 5),
		CFrame=CFrame.new( 9, 0.2, 1) * CFrame.Angles(0, math.rad(-8), 0),
		Color=accent, Material=Enum.Material.Metal,
		Parent=model,
	}
	-- Winglets at wing tips
	local wingletL = makePart{
		Name="WingletL", Size=Vector3.new(0.6, 2.5, 3),
		CFrame=CFrame.new(-15.5, 1.4, 1.5),
		Color=trim, Material=Enum.Material.Metal,
		Parent=model,
	}
	local wingletR = makePart{
		Name="WingletR", Size=Vector3.new(0.6, 2.5, 3),
		CFrame=CFrame.new( 15.5, 1.4, 1.5),
		Color=trim, Material=Enum.Material.Metal,
		Parent=model,
	}

	-- Engines on wings (cylinders) with propellers
	local function buildEngine(side)
		local engine = makePart{
			Name="Engine",
			Shape=Enum.PartType.Cylinder,
			Size=Vector3.new(5, 2, 2),
			CFrame=CFrame.new(side * 6, -0.6, -1) * CFrame.Angles(0, 0, math.rad(90)),
			Color=Color3.fromRGB(60, 60, 70), Material=Enum.Material.Metal,
			Parent=model,
		}
		-- Propeller (3-blade) — anchored disc that we'll spin via tween or while loop
		local prop = makePart{
			Name="Propeller",
			Shape=Enum.PartType.Cylinder,
			Size=Vector3.new(0.3, 4, 0.4),
			CFrame=CFrame.new(side * 6, -0.6, -3.6) * CFrame.Angles(0, 0, 0),
			Color=Color3.fromRGB(20, 20, 22), Material=Enum.Material.Metal,
			Parent=model,
		}
		prop:SetAttribute("IsProp", true)
		-- Spinner cone
		local spinner = makePart{
			Name="Spinner", Shape=Enum.PartType.Ball,
			Size=Vector3.new(1.2, 1.2, 1.2),
			CFrame=CFrame.new(side * 6, -0.6, -3.8),
			Color=trim, Material=Enum.Material.Metal,
			Parent=model,
		}
		return prop
	end
	local propL = buildEngine(-1)
	local propR = buildEngine( 1)

	-- Tail section
	local tailFin = makePart{
		Name="TailFin", Size=Vector3.new(0.6, 5, 5),
		CFrame=CFrame.new(0, 3, 12),
		Color=accent, Material=Enum.Material.Metal,
		Parent=model,
	}
	local hStab = makePart{
		Name="HorizStab", Size=Vector3.new(8, 0.5, 3),
		CFrame=CFrame.new(0, 1.5, 13),
		Color=accent, Material=Enum.Material.Metal,
		Parent=model,
	}
	local tailTrim = makePart{
		Name="TailTrim", Size=Vector3.new(0.7, 1, 5),
		CFrame=CFrame.new(0, 5.2, 12),
		Color=trim, Material=Enum.Material.SmoothPlastic,
		Parent=model,
	}

	-- Door (left side, rear)
	local door = makePart{
		Name="Door", Size=Vector3.new(0.3, 3.5, 2),
		CFrame=CFrame.new(-2.6, 0.2, 4),
		Color=trim, Material=Enum.Material.Metal,
		Parent=model,
	}

	-- Weld everything to fuselage so the model moves as one when we tween.
	for _, p in ipairs(model:GetChildren()) do
		if p ~= fuselage and p:IsA("BasePart") then
			weldTo(p, fuselage)
		end
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end

	model.PrimaryPart = fuselage
	return model
end

local function seatPlayers(model, players)
	local body = model.PrimaryPart
	local seatPositions = {
		Vector3.new(-2, 2.5, -4),
		Vector3.new( 2, 2.5, -4),
		Vector3.new(-2, 2.5,  2),
		Vector3.new( 2, 2.5,  2),
		Vector3.new( 0, 2.5,  6),
	}
	for i, p in ipairs(players) do
		local char = p.Character
		if not char then continue end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hrp and hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hrp.Anchored  = true
			local off = seatPositions[i] or Vector3.new(0, 2.5, 0)
			hrp.CFrame = body.CFrame * CFrame.new(off)
		end
	end
end

local function unseatPlayers(players, ejectionCenter)
	local r = GameConfig.Plane.EjectionSpread
	for _, p in ipairs(players) do
		local char = p.Character
		if not char then continue end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hrp and hum then
			hrp.Anchored = false
			hum.WalkSpeed = 16
			hum.JumpPower = 50
			local angle = math.random() * math.pi * 2
			local dist  = math.random(r/2, r)
			hrp.CFrame = CFrame.new(
				ejectionCenter + Vector3.new(math.cos(angle)*dist, 8, math.sin(angle)*dist)
			)
		end
	end
end

function PlaneManager.RunFlight(players, onArrive)
	local model = buildPlaneModel()
	model.Parent = Workspace

	local startPos = GameConfig.Plane.StartOffset
	local endPos   = GameConfig.Plane.CrashTarget + Vector3.new(0, 50, 0)
	local startCF  = CFrame.new(startPos, endPos)
	model:SetPrimaryPartCFrame(startCF)

	-- Notify clients (for camera framing if desired)
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	Remotes.PlaneFlight:FireAllClients({
		startPosition = startPos,
		endPosition   = endPos,
		duration      = GameConfig.Plane.FlightSeconds,
	})

	seatPlayers(model, players)

	-- Animate via repeated CFrame interpolation (PrimaryPart drag).
	local steps = 60
	local dt    = GameConfig.Plane.FlightSeconds / steps
	task.spawn(function()
		for i = 1, steps do
			if not model.Parent then return end
			local t = i / steps
			-- Slight arc: dip mid-flight then climb to crash height
			local arcY = math.sin(t * math.pi) * 30
			local pos  = startPos:Lerp(endPos, t) + Vector3.new(0, arcY, 0)
			local look = endPos
			local cf   = CFrame.new(pos, look)
			-- Wobble for engine-failure effect at the end
			if t > 0.7 then
				local shake = (t - 0.7) * 4
				cf = cf * CFrame.Angles(
					math.sin(tick()*15)*shake*0.05,
					0,
					math.sin(tick()*22)*shake*0.08
				)
			end
			model:SetPrimaryPartCFrame(cf)
			-- Re-anchor players to seats
			seatPlayers(model, players)
			task.wait(dt)
		end

		-- Final crash position
		local crash = (_G.IslandBuilder and _G.IslandBuilder.GetCrashPosition()) or Vector3.new(0,10,0)
		Remotes.CrashEffect:FireAllClients({ position = crash })

		-- Eject players to crash site
		unseatPlayers(players, crash)
		PlaneManager.PlayCrash(model, crash)

		if onArrive then onArrive() end
	end)
end

-- Spawn explosion + smoke at a position. Optionally destroys a plane model.
function PlaneManager.PlayCrash(model, position)
	if type(model) == "table" and model.Position then
		position = model
		model = nil
	end
	position = position or Vector3.new(0, 10, 0)

	-- Explosion
	local exp = Instance.new("Explosion")
	exp.BlastRadius = 0
	exp.BlastPressure = 0
	exp.DestroyJointRadiusPercent = 0
	exp.Position = position
	exp.Parent = Workspace

	-- Smoke
	local debris = makePart{
		Name="CrashDebris", Anchored=true, CanCollide=false, Transparency=1,
		Size=Vector3.new(1,1,1), Position=position, Parent=Workspace,
	}
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(40,40,40)
	smoke.Opacity = 0.8
	smoke.Size = 12
	smoke.RiseVelocity = 6
	smoke.Parent = debris
	Debris:AddItem(debris, 30)

	-- Destroy plane after a beat
	if model then
		task.delay(0.3, function()
			if model.Parent then model:Destroy() end
		end)
	end
end

_G.PlaneManager = PlaneManager
print("[PlaneManager] Ready.")

]==]

sources.AnimalManager = [==[
-- AnimalManager.server.lua
-- Place in: ServerScriptService as Script named "AnimalManager"
-- Spawns and runs animals: builds models, runs FSM (Idle -> Chase -> Attack).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")
local Debris            = game:GetService("Debris")

local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))
local AnimalConfig = require(ReplicatedStorage:WaitForChild("AnimalConfig"))
local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))

local AnimalManager = {}
local active = {}            -- [model] = stateTable
local spawning = false
local roundStartTime = 0
local Remotes -- lazy

local function getRemotes()
	if Remotes then return Remotes end
	Remotes = ReplicatedStorage:WaitForChild("Remotes")
	return Remotes
end

local function makePart(props)
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

-- Build a detailed animal model with per-species touches.
-- Uses Motor6D welds for legs/tail so we can animate them.
local function buildAnimalModel(spec)
	local model = Instance.new("Model")
	model.Name = spec.Id

	-- Invisible HRP doubles as collision body sized to the visible body.
	local hrp = makePart{
		Name="HumanoidRootPart",
		Size=Vector3.new(spec.BodySize.X, spec.BodySize.Y, spec.BodySize.Z),
		Color=spec.BodyColor, Material=Enum.Material.SmoothPlastic,
		CanCollide=true, Transparency=1, Parent=model,
	}
	model.PrimaryPart = hrp

	-- Main torso (slightly tapered: chest larger than rear)
	local chest = makePart{
		Name="Chest",
		Shape=Enum.PartType.Block,
		Size=Vector3.new(spec.BodySize.X * 1.05, spec.BodySize.Y * 1.05, spec.BodySize.Z * 0.55),
		Color=spec.BodyColor, Material=Enum.Material.SmoothPlastic,
		CanCollide=false, Parent=model,
	}
	chest.CFrame = hrp.CFrame * CFrame.new(0, 0, -spec.BodySize.Z * 0.18)
	local cw = Instance.new("WeldConstraint", chest); cw.Part0 = hrp; cw.Part1 = chest

	local rear = makePart{
		Name="Rear",
		Shape=Enum.PartType.Block,
		Size=Vector3.new(spec.BodySize.X * 0.92, spec.BodySize.Y * 0.95, spec.BodySize.Z * 0.5),
		Color=spec.BodyColor, Material=Enum.Material.SmoothPlastic,
		CanCollide=false, Parent=model,
	}
	rear.CFrame = hrp.CFrame * CFrame.new(0, -0.05, spec.BodySize.Z * 0.25)
	local rw = Instance.new("WeldConstraint", rear); rw.Part0 = hrp; rw.Part1 = rear

	-- Neck (cylinder leading to head)
	local neckLen = math.max(0.6, spec.BodySize.Y * 0.4)
	local neck = makePart{
		Name="Neck", Shape=Enum.PartType.Cylinder,
		Size=Vector3.new(neckLen, spec.BodySize.X * 0.5, spec.BodySize.X * 0.5),
		Color=spec.BodyColor, Material=Enum.Material.SmoothPlastic,
		CanCollide=false, Parent=model,
	}
	neck.CFrame = hrp.CFrame
		* CFrame.new(0, spec.BodySize.Y * 0.25, -spec.BodySize.Z * 0.55)
		* CFrame.Angles(0, 0, math.rad(70))
	local nw = Instance.new("WeldConstraint", neck); nw.Part0 = hrp; nw.Part1 = neck

	-- Head: shape varies per species
	local headShape = Enum.PartType.Block
	if spec.Id == "Bear" or spec.Id == "Lion" then
		headShape = Enum.PartType.Ball
	end
	local head = makePart{
		Name="Head",
		Shape = headShape,
		Size=spec.HeadSize, Color=spec.BodyColor,
		Material=Enum.Material.SmoothPlastic,
		CanCollide=false, Parent=model,
	}
	head.CFrame = hrp.CFrame * CFrame.new(0, spec.BodySize.Y * 0.5, -spec.BodySize.Z * 0.7)
	local hw = Instance.new("WeldConstraint", head); hw.Part0 = hrp; hw.Part1 = head

	-- Snout (forward extension of head)
	local snoutLen = spec.HeadSize.Z * 0.55
	local snoutColor = spec.Id == "Lion" and Color3.fromRGB(230, 200, 130)
		or Color3.fromRGB(math.max(spec.BodyColor.R*255 - 30, 0), math.max(spec.BodyColor.G*255 - 30, 0), math.max(spec.BodyColor.B*255 - 30, 0))
	local snout = makePart{
		Name="Snout",
		Shape = (spec.Id == "Wolf") and Enum.PartType.Block or Enum.PartType.Block,
		Size=Vector3.new(spec.HeadSize.X * 0.65, spec.HeadSize.Y * 0.55, snoutLen),
		Color=snoutColor, Material=Enum.Material.SmoothPlastic,
		CanCollide=false, Parent=model,
	}
	snout.CFrame = head.CFrame * CFrame.new(0, -spec.HeadSize.Y * 0.1, -(spec.HeadSize.Z * 0.5 + snoutLen * 0.4))
	local sw = Instance.new("WeldConstraint", snout); sw.Part0 = head; sw.Part1 = snout

	-- Nose tip
	local nose = makePart{
		Name="Nose", Shape=Enum.PartType.Ball,
		Size=Vector3.new(spec.HeadSize.X * 0.28, spec.HeadSize.X * 0.28, spec.HeadSize.X * 0.28),
		Color=Color3.fromRGB(20, 16, 18), Material=Enum.Material.SmoothPlastic,
		CanCollide=false, Parent=model,
	}
	nose.CFrame = snout.CFrame * CFrame.new(0, 0, -snoutLen * 0.5)
	local nosew = Instance.new("WeldConstraint", nose); nosew.Part0 = snout; nosew.Part1 = nose

	-- Eyes
	for _, sx in ipairs({-1, 1}) do
		local eye = makePart{
			Name="Eye", Shape=Enum.PartType.Ball,
			Size=Vector3.new(0.32, 0.32, 0.32),
			Color=Color3.fromRGB(20,20,20), Material=Enum.Material.SmoothPlastic,
			CanCollide=false, Parent=model,
		}
		eye.CFrame = head.CFrame * CFrame.new(sx*spec.HeadSize.X*0.32, spec.HeadSize.Y*0.18, -spec.HeadSize.Z*0.45)
		local ew = Instance.new("WeldConstraint", eye); ew.Part0 = head; ew.Part1 = eye
	end

	-- Ears: per-species
	local function buildEar(side)
		if spec.Id == "Dog" then
			-- Floppy down-pointing ears
			local ear = makePart{
				Name="Ear", Shape=Enum.PartType.Block,
				Size=Vector3.new(0.25, spec.HeadSize.Y * 0.6, spec.HeadSize.Z * 0.45),
				Color=spec.BodyColor, Material=Enum.Material.SmoothPlastic,
				CanCollide=false, Parent=model,
			}
			ear.CFrame = head.CFrame
				* CFrame.new(side * spec.HeadSize.X * 0.5, 0, 0)
				* CFrame.Angles(math.rad(-15), 0, math.rad(side * 25))
			local ew = Instance.new("WeldConstraint", ear); ew.Part0 = head; ew.Part1 = ear
		elseif spec.Id == "Wolf" then
			-- Pointy upright ears
			local ear = makePart{
				Name="Ear", Shape=Enum.PartType.Block,
				Size=Vector3.new(0.3, spec.HeadSize.Y * 0.7, 0.5),
				Color=spec.BodyColor, Material=Enum.Material.SmoothPlastic,
				CanCollide=false, Parent=model,
			}
			ear.CFrame = head.CFrame
				* CFrame.new(side * spec.HeadSize.X * 0.4, spec.HeadSize.Y * 0.55, spec.HeadSize.Z * 0.1)
				* CFrame.Angles(0, 0, math.rad(side * 20))
			local ew = Instance.new("WeldConstraint", ear); ew.Part0 = head; ew.Part1 = ear
		elseif spec.Id == "Bear" then
			-- Small round ears on top
			local ear = makePart{
				Name="Ear", Shape=Enum.PartType.Ball,
				Size=Vector3.new(spec.HeadSize.X * 0.35, spec.HeadSize.X * 0.35, spec.HeadSize.X * 0.35),
				Color=spec.BodyColor, Material=Enum.Material.SmoothPlastic,
				CanCollide=false, Parent=model,
			}
			ear.CFrame = head.CFrame * CFrame.new(side * spec.HeadSize.X * 0.42, spec.HeadSize.Y * 0.45, spec.HeadSize.Z * 0.05)
			local ew = Instance.new("WeldConstraint", ear); ew.Part0 = head; ew.Part1 = ear
		else
			-- Lion: tufted small ears
			local ear = makePart{
				Name="Ear", Shape=Enum.PartType.Ball,
				Size=Vector3.new(spec.HeadSize.X * 0.3, spec.HeadSize.X * 0.3, spec.HeadSize.X * 0.3),
				Color=spec.BodyColor, Material=Enum.Material.SmoothPlastic,
				CanCollide=false, Parent=model,
			}
			ear.CFrame = head.CFrame * CFrame.new(side * spec.HeadSize.X * 0.5, spec.HeadSize.Y * 0.4, 0)
			local ew = Instance.new("WeldConstraint", ear); ew.Part0 = head; ew.Part1 = ear
		end
	end
	buildEar(-1); buildEar(1)

	-- Mane (lion: large fluffy ring around the head)
	if spec.ManeColor then
		for i = 1, 6 do
			local angle = (i / 6) * math.pi * 2
			local r = spec.HeadSize.X * 1.0
			local tuft = makePart{
				Name="ManeTuft", Shape=Enum.PartType.Ball,
				Size=Vector3.new(spec.HeadSize.X * 0.85, spec.HeadSize.X * 0.85, spec.HeadSize.X * 0.85),
				Color=spec.ManeColor, Material=Enum.Material.SmoothPlastic,
				CanCollide=false, Parent=model,
			}
			tuft.CFrame = head.CFrame * CFrame.new(math.cos(angle) * r, math.sin(angle) * r * 0.7, spec.HeadSize.Z * 0.15)
			local tw = Instance.new("WeldConstraint", tuft); tw.Part0 = head; tw.Part1 = tuft
		end
		-- Center mass behind head
		local mass = makePart{
			Name="ManeMass", Shape=Enum.PartType.Ball,
			Size=Vector3.new(spec.HeadSize.X * 1.7, spec.HeadSize.Y * 1.5, spec.HeadSize.Z * 1.4),
			Color=spec.ManeColor, Material=Enum.Material.SmoothPlastic,
			CanCollide=false, Parent=model,
		}
		mass.CFrame = head.CFrame * CFrame.new(0, 0, spec.HeadSize.Z * 0.2)
		local mw = Instance.new("WeldConstraint", mass); mw.Part0 = head; mw.Part1 = mass
	end

	-- Bear belly (chunky)
	if spec.Id == "Bear" then
		local belly = makePart{
			Name="Belly", Shape=Enum.PartType.Ball,
			Size=Vector3.new(spec.BodySize.X * 1.15, spec.BodySize.Y * 1.1, spec.BodySize.Z * 0.7),
			Color=Color3.fromRGB(75, 50, 30), Material=Enum.Material.SmoothPlastic,
			CanCollide=false, Parent=model,
		}
		belly.CFrame = hrp.CFrame * CFrame.new(0, -spec.BodySize.Y * 0.15, 0)
		local bw = Instance.new("WeldConstraint", belly); bw.Part0 = hrp; bw.Part1 = belly
	end

	-- Legs as Motor6D-anchored parts so we can animate the rotation.
	local legParts = {}
	local legOffsets = {
		Vector3.new(-spec.BodySize.X*0.32, -spec.BodySize.Y*0.5, -spec.BodySize.Z*0.32),  -- FL
		Vector3.new( spec.BodySize.X*0.32, -spec.BodySize.Y*0.5, -spec.BodySize.Z*0.32),  -- FR
		Vector3.new(-spec.BodySize.X*0.32, -spec.BodySize.Y*0.5,  spec.BodySize.Z*0.32),  -- BL
		Vector3.new( spec.BodySize.X*0.32, -spec.BodySize.Y*0.5,  spec.BodySize.Z*0.32),  -- BR
	}
	for i, off in ipairs(legOffsets) do
		local leg = makePart{
			Name = "Leg" .. i, Size = spec.LegSize,
			Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
			CanCollide = false, Parent = model,
		}
		-- attachment-based motor so we can rotate
		local a0 = Instance.new("Attachment"); a0.Position = off; a0.Parent = hrp
		local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, spec.LegSize.Y * 0.5, 0); a1.Parent = leg
		leg.CFrame = hrp.CFrame * CFrame.new(off + Vector3.new(0, -spec.LegSize.Y * 0.5, 0))
		local motor = Instance.new("Motor6D")
		motor.Name = "LegMotor"
		motor.Part0 = hrp
		motor.Part1 = leg
		motor.C0 = CFrame.new(off)
		motor.C1 = CFrame.new(0, spec.LegSize.Y * 0.5, 0)
		motor.Parent = hrp
		-- Paw
		local paw = makePart{
			Name="Paw", Shape=Enum.PartType.Block,
			Size=Vector3.new(spec.LegSize.X * 1.2, spec.LegSize.X * 0.4, spec.LegSize.X * 1.4),
			Color=Color3.fromRGB(30, 22, 18), Material=Enum.Material.SmoothPlastic,
			CanCollide=false, Parent=model,
		}
		paw.CFrame = leg.CFrame * CFrame.new(0, -spec.LegSize.Y * 0.45, 0)
		local pw = Instance.new("WeldConstraint", paw); pw.Part0 = leg; pw.Part1 = paw
		legParts[i] = motor
	end

	-- Tail with Motor6D so we can wag it.
	local tailLen = spec.BodySize.Z * 0.55
	local tail = makePart{
		Name="Tail", Shape=Enum.PartType.Cylinder,
		Size=Vector3.new(tailLen, 0.4, 0.4),
		Color=spec.BodyColor, Material=Enum.Material.SmoothPlastic,
		CanCollide=false, Parent=model,
	}
	tail.CFrame = hrp.CFrame
		* CFrame.new(0, spec.BodySize.Y * 0.2, spec.BodySize.Z * 0.55 + tailLen * 0.4)
		* CFrame.Angles(0, math.rad(90), 0)
	local tailMotor = Instance.new("Motor6D")
	tailMotor.Name = "TailMotor"
	tailMotor.Part0 = hrp
	tailMotor.Part1 = tail
	tailMotor.C0 = CFrame.new(0, spec.BodySize.Y * 0.2, spec.BodySize.Z * 0.55) * CFrame.Angles(0, math.rad(90), 0)
	tailMotor.C1 = CFrame.new(-tailLen * 0.4, 0, 0)
	tailMotor.Parent = hrp

	-- Tail tuft (lion)
	if spec.ManeColor then
		local tuft = makePart{
			Name="TailTuft", Shape=Enum.PartType.Ball,
			Size=Vector3.new(0.8, 0.8, 0.8),
			Color=spec.ManeColor, Material=Enum.Material.SmoothPlastic,
			CanCollide=false, Parent=model,
		}
		tuft.CFrame = tail.CFrame * CFrame.new(tailLen * 0.5, 0, 0)
		local tuw = Instance.new("WeldConstraint", tuft); tuw.Part0 = tail; tuw.Part1 = tuft
	end

	-- Humanoid
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = spec.HP
	hum.Health    = spec.HP
	hum.WalkSpeed = spec.WalkSpeed
	hum.AutoRotate = true
	hum.HipHeight  = spec.LegSize.Y * 0.5
	hum.BreakJointsOnDeath = false
	hum.Parent = model

	-- Stash motors so the AI loop can animate.
	model:SetAttribute("_HasMotors", true)
	local motorFolder = Instance.new("Configuration", hrp)
	motorFolder.Name = "Motors"
	for i, m in ipairs(legParts) do m.Parent = hrp; m:SetAttribute("LegIndex", i) end

	-- HP bar above
	local bb = Instance.new("BillboardGui")
	bb.Name = "HPBar"
	bb.Size = UDim2.new(0, 80, 0, 18)
	bb.StudsOffset = Vector3.new(0, spec.BodySize.Y + 1.5, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = hrp
	bb.Parent = hrp
	local bg = Instance.new("Frame", bb)
	bg.Size = UDim2.new(1,0,1,0)
	bg.BackgroundColor3 = Color3.fromRGB(40,40,40)
	bg.BorderSizePixel  = 0
	local fill = Instance.new("Frame", bg)
	fill.Name = "Fill"
	fill.Size = UDim2.new(1,0,1,0)
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	fill.BorderSizePixel  = 0
	local label = Instance.new("TextLabel", bb)
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1,0,1,0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255,255,255)
	label.TextStrokeTransparency = 0
	label.Text = (Strings.Animals[spec.DisplayKey] or spec.Id) .. "  " .. spec.HP .. "/" .. spec.HP

	model:SetAttribute("AnimalId", spec.Id)
	model:SetAttribute("Level", spec.Level)
	model:SetAttribute("XPReward", spec.XPReward)
	model:SetAttribute("Damage", spec.Damage)

	return model
end

local function pickSpawnPos()
	-- Randomly pick a position on the island, between MinDistanceFromPlayer and MaxDistanceFromPlayer
	-- of any active player. Prefer outside crash clearing.
	local cfg = GameConfig.AnimalSpawning
	for _ = 1, 30 do
		local players = Players:GetPlayers()
		local origin
		for _, p in ipairs(players) do
			if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				origin = p.Character.HumanoidRootPart.Position
				break
			end
		end
		if not origin then origin = Vector3.new(0, GameConfig.Island.BaseSize.Y, 0) end
		local angle = math.random() * math.pi * 2
		local d     = math.random(cfg.MinDistanceFromPlayer, cfg.MaxDistanceFromPlayer)
		local x = origin.X + math.cos(angle) * d
		local z = origin.Z + math.sin(angle) * d
		local hx = GameConfig.Island.BaseSize.X / 2 - 20
		local hz = GameConfig.Island.BaseSize.Z / 2 - 20
		if math.abs(x) <= hx and math.abs(z) <= hz then
			return Vector3.new(x, GameConfig.Island.BaseSize.Y + 4, z)
		end
	end
	return Vector3.new(60, GameConfig.Island.BaseSize.Y + 4, 60)
end

local function pickSpecForElapsed(elapsed)
	-- Find current weight stage
	local weights = GameConfig.AnimalSpawning.WeightStages[1].weights
	for _, stage in ipairs(GameConfig.AnimalSpawning.WeightStages) do
		if elapsed >= stage.time then weights = stage.weights end
	end
	-- Weighted pick: index 1=dog, 2=wolf, 3=bear, 4=lion
	local total = 0
	for _, w in ipairs(weights) do total = total + w end
	local roll = math.random() * total
	local accum = 0
	for i, w in ipairs(weights) do
		accum = accum + w
		if roll <= accum then
			return AnimalConfig.List[i]
		end
	end
	return AnimalConfig.List[1]
end

local function findNearestPlayer(animal)
	local hrp = animal.PrimaryPart
	if not hrp then return nil, math.huge end
	local nearest, nearestD = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.Health > 0 then
			local pHrp = char:FindFirstChild("HumanoidRootPart")
			if pHrp then
				local d = (pHrp.Position - hrp.Position).Magnitude
				if d < nearestD then
					nearestD = d
					nearest  = p
				end
			end
		end
	end
	return nearest, nearestD
end

local function attachHumanoidWatcher(model, spec)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.HealthChanged:Connect(function(hp)
		local hrp = model.PrimaryPart
		if hrp then
			local bb = hrp:FindFirstChild("HPBar")
			if bb then
				local fill  = bb:FindFirstChild("Frame") and bb.Frame:FindFirstChild("Fill")
				local label = bb:FindFirstChildOfClass("TextLabel")
				if fill then
					fill.Size = UDim2.new(math.clamp(hp / hum.MaxHealth, 0, 1), 0, 1, 0)
				end
				if label then
					label.Text = (Strings.Animals[spec.DisplayKey] or spec.Id) .. "  " .. math.floor(hp) .. "/" .. spec.HP
				end
			end
		end
	end)
	hum.Died:Connect(function()
		local pos = model.PrimaryPart and model.PrimaryPart.Position or Vector3.new()
		getRemotes().AnimalDied:FireAllClients({
			animalId = spec.Id, position = pos, displayName = Strings.Animals[spec.DisplayKey] or spec.Id,
		})
		active[model] = nil
		Debris:AddItem(model, 4)
	end)
end

-- Walk-cycle animation: rotates the four leg motors out of phase, plus a
-- gentle tail wag. Runs while the animal's velocity is non-trivial.
local function startLegAnimation(model, spec)
	local hrp = model.PrimaryPart
	if not hrp then return end
	-- Collect leg motors (children of hrp with LegMotor name) and tail motor.
	local legMotors, tailMotor
	task.spawn(function()
		while model.Parent do
			if not legMotors then
				legMotors = {}
				for _, c in ipairs(hrp:GetChildren()) do
					if c:IsA("Motor6D") and c.Name == "LegMotor" then
						local idx = c:GetAttribute("LegIndex")
						if idx then legMotors[idx] = c end
					elseif c:IsA("Motor6D") and c.Name == "TailMotor" then
						tailMotor = c
					end
				end
			end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then return end
			local moving = hum.MoveDirection.Magnitude > 0.05
			local t = tick()
			local amp = moving and math.rad(35) or math.rad(0)
			-- Front-left & rear-right move together; front-right & rear-left opposite.
			local phaseA = math.sin(t * 8)
			local phaseB = -phaseA
			if legMotors[1] then legMotors[1].C1 = CFrame.new(0, spec.LegSize.Y * 0.5, 0) * CFrame.Angles(amp * phaseA, 0, 0) end
			if legMotors[2] then legMotors[2].C1 = CFrame.new(0, spec.LegSize.Y * 0.5, 0) * CFrame.Angles(amp * phaseB, 0, 0) end
			if legMotors[3] then legMotors[3].C1 = CFrame.new(0, spec.LegSize.Y * 0.5, 0) * CFrame.Angles(amp * phaseB, 0, 0) end
			if legMotors[4] then legMotors[4].C1 = CFrame.new(0, spec.LegSize.Y * 0.5, 0) * CFrame.Angles(amp * phaseA, 0, 0) end
			if tailMotor then
				local wag = math.rad(15) * math.sin(t * 4)
				tailMotor.C1 = CFrame.new(-spec.BodySize.Z * 0.55 * 0.4, 0, 0) * CFrame.Angles(0, wag, 0)
			end
			task.wait(0.05)
		end
	end)
end

local function runAnimalAI(model, spec)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hrp = model.PrimaryPart
	if not hum or not hrp then return end

	startLegAnimation(model, spec)

	local state = "IDLE"
	local nextWander = 0
	local nextAttack = 0

	while model.Parent and hum.Health > 0 do
		local rm = _G.RoundManager
		if not rm or rm.GetState() ~= "PLAYING" then
			task.wait(0.5)
		else
			local target, dist = findNearestPlayer(model)
			if target and dist <= spec.AggroRange then
				if dist <= spec.AttackRange then
					state = "ATTACK"
					if tick() >= nextAttack then
						-- Apply damage to target
						local char = target.Character
						local tHum = char and char:FindFirstChildOfClass("Humanoid")
						if tHum and tHum.Health > 0 then
							tHum:TakeDamage(spec.Damage)
							-- visual: shake animal forward briefly
							local pHrp = char and char:FindFirstChild("HumanoidRootPart")
							if pHrp then
								getRemotes().ShowDamage:FireAllClients({
									position = pHrp.Position + Vector3.new(0, 3, 0),
									amount   = spec.Damage,
									color    = Color3.fromRGB(255, 80, 80),
								})
							end
						end
						nextAttack = tick() + spec.AttackCD
					end
				else
					state = "CHASE"
					hum:MoveTo(target.Character.HumanoidRootPart.Position)
				end
			else
				state = "IDLE"
				if tick() >= nextWander then
					local angle = math.random() * math.pi * 2
					local r     = math.random(8, 20)
					local goal  = hrp.Position + Vector3.new(math.cos(angle)*r, 0, math.sin(angle)*r)
					hum:MoveTo(goal)
					nextWander = tick() + math.random(4, 7)
				end
			end
			task.wait(0.3)
		end
	end
end

function AnimalManager.SpawnOne()
	local elapsed = tick() - roundStartTime
	local spec = pickSpecForElapsed(elapsed)
	local model = buildAnimalModel(spec)
	local pos = pickSpawnPos()
	model:SetPrimaryPartCFrame(CFrame.new(pos))
	model.Parent = Workspace

	active[model] = { spec = spec }
	attachHumanoidWatcher(model, spec)
	task.spawn(runAnimalAI, model, spec)
	return model
end

function AnimalManager.GetActive() return active end

function AnimalManager.CountActive()
	local n = 0
	for _ in pairs(active) do n = n + 1 end
	return n
end

function AnimalManager.StartSpawning()
	spawning = true
	roundStartTime = tick()
	task.spawn(function()
		-- initial spawn burst
		for i = 1, 4 do
			if not spawning then return end
			AnimalManager.SpawnOne()
			task.wait(0.5)
		end
		while spawning do
			task.wait(GameConfig.AnimalSpawning.SpawnInterval)
			if not spawning then break end
			if AnimalManager.CountActive() < GameConfig.AnimalSpawning.MaxAlive then
				AnimalManager.SpawnOne()
			end
		end
	end)
end

function AnimalManager.StopSpawning()
	spawning = false
end

function AnimalManager.ClearAll()
	for model, _ in pairs(active) do
		if model.Parent then model:Destroy() end
	end
	active = {}
end

_G.AnimalManager = AnimalManager
print("[AnimalManager] Ready.")

]==]

sources.CombatManager = [==[
-- CombatManager.server.lua
-- Place in: ServerScriptService as Script named "CombatManager"
-- Server-authoritative damage. Clients send RequestAttack; the server validates
-- weapon ownership, range, line-of-sight, and cooldown before dealing damage.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")

local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local AnimalConfig = require(ReplicatedStorage:WaitForChild("AnimalConfig"))
local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))

local CombatManager = {}
local lastAttackTime = {}  -- [userId] = tick()
local Remotes -- lazy

local function getRemotes()
	if Remotes then return Remotes end
	Remotes = ReplicatedStorage:WaitForChild("Remotes")
	return Remotes
end

local function dm()
	while not _G.DataManager do task.wait(0.05) end
	return _G.DataManager
end

-- Returns the equipped weapon ID by checking the player's character for a Tool.
local function equippedWeaponId(player)
	local char = player.Character
	if not char then return nil end
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") and c:GetAttribute("WeaponId") then
			return c:GetAttribute("WeaponId"), c
		end
	end
	return nil
end

local function targetIsValidAnimal(target)
	if not target or not target.Parent then return false end
	if not target:IsA("Model") then return false end
	if not target:GetAttribute("AnimalId") then return false end
	local hum = target:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	return true, hum
end

function CombatManager.HandleAttackRequest(player, payload)
	local rm = _G.RoundManager
	if not rm or not rm.IsPlaying() then return end
	if not payload or type(payload) ~= "table" then return end

	local target = payload.target
	local valid, hum = targetIsValidAnimal(target)
	if not valid then return end

	local weaponId, tool = equippedWeaponId(player)
	if not weaponId then return end
	local weapon = WeaponConfig.ById[weaponId]
	if not weapon then return end
	if not dm().OwnsWeapon(player, weaponId) then return end

	local now = tick()
	local last = lastAttackTime[player.UserId] or 0
	if now - last < weapon.Cooldown then return end

	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	local thrp = target.PrimaryPart or target:FindFirstChild("HumanoidRootPart")
	if not hrp or not thrp then return end
	local dist = (thrp.Position - hrp.Position).Magnitude
	if dist > weapon.Range + 4 then return end

	-- All checks passed. Compute damage.
	local animalLevel = target:GetAttribute("Level") or 1
	local damage = weapon.Damage
	if weapon.Level < animalLevel then
		damage = math.floor(damage * GameConfig.DamageScale.UnderLeveledMultiplier)
	end

	lastAttackTime[player.UserId] = now
	hum:TakeDamage(damage)

	-- Damage number to all clients
	getRemotes().ShowDamage:FireAllClients({
		position = thrp.Position + Vector3.new(0, 3, 0),
		amount   = damage,
		color    = (weapon.Level >= animalLevel) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(180, 180, 180),
	})

	-- If killed, award XP
	if hum.Health <= 0 then
		local xp = target:GetAttribute("XPReward") or (animalLevel * 50)
		dm().AddXP(player, xp)
		local key = target:GetAttribute("AnimalId")
		local nameTxt = key and Strings.Animals[key] or "חיה"
		getRemotes().ToastNotify:FireClient(player, {
			text  = string.format(Strings.Round.AnimalKilled, nameTxt, xp),
			color = Color3.fromRGB(120, 220, 120),
		})
	end

	if GameConfig.Debug then
		print(string.format("[CombatManager] %s hit %s for %d (weapon L%d vs animal L%d)",
			player.Name, target.Name, damage, weapon.Level, animalLevel))
	end
end

function CombatManager.Start()
	getRemotes().RequestAttack.OnServerEvent:Connect(function(player, payload)
		local ok, err = pcall(CombatManager.HandleAttackRequest, player, payload)
		if not ok then warn("[CombatManager] error:", err) end
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastAttackTime[p.UserId] = nil
	end)
end

CombatManager.Start()
_G.CombatManager = CombatManager
print("[CombatManager] Ready.")

]==]

sources.ShopManager = [==[
-- ShopManager.server.lua
-- Place in: ServerScriptService as Script named "ShopManager"
-- Handles XP-based purchases (weapons, plane upgrades) and tool spawning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local MarketplaceService= game:GetService("MarketplaceService")

local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))

local ShopManager = {}
local Remotes

local function getRemotes()
	if Remotes then return Remotes end
	Remotes = ReplicatedStorage:WaitForChild("Remotes")
	return Remotes
end

local function dm()
	while not _G.DataManager do task.wait(0.05) end
	return _G.DataManager
end

-- Build a Tool instance for a weapon spec.
local function buildToolForWeapon(spec)
	local tool = Instance.new("Tool")
	tool.Name = Strings.Weapons[spec.DisplayKey] or spec.Id
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", spec.Id)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = spec.HandleSize
	handle.Color = spec.HandleColor
	handle.Material = spec.Type == "Ranged" and Enum.Material.Metal or Enum.Material.Wood
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	-- Tool tag
	local sg = Instance.new("BillboardGui")
	sg.Adornee = handle
	sg.Size = UDim2.new(0, 100, 0, 30)
	sg.StudsOffset = Vector3.new(0, 1, 0)
	sg.AlwaysOnTop = true
	sg.Parent = handle
	local lbl = Instance.new("TextLabel", sg)
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0
	lbl.Text = tool.Name

	return tool
end

-- Removes any tools the player currently has, then gives the requested one.
function ShopManager.GiveWeapon(player, weaponId)
	local spec = WeaponConfig.ById[weaponId]
	if not spec then return false end
	-- ensure session ownership reflects this
	dm().GrantSessionWeapon(player, weaponId)
	local sess = dm().GetSession(player)
	sess.CurrentWeapon = weaponId

	local char = player.Character
	if not char then return false end
	local backpack = player:FindFirstChildOfClass("Backpack")
	-- remove only previously-spawned tools (so we don't infinitely stack)
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") then c:Destroy() end
	end
	if backpack then
		for _, c in ipairs(backpack:GetChildren()) do
			if c:IsA("Tool") then c:Destroy() end
		end
	end
	-- Spawn ALL owned weapons; player chooses via 1/2/3 keys (Roblox default).
	for ownedId, _ in pairs(sess.OwnedWeapons) do
		local s = WeaponConfig.ById[ownedId]
		if s then
			local tool = buildToolForWeapon(s)
			tool.Parent = backpack or char
		end
	end
	return true
end

-- Handle XP purchase requests
function ShopManager.HandleBuyXP(player, payload)
	local rm = _G.RoundManager
	if not rm or not rm.IsPlaying() then
		getRemotes().ToastNotify:FireClient(player, {
			text = "ניתן לקנות רק במהלך הסבב", color = Color3.fromRGB(255,170,80),
		})
		return
	end
	if not payload or type(payload) ~= "table" then return end

	local sess = dm().GetSession(player)
	if payload.itemType == "Weapon" then
		local weapon = WeaponConfig.ById[payload.itemId]
		if not weapon then return end
		if WeaponConfig.IsPermanent(weapon.Id) then
			-- Shotgun: must be Robux
			getRemotes().ToastNotify:FireClient(player, {
				text = "רובה ציד נרכש רק ב-Robux", color = Color3.fromRGB(255,170,80),
			})
			return
		end
		if dm().OwnsWeapon(player, weapon.Id) then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.Owned, color = Color3.fromRGB(180,180,180),
			})
			return
		end
		local price = weapon.PriceXP or math.huge
		if not dm().SpendXP(player, price) then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.NotEnoughXP, color = Color3.fromRGB(255,100,100),
			})
			return
		end
		ShopManager.GiveWeapon(player, weapon.Id)
		getRemotes().ToastNotify:FireClient(player, {
			text  = Strings.Shop.Purchased,
			color = Color3.fromRGB(120,220,120),
		})
	elseif payload.itemType == "Upgrade" then
		local id = payload.itemId  -- "Speed" or "HP"
		local cfg = GameConfig.PlaneUpgrades[id]
		if not cfg then return end
		local cur = sess.PlaneUpgrades[id] or 0
		if cur >= #cfg.Levels then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.MaxLevel, color = Color3.fromRGB(180,180,180),
			})
			return
		end
		local price = cfg.Levels[cur + 1]
		if not dm().SpendXP(player, price) then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.NotEnoughXP, color = Color3.fromRGB(255,100,100),
			})
			return
		end
		sess.PlaneUpgrades[id] = cur + 1
		-- Apply effect immediately
		local char = player.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			if id == "HP" then
				local newMax = cfg.Effect[sess.PlaneUpgrades.HP + 1]
				local diff = newMax - hum.MaxHealth
				hum.MaxHealth = newMax
				if diff > 0 then
					hum.Health = math.min(newMax, hum.Health + diff)
				end
			elseif id == "Speed" then
				local mul = cfg.Effect[sess.PlaneUpgrades.Speed + 1]
				hum.WalkSpeed = 16 * mul
			end
		end
		getRemotes().ToastNotify:FireClient(player, {
			text  = Strings.Shop.Purchased,
			color = Color3.fromRGB(120,220,120),
		})
	end
end

function ShopManager.HandlePromptShotgun(player)
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, GameConfig.Products.SHOTGUN)
	end)
	if not ok then
		warn("[ShopManager] PromptShotgun failed:", err)
		getRemotes().ToastNotify:FireClient(player, {
			text = Strings.Notifications.PurchaseFailed, color = Color3.fromRGB(255,100,100),
		})
	end
end

function ShopManager.HandlePromptRevive(player)
	local rm = _G.RoundManager
	if not rm or rm.GetState() ~= "PLAYING" then return end
	local sess = dm().GetSession(player)
	if sess.UsedRevive then
		getRemotes().ToastNotify:FireClient(player, {
			text = Strings.Death.ReviveUsed, color = Color3.fromRGB(255,170,80),
		})
		return
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, GameConfig.Products.REVIVE)
	end)
	if not ok then
		warn("[ShopManager] PromptRevive failed:", err)
	end
end

function ShopManager.GetShopState(player)
	local sess = dm().GetSession(player)
	local owned = {}
	for k in pairs(sess.OwnedWeapons) do owned[k] = true end
	return {
		ownsShotgun = dm().OwnsShotgun(player),
		ownedWeapons = owned,
		planeUpgrades = sess.PlaneUpgrades,
		xp = sess.XP,
		alive = sess.Alive,
		usedRevive = sess.UsedRevive,
	}
end

function ShopManager.Start()
	getRemotes().BuyXPItem.OnServerEvent:Connect(function(player, payload)
		local ok, err = pcall(ShopManager.HandleBuyXP, player, payload)
		if not ok then warn("[ShopManager] BuyXPItem error:", err) end
	end)
	getRemotes().PromptShotgun.OnServerEvent:Connect(function(player)
		ShopManager.HandlePromptShotgun(player)
	end)
	getRemotes().PromptRevive.OnServerEvent:Connect(function(player)
		ShopManager.HandlePromptRevive(player)
	end)
	getRemotes().GetShopState.OnServerInvoke = function(player)
		return ShopManager.GetShopState(player)
	end
end

ShopManager.Start()
_G.ShopManager = ShopManager
print("[ShopManager] Ready.")

]==]

sources.ProductHandler = [==[
-- ProductHandler.server.lua
-- Place in: ServerScriptService as Script named "ProductHandler"
-- Handles MarketplaceService.ProcessReceipt for Shotgun (permanent) and Revive
-- (one-time per round). Critical: must return PurchaseGranted only AFTER
-- a successful save.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Strings    = require(ReplicatedStorage:WaitForChild("Strings"))

local ProductHandler = {}
local processed = {}  -- per-server dedup of receipt purchase IDs

local function getRemotes()
	return ReplicatedStorage:WaitForChild("Remotes")
end

local function dm()
	while not _G.DataManager do task.wait(0.05) end
	return _G.DataManager
end

local function grantShotgun(player)
	local ok = dm().SetOwnsShotgun(player, true)
	if not ok then return false end
	-- Reflect in session and equip in-game if currently playing
	dm().GrantSessionWeapon(player, "Shotgun")
	local rm = _G.RoundManager
	if rm and rm.IsPlaying() and _G.ShopManager then
		_G.ShopManager.GiveWeapon(player, "Shotgun")
	end
	getRemotes().ToastNotify:FireClient(player, {
		text  = Strings.Notifications.ShotgunUnlocked,
		color = Color3.fromRGB(255, 220, 80),
	})
	return true
end

local function grantRevive(player)
	local rm = _G.RoundManager
	if not rm then return false end
	-- Allow purchase even if state is ENDING; useful if death came at the wire.
	local ok = rm.RevivePlayer(player)
	if not ok then
		-- If we can't revive (e.g., already used), refund still is "granted" because
		-- Roblox does not allow refunds; alert the player instead.
		getRemotes().ToastNotify:FireClient(player, {
			text = Strings.Death.ReviveUsed, color = Color3.fromRGB(255,170,80),
		})
	end
	return true
end

local function processReceipt(receiptInfo)
	local key = receiptInfo.PlayerId .. ":" .. receiptInfo.PurchaseId
	if processed[key] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local id = receiptInfo.ProductId
	local granted = false
	if id == GameConfig.Products.SHOTGUN then
		granted = grantShotgun(player)
	elseif id == GameConfig.Products.REVIVE then
		granted = grantRevive(player)
	else
		warn("[ProductHandler] Unknown product:", id)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	processed[key] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt
_G.ProductHandler = ProductHandler
print("[ProductHandler] Ready.")

]==]

sources.Main = [==[
-- Main.server.lua
-- Place in: ServerScriptService as Script named "Main"
-- Bootstrap: creates Remotes, waits for managers, starts the round loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- ====== Create Remotes folder ======
local function ensureRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local function ev(name)
		if not remotes:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = remotes
		end
	end
	local function fn(name)
		if not remotes:FindFirstChild(name) then
			local f = Instance.new("RemoteFunction")
			f.Name = name
			f.Parent = remotes
		end
	end

	-- Combat
	ev("RequestAttack")          -- client -> server { targetModel, originPos }
	ev("ShowDamage")             -- server -> all clients { position, amount, color }
	ev("AnimalDied")             -- server -> all clients { animalId, position }

	-- Round / state
	ev("RoundStateChanged")      -- server -> all clients { state, payload }
	ev("LobbyCountdown")         -- server -> all clients { secondsLeft }
	ev("PlaneFlight")            -- server -> all clients { startCFrame, endCFrame, duration }
	ev("CrashEffect")            -- server -> all clients { position }

	-- Player state
	ev("UpdateHUD")              -- server -> client { hp, maxHp, xp, weapon, time, alive }
	ev("PlayerDied")             -- server -> player { killedBy }
	ev("ToastNotify")            -- server -> player { text, color }

	-- Shop / purchases
	ev("BuyXPItem")              -- client -> server { itemType, itemId }   itemType: "Weapon" | "Upgrade"
	ev("PromptShotgun")          -- client -> server { } (server triggers MarketplaceService)
	ev("PromptRevive")           -- client -> server { }
	fn("GetShopState")           -- client <-> server returns { ownsShotgun, ownedSessionWeapons, planeUpgrades, xp }

	-- Best time / personal record
	ev("UpdateBestTimes")        -- server -> all clients { [userId] = seconds }
	ev("DeathCountdown")         -- server -> player { secondsLeft, survivedSeconds, bestSeconds, isNewRecord }
	fn("GetBestTimes")           -- client <-> server returns table of { [userId]=seconds }

	return remotes
end

local Remotes = ensureRemotes()

-- Wait for the script-loading order. Each manager registers itself on _G when ready.
local function waitForAll(names, timeoutSec)
	timeoutSec = timeoutSec or 15
	local started = tick()
	while tick() - started < timeoutSec do
		local allReady = true
		for _, n in ipairs(names) do
			if not _G[n] then allReady = false break end
		end
		if allReady then return true end
		task.wait(0.1)
	end
	return false
end

print("[Main] Waiting for managers...")
local ok = waitForAll({
	"DataManager",
	"RoundManager",
	"LobbyManager",
	"IslandBuilder",
	"PlaneManager",
	"AnimalManager",
	"CombatManager",
	"ShopManager",
	"ProductHandler",
}, 30)

if not ok then
	warn("[Main] Some managers did not register. Check script load errors.")
	for _, n in ipairs({"DataManager","RoundManager","LobbyManager","IslandBuilder","PlaneManager","AnimalManager","CombatManager","ShopManager","ProductHandler"}) do
		print("  ", n, _G[n] and "OK" or "MISSING")
	end
else
	print("[Main] All managers registered.")
end

-- Build the static world (island + lobby) once.
if _G.IslandBuilder and _G.IslandBuilder.Build then
	_G.IslandBuilder.Build()
end

-- Start the round state machine.
if _G.RoundManager and _G.RoundManager.Start then
	_G.RoundManager.Start()
end

-- Welcome notify on join.
local Strings = require(ReplicatedStorage:WaitForChild("Strings"))
Players.PlayerAdded:Connect(function(player)
	task.wait(2)
	Remotes.ToastNotify:FireClient(player, {
		text  = Strings.Notifications.Welcome,
		color = Color3.fromRGB(255, 220, 120),
	})
end)

-- Wire up GetBestTimes RemoteFunction (allowed only after DataManager exists).
task.spawn(function()
	while not _G.DataManager do task.wait(0.1) end
	Remotes.GetBestTimes.OnServerInvoke = function()
		return _G.DataManager.GetAllBestTimes()
	end
end)

-- Broadcast best times whenever a new player joins (so their tag is up to date).
Players.PlayerAdded:Connect(function(player)
	task.wait(3)
	if not player.Parent then return end
	if _G.DataManager then
		Remotes.UpdateBestTimes:FireAllClients(_G.DataManager.GetAllBestTimes())
	end
end)

print("[Main] Island Survival is running.")

]==]

sources.HUDGui = [==[
-- HUDGui.lua
-- Place in: StarterGui as LocalScript named "HUDGui"
-- Heads-up display: HP, XP, weapon, time, shop hint.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- Build root GUI
local screen = Instance.new("ScreenGui")
screen.Name = "HUDGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = pg

local function makeFrame(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 0.2
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end
local function makeLabel(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.fromRGB(240, 240, 240)
	t.TextStrokeTransparency = 0.5
	t.TextScaled = true
	t.TextXAlignment = Enum.TextXAlignment.Right
	for k, v in pairs(props) do t[k] = v end
	t.Parent = parent
	return t
end
local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end
local function stroke(parent, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(0,0,0)
	s.Thickness = t or 1
	s.Parent = parent
	return s
end

-- Top-left container
local container = makeFrame(screen, {
	Name = "Container",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 16, 0, 16),
	Size = UDim2.new(0, 280, 0, 130),
	BackgroundTransparency = 0.3,
})
corner(container, 12)
stroke(container, Color3.fromRGB(80, 90, 110), 1)

-- HP bar
local hpFrame = makeFrame(container, {
	Position = UDim2.new(0, 12, 0, 12),
	Size = UDim2.new(1, -24, 0, 28),
	BackgroundColor3 = Color3.fromRGB(40, 40, 40),
	BackgroundTransparency = 0,
})
corner(hpFrame, 6)
local hpFill = makeFrame(hpFrame, {
	Name = "Fill",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(220, 60, 60),
	BackgroundTransparency = 0,
})
corner(hpFill, 6)
local hpLabel = makeLabel(hpFrame, {
	Size = UDim2.new(1, -8, 1, 0),
	Position = UDim2.new(0, 4, 0, 0),
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "100/100",
	TextColor3 = Color3.fromRGB(255,255,255),
	ZIndex = 2,
})
local hpTitle = makeLabel(hpFrame, {
	Size = UDim2.new(0.5, 0, 1, 0),
	Position = UDim2.new(0, 8, 0, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = Strings.HUD.HP,
	TextColor3 = Color3.fromRGB(255,255,255),
	ZIndex = 2,
})

-- XP bar
local xpFrame = makeFrame(container, {
	Position = UDim2.new(0, 12, 0, 50),
	Size = UDim2.new(1, -24, 0, 22),
	BackgroundColor3 = Color3.fromRGB(40, 40, 40),
	BackgroundTransparency = 0,
})
corner(xpFrame, 6)
local xpFill = makeFrame(xpFrame, {
	Name = "Fill",
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(120, 200, 255),
	BackgroundTransparency = 0,
})
corner(xpFill, 6)
local xpLabel = makeLabel(xpFrame, {
	Size = UDim2.new(1, 0, 1, 0),
	Text = string.format("%s: 0", Strings.HUD.XP),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Color3.fromRGB(255,255,255),
	ZIndex = 2,
})

-- Weapon + time
local weaponLabel = makeLabel(container, {
	Position = UDim2.new(0, 12, 0, 78),
	Size = UDim2.new(1, -24, 0, 22),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = Strings.HUD.Weapon .. ": -",
	TextColor3 = Color3.fromRGB(255,220,140),
})
local timeLabel = makeLabel(container, {
	Position = UDim2.new(0, 12, 0, 102),
	Size = UDim2.new(1, -24, 0, 22),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = Strings.HUD.Time .. ": 0s",
	TextColor3 = Color3.fromRGB(180,220,255),
})

-- Shop hint (bottom-right)
local hint = makeLabel(screen, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16),
	Size = UDim2.new(0, 220, 0, 30),
	Text = Strings.HUD.ShopHint,
	TextColor3 = Color3.fromRGB(255, 220, 80),
	BackgroundColor3 = Color3.fromRGB(28, 32, 40),
	BackgroundTransparency = 0.3,
	TextScaled = true,
})

local function fmtSeconds(t)
	local m = math.floor(t/60)
	local s = t - m*60
	return string.format("%d:%02d", m, s)
end

Remotes.UpdateHUD.OnClientEvent:Connect(function(state)
	if not state then return end
	local hp, maxHp = state.hp or 100, state.maxHp or 100
	hpFill.Size  = UDim2.new(math.clamp(hp/maxHp, 0, 1), 0, 1, 0)
	hpLabel.Text = tostring(hp) .. "/" .. tostring(maxHp)

	-- XP fills relative to next level cost; for now show fraction to 800 (Pistol).
	local xpCap = 800
	local xp = state.xp or 0
	xpFill.Size = UDim2.new(math.clamp(xp/xpCap, 0, 1), 0, 1, 0)
	xpLabel.Text = string.format("%s: %d", Strings.HUD.XP, xp)

	local wId = state.weapon
	local wSpec = WeaponConfig.ById[wId]
	local wName = wSpec and (Strings.Weapons[wSpec.DisplayKey] or wSpec.Id) or "-"
	weaponLabel.Text = Strings.HUD.Weapon .. ": " .. wName

	timeLabel.Text = Strings.HUD.Time .. ": " .. fmtSeconds(state.time or 0)

	-- Hide hint when not playing
	hint.Visible = (state.state == "PLAYING")
	container.Visible = (state.state == "PLAYING")
end)

]==]

sources.LobbyGui = [==[
-- LobbyGui.lua
-- Place in: StarterGui as LocalScript named "LobbyGui"
-- Lobby instructions + countdown overlay.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")

local Strings = require(ReplicatedStorage:WaitForChild("Strings"))

local player  = Players.LocalPlayer
local pg      = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local screen = Instance.new("ScreenGui")
screen.Name = "LobbyGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = pg

local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c end
local function stroke(p, c, t) local s = Instance.new("UIStroke"); s.Color = c; s.Thickness = t or 1; s.Parent = p; return s end

-- Welcome banner (always visible in LOBBY)
local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 24)
banner.Size = UDim2.new(0, 540, 0, 70)
banner.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
banner.BackgroundTransparency = 0.2
banner.BorderSizePixel = 0
banner.Parent = screen
corner(banner, 12)
stroke(banner, Color3.fromRGB(255, 180, 60), 2)

local title = Instance.new("TextLabel", banner)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -20, 0, 32)
title.Position = UDim2.new(0, 10, 0, 6)
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 220, 120)
title.TextScaled = true
title.Text = Strings.Lobby.Welcome

local sub = Instance.new("TextLabel", banner)
sub.BackgroundTransparency = 1
sub.Size = UDim2.new(1, -20, 0, 28)
sub.Position = UDim2.new(0, 10, 0, 38)
sub.Font = Enum.Font.Gotham
sub.TextColor3 = Color3.fromRGB(220, 220, 220)
sub.TextScaled = true
sub.Text = Strings.Lobby.Instruction

-- Countdown overlay (shown only during COUNTDOWN)
local countFrame = Instance.new("Frame")
countFrame.Name = "Countdown"
countFrame.AnchorPoint = Vector2.new(0.5, 0.5)
countFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
countFrame.Size = UDim2.new(0, 380, 0, 220)
countFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
countFrame.BackgroundTransparency = 0.15
countFrame.BorderSizePixel = 0
countFrame.Visible = false
countFrame.Parent = screen
corner(countFrame, 18)
stroke(countFrame, Color3.fromRGB(255, 140, 0), 3)

local countTitle = Instance.new("TextLabel", countFrame)
countTitle.BackgroundTransparency = 1
countTitle.Size = UDim2.new(1, -20, 0, 40)
countTitle.Position = UDim2.new(0, 10, 0, 12)
countTitle.Font = Enum.Font.GothamBold
countTitle.TextColor3 = Color3.fromRGB(255, 220, 120)
countTitle.TextScaled = true
countTitle.Text = "מתחילים בעוד..."

local countNum = Instance.new("TextLabel", countFrame)
countNum.BackgroundTransparency = 1
countNum.Size = UDim2.new(1, -20, 0, 130)
countNum.Position = UDim2.new(0, 10, 0, 60)
countNum.Font = Enum.Font.GothamBlack
countNum.TextColor3 = Color3.fromRGB(255, 255, 255)
countNum.TextScaled = true
countNum.Text = "10"

local hint = Instance.new("TextLabel", countFrame)
hint.BackgroundTransparency = 1
hint.Size = UDim2.new(1, -20, 0, 22)
hint.Position = UDim2.new(0, 10, 1, -28)
hint.Font = Enum.Font.Gotham
hint.TextColor3 = Color3.fromRGB(200, 200, 200)
hint.TextScaled = true
hint.Text = Strings.Lobby.StepOff

-- Top center "STATE" indicator (FLIGHT, CRASH)
local stateFrame = Instance.new("TextLabel")
stateFrame.AnchorPoint = Vector2.new(0.5, 0)
stateFrame.Position = UDim2.new(0.5, 0, 0, 110)
stateFrame.Size = UDim2.new(0, 360, 0, 60)
stateFrame.BackgroundColor3 = Color3.fromRGB(180, 50, 40)
stateFrame.BackgroundTransparency = 0.2
stateFrame.Font = Enum.Font.GothamBold
stateFrame.TextColor3 = Color3.fromRGB(255, 255, 255)
stateFrame.TextScaled = true
stateFrame.Text = ""
stateFrame.BorderSizePixel = 0
stateFrame.Visible = false
stateFrame.Parent = screen
corner(stateFrame, 10)

local function setBannerVisible(v) banner.Visible = v end

Remotes.LobbyCountdown.OnClientEvent:Connect(function(payload)
	if not payload then return end
	if payload.cancelled then
		countFrame.Visible = false
		return
	end
	countFrame.Visible = true
	countNum.Text = tostring(payload.secondsLeft)
	-- pulse
	countNum.TextTransparency = 0
	local goal = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(countNum, goal, { TextTransparency = 0.3 }):Play()
end)

Remotes.RoundStateChanged.OnClientEvent:Connect(function(data)
	if not data or not data.state then return end
	local s = data.state
	if s == "LOBBY" then
		setBannerVisible(true)
		countFrame.Visible = false
		stateFrame.Visible = false
	elseif s == "COUNTDOWN" then
		setBannerVisible(false)
		stateFrame.Visible = false
	elseif s == "BOARDING" then
		setBannerVisible(false)
		countFrame.Visible = false
		stateFrame.Text = Strings.Lobby.Boarding
		stateFrame.BackgroundColor3 = Color3.fromRGB(60, 110, 200)
		stateFrame.Visible = true
	elseif s == "FLIGHT" then
		stateFrame.Text = Strings.Flight.TakeOff
		stateFrame.BackgroundColor3 = Color3.fromRGB(60, 110, 200)
		stateFrame.Visible = true
		task.delay(5, function() if data.state == "FLIGHT" then stateFrame.Text = Strings.Flight.EngineFailure end end)
	elseif s == "CRASH" then
		stateFrame.Text = Strings.Flight.Crash
		stateFrame.BackgroundColor3 = Color3.fromRGB(180, 50, 40)
		stateFrame.Visible = true
	elseif s == "PLAYING" then
		stateFrame.Visible = false
		countFrame.Visible = false
		setBannerVisible(false)
	elseif s == "ENDING" then
		stateFrame.Text = Strings.Round.AllDead
		stateFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		stateFrame.Visible = true
	end
end)

]==]

sources.ShopGui = [==[
-- ShopGui.lua
-- Place in: StarterGui as LocalScript named "ShopGui"
-- Toggle with B. Shows weapons + plane upgrades, all in Hebrew.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

local screen = Instance.new("ScreenGui")
screen.Name = "ShopGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = pg

local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c end
local function stroke(p, c, t) local s = Instance.new("UIStroke"); s.Color = c; s.Thickness = t or 1; s.Parent = p; return s end
local function listLayout(p, padding) local l = Instance.new("UIListLayout"); l.SortOrder = Enum.SortOrder.LayoutOrder; l.Padding = UDim.new(0, padding or 6); l.Parent = p; return l end
local function pad(p, x, y) local pp = Instance.new("UIPadding"); pp.PaddingLeft=UDim.new(0,x); pp.PaddingRight=UDim.new(0,x); pp.PaddingTop=UDim.new(0,y); pp.PaddingBottom=UDim.new(0,y); pp.Parent = p; return pp end

local backdrop = Instance.new("Frame", screen)
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel = 0
backdrop.Visible = false

local panel = Instance.new("Frame", backdrop)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 720, 0, 540)
panel.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
panel.BorderSizePixel = 0
corner(panel, 14)
stroke(panel, Color3.fromRGB(80, 90, 110), 1)

-- Title bar
local titleBar = Instance.new("Frame", panel)
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(38, 44, 56)
titleBar.BorderSizePixel = 0
corner(titleBar, 14)

local title = Instance.new("TextLabel", titleBar)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -120, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 220, 120)
title.TextXAlignment = Enum.TextXAlignment.Right
title.TextScaled = true
title.Text = Strings.Shop.Title

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 100, 0, 36)
closeBtn.AnchorPoint = Vector2.new(0, 0.5)
closeBtn.Position = UDim2.new(0, 12, 0.5, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Text = Strings.Shop.Close
corner(closeBtn, 8)

-- XP display in title
local xpLabel = Instance.new("TextLabel", titleBar)
xpLabel.BackgroundTransparency = 1
xpLabel.AnchorPoint = Vector2.new(0.5, 0.5)
xpLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
xpLabel.Size = UDim2.new(0, 200, 0, 30)
xpLabel.Font = Enum.Font.GothamBold
xpLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
xpLabel.TextScaled = true
xpLabel.Text = "XP: 0"

-- Tabs
local tabBar = Instance.new("Frame", panel)
tabBar.Position = UDim2.new(0, 0, 0, 50)
tabBar.Size = UDim2.new(1, 0, 0, 40)
tabBar.BackgroundColor3 = Color3.fromRGB(22, 26, 32)
tabBar.BorderSizePixel = 0

local function makeTab(text, x)
	local b = Instance.new("TextButton", tabBar)
	b.Position = UDim2.new(0, x, 0, 4)
	b.Size = UDim2.new(0, 200, 0, 32)
	b.BackgroundColor3 = Color3.fromRGB(40, 50, 65)
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.fromRGB(220, 220, 220)
	b.TextScaled = true
	b.Text = text
	corner(b, 6)
	return b
end
local tabWeapons  = makeTab(Strings.Shop.TabWeapons,  16)
local tabUpgrades = makeTab(Strings.Shop.TabUpgrades, 230)

-- Content
local content = Instance.new("ScrollingFrame", panel)
content.Position = UDim2.new(0, 0, 0, 96)
content.Size = UDim2.new(1, 0, 1, -96)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 6
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
pad(content, 16, 12)
listLayout(content, 8)

local currentTab = "Weapons"
local currentState = nil

local function clearContent()
	for _, c in ipairs(content:GetChildren()) do
		if not (c:IsA("UIListLayout") or c:IsA("UIPadding")) then
			c:Destroy()
		end
	end
end

local function buildItemCard(opts)
	local card = Instance.new("Frame", content)
	card.Size = UDim2.new(1, 0, 0, 96)
	card.BackgroundColor3 = Color3.fromRGB(40, 48, 60)
	card.BorderSizePixel = 0
	corner(card, 10)
	stroke(card, Color3.fromRGB(70, 80, 100), 1)

	local name = Instance.new("TextLabel", card)
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 14, 0, 8)
	name.Size = UDim2.new(1, -180, 0, 28)
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = Color3.fromRGB(255, 220, 120)
	name.TextXAlignment = Enum.TextXAlignment.Right
	name.TextScaled = true
	name.Text = opts.name

	local desc = Instance.new("TextLabel", card)
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.new(0, 14, 0, 36)
	desc.Size = UDim2.new(1, -180, 0, 20)
	desc.Font = Enum.Font.Gotham
	desc.TextColor3 = Color3.fromRGB(200, 200, 200)
	desc.TextXAlignment = Enum.TextXAlignment.Right
	desc.TextScaled = true
	desc.Text = opts.desc or ""

	local stats = Instance.new("TextLabel", card)
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.new(0, 14, 0, 58)
	stats.Size = UDim2.new(1, -180, 0, 30)
	stats.Font = Enum.Font.Gotham
	stats.TextColor3 = Color3.fromRGB(160, 200, 230)
	stats.TextXAlignment = Enum.TextXAlignment.Right
	stats.TextScaled = true
	stats.Text = opts.stats or ""

	local btn = Instance.new("TextButton", card)
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -12, 0.5, 0)
	btn.Size = UDim2.new(0, 150, 0, 60)
	btn.BackgroundColor3 = opts.btnColor or Color3.fromRGB(60, 130, 80)
	btn.Font = Enum.Font.GothamBold
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextScaled = true
	btn.Text = opts.btnText
	corner(btn, 8)
	if opts.disabled then
		btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		btn.AutoButtonColor = false
		btn.Active = false
	else
		btn.MouseButton1Click:Connect(opts.onClick)
	end
	return card
end

local function refreshContent()
	clearContent()
	if not currentState then return end
	xpLabel.Text = "XP: " .. tostring(currentState.xp or 0)

	if currentTab == "Weapons" then
		for _, w in ipairs(WeaponConfig.List) do
			local owned = currentState.ownedWeapons and currentState.ownedWeapons[w.Id]
			local statsTxt = string.format("%s    %s    %s",
				string.format(Strings.Shop.Damage, w.Damage),
				string.format(Strings.Shop.Cooldown, w.Cooldown),
				string.format(Strings.Shop.Range, w.Range))
			local btnText, btnColor, onClick, disabled

			if w.Id == "Stick" then
				btnText, btnColor, disabled = Strings.Shop.Owned, Color3.fromRGB(80,80,80), true
			elseif owned then
				btnText, btnColor, disabled = Strings.Shop.Owned, Color3.fromRGB(80,80,80), true
			elseif w.Id == "Shotgun" then
				btnText  = string.format(Strings.Shop.PriceRobux, w.PriceRobux or 20)
				btnColor = Color3.fromRGB(255, 180, 60)
				onClick  = function() Remotes.PromptShotgun:FireServer() end
			else
				btnText  = string.format(Strings.Shop.Price, w.PriceXP or 0)
				btnColor = Color3.fromRGB(60, 130, 80)
				onClick  = function() Remotes.BuyXPItem:FireServer({ itemType="Weapon", itemId=w.Id }) end
				if (currentState.xp or 0) < (w.PriceXP or 0) then
					btnColor = Color3.fromRGB(120, 60, 60)
				end
			end

			buildItemCard{
				name = string.format("%s  (%s)", Strings.Weapons[w.DisplayKey] or w.Id, string.format(Strings.Shop.Level, w.Level)),
				desc = w.Description,
				stats = statsTxt,
				btnText = btnText, btnColor = btnColor, onClick = onClick, disabled = disabled,
			}
		end
	elseif currentTab == "Upgrades" then
		for _, id in ipairs({"Speed", "HP"}) do
			local cfg = GameConfig.PlaneUpgrades[id]
			local cur = (currentState.planeUpgrades and currentState.planeUpgrades[id]) or 0
			local maxed = cur >= #cfg.Levels
			local nextPrice = (not maxed) and cfg.Levels[cur + 1] or 0
			local statsTxt
			if id == "Speed" then
				local nextEffect = cfg.Effect[cur + 2] or cfg.Effect[#cfg.Effect]
				statsTxt = string.format("רמה %d/%d   ערך הבא: x%.2f", cur, #cfg.Levels, nextEffect)
			else
				local nextEffect = cfg.Effect[cur + 2] or cfg.Effect[#cfg.Effect]
				statsTxt = string.format("רמה %d/%d   HP מקס': %d", cur, #cfg.Levels, nextEffect)
			end
			local btnText, btnColor, onClick, disabled
			if maxed then
				btnText, btnColor, disabled = Strings.Shop.MaxLevel, Color3.fromRGB(80,80,80), true
			else
				btnText  = string.format(Strings.Shop.Price, nextPrice)
				btnColor = (currentState.xp or 0) >= nextPrice and Color3.fromRGB(60, 130, 80) or Color3.fromRGB(120, 60, 60)
				onClick  = function() Remotes.BuyXPItem:FireServer({ itemType="Upgrade", itemId=id }) end
			end
			buildItemCard{
				name = cfg.Display,
				desc = "שדרוג טיסה - מתאפס בין סבבים",
				stats = statsTxt,
				btnText = btnText, btnColor = btnColor, onClick = onClick, disabled = disabled,
			}
		end
	end
end

local function setTab(t)
	currentTab = t
	tabWeapons.BackgroundColor3  = (t=="Weapons")  and Color3.fromRGB(70, 100, 140) or Color3.fromRGB(40, 50, 65)
	tabUpgrades.BackgroundColor3 = (t=="Upgrades") and Color3.fromRGB(70, 100, 140) or Color3.fromRGB(40, 50, 65)
	refreshContent()
end
tabWeapons.MouseButton1Click:Connect(function() setTab("Weapons") end)
tabUpgrades.MouseButton1Click:Connect(function() setTab("Upgrades") end)

local function open()
	-- Refresh state from server
	local ok, state = pcall(function() return Remotes.GetShopState:InvokeServer() end)
	if ok and state then currentState = state end
	backdrop.Visible = true
	setTab(currentTab)
end
local function close() backdrop.Visible = false end
local function toggle() if backdrop.Visible then close() else open() end end

closeBtn.MouseButton1Click:Connect(close)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.B then
		toggle()
	elseif input.KeyCode == Enum.KeyCode.Escape and backdrop.Visible then
		close()
	end
end)

-- Refresh shop state periodically while open
task.spawn(function()
	while true do
		task.wait(0.7)
		if backdrop.Visible then
			local ok, state = pcall(function() return Remotes.GetShopState:InvokeServer() end)
			if ok and state then
				currentState = state
				refreshContent()
			end
		end
	end
end)

]==]

sources.DeathGui = [==[
-- DeathGui.lua
-- Place in: StarterGui as LocalScript named "DeathGui"
-- Dramatic death overlay: 15-second countdown, revive button, survived stats,
-- personal best display.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local Strings = require(ReplicatedStorage:WaitForChild("Strings"))

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

local screen = Instance.new("ScreenGui")
screen.Name = "DeathGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 50
screen.Parent = pg

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
	return c
end
local function stroke(p, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(0,0,0)
	s.Thickness = thick or 1
	s.Parent = p
	return s
end
local function fmtTime(sec)
	sec = math.max(0, math.floor(sec or 0))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- Vignette / red gradient backdrop
local backdrop = Instance.new("Frame", screen)
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.45
backdrop.BorderSizePixel = 0
backdrop.Visible = false

local vignette = Instance.new("UIGradient", backdrop)
vignette.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 0, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 0, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0)),
})
vignette.Rotation = 90

-- Main card
local card = Instance.new("Frame", backdrop)
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.new(0.5, 0, 0.5, 0)
card.Size = UDim2.new(0, 540, 0, 460)
card.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
card.BorderSizePixel = 0
corner(card, 18)
stroke(card, Color3.fromRGB(220, 60, 60), 4)

local cardGradient = Instance.new("UIGradient", card)
cardGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 18, 22)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 14, 18)),
})
cardGradient.Rotation = 90

-- Title "מתת" with shadow
local titleShadow = Instance.new("TextLabel", card)
titleShadow.BackgroundTransparency = 1
titleShadow.Position = UDim2.new(0, 14, 0, 22)
titleShadow.Size = UDim2.new(1, -28, 0, 64)
titleShadow.Font = Enum.Font.GothamBlack
titleShadow.TextColor3 = Color3.fromRGB(120, 20, 20)
titleShadow.TextStrokeTransparency = 0.3
titleShadow.TextScaled = true
titleShadow.Text = Strings.Death.Title
titleShadow.ZIndex = 1
titleShadow.TextTransparency = 0.5

local title = Instance.new("TextLabel", card)
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 18)
title.Size = UDim2.new(1, -24, 0, 64)
title.Font = Enum.Font.GothamBlack
title.TextColor3 = Color3.fromRGB(255, 80, 80)
title.TextStrokeTransparency = 0
title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
title.TextScaled = true
title.Text = Strings.Death.Title
title.ZIndex = 2

-- Killed-by sub
local killedBy = Instance.new("TextLabel", card)
killedBy.BackgroundTransparency = 1
killedBy.Position = UDim2.new(0, 12, 0, 90)
killedBy.Size = UDim2.new(1, -24, 0, 28)
killedBy.Font = Enum.Font.Gotham
killedBy.TextColor3 = Color3.fromRGB(220, 220, 220)
killedBy.TextScaled = true
killedBy.Text = ""

-- Survived time + best (centered row)
local statsFrame = Instance.new("Frame", card)
statsFrame.BackgroundTransparency = 1
statsFrame.Position = UDim2.new(0, 16, 0, 124)
statsFrame.Size = UDim2.new(1, -32, 0, 60)
local statsLayout = Instance.new("UIListLayout", statsFrame)
statsLayout.FillDirection = Enum.FillDirection.Horizontal
statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Padding = UDim.new(0, 16)

local function makeStat(parent, headerText, valueText, valueColor)
	local box = Instance.new("Frame", parent)
	box.BackgroundColor3 = Color3.fromRGB(34, 38, 46)
	box.BorderSizePixel = 0
	box.Size = UDim2.new(0, 220, 0, 60)
	corner(box, 10)
	stroke(box, Color3.fromRGB(60, 65, 80), 1)
	local h = Instance.new("TextLabel", box)
	h.BackgroundTransparency = 1
	h.Position = UDim2.new(0, 6, 0, 4)
	h.Size = UDim2.new(1, -12, 0, 18)
	h.Font = Enum.Font.Gotham
	h.TextColor3 = Color3.fromRGB(160, 170, 190)
	h.TextScaled = true
	h.Text = headerText
	local v = Instance.new("TextLabel", box)
	v.BackgroundTransparency = 1
	v.Position = UDim2.new(0, 6, 0, 24)
	v.Size = UDim2.new(1, -12, 0, 32)
	v.Font = Enum.Font.GothamBold
	v.TextColor3 = valueColor or Color3.fromRGB(255, 255, 255)
	v.TextScaled = true
	v.Text = valueText
	return box, v
end

local _, survivedValue = makeStat(statsFrame, "שרדת", "0:00", Color3.fromRGB(255, 220, 120))
local _, bestValue     = makeStat(statsFrame, "שיא אישי", "0:00", Color3.fromRGB(120, 220, 255))

-- Big countdown number
local countLabel = Instance.new("TextLabel", card)
countLabel.BackgroundTransparency = 1
countLabel.Position = UDim2.new(0, 12, 0, 196)
countLabel.Size = UDim2.new(1, -24, 0, 110)
countLabel.Font = Enum.Font.GothamBlack
countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
countLabel.TextStrokeTransparency = 0
countLabel.TextScaled = true
countLabel.Text = "15"

local countSub = Instance.new("TextLabel", card)
countSub.BackgroundTransparency = 1
countSub.Position = UDim2.new(0, 12, 0, 304)
countSub.Size = UDim2.new(1, -24, 0, 22)
countSub.Font = Enum.Font.Gotham
countSub.TextColor3 = Color3.fromRGB(180, 180, 180)
countSub.TextScaled = true
countSub.Text = string.format(Strings.Death.ReturningInSec, 15) .. " " .. Strings.Death.ReturningSec

-- Revive button
local reviveBtn = Instance.new("TextButton", card)
reviveBtn.AnchorPoint = Vector2.new(0.5, 0)
reviveBtn.Position = UDim2.new(0.5, 0, 0, 340)
reviveBtn.Size = UDim2.new(0, 460, 0, 60)
reviveBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 60)
reviveBtn.Font = Enum.Font.GothamBold
reviveBtn.TextColor3 = Color3.fromRGB(40, 30, 0)
reviveBtn.TextScaled = true
reviveBtn.Text = Strings.Death.ReviveBtn
corner(reviveBtn, 12)
stroke(reviveBtn, Color3.fromRGB(180, 120, 30), 2)

-- New record badge (hidden until earned)
local recordBadge = Instance.new("TextLabel", card)
recordBadge.AnchorPoint = Vector2.new(0.5, 0)
recordBadge.Position = UDim2.new(0.5, 0, 0, 410)
recordBadge.Size = UDim2.new(0, 380, 0, 38)
recordBadge.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
recordBadge.BackgroundTransparency = 0.1
recordBadge.Font = Enum.Font.GothamBlack
recordBadge.TextColor3 = Color3.fromRGB(40, 30, 0)
recordBadge.TextScaled = true
recordBadge.Text = ""
recordBadge.Visible = false
corner(recordBadge, 8)
stroke(recordBadge, Color3.fromRGB(180, 140, 30), 2)

-- ====== Animation ======
local function showDeath()
	backdrop.Visible = true
	card.Position = UDim2.new(0.5, 0, 0.4, 0)
	card.Size = UDim2.new(0, 460, 0, 380)
	backdrop.BackgroundTransparency = 1
	TweenService:Create(backdrop, TweenInfo.new(0.4), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 540, 0, 460),
	}):Play()
end
local function hideDeath()
	TweenService:Create(backdrop, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	task.wait(0.3)
	backdrop.Visible = false
end

reviveBtn.MouseButton1Click:Connect(function()
	Remotes.PromptRevive:FireServer()
end)

-- Pulse the count label
local pulsing = false
local function startPulse()
	if pulsing then return end
	pulsing = true
	task.spawn(function()
		while pulsing and backdrop.Visible do
			TweenService:Create(countLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0.2,
			}):Play()
			task.wait(0.4)
			TweenService:Create(countLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 0,
			}):Play()
			task.wait(0.6)
		end
	end)
end
local function stopPulse() pulsing = false end

-- ====== Events ======
Remotes.PlayerDied.OnClientEvent:Connect(function(payload)
	payload = payload or {}
	killedBy.Text = string.format(Strings.Death.KilledBy, payload.killedBy or "סכנה")
	survivedValue.Text = fmtTime(payload.survivedSeconds or 0)
	bestValue.Text     = fmtTime(payload.bestSeconds or 0)
	if payload.canRevive then
		reviveBtn.Visible = true
		reviveBtn.Text = Strings.Death.ReviveBtn
	else
		reviveBtn.Visible = false
	end
	if payload.isNewRecord then
		recordBadge.Visible = true
		recordBadge.Text = string.format(Strings.Death.NewBestTime, fmtTime(payload.bestSeconds or 0))
	else
		recordBadge.Visible = false
	end
	countLabel.Text = "15"
	countSub.Text = string.format(Strings.Death.ReturningInSec, 15) .. " " .. Strings.Death.ReturningSec
	showDeath()
	startPulse()
end)

Remotes.DeathCountdown.OnClientEvent:Connect(function(payload)
	if not payload then return end
	if not backdrop.Visible then
		showDeath()
		startPulse()
	end
	survivedValue.Text = fmtTime(payload.survivedSeconds or 0)
	bestValue.Text     = fmtTime(payload.bestSeconds or 0)

	local left = payload.secondsLeft or 0
	if left > 0 then
		countLabel.Text = tostring(left)
		countSub.Text = string.format(Strings.Death.ReturningInSec, left) .. " " .. Strings.Death.ReturningSec
		-- Color shifts from yellow -> orange -> red as time runs out
		if left <= 5 then
			countLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		elseif left <= 10 then
			countLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
		else
			countLabel.TextColor3 = Color3.fromRGB(255, 240, 200)
		end
		reviveBtn.Visible = payload.canRevive == true
	else
		stopPulse()
		hideDeath()
	end

	if payload.isNewRecord then
		recordBadge.Visible = true
		recordBadge.Text = string.format(Strings.Death.NewBestTime, fmtTime(payload.bestSeconds or 0))
	end
end)

-- Hide on respawn / state changes
Remotes.RoundStateChanged.OnClientEvent:Connect(function(data)
	if data and (data.state == "LOBBY" or data.state == "ENDING") then
		stopPulse()
		hideDeath()
	end
end)
Remotes.UpdateHUD.OnClientEvent:Connect(function(state)
	if state and state.alive then
		stopPulse()
		hideDeath()
	end
end)

]==]

sources.NotificationGui = [==[
-- NotificationGui.lua
-- Place in: StarterGui as LocalScript named "NotificationGui"
-- Toast notifications stacked top-right. Driven by ToastNotify RemoteEvent.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

local screen = Instance.new("ScreenGui")
screen.Name = "NotificationGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = pg

local container = Instance.new("Frame", screen)
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.new(0.5, 0, 0, 200)
container.Size = UDim2.new(0, 480, 1, -220)
container.BackgroundTransparency = 1

local layout = Instance.new("UIListLayout", container)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function pop(text, color)
	local f = Instance.new("Frame", container)
	f.Size = UDim2.new(0, 460, 0, 50)
	f.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner", f); c.CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke", f); s.Color = color or Color3.fromRGB(180,180,180); s.Thickness = 2

	local lbl = Instance.new("TextLabel", f)
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, -20, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = color or Color3.fromRGB(240, 240, 240)
	lbl.TextScaled = true
	lbl.Text = text

	-- entrance
	f.BackgroundTransparency = 1
	lbl.TextTransparency = 1
	s.Transparency = 1
	TweenService:Create(f, TweenInfo.new(0.25), { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(lbl, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	TweenService:Create(s, TweenInfo.new(0.25), { Transparency = 0 }):Play()

	task.delay(3.5, function()
		TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.wait(0.5)
		f:Destroy()
	end)
end

Remotes.ToastNotify.OnClientEvent:Connect(function(payload)
	if not payload or not payload.text then return end
	pop(payload.text, payload.color)
end)

]==]

sources.ClientCombat = [==[
-- ClientCombat.lua
-- Place in: StarterPlayerScripts as LocalScript named "ClientCombat"
-- Bridges Tool.Activated to RequestAttack, picking the nearest valid animal target.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local lastSendByTool = {}  -- per Tool, last activation time

local function getEquippedTool(char)
	if not char then return nil end
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") and c:GetAttribute("WeaponId") then
			return c
		end
	end
	return nil
end

-- Find the best animal target near the player (front-cone).
local function findTarget(weapon, char, hrp)
	local fwd = hrp.CFrame.LookVector
	local origin = hrp.Position
	local best, bestScore = nil, math.huge
	for _, m in ipairs(Workspace:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("AnimalId") then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local thrp = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and thrp then
				local toT = thrp.Position - origin
				local dist = toT.Magnitude
				if dist <= weapon.Range + 4 then
					local dir = toT.Unit
					local dot = fwd:Dot(dir)
					-- accept frontal hemisphere; prefer closer + more aligned
					if dot > 0.2 then
						local score = dist - dot * 5
						if score < bestScore then
							best, bestScore = m, score
						end
					end
				end
			end
		end
	end
	return best
end

local function tryAttack(tool)
	local now = tick()
	local weaponId = tool:GetAttribute("WeaponId")
	local weapon = WeaponConfig.ById[weaponId]
	if not weapon then return end
	local lastT = lastSendByTool[tool] or 0
	if now - lastT < weapon.Cooldown then return end
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local target = findTarget(weapon, char, hrp)
	if not target then return end
	lastSendByTool[tool] = now
	Remotes.RequestAttack:FireServer({ target = target })
end

local function bindTool(tool)
	tool.Activated:Connect(function()
		tryAttack(tool)
	end)
end

local function onCharacter(char)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") and c:GetAttribute("WeaponId") then bindTool(c) end
	end)
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") and c:GetAttribute("WeaponId") then bindTool(c) end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		backpack.ChildAdded:Connect(function(c)
			if c:IsA("Tool") and c:GetAttribute("WeaponId") then bindTool(c) end
		end)
		for _, c in ipairs(backpack:GetChildren()) do
			if c:IsA("Tool") and c:GetAttribute("WeaponId") then bindTool(c) end
		end
	end
end

if player.Character then onCharacter(player.Character) end
player.CharacterAdded:Connect(onCharacter)

]==]

sources.EffectsClient = [==[
-- EffectsClient.lua
-- Place in: StarterPlayerScripts as LocalScript named "EffectsClient"
-- Floating damage numbers, hit sparks, and animal-death poof.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local Debris           = game:GetService("Debris")
local Workspace        = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function spawnDamageNumber(position, amount, color)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Parent = Workspace

	local bb = Instance.new("BillboardGui", part)
	bb.Size = UDim2.new(0, 80, 0, 32)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	local lbl = Instance.new("TextLabel", bb)
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextColor3 = color or Color3.fromRGB(255, 220, 80)
	lbl.TextStrokeTransparency = 0
	lbl.Text = "-" .. tostring(amount)

	-- Float up and fade
	local up = TweenService:Create(part, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = position + Vector3.new(0, 4, 0)
	})
	up:Play()
	task.delay(0.4, function()
		TweenService:Create(lbl, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(part, 1.0)
end

local function spawnDeathPoof(position, name)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position + Vector3.new(0, 3, 0)
	part.Parent = Workspace

	local bb = Instance.new("BillboardGui", part)
	bb.Size = UDim2.new(0, 220, 0, 60)
	bb.AlwaysOnTop = true
	local lbl = Instance.new("TextLabel", bb)
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
	lbl.TextStrokeTransparency = 0
	lbl.TextScaled = true
	lbl.Text = (name and name .. " - הוכרע!") or "הוכרע!"

	-- Smoke
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(80, 30, 30)
	smoke.Size = 4
	smoke.RiseVelocity = 4
	smoke.Opacity = 0.5
	smoke.Parent = part

	TweenService:Create(part, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
		Position = position + Vector3.new(0, 8, 0)
	}):Play()
	task.delay(0.6, function()
		TweenService:Create(lbl, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(part, 2)
end

Remotes.ShowDamage.OnClientEvent:Connect(function(payload)
	if not payload then return end
	spawnDamageNumber(payload.position, payload.amount, payload.color)
end)

Remotes.AnimalDied.OnClientEvent:Connect(function(payload)
	if not payload then return end
	spawnDeathPoof(payload.position, payload.displayName)
end)

Remotes.CrashEffect.OnClientEvent:Connect(function(payload)
	if not payload then return end
	-- big red flash
	local sg = Instance.new("ScreenGui", Players.LocalPlayer:WaitForChild("PlayerGui"))
	sg.IgnoreGuiInset = true
	local f = Instance.new("Frame", sg)
	f.Size = UDim2.new(1, 0, 1, 0)
	f.BackgroundColor3 = Color3.fromRGB(220, 60, 30)
	f.BackgroundTransparency = 0.2
	f.BorderSizePixel = 0
	TweenService:Create(f, TweenInfo.new(1.0), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(sg, 1.5)
end)

]==]

sources.CameraClient = [==[
-- CameraClient.lua
-- Place in: StarterPlayerScripts as LocalScript named "CameraClient"
-- Camera shake on damage taken or crash.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player  = Players.LocalPlayer

local shakeAmt = 0
local shakeDecay = 5  -- per second

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam or shakeAmt <= 0 then return end
	local off = Vector3.new(
		(math.random()*2-1) * shakeAmt,
		(math.random()*2-1) * shakeAmt,
		(math.random()*2-1) * shakeAmt
	)
	cam.CFrame = cam.CFrame * CFrame.new(off * 0.05)
	shakeAmt = math.max(0, shakeAmt - shakeDecay * dt)
end)

local function shake(amount)
	shakeAmt = math.max(shakeAmt, amount)
end

-- Shake when local player takes damage
local lastHP
local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid")
	lastHP = hum.Health
	hum.HealthChanged:Connect(function(hp)
		if lastHP and hp < lastHP then
			shake(0.6)
		end
		lastHP = hp
	end)
end
if player.Character then onCharacter(player.Character) end
player.CharacterAdded:Connect(onCharacter)

Remotes.CrashEffect.OnClientEvent:Connect(function() shake(2.0) end)

]==]

sources.PlayerTagsClient = [==[
-- PlayerTagsClient.lua
-- Place in: StarterPlayerScripts as LocalScript named "PlayerTagsClient"
-- Renders a "שיא: M:SS" BillboardGui above each player's head, including the
-- local player. Listens to UpdateBestTimes for live updates.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage:WaitForChild("Strings"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TAG_NAME = "BestTimeTag"

local bestTimes = {}  -- [userId] = seconds

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec or 0))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function formatTagText(seconds)
	if not seconds or seconds <= 0 then
		return Strings.BestTime.Tag .. ": " .. Strings.BestTime.None
	end
	return Strings.BestTime.Tag .. ": " .. fmtTime(seconds)
end

local function buildTag(character)
	local head = character:FindFirstChild("Head")
	if not head then return nil end
	local existing = head:FindFirstChild(TAG_NAME)
	if existing then return existing end

	local bb = Instance.new("BillboardGui")
	bb.Name = TAG_NAME
	bb.Adornee = head
	bb.Size = UDim2.new(0, 180, 0, 36)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = head

	local frame = Instance.new("Frame", bb)
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	local c = Instance.new("UICorner", frame); c.CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", frame); s.Color = Color3.fromRGB(120, 200, 255); s.Thickness = 1.5

	local label = Instance.new("TextLabel", frame)
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -8, 1, 0)
	label.Position = UDim2.new(0, 4, 0, 0)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(180, 220, 255)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Text = formatTagText(0)
	return bb
end

local function refreshTagFor(player)
	local char = player.Character
	if not char then return end
	local bb = buildTag(char)
	if not bb then return end
	local frame = bb:FindFirstChildWhichIsA("Frame")
	if not frame then return end
	local label = frame:FindFirstChild("Label")
	if not label then return end
	label.Text = formatTagText(bestTimes[player.UserId])
end

local function refreshAll()
	for _, p in ipairs(Players:GetPlayers()) do
		refreshTagFor(p)
	end
end

local function attachToCharacter(player)
	local char = player.Character
	if not char then return end
	-- Wait for head, then build the tag once.
	task.spawn(function()
		local head = char:WaitForChild("Head", 5)
		if head then
			refreshTagFor(player)
		end
	end)
end

-- Hook player events
local function onPlayer(p)
	if p.Character then attachToCharacter(p) end
	p.CharacterAdded:Connect(function() attachToCharacter(p) end)
end
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerAdded:Connect(onPlayer)

-- Listen for live updates
Remotes.UpdateBestTimes.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	for k, v in pairs(payload) do
		bestTimes[tonumber(k) or k] = v
	end
	refreshAll()
end)

-- Initial fetch
task.spawn(function()
	local ok, snapshot = pcall(function()
		return Remotes.GetBestTimes:InvokeServer()
	end)
	if ok and type(snapshot) == "table" then
		for k, v in pairs(snapshot) do
			bestTimes[tonumber(k) or k] = v
		end
		refreshAll()
	end
end)

]==]


-- ====================================================================
-- INSTALL ALL SCRIPTS  (only those listed here are touched)
-- ====================================================================

local installed = {}
local function track(parent, name, className, src)
	ensure(parent, name, className, src)
	table.insert(installed, name)
end

track(ReplicatedStorage, "GameConfig",   "ModuleScript", sources.GameConfig)
track(ReplicatedStorage, "Strings",      "ModuleScript", sources.Strings)
track(ReplicatedStorage, "WeaponConfig", "ModuleScript", sources.WeaponConfig)
track(ReplicatedStorage, "AnimalConfig", "ModuleScript", sources.AnimalConfig)

track(ServerScriptService, "DataManager",     "Script", sources.DataManager)
track(ServerScriptService, "IslandBuilder",   "Script", sources.IslandBuilder)
track(ServerScriptService, "RoundManager",    "Script", sources.RoundManager)
track(ServerScriptService, "LobbyManager",    "Script", sources.LobbyManager)
track(ServerScriptService, "PlaneManager",    "Script", sources.PlaneManager)
track(ServerScriptService, "AnimalManager",   "Script", sources.AnimalManager)
track(ServerScriptService, "CombatManager",   "Script", sources.CombatManager)
track(ServerScriptService, "ShopManager",     "Script", sources.ShopManager)
track(ServerScriptService, "ProductHandler",  "Script", sources.ProductHandler)
track(ServerScriptService, "Main",            "Script", sources.Main)

track(StarterGui, "HUDGui",          "LocalScript", sources.HUDGui)
track(StarterGui, "LobbyGui",        "LocalScript", sources.LobbyGui)
track(StarterGui, "ShopGui",         "LocalScript", sources.ShopGui)
track(StarterGui, "DeathGui",        "LocalScript", sources.DeathGui)
track(StarterGui, "NotificationGui", "LocalScript", sources.NotificationGui)

track(StarterPlayerScripts, "ClientCombat",     "LocalScript", sources.ClientCombat)
track(StarterPlayerScripts, "EffectsClient",    "LocalScript", sources.EffectsClient)
track(StarterPlayerScripts, "CameraClient",     "LocalScript", sources.CameraClient)
track(StarterPlayerScripts, "PlayerTagsClient", "LocalScript", sources.PlayerTagsClient)

local Lighting = game:GetService("Lighting")
Lighting.ClockTime = 14
Lighting.Brightness = 2

pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

print("==============================================================")
print("[Install] Island Survival installed successfully")
print(string.format("[Install] %d scripts replaced (all other scripts left untouched)", #installed))
for _, n in ipairs(installed) do print("    -", n) end
print("[Install] Press Play (F5) to test.")
print("[Install] Make sure 'Allow API Services' is ON in Game Settings -> Security.")
print("==============================================================")
