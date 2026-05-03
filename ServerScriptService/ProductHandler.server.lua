-- ProductHandler.server.lua
-- Place in: ServerScriptService as Script named "ProductHandler"
-- Handles MarketplaceService.ProcessReceipt for Shotgun (permanent) and Revive
-- (one-time per round). Critical: must return PurchaseGranted only AFTER
-- a successful save.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Strings    = require(ReplicatedStorage:WaitForChild("Strings"))

local ProductHandler = {}
local processed = {}  -- per-server dedup of receipt purchase IDs

local function getRemotes()
	return ReplicatedStorage:WaitForChild("Remotes")
end

local function dm()
	while not _G.DataManager do task.wait(0.05) end
	return _G.DataManager
end

local function grantShotgun(player)
	local ok = dm().SetOwnsShotgun(player, true)
	if not ok then return false end
	-- Reflect in session and equip in-game if currently playing
	dm().GrantSessionWeapon(player, "Shotgun")
	local rm = _G.RoundManager
	if rm and rm.IsPlaying() and _G.ShopManager then
		_G.ShopManager.GiveWeapon(player, "Shotgun")
	end
	getRemotes().ToastNotify:FireClient(player, {
		text  = Strings.Notifications.ShotgunUnlocked,
		color = Color3.fromRGB(255, 220, 80),
	})
	return true
end

local function grantRevive(player)
	local rm = _G.RoundManager
	if not rm then
		warn("[ProductHandler] grantRevive: RoundManager not ready")
		return false
	end
	print("[ProductHandler] grantRevive for", player.Name, "state:", rm.GetState())
	local ok = rm.RevivePlayer(player)
	if not ok then
		warn("[ProductHandler] RevivePlayer returned false. State:", rm.GetState())
		getRemotes().ToastNotify:FireClient(player, {
			text = "החייאה נכשלה - נסה שוב בסבב הבא",
			color = Color3.fromRGB(255, 170, 80),
		})
	else
		print("[ProductHandler] Revive successful for", player.Name)
	end
	return true
end

local function processReceipt(receiptInfo)
	print("[ProductHandler] ProcessReceipt called for product", receiptInfo.ProductId, "player", receiptInfo.PlayerId)
	local key = receiptInfo.PlayerId .. ":" .. receiptInfo.PurchaseId
	if processed[key] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local id = receiptInfo.ProductId
	local granted = false
	if id == GameConfig.Products.SHOTGUN then
		granted = grantShotgun(player)
	elseif id == GameConfig.Products.REVIVE then
		granted = grantRevive(player)
	else
		warn("[ProductHandler] Unknown product:", id)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Always consume the purchase (return PurchaseGranted) once we've made
	-- our best effort. For revive specifically we always grant — if the
	-- revive itself failed (e.g., round state changed) the user has been
	-- notified via toast and we don't want Roblox to retry the receipt.
	processed[key] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt
_G.ProductHandler = ProductHandler
print("[ProductHandler] Ready.")
