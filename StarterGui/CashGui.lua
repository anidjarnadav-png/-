-- CashGui.lua
-- Place in: StarterGui > ScreenGui named "CashGui"
-- Then inside the ScreenGui add a LocalScript and paste this code.
-- (Or place directly as a LocalScript inside StarterGui)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateCashEvent = remotes:WaitForChild("UpdateCash")
local notifyEvent = remotes:WaitForChild("Notify")

-- -------------------------------------------------------
-- Build the ScreenGui
-- -------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TycoonHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player.PlayerGui

-- Cash Frame (top center)
local cashFrame = Instance.new("Frame")
cashFrame.Name = "CashFrame"
cashFrame.Size = UDim2.new(0, 260, 0, 60)
cashFrame.Position = UDim2.new(0.5, -130, 0, 10)
cashFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
cashFrame.BackgroundTransparency = 0.3
cashFrame.BorderSizePixel = 0
cashFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = cashFrame

local cashIcon = Instance.new("TextLabel")
cashIcon.Size = UDim2.new(0, 40, 1, 0)
cashIcon.Position = UDim2.new(0, 5, 0, 0)
cashIcon.BackgroundTransparency = 1
cashIcon.Text = "$"
cashIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
cashIcon.Font = Enum.Font.GothamBold
cashIcon.TextScaled = true
cashIcon.Parent = cashFrame

local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLabel"
cashLabel.Size = UDim2.new(1, -50, 1, 0)
cashLabel.Position = UDim2.new(0, 45, 0, 0)
cashLabel.BackgroundTransparency = 1
cashLabel.Text = "0"
cashLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
cashLabel.Font = Enum.Font.GothamBold
cashLabel.TextScaled = true
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Parent = cashFrame

-- Notification Frame (bottom center)
local notifFrame = Instance.new("Frame")
notifFrame.Name = "NotifFrame"
notifFrame.Size = UDim2.new(0, 400, 0, 50)
notifFrame.Position = UDim2.new(0.5, -200, 1, -80)
notifFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
notifFrame.BackgroundTransparency = 1
notifFrame.BorderSizePixel = 0
notifFrame.Parent = screenGui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 8)
notifCorner.Parent = notifFrame

local notifLabel = Instance.new("TextLabel")
notifLabel.Name = "NotifLabel"
notifLabel.Size = UDim2.new(1, -20, 1, 0)
notifLabel.Position = UDim2.new(0, 10, 0, 0)
notifLabel.BackgroundTransparency = 1
notifLabel.Text = ""
notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
notifLabel.Font = Enum.Font.Gotham
notifLabel.TextScaled = true
notifLabel.Parent = notifFrame

-- -------------------------------------------------------
-- Format large numbers: 1500 -> "1.5K", 2000000 -> "2M"
-- -------------------------------------------------------
local function formatCash(amount)
	if amount >= 1e9 then
		return string.format("%.1fB", amount / 1e9)
	elseif amount >= 1e6 then
		return string.format("%.1fM", amount / 1e6)
	elseif amount >= 1e3 then
		return string.format("%.1fK", amount / 1e3)
	else
		return tostring(math.floor(amount))
	end
end

-- -------------------------------------------------------
-- Cash update handler
-- -------------------------------------------------------
local currentCash = 0

updateCashEvent.OnClientEvent:Connect(function(newCash)
	local old = currentCash
	currentCash = newCash
	cashLabel.Text = formatCash(newCash)

	-- Flash green on increase, red on decrease
	if newCash > old then
		TweenService:Create(cashLabel, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(100, 255, 100)}):Play()
		task.wait(0.15)
		TweenService:Create(cashLabel, TweenInfo.new(0.3), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	elseif newCash < old then
		TweenService:Create(cashLabel, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 80, 80)}):Play()
		task.wait(0.15)
		TweenService:Create(cashLabel, TweenInfo.new(0.3), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end
end)

-- -------------------------------------------------------
-- Notification handler
-- -------------------------------------------------------
local notifQueue = {}
local isShowingNotif = false

local function showNextNotif()
	if isShowingNotif or #notifQueue == 0 then return end
	isShowingNotif = true

	local msg = table.remove(notifQueue, 1)
	notifLabel.Text = msg

	-- Fade in
	TweenService:Create(notifFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.2}):Play()
	TweenService:Create(notifLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()

	task.wait(2.5)

	-- Fade out
	TweenService:Create(notifFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
	TweenService:Create(notifLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	task.wait(0.3)

	isShowingNotif = false
	showNextNotif()
end

notifLabel.TextTransparency = 1

notifyEvent.OnClientEvent:Connect(function(message)
	table.insert(notifQueue, message)
	task.spawn(showNextNotif)
end)
