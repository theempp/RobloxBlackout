-- One-seat kart: invisible physics assembly plus the offline Vortex model. Visual
-- motors articulate wheels, steering and doors; client transforms do not affect
-- the physical collider. Pivot = ground point under the kart at rest.
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Config)
local KartPhysics = require(script.Parent.KartPhysics)

local KartModel = { WHEELS = { "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR" } }
local V = Vector3.new
local BLACK, DARK = Color3.fromRGB(26, 26, 30), Color3.fromRGB(44, 46, 54)

local function vortexLED(name)
	return name:match("^NoseRail_") or name:match("^Headlight_") or name:match("^IntakeRim_")
		or name:match("^Door_[LR]_Rim$") or name:match("^TailLED_")
		or name == "WingLED" or name == "DashScreen"
end

function KartModel.template()
	local folder = RS:FindFirstChild("BlackoutCrewAssets")
	return folder and folder:FindFirstChild(Config.KartModel.Template)
end

-- The steering column axis (kart frame): RAZOR steer origin tilted SteerTilt deg, pointing up/back.
function KartModel.columnAxis()
	local a = math.rad(Config.Kart.Geo.SteerTilt)
	return V(0, math.sin(a), math.cos(a))
end

-- Template kart frame from its Chassis mesh bbox; nil + reason unless every wheel sits on its hub.
function KartModel.templateFrame(tpl)
	local G = Config.Kart.Geo
	local chassis = tpl:FindFirstChild("Chassis", true)
	if not (chassis and chassis:IsA("BasePart")) then
		return nil, "no Chassis part"
	end
	local steer = tpl:FindFirstChild("Steer", true)
	if not (steer and steer:IsA("BasePart")) then return nil, "no Steer part" end
	local frame = chassis.CFrame * CFrame.new(-G.Chassis.Center)
	for i, name in ipairs(KartModel.WHEELS) do
		local w = tpl:FindFirstChild(name, true)
		if not (w and w:IsA("BasePart")) then
			return nil, "missing " .. name
		end
		local d = (frame:PointToObjectSpace(w.Position) - G.Hubs[i]).Magnitude
		if d > Config.KartModel.HubTolerance then
			return nil, string.format("%s %.2f studs off its hub (axes/pivot?)", name, d)
		end
	end
	return frame
end

