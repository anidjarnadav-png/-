-- DevPanelGui.lua
-- Place in: StarterGui as LocalScript named "DevPanelGui"
-- Creator/Dev Panel for game owners. Mirrors the HTML mockup: global
-- message broadcaster, give XP/weapon/heal (self or other), ban/kick,
-- restart server/all. Only visible to authorized UserIds (server checks
-- IsAdmin RemoteFunction; the panel is also gated by the same check on
-- every action so a tampered client can't bypass it).

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ==== Admin check ====
local isAdmin = false
do
	local ok, val = pcall(function() return Remotes.IsAdmin:InvokeServer() end)
	if ok then isAdmin = val == true end
end
if not isAdmin then
	-- Non-admins don't even instantiate the GUI. Silently return.
	return
end

-- ==== ScreenGui ====
local screen = Instance.new("ScreenGui")
screen.Name = "DevPanelGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 200
screen.Parent = pg

-- ==== Helpers ====
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
	return c
end
local function stroke(p, color, thick, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(255, 255, 255)
	s.Thickness = thick or 1
	s.Transparency = transparency or 0.85
	s.Parent = p
	return s
end
local function pad(p, opts)
	local up = Instance.new("UIPadding")
	up.PaddingLeft = UDim.new(0, opts.left or 0)
	up.PaddingRight = UDim.new(0, opts.right or 0)
	up.PaddingTop = UDim.new(0, opts.top or 0)
	up.PaddingBottom = UDim.new(0, opts.bottom or 0)
	up.Parent = p
	return up
end
local function listLayout(p, padding, dir)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 0)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Parent = p
	return l
end

-- ==== Devs Panel opener button (top-left) ====
local opener = Instance.new("TextButton")
opener.Name = "DevsPanelOpener"
opener.AnchorPoint = Vector2.new(0, 0)
opener.Position = UDim2.new(0, 24, 0, 24)
opener.Size = UDim2.new(0, 150, 0, 44)
opener.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
opener.BorderSizePixel = 0
opener.Font = Enum.Font.GothamBold
opener.TextColor3 = Color3.fromRGB(255, 255, 255)
opener.TextSize = 16
opener.Text = "devs panel"
opener.AutoButtonColor = true
opener.Parent = screen
corner(opener, 12)
stroke(opener, Color3.fromRGB(255, 255, 255), 1.5, 0.7)

-- ==== Backdrop + Panel ====
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.4
backdrop.BorderSizePixel = 0
backdrop.Visible = false
backdrop.Parent = screen

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0.8, 0, 0.85, 0)
panel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
panel.BorderSizePixel = 0
panel.Parent = backdrop
corner(panel, 18)
stroke(panel, Color3.fromRGB(255, 255, 255), 2, 0.88)

-- ==== Header ====
local header = Instance.new("Frame", panel)
header.Name = "Header"
header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
header.BorderSizePixel = 0
header.Size = UDim2.new(1, 0, 0, 70)
header.Position = UDim2.new(0, 0, 0, 0)
do
	local s = Instance.new("UIStroke", header)
	s.Color = Color3.fromRGB(255, 255, 255); s.Thickness = 1; s.Transparency = 0.92
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

local headerIcon = Instance.new("Frame", header)
headerIcon.AnchorPoint = Vector2.new(0, 0.5)
headerIcon.Position = UDim2.new(0, 24, 0.5, 0)
headerIcon.Size = UDim2.new(0, 44, 0, 44)
headerIcon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
headerIcon.BorderSizePixel = 0
corner(headerIcon, 10)
local headerIconLbl = Instance.new("TextLabel", headerIcon)
headerIconLbl.BackgroundTransparency = 1
headerIconLbl.Size = UDim2.new(1, 0, 1, 0)
headerIconLbl.Font = Enum.Font.GothamBlack
headerIconLbl.TextColor3 = Color3.fromRGB(0, 0, 0)
headerIconLbl.TextSize = 22
headerIconLbl.Text = "DP"

