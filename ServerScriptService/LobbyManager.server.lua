-- LobbyManager.server.lua
-- Place in: ServerScriptService as Script named "LobbyManager"
-- Detects players standing on the Ready Pad and triggers RoundManager.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local LobbyManager = {}

local function getReadyPad()
	local world = Workspace:FindFirstChild("IslandWorld")
	if not world then return nil end
	local lobby = world:FindFirstChild("Lobby")
	if not lobby then return nil end
	return lobby:FindFirstChild("ReadyPad")
end

-- Returns count of distinct players whose HumanoidRootPart is above the pad.
local function countOnPad(pad)
	if not pad then return 0 end
	local seen = {}
	local padPos = pad.Position
	local s = pad.Size
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = hrp.Position - padPos
				if math.abs(d.X) <= s.X/2 + 1 and math.abs(d.Z) <= s.Z/2 + 1 and d.Y >= -2 and d.Y <= 8 then
					seen[p.UserId] = true
				end
			end
		end
	end
	local n = 0
	for _ in pairs(seen) do n = n + 1 end
	return n
end

function LobbyManager.Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local rm = _G.RoundManager
			if not rm then continue end
			if rm.GetState() ~= "LOBBY" and rm.GetState() ~= "COUNTDOWN" then
				continue
			end
			local pad = getReadyPad()
			if not pad then continue end
			local n = countOnPad(pad)
			if rm.GetState() == "LOBBY" then
				if n >= 1 then rm.StartCountdown() end
			elseif rm.GetState() == "COUNTDOWN" then
				if n == 0 then rm.CancelCountdown() end
			end
		end
	end)
	print("[LobbyManager] Started.")
end

_G.LobbyManager = LobbyManager
LobbyManager.Start()
print("[LobbyManager] Ready.")
