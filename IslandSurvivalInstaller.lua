-- ====================================================================
-- IslandSurvivalInstaller.lua  (v3.7 — death GUI race fix)
-- ====================================================================
-- NON-DESTRUCTIVE installer. Studio: enable "Allow API Services" ->
-- View > Command Bar -> paste -> Enter. STOP THE GAME AND PLAY AGAIN.
-- ====================================================================

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui          = game:GetService("StarterGui")
local StarterPlayer       = game:GetService("StarterPlayer")
local StarterPlayerScripts= StarterPlayer:WaitForChild("StarterPlayerScripts")

local function ensure(parent, name, className, source)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local inst = Instance.new(className)
	inst.Name = name
	if source then inst.Source = source end
	inst.Parent = parent
	return inst
end

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
	-- With auto-loads disabled, dead players have no character. Make one.
	if not player.Character or not player.Character:FindFirstChildOfClass("Humanoid") or
	   (player.Character:FindFirstChildOfClass("Humanoid").Health <= 0) then
		player:LoadCharacter()
		task.wait(0.2)
	end
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
	print(string.format("[RoundManager] OnPlayerDied %s state=%s", player.Name, RoundManager.State))
	if RoundManager.State ~= "PLAYING" then
		warn(string.format("[RoundManager] OnPlayerDied dropped — state is %s, expected PLAYING", RoundManager.State))
		return
	end
	local s = dm().GetSession(player)
	if not s.Alive then
		warn(string.format("[RoundManager] OnPlayerDied dropped — %s session.Alive already false", player.Name))
		return
	end
	s.Alive = false
	s.DeathTime = tick()

	-- Compute survived time and update personal best.
	local survived = math.max(0, math.floor(s.DeathTime - RoundManager.RoundStartTime + 0.5))
	local prevBest = dm().GetBestTime(player)
	local isNewRecord, newBest = dm().UpdateBestTime(player, survived)
	local bestSeconds = isNewRecord and newBest or prevBest

	print(string.format("[RoundManager] Firing PlayerDied to %s (survived=%d, best=%d, canRevive=%s)",
		player.Name, survived, bestSeconds, tostring(not s.UsedRevive)))
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

	-- Check if everyone's done. We don't end the round while ANY player still
	-- has an active death countdown (so they can still revive). Polls until
	-- all players are either alive or have been returned to the lobby.
	task.spawn(function()
		while RoundManager.State == "PLAYING" do
			task.wait(0.5)
			local anyEngaged = false
			for _, p in ipairs(Players:GetPlayers()) do
				local sess = dm().GetSession(p)
				if sess.Alive or sess.PendingLobbyReturn then
					anyEngaged = true
					break
				end
			end
			if not anyEngaged then
				RoundManager.EndRound("AllDead")
				return
			end
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
		local function sendHide()
			pcall(function()
				getRemotes().DeathCountdown:FireClient(player, {
					secondsLeft     = 0,
					survivedSeconds = survived,
					bestSeconds     = bestSeconds,
					isNewRecord     = isNewRecord and true or false,
					canRevive       = false,
				})
			end)
		end

		local total = GameConfig.Round.DeathLobbyReturnSec
		for left = total, 1, -1 do
			-- If a different countdown was started or player revived, hide and stop.
			if s.DeathTaskId ~= taskId then
				sendHide()
				return
			end
			if s.Alive then
				s.PendingLobbyReturn = false
				sendHide()
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
		if s.DeathTaskId ~= taskId then sendHide() return end
		if s.Alive then sendHide() return end

		s.PendingLobbyReturn = false
		s.DeathTaskId = nil
		sendHide()
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
	-- Allow during PLAYING and ENDING (defensive — purchase may have happened
	-- right as the round was ending).
	if RoundManager.State ~= "PLAYING" and RoundManager.State ~= "ENDING" then
		warn("[RevivePlayer] Blocked, state:", RoundManager.State)
		return false
	end
	local s = dm().GetSession(player)
	if s.UsedRevive then
		warn("[RevivePlayer] Already used revive for", player.Name)
		return false
	end
	-- If the round had already ended, force it back to PLAYING for this revive.
	if RoundManager.State == "ENDING" then
		print("[RevivePlayer] Reversing ENDING -> PLAYING for late revive")
		RoundManager.State = "PLAYING"
		broadcastState({ reason = "late_revive" })
		if _G.AnimalManager and _G.AnimalManager.StartSpawning then
			_G.AnimalManager.StartSpawning()
		end
	end
	print("[RevivePlayer] Reviving", player.Name)
	s.UsedRevive = true
	s.Alive = true
	-- Cancel any pending death-to-lobby countdown for this player.
	s.DeathTaskId = nil
	s.PendingLobbyReturn = false

	-- Force-hide the death GUI on the client immediately. We don't wait
	-- for the countdown task to do this since there can be a race where
	-- the player is already past the timer when ProcessReceipt fires.
	pcall(function()
		getRemotes().DeathCountdown:FireClient(player, {
			secondsLeft = 0,
			survivedSeconds = 0,
			bestSeconds = _G.DataManager.GetBestTime(player),
			isNewRecord = false,
			canRevive = false,
		})
	end)

	-- Respawn at a safe spot (crash position).
	player:LoadCharacter()
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp  = char:WaitForChild("HumanoidRootPart")
	local crash = (_G.IslandBuilder and _G.IslandBuilder.GetCrashPosition()) or Vector3.new(0, 10, 0)
	-- task.wait so the engine settles the new HRP before we move it.
	task.wait(0.1)
	hrp.CFrame = CFrame.new(crash + Vector3.new(0, 6, 0))

	-- Re-equip starter weapon
	if _G.ShopManager and _G.ShopManager.GiveWeapon then
		_G.ShopManager.GiveWeapon(player, GameConfig.Round.StartingWeapon)
	end

	-- Apply HP/speed upgrades to the freshly-spawned humanoid.
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		local hpLevel = s.PlaneUpgrades.HP or 0
		local spdLevel = s.PlaneUpgrades.Speed or 0
		local maxHp = GameConfig.PlaneUpgrades.HP.Effect[hpLevel + 1] or GameConfig.Round.StartingHP
		local spdMul = GameConfig.PlaneUpgrades.Speed.Effect[spdLevel + 1] or 1
		hum.MaxHealth = maxHp
		hum.Health    = maxHp
		hum.WalkSpeed = 16 * spdMul
	end

	-- Force-update HUD so the client sees alive=true immediately.
	pcall(function()
		getRemotes().UpdateHUD:FireClient(player, RoundManager.BuildHUD(player))
	end)

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
	-- We control all character spawning ourselves so dead players stay dead
	-- (no auto-respawn) until either revive or the lobby-return countdown
	-- finishes.
	Players.CharacterAutoLoads = false

	local function setupCharacter(player, char)
		-- Hook death detection.
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum.Died:Connect(function()
				RoundManager.OnPlayerDied(player, "סכנה")
			end)
		end
		-- Send fresh HUD pulse so the new client sees correct state.
		task.delay(0.4, function()
			if not player.Parent then return end
			getRemotes().UpdateHUD:FireClient(player, RoundManager.BuildHUD(player))
		end)
	end

	local function spawnNewPlayer(player)
		-- New players always start in the lobby.
		dm().ResetSession(player)
		player:LoadCharacter()
		task.wait(0.2)
		teleportToLobby(player)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			-- Whoever LoadCharacter'd this character is responsible for
			-- positioning it. We just attach death detection + HUD.
			setupCharacter(player, char)
		end)
		task.spawn(spawnNewPlayer, player)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(spawnNewPlayer, p)
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

	local bodyColor = GameConfig.Plane.BodyColor
	local accent    = GameConfig.Plane.WingColor
	local trim      = Color3.fromRGB(160, 50, 50)
	local glassCol  = Color3.fromRGB(120, 180, 220)

	-- Roblox convention: a Part's "front" is its -Z axis (LookVector).
	-- We build the plane with its NOSE at -Z so CFrame.new(start, end)
	-- points the nose toward the destination. Everything in this builder is
	-- a Block shape (or Ball) for predictable orientation.

	-- Fuselage: long box centered at origin, length along Z (28 long, 5x5).
	local fuselage = makePart{
		Name = "Fuselage",
		Size = Vector3.new(5, 5, 28),
		CFrame = CFrame.new(0, 0, 0),
		Color = bodyColor, Material = Enum.Material.Metal,
		Parent = model,
	}

	-- Nose at -Z (front).
	makePart{
		Name = "Nose", Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		CFrame = CFrame.new(0, 0, -14),
		Color = bodyColor, Material = Enum.Material.Metal,
		Parent = model,
	}
	-- Rear cap at +Z (tail).
	makePart{
		Name = "TailCap", Shape = Enum.PartType.Ball,
		Size = Vector3.new(4.5, 4.5, 4),
		CFrame = CFrame.new(0, 0, 14),
		Color = bodyColor, Material = Enum.Material.Metal,
		Parent = model,
	}

	-- Trim stripes along both sides.
	makePart{
		Name = "StripeL", Size = Vector3.new(0.3, 1, 28),
		CFrame = CFrame.new(-2.55, 0.5, 0),
		Color = trim, Material = Enum.Material.SmoothPlastic, Parent = model,
	}
	makePart{
		Name = "StripeR", Size = Vector3.new(0.3, 1, 28),
		CFrame = CFrame.new(2.55, 0.5, 0),
		Color = trim, Material = Enum.Material.SmoothPlastic, Parent = model,
	}

	-- Cockpit windows on top of fuselage near the nose (z negative).
	makePart{
		Name = "CanopyL", Size = Vector3.new(0.3, 2.4, 7),
		CFrame = CFrame.new(-1.7, 2.6, -7),
		Color = glassCol, Material = Enum.Material.Glass,
		Transparency = 0.35, Reflectance = 0.3, Parent = model,
	}
	makePart{
		Name = "CanopyR", Size = Vector3.new(0.3, 2.4, 7),
		CFrame = CFrame.new(1.7, 2.6, -7),
		Color = glassCol, Material = Enum.Material.Glass,
		Transparency = 0.35, Reflectance = 0.3, Parent = model,
	}
	makePart{
		Name = "CanopyTop", Size = Vector3.new(3.4, 0.4, 7),
		CFrame = CFrame.new(0, 3.7, -7),
		Color = glassCol, Material = Enum.Material.Glass,
		Transparency = 0.35, Reflectance = 0.3, Parent = model,
	}
	-- Forward windshield (slanted slightly).
	makePart{
		Name = "Windshield", Size = Vector3.new(3.4, 2.6, 0.3),
		CFrame = CFrame.new(0, 2.4, -10.5) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = glassCol, Material = Enum.Material.Glass,
		Transparency = 0.35, Reflectance = 0.3, Parent = model,
	}

	-- Main wing — single block across both sides, slightly behind cockpit.
	makePart{
		Name = "Wing", Size = Vector3.new(30, 0.8, 5),
		CFrame = CFrame.new(0, 0.4, 1),
		Color = accent, Material = Enum.Material.Metal,
		Parent = model,
	}
	-- Winglets at wing tips.
	makePart{
		Name = "WingletL", Size = Vector3.new(0.7, 2.6, 3),
		CFrame = CFrame.new(-14.6, 1.7, 1),
		Color = trim, Material = Enum.Material.Metal, Parent = model,
	}
	makePart{
		Name = "WingletR", Size = Vector3.new(0.7, 2.6, 3),
		CFrame = CFrame.new(14.6, 1.7, 1),
		Color = trim, Material = Enum.Material.Metal, Parent = model,
	}

	-- Two underwing engines with propellers IN FRONT (more negative Z).
	local function buildEngine(side)
		makePart{
			Name = "Engine", Size = Vector3.new(2, 2, 5),
			CFrame = CFrame.new(side * 7, -0.8, -1),
			Color = Color3.fromRGB(60, 60, 70),
			Material = Enum.Material.Metal, Parent = model,
		}
		makePart{
			Name = "PropHub", Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 1.2, 1.2),
			CFrame = CFrame.new(side * 7, -0.8, -4),
			Color = trim, Material = Enum.Material.Metal, Parent = model,
		}
		-- Two crossed prop blades (vertical + horizontal).
		makePart{
			Name = "PropBlade1", Size = Vector3.new(0.3, 5, 0.4),
			CFrame = CFrame.new(side * 7, -0.8, -4.1),
			Color = Color3.fromRGB(30, 30, 35),
			Material = Enum.Material.Metal, Parent = model,
		}
		makePart{
			Name = "PropBlade2", Size = Vector3.new(5, 0.3, 0.4),
			CFrame = CFrame.new(side * 7, -0.8, -4.1),
			Color = Color3.fromRGB(30, 30, 35),
			Material = Enum.Material.Metal, Parent = model,
		}
	end
	buildEngine(-1)
	buildEngine(1)

	-- Tail vertical fin (rises up at the back, +Z).
	makePart{
		Name = "TailFin", Size = Vector3.new(0.6, 5, 5),
		CFrame = CFrame.new(0, 3, 11.5),
		Color = accent, Material = Enum.Material.Metal, Parent = model,
	}
	-- Tail horizontal stabilizer.
	makePart{
		Name = "HorizStab", Size = Vector3.new(9, 0.5, 3),
		CFrame = CFrame.new(0, 1.5, 12),
		Color = accent, Material = Enum.Material.Metal, Parent = model,
	}
	-- Tip of fin (red trim).
	makePart{
		Name = "TailTip", Size = Vector3.new(0.7, 1, 4),
		CFrame = CFrame.new(0, 5.2, 11.8),
		Color = trim, Material = Enum.Material.SmoothPlastic, Parent = model,
	}

	-- Side door (left fuselage, mid-section).
	makePart{
		Name = "Door", Size = Vector3.new(0.3, 3.5, 2.5),
		CFrame = CFrame.new(-2.6, 0.3, 4),
		Color = trim, Material = Enum.Material.Metal, Parent = model,
	}

	-- Weld everything to fuselage and finalize physics flags.
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			if p ~= fuselage then
				weldTo(p, fuselage)
			end
		end
	end

	model.PrimaryPart = fuselage
	return model
