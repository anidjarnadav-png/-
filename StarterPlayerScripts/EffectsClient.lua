-- EffectsClient.lua
-- Place in: StarterPlayerScripts as LocalScript named "EffectsClient"
-- Floating damage numbers, hit sparks, and animal-death poof.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local Debris           = game:GetService("Debris")
local Workspace        = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function spawnDamageNumber(position, amount, color)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Parent = Workspace

	local bb = Instance.new("BillboardGui", part)
	bb.Size = UDim2.new(0, 80, 0, 32)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	local lbl = Instance.new("TextLabel", bb)
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextColor3 = color or Color3.fromRGB(255, 220, 80)
	lbl.TextStrokeTransparency = 0
	lbl.Text = "-" .. tostring(amount)

	-- Float up and fade
	local up = TweenService:Create(part, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = position + Vector3.new(0, 4, 0)
	})
	up:Play()
	task.delay(0.4, function()
		TweenService:Create(lbl, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(part, 1.0)
end

local function spawnDeathPoof(position, name)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position + Vector3.new(0, 3, 0)
	part.Parent = Workspace

	local bb = Instance.new("BillboardGui", part)
	bb.Size = UDim2.new(0, 220, 0, 60)
	bb.AlwaysOnTop = true
	local lbl = Instance.new("TextLabel", bb)
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
	lbl.TextStrokeTransparency = 0
	lbl.TextScaled = true
	lbl.Text = (name and name .. " - הוכרע!") or "הוכרע!"

	-- Smoke
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(80, 30, 30)
	smoke.Size = 4
	smoke.RiseVelocity = 4
	smoke.Opacity = 0.5
	smoke.Parent = part

	TweenService:Create(part, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
		Position = position + Vector3.new(0, 8, 0)
	}):Play()
	task.delay(0.6, function()
		TweenService:Create(lbl, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(part, 2)
end

Remotes.ShowDamage.OnClientEvent:Connect(function(payload)
	if not payload then return end
	spawnDamageNumber(payload.position, payload.amount, payload.color)
end)

Remotes.AnimalDied.OnClientEvent:Connect(function(payload)
	if not payload then return end
	spawnDeathPoof(payload.position, payload.displayName)
end)

Remotes.CrashEffect.OnClientEvent:Connect(function(payload)
	if not payload then return end
	-- big red flash
	local sg = Instance.new("ScreenGui", Players.LocalPlayer:WaitForChild("PlayerGui"))
	sg.IgnoreGuiInset = true
	local f = Instance.new("Frame", sg)
	f.Size = UDim2.new(1, 0, 1, 0)
	f.BackgroundColor3 = Color3.fromRGB(220, 60, 30)
	f.BackgroundTransparency = 0.2
	f.BorderSizePixel = 0
	TweenService:Create(f, TweenInfo.new(1.0), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(sg, 1.5)
end)
