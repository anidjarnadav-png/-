-- DeathGui.lua
-- Place in: StarterGui as LocalScript named "DeathGui"
-- Dramatic death overlay: 15-second countdown, revive button, survived stats,
-- personal best display.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local Strings = require(ReplicatedStorage:WaitForChild("Strings"))

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

local screen = Instance.new("ScreenGui")
screen.Name = "DeathGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 50
screen.Parent = pg

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
	return c
end
local function stroke(p, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(0,0,0)
	s.Thickness = thick or 1
	s.Parent = p
	return s
end
local function fmtTime(sec)
	sec = math.max(0, math.floor(sec or 0))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- Vignette / red gradient backdrop
local backdrop = Instance.new("Frame", screen)
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.45
backdrop.BorderSizePixel = 0
backdrop.Visible = false

local vignette = Instance.new("UIGradient", backdrop)
vignette.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 0, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 0, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0)),
})
vignette.Rotation = 90

-- Main card
local card = Instance.new("Frame", backdrop)
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.new(0.5, 0, 0.5, 0)
card.Size = UDim2.new(0, 540, 0, 460)
card.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
card.BorderSizePixel = 0
corner(card, 18)
stroke(card, Color3.fromRGB(220, 60, 60), 4)

local cardGradient = Instance.new("UIGradient", card)
cardGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 18, 22)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 14, 18)),
})
cardGradient.Rotation = 90

-- Title "מתת" with shadow
local titleShadow = Instance.new("TextLabel", card)
titleShadow.BackgroundTransparency = 1
titleShadow.Position = UDim2.new(0, 14, 0, 22)
titleShadow.Size = UDim2.new(1, -28, 0, 64)
titleShadow.Font = Enum.Font.GothamBlack
titleShadow.TextColor3 = Color3.fromRGB(120, 20, 20)
titleShadow.TextStrokeTransparency = 0.3
titleShadow.TextScaled = true
titleShadow.Text = Strings.Death.Title
titleShadow.ZIndex = 1
titleShadow.TextTransparency = 0.5

local title = Instance.new("TextLabel", card)
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 18)
title.Size = UDim2.new(1, -24, 0, 64)
title.Font = Enum.Font.GothamBlack
title.TextColor3 = Color3.fromRGB(255, 80, 80)
title.TextStrokeTransparency = 0
title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
title.TextScaled = true
title.Text = Strings.Death.Title
title.ZIndex = 2

-- Killed-by sub
local killedBy = Instance.new("TextLabel", card)
killedBy.BackgroundTransparency = 1
killedBy.Position = UDim2.new(0, 12, 0, 90)
killedBy.Size = UDim2.new(1, -24, 0, 28)
killedBy.Font = Enum.Font.Gotham
killedBy.TextColor3 = Color3.fromRGB(220, 220, 220)
killedBy.TextScaled = true
killedBy.Text = ""

-- Survived time + best (centered row)
local statsFrame = Instance.new("Frame", card)
statsFrame.BackgroundTransparency = 1
statsFrame.Position = UDim2.new(0, 16, 0, 124)
statsFrame.Size = UDim2.new(1, -32, 0, 60)
local statsLayout = Instance.new("UIListLayout", statsFrame)
statsLayout.FillDirection = Enum.FillDirection.Horizontal
statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Padding = UDim.new(0, 16)

local function makeStat(parent, headerText, valueText, valueColor)
	local box = Instance.new("Frame", parent)
	box.BackgroundColor3 = Color3.fromRGB(34, 38, 46)
	box.BorderSizePixel = 0
	box.Size = UDim2.new(0, 220, 0, 60)
	corner(box, 10)
	stroke(box, Color3.fromRGB(60, 65, 80), 1)
	local h = Instance.new("TextLabel", box)
	h.BackgroundTransparency = 1
	h.Position = UDim2.new(0, 6, 0, 4)
	h.Size = UDim2.new(1, -12, 0, 18)
	h.Font = Enum.Font.Gotham
	h.TextColor3 = Color3.fromRGB(160, 170, 190)
	h.TextScaled = true
	h.Text = headerText
	local v = Instance.new("TextLabel", box)
	v.BackgroundTransparency = 1
	v.Position = UDim2.new(0, 6, 0, 24)
	v.Size = UDim2.new(1, -12, 0, 32)
	v.Font = Enum.Font.GothamBold
	v.TextColor3 = valueColor or Color3.fromRGB(255, 255, 255)
	v.TextScaled = true
	v.Text = valueText
	return box, v
