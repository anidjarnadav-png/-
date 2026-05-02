-- ShopGui.lua
-- Place in: StarterGui as LocalScript named "ShopGui"
-- Toggle with B. Shows weapons + plane upgrades, all in Hebrew.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player    = Players.LocalPlayer
local pg        = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

local screen = Instance.new("ScreenGui")
screen.Name = "ShopGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = pg

local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c end
local function stroke(p, c, t) local s = Instance.new("UIStroke"); s.Color = c; s.Thickness = t or 1; s.Parent = p; return s end
local function listLayout(p, padding) local l = Instance.new("UIListLayout"); l.SortOrder = Enum.SortOrder.LayoutOrder; l.Padding = UDim.new(0, padding or 6); l.Parent = p; return l end
local function pad(p, x, y) local pp = Instance.new("UIPadding"); pp.PaddingLeft=UDim.new(0,x); pp.PaddingRight=UDim.new(0,x); pp.PaddingTop=UDim.new(0,y); pp.PaddingBottom=UDim.new(0,y); pp.Parent = p; return pp end

local backdrop = Instance.new("Frame", screen)
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel = 0
backdrop.Visible = false

local panel = Instance.new("Frame", backdrop)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 720, 0, 540)
panel.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
panel.BorderSizePixel = 0
corner(panel, 14)
stroke(panel, Color3.fromRGB(80, 90, 110), 1)

-- Title bar
local titleBar = Instance.new("Frame", panel)
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(38, 44, 56)
titleBar.BorderSizePixel = 0
corner(titleBar, 14)

local title = Instance.new("TextLabel", titleBar)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -120, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 220, 120)
title.TextXAlignment = Enum.TextXAlignment.Right
title.TextScaled = true
title.Text = Strings.Shop.Title

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 100, 0, 36)
closeBtn.AnchorPoint = Vector2.new(0, 0.5)
closeBtn.Position = UDim2.new(0, 12, 0.5, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Text = Strings.Shop.Close
corner(closeBtn, 8)

-- XP display in title
local xpLabel = Instance.new("TextLabel", titleBar)
xpLabel.BackgroundTransparency = 1
xpLabel.AnchorPoint = Vector2.new(0.5, 0.5)
xpLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
xpLabel.Size = UDim2.new(0, 200, 0, 30)
xpLabel.Font = Enum.Font.GothamBold
xpLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
xpLabel.TextScaled = true
xpLabel.Text = "XP: 0"

-- Tabs
local tabBar = Instance.new("Frame", panel)
tabBar.Position = UDim2.new(0, 0, 0, 50)
tabBar.Size = UDim2.new(1, 0, 0, 40)
tabBar.BackgroundColor3 = Color3.fromRGB(22, 26, 32)
tabBar.BorderSizePixel = 0

local function makeTab(text, x)
	local b = Instance.new("TextButton", tabBar)
	b.Position = UDim2.new(0, x, 0, 4)
	b.Size = UDim2.new(0, 200, 0, 32)
	b.BackgroundColor3 = Color3.fromRGB(40, 50, 65)
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.fromRGB(220, 220, 220)
	b.TextScaled = true
	b.Text = text
	corner(b, 6)
	return b
end
local tabWeapons  = makeTab(Strings.Shop.TabWeapons,  16)
local tabUpgrades = makeTab(Strings.Shop.TabUpgrades, 230)

-- Content
local content = Instance.new("ScrollingFrame", panel)
content.Position = UDim2.new(0, 0, 0, 96)
content.Size = UDim2.new(1, 0, 1, -96)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 6
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
pad(content, 16, 12)
listLayout(content, 8)

local currentTab = "Weapons"
local currentState = nil

local function clearContent()
	for _, c in ipairs(content:GetChildren()) do
		if not (c:IsA("UIListLayout") or c:IsA("UIPadding")) then
			c:Destroy()
		end
	end
end

local function buildItemCard(opts)
	local card = Instance.new("Frame", content)
	card.Size = UDim2.new(1, 0, 0, 96)
	card.BackgroundColor3 = Color3.fromRGB(40, 48, 60)
	card.BorderSizePixel = 0
	corner(card, 10)
	stroke(card, Color3.fromRGB(70, 80, 100), 1)

	local name = Instance.new("TextLabel", card)
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 14, 0, 8)
	name.Size = UDim2.new(1, -180, 0, 28)
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = Color3.fromRGB(255, 220, 120)
	name.TextXAlignment = Enum.TextXAlignment.Right
	name.TextScaled = true
	name.Text = opts.name

	local desc = Instance.new("TextLabel", card)
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.new(0, 14, 0, 36)
	desc.Size = UDim2.new(1, -180, 0, 20)
	desc.Font = Enum.Font.Gotham
	desc.TextColor3 = Color3.fromRGB(200, 200, 200)
	desc.TextXAlignment = Enum.TextXAlignment.Right
	desc.TextScaled = true
	desc.Text = opts.desc or ""

	local stats = Instance.new("TextLabel", card)
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.new(0, 14, 0, 58)
	stats.Size = UDim2.new(1, -180, 0, 30)
	stats.Font = Enum.Font.Gotham
	stats.TextColor3 = Color3.fromRGB(160, 200, 230)
	stats.TextXAlignment = Enum.TextXAlignment.Right
	stats.TextScaled = true
	stats.Text = opts.stats or ""

	local btn = Instance.new("TextButton", card)
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -12, 0.5, 0)
	btn.Size = UDim2.new(0, 150, 0, 60)
	btn.BackgroundColor3 = opts.btnColor or Color3.fromRGB(60, 130, 80)
	btn.Font = Enum.Font.GothamBold
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextScaled = true
	btn.Text = opts.btnText
	corner(btn, 8)
	if opts.disabled then
		btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		btn.AutoButtonColor = false
		btn.Active = false
	else
		btn.MouseButton1Click:Connect(opts.onClick)
	end
	return card
