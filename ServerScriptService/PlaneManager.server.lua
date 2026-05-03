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

	local bodyColor = GameConfig.Plane.BodyColor
	local accent    = GameConfig.Plane.WingColor
	local trim      = Color3.fromRGB(160, 50, 50)
	local glassCol  = Color3.fromRGB(120, 180, 220)

	-- Roblox convention: a Part's "front" is its -Z axis (LookVector).
	-- We build the plane with its NOSE at -Z so CFrame.new(start, end)
	-- points the nose toward the destination. Everything in this builder is
	-- a Block shape (or Ball) for predictable orientation.

	-- Fuselage: long box centered at origin, length along Z (28 long, 5x5).
	local fuselage = makePart{
		Name = "Fuselage",
		Size = Vector3.new(5, 5, 28),
		CFrame = CFrame.new(0, 0, 0),
		Color = bodyColor, Material = Enum.Material.Metal,
		Parent = model,
	}

	-- Nose at -Z (front).
	makePart{
		Name = "Nose", Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		CFrame = CFrame.new(0, 0, -14),
		Color = bodyColor, Material = Enum.Material.Metal,
		Parent = model,
	}
	-- Rear cap at +Z (tail).
	makePart{
		Name = "TailCap", Shape = Enum.PartType.Ball,
		Size = Vector3.new(4.5, 4.5, 4),
		CFrame = CFrame.new(0, 0, 14),
		Color = bodyColor, Material = Enum.Material.Metal,
		Parent = model,
	}

	-- Trim stripes along both sides.
	makePart{
		Name = "StripeL", Size = Vector3.new(0.3, 1, 28),
		CFrame = CFrame.new(-2.55, 0.5, 0),
		Color = trim, Material = Enum.Material.SmoothPlastic, Parent = model,
	}
	makePart{
		Name = "StripeR", Size = Vector3.new(0.3, 1, 28),
		CFrame = CFrame.new(2.55, 0.5, 0),
		Color = trim, Material = Enum.Material.SmoothPlastic, Parent = model,
	}

	-- Cockpit windows on top of fuselage near the nose (z negative).
	makePart{
		Name = "CanopyL", Size = Vector3.new(0.3, 2.4, 7),
		CFrame = CFrame.new(-1.7, 2.6, -7),
		Color = glassCol, Material = Enum.Material.Glass,
		Transparency = 0.35, Reflectance = 0.3, Parent = model,
	}
	makePart{
		Name = "CanopyR", Size = Vector3.new(0.3, 2.4, 7),
		CFrame = CFrame.new(1.7, 2.6, -7),
		Color = glassCol, Material = Enum.Material.Glass,
		Transparency = 0.35, Reflectance = 0.3, Parent = model,
	}
	makePart{
		Name = "CanopyTop", Size = Vector3.new(3.4, 0.4, 7),
		CFrame = CFrame.new(0, 3.7, -7),
		Color = glassCol, Material = Enum.Material.Glass,
		Transparency = 0.35, Reflectance = 0.3, Parent = model,
	}
	-- Forward windshield (slanted slightly).
	makePart{
		Name = "Windshield", Size = Vector3.new(3.4, 2.6, 0.3),
		CFrame = CFrame.new(0, 2.4, -10.5) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = glassCol, Material = Enum.Material.Glass,
		Transparency = 0.35, Reflectance = 0.3, Parent = model,
	}

	-- Main wing — single block across both sides, slightly behind cockpit.
	makePart{
		Name = "Wing", Size = Vector3.new(30, 0.8, 5),
		CFrame = CFrame.new(0, 0.4, 1),
		Color = accent, Material = Enum.Material.Metal,
		Parent = model,
	}
	-- Winglets at wing tips.
	makePart{
		Name = "WingletL", Size = Vector3.new(0.7, 2.6, 3),
		CFrame = CFrame.new(-14.6, 1.7, 1),
		Color = trim, Material = Enum.Material.Metal, Parent = model,
	}
	makePart{
		Name = "WingletR", Size = Vector3.new(0.7, 2.6, 3),
		CFrame = CFrame.new(14.6, 1.7, 1),
		Color = trim, Material = Enum.Material.Metal, Parent = model,
	}

	-- Two underwing engines with propellers IN FRONT (more negative Z).
	local function buildEngine(side)
		makePart{
			Name = "Engine", Size = Vector3.new(2, 2, 5),
			CFrame = CFrame.new(side * 7, -0.8, -1),
			Color = Color3.fromRGB(60, 60, 70),
			Material = Enum.Material.Metal, Parent = model,
		}
		makePart{
			Name = "PropHub", Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 1.2, 1.2),
			CFrame = CFrame.new(side * 7, -0.8, -4),
			Color = trim, Material = Enum.Material.Metal, Parent = model,
		}
		-- Two crossed prop blades (vertical + horizontal).
		makePart{
			Name = "PropBlade1", Size = Vector3.new(0.3, 5, 0.4),
			CFrame = CFrame.new(side * 7, -0.8, -4.1),
			Color = Color3.fromRGB(30, 30, 35),
			Material = Enum.Material.Metal, Parent = model,
		}
		makePart{
			Name = "PropBlade2", Size = Vector3.new(5, 0.3, 0.4),
			CFrame = CFrame.new(side * 7, -0.8, -4.1),
			Color = Color3.fromRGB(30, 30, 35),
			Material = Enum.Material.Metal, Parent = model,
		}
	end
	buildEngine(-1)
	buildEngine(1)

	-- Tail vertical fin (rises up at the back, +Z).
	makePart{
		Name = "TailFin", Size = Vector3.new(0.6, 5, 5),
		CFrame = CFrame.new(0, 3, 11.5),
		Color = accent, Material = Enum.Material.Metal, Parent = model,
	}
	-- Tail horizontal stabilizer.
	makePart{
		Name = "HorizStab", Size = Vector3.new(9, 0.5, 3),
		CFrame = CFrame.new(0, 1.5, 12),
		Color = accent, Material = Enum.Material.Metal, Parent = model,
	}
	-- Tip of fin (red trim).
	makePart{
		Name = "TailTip", Size = Vector3.new(0.7, 1, 4),
		CFrame = CFrame.new(0, 5.2, 11.8),
		Color = trim, Material = Enum.Material.SmoothPlastic, Parent = model,
	}

	-- Side door (left fuselage, mid-section).
	makePart{
		Name = "Door", Size = Vector3.new(0.3, 3.5, 2.5),
		CFrame = CFrame.new(-2.6, 0.3, 4),
		Color = trim, Material = Enum.Material.Metal, Parent = model,
	}

	-- Weld everything to fuselage and finalize physics flags.
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			if p ~= fuselage then
				weldTo(p, fuselage)
			end
		end
	end

	model.PrimaryPart = fuselage
	return model
end

local function seatPlayers(model, players)
	local body = model.PrimaryPart
	-- Seats are in cockpit-and-cabin area. Nose is at -Z so seats with
	-- negative Z are forward, positive Z are aft.
	local seatPositions = {
		Vector3.new(-2, 2.0, -7),  -- pilot
		Vector3.new( 2, 2.0, -7),  -- co-pilot
		Vector3.new(-2, 2.0, -1),  -- mid left
		Vector3.new( 2, 2.0, -1),  -- mid right
		Vector3.new( 0, 2.0,  5),  -- rear center
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
