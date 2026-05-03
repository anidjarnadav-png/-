-- ShopManager.server.lua
-- Place in: ServerScriptService as Script named "ShopManager"
-- Handles XP-based purchases (weapons, plane upgrades) and tool spawning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local MarketplaceService= game:GetService("MarketplaceService")

local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))

local ShopManager = {}
local Remotes

local function getRemotes()
	if Remotes then return Remotes end
	Remotes = ReplicatedStorage:WaitForChild("Remotes")
	return Remotes
end

local function dm()
	while not _G.DataManager do task.wait(0.05) end
	return _G.DataManager
end

-- Build a Tool instance for a weapon spec.
local function buildToolForWeapon(spec)
	local tool = Instance.new("Tool")
	tool.Name = Strings.Weapons[spec.DisplayKey] or spec.Id
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", spec.Id)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = spec.HandleSize
	handle.Color = spec.HandleColor
	handle.Material = spec.Type == "Ranged" and Enum.Material.Metal or Enum.Material.Wood
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	-- Tool tag
	local sg = Instance.new("BillboardGui")
	sg.Adornee = handle
	sg.Size = UDim2.new(0, 100, 0, 30)
	sg.StudsOffset = Vector3.new(0, 1, 0)
	sg.AlwaysOnTop = true
	sg.Parent = handle
	local lbl = Instance.new("TextLabel", sg)
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0
	lbl.Text = tool.Name

	return tool
end

-- Removes any tools the player currently has, then gives the requested one.
function ShopManager.GiveWeapon(player, weaponId)
	local spec = WeaponConfig.ById[weaponId]
	if not spec then return false end
	-- ensure session ownership reflects this
	dm().GrantSessionWeapon(player, weaponId)
	local sess = dm().GetSession(player)
	sess.CurrentWeapon = weaponId

	local char = player.Character
	if not char then return false end
	local backpack = player:FindFirstChildOfClass("Backpack")
	-- remove only previously-spawned tools (so we don't infinitely stack)
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") then c:Destroy() end
	end
	if backpack then
		for _, c in ipairs(backpack:GetChildren()) do
			if c:IsA("Tool") then c:Destroy() end
		end
	end
	-- Spawn ALL owned weapons; player chooses via 1/2/3 keys (Roblox default).
	for ownedId, _ in pairs(sess.OwnedWeapons) do
		local s = WeaponConfig.ById[ownedId]
		if s then
			local tool = buildToolForWeapon(s)
			tool.Parent = backpack or char
		end
	end
	return true
end

-- Handle XP purchase requests
function ShopManager.HandleBuyXP(player, payload)
	local rm = _G.RoundManager
	if not rm or not rm.IsPlaying() then
		getRemotes().ToastNotify:FireClient(player, {
			text = "ניתן לקנות רק במהלך הסבב", color = Color3.fromRGB(255,170,80),
		})
		return
	end
	if not payload or type(payload) ~= "table" then return end

	local sess = dm().GetSession(player)
	if payload.itemType == "Weapon" then
		local weapon = WeaponConfig.ById[payload.itemId]
		if not weapon then return end
		if WeaponConfig.IsPermanent(weapon.Id) then
			-- Shotgun: must be Robux
			getRemotes().ToastNotify:FireClient(player, {
				text = "רובה ציד נרכש רק ב-Robux", color = Color3.fromRGB(255,170,80),
			})
			return
		end
		if dm().OwnsWeapon(player, weapon.Id) then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.Owned, color = Color3.fromRGB(180,180,180),
			})
			return
		end
		local price = weapon.PriceXP or math.huge
		if not dm().SpendXP(player, price) then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.NotEnoughXP, color = Color3.fromRGB(255,100,100),
			})
			return
		end
		ShopManager.GiveWeapon(player, weapon.Id)
		getRemotes().ToastNotify:FireClient(player, {
			text  = Strings.Shop.Purchased,
			color = Color3.fromRGB(120,220,120),
		})
	elseif payload.itemType == "Upgrade" then
		local id = payload.itemId  -- "Speed" or "HP"
		local cfg = GameConfig.PlaneUpgrades[id]
		if not cfg then return end
		local cur = sess.PlaneUpgrades[id] or 0
		if cur >= #cfg.Levels then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.MaxLevel, color = Color3.fromRGB(180,180,180),
			})
			return
		end
		local price = cfg.Levels[cur + 1]
		if not dm().SpendXP(player, price) then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.NotEnoughXP, color = Color3.fromRGB(255,100,100),
			})
			return
		end
		sess.PlaneUpgrades[id] = cur + 1
		-- Apply effect immediately
		local char = player.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			if id == "HP" then
				local newMax = cfg.Effect[sess.PlaneUpgrades.HP + 1]
				local diff = newMax - hum.MaxHealth
				hum.MaxHealth = newMax
				if diff > 0 then
					hum.Health = math.min(newMax, hum.Health + diff)
				end
			elseif id == "Speed" then
				local mul = cfg.Effect[sess.PlaneUpgrades.Speed + 1]
				hum.WalkSpeed = 16 * mul
			end
		end
		getRemotes().ToastNotify:FireClient(player, {
			text  = Strings.Shop.Purchased,
			color = Color3.fromRGB(120,220,120),
		})
	end