local headerTitle = Instance.new("TextLabel", header)
headerTitle.BackgroundTransparency = 1
headerTitle.AnchorPoint = Vector2.new(0, 0.5)
headerTitle.Position = UDim2.new(0, 80, 0.5, -8)
headerTitle.Size = UDim2.new(0, 380, 0, 24)
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
headerTitle.TextSize = 22
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Text = "Creator Panel"

local headerSubtitle = Instance.new("TextLabel", header)
headerSubtitle.BackgroundTransparency = 1
headerSubtitle.AnchorPoint = Vector2.new(0, 0.5)
headerSubtitle.Position = UDim2.new(0, 80, 0.5, 12)
headerSubtitle.Size = UDim2.new(0, 380, 0, 18)
headerSubtitle.Font = Enum.Font.Gotham
headerSubtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
headerSubtitle.TextSize = 12
headerSubtitle.TextXAlignment = Enum.TextXAlignment.Left
headerSubtitle.Text = "Developer Mode"

local headerStatusDot = Instance.new("Frame", header)
headerStatusDot.AnchorPoint = Vector2.new(1, 0.5)
headerStatusDot.Position = UDim2.new(1, -130, 0.5, 0)
headerStatusDot.Size = UDim2.new(0, 10, 0, 10)
headerStatusDot.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
headerStatusDot.BorderSizePixel = 0
corner(headerStatusDot, 5)

local headerStatusText = Instance.new("TextLabel", header)
headerStatusText.BackgroundTransparency = 1
headerStatusText.AnchorPoint = Vector2.new(1, 0.5)
headerStatusText.Position = UDim2.new(1, -68, 0.5, 0)
headerStatusText.Size = UDim2.new(0, 90, 0, 18)
headerStatusText.Font = Enum.Font.Gotham
headerStatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
headerStatusText.TextSize = 13
headerStatusText.TextXAlignment = Enum.TextXAlignment.Right
headerStatusText.Text = "Connected"

local closeBtn = Instance.new("TextButton", header)
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.Position = UDim2.new(1, -16, 0.5, 0)
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 18
closeBtn.Text = "✕"
corner(closeBtn, 8)
stroke(closeBtn, Color3.fromRGB(255, 255, 255), 1, 0.9)

-- pulse animation for status dot
task.spawn(function()
	while screen.Parent do
		TweenService:Create(headerStatusDot, TweenInfo.new(1), { BackgroundTransparency = 0.5 }):Play()
		task.wait(1)
		TweenService:Create(headerStatusDot, TweenInfo.new(1), { BackgroundTransparency = 0 }):Play()
		task.wait(1)
	end
end)

-- ==== Footer ====
local footer = Instance.new("Frame", panel)
footer.Name = "Footer"
footer.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
footer.BorderSizePixel = 0
footer.Size = UDim2.new(1, 0, 0, 36)
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.new(0, 0, 1, 0)
local footerL = Instance.new("TextLabel", footer)
footerL.BackgroundTransparency = 1
footerL.AnchorPoint = Vector2.new(0, 0.5)
footerL.Position = UDim2.new(0, 24, 0.5, 0)
footerL.Size = UDim2.new(0.5, 0, 1, 0)
footerL.Font = Enum.Font.Gotham
footerL.TextColor3 = Color3.fromRGB(140, 140, 140)
footerL.TextSize = 12
footerL.TextXAlignment = Enum.TextXAlignment.Left
footerL.Text = "Esc לסגירה · F4 לפתיחה"
local footerR = Instance.new("TextLabel", footer)
footerR.BackgroundTransparency = 1
footerR.AnchorPoint = Vector2.new(1, 0.5)
footerR.Position = UDim2.new(1, -24, 0.5, 0)
footerR.Size = UDim2.new(0.5, 0, 1, 0)
footerR.Font = Enum.Font.Gotham
footerR.TextColor3 = Color3.fromRGB(140, 140, 140)
footerR.TextSize = 12
footerR.TextXAlignment = Enum.TextXAlignment.Right
footerR.Text = "v1.0.0 · Developer Mode"

