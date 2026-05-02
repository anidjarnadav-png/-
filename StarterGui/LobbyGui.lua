-- LobbyGui.lua
-- Place in: StarterGui as LocalScript named "LobbyGui"
-- Lobby instructions + countdown overlay.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")

local Strings = require(ReplicatedStorage:WaitForChild("Strings"))

local player  = Players.LocalPlayer
local pg      = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local screen = Instance.new("ScreenGui")
screen.Name = "LobbyGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = pg

local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c end
local function stroke(p, c, t) local s = Instance.new("UIStroke"); s.Color = c; s.Thickness = t or 1; s.Parent = p; return s end

-- Welcome banner (always visible in LOBBY)
local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 24)
banner.Size = UDim2.new(0, 540, 0, 70)
banner.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
banner.BackgroundTransparency = 0.2
banner.BorderSizePixel = 0
banner.Parent = screen
corner(banner, 12)
stroke(banner, Color3.fromRGB(255, 180, 60), 2)

local title = Instance.new("TextLabel", banner)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -20, 0, 32)
title.Position = UDim2.new(0, 10, 0, 6)
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 220, 120)
title.TextScaled = true
title.Text = Strings.Lobby.Welcome

local sub = Instance.new("TextLabel", banner)
sub.BackgroundTransparency = 1
sub.Size = UDim2.new(1, -20, 0, 28)
sub.Position = UDim2.new(0, 10, 0, 38)
sub.Font = Enum.Font.Gotham
sub.TextColor3 = Color3.fromRGB(220, 220, 220)
sub.TextScaled = true
sub.Text = Strings.Lobby.Instruction

-- Countdown overlay (shown only during COUNTDOWN)
local countFrame = Instance.new("Frame")
countFrame.Name = "Countdown"
countFrame.AnchorPoint = Vector2.new(0.5, 0.5)
countFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
countFrame.Size = UDim2.new(0, 380, 0, 220)
countFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
countFrame.BackgroundTransparency = 0.15
countFrame.BorderSizePixel = 0
countFrame.Visible = false
countFrame.Parent = screen
corner(countFrame, 18)
stroke(countFrame, Color3.fromRGB(255, 140, 0), 3)

local countTitle = Instance.new("TextLabel", countFrame)
countTitle.BackgroundTransparency = 1
countTitle.Size = UDim2.new(1, -20, 0, 40)
countTitle.Position = UDim2.new(0, 10, 0, 12)
countTitle.Font = Enum.Font.GothamBold
countTitle.TextColor3 = Color3.fromRGB(255, 220, 120)
countTitle.TextScaled = true
countTitle.Text = "מתחילים בעוד..."

local countNum = Instance.new("TextLabel", countFrame)
countNum.BackgroundTransparency = 1
countNum.Size = UDim2.new(1, -20, 0, 130)
countNum.Position = UDim2.new(0, 10, 0, 60)
countNum.Font = Enum.Font.GothamBlack
countNum.TextColor3 = Color3.fromRGB(255, 255, 255)
countNum.TextScaled = true
countNum.Text = "10"

local hint = Instance.new("TextLabel", countFrame)
hint.BackgroundTransparency = 1
hint.Size = UDim2.new(1, -20, 0, 22)
hint.Position = UDim2.new(0, 10, 1, -28)
hint.Font = Enum.Font.Gotham
hint.TextColor3 = Color3.fromRGB(200, 200, 200)
hint.TextScaled = true
hint.Text = Strings.Lobby.StepOff

-- Top center "STATE" indicator (FLIGHT, CRASH)
local stateFrame = Instance.new("TextLabel")
stateFrame.AnchorPoint = Vector2.new(0.5, 0)
stateFrame.Position = UDim2.new(0.5, 0, 0, 110)
stateFrame.Size = UDim2.new(0, 360, 0, 60)
stateFrame.BackgroundColor3 = Color3.fromRGB(180, 50, 40)
stateFrame.BackgroundTransparency = 0.2
stateFrame.Font = Enum.Font.GothamBold
stateFrame.TextColor3 = Color3.fromRGB(255, 255, 255)
stateFrame.TextScaled = true
stateFrame.Text = ""
stateFrame.BorderSizePixel = 0
stateFrame.Visible = false
stateFrame.Parent = screen
corner(stateFrame, 10)

local function setBannerVisible(v) banner.Visible = v end

Remotes.LobbyCountdown.OnClientEvent:Connect(function(payload)
	if not payload then return end
	if payload.cancelled then
		countFrame.Visible = false
		return
	end
	countFrame.Visible = true
	countNum.Text = tostring(payload.secondsLeft)
	-- pulse
	countNum.TextTransparency = 0
	local goal = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(countNum, goal, { TextTransparency = 0.3 }):Play()
end)

Remotes.RoundStateChanged.OnClientEvent:Connect(function(data)
	if not data or not data.state then return end
	local s = data.state
	if s == "LOBBY" then
		setBannerVisible(true)
		countFrame.Visible = false
		stateFrame.Visible = false
	elseif s == "COUNTDOWN" then
		setBannerVisible(false)
		stateFrame.Visible = false
	elseif s == "BOARDING" then
		setBannerVisible(false)
		countFrame.Visible = false
		stateFrame.Text = Strings.Lobby.Boarding
		stateFrame.BackgroundColor3 = Color3.fromRGB(60, 110, 200)
		stateFrame.Visible = true
	elseif s == "FLIGHT" then
		stateFrame.Text = Strings.Flight.TakeOff
		stateFrame.BackgroundColor3 = Color3.fromRGB(60, 110, 200)
		stateFrame.Visible = true
		task.delay(5, function() if data.state == "FLIGHT" then stateFrame.Text = Strings.Flight.EngineFailure end end)
	elseif s == "CRASH" then
		stateFrame.Text = Strings.Flight.Crash
		stateFrame.BackgroundColor3 = Color3.fromRGB(180, 50, 40)
		stateFrame.Visible = true
	elseif s == "PLAYING" then
		stateFrame.Visible = false
		countFrame.Visible = false
		setBannerVisible(false)
	elseif s == "ENDING" then
		stateFrame.Text = Strings.Round.AllDead
		stateFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		stateFrame.Visible = true
	end
end)
