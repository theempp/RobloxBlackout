-- Daily reward screen "Getaway Route" (owner-locked look: refs/daily-reward-concepts/v2/D2.png). Lobby role module;
-- LobbyHud opens it from the DAILY REWARD plate and wires onClaim -> DailyClaim remote. show(view) takes D.view(...).
-- Layout: night skyline backdrop -> one static ViewportFrame diorama (7 rooftop stops climbing left to right to the
-- Directive tower vault, kart, repo drones) -> flat 2D labels projected from the diorama -> reward card + CLAIM,
-- streak / tomorrow / next-reward timer, close X. Art direction: near-black matte, thin gold trim, white LED
-- windows, gold glow on TODAY only (faint gold on the vault). No neon, no emissive. The render loop only runs
-- while open; reduced motion (settings.reducedMotion) freezes every animation.
local RunService = game:GetService("RunService")

local UI = { open = false, onClaim = nil, onClose = nil }
local ctx, C, DR, K, H, D, HudScale
local gui, root, scale, W, H_ = nil, nil, 1, 0, 0
local scene, ov, card, side, closeBtn
local view, shownAt, claimBurst = nil, 0, 0

-- ---------- tiny helpers (Hud.make/corner/stroke are pure; Hud.label needs Hud.init so labels are local) ----------
local function label(parent, text, size, props)
	local l = H.make("TextLabel", parent, { BackgroundTransparency = 1, Text = text, TextSize = size, Font = Enum.Font.GothamBlack, TextColor3 = K.Ink })
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end
local function dim(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

-- ---------- diorama ----------
local STOP_DX, STOP_TOPS = 13, { 10, 12, 14, 12, 16, 15, 34 }
-- The camera looks down +Z, so +X is screen-left: the route runs along -X to read left to right.
local function sx(i: number): number
	return -(i - 1) * STOP_DX
end
local function stopPos(i: number): Vector3
	return Vector3.new(sx(i), STOP_TOPS[i], 0)
end

local function part(parent, size, cf, color, extra)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.CFrame, p.Color, p.Material = size, typeof(cf) == "Vector3" and CFrame.new(cf) or cf, color, Enum.Material.SmoothPlastic
	for k, v in pairs(extra or {}) do
		p[k] = v
	end
	p:SetAttribute("Base", color)
	p.Parent = parent
	return p
end

local function cyl(parent, d, len, cf, color, extra) -- cylinder, axis along local X
	local e = { Shape = Enum.PartType.Cylinder }
	for k, v in pairs(extra or {}) do
		e[k] = v
	end
	return part(parent, Vector3.new(len, d, d), cf, color, e)
end

-- Chunky Roblox-blocky props, base = centre of the roof surface. Colours are matte; gold only as trim.
local function buildProp(kind: string, parent, base: Vector3)
	local m = Instance.new("Model")
	m.Name = kind
	local g, edge = K.Gold, Color3.fromRGB(36, 36, 42)
	local function case(color, trim)
		part(m, Vector3.new(5, 3.2, 3), base + Vector3.new(0, 1.6, 0), color)
		for _, dx in ipairs({ -2.5, 2.5 }) do
			part(m, Vector3.new(0.3, 3.3, 3.1), base + Vector3.new(dx, 1.6, 0), trim)
		end
		part(m, Vector3.new(5.1, 0.3, 3.1), base + Vector3.new(0, 3.3, 0), trim)
		part(m, Vector3.new(5.1, 0.3, 3.1), base + Vector3.new(0, 0.15, 0), trim)
		part(m, Vector3.new(1, 0.8, 0.25), base + Vector3.new(0, 1.8, -1.6), trim) -- crown plate
		part(m, Vector3.new(1.6, 0.5, 0.8), base + Vector3.new(0, 3.7, 0), edge) -- handle
	end
	if kind == "cash" then
		for r = 0, 1 do
			for c = 0, 2 do
				part(m, Vector3.new(1.5, 1, 2.4), base + Vector3.new((c - 1) * 1.6, 0.5 + r * 1.05, 0), Color3.fromRGB(44, 110, 62))
				part(m, Vector3.new(0.4, 1.02, 2.5), base + Vector3.new((c - 1) * 1.6, 0.5 + r * 1.05, 0), Color3.fromRGB(200, 205, 198))
			end
		end
	elseif kind == "spray" then
		cyl(m, 1.8, 3, CFrame.new(base + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(58, 98, 156))
		cyl(m, 1.2, 0.9, CFrame.new(base + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 40, 46))
		part(m, Vector3.new(0.6, 0.5, 0.4), base + Vector3.new(0, 1.8, -0.95), g)
	elseif kind == "token" then
		cyl(m, 3.6, 0.5, CFrame.new(base + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(52, 50, 64))
		cyl(m, 2.4, 0.3, CFrame.new(base + Vector3.new(0, 2, -0.3)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(86, 84, 104))
		part(m, Vector3.new(1.1, 0.8, 0.2), base + Vector3.new(0, 2, -0.5), g)
	elseif kind == "case" then
		case(Color3.fromRGB(26, 26, 30), g)
	elseif kind == "crate" then
		case(Color3.fromRGB(70, 72, 80), Color3.fromRGB(150, 152, 160))
	elseif kind == "crate2" then
		case(Color3.fromRGB(32, 30, 28), Color3.fromRGB(190, 146, 56))
	elseif kind == "vault" then
		part(m, Vector3.new(8, 7, 5), base + Vector3.new(0, 3.5, 0), Color3.fromRGB(24, 25, 30))
		cyl(m, 4.6, 0.5, CFrame.new(base + Vector3.new(0, 3.6, -2.7)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(46, 48, 54))
		cyl(m, 3.0, 0.3, CFrame.new(base + Vector3.new(0, 3.6, -3.0)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(70, 72, 80))
		part(m, Vector3.new(1.4, 1, 0.2), base + Vector3.new(0, 3.6, -3.2), g)
		for _, e in ipairs({ { 8.2, 0.3, 5.2, 0 }, { 8.2, 0.3, 5.2, 7 } }) do -- gold outline top/bottom
			part(m, Vector3.new(e[1], e[2], e[3]), base + Vector3.new(0, e[4] + 0.15, 0), K.GoldDim, { Name = "Trim" })
		end
		for _, dx in ipairs({ -4.1, 4.1 }) do
			part(m, Vector3.new(0.3, 7, 5.2), base + Vector3.new(dx, 3.5, 0), K.GoldDim, { Name = "Trim" })
		end
		part(m, Vector3.new(0.3, 3, 0.3), base + Vector3.new(2.5, 8.5, 0), edge) -- antenna
	end
	m.Parent = parent
	return m
end

local function buildDrone(parent, pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "Drone"
	part(m, Vector3.new(2.2, 0.8, 2.2), pos, Color3.fromRGB(22, 22, 27))
	part(m, Vector3.new(0.8, 0.5, 0.8), pos + Vector3.new(0, -0.6, 0), K.Led)
	for _, o in ipairs({ { 1.6, 1.6 }, { -1.6, 1.6 }, { 1.6, -1.6 }, { -1.6, -1.6 } }) do
		cyl(m, 1.5, 0.12, CFrame.new(pos + Vector3.new(o[1], 0.55, o[2])) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 72, 80), { Transparency = 0.35 })
	end
	-- vision cone: two mirrored wedges seen edge-on, a soft white beam
	for _, s in ipairs({ 1, -1 }) do
		local wedge = Instance.new("WedgePart")
		wedge.Anchored, wedge.CanCollide, wedge.CanQuery, wedge.CastShadow = true, false, false, false
		wedge.Material, wedge.Color, wedge.Transparency = Enum.Material.SmoothPlastic, K.Led, 0.9
		wedge.Size = Vector3.new(0.3, 9, 2.4)
		wedge.CFrame = CFrame.new(pos + Vector3.new(s * 1.2, -5.2, 0)) * CFrame.Angles(0, math.rad(90), s == 1 and 0 or math.rad(180))
		wedge:SetAttribute("Base", K.Led)
		wedge.Parent = m
	end
	m.Parent = parent
	return m
end

local function buildKart(parent, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Kart"
	local dark, blue = Color3.fromRGB(20, 20, 24), K.Kart
	part(m, Vector3.new(4.6, 0.9, 2.6), cf * CFrame.new(0, 0.9, 0), dark)
	part(m, Vector3.new(3.2, 0.5, 0.6), cf * CFrame.new(-0.4, 1.45, -1.1), blue)
	part(m, Vector3.new(3.2, 0.5, 0.6), cf * CFrame.new(-0.4, 1.45, 1.1), blue)
	part(m, Vector3.new(1.6, 1.3, 1.6), cf * CFrame.new(-0.6, 1.9, 0), Color3.fromRGB(40, 44, 54)) -- seat back
	part(m, Vector3.new(1.3, 1.3, 1.3), cf * CFrame.new(-0.2, 3, 0), blue) -- helmet
	part(m, Vector3.new(0.5, 0.8, 1.0), cf * CFrame.new(0.4, 3, 0), Color3.fromRGB(24, 28, 40))
	for _, w in ipairs({ { 1.5, -1.5 }, { 1.5, 1.5 }, { -1.5, -1.5 }, { -1.5, 1.5 } }) do
		cyl(m, 1.3, 0.9, cf * CFrame.new(w[1], 0.65, w[2]) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(14, 14, 16))
	end
	m.Parent = parent
	return m
end

local function buildScene(vp: ViewportFrame)
	local rng = Random.new(7)
	local world = Instance.new("Model")
	world.Name = "Scene"
	world.Parent = vp
	local stops = {}
	for i = 1, 7 do
		local top = STOP_TOPS[i]
		local c = Vector3.new(sx(i), 0, 0)
		part(world, Vector3.new(11, top, 11), c + Vector3.new(0, top / 2, 0), Color3.fromRGB(30, 32, 42))
		part(world, Vector3.new(11.6, 0.5, 11.6), c + Vector3.new(0, top, 0), Color3.fromRGB(62, 64, 76))
		if i == 7 then
			part(world, Vector3.new(11.8, 0.3, 11.8), c + Vector3.new(0, top + 0.3, 0), K.GoldDim)
		end
		for row = 1, math.floor(top / 3.4) do
			for col = -1, 1 do
				if rng:NextNumber() < 0.42 then
					part(world, Vector3.new(1.1, 1.3, 0.1), c + Vector3.new(col * 3, row * 3.4 - 0.8, -5.55), Color3.fromRGB(236, 232, 214))
				end
			end
		end
		-- route strip + white dashes toward the next stop
		part(world, Vector3.new(10, 0.2, 3), c + Vector3.new(0, top + 0.35, -3.5), Color3.fromRGB(32, 33, 40))
		for d = -1, 2 do
			part(world, Vector3.new(1, 0.1, 0.45), c + Vector3.new(d * 2.4 - 1.2, top + 0.5, -3.5), K.Led)
		end
		stops[i] = { top = top, centre = c }
	end
	local props = {}
	for i, r in ipairs(DR.Rewards) do
		local s = stops[i]
		props[i] = buildProp(r.prop, world, Vector3.new(s.centre.X, s.top + 0.35, i == 7 and 0 or 0.8))
	end
	local drones = {
		buildDrone(world, stopPos(4) + Vector3.new(-4, 12, 0)),
		buildDrone(world, stopPos(6) + Vector3.new(3, 12, 0)),
	}
	for _, d in ipairs(drones) do
		d:SetAttribute("Home", d:GetPivot().Position)
	end
	local kart = buildKart(world, CFrame.new(stopPos(2) + Vector3.new(-5.2, 0.5, -3.5)) * CFrame.Angles(0, math.rad(180), 0))
	local cam = Instance.new("Camera")
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Ambient, vp.LightColor, vp.LightDirection = Color3.fromRGB(120, 126, 150), Color3.fromRGB(200, 206, 232), Vector3.new(-0.5, -1, 0.7)
	return { world = world, props = props, drones = drones, kart = kart, cam = cam, vp = vp }
end

-- Camera fitted so the whole route (x 0..78) always fits the viewport width, then tilted isometric-ish.
local TARGET, OFFSET = Vector3.new(-39, 17, 0), Vector3.new(26, 46, -150)
local function fitCamera(aspect: number)
	local cam = scene.cam
	cam.CFrame = CFrame.lookAt(TARGET + OFFSET, TARGET)
	local half = 58
	cam.FieldOfView = math.deg(2 * math.atan((half / aspect) / OFFSET.Magnitude))
	cam.FieldOfView = math.clamp(cam.FieldOfView, 10, 40)
end

-- World point -> pixel inside the viewport (the camera's own projection, no engine call).
local function project(p: Vector3, w: number, h: number): Vector2
	local cam = scene.cam
	local v = cam.CFrame:PointToObjectSpace(p)
	local t = math.tan(math.rad(cam.FieldOfView) / 2)
	local nx, ny = (v.X / -v.Z) / t / (w / h), (v.Y / -v.Z) / t
	return Vector2.new((nx * 0.5 + 0.5) * w, (0.5 - ny * 0.5) * h)
end
UI._project = project

-- ---------- 2D pieces ----------
local function panel(parent, props)
	local f = H.make("Frame", parent, { BackgroundColor3 = K.Panel, BorderSizePixel = 0 })
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	H.corner(f, 8)
	H.stroke(f, K.GoldDim, 1.5, 0)
	return f
end

local function buildBackdrop(parent)
	local bg = H.make("Frame", parent, { Name = "Backdrop", BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(-400, -400), Size = UDim2.new(1, 800, 1, 800), ZIndex = 0 })
	H.make("UIGradient", bg, { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(20, 24, 36), K.Night) })
	local sky = H.make("Frame", parent, { Name = "Sky", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 })
	local moon = H.make("Frame", sky, { Name = "Moon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.66, 0, 0, 44), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.fromRGB(222, 226, 236), BorderSizePixel = 0, ZIndex = 1 })
	H.corner(moon, UDim.new(0.5, 0))
	local rng = Random.new(11) -- far skyline: flat dark blocks with a few LED windows
	for i = 0, 17 do
		local w, h = rng:NextInteger(34, 70), rng:NextInteger(60, 190)
		local b = H.make("Frame", sky, { Name = "Far" .. i, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(i / 17, -20, 0.8, 0), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(14, 15, 20) or Color3.fromRGB(11, 12, 16), BorderSizePixel = 0, ZIndex = 1 })
		for _ = 1, rng:NextInteger(2, 5) do
			H.make("Frame", b, { Position = UDim2.fromOffset(rng:NextInteger(4, math.max(5, w - 8)), rng:NextInteger(6, math.max(7, h - 12))), Size = UDim2.fromOffset(3, 4),
				BackgroundColor3 = Color3.fromRGB(226, 224, 214), BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 2 })
		end
	end
	return bg
end

local function buildTitle(parent)
	local t = H.make("Frame", parent, { Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 6), Size = UDim2.fromOffset(250, 96), Rotation = -5, ZIndex = 6 })
	local a = label(t, "GETAWAY", 44, { Size = UDim2.new(1, 0, 0, 48), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, TextStrokeTransparency = 0.2, TextStrokeColor3 = Color3.new(0, 0, 0) })
	H.make("UIGradient", a, { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 154, 166)) })
	local b = label(t, "ROUTE", 40, { Position = UDim2.fromOffset(38, 44), Size = UDim2.fromOffset(150, 44), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, TextColor3 = K.Gold, TextStrokeTransparency = 0.2, TextStrokeColor3 = Color3.new(0, 0, 0) })
	H.make("UIGradient", b, { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 214, 110), Color3.fromRGB(176, 124, 36)) })
	local kv = H.make("ViewportFrame", t, { Name = "TitleKart", BackgroundTransparency = 1, Position = UDim2.fromOffset(180, 40), Size = UDim2.fromOffset(78, 56), ZIndex = 7,
		Ambient = Color3.fromRGB(90, 94, 110), LightColor = Color3.fromRGB(210, 214, 236), LightDirection = Vector3.new(-0.5, -1, 0.7) })
	local model = buildKart(kv, CFrame.new())
	local cam = Instance.new("Camera")
	cam.CFrame, cam.FieldOfView = CFrame.lookAt(Vector3.new(-9, 7, -11), Vector3.new(0, 1.4, 0)), 26
	cam.Parent = kv
	kv.CurrentCamera = cam
	model.Parent = kv
	return t
end

local function buildLabels(parent)
	local layer = H.make("Frame", parent, { Name = "Labels", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 })
	local out = { layer = layer, plates = {}, pills = {}, glow = nil }
	for i = 1, 7 do
		local plate = H.make("Frame", layer, { Name = "Plate" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(i == 3 and 52 or 44, i == 3 and 18 or 15), BackgroundColor3 = Color3.fromRGB(18, 18, 20), BorderSizePixel = 0, ZIndex = 6 })
		H.corner(plate, 5)
		out.plates[i] = { frame = plate, stroke = H.stroke(plate, K.GoldDim, 1.2, 0), text = label(plate, "DAY " .. i, 11, { Size = UDim2.fromScale(1, 1), ZIndex = 7 }) }
		local pill = H.make("Frame", layer, { Name = "Pill" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, 15), BackgroundColor3 = Color3.fromRGB(18, 18, 20), BorderSizePixel = 0, ZIndex = 6 })
		H.corner(pill, UDim.new(0.5, 0))
		out.pills[i] = { frame = pill, stroke = H.stroke(pill, K.GoldDim, 1.2, 0), text = label(pill, "", 9, { Size = UDim2.fromScale(1, 1), ZIndex = 7 }) }
	end
	-- TODAY glow: two nested gold outlines pulsing together (soft glow without any emissive part)
	local g1 = H.make("Frame", layer, { Name = "GlowOuter", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(78, 62), BackgroundTransparency = 1, ZIndex = 4, Visible = false })
	H.corner(g1, 12)
	local s1 = H.stroke(g1, K.Gold, 5, 0.75)
	local g2 = H.make("Frame", g1, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1 })
	H.corner(g2, 9)
	local s2 = H.stroke(g2, K.Gold, 2, 0.35)
	out.glow = { frame = g1, outer = s1, inner = s2 }
	local ring = H.make("Frame", layer, { Name = "ClaimBurst", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 8, Visible = false })
	H.corner(ring, UDim.new(0.5, 0))
	out.burst = { frame = ring, stroke = H.stroke(ring, K.Gold, 3, 0) }
	return out
end

local function buildCard(parent)
	local f = panel(parent, { Name = "RewardCard", AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(330, 92), ZIndex = 10 })
	local icon = panel(f, { Name = "Icon", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(34, 34), ZIndex = 11 })
	local gem = H.make("Frame", icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14), Rotation = 45, BackgroundColor3 = K.Gold, BorderSizePixel = 0, ZIndex = 12 })
	local head = label(f, "", 11, { Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -60, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = K.Gold, ZIndex = 11 })
	local name = label(f, "", 20, { Position = UDim2.fromOffset(52, 22), Size = UDim2.new(1, -60, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 11 })
	local claim = H.make("TextButton", f, { Name = "Claim", Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 0, 32), BackgroundColor3 = Color3.fromRGB(10, 10, 12), AutoButtonColor = false,
		Text = "CLAIM", TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = K.Gold, ZIndex = 11, Selectable = true })
	H.corner(claim, 7)
	local cs = H.stroke(claim, K.Gold, 2, 0)
	claim:SetAttribute("TouchTarget", true)
	return { frame = f, head = head, name = name, claim = claim, claimStroke = cs, gem = gem }
