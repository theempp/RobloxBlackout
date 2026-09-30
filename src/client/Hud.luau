-- HUD root + helpers (ported from roblox 1: make/corner/stroke/pad, rescale S, CoreUISafeInsets),
-- crosshair, hit marker, ammo, toast. One per-frame loop animates everything (no tweens allocated).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Hud = {}
local ctx, C, HudScale
local markerT, markerColor, toastT = 0, nil, 0

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
	local l = Hud.make("TextLabel", parent, { BackgroundTransparency = 1, Text = text, TextSize = size, Font = Enum.Font.GothamBold, TextColor3 = C.Colors.Text })
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end
-- Round button used by touch controls, wheel and menus. TouchTarget marks it for the 44px UI probe.
function Hud.button(parent, name, text, size, props)
	local b = Hud.make("TextButton", parent, { Name = name, Text = text, TextSize = 14, Font = Enum.Font.GothamBlack, TextColor3 = C.Colors.Text,
		AutoButtonColor = false, BackgroundColor3 = C.Colors.Panel, BackgroundTransparency = 0.35, Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5) })
	Hud.corner(b, UDim.new(0.5, 0))
	Hud.stroke(b, C.Colors.Text, 2, 0.6)
	b:SetAttribute("TouchTarget", true)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	return b
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

function Hud.toast(text, seconds)
	Hud.toastLabel.Text = text
	toastT = seconds or 2
end

function Hud.setAmmo(ammo, mag, reloading)
	Hud.ammoLabel.Text = reloading and "RELOADING" or (tostring(ammo) .. " / " .. tostring(mag))
	Hud.ammoLabel.TextColor3 = (not reloading and ammo <= math.ceil(mag * 0.25)) and C.Colors.Kill or C.Colors.Text
end

function Hud.setGun(name)
	Hud.gunLabel.Text = name
end

function Hud.setReload(frac)
	Hud.reloadBar.Visible = frac ~= nil
	if frac then
		Hud.reloadFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	end
end

function Hud.setCrosshair(visible, gapPx)
	Hud.cross.Visible = visible
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
	Hud.ammoPanel = panel
	Hud.ammoLabel = Hud.label(panel, "", 22, { Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBlack })
	Hud.gunLabel = Hud.label(panel, "", 13, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Colors.Muted })
	Hud.reloadBar = Hud.make("Frame", panel, { Position = UDim2.new(0, 70, 0, 44), Size = UDim2.new(1, -70, 0, 4), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0, Visible = false })
	Hud.reloadFill = Hud.make("Frame", Hud.reloadBar, { BackgroundColor3 = C.Colors.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) })

	Hud.toastLabel = Hud.label(Hud.root, "", 16, { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(420, 24), TextTransparency = 1, TextStrokeTransparency = 1 })

	gui.Parent = lp:WaitForChild("PlayerGui")
	ctx.on("rescale", function()
		panel.Position = UDim2.fromOffset(Hud.W - 10, 6)
		Hud.toastLabel.Position = UDim2.fromOffset(Hud.W / 2, 56)
	end)
	ctx.on("settings", rescale)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	rescale()

	RunService.RenderStepped:Connect(function(dt)
		if markerT > 0 then
			markerT -= dt
			marker.Visible = markerT > 0
		end
		if toastT > 0 then
			toastT -= dt
			local a = toastT < 0.4 and 1 - toastT / 0.4 or 0
			Hud.toastLabel.TextTransparency = a
			Hud.toastLabel.TextStrokeTransparency = 0.5 + a * 0.5
		end
	end)
end

return Hud