end

local function seatPlayers(model, players)
	local body = model.PrimaryPart
	-- Seats are in cockpit-and-cabin area. Nose is at -Z so seats with
	-- negative Z are forward, positive Z are aft.
	local seatPositions = {
		Vector3.new(-2, 2.0, -7),  -- pilot
		Vector3.new( 2, 2.0, -7),  -- co-pilot
		Vector3.new(-2, 2.0, -1),  -- mid left
		Vector3.new( 2, 2.0, -1),  -- mid right
		Vector3.new( 0, 2.0,  5),  -- rear center
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
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
	return w
end

-- Build a detailed animal model. Uses a small invisible HumanoidRootPart for
-- physics/collision and welds every visible part to it via WeldConstraint.
-- Reliable rendering — no Motor6D animation (caused instability earlier).
local function buildAnimalModel(spec)
	local model = Instance.new("Model")
	model.Name = spec.Id

	-- Standard-sized invisible HRP. Smaller than the visible body so it
	-- doesn't trap on terrain or hills. Massless=false so the Humanoid can
	-- move it; visible parts are Massless=true so they don't fight physics.
	local hrpSize = Vector3.new(
		math.max(1.5, spec.BodySize.X * 0.6),
		math.max(1.5, spec.BodySize.Y * 0.6),
		math.max(1.5, spec.BodySize.Z * 0.6)
	)
	local hrp = makePart{
		Name = "HumanoidRootPart",
		Size = hrpSize,
		Color = spec.BodyColor,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		CanCollide = true,
		Massless = false,
		Parent = model,
	}
	model.PrimaryPart = hrp

	-- Convenience: place a visible part at an offset relative to hrp and weld.
	local function addPart(name, size, offset, props)
		props = props or {}
		props.Name = name
		props.Size = size
		props.Color = props.Color or spec.BodyColor
		props.Material = props.Material or Enum.Material.SmoothPlastic
		props.CanCollide = false
		props.Massless = true
		props.Parent = model
		local p = makePart(props)
		p.CFrame = hrp.CFrame * offset
		weld(hrp, p)
		return p
	end

	-- Main body (chest+rear in one rounded mass)
	addPart("Body",
		Vector3.new(spec.BodySize.X, spec.BodySize.Y, spec.BodySize.Z),
		CFrame.new(0, 0, 0))

	-- Slight chest bulge
	addPart("Chest",
		Vector3.new(spec.BodySize.X * 1.1, spec.BodySize.Y * 1.05, spec.BodySize.Z * 0.5),
		CFrame.new(0, 0, -spec.BodySize.Z * 0.18))

	-- Neck cylinder
	local neckLen = math.max(0.6, spec.BodySize.Y * 0.5)
	addPart("Neck",
		Vector3.new(neckLen, spec.BodySize.X * 0.55, spec.BodySize.X * 0.55),
		CFrame.new(0, spec.BodySize.Y * 0.2, -spec.BodySize.Z * 0.55) * CFrame.Angles(0, 0, math.rad(70)),
		{ Shape = Enum.PartType.Cylinder })

	-- Head — shape varies per species
	local headShape = Enum.PartType.Block
	if spec.Id == "Bear" or spec.Id == "Lion" then
		headShape = Enum.PartType.Ball
	end
	local head = addPart("Head",
		spec.HeadSize,
		CFrame.new(0, spec.BodySize.Y * 0.5, -spec.BodySize.Z * 0.7),
		{ Shape = headShape })

	-- Snout (welded to head)
	local snoutLen = spec.HeadSize.Z * 0.55
	local snoutR, snoutG, snoutB
	if spec.Id == "Lion" then
		snoutR, snoutG, snoutB = 230, 200, 130
	else
		snoutR = math.max(0, math.floor(spec.BodyColor.R * 255 - 30))
		snoutG = math.max(0, math.floor(spec.BodyColor.G * 255 - 30))
		snoutB = math.max(0, math.floor(spec.BodyColor.B * 255 - 30))
	end
	local snout = makePart{
		Name = "Snout",
		Size = Vector3.new(spec.HeadSize.X * 0.65, spec.HeadSize.Y * 0.55, snoutLen),
		Color = Color3.fromRGB(snoutR, snoutG, snoutB),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	}
	snout.CFrame = head.CFrame * CFrame.new(0, -spec.HeadSize.Y * 0.1, -(spec.HeadSize.Z * 0.5 + snoutLen * 0.4))
	weld(head, snout)

	-- Nose tip
	local nose = makePart{
		Name = "Nose", Shape = Enum.PartType.Ball,
		Size = Vector3.new(spec.HeadSize.X * 0.28, spec.HeadSize.X * 0.28, spec.HeadSize.X * 0.28),
		Color = Color3.fromRGB(20, 16, 18),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	}
	nose.CFrame = snout.CFrame * CFrame.new(0, 0, -snoutLen * 0.5)
	weld(snout, nose)

	-- Eyes
	for _, sx in ipairs({-1, 1}) do
		local eye = makePart{
			Name = "Eye", Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.32, 0.32, 0.32),
			Color = Color3.fromRGB(20, 20, 20),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		eye.CFrame = head.CFrame * CFrame.new(sx * spec.HeadSize.X * 0.32, spec.HeadSize.Y * 0.18, -spec.HeadSize.Z * 0.45)
		weld(head, eye)
	end

	-- Ears: per-species
	local function buildEar(side)
		local ear, cf
		if spec.Id == "Dog" then
			ear = makePart{
				Name = "Ear",
				Size = Vector3.new(0.25, spec.HeadSize.Y * 0.6, spec.HeadSize.Z * 0.45),
				Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
				Parent = model,
			}
			cf = head.CFrame * CFrame.new(side * spec.HeadSize.X * 0.5, 0, 0)
				* CFrame.Angles(math.rad(-15), 0, math.rad(side * 25))
		elseif spec.Id == "Wolf" then
			ear = makePart{
				Name = "Ear",
				Size = Vector3.new(0.3, spec.HeadSize.Y * 0.7, 0.5),
				Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
				Parent = model,
			}
			cf = head.CFrame * CFrame.new(side * spec.HeadSize.X * 0.4, spec.HeadSize.Y * 0.55, spec.HeadSize.Z * 0.1)
				* CFrame.Angles(0, 0, math.rad(side * 20))
		elseif spec.Id == "Bear" then
			ear = makePart{
				Name = "Ear", Shape = Enum.PartType.Ball,
				Size = Vector3.new(spec.HeadSize.X * 0.35, spec.HeadSize.X * 0.35, spec.HeadSize.X * 0.35),
				Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
				Parent = model,
			}
			cf = head.CFrame * CFrame.new(side * spec.HeadSize.X * 0.42, spec.HeadSize.Y * 0.45, spec.HeadSize.Z * 0.05)
		else  -- Lion
			ear = makePart{
				Name = "Ear", Shape = Enum.PartType.Ball,
				Size = Vector3.new(spec.HeadSize.X * 0.3, spec.HeadSize.X * 0.3, spec.HeadSize.X * 0.3),
				Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
				Parent = model,
			}
			cf = head.CFrame * CFrame.new(side * spec.HeadSize.X * 0.5, spec.HeadSize.Y * 0.4, 0)
		end
		ear.CFrame = cf
		weld(head, ear)
	end
	buildEar(-1); buildEar(1)

	-- Mane (lion: ring of tufts + center mass)
	if spec.ManeColor then
		for i = 1, 6 do
			local angle = (i / 6) * math.pi * 2
			local r = spec.HeadSize.X * 1.0
			local tuft = makePart{
				Name = "ManeTuft", Shape = Enum.PartType.Ball,
				Size = Vector3.new(spec.HeadSize.X * 0.85, spec.HeadSize.X * 0.85, spec.HeadSize.X * 0.85),
				Color = spec.ManeColor, Material = Enum.Material.SmoothPlastic,
				Parent = model,
			}
			tuft.CFrame = head.CFrame * CFrame.new(math.cos(angle) * r, math.sin(angle) * r * 0.7, spec.HeadSize.Z * 0.15)
			weld(head, tuft)
		end
		local mass = makePart{
			Name = "ManeMass", Shape = Enum.PartType.Ball,
			Size = Vector3.new(spec.HeadSize.X * 1.7, spec.HeadSize.Y * 1.5, spec.HeadSize.Z * 1.4),
			Color = spec.ManeColor, Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		mass.CFrame = head.CFrame * CFrame.new(0, 0, spec.HeadSize.Z * 0.2)
		weld(head, mass)
	end

	-- Bear belly (chunky underside)
	if spec.Id == "Bear" then
		local belly = makePart{
			Name = "Belly", Shape = Enum.PartType.Ball,
			Size = Vector3.new(spec.BodySize.X * 1.15, spec.BodySize.Y * 1.1, spec.BodySize.Z * 0.7),
			Color = Color3.fromRGB(75, 50, 30), Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		belly.CFrame = hrp.CFrame * CFrame.new(0, -spec.BodySize.Y * 0.15, 0)
		weld(hrp, belly)
	end

	-- Legs (4) — welded directly to hrp, no Motor6D
	local legOffsets = {
		Vector3.new(-spec.BodySize.X * 0.32, -spec.BodySize.Y * 0.3, -spec.BodySize.Z * 0.32), -- FL
		Vector3.new( spec.BodySize.X * 0.32, -spec.BodySize.Y * 0.3, -spec.BodySize.Z * 0.32), -- FR
		Vector3.new(-spec.BodySize.X * 0.32, -spec.BodySize.Y * 0.3,  spec.BodySize.Z * 0.32), -- BL
		Vector3.new( spec.BodySize.X * 0.32, -spec.BodySize.Y * 0.3,  spec.BodySize.Z * 0.32), -- BR
	}
	for i, off in ipairs(legOffsets) do
		local leg = makePart{
			Name = "Leg" .. i, Size = spec.LegSize,
			Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		leg.CFrame = hrp.CFrame * CFrame.new(off.X, off.Y - spec.LegSize.Y * 0.5, off.Z)
		weld(hrp, leg)

		local paw = makePart{
			Name = "Paw",
			Size = Vector3.new(spec.LegSize.X * 1.2, spec.LegSize.X * 0.4, spec.LegSize.X * 1.4),
			Color = Color3.fromRGB(30, 22, 18), Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		paw.CFrame = leg.CFrame * CFrame.new(0, -spec.LegSize.Y * 0.45, 0)
		weld(leg, paw)
	end

	-- Tail
	local tailLen = spec.BodySize.Z * 0.55
	local tail = makePart{
		Name = "Tail", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(tailLen, 0.4, 0.4),
		Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
		Parent = model,
	}
	tail.CFrame = hrp.CFrame
		* CFrame.new(0, spec.BodySize.Y * 0.1, spec.BodySize.Z * 0.55 + tailLen * 0.4)
		* CFrame.Angles(0, math.rad(90), 0)
	weld(hrp, tail)

	if spec.ManeColor then
		local tuft = makePart{
			Name = "TailTuft", Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.8, 0.8, 0.8),
			Color = spec.ManeColor, Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		tuft.CFrame = tail.CFrame * CFrame.new(tailLen * 0.5, 0, 0)
		weld(tail, tuft)
	end

	-- Humanoid — HipHeight large enough to keep HRP fully above terrain.
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = spec.HP
	hum.Health    = spec.HP
	hum.WalkSpeed = spec.WalkSpeed
	hum.AutoRotate = true
	hum.HipHeight  = spec.LegSize.Y + 0.5  -- HRP bottom this far above ground
	hum.BreakJointsOnDeath = false
	hum.Parent = model

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
			return Vector3.new(x, GameConfig.Island.BaseSize.Y + 12, z)
		end
	end
	return Vector3.new(60, GameConfig.Island.BaseSize.Y + 12, 60)
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

-- Walk-cycle animation: a subtle vertical bob driven by the AI loop's
-- TweenService — applied directly to the HRP via BodyVelocity-free CFrame
-- nudges. We avoid Motor6D because they previously caused parts to detach.
-- (Implemented inline inside runAnimalAI with the bob.)

local function runAnimalAI(model, spec)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hrp = model.PrimaryPart
	if not hum or not hrp then return end

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
	-- Parent FIRST so physics simulates correctly when we move the model.
	model.Parent = Workspace
	-- PivotTo is the modern, accurate way to move a model with welds.
	model:PivotTo(CFrame.new(pos))

	active[model] = { spec = spec }
	attachHumanoidWatcher(model, spec)
	task.spawn(runAnimalAI, model, spec)
	return model
end

-- Spawn a SPECIFIC species (used by the dev panel "spawn animal" action).
-- animalId is one of the AnimalConfig.List Ids ("Dog", "Wolf", "Bear", "Lion").
function AnimalManager.SpawnSpecific(animalId)
	local spec = AnimalConfig.ById[animalId]
	if not spec then return nil end
	local model = buildAnimalModel(spec)
	local pos = pickSpawnPos()
	model.Parent = Workspace
	model:PivotTo(CFrame.new(pos))
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

-- ====================================================================
-- WEAPON MODEL BUILDERS
-- Each weapon is built from many welded parts for visual quality.
-- The "Handle" part is what the player's hand attaches to (Tool.Grip
-- offsets where on the Handle the hand sits).
-- ====================================================================

local function configurePart(p, props)
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
end

local function newPart(props)
	local p = Instance.new("Part")
	configurePart(p, props)
	return p
end

local function newWedge(props)
	local p = Instance.new("WedgePart")
	configurePart(p, props)
	return p
end

local function weldTo(parent, child)
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = child
	w.Parent = child
end

-- ----- Stick: gnarled wooden club -----
local function buildStick(tool)
	local handle = newPart{
		Name = "Handle",
		Size = Vector3.new(0.55, 0.55, 3.4),
		Color = Color3.fromRGB(105, 70, 35),
		Material = Enum.Material.Wood,
		Parent = tool,
	}

	-- Knot bumps along the stick for character.
	local knotOffsets = {
		Vector3.new( 0.2, 0.05, -0.9),
		Vector3.new(-0.2, 0.0,   0.1),
		Vector3.new( 0.1, 0.2,   1.0),
		Vector3.new(-0.15, -0.1, 1.4),
	}
	for _, off in ipairs(knotOffsets) do
		local knot = newPart{
			Name = "Knot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.55, 0.45, 0.5),
			Color = Color3.fromRGB(82, 50, 22),
			Material = Enum.Material.Wood,
			Parent = tool,
		}
		knot.CFrame = handle.CFrame * CFrame.new(off)
		weldTo(handle, knot)
	end

	-- Tapered tip (the "business end"): heavier, wider.
	local head = newPart{
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.95, 0.85, 0.95),
		Color = Color3.fromRGB(95, 60, 28),
		Material = Enum.Material.Wood,
		Parent = tool,
	}
	head.CFrame = handle.CFrame * CFrame.new(0, 0, -1.6)
	weldTo(handle, head)

	-- A few darker spikes/splinters on the head for brutality.
	for i, off in ipairs({
		Vector3.new( 0.32,  0.18, -1.7),
		Vector3.new(-0.30,  0.22, -1.55),
		Vector3.new( 0.10, -0.30, -1.85),
	}) do
		local spike = newPart{
			Name = "Splinter",
			Size = Vector3.new(0.14, 0.14, 0.45),
			Color = Color3.fromRGB(60, 38, 18),
			Material = Enum.Material.Wood,
			Parent = tool,
		}
		spike.CFrame = handle.CFrame * CFrame.new(off) * CFrame.Angles(math.rad(20 * i), math.rad(15 * i), 0)
		weldTo(handle, spike)
	end

	-- Leather grip wrap at the back third.
	for _, z in ipairs({1.05, 1.35, 1.65}) do
		local wrap = newPart{
			Name = "Wrap",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 0.66, 0.66),
			Color = Color3.fromRGB(55, 32, 18),
			Material = Enum.Material.Fabric,
			Parent = tool,
		}
		wrap.CFrame = handle.CFrame * CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(90), 0)
		weldTo(handle, wrap)
	end

	tool.Grip = CFrame.new(0, 0, -1.4)
end

-- ----- Spear: long shaft with a steel head -----
local function buildSpear(tool)
	local handle = newPart{
		Name = "Handle",
		Size = Vector3.new(0.32, 0.32, 6),
		Color = Color3.fromRGB(155, 120, 80),
		Material = Enum.Material.Wood,
		Parent = tool,
	}

	-- Steel band where head meets shaft.
	local band = newPart{
		Name = "Band",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 0.45, 0.45),
		Color = Color3.fromRGB(110, 110, 120),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	band.CFrame = handle.CFrame * CFrame.new(0, 0, -2.85) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(handle, band)

	-- Spearhead base (rectangular blade).
	local headBase = newPart{
		Name = "HeadBase",
		Size = Vector3.new(0.55, 0.08, 0.9),
		Color = Color3.fromRGB(190, 195, 205),
		Material = Enum.Material.Metal,
		Reflectance = 0.25,
		Parent = tool,
	}
	headBase.CFrame = handle.CFrame * CFrame.new(0, 0, -3.5)
	weldTo(handle, headBase)

	-- Spear tip: two angled wedges making a triangular point.
	local tipL = newWedge{
		Name = "TipL",
		Size = Vector3.new(0.275, 0.08, 0.65),
		Color = Color3.fromRGB(220, 220, 230),
		Material = Enum.Material.Metal,
		Reflectance = 0.4,
		Parent = tool,
	}
	tipL.CFrame = handle.CFrame * CFrame.new(-0.137, 0, -4.275) * CFrame.Angles(0, 0, 0)
	weldTo(handle, tipL)

	local tipR = newWedge{
		Name = "TipR",
		Size = Vector3.new(0.275, 0.08, 0.65),
		Color = Color3.fromRGB(220, 220, 230),
		Material = Enum.Material.Metal,
		Reflectance = 0.4,
		Parent = tool,
	}
	tipR.CFrame = handle.CFrame * CFrame.new(0.137, 0, -4.275) * CFrame.Angles(0, math.rad(180), 0)
	weldTo(handle, tipR)

	-- Center ridge of the blade.
	local ridge = newPart{
		Name = "Ridge",
		Size = Vector3.new(0.06, 0.18, 1.5),
		Color = Color3.fromRGB(170, 175, 185),
		Material = Enum.Material.Metal,
		Reflectance = 0.3,
		Parent = tool,
	}
	ridge.CFrame = handle.CFrame * CFrame.new(0, 0.05, -3.85)
	weldTo(handle, ridge)

	-- Leather wrap at grip area.
	for _, z in ipairs({1.6, 2.0, 2.4, 2.8}) do
		local wrap = newPart{
			Name = "Wrap",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.32, 0.42, 0.42),
			Color = Color3.fromRGB(48, 28, 16),
			Material = Enum.Material.Fabric,
			Parent = tool,
		}
		wrap.CFrame = handle.CFrame * CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(90), 0)
		weldTo(handle, wrap)
	end

	-- Counterweight at the butt end (steel cap).
	local butt = newPart{
		Name = "Butt",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 0.42, 0.42),
		Color = Color3.fromRGB(95, 95, 105),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	butt.CFrame = handle.CFrame * CFrame.new(0, 0, 3.2) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(handle, butt)

	-- Decorative red feather just behind the head.
	local feather = newPart{
		Name = "Feather",
		Size = Vector3.new(0.05, 0.6, 0.5),
		Color = Color3.fromRGB(170, 30, 30),
		Material = Enum.Material.Fabric,
		Transparency = 0.1,
		Parent = tool,
	}
	feather.CFrame = handle.CFrame * CFrame.new(0, 0.4, -2.55) * CFrame.Angles(0, 0, math.rad(15))
	weldTo(handle, feather)

	tool.Grip = CFrame.new(0, 0, -2.2)
