-- Test range (Build 1): floor, firing line, distance markers, cover, static dummies, strafing dummies,
-- a sentry dummy that tracks players (harmless), and a gun rack that loans any gun into the current slot.
-- Moving parts are physics-driven (servo constraints, server-owned) so motion replicates smoothly
-- without per-frame server CFrame writes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local GunModel = require(shared.GunModel)
local Targets = require(script.Parent.Targets)
local R = Config.Range

local Range = {}
local FIRING_Z = 10

local function part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CastShadow = false
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function label(p, text, face)
	local g = Instance.new("SurfaceGui")
	g.Face = face or Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = g
	g.Parent = p
end

-- Unanchored dummy on a prismatic servo that slides between two points.
local function strafer(folder, at)
	local rail = part(folder, "Rail", Vector3.new(R.StrafeWidth + 2, 0.2, 1), CFrame.new(at), Color3.fromRGB(40, 40, 48))
	local m = Targets.makeDummy(CFrame.new(at + Vector3.new(0, 0.1, 0)), { name = "Strafer", parent = folder })
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			if p ~= m.PrimaryPart then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = m.PrimaryPart, p
				w.Parent = p
			end
		end
	end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = rail, m.PrimaryPart
	local slide = Instance.new("PrismaticConstraint")
	slide.Attachment0, slide.Attachment1 = a0, a1
	slide.ActuatorType = Enum.ActuatorType.Servo
	slide.Speed = R.StrafeSpeed
	slide.ServoMaxForce = 1e6
	slide.LimitsEnabled = true
	slide.LowerLimit, slide.UpperLimit = -R.StrafeWidth / 2, R.StrafeWidth / 2
	slide.Parent = rail
	m.PrimaryPart:SetNetworkOwner(nil)
	return slide
end

-- Sentry: anchored pedestal + head on a hinge servo that turns toward the nearest player.
local function sentry(folder, at)
	part(folder, "SentryPost", Vector3.new(1.2, 3, 1.2), CFrame.new(at + Vector3.new(0, 1.5, 0)), Color3.fromRGB(40, 40, 48))
	local base = part(folder, "SentryBase", Vector3.new(2, 0.4, 2), CFrame.new(at + Vector3.new(0, 3.2, 0)), Color3.fromRGB(40, 40, 48))
	local m = Instance.new("Model")
	m.Name = "Sentry"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local head = part(m, "Head", Vector3.new(2.4, 1.6, 2.4), CFrame.new(at + Vector3.new(0, 4.3, 0)), Color3.fromRGB(120, 124, 136), nil, { Anchored = false })
	local eye = part(m, "Eye", Vector3.new(1.4, 0.3, 0.1), head.CFrame * CFrame.new(0, 0.2, -1.22), Color3.fromRGB(255, 70, 70), Enum.Material.SmoothPlastic, { Anchored = false, CanQuery = false, CanCollide = false })
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = head, eye
	w.Parent = eye
	m.PrimaryPart = head
	m:SetAttribute("MaxHealth", R.SentryHealth)
	m:SetAttribute("Health", R.SentryHealth)
	m:SetAttribute("Down", false)
	game:GetService("CollectionService"):AddTag(m, Targets.TAG)
	m.Parent = folder
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)) -- hinge axis = world Y
	a1.CFrame = CFrame.new(0, -0.8, 0) * CFrame.Angles(0, 0, math.rad(90))
	a0.Parent, a1.Parent = base, head
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0, hinge.Attachment1 = a0, a1
	hinge.ActuatorType = Enum.ActuatorType.Servo
	hinge.AngularSpeed = math.rad(R.SentryTurnRate)
	hinge.ServoMaxTorque = 1e6
	hinge.Parent = base
	head:SetNetworkOwner(nil)
	return hinge, at
end