-- ==== Body (scrolling) ====
local body = Instance.new("ScrollingFrame", panel)
body.Name = "Body"
body.Size = UDim2.new(1, 0, 1, -106)  -- minus header (70) and footer (36)
body.Position = UDim2.new(0, 0, 0, 70)
body.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
body.BorderSizePixel = 0
body.ScrollBarThickness = 8
body.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
body.ScrollBarImageTransparency = 0.85
body.CanvasSize = UDim2.new(0, 0, 0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
pad(body, { left = 28, right = 28, top = 24, bottom = 24 })
listLayout(body, 18)

-- Helpers to build form widgets
local function newInput(parent, props)
	local f = Instance.new("TextBox", parent)
	f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	f.BorderSizePixel = 0
	f.Font = Enum.Font.Gotham
	f.TextColor3 = Color3.fromRGB(255, 255, 255)
	f.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
	f.TextSize = 14
	f.TextXAlignment = Enum.TextXAlignment.Right
	f.ClearTextOnFocus = false
	f.Size = props.Size or UDim2.new(1, 0, 0, 38)
	for k, v in pairs(props) do f[k] = v end
	corner(f, 8)
	stroke(f, Color3.fromRGB(255, 255, 255), 1, 0.85)
	pad(f, { left = 12, right = 12, top = 4, bottom = 4 })
	return f
end

local function newLabel(parent, props)
	local l = Instance.new("TextLabel", parent)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.fromRGB(200, 200, 200)
	l.TextSize = 13
	l.TextXAlignment = Enum.TextXAlignment.Right
	l.Size = UDim2.new(1, 0, 0, 18)
	for k, v in pairs(props) do l[k] = v end
	return l
end

local function newButton(parent, props, color, textColor)
	local b = Instance.new("TextButton", parent)
	b.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	b.TextColor3 = textColor or Color3.fromRGB(0, 0, 0)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.Size = UDim2.new(1, 0, 0, 44)
	b.AutoButtonColor = true
	for k, v in pairs(props) do b[k] = v end
	corner(b, 10)
	return b
end

-- Toast (bottom of panel)
local toast = Instance.new("TextLabel", panel)
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -50)
toast.Size = UDim2.new(0, 360, 0, 44)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
toast.BackgroundTransparency = 0
toast.Font = Enum.Font.GothamBold
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.TextSize = 14
toast.Text = ""
toast.Visible = false
toast.ZIndex = 50
corner(toast, 10)
stroke(toast, Color3.fromRGB(255, 255, 255), 1, 0.7)

local function showToast(text, color)
	toast.Text = text or ""
	if color then toast.TextColor3 = color else toast.TextColor3 = Color3.fromRGB(255, 255, 255) end
	toast.Visible = true
	toast.BackgroundTransparency = 0
	toast.TextTransparency = 0
	task.delay(2.5, function()
		TweenService:Create(toast, TweenInfo.new(0.4), {
			BackgroundTransparency = 1, TextTransparency = 1,
		}):Play()
		task.wait(0.4)
		toast.Visible = false
	end)
end

