-- HUDGui.lua
-- Place in: StarterGui as LocalScript named "HUDGui"
-- Heads-up display: HP, XP, weapon, time, shop hint.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- Build root GUI
local screen = Instance.new("ScreenGui")
screen.Name = "HUDGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = pg

local function makeFrame(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 0.2
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end
local function makeLabel(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.fromRGB(240, 240, 240)
	t.TextStrokeTransparency = 0.5
	t.TextScaled = true
	t.TextXAlignment = Enum.TextXAlignment.Right
	for k, v in pairs(props) do t[k] = v end
	t.Parent = parent
	return t
end
local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end
local function stroke(parent, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(0,0,0)
	s.Thickness = t or 1
	s.Parent = parent
	return s
end

-- Top-left container
local container = makeFrame(screen, {
	Name = "Container",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 16, 0, 16),
	Size = UDim2.new(0, 280, 0, 130),
	BackgroundTransparency = 0.3,
})
corner(container, 12)
stroke(container, Color3.fromRGB(80, 90, 110), 1)

-- HP bar
local hpFrame = makeFrame(container, {
	Position = UDim2.new(0, 12, 0, 12),
	Size = UDim2.new(1, -24, 0, 28),
	BackgroundColor3 = Color3.fromRGB(40, 40, 40),
	BackgroundTransparency = 0,
})
corner(hpFrame, 6)
local hpFill = makeFrame(hpFrame, {
	Name = "Fill",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(220, 60, 60),
	BackgroundTransparency = 0,
})
corner(hpFill, 6)
local hpLabel = makeLabel(hpFrame, {
	Size = UDim2.new(1, -8, 1, 0),
	Position = UDim2.new(0, 4, 0, 0),
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "100/100",
	TextColor3 = Color3.fromRGB(255,255,255),
	ZIndex = 2,
})
local hpTitle = makeLabel(hpFrame, {
	Size = UDim2.new(0.5, 0, 1, 0),
	Position = UDim2.new(0, 8, 0, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = Strings.HUD.HP,
	TextColor3 = Color3.fromRGB(255,255,255),
	ZIndex = 2,
})

-- XP bar
local xpFrame = makeFrame(container, {
	Position = UDim2.new(0, 12, 0, 50),
	Size = UDim2.new(1, -24, 0, 22),
	BackgroundColor3 = Color3.fromRGB(40, 40, 40),
	BackgroundTransparency = 0,
})
corner(xpFrame, 6)
local xpFill = makeFrame(xpFrame, {
	Name = "Fill",
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(120, 200, 255),
	BackgroundTransparency = 0,
})
corner(xpFill, 6)
local xpLabel = makeLabel(xpFrame, {
	Size = UDim2.new(1, 0, 1, 0),
	Text = string.format("%s: 0", Strings.HUD.XP),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Color3.fromRGB(255,255,255),
	ZIndex = 2,
})

-- Weapon + time
local weaponLabel = makeLabel(container, {
	Position = UDim2.new(0, 12, 0, 78),
	Size = UDim2.new(1, -24, 0, 22),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = Strings.HUD.Weapon .. ": -",
	TextColor3 = Color3.fromRGB(255,220,140),
})
local timeLabel = makeLabel(container, {
	Position = UDim2.new(0, 12, 0, 102),
	Size = UDim2.new(1, -24, 0, 22),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = Strings.HUD.Time .. ": 0s",
	TextColor3 = Color3.fromRGB(180,220,255),
})

-- Shop button (bottom-right) — also clickable so mobile/touch players can use it.
local hint = Instance.new("TextButton")
hint.Name = "ShopHint"
hint.AnchorPoint = Vector2.new(1, 1)
hint.Position = UDim2.new(1, -16, 1, -16)
hint.Size = UDim2.new(0, 220, 0, 44)
hint.BackgroundColor3 = Color3.fromRGB(36, 42, 54)
hint.BackgroundTransparency = 0.15
hint.BorderSizePixel = 0
hint.Font = Enum.Font.GothamBold
hint.TextColor3 = Color3.fromRGB(255, 220, 100)
hint.TextStrokeTransparency = 0.5
hint.TextScaled = true
hint.AutoButtonColor = true
hint.Text = Strings.HUD.ShopHint
hint.Parent = screen
do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = hint
	local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255, 200, 60); s.Thickness = 2; s.Parent = hint
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = hint
end

-- Wire the click into the shop's toggle. ShopGui creates a BindableEvent
-- "ShopToggleEvent" inside PlayerGui that we fire here.
hint.MouseButton1Click:Connect(function()
	local evt = pg:FindFirstChild("ShopToggleEvent")
	if not evt then
		-- ShopGui may still be loading; wait briefly.
		evt = pg:WaitForChild("ShopToggleEvent", 2)
	end
	if evt then evt:Fire() end
end)

local function fmtSeconds(t)
	local m = math.floor(t/60)
	local s = t - m*60
	return string.format("%d:%02d", m, s)
end

Remotes.UpdateHUD.OnClientEvent:Connect(function(state)
	if not state then return end
	local hp, maxHp = state.hp or 100, state.maxHp or 100
	hpFill.Size  = UDim2.new(math.clamp(hp/maxHp, 0, 1), 0, 1, 0)
	hpLabel.Text = tostring(hp) .. "/" .. tostring(maxHp)

	-- XP fills relative to next level cost; for now show fraction to 800 (Pistol).
	local xpCap = 800
	local xp = state.xp or 0
	xpFill.Size = UDim2.new(math.clamp(xp/xpCap, 0, 1), 0, 1, 0)
	xpLabel.Text = string.format("%s: %d", Strings.HUD.XP, xp)

	local wId = state.weapon
	local wSpec = WeaponConfig.ById[wId]
	local wName = wSpec and (Strings.Weapons[wSpec.DisplayKey] or wSpec.Id) or "-"
	weaponLabel.Text = Strings.HUD.Weapon .. ": " .. wName

	timeLabel.Text = Strings.HUD.Time .. ": " .. fmtSeconds(state.time or 0)

	-- Hide hint when not playing
	hint.Visible = (state.state == "PLAYING")
	container.Visible = (state.state == "PLAYING")
end)