end

-- ----- Knife: short bladed weapon with crossguard -----
local function buildKnife(tool)
	local handle = newPart{
		Name = "Handle",
		Size = Vector3.new(0.42, 0.32, 1.1),
		Color = Color3.fromRGB(75, 48, 25),
		Material = Enum.Material.Wood,
		Parent = tool,
	}

	-- Wrapping ridges on the wooden handle.
	for _, z in ipairs({-0.3, 0.0, 0.3}) do
		local ridge = newPart{
			Name = "HandleRidge",
			Size = Vector3.new(0.46, 0.36, 0.08),
			Color = Color3.fromRGB(50, 30, 16),
			Material = Enum.Material.Wood,
			Parent = tool,
		}
		ridge.CFrame = handle.CFrame * CFrame.new(0, 0, z)
		weldTo(handle, ridge)
	end

	-- Pommel ball at the back.
	local pommel = newPart{
		Name = "Pommel",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.45, 0.45, 0.45),
		Color = Color3.fromRGB(140, 140, 150),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
		Parent = tool,
	}
	pommel.CFrame = handle.CFrame * CFrame.new(0, 0, 0.6)
	weldTo(handle, pommel)

	-- Crossguard between handle and blade.
	local guard = newPart{
		Name = "Guard",
		Size = Vector3.new(0.85, 0.18, 0.22),
		Color = Color3.fromRGB(150, 150, 160),
		Material = Enum.Material.Metal,
		Reflectance = 0.3,
		Parent = tool,
	}
	guard.CFrame = handle.CFrame * CFrame.new(0, 0, -0.6)
	weldTo(handle, guard)

	-- Main blade body (broad, slightly tapered).
	local blade = newPart{
		Name = "Blade",
		Size = Vector3.new(0.38, 0.06, 1.7),
		Color = Color3.fromRGB(205, 210, 220),
		Material = Enum.Material.Metal,
		Reflectance = 0.4,
		Parent = tool,
	}
	blade.CFrame = handle.CFrame * CFrame.new(0, 0.03, -1.55)
	weldTo(handle, blade)

	-- Sharpened edge highlight (thin reflective strip).
	local edge = newPart{
		Name = "Edge",
		Size = Vector3.new(0.27, 0.03, 1.6),
		Color = Color3.fromRGB(245, 245, 255),
		Material = Enum.Material.Metal,
		Reflectance = 0.6,
		Parent = tool,
	}
	edge.CFrame = handle.CFrame * CFrame.new(0, -0.01, -1.55)
	weldTo(handle, edge)

	-- Pointed blade tip (wedge shape).
	local tip = newWedge{
		Name = "BladeTip",
		Size = Vector3.new(0.38, 0.06, 0.55),
		Color = Color3.fromRGB(220, 225, 235),
		Material = Enum.Material.Metal,
		Reflectance = 0.45,
		Parent = tool,
	}
	tip.CFrame = handle.CFrame * CFrame.new(0, 0.03, -2.7) * CFrame.Angles(0, 0, 0)
	weldTo(handle, tip)

	-- Blood groove (decorative line on the blade).
	local groove = newPart{
		Name = "Groove",
		Size = Vector3.new(0.08, 0.03, 1.3),
		Color = Color3.fromRGB(120, 125, 135),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	groove.CFrame = handle.CFrame * CFrame.new(0, 0.07, -1.55)
	weldTo(handle, groove)

	tool.Grip = CFrame.new(0, 0, 0)
end

-- ----- Pistol: realistic semi-auto -----
local function buildPistol(tool)
	-- The Handle is the slide/body (top of the pistol).
	local slide = newPart{
		Name = "Handle",
		Size = Vector3.new(0.45, 0.55, 1.7),
		Color = Color3.fromRGB(38, 38, 42),
		Material = Enum.Material.Metal,
		Reflectance = 0.1,
		Parent = tool,
	}

	-- Slide texture grooves (little vertical lines at the back).
	for _, z in ipairs({0.55, 0.65, 0.75}) do
		local groove = newPart{
			Name = "SlideGroove",
			Size = Vector3.new(0.46, 0.4, 0.04),
			Color = Color3.fromRGB(20, 20, 24),
			Material = Enum.Material.Metal,
			Parent = tool,
		}
		groove.CFrame = slide.CFrame * CFrame.new(0, 0.05, z)
		weldTo(slide, groove)
	end

	-- Front sight blade.
	local frontSight = newPart{
		Name = "FrontSight",
		Size = Vector3.new(0.06, 0.18, 0.12),
		Color = Color3.fromRGB(15, 15, 18),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	frontSight.CFrame = slide.CFrame * CFrame.new(0, 0.36, -0.7)
	weldTo(slide, frontSight)

	-- Rear sight notch.
	local rearSight = newPart{
		Name = "RearSight",
		Size = Vector3.new(0.32, 0.12, 0.16),
		Color = Color3.fromRGB(15, 15, 18),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	rearSight.CFrame = slide.CFrame * CFrame.new(0, 0.33, 0.7)
	weldTo(slide, rearSight)

	-- Barrel extending forward.
	local barrel = newPart{
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.55, 0.28, 0.28),
		Color = Color3.fromRGB(25, 25, 28),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	barrel.CFrame = slide.CFrame * CFrame.new(0, 0, -1.1) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(slide, barrel)

	-- Muzzle ring.
	local muzzle = newPart{
		Name = "Muzzle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, 0.32, 0.32),
		Color = Color3.fromRGB(15, 15, 18),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	muzzle.CFrame = slide.CFrame * CFrame.new(0, 0, -1.4) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(slide, muzzle)

	-- Grip frame (vertical, below slide).
	local grip = newPart{
		Name = "Grip",
		Size = Vector3.new(0.42, 1.15, 0.55),
		Color = Color3.fromRGB(28, 28, 32),
		Material = Enum.Material.Plastic,
		Parent = tool,
	}
	grip.CFrame = slide.CFrame * CFrame.new(0, -0.78, 0.45) * CFrame.Angles(math.rad(-12), 0, 0)
	weldTo(slide, grip)

	-- Checkering on the grip (texture lines).
	for i = 1, 5 do
		local line = newPart{
			Name = "GripCheck",
			Size = Vector3.new(0.44, 0.06, 0.5),
			Color = Color3.fromRGB(15, 15, 18),
			Material = Enum.Material.Plastic,
			Parent = tool,
		}
		line.CFrame = slide.CFrame * CFrame.new(0, -0.4 - i * 0.16, 0.45 + (i - 3) * 0.05) * CFrame.Angles(math.rad(-12), 0, 0)
		weldTo(slide, line)
	end

	-- Trigger guard (the loop around the trigger).
	local guardFront = newPart{
		Name = "TriggerGuardF",
		Size = Vector3.new(0.18, 0.08, 0.5),
		Color = Color3.fromRGB(28, 28, 32),
		Material = Enum.Material.Plastic,
		Parent = tool,
	}
	guardFront.CFrame = slide.CFrame * CFrame.new(0, -0.35, -0.05)
	weldTo(slide, guardFront)
	local guardBack = newPart{
		Name = "TriggerGuardB",
		Size = Vector3.new(0.16, 0.32, 0.1),
		Color = Color3.fromRGB(28, 28, 32),
		Material = Enum.Material.Plastic,
		Parent = tool,
	}
	guardBack.CFrame = slide.CFrame * CFrame.new(0, -0.5, 0.18)
	weldTo(slide, guardBack)

	-- Trigger
	local trigger = newPart{
		Name = "Trigger",
		Size = Vector3.new(0.1, 0.28, 0.08),
		Color = Color3.fromRGB(120, 120, 130),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
		Parent = tool,
	}
	trigger.CFrame = slide.CFrame * CFrame.new(0, -0.45, 0.0)
	weldTo(slide, trigger)

	-- Magazine (visible at bottom of grip).
	local mag = newPart{
		Name = "Magazine",
		Size = Vector3.new(0.36, 0.22, 0.5),
		Color = Color3.fromRGB(50, 50, 58),
		Material = Enum.Material.Metal,
		Reflectance = 0.15,
		Parent = tool,
	}
	mag.CFrame = slide.CFrame * CFrame.new(0, -1.4, 0.5) * CFrame.Angles(math.rad(-12), 0, 0)
	weldTo(slide, mag)

	-- Hammer at the back of the slide.
	local hammer = newPart{
		Name = "Hammer",
		Size = Vector3.new(0.12, 0.25, 0.12),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	hammer.CFrame = slide.CFrame * CFrame.new(0, 0.34, 0.83)
	weldTo(slide, hammer)

	tool.Grip = CFrame.new(0, 0.7, -0.4)
end

-- ----- Shotgun: pump-action with wooden stock -----
local function buildShotgun(tool)
	-- Receiver in the middle (Handle).
	local receiver = newPart{
		Name = "Handle",
		Size = Vector3.new(0.55, 0.7, 1.6),
		Color = Color3.fromRGB(45, 30, 15),
		Material = Enum.Material.Wood,
		Parent = tool,
	}

	-- Steel band on receiver.
	local band = newPart{
		Name = "ReceiverBand",
		Size = Vector3.new(0.6, 0.74, 0.18),
		Color = Color3.fromRGB(70, 70, 78),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
		Parent = tool,
	}
	band.CFrame = receiver.CFrame * CFrame.new(0, 0, -0.7)
	weldTo(receiver, band)

	-- Main barrel (long).
	local barrel = newPart{
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4.8, 0.4, 0.4),
		Color = Color3.fromRGB(28, 28, 32),
		Material = Enum.Material.Metal,
		Reflectance = 0.15,
		Parent = tool,
	}
	barrel.CFrame = receiver.CFrame * CFrame.new(0, 0.05, -3.2) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(receiver, barrel)

	-- Front bead sight.
	local bead = newPart{
		Name = "FrontBead",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.1, 0.1, 0.1),
		Color = Color3.fromRGB(220, 200, 60),
		Material = Enum.Material.Neon,
		Parent = tool,
	}
	bead.CFrame = receiver.CFrame * CFrame.new(0, 0.27, -5.5)
	weldTo(receiver, bead)

	-- Magazine tube (under barrel).
	local magTube = newPart{
		Name = "MagTube",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4.6, 0.28, 0.28),
		Color = Color3.fromRGB(35, 35, 40),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	magTube.CFrame = receiver.CFrame * CFrame.new(0, -0.2, -3.1) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(receiver, magTube)

	-- Pump grip (forward of trigger, slides on the mag tube).
	local pump = newPart{
		Name = "Pump",
		Size = Vector3.new(0.6, 0.45, 1.0),
		Color = Color3.fromRGB(30, 18, 8),
		Material = Enum.Material.Wood,
		Parent = tool,
	}
	pump.CFrame = receiver.CFrame * CFrame.new(0, -0.18, -1.6)
	weldTo(receiver, pump)

	-- Pump grip ridges.
	for i = 1, 4 do
		local ridge = newPart{
			Name = "PumpRidge",
			Size = Vector3.new(0.62, 0.46, 0.06),
			Color = Color3.fromRGB(15, 8, 4),
			Material = Enum.Material.Wood,
			Parent = tool,
		}
		ridge.CFrame = receiver.CFrame * CFrame.new(0, -0.18, -1.95 + (i - 1) * 0.22)
		weldTo(receiver, ridge)
	end

	-- Wooden buttstock (back of the gun).
	local stock = newPart{
		Name = "Stock",
		Size = Vector3.new(0.5, 1.1, 1.7),
		Color = Color3.fromRGB(95, 60, 30),
		Material = Enum.Material.Wood,
		Parent = tool,
	}
	stock.CFrame = receiver.CFrame * CFrame.new(0, -0.3, 1.55) * CFrame.Angles(math.rad(-8), 0, 0)
	weldTo(receiver, stock)

	-- Recoil pad on stock.
	local pad = newPart{
		Name = "Pad",
		Size = Vector3.new(0.55, 1.15, 0.18),
		Color = Color3.fromRGB(20, 18, 16),
		Material = Enum.Material.Fabric,
		Parent = tool,
	}
	pad.CFrame = stock.CFrame * CFrame.new(0, 0, 0.92)
	weldTo(receiver, pad)

	-- Pistol grip section (where the trigger hand goes).
	local grip = newPart{
		Name = "Grip",
		Size = Vector3.new(0.38, 0.85, 0.55),
		Color = Color3.fromRGB(30, 18, 8),
		Material = Enum.Material.Wood,
		Parent = tool,
	}
	grip.CFrame = receiver.CFrame * CFrame.new(0, -0.65, 0.5) * CFrame.Angles(math.rad(-15), 0, 0)
	weldTo(receiver, grip)

	-- Trigger guard.
	local guardFront = newPart{
		Name = "TriggerGuardF",
		Size = Vector3.new(0.16, 0.08, 0.4),
		Color = Color3.fromRGB(40, 40, 48),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	guardFront.CFrame = receiver.CFrame * CFrame.new(0, -0.5, 0.05)
	weldTo(receiver, guardFront)
	local guardBack = newPart{
		Name = "TriggerGuardB",
		Size = Vector3.new(0.14, 0.28, 0.1),
		Color = Color3.fromRGB(40, 40, 48),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	guardBack.CFrame = receiver.CFrame * CFrame.new(0, -0.62, 0.25)
	weldTo(receiver, guardBack)

	-- Trigger
	local trigger = newPart{
		Name = "Trigger",
		Size = Vector3.new(0.08, 0.22, 0.07),
		Color = Color3.fromRGB(140, 140, 150),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
		Parent = tool,
	}
	trigger.CFrame = receiver.CFrame * CFrame.new(0, -0.55, 0.05)
	weldTo(receiver, trigger)

	tool.Grip = CFrame.new(0, 0.55, -0.5)
end

local WEAPON_BUILDERS = {
	Stick   = buildStick,
	Spear   = buildSpear,
	Knife   = buildKnife,
	Pistol  = buildPistol,
	Shotgun = buildShotgun,
}

-- Build a Tool instance for a weapon spec, choosing the right builder.
local function buildToolForWeapon(spec)
	local tool = Instance.new("Tool")
	tool.Name = Strings.Weapons[spec.DisplayKey] or spec.Id
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", spec.Id)

	local builder = WEAPON_BUILDERS[spec.Id]
	if builder then
		builder(tool)
	else
		-- Fallback: simple block handle.
		local handle = newPart{
			Name = "Handle",
			Size = spec.HandleSize or Vector3.new(0.4, 0.4, 2),
			Color = spec.HandleColor or Color3.fromRGB(120, 80, 40),
			Material = Enum.Material.Wood,
			Parent = tool,
		}
	end

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
	-- Allow during PLAYING (normal case) AND during the brief death window
	-- before the round formally ends. The new round-end logic keeps state
	-- as PLAYING while any player has a death countdown active.
	if not rm or (rm.GetState() ~= "PLAYING" and rm.GetState() ~= "ENDING") then
		warn("[ShopManager] PromptRevive blocked, state:", rm and rm.GetState() or "nil")
		return
	end
	local sess = dm().GetSession(player)
	if sess.UsedRevive then
		getRemotes().ToastNotify:FireClient(player, {
			text = Strings.Death.ReviveUsed, color = Color3.fromRGB(255,170,80),
		})
		return
	end
	-- Don't try to revive an already-alive player.
	if sess.Alive then return end
	print("[ShopManager] Prompting revive for", player.Name)
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, GameConfig.Products.REVIVE)
	end)
	if not ok then
		warn("[ShopManager] PromptRevive failed:", err)
		getRemotes().ToastNotify:FireClient(player, {
			text  = Strings.Notifications.PurchaseFailed,
			color = Color3.fromRGB(255, 100, 100),
		})
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
	if not rm then
		warn("[ProductHandler] grantRevive: RoundManager not ready")
		return false
	end
	print("[ProductHandler] grantRevive for", player.Name, "state:", rm.GetState())
	local ok = rm.RevivePlayer(player)
	if not ok then
		warn("[ProductHandler] RevivePlayer returned false. State:", rm.GetState())
		getRemotes().ToastNotify:FireClient(player, {
			text = "החייאה נכשלה - נסה שוב בסבב הבא",
			color = Color3.fromRGB(255, 170, 80),
		})
	else
		print("[ProductHandler] Revive successful for", player.Name)
	end
	return true
end

local function processReceipt(receiptInfo)
	print("[ProductHandler] ProcessReceipt called for product", receiptInfo.ProductId, "player", receiptInfo.PlayerId)
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

	-- Always consume the purchase (return PurchaseGranted) once we've made
	-- our best effort. For revive specifically we always grant — if the
	-- revive itself failed (e.g., round state changed) the user has been
	-- notified via toast and we don't want Roblox to retry the receipt.
	processed[key] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt
_G.ProductHandler = ProductHandler
print("[ProductHandler] Ready.")

]==]

sources.AdminManager = [==[
-- AdminManager.server.lua
-- Place in: ServerScriptService as Script named "AdminManager"
-- Backend for the Dev Panel. Validates that the requesting player is one of
-- the configured owners before performing any admin action. All actions
-- short-circuit silently if the player isn't authorized.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local MessagingService  = game:GetService("MessagingService")
local TeleportService   = game:GetService("TeleportService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local AdminManager = {}
local Remotes  -- lazy

local function getRemotes()
	if Remotes then return Remotes end
	Remotes = ReplicatedStorage:WaitForChild("Remotes")
	return Remotes
end

local function dm()
	while not _G.DataManager do task.wait(0.05) end
	return _G.DataManager
end

-- ==== Authorization ====
local ALLOWED = {}
for _, uid in ipairs(GameConfig.Owners or {}) do
	ALLOWED[uid] = true
end

function AdminManager.IsAdmin(player)
	if not player then return false end
	return ALLOWED[player.UserId] == true
end

-- ==== Ban list (DataStore) ====
local BAN_DATASTORE = "IslandSurvival_Bans_v1"
local banStore = DataStoreService:GetDataStore(BAN_DATASTORE)

local function isBanned(userId)
	local ok, val = pcall(function() return banStore:GetAsync("u_" .. userId) end)
	if ok and val == true then return true end
	return false
end

local function setBanned(userId, banned)
	local ok, err = pcall(function() banStore:SetAsync("u_" .. userId, banned and true or nil) end)
	if not ok then warn("[AdminManager] ban-store set failed:", err) end
	return ok
end

-- Kick on join if banned. Best-effort only.
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		if isBanned(player.UserId) then
			player:Kick("Banned from this game.")
		end
	end)
end)

-- ==== Cross-server messaging ====
local TOPIC_GLOBAL = "IslandSurvival.GlobalMessage"
local TOPIC_RESTART_ALL = "IslandSurvival.RestartAll"
local TOPIC_SPAWN_ANIMAL = "IslandSurvival.SpawnAnimal"

-- ==== Helpers ====
local function notify(player, ok, message, color)
	getRemotes().AdminResult:FireClient(player, {
		ok = ok and true or false,
		message = message,
		color = color,
	})
end

-- Resolve a target by username — returns the matching Player or nil.
local function findPlayerByName(name)
	if not name or name == "" then return nil end
	local lower = string.lower(name)
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
			return p
		end
	end
	return nil
end

-- Pull the current weapon-target player based on payload.
-- If target is "self" or no username given, use the requesting admin.
local function resolveTarget(admin, data)
	if not data or data.target == "self" or not data.username or data.username == "" then
		return admin
	end
	return findPlayerByName(data.username)
end

local function localBroadcastMessage(text, color)
	getRemotes().GlobalMessage:FireAllClients({
		text  = text,
		color = color,
	})
end

-- ==== God Mode ====
local godModeMap = {}    -- [userId] = true while enabled
local godConnections = {} -- [userId] = HealthChanged RBXScriptConnection

local function clearGodConnection(userId)
	local c = godConnections[userId]
	if c then
		pcall(function() c:Disconnect() end)
		godConnections[userId] = nil
	end
end

local function attachGodMode(player)
	clearGodConnection(player.UserId)
	if not godModeMap[player.UserId] then return end
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	-- Snap to full first.
	hum.Health = hum.MaxHealth
	-- Reset HP every time it drops.
	godConnections[player.UserId] = hum.HealthChanged:Connect(function(hp)
		if not godModeMap[player.UserId] then
			clearGodConnection(player.UserId)
			return
		end
		if hp < hum.MaxHealth then
			hum.Health = hum.MaxHealth
		end
	end)
end

-- Re-attach god mode when a god player's character respawns.
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function()
		if godModeMap[p.UserId] then
			task.wait(0.3)
			attachGodMode(p)
		end
	end)
end)
Players.PlayerRemoving:Connect(function(p)
	clearGodConnection(p.UserId)
	godModeMap[p.UserId] = nil
end)