-- ==== Section builder ====
local function buildSection(opts)
	local sec = Instance.new("Frame", body)
	sec.Name = opts.name or "Section"
	sec.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	sec.BorderSizePixel = 0
	sec.Size = UDim2.new(1, 0, 0, 100)  -- AutomaticSize will grow
	sec.AutomaticSize = Enum.AutomaticSize.Y
	sec.LayoutOrder = opts.order or 0
	corner(sec, 14)
	stroke(sec, Color3.fromRGB(255, 255, 255), 1, 0.9)
	pad(sec, { left = 22, right = 22, top = 18, bottom = 18 })
	listLayout(sec, 12)

	-- Header row: title + desc
	local titleRow = Instance.new("Frame", sec)
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(1, 0, 0, 46)
	titleRow.LayoutOrder = 1
	local title = Instance.new("TextLabel", titleRow)
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 0, 0, 0)
	title.Size = UDim2.new(1, 0, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Right
	title.Text = opts.title or ""
	if opts.titleColor then title.TextColor3 = opts.titleColor end
	if opts.desc then
		local desc = Instance.new("TextLabel", titleRow)
		desc.BackgroundTransparency = 1
		desc.Position = UDim2.new(0, 0, 0, 24)
		desc.Size = UDim2.new(1, 0, 0, 18)
		desc.Font = Enum.Font.Gotham
		desc.TextColor3 = Color3.fromRGB(140, 140, 140)
		desc.TextSize = 12
		desc.TextXAlignment = Enum.TextXAlignment.Right
		desc.Text = opts.desc
	end

	return sec
end

-- ==== Target toggle helper (self/other) ====
local function buildTargetToggle(parent, defaultValue)
	local row = Instance.new("Frame", parent)
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 44)
	local label = newLabel(row, { Position = UDim2.new(0, 0, 0, 0), Text = "יעד" })
	local toggle = Instance.new("Frame", row)
	toggle.Position = UDim2.new(0, 0, 0, 22)
	toggle.Size = UDim2.new(1, 0, 0, 36)
	toggle.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	toggle.BorderSizePixel = 0
	corner(toggle, 8)
	stroke(toggle, Color3.fromRGB(255, 255, 255), 1, 0.85)
	pad(toggle, { left = 4, right = 4, top = 4, bottom = 4 })
	listLayout(toggle, 4, Enum.FillDirection.Horizontal)

	local btnSelf = Instance.new("TextButton", toggle)
	btnSelf.LayoutOrder = 1
	btnSelf.Size = UDim2.new(0.5, -2, 1, 0)
	btnSelf.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	btnSelf.BorderSizePixel = 0
	btnSelf.Font = Enum.Font.GothamBold
	btnSelf.TextColor3 = Color3.fromRGB(0, 0, 0)
	btnSelf.TextSize = 13
	btnSelf.Text = "לעצמך"
	corner(btnSelf, 6)

	local btnOther = Instance.new("TextButton", toggle)
	btnOther.LayoutOrder = 2
	btnOther.Size = UDim2.new(0.5, -2, 1, 0)
	btnOther.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	btnOther.BorderSizePixel = 0
	btnOther.Font = Enum.Font.GothamBold
	btnOther.TextColor3 = Color3.fromRGB(140, 140, 140)
	btnOther.TextSize = 13
	btnOther.Text = "לשחקן אחר"
	corner(btnOther, 6)

	local state = { value = defaultValue or "self" }
	local function refresh()
		if state.value == "self" then
			btnSelf.BackgroundColor3 = Color3.fromRGB(255, 255, 255); btnSelf.TextColor3 = Color3.fromRGB(0, 0, 0)
			btnOther.BackgroundColor3 = Color3.fromRGB(20, 20, 20);  btnOther.TextColor3 = Color3.fromRGB(140, 140, 140)
		else
			btnOther.BackgroundColor3 = Color3.fromRGB(255, 255, 255); btnOther.TextColor3 = Color3.fromRGB(0, 0, 0)
			btnSelf.BackgroundColor3 = Color3.fromRGB(20, 20, 20);    btnSelf.TextColor3 = Color3.fromRGB(140, 140, 140)
		end
	end
	btnSelf.MouseButton1Click:Connect(function() state.value = "self"; refresh(); if state.onChange then state.onChange(state.value) end end)
	btnOther.MouseButton1Click:Connect(function() state.value = "other"; refresh(); if state.onChange then state.onChange(state.value) end end)
	refresh()
	return state
end

-- ==== Sections ====

-- 1. GLOBAL MESSAGE
local msgSection = buildSection{
	title = "הודעה גלובלית",
	desc  = "הודעה לכל השרתים — תוצג לכל השחקנים בכל השרתים הפעילים",
	order = 1,
}
newLabel(msgSection, { Text = "תוכן ההודעה", LayoutOrder = 2 })
local msgInput = newInput(msgSection, {
	LayoutOrder = 3,
	PlaceholderText = "מקום לרשום...",
	MultiLine = true,
	TextWrapped = true,
	ClearTextOnFocus = false,
	Size = UDim2.new(1, 0, 0, 80),
})

