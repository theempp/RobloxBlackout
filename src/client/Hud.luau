-- HUD root + helpers (ported from roblox 1: make/corner/stroke/pad, rescale S, CoreUISafeInsets),
-- crosshair, hit marker, ammo, toast, ELIMINATED tag, full-viewport scope reticle. One per-frame loop animates
-- everything (no tweens allocated).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Hud = {}
local ctx, C, HudScale
local markerT, markerColor, toastT = 0, nil, 0
local elimT = 0
Hud.elimShown = 0

function Hud.make(kind, parent, props)
	local x = Instance.new(kind)
	for k, v in pairs(props or {}) do
		x[k] = v
	end
	x.Parent = parent
	return x
end
function Hud.corner(x, r)
	return Hud.make("UICorner", x, { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 12) })
end
function Hud.stroke(x, c, t, tr)
	return Hud.make("UIStroke", x, { Color = c or Color3.new(0, 0, 0), Thickness = t or 2, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
function Hud.pad(x, n)
	return Hud.make("UIPadding", x, { PaddingLeft = UDim.new(0, n), PaddingRight = UDim.new(0, n), PaddingTop = UDim.new(0, n), PaddingBottom = UDim.new(0, n) })
end
function Hud.label(parent, text, size, props)
	local l = Hud.make("TextLabel", parent, { BackgroundTransparency = 1, Text = text, TextSize = size, Font = Enum.Font.GothamBold, TextColor3 = C.UI.Ink })
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end
-- Round button used by touch controls, wheel and menus. TouchTarget marks it for the 44px UI probe.
function Hud.button(parent, name, text, size, props)
	local b = Hud.make("TextButton", parent, { Name = name, Text = text, TextSize = 14, Font = Enum.Font.GothamBlack, TextColor3 = C.UI.Ink,
		AutoButtonColor = false, BackgroundColor3 = C.UI.Blue, BackgroundTransparency = 0, Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5) })
	Hud.corner(b, UDim.new(0.5, 0))
	Hud.stroke(b, C.UI.Ink, C.UI.Outline, 0)
	b:SetAttribute("TouchTarget", true)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	return b
end

-- Rounded-rectangle menu button (>= 52 design units = 44 physical px at the minimum HUD scale).
function Hud.pill(parent, name, text, w, h, color, props)
	local b = Hud.make("TextButton", parent, { Name = name, Text = text, TextSize = 13, Font = Enum.Font.GothamBlack, TextColor3 = C.UI.Ink,
		AutoButtonColor = true, BackgroundColor3 = color or C.UI.Blue, Size = UDim2.fromOffset(w, h), TextWrapped = true, Selectable = true })
	Hud.corner(b, 12)
	Hud.stroke(b, C.UI.Ink, 2, 0)
	b:SetAttribute("TouchTarget", true)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	return b
end

-- Shared paper panel treatment; compact chips retain the small phone HUD footprint.
function Hud.surface(panel, compact)
	panel.BackgroundColor3, panel.BackgroundTransparency, panel.BorderSizePixel = C.UI.Paper, 0, 0
	local corner = panel:FindFirstChildOfClass("UICorner")
	if corner then corner.CornerRadius = UDim.new(0, compact and 8 or 16) else Hud.corner(panel, compact and 8 or 16) end
	local stroke = panel:FindFirstChildOfClass("UIStroke") or Hud.stroke(panel)
	stroke.Color, stroke.Thickness, stroke.Transparency = C.UI.Ink, compact and 2 or C.UI.Outline, 0
end

local function rescale()
	local v = Hud.gui.AbsoluteSize
	if v.X < 10 then
		return
	end
	Hud.S = HudScale.scale(v.X, v.Y, ctx.settings.largeHud)
	Hud.W, Hud.H = v.X / Hud.S, v.Y / Hud.S
	Hud.scale.Scale = Hud.S
	Hud.root.Size = UDim2.fromScale(1 / Hud.S, 1 / Hud.S)
	ctx.emit("rescale", Hud.S)
end

function Hud.hitMarker(kind)
	markerT = kind == "predict" and 0.08 or 0.16
	markerColor = C.Colors[kind == "kill" and "Kill" or kind == "head" and "Head" or kind == "predict" and "Predict" or "Hit"]
	for _, t in ipairs(Hud.marker:GetChildren()) do
		t.BackgroundColor3 = markerColor
	end
end

-- Server-confirmed defeat (GunClient dedupes by defeat id before calling). Sits below-right of the reticle.
function Hud.eliminated()
	elimT = C.HitFx.ElimTime
	Hud.elimShown += 1
	Hud.elim.Visible = true
end

-- Full-viewport scope: reticle lines across the whole play view + light corner shading; behind the controls.
local function buildScope(lp)
	local SC = C.Scope
	local g = Hud.make("ScreenGui", nil, { Name = "BlackoutCrewScope", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = -1, Enabled = false })
	local function bar(props)
		props.BorderSizePixel = 0
		props.BackgroundColor3 = SC.LineColor
		return Hud.make("Frame", g, props)
	end
	local t, gap = SC.LineThickness, SC.CenterGap
	bar({ Name = "L", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0.5, -gap, 0, t) })
	bar({ Name = "R", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.5, -gap, 0, t) })
	bar({ Name = "T", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, t, 0.5, -gap) })
	bar({ Name = "B", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(0, t, 0.5, -gap) })
	local post = 0.5 * (1 - SC.ThickFrom)
	bar({ Name = "PL", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(post, 0, 0, t * 3) })
	bar({ Name = "PR", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(post, 0, 0, t * 3) })
	bar({ Name = "PB", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(0, t * 3, post, 0) })
	local dot = bar({ Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(SC.Dot, SC.Dot) })
	Hud.corner(dot, SC.Dot)
	for _, e in ipairs({ { "ShadeT", Vector2.new(0, 0), UDim2.fromScale(1, 0.14), 90 }, { "ShadeB", Vector2.new(0, 1), UDim2.fromScale(1, 0.14), -90 },
		{ "ShadeL", Vector2.new(0, 0), UDim2.fromScale(0.1, 1), 0 }, { "ShadeR", Vector2.new(1, 0), UDim2.fromScale(0.1, 1), 180 } }) do
		local f = Hud.make("Frame", g, { Name = e[1], BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = e[2],
			Position = UDim2.fromScale(e[2].X, e[2].Y), Size = e[3], ZIndex = 0 })
		Hud.make("UIGradient", f, { Rotation = e[4], Transparency = NumberSequence.new(SC.EdgeShade, 1) })
	end
	g.Parent = lp:WaitForChild("PlayerGui")
	return g
