-- ShopManager.server.lua
-- Place in: ServerScriptService as Script named "ShopManager"
-- Handles XP-based purchases (weapons, plane upgrades) and tool spawning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local MarketplaceService= game:GetService("MarketplaceService")

local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local Strings      = require(ReplicatedStorage:WaitForChild("Strings"))

local ShopManager = {}
local Remotes

local function getRemotes()
	if Remotes then return Remotes end
	Remotes = ReplicatedStorage:WaitForChild("Remotes")
	return Remotes
end

local function dm()
	while not _G.DataManager do task.wait(0.05) end
	return _G.DataManager
end

-- ====================================================================
-- WEAPON MODEL BUILDERS
-- Each weapon is built from many welded parts for visual quality.
-- The "Handle" part is what the player's hand attaches to (Tool.Grip
-- offsets where on the Handle the hand sits).
-- ====================================================================

local function configurePart(p, props)
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
end

local function newPart(props)
	local p = Instance.new("Part")
	configurePart(p, props)
	return p
end

local function newWedge(props)
	local p = Instance.new("WedgePart")
	configurePart(p, props)
	return p
end

local function weldTo(parent, child)
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = child
	w.Parent = child
end

-- ----- Stick: gnarled wooden club -----
local function buildStick(tool)
	local handle = newPart{
		Name = "Handle",
		Size = Vector3.new(0.55, 0.55, 3.4),
		Color = Color3.fromRGB(105, 70, 35),
		Material = Enum.Material.Wood,
		Parent = tool,
	}

	-- Knot bumps along the stick for character.
	local knotOffsets = {
		Vector3.new( 0.2, 0.05, -0.9),
		Vector3.new(-0.2, 0.0,   0.1),
		Vector3.new( 0.1, 0.2,   1.0),
		Vector3.new(-0.15, -0.1, 1.4),
	}
	for _, off in ipairs(knotOffsets) do
		local knot = newPart{
			Name = "Knot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.55, 0.45, 0.5),
			Color = Color3.fromRGB(82, 50, 22),
			Material = Enum.Material.Wood,
			Parent = tool,
		}
		knot.CFrame = handle.CFrame * CFrame.new(off)
		weldTo(handle, knot)
	end

	-- Tapered tip (the "business end"): heavier, wider.
	local head = newPart{
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.95, 0.85, 0.95),
		Color = Color3.fromRGB(95, 60, 28),
		Material = Enum.Material.Wood,
		Parent = tool,
	}
	head.CFrame = handle.CFrame * CFrame.new(0, 0, -1.6)
	weldTo(handle, head)

	-- A few darker spikes/splinters on the head for brutality.
	for i, off in ipairs({
		Vector3.new( 0.32,  0.18, -1.7),
		Vector3.new(-0.30,  0.22, -1.55),
		Vector3.new( 0.10, -0.30, -1.85),
	}) do
		local spike = newPart{
			Name = "Splinter",
			Size = Vector3.new(0.14, 0.14, 0.45),
			Color = Color3.fromRGB(60, 38, 18),
			Material = Enum.Material.Wood,
			Parent = tool,
		}
		spike.CFrame = handle.CFrame * CFrame.new(off) * CFrame.Angles(math.rad(20 * i), math.rad(15 * i), 0)
		weldTo(handle, spike)
	end

	-- Leather grip wrap at the back third.
	for _, z in ipairs({1.05, 1.35, 1.65}) do
		local wrap = newPart{
			Name = "Wrap",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 0.66, 0.66),
			Color = Color3.fromRGB(55, 32, 18),
			Material = Enum.Material.Fabric,
			Parent = tool,
		}
		wrap.CFrame = handle.CFrame * CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(90), 0)
		weldTo(handle, wrap)
	end

	tool.Grip = CFrame.new(0, 0, -1.4)
end

