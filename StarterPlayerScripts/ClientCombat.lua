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