end

function ShopManager.HandlePromptShotgun(player)
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, GameConfig.Products.SHOTGUN)
	end)
	if not ok then
		warn("[ShopManager] PromptShotgun failed:", err)
		getRemotes().ToastNotify:FireClient(player, {
			text = Strings.Notifications.PurchaseFailed, color = Color3.fromRGB(255,100,100),
		})
	end
end

function ShopManager.HandlePromptRevive(player)
	local rm = _G.RoundManager
	-- Allow during PLAYING (normal case) AND during the brief death window
	-- before the round formally ends. The new round-end logic keeps state
	-- as PLAYING while any player has a death countdown active.
	if not rm or (rm.GetState() ~= "PLAYING" and rm.GetState() ~= "ENDING") then
		warn("[ShopManager] PromptRevive blocked, state:", rm and rm.GetState() or "nil")
		return
	end
	local sess = dm().GetSession(player)
	if sess.UsedRevive then
		getRemotes().ToastNotify:FireClient(player, {
			text = Strings.Death.ReviveUsed, color = Color3.fromRGB(255,170,80),
		})
		return
	end
	-- Don't try to revive an already-alive player.
	if sess.Alive then return end
	print("[ShopManager] Prompting revive for", player.Name)
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, GameConfig.Products.REVIVE)
	end)
	if not ok then
		warn("[ShopManager] PromptRevive failed:", err)
		getRemotes().ToastNotify:FireClient(player, {
			text  = Strings.Notifications.PurchaseFailed,
			color = Color3.fromRGB(255, 100, 100),
		})
	end
end

function ShopManager.GetShopState(player)
	local sess = dm().GetSession(player)
	local owned = {}
	for k in pairs(sess.OwnedWeapons) do owned[k] = true end
	return {
		ownsShotgun = dm().OwnsShotgun(player),
		ownedWeapons = owned,
		planeUpgrades = sess.PlaneUpgrades,
		xp = sess.XP,
		alive = sess.Alive,
		usedRevive = sess.UsedRevive,
	}
end

function ShopManager.Start()
	getRemotes().BuyXPItem.OnServerEvent:Connect(function(player, payload)
		local ok, err = pcall(ShopManager.HandleBuyXP, player, payload)
		if not ok then warn("[ShopManager] BuyXPItem error:", err) end
	end)
	getRemotes().PromptShotgun.OnServerEvent:Connect(function(player)
		ShopManager.HandlePromptShotgun(player)
	end)
	getRemotes().PromptRevive.OnServerEvent:Connect(function(player)
		ShopManager.HandlePromptRevive(player)
	end)
	getRemotes().GetShopState.OnServerInvoke = function(player)
		return ShopManager.GetShopState(player)
	end
end

ShopManager.Start()
_G.ShopManager = ShopManager
print("[ShopManager] Ready.")