newLabel(msgSection, { Text = "צבע ההודעה", LayoutOrder = 4 })
local colorRow = Instance.new("Frame", msgSection)
colorRow.LayoutOrder = 5
colorRow.BackgroundTransparency = 1
colorRow.Size = UDim2.new(1, 0, 0, 80)
do
	local g = Instance.new("UIGridLayout", colorRow)
	g.CellSize = UDim2.new(0, 30, 0, 30)
	g.CellPadding = UDim2.new(0, 8, 0, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
end
local COLORS = {
	{"#ffffff", Color3.fromRGB(255,255,255)},
	{"#000000", Color3.fromRGB(0,0,0)},
	{"#868e96", Color3.fromRGB(134,142,150)},
	{"#ff5757", Color3.fromRGB(255,87,87)},
	{"#e03131", Color3.fromRGB(224,49,49)},
	{"#ffa94d", Color3.fromRGB(255,169,77)},
	{"#ff922b", Color3.fromRGB(255,146,43)},
	{"#ffd43b", Color3.fromRGB(255,212,59)},
	{"#fab005", Color3.fromRGB(250,176,5)},
	{"#a9e34b", Color3.fromRGB(169,227,75)},
	{"#51cf66", Color3.fromRGB(81,207,102)},
	{"#2f9e44", Color3.fromRGB(47,158,68)},
	{"#38d9a9", Color3.fromRGB(56,217,169)},
	{"#22b8cf", Color3.fromRGB(34,184,207)},
	{"#4dabf7", Color3.fromRGB(77,171,247)},
	{"#1971c2", Color3.fromRGB(25,113,194)},
	{"#5c7cfa", Color3.fromRGB(92,124,250)},
	{"#cc5de8", Color3.fromRGB(204,93,232)},
	{"#9c36b5", Color3.fromRGB(156,54,181)},
	{"#f783ac", Color3.fromRGB(247,131,172)},
	{"#e64980", Color3.fromRGB(230,73,128)},
	{"#a0826d", Color3.fromRGB(160,130,109)},
}
local selectedColor = "#ffffff"
local swatches = {}
for i, c in ipairs(COLORS) do
	local sw = Instance.new("TextButton", colorRow)
	sw.LayoutOrder = i
	sw.AutoButtonColor = false
	sw.BackgroundColor3 = c[2]
	sw.BorderSizePixel = 0
	sw.Text = ""
	corner(sw, 8)
	local s = Instance.new("UIStroke", sw)
	s.Color = Color3.fromRGB(255, 255, 255)
	s.Thickness = 1
	s.Transparency = 0.7
	swatches[i] = { btn = sw, hex = c[1], stroke = s }
	sw.MouseButton1Click:Connect(function()
		selectedColor = c[1]
		for _, w in ipairs(swatches) do
			w.stroke.Thickness = w.hex == selectedColor and 3 or 1
			w.stroke.Transparency = w.hex == selectedColor and 0 or 0.7
		end
		previewText.Text = msgInput.Text ~= "" and msgInput.Text or "ההודעה שלך תופיע כאן..."
		previewText.TextColor3 = c[2]
	end)
end
swatches[1].stroke.Thickness = 3; swatches[1].stroke.Transparency = 0  -- white default

newLabel(msgSection, { Text = "תצוגה מקדימה", LayoutOrder = 6 })
local previewBox = Instance.new("Frame", msgSection)
previewBox.LayoutOrder = 7
previewBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
previewBox.BackgroundTransparency = 0.4
previewBox.BorderSizePixel = 0
previewBox.Size = UDim2.new(1, 0, 0, 50)
corner(previewBox, 8)
stroke(previewBox, Color3.fromRGB(255, 255, 255), 1, 0.92)
pad(previewBox, { left = 12, right = 12, top = 8, bottom = 8 })
previewText = Instance.new("TextLabel", previewBox)
previewText.BackgroundTransparency = 1
previewText.Size = UDim2.new(1, 0, 1, 0)
previewText.Font = Enum.Font.GothamBold
previewText.TextColor3 = Color3.fromRGB(255, 255, 255)
previewText.TextSize = 14
previewText.TextXAlignment = Enum.TextXAlignment.Right
previewText.Text = "ההודעה שלך תופיע כאן..."

msgInput:GetPropertyChangedSignal("Text"):Connect(function()
	local v = msgInput.Text
	previewText.Text = v ~= "" and v or "ההודעה שלך תופיע כאן..."
end)

local sendMsgBtn = newButton(msgSection, {
	LayoutOrder = 8,
	Text = "שלח לכולם",
}, Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0))