-- ----- Spear: long shaft with a steel head -----
local function buildSpear(tool)
	local handle = newPart{
		Name = "Handle",
		Size = Vector3.new(0.32, 0.32, 6),
		Color = Color3.fromRGB(155, 120, 80),
		Material = Enum.Material.Wood,
		Parent = tool,
	}

	-- Steel band where head meets shaft.
	local band = newPart{
		Name = "Band",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 0.45, 0.45),
		Color = Color3.fromRGB(110, 110, 120),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	band.CFrame = handle.CFrame * CFrame.new(0, 0, -2.85) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(handle, band)

	-- Spearhead base (rectangular blade).
	local headBase = newPart{
		Name = "HeadBase",
		Size = Vector3.new(0.55, 0.08, 0.9),
		Color = Color3.fromRGB(190, 195, 205),
		Material = Enum.Material.Metal,
		Reflectance = 0.25,
		Parent = tool,
	}
	headBase.CFrame = handle.CFrame * CFrame.new(0, 0, -3.5)
	weldTo(handle, headBase)

	-- Spear tip: two angled wedges making a triangular point.
	local tipL = newWedge{
		Name = "TipL",
		Size = Vector3.new(0.275, 0.08, 0.65),
		Color = Color3.fromRGB(220, 220, 230),
		Material = Enum.Material.Metal,
		Reflectance = 0.4,
		Parent = tool,
	}
	tipL.CFrame = handle.CFrame * CFrame.new(-0.137, 0, -4.275) * CFrame.Angles(0, 0, 0)
	weldTo(handle, tipL)

	local tipR = newWedge{
		Name = "TipR",
		Size = Vector3.new(0.275, 0.08, 0.65),
		Color = Color3.fromRGB(220, 220, 230),
		Material = Enum.Material.Metal,
		Reflectance = 0.4,
		Parent = tool,
	}
	tipR.CFrame = handle.CFrame * CFrame.new(0.137, 0, -4.275) * CFrame.Angles(0, math.rad(180), 0)
	weldTo(handle, tipR)

	-- Center ridge of the blade.
	local ridge = newPart{
		Name = "Ridge",
		Size = Vector3.new(0.06, 0.18, 1.5),
		Color = Color3.fromRGB(170, 175, 185),
		Material = Enum.Material.Metal,
		Reflectance = 0.3,
		Parent = tool,
	}
	ridge.CFrame = handle.CFrame * CFrame.new(0, 0.05, -3.85)
	weldTo(handle, ridge)

	-- Leather wrap at grip area.
	for _, z in ipairs({1.6, 2.0, 2.4, 2.8}) do
		local wrap = newPart{
			Name = "Wrap",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.32, 0.42, 0.42),
			Color = Color3.fromRGB(48, 28, 16),
			Material = Enum.Material.Fabric,
			Parent = tool,
		}
		wrap.CFrame = handle.CFrame * CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(90), 0)
		weldTo(handle, wrap)
	end

	-- Counterweight at the butt end (steel cap).
	local butt = newPart{
		Name = "Butt",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 0.42, 0.42),
		Color = Color3.fromRGB(95, 95, 105),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	butt.CFrame = handle.CFrame * CFrame.new(0, 0, 3.2) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(handle, butt)

	-- Decorative red feather just behind the head.
	local feather = newPart{
		Name = "Feather",
		Size = Vector3.new(0.05, 0.6, 0.5),
		Color = Color3.fromRGB(170, 30, 30),
		Material = Enum.Material.Fabric,
		Transparency = 0.1,
		Parent = tool,
	}
	feather.CFrame = handle.CFrame * CFrame.new(0, 0.4, -2.55) * CFrame.Angles(0, 0, math.rad(15))
	weldTo(handle, feather)

	tool.Grip = CFrame.new(0, 0, -2.2)
end