function AdminManager.IsGodMode(player)
	return godModeMap[player.UserId] == true
end

-- ==== Action handlers ====
local actions = {}

actions.globalMessage = function(admin, data)
	local text = tostring(data and data.text or ""):sub(1, 200)
	local color = data and data.color or "#ffffff"
	if text == "" then
		notify(admin, false, "ההודעה ריקה")
		return
	end
	-- broadcast in this server immediately
	localBroadcastMessage(text, color)
	-- and to other servers via MessagingService (best-effort)
	pcall(function()
		MessagingService:PublishAsync(TOPIC_GLOBAL, { text = text, color = color, sender = admin.UserId })
	end)
	notify(admin, true, "הודעה נשלחה לכל השרתים", "#51cf66")
end

actions.giveXP = function(admin, data)
	local amount = tonumber(data and data.amount) or 0
	if amount <= 0 then
		notify(admin, false, "כמות XP לא תקינה")
		return
	end
	local target = resolveTarget(admin, data)
	if not target then
		notify(admin, false, "השחקן לא נמצא בשרת")
		return
	end
	dm().AddXP(target, amount)
	notify(admin, true, string.format("הוענקו %d XP ל-%s", amount, target.Name), "#51cf66")
end

actions.giveWeapon = function(admin, data)
	local weaponId = tostring(data and data.weaponId or "")
	local weaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
	if not weaponConfig.ById[weaponId] then
		notify(admin, false, "נשק לא תקין")
		return
	end
	local target = resolveTarget(admin, data)
	if not target then
		notify(admin, false, "השחקן לא נמצא בשרת")
		return
	end
	if _G.ShopManager and _G.ShopManager.GiveWeapon then
		dm().GrantSessionWeapon(target, weaponId)
		_G.ShopManager.GiveWeapon(target, weaponId)
		notify(admin, true, string.format("הוענק %s ל-%s", weaponId, target.Name), "#51cf66")
	else
		notify(admin, false, "ShopManager לא פעיל")
	end
