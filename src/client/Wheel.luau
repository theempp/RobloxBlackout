-- Radial weapon wheel UI: 5 fixed slots (2 left, 2 right, 1 top). Open by holding the weapon icon /
-- Tab / gamepad Y; slide (or mouse, or right stick) toward a slot and release to equip. Slots 4-5 are
-- faded "Coming Soon" teasers. Selection math lives in shared WheelLogic.
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Wheel = { open = false, selected = nil }
local ctx, C, Hud, WheelLogic
local slots = {}
local overlay, hubName, hubInfo
local padStick = Vector2.zero

local function highlight(index)
	Wheel.selected = index
	for i, b in ipairs(slots) do
		local on = i == index
		b.BackgroundTransparency = on and 0.05 or 0.35
		b:FindFirstChildOfClass("UIStroke").Color = on and C.Colors.Accent or C.Colors.Text
	end
	local def = index and C.Wheel.Slots[index]
	if not def then
		hubName.Text, hubInfo.Text = "", "Slide to a blaster"
	elseif not def.usable then
		hubName.Text, hubInfo.Text = "COMING SOON", def.teaser or ""
	else
		local g = C.GunsById[ctx.GunClient.loadout()[index] or ""]
		hubName.Text = g and g.name or "EMPTY"
		hubInfo.Text = g and (g.class .. " · " .. g.damage .. " dmg · " .. g.rpm .. " rpm · " .. g.mag .. " mag") or "Pick one at the rack"
	end
end

local function refresh()
	local lo = ctx.GunClient.loadout()
	for i, b in ipairs(slots) do
		local def = C.Wheel.Slots[i]
		local g = def.usable and C.GunsById[lo[i] or ""]
		b.Text = def.usable and (g and g.name:upper() or "EMPTY") or "COMING\nSOON"
		b.TextTransparency = def.usable and 0 or 0.45
		b.BackgroundTransparency = def.usable and 0.35 or 0.7
	end
end

function Wheel.show()
	if Wheel.open then
		return
	end
	Wheel.open = true
	ctx.cursorFree = ctx.inputKind == "Keyboard"
	refresh()
	highlight(nil)
	overlay.Visible = true
end

function Wheel.release()
	if not Wheel.open then
		return
	end
	Wheel.open = false
	overlay.Visible = false
	ctx.cursorFree = false
	if Wheel.selected then
		ctx.GunClient.equip(Wheel.selected)
	end
end

function Wheel.init(c)
	ctx = c
	C = ctx.Config
	Hud = ctx.Hud
	WheelLogic = require(ctx.shared.WheelLogic)
	overlay = Hud.make("Frame", Hud.gui, { Name = "WeaponWheel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55, Visible = false, ZIndex = 30 })
	local ring = Hud.make("Frame", overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1, ZIndex = 30 })
	Hud.make("UIScale", ring, { Scale = 1 })
	ctx.on("rescale", function(S)
		ring:FindFirstChildOfClass("UIScale").Scale = S
	end)
	local hub = Hud.make("Frame", ring, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = C.Colors.Panel, BackgroundTransparency = 0.1, ZIndex = 31 })
	Hud.corner(hub, UDim.new(0.5, 0))
	hubName = Hud.label(hub, "", 14, { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 34), ZIndex = 32, Font = Enum.Font.GothamBlack })
	hubInfo = Hud.label(hub, "", 10, { Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 56), ZIndex = 32, TextWrapped = true, TextColor3 = C.Colors.Muted })
	for i, def in ipairs(C.Wheel.Slots) do
		local a = math.rad(def.angle)
		local b = Hud.button(ring, "Slot" .. i, "", 72, { Position = UDim2.new(0.5, math.cos(a) * C.Wheel.Radius, 0.5, math.sin(a) * C.Wheel.Radius), ZIndex = 31, TextSize = 11, TextWrapped = true })
		b.Activated:Connect(function() -- direct tap while open
			highlight(i)
			Wheel.release()
		end)
		b.MouseEnter:Connect(function()
			if Wheel.open then
				highlight(i)
			end
		end)
		slots[i] = b
	end
	ctx.on("wheelOpen", Wheel.show)
	ctx.on("wheelRelease", Wheel.release)
	ctx.on("wheelDrag", function(d)
		if Wheel.open then
			highlight(WheelLogic.pick(d.X, d.Y))
		end
	end)
	ctx.on("loadout", refresh)
	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			padStick = Vector2.new(input.Position.X, -input.Position.Y)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not Wheel.open then
			return
		end
		if ctx.inputKind == "Keyboard" then
			local m = UserInputService:GetMouseLocation()
			local centre = ring.AbsolutePosition + ring.AbsoluteSize / 2
			local d = m - centre - Vector2.new(0, 36) -- GetMouseLocation includes the top bar inset
			highlight(WheelLogic.pick(d.X, d.Y))
		elseif ctx.inputKind == "Gamepad" and padStick.Magnitude > 0.4 then
			highlight(WheelLogic.pick(padStick.X * 100, padStick.Y * 100))
		end
	end)
end

return Wheel
