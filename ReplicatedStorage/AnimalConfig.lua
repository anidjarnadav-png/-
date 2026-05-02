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