end

local _, survivedValue = makeStat(statsFrame, "שרדת", "0:00", Color3.fromRGB(255, 220, 120))
local _, bestValue     = makeStat(statsFrame, "שיא אישי", "0:00", Color3.fromRGB(120, 220, 255))

-- Big countdown number
local countLabel = Instance.new("TextLabel", card)
countLabel.BackgroundTransparency = 1
countLabel.Position = UDim2.new(0, 12, 0, 196)
countLabel.Size = UDim2.new(1, -24, 0, 110)
countLabel.Font = Enum.Font.GothamBlack
countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
countLabel.TextStrokeTransparency = 0
countLabel.TextScaled = true
countLabel.Text = "15"

local countSub = Instance.new("TextLabel", card)
countSub.BackgroundTransparency = 1
countSub.Position = UDim2.new(0, 12, 0, 304)
countSub.Size = UDim2.new(1, -24, 0, 22)
countSub.Font = Enum.Font.Gotham
countSub.TextColor3 = Color3.fromRGB(180, 180, 180)
countSub.TextScaled = true
countSub.Text = string.format(Strings.Death.ReturningInSec, 15) .. " " .. Strings.Death.ReturningSec

-- Revive button
local reviveBtn = Instance.new("TextButton", card)
reviveBtn.AnchorPoint = Vector2.new(0.5, 0)
reviveBtn.Position = UDim2.new(0.5, 0, 0, 340)
reviveBtn.Size = UDim2.new(0, 460, 0, 60)
reviveBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 60)
reviveBtn.Font = Enum.Font.GothamBold
reviveBtn.TextColor3 = Color3.fromRGB(40, 30, 0)
reviveBtn.TextScaled = true
reviveBtn.Text = Strings.Death.ReviveBtn
corner(reviveBtn, 12)
stroke(reviveBtn, Color3.fromRGB(180, 120, 30), 2)

-- New record badge (hidden until earned)
local recordBadge = Instance.new("TextLabel", card)
recordBadge.AnchorPoint = Vector2.new(0.5, 0)
recordBadge.Position = UDim2.new(0.5, 0, 0, 410)
recordBadge.Size = UDim2.new(0, 380, 0, 38)
recordBadge.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
recordBadge.BackgroundTransparency = 0.1
recordBadge.Font = Enum.Font.GothamBlack
recordBadge.TextColor3 = Color3.fromRGB(40, 30, 0)
recordBadge.TextScaled = true
recordBadge.Text = ""
recordBadge.Visible = false
corner(recordBadge, 8)
stroke(recordBadge, Color3.fromRGB(180, 140, 30), 2)

-- ====== Animation ======
local function showDeath()
	backdrop.Visible = true
	card.Position = UDim2.new(0.5, 0, 0.4, 0)
	card.Size = UDim2.new(0, 460, 0, 380)
	backdrop.BackgroundTransparency = 1
	TweenService:Create(backdrop, TweenInfo.new(0.4), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 540, 0, 460),
	}):Play()
end
local function hideDeath()
	-- Hide immediately so a delayed in-flight DeathCountdown event with a
	-- non-zero secondsLeft can't visually "stick" the GUI in a partially-
	-- visible state. The tween still runs for a smooth fade-out look.
	backdrop.Visible = false
	TweenService:Create(backdrop, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
end

reviveBtn.MouseButton1Click:Connect(function()
	Remotes.PromptRevive:FireServer()
end)

-- Pulse the count label
local pulsing = false
local function startPulse()
	if pulsing then return end
	pulsing = true
	task.spawn(function()
		while pulsing and backdrop.Visible do
			TweenService:Create(countLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0.2,
			}):Play()
			task.wait(0.4)
			TweenService:Create(countLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 0,
			}):Play()
			task.wait(0.6)
		end
	end)
