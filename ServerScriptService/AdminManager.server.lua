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
		-- Round not playing (or revive failed) — just LoadCharacter. We must
		-- also resync the session: sess.Alive needs to match reality so the
		-- next death is processed correctly by RoundManager.OnPlayerDied.
		target:LoadCharacter()
		local sess = dm().GetSession(target)
		sess.Alive = true
		sess.UsedRevive = false
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