end

actions.heal = function(admin, data)
	local target = resolveTarget(admin, data)
	if not target then
		notify(admin, false, "השחקן לא נמצא בשרת")
		return
	end
	-- If the target is dead (no character or zero HP), promote heal -> revive.
	-- This lets an admin still on the death countdown screen come back to the
	-- island via the dev panel.
	local char = target.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if (not hum) or hum.Health <= 0 then
		if _G.RoundManager and _G.RoundManager.GetState() == "PLAYING" and _G.RoundManager.RevivePlayer then
			-- Bypass UsedRevive — admins should always be able to come back.
			local sess = dm().GetSession(target)
			sess.UsedRevive = false
			local ok = _G.RoundManager.RevivePlayer(target)
			if ok then
				notify(admin, true, string.format("%s הוחייה ע\"י הפאנל", target.Name), "#51cf66")
				return
			end
		end
		-- Round not playing — just LoadCharacter at lobby spawn.
		target:LoadCharacter()
		notify(admin, true, string.format("%s הופעל מחדש", target.Name), "#51cf66")
		return
	end

	local amount = tonumber(data and data.amount)
	if not amount then
		hum.Health = hum.MaxHealth
		notify(admin, true, string.format("%s הוחזר ל-HP מלא", target.Name), "#51cf66")
	elseif amount <= 0 then
		notify(admin, false, "כמות HP לא תקינה")
	else
		hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
		notify(admin, true, string.format("רפא %d HP ל-%s", amount, target.Name), "#51cf66")
	end
end

actions.godMode = function(admin, data)
	local target = resolveTarget(admin, data)
	if not target then
		notify(admin, false, "השחקן לא נמצא בשרת")
		return
	end
	-- Toggle if no explicit "on" passed, otherwise honor it.
	local desired
	if data and data.on ~= nil then
		desired = data.on and true or false
	else
		desired = not godModeMap[target.UserId]
	end
	godModeMap[target.UserId] = desired or nil
	if desired then
		attachGodMode(target)
		notify(admin, true, string.format("God Mode הופעל ל-%s", target.Name), "#ffd43b")
	else
		clearGodConnection(target.UserId)
		notify(admin, true, string.format("God Mode כובה ל-%s", target.Name), "#868e96")
	end
end

actions.kick = function(admin, data)
	local target = findPlayerByName(data and data.username)
	if not target then
		notify(admin, false, "השחקן לא נמצא בשרת")
		return
	end
	if ALLOWED[target.UserId] then
		notify(admin, false, "אי אפשר לקיק מנהל")
		return
	end
	target:Kick("Kicked by an administrator.")
	notify(admin, true, string.format("%s הועף מהשרת", target.Name), "#ffa94d")
end

actions.ban = function(admin, data)
	local username = data and data.username
	if not username or username == "" then
		notify(admin, false, "יש להזין שם משתמש")
		return
	end
	local target = findPlayerByName(username)
	-- Try resolving even if not online (UserService API)
	local userId
	if target then
		userId = target.UserId
		if ALLOWED[userId] then
			notify(admin, false, "אי אפשר לבאן מנהל")
			return
		end
	else
		local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(username) end)
		if ok and id then userId = id end
	end
	if not userId then
		notify(admin, false, "שם משתמש לא נמצא")
		return
	end
	if ALLOWED[userId] then
		notify(admin, false, "אי אפשר לבאן מנהל")
		return
	end
	if not setBanned(userId, true) then
		notify(admin, false, "שמירת הבאן נכשלה")
		return
	end
	if target then target:Kick("Banned from this game.") end
	notify(admin, true, string.format("%s קיבל באן לצמיתות", username), "#ff5757")
end

local function teleportEveryoneToSamePlace(reason)
	local placeId = game.PlaceId
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = false
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			pcall(function()
				TeleportService:TeleportAsync(placeId, { p }, options)
			end)
		end)
	end
end

local function spawnAnimalsLocal(animalId, count)
	if not _G.AnimalManager or not _G.AnimalManager.SpawnSpecific then return 0 end
	count = math.clamp(tonumber(count) or 1, 1, 30)
	local spawned = 0
	for _ = 1, count do
		if _G.AnimalManager.SpawnSpecific(animalId) then
			spawned = spawned + 1
		end
		task.wait(0.05)
	end
	return spawned
end

actions.spawnAnimal = function(admin, data)
	local animalId = tostring(data and data.animalId or "")
	local count = tonumber(data and data.count) or 1
	local AnimalConfig = require(ReplicatedStorage:WaitForChild("AnimalConfig"))
	if not AnimalConfig.ById[animalId] then
		notify(admin, false, "חיה לא תקינה")
		return
	end
	if not _G.RoundManager or _G.RoundManager.GetState() ~= "PLAYING" then
		notify(admin, false, "אפשר לזמן חיות רק במהלך סבב")
		return
	end
	local spawned = spawnAnimalsLocal(animalId, count)
	notify(admin, true, string.format("זומנו %d חיות (%s)", spawned, animalId), "#ffa94d")
end

actions.spawnAnimalAll = function(admin, data)
	local animalId = tostring(data and data.animalId or "")
	local count = tonumber(data and data.count) or 1
	local AnimalConfig = require(ReplicatedStorage:WaitForChild("AnimalConfig"))
	if not AnimalConfig.ById[animalId] then
		notify(admin, false, "חיה לא תקינה")
		return
	end
	-- Spawn locally (this server) immediately if we're playing.
	local spawned = 0
	if _G.RoundManager and _G.RoundManager.GetState() == "PLAYING" then
		spawned = spawnAnimalsLocal(animalId, count)
	end
	-- Tell every other server to spawn too.
	pcall(function()
		MessagingService:PublishAsync(TOPIC_SPAWN_ANIMAL, {
			animalId = animalId,
			count    = count,
			sender   = admin.UserId,
		})
	end)
	notify(admin, true, string.format("בקשה להזמנת %d %s נשלחה לכל השרתים", count, animalId), "#ff5757")
end

actions.restartServer = function(admin, data)
	local reason = (data and data.reason) and tostring(data.reason) or ""
	local text = "השרת מופעל מחדש"
	if reason ~= "" then text = text .. " — " .. reason end
	localBroadcastMessage(text, "#ffa94d")
	notify(admin, true, "פעולת restart החלה", "#ffa94d")
	task.delay(3, function()
		teleportEveryoneToSamePlace(reason)
	end)
end

actions.restartAll = function(admin, data)
	local reason = (data and data.reason) and tostring(data.reason) or ""
	local text = "כל השרתים מופעלים מחדש"
	if reason ~= "" then text = text .. " — " .. reason end
	localBroadcastMessage(text, "#ff5757")
	notify(admin, true, "פעולת restart-all החלה", "#ff5757")
	-- Tell every other server to restart, too.
	pcall(function()
		MessagingService:PublishAsync(TOPIC_RESTART_ALL, { reason = reason, sender = admin.UserId })
	end)
	task.delay(3, function()
		teleportEveryoneToSamePlace(reason)
	end)
end

-- ==== Subscribe to cross-server topics ====
pcall(function()
	MessagingService:SubscribeAsync(TOPIC_GLOBAL, function(packet)
		local data = packet.Data
		if type(data) == "table" and data.text then
			-- Don't double-broadcast on the originating server (it already
			-- fires localBroadcastMessage when the action runs).
			if data.sender then
				local s = Players:GetPlayerByUserId(data.sender)
				if s and s.Parent then return end
			end
			localBroadcastMessage(data.text, data.color)
		end
	end)
end)

pcall(function()
	MessagingService:SubscribeAsync(TOPIC_SPAWN_ANIMAL, function(packet)
		local data = packet.Data
		if type(data) ~= "table" or not data.animalId then return end
		-- Don't spawn twice on the originating server.
		if data.sender then
			local s = Players:GetPlayerByUserId(data.sender)
			if s and s.Parent then return end
		end
		if not _G.RoundManager or _G.RoundManager.GetState() ~= "PLAYING" then return end
		spawnAnimalsLocal(data.animalId, data.count)
	end)
end)

pcall(function()
	MessagingService:SubscribeAsync(TOPIC_RESTART_ALL, function(packet)
		local data = packet.Data
		if type(data) == "table" then
			local reason = data.reason or ""
			-- Don't restart twice on the originating server.
			if data.sender then
				local s = Players:GetPlayerByUserId(data.sender)
				if s and s.Parent then return end
			end
			local text = "כל השרתים מופעלים מחדש"
			if reason ~= "" then text = text .. " — " .. reason end
			localBroadcastMessage(text, "#ff5757")
			task.delay(3, function() teleportEveryoneToSamePlace(reason) end)
		end
	end)
end)

-- ==== Wire remotes ====
local function bind()
	local r = getRemotes()

	r.AdminAction.OnServerEvent:Connect(function(player, payload)
		if not AdminManager.IsAdmin(player) then return end
		if type(payload) ~= "table" or type(payload.action) ~= "string" then return end
		local fn = actions[payload.action]
		if not fn then
			warn("[AdminManager] unknown action:", payload.action)
			return
		end
		local ok, err = pcall(fn, player, payload.data or {})
		if not ok then
			warn("[AdminManager] action error:", payload.action, err)
			notify(player, false, "שגיאה: " .. tostring(err))
		end
	end)

	r.IsAdmin.OnServerInvoke = function(player)
		return AdminManager.IsAdmin(player)
	end
end
bind()

_G.AdminManager = AdminManager
print("[AdminManager] Ready. Admins:", #(GameConfig.Owners or {}))

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

	-- Admin / Dev Panel
	ev("AdminAction")            -- client -> server { action, data } (server validates admin)
	ev("AdminResult")            -- server -> player { ok, message, color }
	ev("GlobalMessage")          -- server -> all clients { text, color }
	fn("IsAdmin")                -- client -> server returns bool

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
	"AdminManager",
}, 30)

if not ok then
	warn("[Main] Some managers did not register. Check script load errors.")
	for _, n in ipairs({"DataManager","RoundManager","LobbyManager","IslandBuilder","PlaneManager","AnimalManager","CombatManager","ShopManager","ProductHandler","AdminManager"}) do
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

-- Shop button (bottom-right) — also clickable so mobile/touch players can use it.
local hint = Instance.new("TextButton")
hint.Name = "ShopHint"
hint.AnchorPoint = Vector2.new(1, 1)
hint.Position = UDim2.new(1, -16, 1, -16)
hint.Size = UDim2.new(0, 220, 0, 44)
hint.BackgroundColor3 = Color3.fromRGB(36, 42, 54)
hint.BackgroundTransparency = 0.15
hint.BorderSizePixel = 0
hint.Font = Enum.Font.GothamBold
hint.TextColor3 = Color3.fromRGB(255, 220, 100)
hint.TextStrokeTransparency = 0.5
hint.TextScaled = true
hint.AutoButtonColor = true
hint.Text = Strings.HUD.ShopHint
hint.Parent = screen
do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = hint
	local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255, 200, 60); s.Thickness = 2; s.Parent = hint
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = hint
end

-- Wire the click into the shop's toggle. ShopGui creates a BindableEvent
-- "ShopToggleEvent" inside PlayerGui that we fire here.
hint.MouseButton1Click:Connect(function()
	local evt = pg:FindFirstChild("ShopToggleEvent")
	if not evt then
		-- ShopGui may still be loading; wait briefly.
		evt = pg:WaitForChild("ShopToggleEvent", 2)
	end
	if evt then evt:Fire() end
end)

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

-- Cross-script trigger: HUDGui's clickable shop button fires this BindableEvent.
local toggleEvent = pg:FindFirstChild("ShopToggleEvent")
if not toggleEvent then
	toggleEvent = Instance.new("BindableEvent")
	toggleEvent.Name = "ShopToggleEvent"
	toggleEvent.Parent = pg
end
toggleEvent.Event:Connect(toggle)

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

-- Global message banner (sent by the dev panel via AdminManager).
local globalMsg = Remotes:FindFirstChild("GlobalMessage")
if globalMsg then
	globalMsg.OnClientEvent:Connect(function(payload)
		if not payload or not payload.text then return end
		local color = Color3.fromRGB(255, 255, 255)
		local hex = tostring(payload.color or "#ffffff"):gsub("#", "")
		if #hex == 6 then
			local r = tonumber(hex:sub(1, 2), 16) or 255
			local g = tonumber(hex:sub(3, 4), 16) or 255
			local b = tonumber(hex:sub(5, 6), 16) or 255
			color = Color3.fromRGB(r, g, b)
		end
		pop(payload.text, color)
	end)
end

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