end
local function stopPulse() pulsing = false end

-- Track the round state so we can ignore stale DeathCountdown events that
-- arrive after the round transitioned out of PLAYING (network reordering
-- in live Roblox can cause an old "secondsLeft=1" packet to arrive *after*
-- the lobby/ending state change, which previously re-showed the GUI).
local currentRoundState = "LOBBY"

-- ====== Events ======
Remotes.PlayerDied.OnClientEvent:Connect(function(payload)
	payload = payload or {}
	-- The server only fires PlayerDied during a real PLAYING-state death,
	-- so we trust it and force-update our local state tracker. (We used to
	-- guard on currentRoundState here, but that occasionally rejected a
	-- valid death event when the client hadn't received an UpdateHUD pulse
	-- yet — leaving the player in a "dead but no GUI" limbo.)
	currentRoundState = "PLAYING"
	killedBy.Text = string.format(Strings.Death.KilledBy, payload.killedBy or "סכנה")
	survivedValue.Text = fmtTime(payload.survivedSeconds or 0)
	bestValue.Text     = fmtTime(payload.bestSeconds or 0)
	if payload.canRevive then
		reviveBtn.Visible = true
		reviveBtn.Text = Strings.Death.ReviveBtn
	else
		reviveBtn.Visible = false
	end
	if payload.isNewRecord then
		recordBadge.Visible = true
		recordBadge.Text = string.format(Strings.Death.NewBestTime, fmtTime(payload.bestSeconds or 0))
	else
		recordBadge.Visible = false
	end
	countLabel.Text = "15"
	countSub.Text = string.format(Strings.Death.ReturningInSec, 15) .. " " .. Strings.Death.ReturningSec
	showDeath()
	startPulse()
end)

Remotes.DeathCountdown.OnClientEvent:Connect(function(payload)
	if not payload then return end
	-- Reject stale countdown updates received after the round has already
	-- ended. Without this guard the GUI can re-show showing a stuck count.
	if currentRoundState ~= "PLAYING" then
		stopPulse()
		hideDeath()
		return
	end
	if not backdrop.Visible then
		showDeath()
		startPulse()
	end
	survivedValue.Text = fmtTime(payload.survivedSeconds or 0)
	bestValue.Text     = fmtTime(payload.bestSeconds or 0)

	local left = payload.secondsLeft or 0
	if left > 0 then
		countLabel.Text = tostring(left)
		countSub.Text = string.format(Strings.Death.ReturningInSec, left) .. " " .. Strings.Death.ReturningSec
		-- Color shifts from yellow -> orange -> red as time runs out
		if left <= 5 then
			countLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		elseif left <= 10 then
			countLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
		else
			countLabel.TextColor3 = Color3.fromRGB(255, 240, 200)
		end
		reviveBtn.Visible = payload.canRevive == true
	else
		stopPulse()
		hideDeath()
	end

	if payload.isNewRecord then
		recordBadge.Visible = true
		recordBadge.Text = string.format(Strings.Death.NewBestTime, fmtTime(payload.bestSeconds or 0))
	end
end)

-- Hide on respawn / state changes
Remotes.RoundStateChanged.OnClientEvent:Connect(function(data)
	if not data or not data.state then return end
	currentRoundState = data.state
	-- Anything that's not PLAYING means the death GUI should be hidden.
	if data.state ~= "PLAYING" then
		stopPulse()
		hideDeath()
	end
end)
Remotes.UpdateHUD.OnClientEvent:Connect(function(state)
	if state and state.state then
		currentRoundState = state.state
	end
	if state and state.alive then
		stopPulse()
		hideDeath()
	end
	-- Defense in depth: if the HUD says we're not in PLAYING, hide.
	if state and state.state and state.state ~= "PLAYING" and backdrop.Visible then
		stopPulse()
		hideDeath()
	end
end)
