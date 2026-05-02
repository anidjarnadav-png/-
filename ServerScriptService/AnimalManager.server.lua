-- AnimalManager.server.lua
-- Place in: ServerScriptService as Script named "AnimalManager"
-- Spawns and runs animals: builds models, runs FSM (Idle -> Chase -> Attack).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")
local Debris            = game:GetService("Debris")

local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))
local AnimalConfig = require(ReplicatedStorage:WaitForChild("AnimalConfig"))
local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))

local AnimalManager = {}
local active = {}            -- [model] = stateTable
local spawning = false
local roundStartTime = 0
local Remotes -- lazy

local function getRemotes()
	if Remotes then return Remotes end
	Remotes = ReplicatedStorage:WaitForChild("Remotes")
	return Remotes
end

local function makePart(props)
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

-- Build a simple but recognizable animal model.
local function buildAnimalModel(spec)
	local model = Instance.new("Model")
	model.Name = spec.Id

	local hrp = makePart{
		Name="HumanoidRootPart",
		Size=Vector3.new(spec.BodySize.X, spec.BodySize.Y, spec.BodySize.Z),
		Color=spec.BodyColor, Material=Enum.Material.SmoothPlastic,
		CanCollide=true, Transparency=1, Parent=model,
	}
	model.PrimaryPart = hrp

	-- Body
	local body = makePart{
		Name="Body", Size=spec.BodySize, Color=spec.BodyColor,
		Material=Enum.Material.SmoothPlastic, CanCollide=false, Parent=model,
	}
	local bodyWeld = Instance.new("WeldConstraint", body)
	body.CFrame = hrp.CFrame
	bodyWeld.Part0 = hrp
	bodyWeld.Part1 = body

	-- Head
	local head = makePart{
		Name="Head", Size=spec.HeadSize, Color=spec.BodyColor,
		Material=Enum.Material.SmoothPlastic, CanCollide=false, Parent=model,
	}
	head.CFrame = hrp.CFrame * CFrame.new(0, spec.BodySize.Y*0.3, -spec.BodySize.Z*0.55)
	local hw = Instance.new("WeldConstraint", head); hw.Part0 = hrp; hw.Part1 = head

	-- Eyes
	for _, sx in ipairs({-1, 1}) do
		local eye = makePart{
			Name="Eye", Shape=Enum.PartType.Ball, Size=Vector3.new(0.3,0.3,0.3),
			Color=Color3.fromRGB(20,20,20), Material=Enum.Material.SmoothPlastic,
			CanCollide=false, Parent=model,
		}
		eye.CFrame = head.CFrame * CFrame.new(sx*spec.HeadSize.X*0.3, spec.HeadSize.Y*0.2, -spec.HeadSize.Z*0.45)
		local ew = Instance.new("WeldConstraint", eye); ew.Part0 = head; ew.Part1 = eye
	end

	-- Mane (lion only)
	if spec.ManeColor then
		local mane = makePart{
			Name="Mane", Shape=Enum.PartType.Ball,
			Size=Vector3.new(spec.HeadSize.X*1.7, spec.HeadSize.Y*1.7, spec.HeadSize.Z*1.7),
			Color=spec.ManeColor, Material=Enum.Material.SmoothPlastic,
			CanCollide=false, Parent=model,
		}
		mane.CFrame = head.CFrame
		local mw = Instance.new("WeldConstraint", mane); mw.Part0 = head; mw.Part1 = mane
	end

	-- Legs
	for i, off in ipairs({
		Vector3.new(-spec.BodySize.X*0.3, -spec.BodySize.Y*0.5, -spec.BodySize.Z*0.35),
		Vector3.new( spec.BodySize.X*0.3, -spec.BodySize.Y*0.5, -spec.BodySize.Z*0.35),
		Vector3.new(-spec.BodySize.X*0.3, -spec.BodySize.Y*0.5,  spec.BodySize.Z*0.35),
		Vector3.new( spec.BodySize.X*0.3, -spec.BodySize.Y*0.5,  spec.BodySize.Z*0.35),
	}) do
		local leg = makePart{
			Name="Leg", Size=spec.LegSize, Color=spec.BodyColor,
			Material=Enum.Material.SmoothPlastic, CanCollide=false, Parent=model,
		}
		leg.CFrame = hrp.CFrame * CFrame.new(off)
		local lw = Instance.new("WeldConstraint", leg); lw.Part0 = hrp; lw.Part1 = leg
	end

	-- Tail
	local tail = makePart{
		Name="Tail", Size=Vector3.new(0.4, 0.4, spec.BodySize.Z*0.4),
		Color=spec.BodyColor, Material=Enum.Material.SmoothPlastic,
		CanCollide=false, Parent=model,
	}
	tail.CFrame = hrp.CFrame * CFrame.new(0, spec.BodySize.Y*0.2, spec.BodySize.Z*0.6)
	local tw = Instance.new("WeldConstraint", tail); tw.Part0 = hrp; tw.Part1 = tail

	-- Humanoid
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = spec.HP
	hum.Health    = spec.HP
	hum.WalkSpeed = spec.WalkSpeed
	hum.AutoRotate = true
	hum.HipHeight  = spec.LegSize.Y * 0.5
	hum.BreakJointsOnDeath = false
	hum.Parent = model

	-- HP bar above
	local bb = Instance.new("BillboardGui")
	bb.Name = "HPBar"
	bb.Size = UDim2.new(0, 80, 0, 18)
	bb.StudsOffset = Vector3.new(0, spec.BodySize.Y + 1.5, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = hrp
	bb.Parent = hrp
	local bg = Instance.new("Frame", bb)
	bg.Size = UDim2.new(1,0,1,0)
	bg.BackgroundColor3 = Color3.fromRGB(40,40,40)
	bg.BorderSizePixel  = 0
	local fill = Instance.new("Frame", bg)
	fill.Name = "Fill"
	fill.Size = UDim2.new(1,0,1,0)
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	fill.BorderSizePixel  = 0
	local label = Instance.new("TextLabel", bb)
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1,0,1,0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255,255,255)
	label.TextStrokeTransparency = 0
	label.Text = (Strings.Animals[spec.DisplayKey] or spec.Id) .. "  " .. spec.HP .. "/" .. spec.HP

	model:SetAttribute("AnimalId", spec.Id)
	model:SetAttribute("Level", spec.Level)
	model:SetAttribute("XPReward", spec.XPReward)
	model:SetAttribute("Damage", spec.Damage)

	return model