end

function Hud.toast(text, seconds)
	Hud.toastLabel.Text = text
	toastT = seconds or 2
end

-- Heist: HUD v2 owns the ammo/weapon plate (HeistHud calls this once); the old panel retires.
function Hud.useV2(v)
	Hud.v2 = v
	Hud.ammoPanel.Visible = false
	v.setAmmo(Hud.last and Hud.last[1], Hud.last and Hud.last[2], Hud.last and Hud.last[3])
	v.setGun(Hud.gunLabel.Text)
end

function Hud.setAmmo(ammo, mag, reloading)
	Hud.last = { ammo, mag, reloading }
	if Hud.v2 then
		Hud.v2.setAmmo(ammo, mag, reloading)
	end
	Hud.ammoLabel.Text = reloading and "RELOADING" or (tostring(ammo) .. " / " .. tostring(mag))
	Hud.ammoLabel.TextColor3 = (not reloading and ammo <= math.ceil(mag * 0.25)) and C.Colors.Kill or C.UI.Ink
end

function Hud.setGun(name)
	Hud.gunLabel.Text = name
	if Hud.v2 then
		Hud.v2.setGun(name)
	end
end

function Hud.setReload(frac)
	if Hud.v2 then
		Hud.v2.setReload(frac)
	end
	Hud.reloadBar.Visible = frac ~= nil
	if frac then
		Hud.reloadFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	end
end

local crossWanted = true
function Hud.setCrosshair(visible, gapPx)
	crossWanted = visible
	Hud.cross.Visible = visible and not Hud.menuOpen -- menus (locker preview, armory) hide it
	local g = gapPx or 8
	local t = Hud.cross:GetChildren()
	for _, tick in ipairs(t) do
		local d = tick:GetAttribute("Dir")
		if d then
			tick.Position = UDim2.new(0.5, d.X * g, 0.5, d.Y * g)
		end
	end
end