-- ----- Knife: short bladed weapon with crossguard -----
local function buildKnife(tool)
	local handle = newPart{
		Name = "Handle",
		Size = Vector3.new(0.42, 0.32, 1.1),
		Color = Color3.fromRGB(75, 48, 25),
		Material = Enum.Material.Wood,
		Parent = tool,
	}

	-- Wrapping ridges on the wooden handle.
	for _, z in ipairs({-0.3, 0.0, 0.3}) do
		local ridge = newPart{
			Name = "HandleRidge",
			Size = Vector3.new(0.46, 0.36, 0.08),
			Color = Color3.fromRGB(50, 30, 16),
			Material = Enum.Material.Wood,
			Parent = tool,
		}
		ridge.CFrame = handle.CFrame * CFrame.new(0, 0, z)
		weldTo(handle, ridge)
	end

	-- Pommel ball at the back.
	local pommel = newPart{
		Name = "Pommel",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.45, 0.45, 0.45),
		Color = Color3.fromRGB(140, 140, 150),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
		Parent = tool,
	}
	pommel.CFrame = handle.CFrame * CFrame.new(0, 0, 0.6)
	weldTo(handle, pommel)

	-- Crossguard between handle and blade.
	local guard = newPart{
		Name = "Guard",
		Size = Vector3.new(0.85, 0.18, 0.22),
		Color = Color3.fromRGB(150, 150, 160),
		Material = Enum.Material.Metal,
		Reflectance = 0.3,
		Parent = tool,
	}
	guard.CFrame = handle.CFrame * CFrame.new(0, 0, -0.6)
	weldTo(handle, guard)

	-- Main blade body (broad, slightly tapered).
	local blade = newPart{
		Name = "Blade",
		Size = Vector3.new(0.38, 0.06, 1.7),
		Color = Color3.fromRGB(205, 210, 220),
		Material = Enum.Material.Metal,
		Reflectance = 0.4,
		Parent = tool,
	}
	blade.CFrame = handle.CFrame * CFrame.new(0, 0.03, -1.55)
	weldTo(handle, blade)

	-- Sharpened edge highlight (thin reflective strip).
	local edge = newPart{
		Name = "Edge",
		Size = Vector3.new(0.27, 0.03, 1.6),
		Color = Color3.fromRGB(245, 245, 255),
		Material = Enum.Material.Metal,
		Reflectance = 0.6,
		Parent = tool,
	}
	edge.CFrame = handle.CFrame * CFrame.new(0, -0.01, -1.55)
	weldTo(handle, edge)

	-- Pointed blade tip (wedge shape).
	local tip = newWedge{
		Name = "BladeTip",
		Size = Vector3.new(0.38, 0.06, 0.55),
		Color = Color3.fromRGB(220, 225, 235),
		Material = Enum.Material.Metal,
		Reflectance = 0.45,
		Parent = tool,
	}
	tip.CFrame = handle.CFrame * CFrame.new(0, 0.03, -2.7) * CFrame.Angles(0, 0, 0)
	weldTo(handle, tip)

	-- Blood groove (decorative line on the blade).
	local groove = newPart{
		Name = "Groove",
		Size = Vector3.new(0.08, 0.03, 1.3),
		Color = Color3.fromRGB(120, 125, 135),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	groove.CFrame = handle.CFrame * CFrame.new(0, 0.07, -1.55)
	weldTo(handle, groove)

	tool.Grip = CFrame.new(0, 0, 0)
end

-- ----- Pistol: realistic semi-auto -----
local function buildPistol(tool)
	-- The Handle is the slide/body (top of the pistol).
	local slide = newPart{
		Name = "Handle",
		Size = Vector3.new(0.45, 0.55, 1.7),
		Color = Color3.fromRGB(38, 38, 42),
		Material = Enum.Material.Metal,
		Reflectance = 0.1,
		Parent = tool,
	}

	-- Slide texture grooves (little vertical lines at the back).
	for _, z in ipairs({0.55, 0.65, 0.75}) do
		local groove = newPart{
			Name = "SlideGroove",
			Size = Vector3.new(0.46, 0.4, 0.04),
			Color = Color3.fromRGB(20, 20, 24),
			Material = Enum.Material.Metal,
			Parent = tool,
		}
		groove.CFrame = slide.CFrame * CFrame.new(0, 0.05, z)
		weldTo(slide, groove)
	end

	-- Front sight blade.
	local frontSight = newPart{
		Name = "FrontSight",
		Size = Vector3.new(0.06, 0.18, 0.12),
		Color = Color3.fromRGB(15, 15, 18),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	frontSight.CFrame = slide.CFrame * CFrame.new(0, 0.36, -0.7)
	weldTo(slide, frontSight)

	-- Rear sight notch.
	local rearSight = newPart{
		Name = "RearSight",
		Size = Vector3.new(0.32, 0.12, 0.16),
		Color = Color3.fromRGB(15, 15, 18),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	rearSight.CFrame = slide.CFrame * CFrame.new(0, 0.33, 0.7)
	weldTo(slide, rearSight)

	-- Barrel extending forward.
	local barrel = newPart{
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.55, 0.28, 0.28),
		Color = Color3.fromRGB(25, 25, 28),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	barrel.CFrame = slide.CFrame * CFrame.new(0, 0, -1.1) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(slide, barrel)

	-- Muzzle ring.
	local muzzle = newPart{
		Name = "Muzzle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, 0.32, 0.32),
		Color = Color3.fromRGB(15, 15, 18),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	muzzle.CFrame = slide.CFrame * CFrame.new(0, 0, -1.4) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(slide, muzzle)

	-- Grip frame (vertical, below slide).
	local grip = newPart{
		Name = "Grip",
		Size = Vector3.new(0.42, 1.15, 0.55),
		Color = Color3.fromRGB(28, 28, 32),
		Material = Enum.Material.Plastic,
		Parent = tool,
	}
	grip.CFrame = slide.CFrame * CFrame.new(0, -0.78, 0.45) * CFrame.Angles(math.rad(-12), 0, 0)
	weldTo(slide, grip)

	-- Checkering on the grip (texture lines).
	for i = 1, 5 do
		local line = newPart{
			Name = "GripCheck",
			Size = Vector3.new(0.44, 0.06, 0.5),
			Color = Color3.fromRGB(15, 15, 18),
			Material = Enum.Material.Plastic,
			Parent = tool,
		}
		line.CFrame = slide.CFrame * CFrame.new(0, -0.4 - i * 0.16, 0.45 + (i - 3) * 0.05) * CFrame.Angles(math.rad(-12), 0, 0)
		weldTo(slide, line)
	end

	-- Trigger guard (the loop around the trigger).
	local guardFront = newPart{
		Name = "TriggerGuardF",
		Size = Vector3.new(0.18, 0.08, 0.5),
		Color = Color3.fromRGB(28, 28, 32),
		Material = Enum.Material.Plastic,
		Parent = tool,
	}
	guardFront.CFrame = slide.CFrame * CFrame.new(0, -0.35, -0.05)
	weldTo(slide, guardFront)
	local guardBack = newPart{
		Name = "TriggerGuardB",
		Size = Vector3.new(0.16, 0.32, 0.1),
		Color = Color3.fromRGB(28, 28, 32),
		Material = Enum.Material.Plastic,
		Parent = tool,
	}
	guardBack.CFrame = slide.CFrame * CFrame.new(0, -0.5, 0.18)
	weldTo(slide, guardBack)

	-- Trigger
	local trigger = newPart{
		Name = "Trigger",
		Size = Vector3.new(0.1, 0.28, 0.08),
		Color = Color3.fromRGB(120, 120, 130),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
		Parent = tool,
	}
	trigger.CFrame = slide.CFrame * CFrame.new(0, -0.45, 0.0)
	weldTo(slide, trigger)

	-- Magazine (visible at bottom of grip).
	local mag = newPart{
		Name = "Magazine",
		Size = Vector3.new(0.36, 0.22, 0.5),
		Color = Color3.fromRGB(50, 50, 58),
		Material = Enum.Material.Metal,
		Reflectance = 0.15,
		Parent = tool,
	}
	mag.CFrame = slide.CFrame * CFrame.new(0, -1.4, 0.5) * CFrame.Angles(math.rad(-12), 0, 0)
	weldTo(slide, mag)

	-- Hammer at the back of the slide.
	local hammer = newPart{
		Name = "Hammer",
		Size = Vector3.new(0.12, 0.25, 0.12),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	hammer.CFrame = slide.CFrame * CFrame.new(0, 0.34, 0.83)
	weldTo(slide, hammer)

	tool.Grip = CFrame.new(0, 0.7, -0.4)
end

-- ----- Shotgun: pump-action with wooden stock -----
local function buildShotgun(tool)
	-- Receiver in the middle (Handle).
	local receiver = newPart{
		Name = "Handle",
		Size = Vector3.new(0.55, 0.7, 1.6),
		Color = Color3.fromRGB(45, 30, 15),
		Material = Enum.Material.Wood,
		Parent = tool,
	}

	-- Steel band on receiver.
	local band = newPart{
		Name = "ReceiverBand",
		Size = Vector3.new(0.6, 0.74, 0.18),
		Color = Color3.fromRGB(70, 70, 78),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
		Parent = tool,
	}
	band.CFrame = receiver.CFrame * CFrame.new(0, 0, -0.7)
	weldTo(receiver, band)

	-- Main barrel (long).
	local barrel = newPart{
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4.8, 0.4, 0.4),
		Color = Color3.fromRGB(28, 28, 32),
		Material = Enum.Material.Metal,
		Reflectance = 0.15,
		Parent = tool,
	}
	barrel.CFrame = receiver.CFrame * CFrame.new(0, 0.05, -3.2) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(receiver, barrel)

	-- Front bead sight.
	local bead = newPart{
		Name = "FrontBead",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.1, 0.1, 0.1),
		Color = Color3.fromRGB(220, 200, 60),
		Material = Enum.Material.Neon,
		Parent = tool,
	}
	bead.CFrame = receiver.CFrame * CFrame.new(0, 0.27, -5.5)
	weldTo(receiver, bead)

	-- Magazine tube (under barrel).
	local magTube = newPart{
		Name = "MagTube",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4.6, 0.28, 0.28),
		Color = Color3.fromRGB(35, 35, 40),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	magTube.CFrame = receiver.CFrame * CFrame.new(0, -0.2, -3.1) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(receiver, magTube)

	-- Pump grip (forward of trigger, slides on the mag tube).
	local pump = newPart{
		Name = "Pump",
		Size = Vector3.new(0.6, 0.45, 1.0),
		Color = Color3.fromRGB(30, 18, 8),
		Material = Enum.Material.Wood,
		Parent = tool,
	}
	pump.CFrame = receiver.CFrame * CFrame.new(0, -0.18, -1.6)
	weldTo(receiver, pump)

	-- Pump grip ridges.
	for i = 1, 4 do
		local ridge = newPart{
			Name = "PumpRidge",
			Size = Vector3.new(0.62, 0.46, 0.06),
			Color = Color3.fromRGB(15, 8, 4),
			Material = Enum.Material.Wood,
			Parent = tool,
		}
		ridge.CFrame = receiver.CFrame * CFrame.new(0, -0.18, -1.95 + (i - 1) * 0.22)
		weldTo(receiver, ridge)
	end

	-- Wooden buttstock (back of the gun).
	local stock = newPart{
		Name = "Stock",
		Size = Vector3.new(0.5, 1.1, 1.7),
		Color = Color3.fromRGB(95, 60, 30),
		Material = Enum.Material.Wood,
		Parent = tool,
	}
	stock.CFrame = receiver.CFrame * CFrame.new(0, -0.3, 1.55) * CFrame.Angles(math.rad(-8), 0, 0)
	weldTo(receiver, stock)

	-- Recoil pad on stock.
	local pad = newPart{
		Name = "Pad",
		Size = Vector3.new(0.55, 1.15, 0.18),
		Color = Color3.fromRGB(20, 18, 16),
		Material = Enum.Material.Fabric,
		Parent = tool,
	}
	pad.CFrame = stock.CFrame * CFrame.new(0, 0, 0.92)
	weldTo(receiver, pad)

	-- Pistol grip section (where the trigger hand goes).
	local grip = newPart{
		Name = "Grip",
		Size = Vector3.new(0.38, 0.85, 0.55),
		Color = Color3.fromRGB(30, 18, 8),
		Material = Enum.Material.Wood,
		Parent = tool,
	}
	grip.CFrame = receiver.CFrame * CFrame.new(0, -0.65, 0.5) * CFrame.Angles(math.rad(-15), 0, 0)
	weldTo(receiver, grip)

	-- Trigger guard.
	local guardFront = newPart{
		Name = "TriggerGuardF",
		Size = Vector3.new(0.16, 0.08, 0.4),
		Color = Color3.fromRGB(40, 40, 48),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	guardFront.CFrame = receiver.CFrame * CFrame.new(0, -0.5, 0.05)
	weldTo(receiver, guardFront)
	local guardBack = newPart{
		Name = "TriggerGuardB",
		Size = Vector3.new(0.14, 0.28, 0.1),
		Color = Color3.fromRGB(40, 40, 48),
		Material = Enum.Material.Metal,
		Parent = tool,
	}
	guardBack.CFrame = receiver.CFrame * CFrame.new(0, -0.62, 0.25)
	weldTo(receiver, guardBack)

	-- Trigger
	local trigger = newPart{
		Name = "Trigger",
		Size = Vector3.new(0.08, 0.22, 0.07),
		Color = Color3.fromRGB(140, 140, 150),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
		Parent = tool,
	}
	trigger.CFrame = receiver.CFrame * CFrame.new(0, -0.55, 0.05)
	weldTo(receiver, trigger)

	tool.Grip = CFrame.new(0, 0.55, -0.5)
end

local WEAPON_BUILDERS = {
	Stick   = buildStick,
	Spear   = buildSpear,
	Knife   = buildKnife,
	Pistol  = buildPistol,
	Shotgun = buildShotgun,
}

-- Build a Tool instance for a weapon spec, choosing the right builder.
local function buildToolForWeapon(spec)
	local tool = Instance.new("Tool")
	tool.Name = Strings.Weapons[spec.DisplayKey] or spec.Id
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", spec.Id)

	local builder = WEAPON_BUILDERS[spec.Id]
	if builder then
		builder(tool)
	else
		-- Fallback: simple block handle.
		local handle = newPart{
			Name = "Handle",
			Size = spec.HandleSize or Vector3.new(0.4, 0.4, 2),
			Color = spec.HandleColor or Color3.fromRGB(120, 80, 40),
			Material = Enum.Material.Wood,
			Parent = tool,
		}
	end

	return tool
end

-- Removes any tools the player currently has, then gives the requested one.
function ShopManager.GiveWeapon(player, weaponId)
	local spec = WeaponConfig.ById[weaponId]
	if not spec then return false end
	-- ensure session ownership reflects this
	dm().GrantSessionWeapon(player, weaponId)
	local sess = dm().GetSession(player)
	sess.CurrentWeapon = weaponId

	local char = player.Character
	if not char then return false end
	local backpack = player:FindFirstChildOfClass("Backpack")
	-- remove only previously-spawned tools (so we don't infinitely stack)
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") then c:Destroy() end
	end
	if backpack then
		for _, c in ipairs(backpack:GetChildren()) do
			if c:IsA("Tool") then c:Destroy() end
		end
	end
	-- Spawn ALL owned weapons; player chooses via 1/2/3 keys (Roblox default).
	for ownedId, _ in pairs(sess.OwnedWeapons) do
		local s = WeaponConfig.ById[ownedId]
		if s then
			local tool = buildToolForWeapon(s)
			tool.Parent = backpack or char
		end
	end
	return true
end

-- Handle XP purchase requests
function ShopManager.HandleBuyXP(player, payload)
	local rm = _G.RoundManager
	if not rm or not rm.IsPlaying() then
		getRemotes().ToastNotify:FireClient(player, {
			text = "ניתן לקנות רק במהלך הסבב", color = Color3.fromRGB(255,170,80),
		})
		return
	end
	if not payload or type(payload) ~= "table" then return end

	local sess = dm().GetSession(player)
	if payload.itemType == "Weapon" then
		local weapon = WeaponConfig.ById[payload.itemId]
		if not weapon then return end
		if WeaponConfig.IsPermanent(weapon.Id) then
			-- Shotgun: must be Robux
			getRemotes().ToastNotify:FireClient(player, {
				text = "רובה ציד נרכש רק ב-Robux", color = Color3.fromRGB(255,170,80),
			})
			return
		end
		if dm().OwnsWeapon(player, weapon.Id) then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.Owned, color = Color3.fromRGB(180,180,180),
			})
			return
		end
		local price = weapon.PriceXP or math.huge
		if not dm().SpendXP(player, price) then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.NotEnoughXP, color = Color3.fromRGB(255,100,100),
			})
			return
		end
		ShopManager.GiveWeapon(player, weapon.Id)
		getRemotes().ToastNotify:FireClient(player, {
			text  = Strings.Shop.Purchased,
			color = Color3.fromRGB(120,220,120),
		})
	elseif payload.itemType == "Upgrade" then
		local id = payload.itemId  -- "Speed" or "HP"
		local cfg = GameConfig.PlaneUpgrades[id]
		if not cfg then return end
		local cur = sess.PlaneUpgrades[id] or 0
		if cur >= #cfg.Levels then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.MaxLevel, color = Color3.fromRGB(180,180,180),
			})
			return
		end
		local price = cfg.Levels[cur + 1]
		if not dm().SpendXP(player, price) then
			getRemotes().ToastNotify:FireClient(player, {
				text = Strings.Shop.NotEnoughXP, color = Color3.fromRGB(255,100,100),
			})
			return
		end
		sess.PlaneUpgrades[id] = cur + 1
		-- Apply effect immediately
		local char = player.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			if id == "HP" then
				local newMax = cfg.Effect[sess.PlaneUpgrades.HP + 1]
				local diff = newMax - hum.MaxHealth
				hum.MaxHealth = newMax
				if diff > 0 then
					hum.Health = math.min(newMax, hum.Health + diff)
				end
			elseif id == "Speed" then
				local mul = cfg.Effect[sess.PlaneUpgrades.Speed + 1]
				hum.WalkSpeed = 16 * mul
			end
		end
		getRemotes().ToastNotify:FireClient(player, {
			text  = Strings.Shop.Purchased,
			color = Color3.fromRGB(120,220,120),
		})
	end