sendMsgBtn.MouseButton1Click:Connect(function()
	local v = msgInput.Text
	if not v or v == "" then
		showToast("יש להזין הודעה", Color3.fromRGB(255, 100, 100))
		return
	end
	Remotes.AdminAction:FireServer({
		action = "globalMessage",
		data = { text = v, color = selectedColor },
	})
	msgInput.Text = ""
end)

-- 2. GIVE XP
local xpSection = buildSection{
	title = "XP",
	desc  = "הענק נקודות ניסיון — לעצמך או לשחקן אחר",
	order = 2,
}
local xpToggle = buildTargetToggle(xpSection, "self")
xpToggle.LayoutOrder = 2
local xpUserInput = newInput(xpSection, {
	LayoutOrder = 3, PlaceholderText = "שם משתמש...", Visible = false,
})
local xpUserLabel = newLabel(xpSection, { Text = "שם משתמש", LayoutOrder = 3, Visible = false })
xpUserInput.LayoutOrder = 4
xpToggle.onChange = function(v)
	local show = v == "other"
	xpUserLabel.Visible = show
	xpUserInput.Visible = show
end
newLabel(xpSection, { Text = "כמות XP", LayoutOrder = 5 })
local xpAmount = newInput(xpSection, {
	LayoutOrder = 6, PlaceholderText = "מקום לרשום...", Text = "",
})
newButton(xpSection, { LayoutOrder = 7, Text = "הענק XP" }, Color3.fromRGB(255,255,255), Color3.fromRGB(0,0,0))
	.MouseButton1Click:Connect(function()
		local amt = tonumber(xpAmount.Text)
		if not amt or amt <= 0 then return showToast("כמות XP לא תקינה", Color3.fromRGB(255,100,100)) end
		Remotes.AdminAction:FireServer({
			action = "giveXP",
			data = { target = xpToggle.value, username = xpUserInput.Text, amount = amt },
		})
	end)

-- 3. GIVE WEAPON
local weaponSection = buildSection{
	title = "נשק",
	desc  = "הענק נשק — לעצמך או לשחקן אחר",
	order = 3,
}
local weaponToggle = buildTargetToggle(weaponSection, "self")
weaponToggle.LayoutOrder = 2
local weaponUserLabel = newLabel(weaponSection, { Text = "שם משתמש", LayoutOrder = 3, Visible = false })
local weaponUserInput = newInput(weaponSection, { LayoutOrder = 4, PlaceholderText = "שם משתמש...", Visible = false })
weaponToggle.onChange = function(v)
	local show = v == "other"
	weaponUserLabel.Visible = show
	weaponUserInput.Visible = show
