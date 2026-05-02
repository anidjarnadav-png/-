-- NotificationGui.lua
-- Place in: StarterGui as LocalScript named "NotificationGui"
-- Toast notifications stacked top-right. Driven by ToastNotify RemoteEvent.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

local screen = Instance.new("ScreenGui")
screen.Name = "NotificationGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = pg

local container = Instance.new("Frame", screen)
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.new(0.5, 0, 0, 200)
container.Size = UDim2.new(0, 480, 1, -220)
container.BackgroundTransparency = 1

local layout = Instance.new("UIListLayout", container)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function pop(text, color)
	local f = Instance.new("Frame", container)
	f.Size = UDim2.new(0, 460, 0, 50)
	f.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner", f); c.CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke", f); s.Color = color or Color3.fromRGB(180,180,180); s.Thickness = 2

	local lbl = Instance.new("TextLabel", f)
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, -20, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = color or Color3.fromRGB(240, 240, 240)
	lbl.TextScaled = true
	lbl.Text = text

	-- entrance
	f.BackgroundTransparency = 1
	lbl.TextTransparency = 1
	s.Transparency = 1
	TweenService:Create(f, TweenInfo.new(0.25), { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(lbl, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	TweenService:Create(s, TweenInfo.new(0.25), { Transparency = 0 }):Play()

	task.delay(3.5, function()
		TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.wait(0.5)
		f:Destroy()
	end)
end

Remotes.ToastNotify.OnClientEvent:Connect(function(payload)
	if not payload or not payload.text then return end
	pop(payload.text, payload.color)
end)
