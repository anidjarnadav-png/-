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
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
	return w
end

-- Build a detailed animal model. Uses a small invisible HumanoidRootPart for
-- physics/collision and welds every visible part to it via WeldConstraint.
-- Reliable rendering — no Motor6D animation (caused instability earlier).
local function buildAnimalModel(spec)
	local model = Instance.new("Model")
	model.Name = spec.Id

	-- Standard-sized invisible HRP. Smaller than the visible body so it
	-- doesn't trap on terrain or hills. Massless=false so the Humanoid can
	-- move it; visible parts are Massless=true so they don't fight physics.
	local hrpSize = Vector3.new(
		math.max(1.5, spec.BodySize.X * 0.6),
		math.max(1.5, spec.BodySize.Y * 0.6),
		math.max(1.5, spec.BodySize.Z * 0.6)
	)
	local hrp = makePart{
		Name = "HumanoidRootPart",
		Size = hrpSize,
		Color = spec.BodyColor,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		CanCollide = true,
		Massless = false,
		Parent = model,
	}
	model.PrimaryPart = hrp

	-- Convenience: place a visible part at an offset relative to hrp and weld.
	local function addPart(name, size, offset, props)
		props = props or {}
		props.Name = name
		props.Size = size
		props.Color = props.Color or spec.BodyColor
		props.Material = props.Material or Enum.Material.SmoothPlastic
		props.CanCollide = false
		props.Massless = true
		props.Parent = model
		local p = makePart(props)
		p.CFrame = hrp.CFrame * offset
		weld(hrp, p)
		return p
	end

	-- Main body (chest+rear in one rounded mass)
	addPart("Body",
		Vector3.new(spec.BodySize.X, spec.BodySize.Y, spec.BodySize.Z),
		CFrame.new(0, 0, 0))

	-- Slight chest bulge
	addPart("Chest",
		Vector3.new(spec.BodySize.X * 1.1, spec.BodySize.Y * 1.05, spec.BodySize.Z * 0.5),
		CFrame.new(0, 0, -spec.BodySize.Z * 0.18))

	-- Neck cylinder
	local neckLen = math.max(0.6, spec.BodySize.Y * 0.5)
	addPart("Neck",
		Vector3.new(neckLen, spec.BodySize.X * 0.55, spec.BodySize.X * 0.55),
		CFrame.new(0, spec.BodySize.Y * 0.2, -spec.BodySize.Z * 0.55) * CFrame.Angles(0, 0, math.rad(70)),
		{ Shape = Enum.PartType.Cylinder })

	-- Head — shape varies per species
	local headShape = Enum.PartType.Block
	if spec.Id == "Bear" or spec.Id == "Lion" then
		headShape = Enum.PartType.Ball
	end
	local head = addPart("Head",
		spec.HeadSize,
		CFrame.new(0, spec.BodySize.Y * 0.5, -spec.BodySize.Z * 0.7),
		{ Shape = headShape })

	-- Snout (welded to head)
	local snoutLen = spec.HeadSize.Z * 0.55
	local snoutR, snoutG, snoutB
	if spec.Id == "Lion" then
		snoutR, snoutG, snoutB = 230, 200, 130
	else
		snoutR = math.max(0, math.floor(spec.BodyColor.R * 255 - 30))
		snoutG = math.max(0, math.floor(spec.BodyColor.G * 255 - 30))
		snoutB = math.max(0, math.floor(spec.BodyColor.B * 255 - 30))
	end
	local snout = makePart{
		Name = "Snout",
		Size = Vector3.new(spec.HeadSize.X * 0.65, spec.HeadSize.Y * 0.55, snoutLen),
		Color = Color3.fromRGB(snoutR, snoutG, snoutB),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	}
	snout.CFrame = head.CFrame * CFrame.new(0, -spec.HeadSize.Y * 0.1, -(spec.HeadSize.Z * 0.5 + snoutLen * 0.4))
	weld(head, snout)

	-- Nose tip
	local nose = makePart{
		Name = "Nose", Shape = Enum.PartType.Ball,
		Size = Vector3.new(spec.HeadSize.X * 0.28, spec.HeadSize.X * 0.28, spec.HeadSize.X * 0.28),
		Color = Color3.fromRGB(20, 16, 18),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	}
	nose.CFrame = snout.CFrame * CFrame.new(0, 0, -snoutLen * 0.5)
	weld(snout, nose)

	-- Eyes
	for _, sx in ipairs({-1, 1}) do
		local eye = makePart{
			Name = "Eye", Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.32, 0.32, 0.32),
			Color = Color3.fromRGB(20, 20, 20),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		eye.CFrame = head.CFrame * CFrame.new(sx * spec.HeadSize.X * 0.32, spec.HeadSize.Y * 0.18, -spec.HeadSize.Z * 0.45)
		weld(head, eye)
	end

	-- Ears: per-species
	local function buildEar(side)
		local ear, cf
		if spec.Id == "Dog" then
			ear = makePart{
				Name = "Ear",
				Size = Vector3.new(0.25, spec.HeadSize.Y * 0.6, spec.HeadSize.Z * 0.45),
				Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
				Parent = model,
			}
			cf = head.CFrame * CFrame.new(side * spec.HeadSize.X * 0.5, 0, 0)
				* CFrame.Angles(math.rad(-15), 0, math.rad(side * 25))
		elseif spec.Id == "Wolf" then
			ear = makePart{
				Name = "Ear",
				Size = Vector3.new(0.3, spec.HeadSize.Y * 0.7, 0.5),
				Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
				Parent = model,
			}
			cf = head.CFrame * CFrame.new(side * spec.HeadSize.X * 0.4, spec.HeadSize.Y * 0.55, spec.HeadSize.Z * 0.1)
				* CFrame.Angles(0, 0, math.rad(side * 20))
		elseif spec.Id == "Bear" then
			ear = makePart{
				Name = "Ear", Shape = Enum.PartType.Ball,
				Size = Vector3.new(spec.HeadSize.X * 0.35, spec.HeadSize.X * 0.35, spec.HeadSize.X * 0.35),
				Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
				Parent = model,
			}
			cf = head.CFrame * CFrame.new(side * spec.HeadSize.X * 0.42, spec.HeadSize.Y * 0.45, spec.HeadSize.Z * 0.05)
		else  -- Lion
			ear = makePart{
				Name = "Ear", Shape = Enum.PartType.Ball,
				Size = Vector3.new(spec.HeadSize.X * 0.3, spec.HeadSize.X * 0.3, spec.HeadSize.X * 0.3),
				Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
				Parent = model,
			}
			cf = head.CFrame * CFrame.new(side * spec.HeadSize.X * 0.5, spec.HeadSize.Y * 0.4, 0)
		end
		ear.CFrame = cf
		weld(head, ear)
	end
	buildEar(-1); buildEar(1)

	-- Mane (lion: ring of tufts + center mass)
	if spec.ManeColor then
		for i = 1, 6 do
			local angle = (i / 6) * math.pi * 2
			local r = spec.HeadSize.X * 1.0
			local tuft = makePart{
				Name = "ManeTuft", Shape = Enum.PartType.Ball,
				Size = Vector3.new(spec.HeadSize.X * 0.85, spec.HeadSize.X * 0.85, spec.HeadSize.X * 0.85),
				Color = spec.ManeColor, Material = Enum.Material.SmoothPlastic,
				Parent = model,
			}
			tuft.CFrame = head.CFrame * CFrame.new(math.cos(angle) * r, math.sin(angle) * r * 0.7, spec.HeadSize.Z * 0.15)
			weld(head, tuft)
		end
		local mass = makePart{
			Name = "ManeMass", Shape = Enum.PartType.Ball,
			Size = Vector3.new(spec.HeadSize.X * 1.7, spec.HeadSize.Y * 1.5, spec.HeadSize.Z * 1.4),
			Color = spec.ManeColor, Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		mass.CFrame = head.CFrame * CFrame.new(0, 0, spec.HeadSize.Z * 0.2)
		weld(head, mass)
	end

	-- Bear belly (chunky underside)
	if spec.Id == "Bear" then
		local belly = makePart{
			Name = "Belly", Shape = Enum.PartType.Ball,
			Size = Vector3.new(spec.BodySize.X * 1.15, spec.BodySize.Y * 1.1, spec.BodySize.Z * 0.7),
			Color = Color3.fromRGB(75, 50, 30), Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		belly.CFrame = hrp.CFrame * CFrame.new(0, -spec.BodySize.Y * 0.15, 0)
		weld(hrp, belly)
	end

	-- Legs (4) — welded directly to hrp, no Motor6D
	local legOffsets = {
		Vector3.new(-spec.BodySize.X * 0.32, -spec.BodySize.Y * 0.3, -spec.BodySize.Z * 0.32), -- FL
		Vector3.new( spec.BodySize.X * 0.32, -spec.BodySize.Y * 0.3, -spec.BodySize.Z * 0.32), -- FR
		Vector3.new(-spec.BodySize.X * 0.32, -spec.BodySize.Y * 0.3,  spec.BodySize.Z * 0.32), -- BL
		Vector3.new( spec.BodySize.X * 0.32, -spec.BodySize.Y * 0.3,  spec.BodySize.Z * 0.32), -- BR
	}
	for i, off in ipairs(legOffsets) do
		local leg = makePart{
			Name = "Leg" .. i, Size = spec.LegSize,
			Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		leg.CFrame = hrp.CFrame * CFrame.new(off.X, off.Y - spec.LegSize.Y * 0.5, off.Z)
		weld(hrp, leg)

		local paw = makePart{
			Name = "Paw",
			Size = Vector3.new(spec.LegSize.X * 1.2, spec.LegSize.X * 0.4, spec.LegSize.X * 1.4),
			Color = Color3.fromRGB(30, 22, 18), Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		paw.CFrame = leg.CFrame * CFrame.new(0, -spec.LegSize.Y * 0.45, 0)
		weld(leg, paw)
	end

	-- Tail
	local tailLen = spec.BodySize.Z * 0.55
	local tail = makePart{
		Name = "Tail", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(tailLen, 0.4, 0.4),
		Color = spec.BodyColor, Material = Enum.Material.SmoothPlastic,
		Parent = model,
	}
	tail.CFrame = hrp.CFrame
		* CFrame.new(0, spec.BodySize.Y * 0.1, spec.BodySize.Z * 0.55 + tailLen * 0.4)
		* CFrame.Angles(0, math.rad(90), 0)
	weld(hrp, tail)

	if spec.ManeColor then
		local tuft = makePart{
			Name = "TailTuft", Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.8, 0.8, 0.8),
			Color = spec.ManeColor, Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}
		tuft.CFrame = tail.CFrame * CFrame.new(tailLen * 0.5, 0, 0)
		weld(tail, tuft)
	end

	-- Humanoid — HipHeight large enough to keep HRP fully above terrain.
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = spec.HP
	hum.Health    = spec.HP
	hum.WalkSpeed = spec.WalkSpeed
	hum.AutoRotate = true
	hum.HipHeight  = spec.LegSize.Y + 0.5  -- HRP bottom this far above ground
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
			return Vector3.new(x, GameConfig.Island.BaseSize.Y + 12, z)
		end
	end
	return Vector3.new(60, GameConfig.Island.BaseSize.Y + 12, 60)
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

-- Walk-cycle animation: a subtle vertical bob driven by the AI loop's
-- TweenService — applied directly to the HRP via BodyVelocity-free CFrame
-- nudges. We avoid Motor6D because they previously caused parts to detach.
-- (Implemented inline inside runAnimalAI with the bob.)

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
	-- Parent FIRST so physics simulates correctly when we move the model.
	model.Parent = Workspace
	-- PivotTo is the modern, accurate way to move a model with welds.
	model:PivotTo(CFrame.new(pos))

	active[model] = { spec = spec }
	attachHumanoidWatcher(model, spec)
	task.spawn(runAnimalAI, model, spec)
	return model
end

-- Spawn a SPECIFIC species (used by the dev panel "spawn animal" action).
-- animalId is one of the AnimalConfig.List Ids ("Dog", "Wolf", "Bear", "Lion").
function AnimalManager.SpawnSpecific(animalId)
	local spec = AnimalConfig.ById[animalId]
	if not spec then return nil end
	local model = buildAnimalModel(spec)
	local pos = pickSpawnPos()
	model.Parent = Workspace
	model:PivotTo(CFrame.new(pos))
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