function Hud.init(c)
	ctx = c
	C = ctx.Config
	HudScale = require(ctx.shared.HudScale)
	local lp = Players.LocalPlayer
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	pcall(function()
		local cw = game:GetService("TextChatService").ChatWindowConfiguration
		cw.VerticalAlignment = Enum.VerticalAlignment.Bottom
		cw.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end)
	local gui = Hud.make("ScreenGui", nil, { Name = "BlackoutCrewHud", ResetOnSpawn = false, IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	Hud.gui = gui
	Hud.root = Hud.make("Frame", gui, { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	Hud.scale = Hud.make("UIScale", Hud.root)

	-- Crosshair: 4 ticks around the centre; gap reflects spread.
	local cross = Hud.make("Frame", gui, { Name = "Crosshair", BackgroundTransparency = 1, Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	for _, d in ipairs({ Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) }) do
		local tick = Hud.make("Frame", cross, { BorderSizePixel = 0, BackgroundColor3 = C.Colors.Text, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = d.X ~= 0 and UDim2.fromOffset(8, 2) or UDim2.fromOffset(2, 8) })
		tick:SetAttribute("Dir", d)
	end
	Hud.make("Frame", cross, { Name = "Dot", BorderSizePixel = 0, BackgroundColor3 = C.Colors.Text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2, 2) })
	Hud.cross = cross
	Hud.setCrosshair(true, 8)

	-- Hit marker: 4 diagonal ticks.
	local marker = Hud.make("Frame", gui, { Name = "HitMarker", BackgroundTransparency = 1, Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Visible = false })
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		Hud.make("Frame", marker, { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 2), Rotation = 45 + i * 90,
			Position = UDim2.new(0.5, math.cos(a) * 12, 0.5, math.sin(a) * 12) })
	end
	Hud.marker = marker

	-- Ammo + gun name (top right), reload bar under it.
	local panel = Hud.make("Frame", Hud.root, { Name = "Ammo", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(170, 50) })
	Hud.surface(panel, true)
	Hud.pad(panel, 5)
	Hud.ammoPanel = panel
	Hud.ammoLabel = Hud.label(panel, "", 22, { Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBlack })
	Hud.gunLabel = Hud.label(panel, "", 13, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.UI.Muted })
	Hud.reloadBar = Hud.make("Frame", panel, { Position = UDim2.new(0, 70, 0, 44), Size = UDim2.new(1, -70, 0, 4), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0, Visible = false })
	Hud.reloadFill = Hud.make("Frame", Hud.reloadBar, { BackgroundColor3 = C.Colors.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) })

	Hud.toastLabel = Hud.label(Hud.root, "", 16, { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(420, 24), TextTransparency = 1, TextStrokeTransparency = 1 })

	-- ELIMINATED: offset from the screen centre (design units) so it never covers the reticle or scope lines.
	local off = C.HitFx.ElimOffset
	Hud.elim = Hud.label(Hud.root, C.HitFx.ElimText, 20, { Name = "Eliminated", AnchorPoint = Vector2.new(0, 0), Size = UDim2.fromOffset(150, 24),
		Position = UDim2.new(0.5, off.X, 0.5, off.Y), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack,
		TextColor3 = C.HitFx.ElimColor, TextStrokeColor3 = Color3.fromRGB(20, 16, 22), TextStrokeTransparency = 0.2, Visible = false })
	Hud.elimScale = Hud.make("UIScale", Hud.elim)
	Hud.scopeGui = buildScope(lp)

	gui.Parent = lp:WaitForChild("PlayerGui")
	ctx.on("rescale", function()
		-- lobby: top-centre (the lobby HUD's currency pills own the top-right corner)
		local lobby = ctx.role == "lobby"
		panel.AnchorPoint = Vector2.new(lobby and 0.5 or 1, 0)
		panel.Position = UDim2.fromOffset(lobby and Hud.W / 2 or Hud.W - 10, 6)
		Hud.toastLabel.Position = UDim2.fromOffset(Hud.W / 2, 56)
	end)
	ctx.on("settings", rescale)
	ctx.on("menu", function(name)
		Hud.menuOpen = name ~= nil
		cross.Visible = crossWanted and not Hud.menuOpen
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	rescale()

	RunService.RenderStepped:Connect(function(dt)
		if markerT > 0 then
			markerT -= dt
			marker.Visible = markerT > 0
		end
		if elimT > 0 then
			elimT -= dt
			local life = C.HitFx.ElimTime - elimT
			Hud.elimScale.Scale = life < 0.12 and 1.25 - life / 0.12 * 0.25 or 1
			Hud.elim.TextTransparency = elimT < 0.3 and 1 - elimT / 0.3 or 0
			Hud.elim.TextStrokeTransparency = 0.2 + (elimT < 0.3 and (1 - elimT / 0.3) * 0.8 or 0)
			Hud.elim.Visible = elimT > 0
		end
		local scoped = ctx.ViewModel ~= nil and ctx.ViewModel.scoped() and not Hud.menuOpen
		if Hud.scopeGui.Enabled ~= scoped then
			Hud.scopeGui.Enabled = scoped
		end
		if toastT > 0 then
			toastT -= dt
			local a = toastT < 0.4 and 1 - toastT / 0.4 or 0
			Hud.toastLabel.TextColor3 = C.Colors.Text
			Hud.toastLabel.TextTransparency = a
			Hud.toastLabel.TextStrokeTransparency = 0.5 + a * 0.5
		end
	end)
end

return Hud
