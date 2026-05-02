-- PlaneManager.server.lua
-- Place in: ServerScriptService as Script named "PlaneManager"
-- Builds a plane model, seats players, tweens flight, handles crash VFX.

local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local Players          = game:GetService("Players")
local Debris           = game:GetService("Debris")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local PlaneManager = {}

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function buildPlaneModel()
	local model = Instance.new("Model")
	model.Name = "CrashPlane"

	local body = makePart{
		Name="Body", Size=Vector3.new(8, 4, 22),
		Color=GameConfig.Plane.BodyColor, Material=Enum.Material.Metal,
		Parent=model,
	}
	local nose = makePart{
		Name="Nose", Shape=Enum.PartType.Ball, Size=Vector3.new(7,4,7),
		Color=GameConfig.Plane.BodyColor, Material=Enum.Material.Metal,
		Parent=model,
	}
	local tail = makePart{
		Name="Tail", Size=Vector3.new(1, 4, 6),
		Color=GameConfig.Plane.BodyColor, Material=Enum.Material.Metal,
		Parent=model,
	}
	local wingL = makePart{
		Name="WingL", Size=Vector3.new(20, 0.8, 4),
		Color=GameConfig.Plane.WingColor, Material=Enum.Material.Metal,
		Parent=model,
	}
	local wingR = makePart{
		Name="WingR", Size=Vector3.new(20, 0.8, 4),
		Color=GameConfig.Plane.WingColor, Material=Enum.Material.Metal,
		Parent=model,
	}
	-- position children relative to body
	body.CFrame = CFrame.new(0, 0, 0)
	nose.CFrame = CFrame.new(0, 0, -12)
	tail.CFrame = CFrame.new(0, 3, 11)
	wingL.CFrame = CFrame.new(-12, 0.5, 0)
	wingR.CFrame = CFrame.new( 12, 0.5, 0)

	model.PrimaryPart = body
	return model
end

local function seatPlayers(model, players)
	local body = model.PrimaryPart
	local seatPositions = {
		Vector3.new(-2, 2.5, -4),
		Vector3.new( 2, 2.5, -4),
		Vector3.new(-2, 2.5,  2),
		Vector3.new( 2, 2.5,  2),
		Vector3.new( 0, 2.5,  6),
	}
	for i, p in ipairs(players) do
		local char = p.Character
		if not char then continue end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hrp and hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hrp.Anchored  = true
			local off = seatPositions[i] or Vector3.new(0, 2.5, 0)
			hrp.CFrame = body.CFrame * CFrame.new(off)
		end
	end
end

local function unseatPlayers(players, ejectionCenter)
	local r = GameConfig.Plane.EjectionSpread
	for _, p in ipairs(players) do
		local char = p.Character
		if not char then continue end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hrp and hum then
			hrp.Anchored = false
			hum.WalkSpeed = 16
			hum.JumpPower = 50
			local angle = math.random() * math.pi * 2
			local dist  = math.random(r/2, r)
			hrp.CFrame = CFrame.new(
				ejectionCenter + Vector3.new(math.cos(angle)*dist, 8, math.sin(angle)*dist)
			)
		end
	end
end

function PlaneManager.RunFlight(players, onArrive)
	local model = buildPlaneModel()
	model.Parent = Workspace

	local startPos = GameConfig.Plane.StartOffset
	local endPos   = GameConfig.Plane.CrashTarget + Vector3.new(0, 50, 0)
	local startCF  = CFrame.new(startPos, endPos)
	model:SetPrimaryPartCFrame(startCF)

	-- Notify clients (for camera framing if desired)
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	Remotes.PlaneFlight:FireAllClients({
		startPosition = startPos,
		endPosition   = endPos,
		duration      = GameConfig.Plane.FlightSeconds,
	})

	seatPlayers(model, players)

	-- Animate via repeated CFrame interpolation (PrimaryPart drag).
	local steps = 60
	local dt    = GameConfig.Plane.FlightSeconds / steps
	task.spawn(function()
		for i = 1, steps do
			if not model.Parent then return end
			local t = i / steps
			-- Slight arc: dip mid-flight then climb to crash height
			local arcY = math.sin(t * math.pi) * 30
			local pos  = startPos:Lerp(endPos, t) + Vector3.new(0, arcY, 0)
			local look = endPos
			local cf   = CFrame.new(pos, look)
			-- Wobble for engine-failure effect at the end
			if t > 0.7 then
				local shake = (t - 0.7) * 4
				cf = cf * CFrame.Angles(
					math.sin(tick()*15)*shake*0.05,
					0,
					math.sin(tick()*22)*shake*0.08
				)
			end
			model:SetPrimaryPartCFrame(cf)
			-- Re-anchor players to seats
			seatPlayers(model, players)
			task.wait(dt)
		end

		-- Final crash position
		local crash = (_G.IslandBuilder and _G.IslandBuilder.GetCrashPosition()) or Vector3.new(0,10,0)
		Remotes.CrashEffect:FireAllClients({ position = crash })

		-- Eject players to crash site
		unseatPlayers(players, crash)
		PlaneManager.PlayCrash(model, crash)

		if onArrive then onArrive() end
	end)
end

-- Spawn explosion + smoke at a position. Optionally destroys a plane model.
function PlaneManager.PlayCrash(model, position)
	if type(model) == "table" and model.Position then
		position = model
		model = nil
	end
	position = position or Vector3.new(0, 10, 0)

	-- Explosion
	local exp = Instance.new("Explosion")
	exp.BlastRadius = 0
	exp.BlastPressure = 0
	exp.DestroyJointRadiusPercent = 0
	exp.Position = position
	exp.Parent = Workspace

	-- Smoke
	local debris = makePart{
		Name="CrashDebris", Anchored=true, CanCollide=false, Transparency=1,
		Size=Vector3.new(1,1,1), Position=position, Parent=Workspace,
	}
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(40,40,40)
	smoke.Opacity = 0.8
	smoke.Size = 12
	smoke.RiseVelocity = 6
	smoke.Parent = debris
	Debris:AddItem(debris, 30)

	-- Destroy plane after a beat
	if model then
		task.delay(0.3, function()
			if model.Parent then model:Destroy() end
		end)
	end
end

_G.PlaneManager = PlaneManager
print("[PlaneManager] Ready.")