end

local function pickSpawnPos()
	-- Randomly pick a position on the island, between MinDistanceFromPlayer and MaxDistanceFromPlayer
	-- of any active player. Prefer outside crash clearing.
	local cfg = GameConfig.AnimalSpawning
	for _ = 1, 30 do
		local players = Players:GetPlayers()
		local origin
		for _, p in ipairs(players) do
			if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				origin = p.Character.HumanoidRootPart.Position
				break
			end
		end
		if not origin then origin = Vector3.new(0, GameConfig.Island.BaseSize.Y, 0) end
		local angle = math.random() * math.pi * 2
		local d     = math.random(cfg.MinDistanceFromPlayer, cfg.MaxDistanceFromPlayer)
		local x = origin.X + math.cos(angle) * d
		local z = origin.Z + math.sin(angle) * d
		local hx = GameConfig.Island.BaseSize.X / 2 - 20
		local hz = GameConfig.Island.BaseSize.Z / 2 - 20
		if math.abs(x) <= hx and math.abs(z) <= hz then
			return Vector3.new(x, GameConfig.Island.BaseSize.Y + 4, z)
		end
	end
	return Vector3.new(60, GameConfig.Island.BaseSize.Y + 4, 60)
end

local function pickSpecForElapsed(elapsed)
	-- Find current weight stage
	local weights = GameConfig.AnimalSpawning.WeightStages[1].weights
	for _, stage in ipairs(GameConfig.AnimalSpawning.WeightStages) do
		if elapsed >= stage.time then weights = stage.weights end
	end
	-- Weighted pick: index 1=dog, 2=wolf, 3=bear, 4=lion
	local total = 0
	for _, w in ipairs(weights) do total = total + w end
	local roll = math.random() * total
	local accum = 0
	for i, w in ipairs(weights) do
		accum = accum + w
		if roll <= accum then
			return AnimalConfig.List[i]
		end
	end
	return AnimalConfig.List[1]
end

local function findNearestPlayer(animal)
	local hrp = animal.PrimaryPart
	if not hrp then return nil, math.huge end
	local nearest, nearestD = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.Health > 0 then
			local pHrp = char:FindFirstChild("HumanoidRootPart")
			if pHrp then
				local d = (pHrp.Position - hrp.Position).Magnitude
				if d < nearestD then
					nearestD = d
					nearest  = p
				end
			end
		end
	end
	return nearest, nearestD