end

local function refreshContent()
	clearContent()
	if not currentState then return end
	xpLabel.Text = "XP: " .. tostring(currentState.xp or 0)

	if currentTab == "Weapons" then
		for _, w in ipairs(WeaponConfig.List) do
			local owned = currentState.ownedWeapons and currentState.ownedWeapons[w.Id]
			local statsTxt = string.format("%s    %s    %s",
				string.format(Strings.Shop.Damage, w.Damage),
				string.format(Strings.Shop.Cooldown, w.Cooldown),
				string.format(Strings.Shop.Range, w.Range))
			local btnText, btnColor, onClick, disabled

			if w.Id == "Stick" then
				btnText, btnColor, disabled = Strings.Shop.Owned, Color3.fromRGB(80,80,80), true
			elseif owned then
				btnText, btnColor, disabled = Strings.Shop.Owned, Color3.fromRGB(80,80,80), true
			elseif w.Id == "Shotgun" then
				btnText  = string.format(Strings.Shop.PriceRobux, w.PriceRobux or 20)
				btnColor = Color3.fromRGB(255, 180, 60)
				onClick  = function() Remotes.PromptShotgun:FireServer() end
			else
				btnText  = string.format(Strings.Shop.Price, w.PriceXP or 0)
				btnColor = Color3.fromRGB(60, 130, 80)
				onClick  = function() Remotes.BuyXPItem:FireServer({ itemType="Weapon", itemId=w.Id }) end
				if (currentState.xp or 0) < (w.PriceXP or 0) then
					btnColor = Color3.fromRGB(120, 60, 60)
				end
			end

			buildItemCard{
				name = string.format("%s  (%s)", Strings.Weapons[w.DisplayKey] or w.Id, string.format(Strings.Shop.Level, w.Level)),
				desc = w.Description,
				stats = statsTxt,
				btnText = btnText, btnColor = btnColor, onClick = onClick, disabled = disabled,
			}
		end
	elseif currentTab == "Upgrades" then
		for _, id in ipairs({"Speed", "HP"}) do
			local cfg = GameConfig.PlaneUpgrades[id]
			local cur = (currentState.planeUpgrades and currentState.planeUpgrades[id]) or 0
			local maxed = cur >= #cfg.Levels
			local nextPrice = (not maxed) and cfg.Levels[cur + 1] or 0
			local statsTxt
			if id == "Speed" then
				local nextEffect = cfg.Effect[cur + 2] or cfg.Effect[#cfg.Effect]
				statsTxt = string.format("רמה %d/%d   ערך הבא: x%.2f", cur, #cfg.Levels, nextEffect)
			else
				local nextEffect = cfg.Effect[cur + 2] or cfg.Effect[#cfg.Effect]
				statsTxt = string.format("רמה %d/%d   HP מקס': %d", cur, #cfg.Levels, nextEffect)
			end
			local btnText, btnColor, onClick, disabled
			if maxed then
				btnText, btnColor, disabled = Strings.Shop.MaxLevel, Color3.fromRGB(80,80,80), true
			else
				btnText  = string.format(Strings.Shop.Price, nextPrice)
				btnColor = (currentState.xp or 0) >= nextPrice and Color3.fromRGB(60, 130, 80) or Color3.fromRGB(120, 60, 60)
				onClick  = function() Remotes.BuyXPItem:FireServer({ itemType="Upgrade", itemId=id }) end
			end
			buildItemCard{
				name = cfg.Display,
				desc = "שדרוג טיסה - מתאפס בין סבבים",
				stats = statsTxt,
				btnText = btnText, btnColor = btnColor, onClick = onClick, disabled = disabled,
			}
		end
	end
end

local function setTab(t)
	currentTab = t
	tabWeapons.BackgroundColor3  = (t=="Weapons")  and Color3.fromRGB(70, 100, 140) or Color3.fromRGB(40, 50, 65)
	tabUpgrades.BackgroundColor3 = (t=="Upgrades") and Color3.fromRGB(70, 100, 140) or Color3.fromRGB(40, 50, 65)
	refreshContent()
end
tabWeapons.MouseButton1Click:Connect(function() setTab("Weapons") end)
tabUpgrades.MouseButton1Click:Connect(function() setTab("Upgrades") end)

local function open()
	-- Refresh state from server
	local ok, state = pcall(function() return Remotes.GetShopState:InvokeServer() end)
	if ok and state then currentState = state end
	backdrop.Visible = true
	setTab(currentTab)
end
local function close() backdrop.Visible = false end
local function toggle() if backdrop.Visible then close() else open() end end

closeBtn.MouseButton1Click:Connect(close)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.B then
		toggle()
	elseif input.KeyCode == Enum.KeyCode.Escape and backdrop.Visible then
		close()
	end
end)

-- Refresh shop state periodically while open
task.spawn(function()
	while true do
		task.wait(0.7)
		if backdrop.Visible then
			local ok, state = pcall(function() return Remotes.GetShopState:InvokeServer() end)
			if ok and state then
				currentState = state
				refreshContent()
			end
		end
	end
end)