sources.DevPanelGui = [==[
-- DevPanelGui.lua
-- Place in: StarterPlayerScripts as LocalScript named "DevPanelGui"
-- (Lives in StarterPlayerScripts rather than StarterGui so the script
-- isn't reset on character respawn — that previously caused a stale
-- ScreenGui to remain stacked under a fresh one after a heal-revive.)
-- Creator/Dev Panel for game owners. Mirrors the HTML mockup: global
-- message broadcaster, give XP/weapon/heal (self or other), ban/kick,
-- restart server/all, spawn animal. Only visible to authorized UserIds.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- Defensive cleanup: destroy any pre-existing DevPanel ScreenGui from a
-- prior install or session so we don't end up with stacked GUIs whose
-- close handlers no longer work.
for _, c in ipairs(pg:GetChildren()) do
	if c:IsA("ScreenGui") and (c.Name == "DevPanelGui" or c.Name == "DevPanel_Screen") then
		c:Destroy()
	end
end

-- ==== Admin check ====
local isAdmin = false
do
	local ok, val = pcall(function() return Remotes.IsAdmin:InvokeServer() end)
	if ok then isAdmin = val == true end
end
if not isAdmin then
	-- Non-admins don't even instantiate the GUI. Silently return.
	return
end

-- ==== ScreenGui ====
local screen = Instance.new("ScreenGui")
screen.Name = "DevPanel_Screen"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 200
screen.Parent = pg

-- ==== Helpers ====
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
	return c
end
local function stroke(p, color, thick, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(255, 255, 255)
	s.Thickness = thick or 1
	s.Transparency = transparency or 0.85
	s.Parent = p
	return s
end
local function pad(p, opts)
	local up = Instance.new("UIPadding")
	up.PaddingLeft = UDim.new(0, opts.left or 0)
	up.PaddingRight = UDim.new(0, opts.right or 0)
	up.PaddingTop = UDim.new(0, opts.top or 0)
	up.PaddingBottom = UDim.new(0, opts.bottom or 0)
	up.Parent = p
	return up
end
local function listLayout(p, padding, dir)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 0)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Parent = p
	return l
end

-- ==== Devs Panel opener button (bottom-left, above the cart icon) ====
local opener = Instance.new("TextButton")
opener.Name = "DevsPanelOpener"
opener.AnchorPoint = Vector2.new(0, 1)
opener.Position = UDim2.new(0, 16, 1, -130)
opener.Size = UDim2.new(0, 150, 0, 44)
opener.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
opener.BorderSizePixel = 0
opener.Font = Enum.Font.GothamBold
opener.TextColor3 = Color3.fromRGB(255, 255, 255)
opener.TextSize = 16
opener.Text = "devs panel"
opener.AutoButtonColor = true
opener.Parent = screen
corner(opener, 12)
stroke(opener, Color3.fromRGB(255, 255, 255), 1.5, 0.7)

-- ==== Backdrop + Panel ====
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.4
backdrop.BorderSizePixel = 0
backdrop.Visible = false
backdrop.Parent = screen

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0.8, 0, 0.85, 0)
panel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
panel.BorderSizePixel = 0
panel.Parent = backdrop
corner(panel, 18)
stroke(panel, Color3.fromRGB(255, 255, 255), 2, 0.88)

-- ==== Header ====
local header = Instance.new("Frame", panel)
header.Name = "Header"
header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
header.BorderSizePixel = 0
header.Size = UDim2.new(1, 0, 0, 70)
header.Position = UDim2.new(0, 0, 0, 0)
do
	local s = Instance.new("UIStroke", header)
	s.Color = Color3.fromRGB(255, 255, 255); s.Thickness = 1; s.Transparency = 0.92
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

local headerIcon = Instance.new("Frame", header)
headerIcon.AnchorPoint = Vector2.new(0, 0.5)
headerIcon.Position = UDim2.new(0, 24, 0.5, 0)
headerIcon.Size = UDim2.new(0, 44, 0, 44)
headerIcon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
headerIcon.BorderSizePixel = 0
corner(headerIcon, 10)
local headerIconLbl = Instance.new("TextLabel", headerIcon)
headerIconLbl.BackgroundTransparency = 1
headerIconLbl.Size = UDim2.new(1, 0, 1, 0)
headerIconLbl.Font = Enum.Font.GothamBlack
headerIconLbl.TextColor3 = Color3.fromRGB(0, 0, 0)
headerIconLbl.TextSize = 22
headerIconLbl.Text = "DP"

local headerTitle = Instance.new("TextLabel", header)
headerTitle.BackgroundTransparency = 1
headerTitle.AnchorPoint = Vector2.new(0, 0.5)
headerTitle.Position = UDim2.new(0, 80, 0.5, -8)
headerTitle.Size = UDim2.new(0, 380, 0, 24)
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
headerTitle.TextSize = 22
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Text = "Creator Panel"

local headerSubtitle = Instance.new("TextLabel", header)
headerSubtitle.BackgroundTransparency = 1
headerSubtitle.AnchorPoint = Vector2.new(0, 0.5)
headerSubtitle.Position = UDim2.new(0, 80, 0.5, 12)
headerSubtitle.Size = UDim2.new(0, 380, 0, 18)
headerSubtitle.Font = Enum.Font.Gotham
headerSubtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
headerSubtitle.TextSize = 12
headerSubtitle.TextXAlignment = Enum.TextXAlignment.Left
headerSubtitle.Text = "Developer Mode"

local headerStatusDot = Instance.new("Frame", header)
headerStatusDot.AnchorPoint = Vector2.new(1, 0.5)
headerStatusDot.Position = UDim2.new(1, -130, 0.5, 0)
headerStatusDot.Size = UDim2.new(0, 10, 0, 10)
headerStatusDot.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
headerStatusDot.BorderSizePixel = 0
corner(headerStatusDot, 5)

local headerStatusText = Instance.new("TextLabel", header)
headerStatusText.BackgroundTransparency = 1
headerStatusText.AnchorPoint = Vector2.new(1, 0.5)
headerStatusText.Position = UDim2.new(1, -68, 0.5, 0)
headerStatusText.Size = UDim2.new(0, 90, 0, 18)
headerStatusText.Font = Enum.Font.Gotham
headerStatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
headerStatusText.TextSize = 13
headerStatusText.TextXAlignment = Enum.TextXAlignment.Right
headerStatusText.Text = "Connected"

local closeBtn = Instance.new("TextButton", header)
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.Position = UDim2.new(1, -16, 0.5, 0)
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 18
closeBtn.Text = "✕"
corner(closeBtn, 8)
stroke(closeBtn, Color3.fromRGB(255, 255, 255), 1, 0.9)

-- pulse animation for status dot
task.spawn(function()
	while screen.Parent do
		TweenService:Create(headerStatusDot, TweenInfo.new(1), { BackgroundTransparency = 0.5 }):Play()
		task.wait(1)
		TweenService:Create(headerStatusDot, TweenInfo.new(1), { BackgroundTransparency = 0 }):Play()
		task.wait(1)
	end
end)

-- ==== Footer ====
local footer = Instance.new("Frame", panel)
footer.Name = "Footer"
footer.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
footer.BorderSizePixel = 0
footer.Size = UDim2.new(1, 0, 0, 36)
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.new(0, 0, 1, 0)
local footerL = Instance.new("TextLabel", footer)
footerL.BackgroundTransparency = 1
footerL.AnchorPoint = Vector2.new(0, 0.5)
footerL.Position = UDim2.new(0, 24, 0.5, 0)
footerL.Size = UDim2.new(0.5, 0, 1, 0)
footerL.Font = Enum.Font.Gotham
footerL.TextColor3 = Color3.fromRGB(140, 140, 140)
footerL.TextSize = 12
footerL.TextXAlignment = Enum.TextXAlignment.Left
footerL.Text = "Esc לסגירה · F4 לפתיחה"
local footerR = Instance.new("TextLabel", footer)
footerR.BackgroundTransparency = 1
footerR.AnchorPoint = Vector2.new(1, 0.5)
footerR.Position = UDim2.new(1, -24, 0.5, 0)
footerR.Size = UDim2.new(0.5, 0, 1, 0)
footerR.Font = Enum.Font.Gotham
footerR.TextColor3 = Color3.fromRGB(140, 140, 140)
footerR.TextSize = 12
footerR.TextXAlignment = Enum.TextXAlignment.Right
footerR.Text = "v1.0.0 · Developer Mode"

-- ==== Body (scrolling) ====
local body = Instance.new("ScrollingFrame", panel)
body.Name = "Body"
body.Size = UDim2.new(1, 0, 1, -106)  -- minus header (70) and footer (36)
body.Position = UDim2.new(0, 0, 0, 70)
body.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
body.BorderSizePixel = 0
body.ScrollBarThickness = 8
body.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
body.ScrollBarImageTransparency = 0.85
body.CanvasSize = UDim2.new(0, 0, 0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
pad(body, { left = 28, right = 28, top = 24, bottom = 24 })
listLayout(body, 18)

-- Helpers to build form widgets
local function newInput(parent, props)
	local f = Instance.new("TextBox", parent)
	f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	f.BorderSizePixel = 0
	f.Font = Enum.Font.Gotham
	f.TextColor3 = Color3.fromRGB(255, 255, 255)
	f.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
	f.TextSize = 14
	f.TextXAlignment = Enum.TextXAlignment.Right
	f.ClearTextOnFocus = false
	f.Size = props.Size or UDim2.new(1, 0, 0, 38)
	for k, v in pairs(props) do f[k] = v end
	corner(f, 8)
	stroke(f, Color3.fromRGB(255, 255, 255), 1, 0.85)
	pad(f, { left = 12, right = 12, top = 4, bottom = 4 })
	return f
end

local function newLabel(parent, props)
	local l = Instance.new("TextLabel", parent)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.fromRGB(200, 200, 200)
	l.TextSize = 13
	l.TextXAlignment = Enum.TextXAlignment.Right
	l.Size = UDim2.new(1, 0, 0, 18)
	for k, v in pairs(props) do l[k] = v end
	return l
end

local function newButton(parent, props, color, textColor)
	local b = Instance.new("TextButton", parent)
	b.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	b.TextColor3 = textColor or Color3.fromRGB(0, 0, 0)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.Size = UDim2.new(1, 0, 0, 44)
	b.AutoButtonColor = true
	for k, v in pairs(props) do b[k] = v end
	corner(b, 10)
	return b
end

-- Toast (bottom of panel)
local toast = Instance.new("TextLabel", panel)
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -50)
toast.Size = UDim2.new(0, 360, 0, 44)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
toast.BackgroundTransparency = 0
toast.Font = Enum.Font.GothamBold
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.TextSize = 14
toast.Text = ""
toast.Visible = false
toast.ZIndex = 50
corner(toast, 10)
stroke(toast, Color3.fromRGB(255, 255, 255), 1, 0.7)

local function showToast(text, color)
	toast.Text = text or ""
	if color then toast.TextColor3 = color else toast.TextColor3 = Color3.fromRGB(255, 255, 255) end
	toast.Visible = true
	toast.BackgroundTransparency = 0
	toast.TextTransparency = 0
	task.delay(2.5, function()
		TweenService:Create(toast, TweenInfo.new(0.4), {
			BackgroundTransparency = 1, TextTransparency = 1,
		}):Play()
		task.wait(0.4)
		toast.Visible = false
	end)
end

-- ==== Section builder ====
local function buildSection(opts)
	local sec = Instance.new("Frame", body)
	sec.Name = opts.name or "Section"
	sec.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	sec.BorderSizePixel = 0
	sec.Size = UDim2.new(1, 0, 0, 100)  -- AutomaticSize will grow
	sec.AutomaticSize = Enum.AutomaticSize.Y
	sec.LayoutOrder = opts.order or 0
	corner(sec, 14)
	stroke(sec, Color3.fromRGB(255, 255, 255), 1, 0.9)
	pad(sec, { left = 22, right = 22, top = 18, bottom = 18 })
	listLayout(sec, 12)

	-- Header row: title + desc
	local titleRow = Instance.new("Frame", sec)
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(1, 0, 0, 46)
	titleRow.LayoutOrder = 1
	local title = Instance.new("TextLabel", titleRow)
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 0, 0, 0)
	title.Size = UDim2.new(1, 0, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Right
	title.Text = opts.title or ""
	if opts.titleColor then title.TextColor3 = opts.titleColor end
	if opts.desc then
		local desc = Instance.new("TextLabel", titleRow)
		desc.BackgroundTransparency = 1
		desc.Position = UDim2.new(0, 0, 0, 24)
		desc.Size = UDim2.new(1, 0, 0, 18)
		desc.Font = Enum.Font.Gotham
		desc.TextColor3 = Color3.fromRGB(140, 140, 140)
		desc.TextSize = 12
		desc.TextXAlignment = Enum.TextXAlignment.Right
		desc.Text = opts.desc
	end

	return sec
end

-- ==== Target toggle helper (self/other) ====
local function buildTargetToggle(parent, defaultValue)
	local row = Instance.new("Frame", parent)
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 44)
	local label = newLabel(row, { Position = UDim2.new(0, 0, 0, 0), Text = "יעד" })
	local toggle = Instance.new("Frame", row)
	toggle.Position = UDim2.new(0, 0, 0, 22)
	toggle.Size = UDim2.new(1, 0, 0, 36)
	toggle.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	toggle.BorderSizePixel = 0
	corner(toggle, 8)
	stroke(toggle, Color3.fromRGB(255, 255, 255), 1, 0.85)
	pad(toggle, { left = 4, right = 4, top = 4, bottom = 4 })
	listLayout(toggle, 4, Enum.FillDirection.Horizontal)

	local btnSelf = Instance.new("TextButton", toggle)
	btnSelf.LayoutOrder = 1
	btnSelf.Size = UDim2.new(0.5, -2, 1, 0)
	btnSelf.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	btnSelf.BorderSizePixel = 0
	btnSelf.Font = Enum.Font.GothamBold
	btnSelf.TextColor3 = Color3.fromRGB(0, 0, 0)
	btnSelf.TextSize = 13
	btnSelf.Text = "לעצמך"
	corner(btnSelf, 6)

	local btnOther = Instance.new("TextButton", toggle)
	btnOther.LayoutOrder = 2
	btnOther.Size = UDim2.new(0.5, -2, 1, 0)
	btnOther.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	btnOther.BorderSizePixel = 0
	btnOther.Font = Enum.Font.GothamBold
	btnOther.TextColor3 = Color3.fromRGB(140, 140, 140)
	btnOther.TextSize = 13
	btnOther.Text = "לשחקן אחר"
	corner(btnOther, 6)

	local state = { value = defaultValue or "self" }
	local function refresh()
		if state.value == "self" then
			btnSelf.BackgroundColor3 = Color3.fromRGB(255, 255, 255); btnSelf.TextColor3 = Color3.fromRGB(0, 0, 0)
			btnOther.BackgroundColor3 = Color3.fromRGB(20, 20, 20);  btnOther.TextColor3 = Color3.fromRGB(140, 140, 140)
		else
			btnOther.BackgroundColor3 = Color3.fromRGB(255, 255, 255); btnOther.TextColor3 = Color3.fromRGB(0, 0, 0)
			btnSelf.BackgroundColor3 = Color3.fromRGB(20, 20, 20);    btnSelf.TextColor3 = Color3.fromRGB(140, 140, 140)
		end
	end
	btnSelf.MouseButton1Click:Connect(function() state.value = "self"; refresh(); if state.onChange then state.onChange(state.value) end end)
	btnOther.MouseButton1Click:Connect(function() state.value = "other"; refresh(); if state.onChange then state.onChange(state.value) end end)
	refresh()
	return state
