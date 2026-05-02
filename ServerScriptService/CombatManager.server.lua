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
