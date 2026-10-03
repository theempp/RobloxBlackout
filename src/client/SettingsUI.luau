-- Settings panel: aim assist, perf overlay, mirrored fire, reduced motion, large HUD, SFX, sensitivities,
-- button layout editing, benchmark. Saved to the profile (server re-validates via Rules.cleanSettings).
local SettingsUI = { open = false }
local ctx, C, Hud
local panel
local rows = {}

local TOGGLES = {
	{ "aimAssist", "Aim assist (slow-down)" },
	{ "perfOverlay", "Performance overlay" },
	{ "mirrorFire", "Left-edge Fire button" },
	{ "reducedMotion", "Reduced motion" },
	{ "largeHud", "Large HUD" },
	{ "sfx", "Sound effects" },
}
local STEPS = { { "sensitivity", "Look sensitivity" }, { "adsSensitivity", "ADS sensitivity" } }

local function refresh()
	for key, r in pairs(rows) do
		local v = ctx.settings[key]
		if type(v) == "boolean" then
			r.Text = v and "ON" or "OFF"
			r.BackgroundColor3 = v and C.UI.Green or C.UI.Paper
		else
			r.Text = string.format("%.1f", v)
		end
	end
end

function SettingsUI.set(open)
	if open then
		ctx.Menus.open("settings", function()
			SettingsUI.set(false)
		end)
	end
	SettingsUI.open = open
	panel.Visible = open
	if open then
		refresh()
		ctx.Menus.focus(panel:FindFirstChild("Toggle_aimAssist", true))
	else
		ctx.saveSettings()
		ctx.Menus.closed("settings")
	end
end

local function changed()
	refresh()
	ctx.emit("settings", ctx.settings)
end

function SettingsUI.init(c)
	ctx = c
	C = ctx.Config
	Hud = ctx.Hud
	panel = Hud.make("ScrollingFrame", Hud.root, { Name = "Settings", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 300), BackgroundColor3 = C.UI.Paper, BackgroundTransparency = 0.08, Visible = false, ZIndex = 40,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6 })
	Hud.surface(panel)
	Hud.pad(panel, 12)
	Hud.make("UIListLayout", panel, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local order = 0
	local function row(text)
		order += 1
		local f = Hud.make("Frame", panel, { Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 41 })
		Hud.label(f, text, 14, { Size = UDim2.new(1, -180, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41 })
		return f
	end
	local function btn(parent, name, text, x, w)
		local b = Hud.make("TextButton", parent, { Name = name, Text = text, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.UI.Ink,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(w or 60, 52),
			BackgroundColor3 = C.UI.Blue, AutoButtonColor = true, ZIndex = 42 })
		Hud.corner(b, 10)
		Hud.stroke(b, C.UI.Ink, C.UI.Outline, 0)
		b:SetAttribute("TouchTarget", true)
		return b
	end
	for _, t in ipairs(TOGGLES) do
		local key = t[1]
		local b = btn(row(t[2]), "Toggle_" .. key, "", 0, 70)
		rows[key] = b
		b.Activated:Connect(function()
			ctx.settings[key] = not ctx.settings[key]
			changed()
		end)
	end
	for _, t in ipairs(STEPS) do
		local key = t[1]
		local f = row(t[2])
		local lo, hi = C.Settings.Numbers[key][2], C.Settings.Numbers[key][3]
		btn(f, "Dec_" .. key, "−", -120).Activated:Connect(function()
			ctx.settings[key] = math.clamp(ctx.settings[key] - 0.1, lo, hi)
			changed()
		end)
		local v = btn(f, "Val_" .. key, "", -60)
		v.AutoButtonColor = false
		rows[key] = v
		btn(f, "Inc_" .. key, "+", 0).Activated:Connect(function()
			ctx.settings[key] = math.clamp(ctx.settings[key] + 0.1, lo, hi)
			changed()
		end)
	end
	btn(row("Move / resize touch buttons"), "EditLayout", "EDIT", 0, 90).Activated:Connect(function()
		SettingsUI.set(false)
		ctx.emit("editLayout")
	end)
	btn(row("Reset button layout"), "ResetLayout", "RESET", 0, 90).Activated:Connect(function()
		ctx.settings.layout = {}
		changed()
	end)
	btn(row("15 s benchmark (hold still)"), "Benchmark", "RUN", 0, 90).Activated:Connect(function()
		SettingsUI.set(false)
		ctx.emit("benchmark")
	end)
	btn(row(""), "Close", "CLOSE", 0, 120).Activated:Connect(function()
		SettingsUI.set(false)
	end)
	-- Opened by the lobby HUD SETTINGS button, the heist HUD MENU dock button or the Settings key (no floating gear).
	ctx.on("toggleSettings", function()
		SettingsUI.set(not SettingsUI.open)
	end)
	ctx.on("settings", refresh)
end

return SettingsUI
