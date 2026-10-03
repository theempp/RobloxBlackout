-- Heist HUD v2: the owner's reference layout (refs/hud/hud-reference.webp), pure presentation. HeistHud builds it
-- (HudV2.build(Hud.root, ctx)) and feeds the setters; LobbyHud reuses the plate/round/label helpers. Structure:
--   top-left   minimap (N tab; HeistHud parents its scrolling World frame into v.mapClip) + objective checklist
--   top-left   squad portraits (4 circles, health bar on each) just right of the minimap
--   top-right  health bar + number, weapon + magazine | capacity
--   bottom-left   move stick (visual; Roblox's thumbstick still moves you)
--   bottom-right  Controls' own touch buttons (fire, ADS, gun, jump, reload, sneak) restyled by v.adopt and placed
--                 by Controls from Config.Touch ref -> HudRef.Buttons, so layout editing keeps working
--   bottom-centre  inventory / menu / map dock (menu opens settings; the others are greyed until a system exists)
-- Near-black matte panels, dark edge + thin grey rim, light-grey ink. No neon, no emissive, no colour glow.
-- Squad slot colour stays a small dot per portrait and a name under it (directive 5e: colour is never the only cue).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HudV2 = {}

local THUMB = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"
HudV2.THUMB = THUMB

function HudV2.label(H, K, p, text, size, props)
	local l = H.make("TextLabel", p, { BackgroundTransparency = 1, Text = text, TextSize = size, Font = Enum.Font.GothamBlack, TextColor3 = K.Ink })
	for k, val in pairs(props or {}) do
		l[k] = val
	end
	return l
end

-- Matte plate: dark fill, near-black outer edge, thin grey inner rim (the reference's double border).
function HudV2.plate(H, K, p, props, radius, kind)
	local f = H.make(kind or "Frame", p, { BackgroundColor3 = K.Panel, BorderSizePixel = 0 })
	for k, val in pairs(props or {}) do
		f[k] = val
	end
	H.corner(f, radius or 8)
	H.stroke(f, K.Edge, 3, 0)
	local rim = H.make("Frame", f, { Name = "Rim", BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), ZIndex = f.ZIndex })
	H.corner(rim, typeof(radius) == "UDim" and radius or math.max(2, (radius or 8) - 2))
	H.stroke(rim, K.Rim, 1, 0.35)
	return f
end

-- Restyle a round button (made by Hud.button or HudV2.round) as a matte reference button.
function HudV2.matte(H, K, b)
	b.BackgroundColor3, b.TextColor3, b.Font, b.AutoButtonColor = K.Button, K.Ink, Enum.Font.GothamBlack, false
	b:SetAttribute("RestStroke", K.Edge) -- Controls edit mode / HeistControls sneak restore these
	b:SetAttribute("RestFill", K.Button)
	local s = b:FindFirstChildOfClass("UIStroke") or H.stroke(b)
	s.Color, s.Thickness, s.Transparency = K.Edge, 3, 0
	if not b:FindFirstChild("Rim") then
		local rim = H.make("Frame", b, { Name = "Rim", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -5, 1, -5),
			BackgroundTransparency = 1, ZIndex = b.ZIndex })
		H.corner(rim, UDim.new(0.5, 0))
		H.stroke(rim, K.Rim, 1, 0.35)
	end
	return b
end

function HudV2.round(H, K, p, name, text, d, pos, icon)
	local b = H.make("TextButton", p, { Name = name, Text = text, TextSize = 10, Selectable = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos,
		Size = UDim2.fromOffset(d, d), ZIndex = 2 })
	H.corner(b, UDim.new(0.5, 0))
	HudV2.matte(H, K, b)
	if icon and icon ~= "" then
		b.Text = ""
		H.make("ImageLabel", b, { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62), Image = icon, ZIndex = 3 })
	end
	b:SetAttribute("TouchTarget", true)
	return b
end

