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

local function weldTo(child, parent)
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = child
	w.Parent = child
end

local function buildPlaneModel()
	local model = Instance.new("Model")
	model.Name = "CrashPlane"

	local body = GameConfig.Plane.BodyColor
	local accent = GameConfig.Plane.WingColor
	local trim = Color3.fromRGB(160, 50, 50)

	-- Fuselage: rounded cylinder lying flat
	local fuselage = makePart{
		Name="Fuselage",
		Shape=Enum.PartType.Cylinder,
		Size=Vector3.new(28, 5, 5),
		CFrame=CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color=body, Material=Enum.Material.Metal,
		Parent=model,
	}
	-- Nose cone
	local nose = makePart{
		Name="Nose",
		Shape=Enum.PartType.Ball,
		Size=Vector3.new(5, 5, 5),
		CFrame=CFrame.new(0, 0, -14),
		Color=body, Material=Enum.Material.Metal,
		Parent=model,
	}
	-- Trim stripe along the side
	local stripe = makePart{
		Name="Stripe", Size=Vector3.new(6, 1, 28),
		CFrame=CFrame.new(0, 0.6, 0),
		Color=trim, Material=Enum.Material.SmoothPlastic,
		Parent=model,
	}
	-- Cockpit canopy (glass)
	local canopy = makePart{
		Name="Canopy",
		Shape=Enum.PartType.Cylinder,
		Size=Vector3.new(6, 4, 4.6),
		CFrame=CFrame.new(0, 2, -8) * CFrame.Angles(0, 0, math.rad(90)),
		Color=Color3.fromRGB(120, 180, 220),
		Material=Enum.Material.Glass,
		Transparency=0.4,
		Reflectance=0.3,
		Parent=model,
	}
	-- Cockpit window divider
	local divider = makePart{
		Name="Divider", Size=Vector3.new(0.4, 4.2, 6.2),
		CFrame=CFrame.new(0, 2, -8),
		Color=Color3.fromRGB(60, 60, 70), Material=Enum.Material.Metal,
		Parent=model,
	}

	-- Wings (swept slightly back) — main wing
	local wingL = makePart{
		Name="WingL", Size=Vector3.new(14, 0.7, 5),
		CFrame=CFrame.new(-9, 0.2, 1) * CFrame.Angles(0, math.rad(8), 0),
		Color=accent, Material=Enum.Material.Metal,
		Parent=model,
	}
	local wingR = makePart{
		Name="WingR", Size=Vector3.new(14, 0.7, 5),
		CFrame=CFrame.new( 9, 0.2, 1) * CFrame.Angles(0, math.rad(-8), 0),
		Color=accent, Material=Enum.Material.Metal,
		Parent=model,
	}
	-- Winglets at wing tips
	local wingletL = makePart{
		Name="WingletL", Size=Vector3.new(0.6, 2.5, 3),
		CFrame=CFrame.new(-15.5, 1.4, 1.5),
		Color=trim, Material=Enum.Material.Metal,
		Parent=model,
	}
	local wingletR = makePart{
		Name="WingletR", Size=Vector3.new(0.6, 2.5, 3),
		CFrame=CFrame.new( 15.5, 1.4, 1.5),
		Color=trim, Material=Enum.Material.Metal,
		Parent=model,
	}

	-- Engines on wings (cylinders) with propellers
	local function buildEngine(side)
		local engine = makePart{
			Name="Engine",
			Shape=Enum.PartType.Cylinder,
			Size=Vector3.new(5, 2, 2),
			CFrame=CFrame.new(side * 6, -0.6, -1) * CFrame.Angles(0, 0, math.rad(90)),
			Color=Color3.fromRGB(60, 60, 70), Material=Enum.Material.Metal,
			Parent=model,
		}
		-- Propeller (3-blade) — anchored disc that we'll spin via tween or while loop
		local prop = makePart{
			Name="Propeller",
			Shape=Enum.PartType.Cylinder,
			Size=Vector3.new(0.3, 4, 0.4),
			CFrame=CFrame.new(side * 6, -0.6, -3.6) * CFrame.Angles(0, 0, 0),
			Color=Color3.fromRGB(20, 20, 22), Material=Enum.Material.Metal,
			Parent=model,
		}
		prop:SetAttribute("IsProp", true)
		-- Spinner cone
		local spinner = makePart{
			Name="Spinner", Shape=Enum.PartType.Ball,
			Size=Vector3.new(1.2, 1.2, 1.2),
			CFrame=CFrame.new(side * 6, -0.6, -3.8),
			Color=trim, Material=Enum.Material.Metal,
			Parent=model,
		}
		return prop
	end
	local propL = buildEngine(-1)
	local propR = buildEngine( 1)

	-- Tail section
	local tailFin = makePart{
		Name="TailFin", Size=Vector3.new(0.6, 5, 5),
		CFrame=CFrame.new(0, 3, 12),
		Color=accent, Material=Enum.Material.Metal,
		Parent=model,
	}
	local hStab = makePart{
		Name="HorizStab", Size=Vector3.new(8, 0.5, 3),
		CFrame=CFrame.new(0, 1.5, 13),
		Color=accent, Material=Enum.Material.Metal,
		Parent=model,
	}
	local tailTrim = makePart{
		Name="TailTrim", Size=Vector3.new(0.7, 1, 5),
		CFrame=CFrame.new(0, 5.2, 12),
		Color=trim, Material=Enum.Material.SmoothPlastic,
		Parent=model,
	}

	-- Door (left side, rear)
	local door = makePart{
		Name="Door", Size=Vector3.new(0.3, 3.5, 2),
		CFrame=CFrame.new(-2.6, 0.2, 4),
		Color=trim, Material=Enum.Material.Metal,
		Parent=model,
	}

	-- Weld everything to fuselage so the model moves as one when we tween.
	for _, p in ipairs(model:GetChildren()) do
		if p ~= fuselage and p:IsA("BasePart") then
			weldTo(p, fuselage)
		end
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end

	model.PrimaryPart = fuselage
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
