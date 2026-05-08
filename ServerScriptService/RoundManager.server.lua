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

	-- Client may also notify us if it sees Humanoid.Died but the server
	-- hasn't processed it (god-mode race, replication oddities, etc.).
	-- We only act if the character is *actually* dead per the server.
	getRemotes().ClientReportedDeath.OnServerEvent:Connect(function(player)
		local char = player.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then
			RoundManager.OnPlayerDied(player, "סכנה")
		end
	end)

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