function HudV2.build(parent, ctx)
	local C, H = ctx.Config, ctx.Hud
	local HR, K = C.HudRef, C.HudRef.Colors
	local HudScale = require(ctx.shared.HudScale)
	local v = { buttons = {}, portraits = {}, rows = {}, touchOnly = {} }
	local function label(p, text, size, props)
		return HudV2.label(H, K, p, text, size, props)
	end
	local function plate(p, props, radius)
		return HudV2.plate(H, K, p, props, radius)
	end
	local root = H.make("Frame", parent, { Name = "HudV2", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	v.root = root

	-- ---- top-left: minimap ----
	local m = HR.Map
	local map = plate(root, { Name = "Minimap", Position = UDim2.fromOffset(m.x, m.y + HR.TopInset), Size = UDim2.fromOffset(m.w, m.h), BackgroundColor3 = Color3.fromRGB(70, 70, 74), ClipsDescendants = true }, 9)
	v.map = map
	v.mapClip = map
	v.me = label(map, "▲", 16, { Name = "Me", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16), TextColor3 = Color3.new(1, 1, 1), ZIndex = 6 })
	local n = plate(root, { Name = "NorthTab", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(m.x + m.w / 2, m.y + HR.TopInset), Size = UDim2.fromOffset(26, 12), ZIndex = 3 }, 4)
	label(n, "N", 10, { Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	v.north = n

	-- ---- objective checklist (title + up to 4 steps, pooled) ----
	local o = HR.Objective
	local obj = plate(root, { Name = "Objective", Position = UDim2.fromOffset(o.x, m.y + HR.TopInset + m.h + 6), Size = UDim2.fromOffset(o.w + 14, 58) }, 6)
	v.objective = obj
	local gem = H.make("Frame", obj, { Name = "Gem", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(12, 11), Size = UDim2.fromOffset(8, 8), Rotation = 45, BackgroundTransparency = 1 })
	H.stroke(gem, K.Ink, 1.5, 0)
	v.objTitle = label(obj, "", 11, { Position = UDim2.fromOffset(22, 4), Size = UDim2.new(1, -26, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	for i = 1, 4 do
		local y = 20 + (i - 1) * 12
		local dot = H.make("Frame", obj, { Name = "Dot" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(12, y + 6), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = K.Muted, BorderSizePixel = 0, Visible = false })
		H.corner(dot, UDim.new(0.5, 0))
		local ring = H.stroke(dot, K.Ink, 1, 1)
		local text = label(obj, "", 9, { Name = "Step" .. i, Position = UDim2.fromOffset(22, y), Size = UDim2.new(1, -26, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold,
			TextTruncate = Enum.TextTruncate.AtEnd, Visible = false })
		v.rows[i] = { dot = dot, ring = ring, text = text }
	end

	-- ---- squad portraits ----
	local s = HR.Squad
	for i = 1, s.max do
		local d = s.d
		local ring = H.make("Frame", root, { Name = "Portrait" .. i, Position = UDim2.fromOffset(s.x + (i - 1) * s.step, s.y + HR.TopInset - 4), Size = UDim2.fromOffset(d, d), BackgroundColor3 = K.Edge, BorderSizePixel = 0, Visible = false })
		H.corner(ring, UDim.new(0.5, 0))
		H.stroke(ring, K.Rim, 1, 0.3)
		local face = H.make("ImageLabel", ring, { Name = "Face", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundColor3 = Color3.fromRGB(60, 60, 64), BorderSizePixel = 0, ZIndex = 2 })
		H.corner(face, UDim.new(0.5, 0))
		local track = H.make("Frame", ring, { Name = "BarTrack", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.fromOffset(d * 0.62, 4), BackgroundColor3 = K.Edge, BorderSizePixel = 0, ZIndex = 4 })
		H.corner(track, 2)
		local fill = H.make("Frame", track, { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.Bar, BorderSizePixel = 0, ZIndex = 5 })
		H.corner(fill, 2)
		local slot = H.make("Frame", ring, { Name = "SlotDot", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 1, 0, 1), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = K.Muted, BorderSizePixel = 0, ZIndex = 5 })
		H.corner(slot, UDim.new(0.5, 0))
		H.stroke(slot, K.Edge, 1.5, 0)
		-- directive 5e card info kept as two tiny pips: heavy loot (square, top-left) and kart status (dot, bottom-left)
		local heavy = H.make("Frame", ring, { Name = "Heavy", Position = UDim2.fromOffset(-1, 1), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = K.Ink, BorderSizePixel = 0, ZIndex = 5, Visible = false })
		H.stroke(heavy, K.Edge, 1.5, 0)
		local kart = H.make("Frame", ring, { Name = "KartDot", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, -1, 1, -6), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = K.Muted, BorderSizePixel = 0, ZIndex = 5 })
		H.corner(kart, UDim.new(0.5, 0))
		H.stroke(kart, K.Edge, 1.5, 0)
		local name = label(ring, "", 8, { Name = "Name", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 1), Size = UDim2.fromOffset(s.step, 10), TextColor3 = K.Muted,
			TextTruncate = Enum.TextTruncate.AtEnd, Visible = HR.ShowNames ~= false })
		v.portraits[i] = { frame = ring, face = face, fill = fill, slot = slot, name = name, heavy = heavy, kart = kart }
	end

	-- ---- top-right: health + weapon ----
	local hp = HR.Health
	local health = plate(root, { Name = "Health", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, hp.y), Size = UDim2.fromOffset(hp.w, hp.h) }, 7)
	v.health = health
	local track = H.make("Frame", health, { Position = UDim2.fromOffset(7, 7), Size = UDim2.new(1, -44, 1, -14), BackgroundColor3 = K.Edge, BorderSizePixel = 0, ZIndex = 2 })
	H.corner(track, 3)
	v.hpFill = H.make("Frame", track, { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.Bar, BorderSizePixel = 0, ZIndex = 3 })
	H.corner(v.hpFill, 3)
	v.hpText = label(health, "100", 14, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(32, 18), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 })
	local am = HR.Ammo
	local ammo = plate(root, { Name = "Ammo", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, am.y), Size = UDim2.fromOffset(am.w, am.h) }, 7)
	v.ammo = ammo
	v.gunIcon = H.make("ImageLabel", ammo, { Name = "GunIcon", BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(40, am.h - 6), ScaleType = Enum.ScaleType.Fit, ImageColor3 = K.Ink, ZIndex = 3 })
	v.gunName = label(ammo, "", 8, { Name = "GunName", Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(44, am.h - 6), TextColor3 = K.Muted, TextWrapped = true, ZIndex = 3 })
	v.mag = label(ammo, "30", 20, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -38, 0.5, 0), Size = UDim2.fromOffset(34, 22), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 })
	H.make("Frame", ammo, { Position = UDim2.new(1, -34, 0.5, -7), Size = UDim2.fromOffset(1, 14), BackgroundColor3 = K.Rim, BorderSizePixel = 0, ZIndex = 3 })
	v.reserve = label(ammo, "30", 11, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(26, 14), TextColor3 = K.Muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	local reload = H.make("Frame", ammo, { Name = "Reload", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -2), Size = UDim2.new(1, -12, 0, 2), BackgroundColor3 = K.Edge, BorderSizePixel = 0, ZIndex = 3, Visible = false })
	v.reloadFill = H.make("Frame", reload, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = K.Bar, BorderSizePixel = 0, ZIndex = 4 })
	v.reloadBar = reload

	-- ---- bottom-left: move stick (visual; Roblox's own thumbstick does the moving) ----
	local st = HR.Stick
	local outer = plate(root, { Name = "Stick", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, st.x, 1, -st.y), Size = UDim2.fromOffset(st.outer, st.outer) }, UDim.new(0.5, 0))
	local thumb = H.make("Frame", outer, { Name = "Thumb", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(st.thumb, st.thumb), BackgroundColor3 = Color3.fromRGB(122, 122, 126), ZIndex = 3 })
	H.corner(thumb, UDim.new(0.5, 0))
	H.stroke(thumb, K.Edge, 2, 0)
	H.make("UIGradient", thumb, { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 150, 154), Color3.fromRGB(96, 96, 100)) })
	v.stick = { outer = outer, thumb = thumb }
	function v.stick.set(vec: Vector2) -- -1..1 on each axis (screen space: +Y down)
		local r = (st.outer - st.thumb) / 2 - 3
		local len = math.min(vec.Magnitude, 1)
		local dir = vec.Magnitude > 0 and vec.Unit or Vector2.zero
		thumb.Position = UDim2.new(0.5, dir.X * len * r, 0.5, dir.Y * len * r)
	end
	table.insert(v.touchOnly, outer)
	local controls
	local function moveVector()
		if controls == nil then
			local ok, pm = pcall(function()
				return require(Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule", 5)):GetControls()
			end)
			controls = ok and pm or false
		end
		return controls and controls:GetMoveVector() or Vector3.zero
	end
	v.stickConn = RunService.RenderStepped:Connect(function()
		if outer.Visible then
			local mv = moveVector()
			v.stick.set(Vector2.new(mv.X, mv.Z))
		end
	end)

	-- ---- bottom-centre dock ----
	local dock = { "inventory", "menu", "map" }
	local dtext = { inventory = "BAG", menu = "MENU", map = "MAP" }
	for i, id in ipairs(dock) do
		local b = HudV2.round(H, K, root, id, dtext[id], HR.Dock.d, UDim2.new(0.5, (i - 2) * HR.Dock.step, 1, -(HR.Dock.y + HR.Dock.d / 2)), HR.Icons[id])
		b.BackgroundTransparency = 0.25
		if HR.DockSoon[id] then
			b.BackgroundTransparency, b.TextTransparency = 0.55, 0.55
			b:SetAttribute("Soon", true)
		end
		v.buttons[id] = b
	end
	v.buttons.menu.Activated:Connect(function()
		ctx.emit("toggleSettings")
	end)
	for id in pairs(HR.DockSoon) do
		v.buttons[id].Activated:Connect(function()
			H.toast("Coming soon", 1.5)
		end)
	end

	-- ---- setters ----
	function v.setHealth(hpNow: number, max: number)
		local f = math.clamp(hpNow / math.max(max, 1), 0, 1)
		v.hpFill.Size = UDim2.fromScale(f, 1)
		v.hpFill.BackgroundColor3 = f <= 0.25 and K.Low or K.Bar
		v.hpText.Text = tostring(math.ceil(hpNow))
	end
	-- mag = rounds loaded, cap = magazine size (no reserve-ammo system: the right number is the capacity)
	function v.setAmmo(mag: number?, cap: number?, reloading: boolean?)
		v.mag.Text = reloading and "--" or tostring(mag or 0)
		v.reserve.Text = tostring(cap or 0)
		v.mag.TextColor3 = (not reloading and mag and cap and mag <= math.ceil(cap * 0.25)) and K.Low or K.Ink
	end
	function v.setReload(frac: number?)
		reload.Visible = frac ~= nil
		if frac then
			v.reloadFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		end
	end
	function v.setGun(name: string?, icon: string?)
		local has = icon ~= nil and icon ~= ""
		v.gunIcon.Image = has and icon or ""
		v.gunIcon.Visible = has
		v.gunName.Text = has and "" or (name or "")
	end
	-- list: { { userId, name, hp = 0..1, slot = Color3, downed, bleed = 0..1, heavy = 0 none | 1 carrying | 2 loaded, kart = Color3 } }
	function v.setSquad(list)
		for i, p in ipairs(v.portraits) do
			local e = list[i]
			p.frame.Visible = e ~= nil
			if e then
				local image = e.userId and e.userId > 0 and string.format(THUMB, e.userId) or ""
				if p.face.Image ~= image then
					p.face.Image = image
				end
				p.face.ImageColor3 = e.downed and Color3.fromRGB(110, 110, 114) or Color3.new(1, 1, 1)
				p.fill.Size = UDim2.fromScale(math.clamp(e.downed and (e.bleed or 0) or e.hp or 1, 0, 1), 1)
				p.fill.BackgroundColor3 = e.downed and K.Low or K.Bar
				p.slot.BackgroundColor3 = e.slot or K.Muted
				p.name.Text = e.name or ""
				p.heavy.Visible = (e.heavy or 0) > 0
				p.heavy.BackgroundTransparency = e.heavy == 2 and 0 or 0.5
				p.kart.BackgroundColor3 = e.kart or K.Muted
			end
		end
	end
	-- steps: { { text, state = "done" | "active" | "todo" } }; the active step is white, the rest muted.
	function v.setObjective(title: string, steps)
		v.objTitle.Text = string.upper(title or "")
		local count = math.min(#steps, #v.rows)
		for i, r in ipairs(v.rows) do
			local step = steps[i]
			r.dot.Visible, r.text.Visible = step ~= nil, step ~= nil
			if step then
				r.text.Text = step.text
				local active = step.state == "active"
				r.text.TextColor3 = active and K.Ink or K.Muted
				r.dot.BackgroundColor3 = active and K.Ink or K.Muted
				r.dot.Size = UDim2.fromOffset(active and 7 or 6, active and 7 or 6)
				r.ring.Transparency = active and 0.2 or 1
			end
		end
		obj.Size = UDim2.fromOffset(HR.Objective.w + 14, 22 + count * 12 + 2)
	end
	function v.setTouchVisible(on: boolean)
		for _, g in ipairs(v.touchOnly) do
			g.Visible = on
		end
	end
	-- Controls' touch buttons, restyled matte (Controls still places, sizes, shows and edits them).
	function v.adopt(buttons)
		for _, b in pairs(buttons) do
			HudV2.matte(H, K, b)
		end
	end

	-- Dock touch targets stay >= MinTouchPx physical pixels at every HUD scale (HudScale.touchSize).
	function v.rescale(S: number)
		local d = HudScale.touchSize(HR.Dock.d, S, 1)
		local step = math.max(HR.Dock.step, d + 4)
		for i, id in ipairs(dock) do
			v.buttons[id].Size = UDim2.fromOffset(d, d)
			v.buttons[id].Position = UDim2.new(0.5, (i - 2) * step, 1, -(HR.Dock.y + d / 2))
		end
	end
	if ctx.on then
		ctx.on("rescale", v.rescale)
	end
	if H.S then
		v.rescale(H.S)
	end
	v.setHealth(100, 100)
	v.setObjective("", {})
	return v
end

return HudV2
