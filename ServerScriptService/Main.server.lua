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
	ev("ClientReportedDeath")    -- client -> server (notice me, server ran into a desync)
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
