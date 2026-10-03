-- Input -> intents (ctx.emit). Touch (§5f): left stick = Roblox thumbstick; right-half drag aims (CameraRig);
-- big Fire bottom-right (drag from it also aims); ADS above-left of Fire; Reload; Jump (replaces the default
-- jump button spot); weapon icon: tap = swap to last-used, hold = radial wheel; optional mirrored Fire on
-- the left edge. Every button is movable/resizable (settings.layout). Keyboard/mouse + gamepad fallback.
-- Holds follow the touch's own End/Cancel (MouseButton1Up never fires if the thumb slides off).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Controls = { buttons = {}, editing = false, selected = nil, contextShown = {} }
local ctx, C, Hud, HudScale
local lp = Players.LocalPlayer

local function touchMode()
	return UserInputService.TouchEnabled or C.Touch.ForceShow or workspace:GetAttribute("BCTesting") == true
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- Calls onEnd when this specific touch ends or is cancelled.
local function follow(input, onEnd)
	local conn
	conn = input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
			conn:Disconnect()
			onEnd(input)
		end
	end)
end

-- Default centre (fraction of the HUD root) and size of a button. In the heist the HUD v2 cluster sets them
-- (Config.Touch ref -> HudRef.Buttons, offsets from the bottom-right corner); a saved layout overrides both.
local function home(id)
	local def = C.Touch.Buttons[id]
	local ref = ctx.role == "heist" and def.ref and C.HudRef.Buttons[def.ref]
	if ref and Hud.W then
		return 1 - ref.x / Hud.W, 1 - ref.y / Hud.H, ref.d
	end
	return def.x, def.y, def.size
end
Controls.home = home

function Controls.layout()
	local S = Hud.S or 1
	local layout = ctx.settings.layout or {}
	-- Touch buttons only while the player is actually using touch (tests/ForceShow force them on).
	local show = (touchMode() and ctx.inputKind == "Touch") or C.Touch.ForceShow or workspace:GetAttribute("BCTesting") == true
	for id, b in pairs(Controls.buttons) do
		local def = C.Touch.Buttons[id]
		local e = layout[id]
		local hx, hy, base = home(id)
		local x, y, u = e and e.x or hx, e and e.y or hy, e and e.s or 1
		local size = HudScale.touchSize(base, S, u)
		b.Size = UDim2.fromOffset(size, size)
		b.Position = UDim2.fromOffset(x * Hud.W, y * Hud.H)
		b.TextSize = math.max(11, math.floor(size * 0.22))
		local vis = show and (not def.optional or ctx.settings.mirrorFire or Controls.editing)
		if def.heist and ctx.role ~= "heist" then
			vis = false
		elseif (def.driving == true) ~= (ctx.driving == true) then
			vis = false -- kart buttons only in a kart, on-foot buttons only on foot (also while editing)
		elseif def.context and not Controls.contextShown[id] and not Controls.editing then
			vis = false -- context button only with something in reach
		elseif ctx.Menus and ctx.Menus.current and ctx.Menus.current ~= "wheel" then
			vis = false -- a menu is open: firing/actions are suppressed, so their buttons step aside
		end
		b.Visible = vis
	end
end

-- Show/hide a context button (heist action) without relaying out everything else.
function Controls.setContext(id, on, label)
	local b = Controls.buttons[id]
	if b and label then
		b.Text = label
	end
	if (Controls.contextShown[id] == true) ~= (on == true) then
		Controls.contextShown[id] = on == true
		Controls.layout()
	end
end

local function hideDefaultJump()
	local function hook(d)
		if d.Name == "JumpButton" and d:IsA("GuiObject") then
			d.Visible = false
			d:GetPropertyChangedSignal("Visible"):Connect(function()
				if d.Visible then
					d.Visible = false
				end
			end)
		end
	end
	local pg = lp:WaitForChild("PlayerGui")
	for _, d in ipairs(pg:GetDescendants()) do
		hook(d)
	end
	pg.DescendantAdded:Connect(hook)
end

local function jump(on)
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Jump = on
	end
end

-- Edit mode: drag a button to move it; the edit bar resizes the selected one.
local function editDrag(b, id, input)
	Controls.selected = id
	Controls.editLabel.Text = "Selected: " .. C.Touch.Buttons[id].label
	local root = Hud.root.AbsolutePosition
	local function place(pos)
		local hx, hy = home(id)
		local e = ctx.settings.layout[id] or { x = hx, y = hy, s = 1 }
		e.x = math.clamp((pos.X - root.X) / Hud.S / Hud.W, 0.02, 0.98)
		e.y = math.clamp((pos.Y - root.Y) / Hud.S / Hud.H, 0.02, 0.98)
		ctx.settings.layout[id] = e
		Controls.layout()
	end
	local conn = input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.Change then
			place(input.Position)
		end
	end)
	follow(input, function()
		conn:Disconnect()
	end)
end

function Controls.setEditing(on)
	Controls.editing = on
	Controls.editBar.Visible = on
	ctx.cursorFree = on
	for _, b in pairs(Controls.buttons) do
		b:FindFirstChildOfClass("UIStroke").Color = on and C.Colors.Accent or (b:GetAttribute("RestStroke") or C.UI.Ink)
	end
	Controls.layout()
	if not on then
		ctx.saveSettings()
	end
end

local function resize(delta)
	local id = Controls.selected
	if not id then
		return
	end
	local hx, hy = home(id)
	local e = ctx.settings.layout[id] or { x = hx, y = hy, s = 1 }
	e.s = math.clamp(e.s + delta, C.Touch.UserScale[1], C.Touch.UserScale[2])
	ctx.settings.layout[id] = e
	Controls.layout()
