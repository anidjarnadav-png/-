-- GameConfig.lua
-- Place in: ReplicatedStorage > ModuleScript named "GameConfig"

local GameConfig = {}

-- Currency settings
GameConfig.CURRENCY_NAME = "Cash"
GameConfig.STARTING_CASH = 0

-- Dropper settings (cash per drop, interval in seconds)
GameConfig.DROPPERS = {
	{name = "Basic Dropper",    cashPerDrop = 1,   interval = 2.0, cost = 0},
	{name = "Silver Dropper",   cashPerDrop = 5,   interval = 2.0, cost = 100},
	{name = "Gold Dropper",     cashPerDrop = 15,  interval = 1.5, cost = 500},
	{name = "Diamond Dropper",  cashPerDrop = 50,  interval = 1.0, cost = 2000},
	{name = "Rainbow Dropper",  cashPerDrop = 200, interval = 0.8, cost = 10000},
}

-- Upgrade buttons (buildings/machines to purchase)
GameConfig.UPGRADES = {
	{id = "upgrade_1", name = "Upgrade 1", description = "Double your income",  cost = 250,   multiplier = 2},
	{id = "upgrade_2", name = "Upgrade 2", description = "Triple your income",  cost = 1500,  multiplier = 3},
	{id = "upgrade_3", name = "Upgrade 3", description = "5x your income",      cost = 8000,  multiplier = 5},
	{id = "upgrade_4", name = "Upgrade 4", description = "10x your income",     cost = 50000, multiplier = 10},
}

-- Plot settings
GameConfig.NUM_PLOTS = 4
GameConfig.PLOT_SIZE = Vector3.new(100, 1, 100)
GameConfig.PLOT_SPACING = 120

-- DataStore name
GameConfig.DATASTORE_NAME = "TycoonData_v1"

-- Team colors for plots
GameConfig.TEAM_COLORS = {
	BrickColor.new("Bright red"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Bright green"),
	BrickColor.new("Bright yellow"),
}

return GameConfig
