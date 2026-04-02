-- LocalScript.client.lua
-- Place in: StarterPlayerScripts > LocalScript named "TycoonClient"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getCashFunction = remotes:WaitForChild("GetCash")

-- Request initial cash on join
task.spawn(function()
	task.wait(2)
	-- The server fires UpdateCash on load, but request it manually in case it was missed
	local cash = getCashFunction:InvokeServer()
	-- UpdateCash event will handle displaying it; this is just a fallback trigger
end)

-- Optional: proximity prompt helper text
-- Show button names when player gets close to a button
local camera = workspace.CurrentCamera

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Find all buttons near the player and highlight them
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return end

	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("Owner") ~= player.Name then continue end
		for _, obj in ipairs(plot:GetChildren()) do
			if obj:IsA("BasePart") and (obj.Name:find("Button") or obj.Name == "Collector") then
				local dist = (obj.Position - root.Position).Magnitude
				if dist < 8 then
					obj.Material = Enum.Material.Neon
				else
					obj.Material = Enum.Material.SmoothPlastic
				end
			end
		end
	end
end)