end

local function makeButtons()
	local B = Controls.buttons
	for id, def in pairs(C.Touch.Buttons) do
		B[id] = Hud.button(Hud.root, "Touch_" .. id, def.label, def.size)
	end
	local function press(id, onDown, onUp)
		B[id].InputBegan:Connect(function(input)
			if not isPress(input) then
				return
			end
			if Controls.editing then
				editDrag(B[id], id, input)
				return
			end
			onDown(input)
			follow(input, function(i)
				if onUp then
					onUp(i)
				end
			end)
		end)
	end
	local function fireDown(input)
		ctx.emit("fire", true)
		if C.Touch.FireDragAims and input.UserInputType == Enum.UserInputType.Touch then
			ctx.CameraRig.adoptTouch(input)
		end
	end
	local function fireUp(input)
		ctx.emit("fire", false)
		ctx.CameraRig.releaseTouch(input)
	end
	Controls.press = press
	press("fire", fireDown, fireUp)
	press("fireLeft", fireDown, fireUp)
	press("ads", function()
		ctx.emit("adsToggle")
	end)
	press("reload", function()
		ctx.emit("reload")
	end)
	press("jump", function()
		jump(true)
	end, function()
		jump(false)
	end)
	-- Weapon icon: tap = swap last; hold = radial; slide + release to equip.
	press("weapon", function(input)
		local start, t0, opened = input.Position, os.clock(), false
		local conn = input.Changed:Connect(function()
			if opened and input.UserInputState == Enum.UserInputState.Change then
				local d = input.Position - start
				ctx.emit("wheelDrag", Vector2.new(d.X, d.Y))
			end
		end)
		task.delay(C.Wheel.HoldTime, function()
			if input.UserInputState ~= Enum.UserInputState.End and input.UserInputState ~= Enum.UserInputState.Cancel then
				opened = true
				ctx.emit("wheelOpen")
			end
		end)
		follow(input, function()
			conn:Disconnect()
			if opened then
				ctx.emit("wheelRelease")
			elseif os.clock() - t0 < C.Wheel.HoldTime then
				ctx.emit("swapLast")
			end
		end)
	end)
end

local function makeEditBar()
	local bar = Hud.make("Frame", Hud.root, { Name = "EditBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(390, 60), BackgroundColor3 = C.Colors.Panel, BackgroundTransparency = 0.2, Visible = false, ZIndex = 20 })
	Hud.surface(bar)
	Controls.editLabel = Hud.label(bar, "Drag a button", 13, { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(130, 60), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 })
	local function small(text, x, fn)
		local b = Hud.button(bar, "Edit_" .. text, text, 52, { Position = UDim2.fromOffset(x, 30), ZIndex = 21 }) -- 52 units >= 44px at min scale
		b.Activated:Connect(fn)
	end
	small("-", 172, function()
		resize(-0.1)
	end)
	small("+", 228, function()
		resize(0.1)
	end)
	small("OK", 340, function()
		Controls.setEditing(false)
	end)
	small("RST", 284, function()
		ctx.settings.layout = {}
		Controls.layout()
	end)
	Controls.editBar = bar
end

local function bindKeys()
	local K = C.Keys
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		local t, k = input.UserInputType, input.KeyCode
		if t == K.Fire or k == K.PadFire then
			if not ctx.cursorFree then
				ctx.emit("fire", true)
			end
		elseif t == K.Ads or k == K.PadAds then
			ctx.emit("ads", true)
		elseif k == K.Reload or k == K.PadReload then
			ctx.emit("reload")
		elseif k == K.SwapLast then
			ctx.emit("swapLast")
		elseif k == K.Wheel then
			ctx.emit("wheelOpen")
		elseif k == K.PadSwap then
			local t0 = os.clock()
			task.delay(C.Wheel.HoldTime, function()
				if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, K.PadSwap) then
					ctx.emit("wheelOpen")
				end
			end)
			Controls.padSwapAt = t0
		elseif k == K.PerfOverlay then
			ctx.emit("togglePerf")
		elseif k == K.Settings then
			ctx.emit("toggleSettings")
		else
			for i, key in ipairs(K.Slots) do
				if k == key then
					ctx.emit("equip", i)
				end
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == K.Action or input.KeyCode == K.PadAction then
			ctx.emit("actionPress", true)
		elseif input.KeyCode == K.Sneak or input.KeyCode == K.PadSneak then
			ctx.emit("sneakToggle")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == K.Action or input.KeyCode == K.PadAction then
			ctx.emit("actionPress", false)
		end
		local t, k = input.UserInputType, input.KeyCode
		if t == K.Fire or k == K.PadFire then
			ctx.emit("fire", false)
		elseif t == K.Ads or k == K.PadAds then
			ctx.emit("ads", false)
		elseif k == K.Wheel then
			ctx.emit("wheelRelease")
		elseif k == K.PadSwap then
			if os.clock() - (Controls.padSwapAt or 0) < C.Wheel.HoldTime then
				ctx.emit("swapLast")
			else
				ctx.emit("wheelRelease")
			end
		end
	end)
end

function Controls.init(c)
	ctx = c
	C = ctx.Config
	Hud = ctx.Hud
	HudScale = require(ctx.shared.HudScale)
	makeButtons()
	makeEditBar()
	bindKeys()
	task.spawn(hideDefaultJump)
	ctx.on("rescale", Controls.layout)
	ctx.on("settings", Controls.layout)
	ctx.on("inputKind", Controls.layout)
	ctx.on("menu", Controls.layout)
	ctx.on("editLayout", function()
		Controls.setEditing(true)
	end)
	Controls.layout()
end

return Controls
