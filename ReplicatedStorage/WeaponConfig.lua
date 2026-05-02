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