function Range.build(S)
	local folder = Instance.new("Folder")
	folder.Name = "Range"
	folder.Parent = workspace -- first: network-ownership calls need parts under Workspace
	local dark, line = Color3.fromRGB(34, 36, 44), Color3.fromRGB(64, 220, 255)
	part(folder, "Floor", Vector3.new(160, 1, 280), CFrame.new(0, -0.5, -100), dark, Enum.Material.Concrete)
	for _, x in ipairs({ -80, 80 }) do
		part(folder, "Wall", Vector3.new(2, 14, 280), CFrame.new(x, 7, -100), Color3.fromRGB(48, 50, 60))
	end
	part(folder, "BackWall", Vector3.new(160, 14, 2), CFrame.new(0, 7, 40), Color3.fromRGB(48, 50, 60))
	part(folder, "FiringLine", Vector3.new(120, 0.05, 0.4), CFrame.new(0, 0.03, FIRING_Z), line, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false })
	for _, d in ipairs({ 10, 25, 50, 100, 150 }) do
		part(folder, "Mark" .. d, Vector3.new(120, 0.05, 0.2), CFrame.new(0, 0.03, FIRING_Z - d), Color3.fromRGB(90, 96, 120), Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false })
		label(part(folder, "Sign" .. d, Vector3.new(6, 0.1, 3), CFrame.new(-45, 0.06, FIRING_Z - d), dark, nil, { CanCollide = false, CanQuery = false }), d .. " studs")
	end
	part(folder, "Cover", Vector3.new(8, 3.5, 1), CFrame.new(0, 1.75, FIRING_Z - 18), Color3.fromRGB(70, 74, 86))
	part(folder, "CoverTall", Vector3.new(4, 8, 1), CFrame.new(-8, 4, FIRING_Z - 35), Color3.fromRGB(70, 74, 86))

	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, -0.45, 22) -- faces -Z (downrange)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = dark
	spawn.Material = Enum.Material.Concrete
	spawn.Parent = folder

	for _, d in ipairs(R.StaticDistances) do
		Targets.makeDummy(CFrame.new(-22, 0, FIRING_Z - d), { name = "Static" .. d, parent = folder })
	end
	local slides = { strafer(folder, Vector3.new(18, 0.1, FIRING_Z - 25)), strafer(folder, Vector3.new(18, 0.1, FIRING_Z - 50)) }
	local hinge, sentryAt = sentry(folder, Vector3.new(40, 0, FIRING_Z - 45))

	-- Gun rack: loan any gun into the current slot (no ownership change).
	for i, g in ipairs(Config.Guns) do
		local x = -17.5 + (i - 1) * 7
		local ped = part(folder, "Rack_" .. g.id, Vector3.new(3, 3, 2), CFrame.new(x, 1.5, 33), Color3.fromRGB(48, 50, 60))
		local model = GunModel.build(g)
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		model:PivotTo(CFrame.new(x, 3.5, 33) * CFrame.Angles(0, math.rad(90), 0))
		model.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Equip " .. g.name
		prompt.ObjectText = g.price == 0 and "Free" or (g.price .. " Credits (range loan)")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = ped
		prompt.Triggered:Connect(function(player)
			S.Weapons.loan(player, g.id)
			S.Weapons.push(player)
		end)
	end

	-- One slow loop drives the strafers' targets and the sentry's aim (physics does the motion).
	task.spawn(function()
		local dir = 1
		local flip = R.StrafeWidth / R.StrafeSpeed
		local t = 0
		while folder.Parent do
			local dt = task.wait(0.1)
			t += dt
			if t >= flip then
				t = 0
				dir = -dir
				for _, s in ipairs(slides) do
					s.TargetPosition = dir * R.StrafeWidth / 2
				end
			end
			local best, bestD = nil, R.SentryRange
			for _, p in ipairs(Players:GetPlayers()) do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				local d = root and (root.Position - sentryAt).Magnitude
				if d and d < bestD then
					best, bestD = root, d
				end
			end
			if best then
				local v = best.Position - sentryAt
				hinge.TargetAngle = math.deg(math.atan2(-v.X, -v.Z))
			end
		end
	end)
	return folder
end

return Range