end

-- ==== Sections ====

-- 1. GLOBAL MESSAGE
local msgSection = buildSection{
	title = "הודעה גלובלית",
	desc  = "הודעה לכל השרתים — תוצג לכל השחקנים בכל השרתים הפעילים",
	order = 1,
}
newLabel(msgSection, { Text = "תוכן ההודעה", LayoutOrder = 2 })
local msgInput = newInput(msgSection, {
	LayoutOrder = 3,
	PlaceholderText = "מקום לרשום...",
	MultiLine = true,
	TextWrapped = true,
	ClearTextOnFocus = false,
	Size = UDim2.new(1, 0, 0, 80),
})

newLabel(msgSection, { Text = "צבע ההודעה", LayoutOrder = 4 })
local colorRow = Instance.new("Frame", msgSection)
colorRow.LayoutOrder = 5
colorRow.BackgroundTransparency = 1
colorRow.Size = UDim2.new(1, 0, 0, 80)
do
	local g = Instance.new("UIGridLayout", colorRow)
	g.CellSize = UDim2.new(0, 30, 0, 30)
	g.CellPadding = UDim2.new(0, 8, 0, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
end
local COLORS = {
	{"#ffffff", Color3.fromRGB(255,255,255)},
	{"#000000", Color3.fromRGB(0,0,0)},
	{"#868e96", Color3.fromRGB(134,142,150)},
	{"#ff5757", Color3.fromRGB(255,87,87)},
	{"#e03131", Color3.fromRGB(224,49,49)},
	{"#ffa94d", Color3.fromRGB(255,169,77)},
	{"#ff922b", Color3.fromRGB(255,146,43)},
	{"#ffd43b", Color3.fromRGB(255,212,59)},
	{"#fab005", Color3.fromRGB(250,176,5)},
	{"#a9e34b", Color3.fromRGB(169,227,75)},
	{"#51cf66", Color3.fromRGB(81,207,102)},
	{"#2f9e44", Color3.fromRGB(47,158,68)},
	{"#38d9a9", Color3.fromRGB(56,217,169)},
	{"#22b8cf", Color3.fromRGB(34,184,207)},
	{"#4dabf7", Color3.fromRGB(77,171,247)},
	{"#1971c2", Color3.fromRGB(25,113,194)},
	{"#5c7cfa", Color3.fromRGB(92,124,250)},
	{"#cc5de8", Color3.fromRGB(204,93,232)},
	{"#9c36b5", Color3.fromRGB(156,54,181)},
	{"#f783ac", Color3.fromRGB(247,131,172)},
	{"#e64980", Color3.fromRGB(230,73,128)},
	{"#a0826d", Color3.fromRGB(160,130,109)},
}
local selectedColor = "#ffffff"
local swatches = {}
for i, c in ipairs(COLORS) do
	local sw = Instance.new("TextButton", colorRow)
	sw.LayoutOrder = i
	sw.AutoButtonColor = false
	sw.BackgroundColor3 = c[2]
	sw.BorderSizePixel = 0
	sw.Text = ""
	corner(sw, 8)
	local s = Instance.new("UIStroke", sw)
	s.Color = Color3.fromRGB(255, 255, 255)
	s.Thickness = 1
	s.Transparency = 0.7
	swatches[i] = { btn = sw, hex = c[1], stroke = s }
	sw.MouseButton1Click:Connect(function()
		selectedColor = c[1]
		for _, w in ipairs(swatches) do
			w.stroke.Thickness = w.hex == selectedColor and 3 or 1
			w.stroke.Transparency = w.hex == selectedColor and 0 or 0.7
		end
		previewText.Text = msgInput.Text ~= "" and msgInput.Text or "ההודעה שלך תופיע כאן..."
		previewText.TextColor3 = c[2]
	end)
end
swatches[1].stroke.Thickness = 3; swatches[1].stroke.Transparency = 0  -- white default

newLabel(msgSection, { Text = "תצוגה מקדימה", LayoutOrder = 6 })
local previewBox = Instance.new("Frame", msgSection)
previewBox.LayoutOrder = 7
previewBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
previewBox.BackgroundTransparency = 0.4
previewBox.BorderSizePixel = 0
previewBox.Size = UDim2.new(1, 0, 0, 50)
corner(previewBox, 8)
stroke(previewBox, Color3.fromRGB(255, 255, 255), 1, 0.92)
pad(previewBox, { left = 12, right = 12, top = 8, bottom = 8 })
previewText = Instance.new("TextLabel", previewBox)
previewText.BackgroundTransparency = 1
previewText.Size = UDim2.new(1, 0, 1, 0)
previewText.Font = Enum.Font.GothamBold
previewText.TextColor3 = Color3.fromRGB(255, 255, 255)
previewText.TextSize = 14
previewText.TextXAlignment = Enum.TextXAlignment.Right
previewText.Text = "ההודעה שלך תופיע כאן..."

msgInput:GetPropertyChangedSignal("Text"):Connect(function()
	local v = msgInput.Text
	previewText.Text = v ~= "" and v or "ההודעה שלך תופיע כאן..."
end)

local sendMsgBtn = newButton(msgSection, {
	LayoutOrder = 8,
	Text = "שלח לכולם",
}, Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0))

sendMsgBtn.MouseButton1Click:Connect(function()
	local v = msgInput.Text
	if not v or v == "" then
		showToast("יש להזין הודעה", Color3.fromRGB(255, 100, 100))
		return
	end
	Remotes.AdminAction:FireServer({
		action = "globalMessage",
		data = { text = v, color = selectedColor },
	})
	msgInput.Text = ""
end)

-- 2. GIVE XP
local xpSection = buildSection{
	title = "XP",
	desc  = "הענק נקודות ניסיון — לעצמך או לשחקן אחר",
	order = 2,
}
local xpToggle = buildTargetToggle(xpSection, "self")
xpToggle.LayoutOrder = 2
local xpUserInput = newInput(xpSection, {
	LayoutOrder = 3, PlaceholderText = "שם משתמש...", Visible = false,
})
local xpUserLabel = newLabel(xpSection, { Text = "שם משתמש", LayoutOrder = 3, Visible = false })
xpUserInput.LayoutOrder = 4
xpToggle.onChange = function(v)
	local show = v == "other"
	xpUserLabel.Visible = show
	xpUserInput.Visible = show
end
newLabel(xpSection, { Text = "כמות XP", LayoutOrder = 5 })
local xpAmount = newInput(xpSection, {
	LayoutOrder = 6, PlaceholderText = "מקום לרשום...", Text = "",
})
newButton(xpSection, { LayoutOrder = 7, Text = "הענק XP" }, Color3.fromRGB(255,255,255), Color3.fromRGB(0,0,0))
	.MouseButton1Click:Connect(function()
		local amt = tonumber(xpAmount.Text)
		if not amt or amt <= 0 then return showToast("כמות XP לא תקינה", Color3.fromRGB(255,100,100)) end
		Remotes.AdminAction:FireServer({
			action = "giveXP",
			data = { target = xpToggle.value, username = xpUserInput.Text, amount = amt },
		})
	end)

-- 3. GIVE WEAPON
local weaponSection = buildSection{
	title = "נשק",
	desc  = "הענק נשק — לעצמך או לשחקן אחר",
	order = 3,
}
local weaponToggle = buildTargetToggle(weaponSection, "self")
weaponToggle.LayoutOrder = 2
local weaponUserLabel = newLabel(weaponSection, { Text = "שם משתמש", LayoutOrder = 3, Visible = false })
local weaponUserInput = newInput(weaponSection, { LayoutOrder = 4, PlaceholderText = "שם משתמש...", Visible = false })
weaponToggle.onChange = function(v)
	local show = v == "other"
	weaponUserLabel.Visible = show
	weaponUserInput.Visible = show
end
newLabel(weaponSection, { Text = "בחר נשק", LayoutOrder = 5 })
local wPickRow = Instance.new("Frame", weaponSection)
wPickRow.LayoutOrder = 6
wPickRow.BackgroundTransparency = 1
wPickRow.Size = UDim2.new(1, 0, 0, 0)
wPickRow.AutomaticSize = Enum.AutomaticSize.Y
do
	local g = Instance.new("UIGridLayout", wPickRow)
	g.CellSize = UDim2.new(0.5, -4, 0, 38)
	g.CellPadding = UDim2.new(0, 8, 0, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
end
local WEAPONS = {
	{ id = "Stick",   label = Strings.Weapons.Stick   },
	{ id = "Spear",   label = Strings.Weapons.Spear   },
	{ id = "Knife",   label = Strings.Weapons.Knife   },
	{ id = "Pistol",  label = Strings.Weapons.Pistol  },
	{ id = "Shotgun", label = Strings.Weapons.Shotgun },
}
local selectedWeapon = "Stick"
local weaponBtns = {}
for i, w in ipairs(WEAPONS) do
	local b = Instance.new("TextButton", wPickRow)
	b.LayoutOrder = i
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.fromRGB(180, 180, 180)
	b.TextSize = 14
	b.Text = w.label
	corner(b, 8)
	local s = stroke(b, Color3.fromRGB(255, 255, 255), 1, 0.85)
	weaponBtns[i] = { btn = b, id = w.id, stroke = s }
	b.MouseButton1Click:Connect(function()
		selectedWeapon = w.id
		for _, wb in ipairs(weaponBtns) do
			if wb.id == selectedWeapon then
				wb.btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255); wb.btn.TextColor3 = Color3.fromRGB(0, 0, 0); wb.stroke.Transparency = 0
			else
				wb.btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20); wb.btn.TextColor3 = Color3.fromRGB(180, 180, 180); wb.stroke.Transparency = 0.85
			end
		end
	end)
end
-- default highlight
weaponBtns[1].btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
weaponBtns[1].btn.TextColor3 = Color3.fromRGB(0, 0, 0)
weaponBtns[1].stroke.Transparency = 0

newButton(weaponSection, { LayoutOrder = 7, Text = "הענק נשק" }, Color3.fromRGB(255,255,255), Color3.fromRGB(0,0,0))
	.MouseButton1Click:Connect(function()
		Remotes.AdminAction:FireServer({
			action = "giveWeapon",
			data = { target = weaponToggle.value, username = weaponUserInput.Text, weaponId = selectedWeapon },
		})
	end)

-- 4. BAN
local banSection = buildSection{
	title = "תן באן",
	titleColor = Color3.fromRGB(255, 100, 100),
	desc  = "חסום שחקן מהמשחק לצמיתות",
	order = 4,
}
newLabel(banSection, { Text = "שם משתמש", LayoutOrder = 2 })
local banInput = newInput(banSection, { LayoutOrder = 3, PlaceholderText = "מקום לרשום..." })
newButton(banSection, { LayoutOrder = 4, Text = "תן באן" }, Color3.fromRGB(255, 87, 87), Color3.fromRGB(255, 255, 255))
	.MouseButton1Click:Connect(function()
		local v = banInput.Text
		if not v or v == "" then return showToast("יש להזין שם משתמש", Color3.fromRGB(255,100,100)) end
		Remotes.AdminAction:FireServer({ action = "ban", data = { username = v } })
		banInput.Text = ""
	end)

-- 5. KICK
local kickSection = buildSection{
	title = "תן קיק",
	titleColor = Color3.fromRGB(255, 169, 77),
	desc  = "העף שחקן מהשרת הנוכחי",
	order = 5,
}
newLabel(kickSection, { Text = "שם משתמש", LayoutOrder = 2 })
local kickInput = newInput(kickSection, { LayoutOrder = 3, PlaceholderText = "מקום לרשום..." })
newButton(kickSection, { LayoutOrder = 4, Text = "תן קיק" }, Color3.fromRGB(255, 169, 77), Color3.fromRGB(0, 0, 0))
	.MouseButton1Click:Connect(function()
		local v = kickInput.Text
		if not v or v == "" then return showToast("יש להזין שם משתמש", Color3.fromRGB(255,100,100)) end
		Remotes.AdminAction:FireServer({ action = "kick", data = { username = v } })
		kickInput.Text = ""
	end)

-- 6. HEAL
local healSection = buildSection{
	title = "רפא",
	titleColor = Color3.fromRGB(81, 207, 102),
	desc  = "החזר HP — לעצמך או לשחקן אחר",
	order = 6,
}
local healToggle = buildTargetToggle(healSection, "self")
healToggle.LayoutOrder = 2
local healUserLabel = newLabel(healSection, { Text = "שם משתמש", LayoutOrder = 3, Visible = false })
local healUserInput = newInput(healSection, { LayoutOrder = 4, PlaceholderText = "שם משתמש...", Visible = false })
healToggle.onChange = function(v)
	local show = v == "other"
	healUserLabel.Visible = show
	healUserInput.Visible = show
end
newLabel(healSection, { Text = "כמות HP (השאר ריק ל-MAX)", LayoutOrder = 5 })
local healAmount = newInput(healSection, { LayoutOrder = 6, PlaceholderText = "מקום לרשום...", Text = "" })
newButton(healSection, { LayoutOrder = 7, Text = "רפא" }, Color3.fromRGB(81, 207, 102), Color3.fromRGB(0, 0, 0))
	.MouseButton1Click:Connect(function()
		local amt = healAmount.Text
		local data = { target = healToggle.value, username = healUserInput.Text }
		if amt and amt ~= "" then
			data.amount = tonumber(amt)
			if not data.amount or data.amount <= 0 then
				return showToast("כמות HP לא תקינה", Color3.fromRGB(255,100,100))
			end
		end
		Remotes.AdminAction:FireServer({ action = "heal", data = data })
	end)