end
newLabel(weaponSection, { Text = "בחר נשק", LayoutOrder = 5 })
local wPickRow = Instance.new("Frame", weaponSection)
wPickRow.LayoutOrder = 6
wPickRow.BackgroundTransparency = 1
wPickRow.Size = UDim2.new(1, 0, 0, 90)
do
	local g = Instance.new("UIGridLayout", wPickRow)
	g.CellSize = UDim2.new(0.5, -4, 0, 38)
	g.CellPadding = UDim2.new(0, 8, 0, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
end
local WEAPONS = {
	{ id = "Stick",   label = Strings.Weapons.Stick   },
	{ id = "Spear",   label = Strings.Weapons.Spear   },
	{ id = "Knife",   label = Strings.Weapons.Knife   },
	{ id = "Pistol",  label = Strings.Weapons.Pistol  },
	{ id = "Shotgun", label = Strings.Weapons.Shotgun },
}
local selectedWeapon = "Stick"
local weaponBtns = {}
for i, w in ipairs(WEAPONS) do
	local b = Instance.new("TextButton", wPickRow)
	b.LayoutOrder = i
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.fromRGB(180, 180, 180)
	b.TextSize = 14
	b.Text = w.label
	corner(b, 8)
	local s = stroke(b, Color3.fromRGB(255, 255, 255), 1, 0.85)
	weaponBtns[i] = { btn = b, id = w.id, stroke = s }
	b.MouseButton1Click:Connect(function()
		selectedWeapon = w.id
		for _, wb in ipairs(weaponBtns) do
			if wb.id == selectedWeapon then
				wb.btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255); wb.btn.TextColor3 = Color3.fromRGB(0, 0, 0); wb.stroke.Transparency = 0
			else
				wb.btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20); wb.btn.TextColor3 = Color3.fromRGB(180, 180, 180); wb.stroke.Transparency = 0.85
			end
		end
	end)
end
-- default highlight
weaponBtns[1].btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
weaponBtns[1].btn.TextColor3 = Color3.fromRGB(0, 0, 0)
weaponBtns[1].stroke.Transparency = 0

newButton(weaponSection, { LayoutOrder = 7, Text = "הענק נשק" }, Color3.fromRGB(255,255,255), Color3.fromRGB(0,0,0))
	.MouseButton1Click:Connect(function()
		Remotes.AdminAction:FireServer({
			action = "giveWeapon",
			data = { target = weaponToggle.value, username = weaponUserInput.Text, weaponId = selectedWeapon },
		})
	end)

-- 4. BAN
local banSection = buildSection{
	title = "תן באן",
	titleColor = Color3.fromRGB(255, 100, 100),
	desc  = "חסום שחקן מהמשחק לצמיתות",
	order = 4,
}
newLabel(banSection, { Text = "שם משתמש", LayoutOrder = 2 })
local banInput = newInput(banSection, { LayoutOrder = 3, PlaceholderText = "מקום לרשום..." })
newButton(banSection, { LayoutOrder = 4, Text = "תן באן" }, Color3.fromRGB(255, 87, 87), Color3.fromRGB(255, 255, 255))
	.MouseButton1Click:Connect(function()
		local v = banInput.Text
		if not v or v == "" then return showToast("יש להזין שם משתמש", Color3.fromRGB(255,100,100)) end
		Remotes.AdminAction:FireServer({ action = "ban", data = { username = v } })
		banInput.Text = ""
	end)

-- 5. KICK
local kickSection = buildSection{
	title = "תן קיק",
	titleColor = Color3.fromRGB(255, 169, 77),
	desc  = "העף שחקן מהשרת הנוכחי",
	order = 5,
}
newLabel(kickSection, { Text = "שם משתמש", LayoutOrder = 2 })
local kickInput = newInput(kickSection, { LayoutOrder = 3, PlaceholderText = "מקום לרשום..." })
newButton(kickSection, { LayoutOrder = 4, Text = "תן קיק" }, Color3.fromRGB(255, 169, 77), Color3.fromRGB(0, 0, 0))
	.MouseButton1Click:Connect(function()
		local v = kickInput.Text
		if not v or v == "" then return showToast("יש להזין שם משתמש", Color3.fromRGB(255,100,100)) end
		Remotes.AdminAction:FireServer({ action = "kick", data = { username = v } })
		kickInput.Text = ""
	end)

-- 6. HEAL
local healSection = buildSection{
	title = "רפא",
	titleColor = Color3.fromRGB(81, 207, 102),
	desc  = "החזר HP — לעצמך או לשחקן אחר",
	order = 6,
}
local healToggle = buildTargetToggle(healSection, "self")
healToggle.LayoutOrder = 2
local healUserLabel = newLabel(healSection, { Text = "שם משתמש", LayoutOrder = 3, Visible = false })
local healUserInput = newInput(healSection, { LayoutOrder = 4, PlaceholderText = "שם משתמש...", Visible = false })
healToggle.onChange = function(v)
	local show = v == "other"
	healUserLabel.Visible = show
	healUserInput.Visible = show
