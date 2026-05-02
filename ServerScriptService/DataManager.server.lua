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
	return { OwnsShotgun = false, Version = GameConfig.DataStoreVersion }
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