end

local function buildSide(parent)
	local f = panel(parent, { Name = "Streak", AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(250, 58), ZIndex = 10 })
	local n = label(f, "0", 30, { Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(40, 44), TextColor3 = K.Gold, ZIndex = 11 })
	label(f, "DAY\nSTREAK", 9, { Position = UDim2.fromOffset(46, 14), Size = UDim2.fromOffset(40, 28), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = K.Muted, ZIndex = 11 })
	H.make("Frame", f, { Position = UDim2.fromOffset(92, 10), Size = UDim2.fromOffset(1, 38), BackgroundColor3 = K.GoldDim, BorderSizePixel = 0, ZIndex = 11 })
	label(f, "TOMORROW'S REWARD", 8, { Position = UDim2.fromOffset(100, 10), Size = UDim2.new(1, -106, 0, 11), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = K.Muted, ZIndex = 11 })
	local tom = label(f, "", 14, { Position = UDim2.fromOffset(100, 22), Size = UDim2.new(1, -106, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 11 })
	local pill = panel(parent, { Name = "NextTimer", AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(250, 24), ZIndex = 10 })
	pill.UICorner.CornerRadius = UDim.new(0.5, 0)
	local timer = label(pill, "", 11, { Size = UDim2.fromScale(1, 1), ZIndex = 11 })
	return { frame = f, streak = n, tomorrow = tom, pill = pill, timer = timer }
end

-- ---------- state ----------
local PILL = {
	claimed = { text = "✓ CLAIMED", color = function() return K.Claimed end, w = 64 },
	today = { text = "TODAY", color = function() return K.Gold end, w = 54 },
	locked = { text = "LOCKED", color = function() return K.Muted end, w = 56 },
}

local function tint(model, f)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local base = p:GetAttribute("Base") or p.Color
			p.Color = f >= 1 and base or dim(base, f)
		end
	end
end

local function reduced()
	return ctx.settings ~= nil and ctx.settings.reducedMotion == true
end

local function layout()
	if not gui or W < 10 then
		return
	end
	local vw, vh = W, H_
	scene.vp.Size = UDim2.fromOffset(vw, vh)
	fitCamera(vw / vh)
	ov.layer.Size = UDim2.fromOffset(vw, vh)
	for i = 1, 7 do
		local top = STOP_TOPS[i]
		local propTop = (DR.Rewards[i].prop == "vault" and 9.5) or 5.2
		local plate = project(Vector3.new(sx(i), top + propTop + 1.5, 0), vw, vh)
		local pill = project(Vector3.new(sx(i), top + 0.5, -5.8), vw, vh)
		ov.plates[i].frame.Position = UDim2.fromOffset(plate.X, plate.Y)
		ov.pills[i].frame.Position = UDim2.fromOffset(pill.X, pill.Y + 4)
	end
	local cw = math.min(330, vw * 0.6)
	card.frame.Size = UDim2.fromOffset(cw, 92)
	card.frame.Position = UDim2.fromOffset(8, vh - 8)
	local sw = math.min(250, vw * 0.36)
	side.frame.Size = UDim2.fromOffset(sw, 58)
	side.frame.Position = UDim2.fromOffset(vw - 8, vh - 8 - 24 - 6)
	side.pill.Size = UDim2.fromOffset(sw, 24)
	side.pill.Position = UDim2.fromOffset(vw - 8, vh - 8)
	local size = HudScale.touchSize(40, scale, 1)
	closeBtn.Size = UDim2.fromOffset(size, size)
	closeBtn.Position = UDim2.fromOffset(vw - 8 - size, 8)
end

local function render(v)
	view = v
	shownAt = os.clock()
	layout()
	for i, d in ipairs(v.days) do
		local pl, pi, st = ov.plates[i], ov.pills[i], PILL[d.state]
		pl.stroke.Color = d.state == "today" and K.Gold or K.GoldDim
		pl.text.TextColor3 = d.state == "locked" and K.Muted or K.Ink
		pi.text.Text, pi.text.TextColor3 = st.text, d.state == "today" and Color3.fromRGB(18, 14, 6) or st.color()
		pi.frame.Size = UDim2.fromOffset(st.w, 15)
		pi.frame.BackgroundColor3 = d.state == "today" and K.Gold or Color3.fromRGB(18, 18, 20)
		pi.stroke.Color = d.state == "claimed" and K.Claimed or (d.state == "today" and K.Gold or K.GoldDim)
		tint(scene.props[i], d.state == "locked" and 0.5 or 1)
		for _, p in ipairs(scene.props[i]:GetDescendants()) do
			if p.Name == "Trim" then
				p.Color = d.state == "today" and K.Gold or K.GoldDim
			end
		end
	end
	local today = v.todayDay
	ov.glow.frame.Visible = today ~= nil
	if today then
		local p = project(Vector3.new(sx(today), STOP_TOPS[today] + 2.8, 0.8), W, H_)
		ov.glow.frame.Position = UDim2.fromOffset(p.X, p.Y)
	end
	local r = v.today or v.days[math.max(1, v.shown)].reward
	card.head.Text = v.canClaim and ("DAY " .. v.todayDay .. " REWARD") or "TODAY'S REWARD CLAIMED"
	card.name.Text = r.name
	card.claim.Text = v.canClaim and "CLAIM" or "COME BACK TOMORROW"
	card.claim.TextSize = v.canClaim and 20 or 13
	card.claim.TextColor3 = v.canClaim and K.Gold or K.Muted
	card.claimStroke.Color = v.canClaim and K.Gold or K.GoldDim
	card.claim.Active = v.canClaim
	side.streak.Text = tostring(v.streak)
	side.tomorrow.Text = v.tomorrow.name
	side.timer.Text = "NEXT REWARD " .. D.timerText(v.secondsLeft)
end

-- ---------- public ----------
function UI.render(v) -- render without opening (tests / previews)
	render(v)
end

function UI.refresh()
	if ctx.profile and ctx.profile.daily then
		render(D.view(ctx.profile, workspace:GetServerTimeNow()))
	end
end

-- Server answered a claim: pass the fresh view; plays the burst unless reduced motion.
function UI.claimed(ok: boolean, message: string?, v)
	if message and ctx.Hud and ctx.Hud.toast then
		ctx.Hud.toast(message, 3)
	end
	if v then
		render(v)
	end
	if ok and not reduced() then
		claimBurst = 0.6
	end
end

local function loop(dt: number)
	local t = os.clock()
	local rm = reduced()
	if view then
		local left = view.secondsLeft - (t - shownAt)
		side.timer.Text = "NEXT REWARD " .. D.timerText(left)
		if left <= 0 and ctx.profile then
			UI.refresh() -- day boundary passed while open
		end
	end
	local pulse = rm and 0.5 or 0.5 + 0.5 * math.sin(t * 2 * math.pi / DR.Pulse)
	ov.glow.outer.Transparency, ov.glow.inner.Transparency = 0.9 - 0.3 * pulse, 0.6 - 0.35 * pulse
	if not rm then
		for i, d in ipairs(scene.drones) do
			local home = d:GetAttribute("Home")
			d:PivotTo(CFrame.new(home + Vector3.new(math.sin(t * 0.9 + i) * 0.8, math.sin(t * 1.3 + i * 2) * 0.4, 0)))
		end
	end
	if claimBurst > 0 then
		claimBurst -= dt
		local f = 1 - math.max(claimBurst, 0) / 0.6
		local b = ov.burst
		b.frame.Visible = claimBurst > 0
		b.frame.Position = ov.glow.frame.Position
		b.frame.Size = UDim2.fromOffset(10 + f * 90, 10 + f * 90)
		b.stroke.Transparency = f
	end
end

function UI.show(v)
	if not gui then
		return
	end
	UI.open = true
	gui.Enabled = true
	render(v or view or D.view({ daily = D.clean(nil) }, workspace:GetServerTimeNow()))
	if ctx.Menus then
		ctx.Menus.open("daily", function()
			UI.hide(true)
		end)
	end
	if UI._conn then
		UI._conn:Disconnect()
	end
	UI._conn = RunService.RenderStepped:Connect(loop)
	if ctx.Menus then
		ctx.Menus.focus(card.claim)
	end
end

function UI.hide(fromMenus: boolean?)
	if not gui or not UI.open then
		return
	end
	UI.open = false
	gui.Enabled = false
	if UI._conn then
		UI._conn:Disconnect()
		UI._conn = nil
	end
	if ctx.Menus and not fromMenus then
		ctx.Menus.closed("daily")
	end
	if UI.onClose then
		UI.onClose()
	end
end

function UI.init(c)
	ctx = c
	C, H, D = c.Config, c.Hud, require(c.shared.DailyReward)
	DR, K = C.DailyReward, C.DailyReward.Colors
	HudScale = require(c.shared.HudScale)
	local lp = game:GetService("Players").LocalPlayer
	gui = H.make("ScreenGui", nil, { Name = "BlackoutCrewDaily", ResetOnSpawn = false, IgnoreGuiInset = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 30, Enabled = false })
	root = H.make("Frame", gui, { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local us = H.make("UIScale", root)
	buildBackdrop(root)
	local vp = H.make("ViewportFrame", root, { Name = "Route", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	scene = buildScene(vp)
	ov = buildLabels(root)
	buildTitle(root)
	card = buildCard(root)
	side = buildSide(root)
	closeBtn = H.make("TextButton", root, { Name = "Close", Text = "X", TextSize = 18, Font = Enum.Font.GothamBlack, TextColor3 = K.Ink, AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(14, 14, 16), ZIndex = 12, Selectable = true })
	H.corner(closeBtn, 8)
	H.stroke(closeBtn, K.GoldDim, 2, 0)
	closeBtn:SetAttribute("TouchTarget", true)
	closeBtn.Activated:Connect(function()
		UI.hide()
	end)
	card.claim.Activated:Connect(function()
		if view and view.canClaim and UI.onClaim then
			UI.onClaim()
		end
	end)
	local function rescale()
		local a = gui.AbsoluteSize
		if a.X < 10 then
			return
		end
		scale = HudScale.scale(a.X, a.Y, ctx.settings and ctx.settings.largeHud)
		W, H_ = a.X / scale, a.Y / scale
		us.Scale = scale
		root.Size = UDim2.fromScale(1 / scale, 1 / scale)
		layout()
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	gui.Parent = lp:WaitForChild("PlayerGui")
	rescale()
	ctx.on("settings", rescale)
	ctx.on("profile", function()
		if UI.open then
			UI.refresh()
		end
	end)
	ctx.probe = ctx.probe or {}
	ctx.probe.daily = function(command)
		if command == "open" then
			UI.show(ctx.profile and ctx.profile.daily and D.view(ctx.profile, workspace:GetServerTimeNow()) or nil)
		elseif command == "close" then
			UI.hide()
		end
		return { open = UI.open, canClaim = view and view.canClaim, stops = view and #view.days, size = { W, H_ } }
	end
end

return UI