-- 6.5 GOD MODE
local godSection = buildSection{
	title = "God Mode",
	titleColor = Color3.fromRGB(255, 212, 59),
	desc  = "אי-פגיעות מוחלטת — לעצמך או לשחקן אחר. לחיצה נוספת מכבה.",
	order = 65,
}
local godToggle = buildTargetToggle(godSection, "self")
godToggle.LayoutOrder = 2
local godUserLabel = newLabel(godSection, { Text = "שם משתמש", LayoutOrder = 3, Visible = false })
local godUserInput = newInput(godSection, { LayoutOrder = 4, PlaceholderText = "שם משתמש...", Visible = false })
godToggle.onChange = function(v)
	local show = v == "other"
	godUserLabel.Visible = show
	godUserInput.Visible = show
end
newButton(godSection, { LayoutOrder = 5, Text = "הפעל / כבה God Mode" }, Color3.fromRGB(255, 212, 59), Color3.fromRGB(0, 0, 0))
	.MouseButton1Click:Connect(function()
		Remotes.AdminAction:FireServer({
			action = "godMode",
			data = { target = godToggle.value, username = godUserInput.Text },
		})
	end)

-- 7. RESTART SERVER
local rsSection = buildSection{
	title = "Restart Server",
	titleColor = Color3.fromRGB(255, 169, 77),
	desc  = "הפעל מחדש את השרת הנוכחי בלבד",
	order = 7,
}
newLabel(rsSection, { Text = "סיבה (אופציונלי)", LayoutOrder = 2 })
local rsReason = newInput(rsSection, { LayoutOrder = 3, PlaceholderText = "מקום לרשום..." })
newButton(rsSection, { LayoutOrder = 4, Text = "Restart Server" }, Color3.fromRGB(255, 169, 77), Color3.fromRGB(0, 0, 0))
	.MouseButton1Click:Connect(function()
		Remotes.AdminAction:FireServer({ action = "restartServer", data = { reason = rsReason.Text } })
		rsReason.Text = ""
	end)

-- 8. SPAWN ANIMAL (this server / all servers)
local AnimalConfig = require(ReplicatedStorage:WaitForChild("AnimalConfig"))
local animalSection = buildSection{
	title = "זמן חיה",
	titleColor = Color3.fromRGB(255, 169, 77),
	desc  = "ייצר חיה — בשרת הזה או בכל השרתים",
	order = 8,
}
newLabel(animalSection, { Text = "בחר חיה", LayoutOrder = 2 })
local aPickRow = Instance.new("Frame", animalSection)
aPickRow.LayoutOrder = 3
aPickRow.BackgroundTransparency = 1
aPickRow.Size = UDim2.new(1, 0, 0, 0)
aPickRow.AutomaticSize = Enum.AutomaticSize.Y
do
	local g = Instance.new("UIGridLayout", aPickRow)
	g.CellSize = UDim2.new(0.5, -4, 0, 38)
	g.CellPadding = UDim2.new(0, 8, 0, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
end
local ANIMALS = {
	{ id = "Dog",  label = Strings.Animals.Dog  },
	{ id = "Wolf", label = Strings.Animals.Wolf },
	{ id = "Bear", label = Strings.Animals.Bear },
	{ id = "Lion", label = Strings.Animals.Lion },
}
local selectedAnimal = "Dog"
local animalBtns = {}
for i, a in ipairs(ANIMALS) do
	local b = Instance.new("TextButton", aPickRow)
	b.LayoutOrder = i
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.fromRGB(180, 180, 180)
	b.TextSize = 14
	b.Text = a.label
	corner(b, 8)
	local s = stroke(b, Color3.fromRGB(255, 255, 255), 1, 0.85)
	animalBtns[i] = { btn = b, id = a.id, stroke = s }
	b.MouseButton1Click:Connect(function()
		selectedAnimal = a.id
		for _, ab in ipairs(animalBtns) do
			if ab.id == selectedAnimal then
				ab.btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255); ab.btn.TextColor3 = Color3.fromRGB(0, 0, 0); ab.stroke.Transparency = 0
			else
				ab.btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20); ab.btn.TextColor3 = Color3.fromRGB(180, 180, 180); ab.stroke.Transparency = 0.85
			end
		end
	end)
end
animalBtns[1].btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
animalBtns[1].btn.TextColor3 = Color3.fromRGB(0, 0, 0)
animalBtns[1].stroke.Transparency = 0

newLabel(animalSection, { Text = "כמות (ברירת מחדל 1)", LayoutOrder = 4 })
local animalCount = newInput(animalSection, { LayoutOrder = 5, PlaceholderText = "1", Text = "" })

newButton(animalSection, { LayoutOrder = 6, Text = "זמן בשרת הזה" }, Color3.fromRGB(255, 169, 77), Color3.fromRGB(0, 0, 0))
	.MouseButton1Click:Connect(function()
		local count = tonumber(animalCount.Text) or 1
		count = math.clamp(math.floor(count), 1, 30)
		Remotes.AdminAction:FireServer({
			action = "spawnAnimal",
			data = { animalId = selectedAnimal, count = count },
		})
	end)
newButton(animalSection, { LayoutOrder = 7, Text = "זמן בכל השרתים" }, Color3.fromRGB(255, 87, 87), Color3.fromRGB(255, 255, 255))
	.MouseButton1Click:Connect(function()
		local count = tonumber(animalCount.Text) or 1
		count = math.clamp(math.floor(count), 1, 30)
		Remotes.AdminAction:FireServer({
			action = "spawnAnimalAll",
			data = { animalId = selectedAnimal, count = count },
		})
	end)

-- 9. RESTART ALL
local raSection = buildSection{
	title = "Restart All Servers",
	titleColor = Color3.fromRGB(255, 87, 87),
	desc  = "הפעל מחדש את כל השרתים הפעילים — מתאים לעדכונים",
	order = 9,
}
newLabel(raSection, { Text = "סיבה (אופציונלי)", LayoutOrder = 2 })
local raReason = newInput(raSection, { LayoutOrder = 3, PlaceholderText = "מקום לרשום..." })
newButton(raSection, { LayoutOrder = 4, Text = "Restart All Servers" }, Color3.fromRGB(255, 87, 87), Color3.fromRGB(255, 255, 255))
	.MouseButton1Click:Connect(function()
		Remotes.AdminAction:FireServer({ action = "restartAll", data = { reason = raReason.Text } })
		raReason.Text = ""
	end)

-- ==== Open / close ====
local function open()
	backdrop.Visible = true
	opener.Visible = false
	panel.Size = UDim2.new(0.78, 0, 0.83, 0)
	TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.8, 0, 0.85, 0),
	}):Play()
end
local function close()
	backdrop.Visible = false
	opener.Visible = true
end

opener.MouseButton1Click:Connect(open)
closeBtn.MouseButton1Click:Connect(close)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.F4 then
		if backdrop.Visible then close() else open() end
	elseif input.KeyCode == Enum.KeyCode.Escape and backdrop.Visible then
		close()
	end
end)

-- ==== Result toasts from server ====
Remotes.AdminResult.OnClientEvent:Connect(function(payload)
	if not payload then return end
	local color = Color3.fromRGB(255, 255, 255)
	if payload.color then
		local hex = tostring(payload.color):gsub("#", "")
		if #hex == 6 then
			local r = tonumber(hex:sub(1, 2), 16) or 255
			local g = tonumber(hex:sub(3, 4), 16) or 255
			local b = tonumber(hex:sub(5, 6), 16) or 255
			color = Color3.fromRGB(r, g, b)
		end
	end
	if not payload.ok then color = Color3.fromRGB(255, 100, 100) end
	showToast(payload.message or "", color)
end)

]==]

sources.DeathGui = [==[
-- DeathGui.lua
-- Place in: StarterPlayerScripts as LocalScript named "DeathGui"
-- (Lives in StarterPlayerScripts so the script isn't reset on every
-- respawn. Otherwise the LocalScript dies after the first death, its
-- event handlers go with it, and on the *next* death no GUI appears.)
-- Dramatic death overlay: 15-second countdown, revive button, survived
-- stats, personal best display.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local Strings = require(ReplicatedStorage:WaitForChild("Strings"))

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- Defensive cleanup: destroy any pre-existing DeathGui ScreenGui (e.g.,
-- from the prior StarterGui install location).
for _, c in ipairs(pg:GetChildren()) do
	if c:IsA("ScreenGui") and (c.Name == "DeathGui" or c.Name == "DeathGui_Screen") then
		c:Destroy()
	end
end

local screen = Instance.new("ScreenGui")
screen.Name = "DeathGui_Screen"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
-- Very high DisplayOrder so a custom shop or other ScreenGui can't cover us.
screen.DisplayOrder = 1000
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
	-- Hide immediately so a delayed in-flight DeathCountdown event with a
	-- non-zero secondsLeft can't visually "stick" the GUI in a partially-
	-- visible state. The tween still runs for a smooth fade-out look.
	backdrop.Visible = false
	TweenService:Create(backdrop, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
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

-- Track the round state so we can ignore stale DeathCountdown events that
-- arrive after the round transitioned out of PLAYING (network reordering
-- in live Roblox can cause an old "secondsLeft=1" packet to arrive *after*
-- the lobby/ending state change, which previously re-showed the GUI).
local currentRoundState = "LOBBY"

-- ====== Events ======
Remotes.PlayerDied.OnClientEvent:Connect(function(payload)
	payload = payload or {}
	-- The server only fires PlayerDied during a real PLAYING-state death,
	-- so we trust it and force-update our local state tracker. (We used to
	-- guard on currentRoundState here, but that occasionally rejected a
	-- valid death event when the client hadn't received an UpdateHUD pulse
	-- yet — leaving the player in a "dead but no GUI" limbo.)
	currentRoundState = "PLAYING"
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
	-- Reject stale countdown updates received after the round has already
	-- ended. Without this guard the GUI can re-show showing a stuck count.
	if currentRoundState ~= "PLAYING" then
		stopPulse()
		hideDeath()
		return
	end
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
	if not data or not data.state then return end
	currentRoundState = data.state
	-- Anything that's not PLAYING means the death GUI should be hidden.
	if data.state ~= "PLAYING" then
		stopPulse()
		hideDeath()
	end
end)
Remotes.UpdateHUD.OnClientEvent:Connect(function(state)
	if state and state.state then
		currentRoundState = state.state
	end
	-- Only hide on alive=true if the LOCAL character is actually alive too.
	-- Without this guard, the server's HUD pulse (which fires every 0.5s)
	-- would race the player's death and reset session.Alive to false:
	-- the client's Humanoid.Died handler shows the GUI; ~half a second
	-- later the server pulse arrives with stale alive=true; we'd hide
	-- the GUI even though the player is still dead.
	if state and state.alive then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			stopPulse()
			hideDeath()
		end
	end
	-- Defense in depth: hide if the round itself is no longer playing.
	if state and state.state and state.state ~= "PLAYING" and backdrop.Visible then
		stopPulse()
		hideDeath()
	end
end)

-- Client-side fallback: if the player's character dies and the server's
-- PlayerDied event doesn't reach us (or arrives delayed), we still pop the
-- GUI so the player isn't left in spectator limbo with no UI.
local function watchCharacter(char)
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
	if not hum then return end
	hum.Died:Connect(function()
		if currentRoundState == "LOBBY" then return end
		print("[DeathGui] Client-side Humanoid.Died fired; showing GUI")
		-- Force-show with neutral defaults; the server's PlayerDied
		-- event (if it arrives later) will overwrite the texts.
		currentRoundState = "PLAYING"
		killedBy.Text = string.format(Strings.Death.KilledBy, "סכנה")
		survivedValue.Text = fmtTime(0)
		bestValue.Text     = fmtTime(0)
		recordBadge.Visible = false
		reviveBtn.Visible = true
		reviveBtn.Text = Strings.Death.ReviveBtn
		countLabel.Text = "15"
		countSub.Text = string.format(Strings.Death.ReturningInSec, 15) .. " " .. Strings.Death.ReturningSec
		if not backdrop.Visible then
			showDeath()
			startPulse()
		end
	end)
end
if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)

print("[DeathGui] Initialized in StarterPlayerScripts. DisplayOrder = " .. tostring(screen.DisplayOrder))

]==]


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
track(ServerScriptService, "AdminManager",    "Script", sources.AdminManager)
track(ServerScriptService, "Main",            "Script", sources.Main)

track(StarterGui, "HUDGui",          "LocalScript", sources.HUDGui)
track(StarterGui, "LobbyGui",        "LocalScript", sources.LobbyGui)
track(StarterGui, "ShopGui",         "LocalScript", sources.ShopGui)
track(StarterGui, "NotificationGui", "LocalScript", sources.NotificationGui)

for _, name in ipairs({ "DevPanelGui", "DeathGui" }) do
	local old = StarterGui:FindFirstChild(name)
	if old then old:Destroy() end
end

track(StarterPlayerScripts, "ClientCombat",     "LocalScript", sources.ClientCombat)
track(StarterPlayerScripts, "EffectsClient",    "LocalScript", sources.EffectsClient)
track(StarterPlayerScripts, "CameraClient",     "LocalScript", sources.CameraClient)
track(StarterPlayerScripts, "PlayerTagsClient", "LocalScript", sources.PlayerTagsClient)
track(StarterPlayerScripts, "DevPanelGui",      "LocalScript", sources.DevPanelGui)
track(StarterPlayerScripts, "DeathGui",         "LocalScript", sources.DeathGui)

local Lighting = game:GetService("Lighting")
Lighting.ClockTime = 14
Lighting.Brightness = 2

pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

print("==============================================================")
print("[Install] Island Survival v3.7 installed successfully")
print(string.format("[Install] %d scripts replaced", #installed))
print("[Install] Stop the game and Play again to pick up the new code.")
print("==============================================================")