local function part(m, name, size, cf, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = BLACK
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = m
	return p
end

local function attach(root, p, motor, cc, hub)
	p.Anchored = false
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	if motor then
		local j = Instance.new("Motor6D")
		j.Name = "M_" .. p.Name
		j.Part0, j.Part1 = root, p
		j.C0 = CFrame.new(hub - cc) -- kart-aligned at the design hub
		j.C1 = (root.CFrame * j.C0):ToObjectSpace(p.CFrame):Inverse() -- keeps the part's rest pose
		j.Parent = root
	else
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = root, p
		w.Parent = p
	end
end

local function label(p, face, text, bg, fg)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = bg or Color3.new()
	t.BackgroundTransparency = bg and 0 or 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = fg
	t.Text = text
	t.Parent = sg
	sg.Parent = p
end

-- §17 decal zones on the placeholder: hood = brand (Config.Branding), rear = number plate.
local function decalZones(m, K, number, stealth)
	local G = Config.Kart.Geo
	local hood = part(m, "DecalHood", G.HoodPlate.Size, K * CFrame.new(G.HoodPlate.Center) * CFrame.Angles(math.rad(G.HoodPlate.Pitch), 0, 0))
	local rear = part(m, "DecalRear", G.RearPlate.Size, K * CFrame.new(G.RearPlate.Center), { Color = Color3.fromRGB(220, 220, 210) })
	if stealth then
		hood.Transparency, rear.Transparency = 1, 1
		hood.CanQuery, rear.CanQuery = false, false
		for zone, p in pairs({ hood = hood, rear = rear }) do
			p:SetAttribute("Zone", zone)
			CollectionService:AddTag(p, "BC_DecalZone")
		end
		return { hood, rear }
	end
	local B = Config.Branding
	if B.DecalId ~= "" then
		local d = Instance.new("Decal")
		d.Face, d.Texture = Enum.NormalId.Top, B.DecalId
		d.Parent = hood
	else
		label(hood, Enum.NormalId.Top, B.Name, nil, Color3.fromRGB(190, 190, 196))
	end
	label(rear, Enum.NormalId.Back, string.format("%02d", number), nil, BLACK)
	for zone, p in pairs({ hood = hood, rear = rear }) do
		p:SetAttribute("Zone", zone)
		CollectionService:AddTag(p, "BC_DecalZone")
	end
	return { hood, rear }
end

-- RAZOR-proportioned primitive stand-in (positions from Config.Kart.Geo / razor_build.py), ~40 tris/part.
local function placeholder(m, K)
	local G = Config.Kart.Geo
	local parts = {
		part(m, "Chassis", V(4, 0.8, 9.6), K * CFrame.new(0, 0.58, 0.1)),
		part(m, "Nose", V(3.6, 0.95, 1.05), K * CFrame.new(0, 0.72, -5.12) * CFrame.Angles(math.rad(-14), 0, 0)),
		part(m, "Hood", V(3.2, 0.5, 3.2), K * CFrame.new(0, 1.2, -3.2)),
		part(m, "Engine", V(3.4, 1.2, 3.4), K * CFrame.new(0, 1.6, 3.4)),
		part(m, "Tail", V(4.2, 0.9, 1.1), K * CFrame.new(0, 0.9, 5.0)),
		part(m, "Wing", V(5.1, 0.14, 1.0), K * CFrame.new(0, 3.3, 5.0), { Color = DARK }),
		part(m, "Hoop", V(2.9, 0.3, 0.3), K * CFrame.new(0, 3.2, 1.35), { Color = DARK }),
		part(m, "SeatBack", V(1.2, 1.1, 0.26), K * CFrame.new(0, 2.0, 0.95) * CFrame.Angles(math.rad(-10), 0, 0), { Color = DARK }),
		part(m, "Headlights", V(3.6, 0.14, 0.12), K * CFrame.new(0, 1.0, -5.0), { Color = Color3.fromRGB(235, 235, 230) }),
		part(m, "TailStrips", V(3.1, 0.16, 0.1), K * CFrame.new(0, 1.55, 5.56), { Color = Color3.fromRGB(150, 30, 34) }),
	}
	for _, x in ipairs({ -1, 1 }) do
		table.insert(parts, part(m, "SidePod", V(0.7, 0.8, 4.2), K * CFrame.new(x * 2.2, 0.9, 0.1)))
		table.insert(parts, part(m, "Endplate", V(0.08, 0.9, 1.1), K * CFrame.new(x * 2.55, 3.0, 5.0), { Color = DARK }))
		table.insert(parts, part(m, "WingStrut", V(0.2, 1.2, 0.3), K * CFrame.new(x * 1.4, 2.65, 4.8), { Color = DARK }))
		for _, z in ipairs({ -3.4, 3.6 }) do
			table.insert(parts, part(m, "Fender", V(1.05, 0.25, 2.4), K * CFrame.new(x * 1.925, 1.98, z)))
		end
	end
	local wheels = {}
	for i, hub in ipairs(G.Hubs) do
		wheels[i] = part(m, KartModel.WHEELS[i], V(G.WheelWidth, G.WheelRadius * 2, G.WheelRadius * 2), K * CFrame.new(hub),
			{ Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(18, 18, 20) })
	end
	local axis = KartModel.columnAxis()
	local steer = part(m, "Steer", V(0.15, 0.72, 0.72), K * CFrame.new(G.SteerHub) * CFrame.lookAt(Vector3.zero, axis) * CFrame.Angles(0, math.rad(90), 0),
		{ Shape = Enum.PartType.Cylinder, Color = DARK })
	return parts, wheels, steer
end

-- Clone the owner's RAZOR into kart frame K. Collision (we have our own box) and Underglow (no neon) go.
local function fromTemplate(m, K, tpl, frame)
	local parts, wheels, steers, doors, wheelDetails = {}, {}, {}, {}, {}
	local clone = tpl:Clone()
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Light") then d:Destroy() end
	end
	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") then
			local rel = frame:ToObjectSpace(p.CFrame)
			if p.Name == "Collision" or p.Name == "Underglow" then
				p:Destroy()
				else
					if p:IsA("Part") and (p.Name:match("^Wheel_") or p.Name:match("^Rim_") or p.Name:match("^BrakeDisc_") or p.Name:match("^Hub_")) then
						p.Shape = Enum.PartType.Cylinder
					elseif p:IsA("Part") and (p.Name == "NoseCore" or p.Name:match("^Door_[LR]_Glass")) then
						p.Shape = Enum.PartType.Ball
					end
					if p.Material == Enum.Material.Neon then p.Material = Enum.Material.SmoothPlastic end
					if tpl.Name == Config.KartModel.Template then
						p.Material = p.Name:match("^Wheel_") and Enum.Material.Rubber or Enum.Material.SmoothPlastic
						p.Reflectance = p.Name:match("^Wheel_") and 0 or (p.Transparency > 0 and 0.04 or 0.1)
						if p.Name == "Chassis" then p.Transparency = 1 end
					end
				p.CFrame = K * rel
				p.Parent = m
					if p.Name == "HeadlightStrips" or p.Name == "TailStrips" then
					p.Material = Enum.Material.SmoothPlastic
					p.Color = p.Name == "TailStrips" and Color3.fromRGB(150, 30, 34) or Color3.fromRGB(235, 235, 230)
					p.CastShadow = false
				elseif p.Name == "DecalPlates" then
					p:SetAttribute("Zone", "hood+rear")
					CollectionService:AddTag(p, "BC_DecalZone")
				end
					local wi = table.find(KartModel.WHEELS, p.Name)
					if wi then
						wheels[wi] = p
					elseif p.Name == "Steer" or p.Name:sub(1, 6) == "Steer_" then
						table.insert(steers, p)
					elseif p.Name:sub(1, 5) == "Door_" then
						table.insert(doors, p)
					elseif p.Name:match("^Rim_") or p.Name:match("^BrakeDisc_") or p.Name:match("^Spoke_") or p.Name:match("^Hub_") then
						table.insert(wheelDetails, p)
					else
						table.insert(parts, p)
					end
					if tpl.Name == Config.KartModel.Template and vortexLED(p.Name) then
						p:SetAttribute("VortexLED", true)
					end
			end
		end
	end
	clone:Destroy()
	return parts, wheels, steers, doors, wheelDetails
end

local function linkages(m, root, K, cc)
	local G = Config.Kart.Geo
	local dark = ColorSequence.new(Color3.fromRGB(27, 30, 33))
	for i, name in ipairs(KartModel.WHEELS) do
		local hub = G.Hubs[i]
		local side = hub.X < 0 and -1 or 1
		local knuckle = part(m, "Knuckle_" .. name:sub(-2), V(0.1, 0.1, 0.1), K * CFrame.new(hub), { Transparency = 1, CastShadow = false })
		attach(root, knuckle, true, cc, hub)
		for j, xyz in ipairs({
			{ V(side * 0.69, 1.16, hub.Z - 0.31), V(-side * 0.14, 0.23, -0.23) },
			{ V(side * 0.69, 1.16, hub.Z + 0.31), V(-side * 0.14, 0.23, 0.23) },
			{ V(side * 0.76, 0.52, hub.Z - 0.36), V(-side * 0.16, -0.23, -0.24) },
			{ V(side * 0.76, 0.52, hub.Z + 0.36), V(-side * 0.16, -0.23, 0.24) },
			{ V(side * 0.56, 0.85, hub.Z + 0.18), V(-side * 0.18, -0.05, 0.1) },
		}) do
			local a = Instance.new("Attachment")
			a.Name = "ArmInner_" .. name .. "_" .. j
			a.Position = xyz[1] - cc
			a.Parent = root
			local b = Instance.new("Attachment")
			b.Name = "ArmOuter_" .. name .. "_" .. j
			b.Position = xyz[2]
			b.Parent = knuckle
			local arm = Instance.new("Beam")
			arm.Name = "ControlArm_" .. name .. "_" .. j
			arm.Attachment0, arm.Attachment1 = a, b
			arm.Width0, arm.Width1 = j == 5 and 0.10 or 0.16, j == 5 and 0.10 or 0.16
			arm.FaceCamera = true
			arm.LightInfluence = 1
			arm.Color = dark
			arm.Parent = root
		end
	end
end

-- slot: squad slot (1-4); groundCF: ground point + heading for the kart at rest; opts: { name, number }.
-- Returns model, root, seat. Root starts anchored; the caller unanchors it to drive.
function KartModel.build(slot, groundCF, opts)
	opts = opts or {}
	local Kc = Config.Kart
	local G = Kc.Geo
	local cc = G.Collider.Center
	local m = Instance.new("Model")
	m.Name = opts.name or ("Kart" .. slot)
 m:SetAttribute("KartTier",opts.topTier and "vortex" or "base")
	local rootCF = KartPhysics.restCF(groundCF, Kc)
	local K = rootCF * CFrame.new(-cc) -- kart frame
	local root = part(m, "Root", G.Collider.Size, rootCF, { Transparency = 1, Anchored = true, CastShadow = false,
		CustomPhysicalProperties = PhysicalProperties.new(G.ColliderDensity, 0.3, 0, 1, 1) })
	root.PivotOffset = CFrame.new(-(cc + Vector3.yAxis * Kc.Susp.StaticDrop))
	m.PrimaryPart = root
	local ballast = part(m, "Ballast", G.Ballast.Size, K * CFrame.new(G.Ballast.Center), { Transparency = 1, CastShadow = false,
		CustomPhysicalProperties = PhysicalProperties.new(G.Ballast.Density, 0.3, 0, 1, 1) })
	ballast.CanCollide, ballast.CanQuery, ballast.CanTouch = false, false, false
	local bw = Instance.new("WeldConstraint")
	bw.Part0, bw.Part1 = root, ballast
	bw.Parent = ballast
	local att = Instance.new("Attachment")
	att.Name = "CoM"
	att.Parent = root
	local ag = Instance.new("VectorForce")
	ag.Name = "AntiGravity"
	ag.Attachment0 = att
	ag.RelativeTo = Enum.ActuatorRelativeTo.World
	ag.ApplyAtCenterOfMass = true
	ag.Force = Vector3.zero
	ag.Parent = root
	local tpl = KartModel.template()
	local frame, why
	if tpl then
		frame, why = KartModel.templateFrame(tpl)
		if not frame then
			warn("BC_WARN RAZOR template rejected (" .. why .. "); using the placeholder")
		end
	end
	local parts, wheels, steers, doors, wheelDetails
	if frame then
		parts, wheels, steers, doors, wheelDetails = fromTemplate(m, K, tpl, frame)
		m:SetAttribute("Visual", tpl.Name == Config.KartModel.Template and "vortex" or "razor")
	else
		local steer
		parts, wheels, steer = placeholder(m, K)
		steers, doors, wheelDetails = { steer }, {}, {}
		m:SetAttribute("Visual", "placeholder")
	end
	for _, p in ipairs(parts) do
		attach(root, p, false)
		p.CastShadow = p.Size.Magnitude > 3
	end
	for i, w in ipairs(wheels) do
		attach(root, w, true, cc, G.Hubs[i])
	end
	for _, p in ipairs(steers) do
		attach(root, p, true, cc, G.SteerHub)
	end
	for _, p in ipairs(doors) do
		local side = p.Name:sub(6, 6) == "L" and -1 or 1
		attach(root, p, true, cc, V(side * 1.54, 1.54, 0.9))
	end
	for _, p in ipairs(wheelDetails) do
		local suffix = p.Name:match("_([FR][LR])")
		local wi = suffix and table.find(KartModel.WHEELS, "Wheel_" .. suffix)
		if wi then
			p.Anchored = false
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = wheels[wi], p
			weld.Parent = p
		end
	end
	if m:GetAttribute("Visual") == "vortex" then
		linkages(m, root, K, cc)
		m:SetAttribute("LightsOn", true)
		m:SetAttribute("DoorsOpen", false)
	end
	for _, p in ipairs(decalZones(m, K, opts.number or slot, m:GetAttribute("Visual") == "vortex")) do
		attach(root, p, false)
	end
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = V(1.2, 0.4, 1.2)
	seat.CFrame = K * CFrame.new(G.Seat - V(0, 0.2, 0))
	seat.MaxSpeed, seat.Torque, seat.TurnSpeed = 0, 0, 0 -- we drive, not the seat
	seat.HeadsUpDisplay = false
	seat.CanTouch = false -- no touch-to-sit: enter by action only
	seat.Transparency = 1
	seat.Parent = m
	attach(root, seat, false)
	seat.CanCollide = false
	m:SetAttribute("Slot", slot)
	CollectionService:AddTag(m, "BC_KartVisual")
	return m, root, seat
end

-- Visual tri estimate (placeholder) or the measured RAZOR count (template), vs Config.TriBudget.Kart.
function KartModel.tris(m)
	if m:GetAttribute("Visual") == "razor" or m:GetAttribute("Visual") == "vortex" then
		return Config.Kart.Geo.Tris
	end
	local E, n = Config.TriEstimate, 0
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("Part") and p.Transparency < 1 then
			n += p.Shape == Enum.PartType.Cylinder and E.Cylinder or E.Block
		end
	end
	return n
end

-- Both places use the same ownership, distance and speed checks for vehicle actions.
function KartModel.action(k, player, action)
	if not k or not k.model.Parent or k.owner ~= player or k.model:GetAttribute("Visual") ~= "vortex" then return false end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local charRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not charRoot then return false end
	local seated = hum.SeatPart == k.seat
	if not seated and (charRoot.Position - k.root.Position).Magnitude > 9 then return false end
	if action == "lights" then
		k.model:SetAttribute("LightsOn", not k.model:GetAttribute("LightsOn"))
		return true
	elseif action == "doors" then
		if k.root.AssemblyLinearVelocity.Magnitude > Config.Kart.DoorMaxSpeed then return false end
		k.model:SetAttribute("DoorsOpen", not k.model:GetAttribute("DoorsOpen"))
		return true
	end
	return false
end

function KartModel.closeMovingDoors(k)
	if k.model:GetAttribute("DoorsOpen") and k.root.AssemblyLinearVelocity.Magnitude > Config.Kart.DoorMaxSpeed then
		k.model:SetAttribute("DoorsOpen", false)
	end
end

function KartModel.doorPrompt(k)
	local shell = k.model:FindFirstChild("Door_L_Shell")
	if not shell then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VortexDoors"
	prompt.ActionText = "Open doors"
	prompt.ObjectText = "Blackout Vortex"
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell
	k.model:GetAttributeChangedSignal("DoorsOpen"):Connect(function()
		prompt.ActionText = k.model:GetAttribute("DoorsOpen") and "Close doors" or "Open doors"
	end)
	prompt.Triggered:Connect(function(player) KartModel.action(k, player, "doors") end)
end

return KartModel