end

local function attachHumanoidWatcher(model, spec)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.HealthChanged:Connect(function(hp)
		local hrp = model.PrimaryPart
		if hrp then
			local bb = hrp:FindFirstChild("HPBar")
			if bb then
				local fill  = bb:FindFirstChild("Frame") and bb.Frame:FindFirstChild("Fill")
				local label = bb:FindFirstChildOfClass("TextLabel")
				if fill then
					fill.Size = UDim2.new(math.clamp(hp / hum.MaxHealth, 0, 1), 0, 1, 0)
				end
				if label then
					label.Text = (Strings.Animals[spec.DisplayKey] or spec.Id) .. "  " .. math.floor(hp) .. "/" .. spec.HP
				end
			end
		end
	end)
	hum.Died:Connect(function()
		local pos = model.PrimaryPart and model.PrimaryPart.Position or Vector3.new()
		getRemotes().AnimalDied:FireAllClients({
			animalId = spec.Id, position = pos, displayName = Strings.Animals[spec.DisplayKey] or spec.Id,
		})
		active[model] = nil
		Debris:AddItem(model, 4)
	end)
end

local function runAnimalAI(model, spec)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hrp = model.PrimaryPart
	if not hum or not hrp then return end

	local state = "IDLE"
	local nextWander = 0
	local nextAttack = 0

	while model.Parent and hum.Health > 0 do
		local rm = _G.RoundManager
		if not rm or rm.GetState() ~= "PLAYING" then
			task.wait(0.5)
		else
			local target, dist = findNearestPlayer(model)
			if target and dist <= spec.AggroRange then
				if dist <= spec.AttackRange then
					state = "ATTACK"
					if tick() >= nextAttack then
						-- Apply damage to target
						local char = target.Character
						local tHum = char and char:FindFirstChildOfClass("Humanoid")
						if tHum and tHum.Health > 0 then
							tHum:TakeDamage(spec.Damage)
							-- visual: shake animal forward briefly
							local pHrp = char and char:FindFirstChild("HumanoidRootPart")
							if pHrp then
								getRemotes().ShowDamage:FireAllClients({
									position = pHrp.Position + Vector3.new(0, 3, 0),
									amount   = spec.Damage,
									color    = Color3.fromRGB(255, 80, 80),
								})
							end
						end
						nextAttack = tick() + spec.AttackCD
					end
				else
					state = "CHASE"
					hum:MoveTo(target.Character.HumanoidRootPart.Position)
				end
			else
				state = "IDLE"
				if tick() >= nextWander then
					local angle = math.random() * math.pi * 2
					local r     = math.random(8, 20)
					local goal  = hrp.Position + Vector3.new(math.cos(angle)*r, 0, math.sin(angle)*r)
					hum:MoveTo(goal)
					nextWander = tick() + math.random(4, 7)
				end
			end
			task.wait(0.3)
		end
	end
end

function AnimalManager.SpawnOne()
	local elapsed = tick() - roundStartTime
	local spec = pickSpecForElapsed(elapsed)
	local model = buildAnimalModel(spec)
	local pos = pickSpawnPos()
	model:SetPrimaryPartCFrame(CFrame.new(pos))
	model.Parent = Workspace

	active[model] = { spec = spec }
	attachHumanoidWatcher(model, spec)
	task.spawn(runAnimalAI, model, spec)
	return model
end

function AnimalManager.GetActive() return active end

function AnimalManager.CountActive()
	local n = 0
	for _ in pairs(active) do n = n + 1 end
	return n
end

function AnimalManager.StartSpawning()
	spawning = true
	roundStartTime = tick()
	task.spawn(function()
		-- initial spawn burst
		for i = 1, 4 do
			if not spawning then return end
			AnimalManager.SpawnOne()
			task.wait(0.5)
		end
		while spawning do
			task.wait(GameConfig.AnimalSpawning.SpawnInterval)
			if not spawning then break end
			if AnimalManager.CountActive() < GameConfig.AnimalSpawning.MaxAlive then
				AnimalManager.SpawnOne()
			end
		end
	end)
end

function AnimalManager.StopSpawning()
	spawning = false
end

function AnimalManager.ClearAll()
	for model, _ in pairs(active) do
		if model.Parent then model:Destroy() end
	end
	active = {}
end

_G.AnimalManager = AnimalManager
print("[AnimalManager] Ready.")
