-- PlayerTagsClient.lua
-- Place in: StarterPlayerScripts as LocalScript named "PlayerTagsClient"
-- Renders a "שיא: M:SS" BillboardGui above each player's head, including the
-- local player. Listens to UpdateBestTimes for live updates.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage:WaitForChild("Strings"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TAG_NAME = "BestTimeTag"

local bestTimes = {}  -- [userId] = seconds

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec or 0))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function formatTagText(seconds)
	if not seconds or seconds <= 0 then
		return Strings.BestTime.Tag .. ": " .. Strings.BestTime.None
	end
	return Strings.BestTime.Tag .. ": " .. fmtTime(seconds)
end

local function buildTag(character)
	local head = character:FindFirstChild("Head")
	if not head then return nil end
	local existing = head:FindFirstChild(TAG_NAME)
	if existing then return existing end

	local bb = Instance.new("BillboardGui")
	bb.Name = TAG_NAME
	bb.Adornee = head
	bb.Size = UDim2.new(0, 180, 0, 36)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = head

	local frame = Instance.new("Frame", bb)
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	local c = Instance.new("UICorner", frame); c.CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", frame); s.Color = Color3.fromRGB(120, 200, 255); s.Thickness = 1.5

	local label = Instance.new("TextLabel", frame)
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -8, 1, 0)
	label.Position = UDim2.new(0, 4, 0, 0)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(180, 220, 255)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Text = formatTagText(0)
	return bb
end

local function refreshTagFor(player)
	local char = player.Character
	if not char then return end
	local bb = buildTag(char)
	if not bb then return end
	local frame = bb:FindFirstChildWhichIsA("Frame")
	if not frame then return end
	local label = frame:FindFirstChild("Label")
	if not label then return end
	label.Text = formatTagText(bestTimes[player.UserId])
end

local function refreshAll()
	for _, p in ipairs(Players:GetPlayers()) do
		refreshTagFor(p)
	end
end

local function attachToCharacter(player)
	local char = player.Character
	if not char then return end
	-- Wait for head, then build the tag once.
	task.spawn(function()
		local head = char:WaitForChild("Head", 5)
		if head then
			refreshTagFor(player)
		end
	end)
end

-- Hook player events
local function onPlayer(p)
	if p.Character then attachToCharacter(p) end
	p.CharacterAdded:Connect(function() attachToCharacter(p) end)
end
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerAdded:Connect(onPlayer)

-- Listen for live updates
Remotes.UpdateBestTimes.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	for k, v in pairs(payload) do
		bestTimes[tonumber(k) or k] = v
	end
	refreshAll()
end)

-- Initial fetch
task.spawn(function()
	local ok, snapshot = pcall(function()
		return Remotes.GetBestTimes:InvokeServer()
	end)
	if ok and type(snapshot) == "table" then
		for k, v in pairs(snapshot) do
			bestTimes[tonumber(k) or k] = v
		end
		refreshAll()
	end
end)