end

function ShopManager.HandlePromptShotgun(player)
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, GameConfig.Products.SHOTGUN)
	end)
	if not ok then
		warn("[ShopManager] PromptShotgun failed:", err)
		getRemotes().ToastNotify:FireClient(player, {
			text = Strings.Notifications.PurchaseFailed, color = Color3.fromRGB(255,100,100),
		})
	end
end

function ShopManager.HandlePromptRevive(player)
	local rm = _G.RoundManager
	if not rm or (rm.GetState() ~= "PLAYING" and rm.GetState() ~= "ENDING") then
		warn("[ShopManager] PromptRevive blocked, state:", rm and rm.GetState() or "nil")
		return
	end
	local sess = dm().GetSession(player)
	if sess.UsedRevive then
		getRemotes().ToastNotify:FireClient(player, {
			text = Strings.Death.ReviveUsed, color = Color3.fromRGB(255,170,80),
		})
		return
	end
	-- Don't trust sess.Alive alone — it can desync with reality (e.g., dev
	-- panel heal that LoadCharacter'd without going through RevivePlayer).
	-- Use the actual Humanoid health: if the character is alive, no revive.
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then return end
	print("[ShopManager] Prompting revive for", player.Name)
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, GameConfig.Products.REVIVE)
	end)
	if not ok then
		warn("[ShopManager] PromptRevive failed:", err)
		getRemotes().ToastNotify:FireClient(player, {
			text  = Strings.Notifications.PurchaseFailed,
			color = Color3.fromRGB(255, 100, 100),
		})
	end
end

function ShopManager.GetShopState(player)
	local sess = dm().GetSession(player)
	local owned = {}
	for k in pairs(sess.OwnedWeapons) do owned[k] = true end
	return {
		ownsShotgun = dm().OwnsShotgun(player),
		ownedWeapons = owned,
		planeUpgrades = sess.PlaneUpgrades,
		xp = sess.XP,
		alive = sess.Alive,
		usedRevive = sess.UsedRevive,
	}
end

function ShopManager.Start()
	getRemotes().BuyXPItem.OnServerEvent:Connect(function(player, payload)
		local ok, err = pcall(ShopManager.HandleBuyXP, player, payload)
		if not ok then warn("[ShopManager] BuyXPItem error:", err) end
	end)
	getRemotes().PromptShotgun.OnServerEvent:Connect(function(player)
		ShopManager.HandlePromptShotgun(player)
	end)
	getRemotes().PromptRevive.OnServerEvent:Connect(function(player)
		ShopManager.HandlePromptRevive(player)
	end)
	getRemotes().GetShopState.OnServerInvoke = function(player)
		return ShopManager.GetShopState(player)
	end
end

ShopManager.Start()
_G.ShopManager = ShopManager
print("[ShopManager] Ready.")
