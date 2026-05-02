-- DeathGui.lua
-- Place in: StarterGui as LocalScript named "DeathGui"
-- Death overlay with revive (Robux) button.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage:WaitForChild("Strings"))

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

local screen = Instance.new("ScreenGui")
screen.Name = "DeathGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = pg

local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c end
local function stroke(p, c, t) local s = Instance.new("UIStroke"); s.Color = c; s.Thickness = t or 1; s.Parent = p; return s end

local backdrop = Instance.new("Frame", screen)
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
backdrop.BackgroundTransparency = 0.45
backdrop.BorderSizePixel = 0
backdrop.Visible = false

local panel = Instance.new("Frame", backdrop)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 460, 0, 280)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
panel.BorderSizePixel = 0
corner(panel, 14)
stroke(panel, Color3.fromRGB(220, 80, 60), 3)

local title = Instance.new("TextLabel", panel)
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 12)
title.Size = UDim2.new(1, -24, 0, 50)
title.Font = Enum.Font.GothamBlack
title.TextColor3 = Color3.fromRGB(255, 70, 70)
title.TextScaled = true
title.Text = Strings.Death.Title

local sub = Instance.new("TextLabel", panel)
sub.BackgroundTransparency = 1
sub.Position = UDim2.new(0, 12, 0, 64)
sub.Size = UDim2.new(1, -24, 0, 30)
sub.Font = Enum.Font.Gotham
sub.TextColor3 = Color3.fromRGB(220, 220, 220)
sub.TextScaled = true
sub.Text = ""

local reviveBtn = Instance.new("TextButton", panel)
reviveBtn.AnchorPoint = Vector2.new(0.5, 0)
reviveBtn.Position = UDim2.new(0.5, 0, 0, 110)
reviveBtn.Size = UDim2.new(0, 360, 0, 60)
reviveBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 60)
reviveBtn.Font = Enum.Font.GothamBold
reviveBtn.TextColor3 = Color3.fromRGB(40, 30, 0)
reviveBtn.TextScaled = true
reviveBtn.Text = Strings.Death.ReviveBtn
corner(reviveBtn, 10)

local spectateBtn = Instance.new("TextButton", panel)
spectateBtn.AnchorPoint = Vector2.new(0.5, 0)
spectateBtn.Position = UDim2.new(0.5, 0, 0, 180)
spectateBtn.Size = UDim2.new(0, 360, 0, 50)
spectateBtn.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
spectateBtn.Font = Enum.Font.Gotham
spectateBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
spectateBtn.TextScaled = true
spectateBtn.Text = Strings.Death.SpectateBtn
corner(spectateBtn, 8)

reviveBtn.MouseButton1Click:Connect(function()
	Remotes.PromptRevive:FireServer()
end)
spectateBtn.MouseButton1Click:Connect(function()
	backdrop.Visible = false
end)

Remotes.PlayerDied.OnClientEvent:Connect(function(payload)
	payload = payload or {}
	sub.Text = string.format(Strings.Death.KilledBy, payload.killedBy or "סכנה")
	if payload.canRevive then
		reviveBtn.Visible = true
		reviveBtn.Text = Strings.Death.ReviveBtn
	else
		reviveBtn.Visible = false
	end
	backdrop.Visible = true
end)

-- Hide on respawn / state changes
Remotes.RoundStateChanged.OnClientEvent:Connect(function(data)
	if data and (data.state == "LOBBY" or data.state == "ENDING") then
		backdrop.Visible = false
	end
end)
Remotes.UpdateHUD.OnClientEvent:Connect(function(state)
	if state and state.alive then
		backdrop.Visible = false
	end
end)