end
newLabel(healSection, { Text = "כמות HP (השאר ריק ל-MAX)", LayoutOrder = 5 })
local healAmount = newInput(healSection, { LayoutOrder = 6, PlaceholderText = "מקום לרשום...", Text = "" })
newButton(healSection, { LayoutOrder = 7, Text = "רפא" }, Color3.fromRGB(81, 207, 102), Color3.fromRGB(0, 0, 0))
	.MouseButton1Click:Connect(function()
		local amt = healAmount.Text
		local data = { target = healToggle.value, username = healUserInput.Text }
		if amt and amt ~= "" then
			data.amount = tonumber(amt)
			if not data.amount or data.amount <= 0 then
				return showToast("כמות HP לא תקינה", Color3.fromRGB(255,100,100))
			end
		end
		Remotes.AdminAction:FireServer({ action = "heal", data = data })
	end)

-- 7. RESTART SERVER
local rsSection = buildSection{
	title = "Restart Server",
	titleColor = Color3.fromRGB(255, 169, 77),
	desc  = "הפעל מחדש את השרת הנוכחי בלבד",
	order = 7,
}
newLabel(rsSection, { Text = "סיבה (אופציונלי)", LayoutOrder = 2 })
local rsReason = newInput(rsSection, { LayoutOrder = 3, PlaceholderText = "מקום לרשום..." })
newButton(rsSection, { LayoutOrder = 4, Text = "Restart Server" }, Color3.fromRGB(255, 169, 77), Color3.fromRGB(0, 0, 0))
	.MouseButton1Click:Connect(function()
		Remotes.AdminAction:FireServer({ action = "restartServer", data = { reason = rsReason.Text } })
		rsReason.Text = ""
	end)

-- 8. RESTART ALL
local raSection = buildSection{
	title = "Restart All Servers",
	titleColor = Color3.fromRGB(255, 87, 87),
	desc  = "הפעל מחדש את כל השרתים הפעילים — מתאים לעדכונים",
	order = 8,
}
newLabel(raSection, { Text = "סיבה (אופציונלי)", LayoutOrder = 2 })
local raReason = newInput(raSection, { LayoutOrder = 3, PlaceholderText = "מקום לרשום..." })
newButton(raSection, { LayoutOrder = 4, Text = "Restart All Servers" }, Color3.fromRGB(255, 87, 87), Color3.fromRGB(255, 255, 255))
	.MouseButton1Click:Connect(function()
		Remotes.AdminAction:FireServer({ action = "restartAll", data = { reason = raReason.Text } })
		raReason.Text = ""
	end)

-- ==== Open / close ====
local function open()
	backdrop.Visible = true
	opener.Visible = false
	panel.Size = UDim2.new(0.78, 0, 0.83, 0)
	TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.8, 0, 0.85, 0),
	}):Play()
end
local function close()
	backdrop.Visible = false
	opener.Visible = true
end

opener.MouseButton1Click:Connect(open)
closeBtn.MouseButton1Click:Connect(close)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.F4 then
		if backdrop.Visible then close() else open() end
	elseif input.KeyCode == Enum.KeyCode.Escape and backdrop.Visible then
		close()
	end
end)

-- ==== Result toasts from server ====
Remotes.AdminResult.OnClientEvent:Connect(function(payload)
	if not payload then return end
	local color = Color3.fromRGB(255, 255, 255)
	if payload.color then
		local hex = tostring(payload.color):gsub("#", "")
		if #hex == 6 then
			local r = tonumber(hex:sub(1, 2), 16) or 255
			local g = tonumber(hex:sub(3, 4), 16) or 255
			local b = tonumber(hex:sub(5, 6), 16) or 255
			color = Color3.fromRGB(r, g, b)
		end
	end
	if not payload.ok then color = Color3.fromRGB(255, 100, 100) end
	showToast(payload.message or "", color)
end)
