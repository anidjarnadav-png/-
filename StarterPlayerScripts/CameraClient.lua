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
