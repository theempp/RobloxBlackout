-- Locker room (revision stage 1). Entry: a short camera push-in while the player's locker door swings open
-- (skip with the button, a tap or any key; reduced motion = instant cut). Then the customization screen: a
-- centred live preview of the player's own character plus owned outfit / disguise / mask choices. The
-- preview is a local clone dressed by the same CosmeticKit the server uses; nothing is saved until APPLY,
-- which the server validates. A rejection or missing ack shows the saved look again. Disguises are cosmetic.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Locker = { open = false, intro = false, category = "outfit", preview = {}, busy = false, status = "", yaw = 0 }
local ctx, C, Hud, Map, Kit
local lp = Players.LocalPlayer
local panel, skipButton, viewport, previewCam, clone, framing
local door, doorCF, introInput, dragging, controls
local stick = 0
local CATS = { { "outfit", "OUTFIT", 96 }, { "disguise", "DISGUISE", 104 }, { "mask", "MASK", 84 } }
local NONE = { outfit = "OWN LOOK", disguise = "NO DISGUISE", mask = "NO MASK" }

local function cosmetics()
	return ctx.profile and ctx.profile.cosmetics
end
local function saved()
	local c = cosmetics()
	return c and c.equipped or {}
end
local function owned(id)
	local c = cosmetics()
	return c ~= nil and c.owned[id] == true
end

-- Freeze walking while the camera is parked on the locker (restored on every close path).
local function setControls(on)
	pcall(function()
		if not controls then
			local module = lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("PlayerModule")
			controls = module and require(module):GetControls()
		end
		if controls then
			if on then controls:Enable() else controls:Disable() end
		end
	end)
end

local function setDoor(f)
	if door and doorCF and door.Parent then
		-- Hinge on the door's -Z edge; opens outward toward the player (-X).
		door.CFrame = doorCF * CFrame.new(0, 0, -1.3) * CFrame.Angles(0, math.rad(-100 * f), 0) * CFrame.new(0, 0, 1.3)
	end
end

local function aimPreview()
	if previewCam and framing then
		local dir = CFrame.Angles(0, Locker.yaw, 0) * framing.look
		previewCam.CFrame = CFrame.lookAt(framing.center + dir * framing.dist + Vector3.new(0, framing.lift, 0), framing.center)
	end
end

local function dress()
	if clone then
		Kit.apply(clone, Locker.preview)
	end
end

local function buildPreview()
	if clone then
		clone:Destroy()
		clone = nil
	end
	for _, x in ipairs(viewport:GetChildren()) do
		if x:IsA("BasePart") or x:IsA("Model") then
			x:Destroy()
		end
	end
	local char = lp.Character
	if not char then
		return false
	end
	local was = char.Archivable
	char.Archivable = true
	local ok, c = pcall(char.Clone, char)
	char.Archivable = was
	if not ok or not c then
		return false
	end
	for _, d in ipairs(c:GetDescendants()) do
		if d.Parent and (d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ForceField") or d.Name == "BCWorldGun") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.LocalTransparencyModifier = 0
		end
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	c.Name = "PreviewCharacter"
	c.Parent = viewport
	clone = c
	dress()
	local root = c:FindFirstChild("HumanoidRootPart")
	local cf, size = c:GetBoundingBox()
	local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	look = Vector3.new(look.X, 0, look.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	framing = { center = cf.Position, look = look, dist = size.Y * 1.7 + 2, lift = size.Y * 0.12 }
	-- Stage: dark-wood disc with a yellow rim under the feet (reference: centred figure on a platform).
	local floorY = cf.Position.Y - size.Y / 2
	for i, spec in ipairs({ { 7.6, Color3.fromRGB(230, 176, 40), 0.3 }, { 7, Color3.fromRGB(45, 34, 28), 0.34 } }) do
		local disc = Instance.new("Part")
		disc.Name, disc.Shape, disc.Anchored = "Stage" .. i, Enum.PartType.Cylinder, true
		disc.Size = Vector3.new(spec[3], spec[1], spec[1])
		disc.CFrame = CFrame.new(cf.Position.X, floorY - 0.2 + (i - 1) * 0.03, cf.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
		disc.Material, disc.Color = Enum.Material.SmoothPlastic, spec[2]
		disc.Parent = viewport
	end
	aimPreview()
	return true
end

local render

local function setStatus(text)
	Locker.status = text
end

function Locker.pick(slot, id)
	if Locker.busy then
		return false
	end
	Locker.focus = { slot = slot, id = id }
	if id and not owned(id) then
		setStatus("Locked: this arrives with the shop update.")
		render()
		return false
	end
	local nextPreview = table.clone(Locker.preview)
	nextPreview[slot] = id
	Locker.preview = nextPreview
	local changed = false
	for _, s in ipairs(C.CosmeticSlots) do
		changed = changed or nextPreview[s] ~= saved()[s]
	end
	setStatus(changed and "Previewing. APPLY saves this look." or "")
	dress()
	render()
	return true
end

function Locker.cancel()
	Locker.preview = table.clone(saved())
	setStatus("Preview cleared. Saved look unchanged.")
	dress()
	render()
end

function Locker.apply()
	if Locker.busy then
		return
	end
	Locker.busy = true
	setStatus("Saving…")
	render()
	ctx.GarageClient.request("cosmetics", table.clone(Locker.preview), nil, function(ok, why)
		Locker.busy = false
		Locker.lastAck = { ok = ok, reason = why }
		Locker.preview = table.clone(saved()) -- the server's answer is the truth either way
		if ok then
			setStatus("Saved. Your crew sees this look here and in the heist.")
		else
			setStatus(ctx.GarageClient.reasonText(why) .. " Showing your saved look.")
			Hud.toast(ctx.GarageClient.reasonText(why), 3)
		end
		dress()
		render()
	end)
end

function Locker.rotate(delta)
	Locker.yaw += delta
	aimPreview()
end

local function saveLine()
	local st = lp:GetAttribute("SaveStatus")
	if st == "SESSION ONLY" then
		return "Profile: SESSION ONLY. Studio test profiles are not kept."
	elseif st == "SAVE RETRY" then
		return "Profile: save retrying. Your look may not be kept yet."
	end
	return "Profile: saved with your account."
end

function render()
	if not Locker.open then
		return
	end
	local keep = GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) and GuiService.SelectedObject.Name
	for _, x in ipairs(panel:GetChildren()) do
		if x:IsA("GuiObject") and x ~= viewport then
			x:Destroy()
		end
	end
	local w, h = math.min(Hud.W - 16, 720), math.min(Hud.H - 12, 330)
	panel.Size = UDim2.fromOffset(w, h)
	local x0, first = 8, nil
	for _, cat in ipairs(CATS) do
		local b = Hud.pill(panel, "Cat_" .. cat[1], cat[2], cat[3], 52, Locker.category == cat[1] and C.UI.Orange or C.UI.Paper, { Position = UDim2.fromOffset(x0, 8) })
		b.Activated:Connect(function()
			Locker.category = cat[1]
			Locker.focus = nil
			render()
		end)
		x0 += cat[3] + 6
	end
	Hud.label(panel, Locker.status ~= "" and Locker.status or "LOCKER · your look", 11, { Name = "Status", Position = UDim2.fromOffset(x0 + 4, 8),
		Size = UDim2.fromOffset(w - x0 - 4 - 106, 52), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.UI.Muted })
	Hud.pill(panel, "Close", "CLOSE", 90, 52, C.UI.Pink, { Position = UDim2.fromOffset(w - 98, 8) }).Activated:Connect(Locker.close)
	if not cosmetics() then
		return
	end
	local top, bodyH, rw = 68, h - 76, 200
	local cx = 200
	local cw = w - cx - 8 - rw - 8
	-- Item grid (own items selectable; locked ones visible but never previewed or saved).
	local grid = Hud.make("ScrollingFrame", panel, { Name = "Items", Position = UDim2.fromOffset(8, top), Size = UDim2.fromOffset(184, bodyH), BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5 })
	local slot = Locker.category
	local items = { { id = nil, name = NONE[slot] } }
	for _, item in ipairs(C.Cosmetics) do
		if item.slot == slot then
			table.insert(items, item)
		end
	end
	for i, item in ipairs(items) do
		local mine = item.id == nil or owned(item.id)
		local on = Locker.preview[slot] == item.id
		local b = Hud.pill(grid, "Item_" .. (item.id or ("none_" .. slot)), item.name:upper() .. (mine and "" or "\nLOCKED"), 84, 60,
			on and C.UI.Blue or (mine and C.UI.Paper or Color3.fromRGB(214, 208, 196)),
			{ Position = UDim2.fromOffset(((i - 1) % 2) * 92, math.floor((i - 1) / 2) * 66), TextSize = 11, TextColor3 = mine and C.UI.Ink or C.UI.Muted })
		b:FindFirstChildOfClass("UIStroke").Thickness = saved()[slot] == item.id and 4 or 2
		local swatch = item.colors and item.colors.torso or (item.parts and item.parts[1].color)
		if swatch then
			Hud.corner(Hud.make("Frame", b, { Name = "Swatch", Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = swatch, BorderSizePixel = 0 }), 6)
		end
		b.Activated:Connect(function()
			Locker.pick(slot, item.id)
		end)
		first = first or b
	end
	-- Live preview + turn buttons
	viewport.Position, viewport.Size = UDim2.fromOffset(cx, top), UDim2.fromOffset(cw, bodyH - 60)
	Hud.pill(panel, "TurnLeft", "<", 52, 52, C.UI.Paper, { Position = UDim2.fromOffset(cx, h - 60) }).Activated:Connect(function() Locker.rotate(-0.6) end)
	Hud.pill(panel, "TurnRight", ">", 52, 52, C.UI.Paper, { Position = UDim2.fromOffset(cx + cw - 52, h - 60) }).Activated:Connect(function() Locker.rotate(0.6) end)
	Hud.label(panel, clone and "Drag to turn" or "Respawning…", 10, { Position = UDim2.fromOffset(cx + 56, h - 60), Size = UDim2.fromOffset(math.max(0, cw - 112), 52),
		TextColor3 = C.UI.Muted, TextWrapped = true })
	-- Details + actions
	local rx = w - rw - 8
	local fid = Locker.focus and Locker.focus.slot == slot and Locker.focus.id
	if fid == nil or fid == false then
		fid = Locker.preview[slot]
	end
	local def = fid and C.CosmeticsById[fid]
	local title = def and def.name or NONE[slot]
	local about = def and def.about or (slot == "outfit" and "Your own avatar clothes." or "Nothing in this slot.")
	if slot == "disguise" then
		about ..= " Cosmetic only: no stealth effect."
	elseif slot == "outfit" and def then
		about ..= " Hides avatar clothing."
	end
	local state = def and not owned(def.id) and "LOCKED · shop update" or (saved()[slot] == (def and def.id) and "SAVED LOOK" or "PREVIEW")
	Hud.label(panel, title:upper(), 15, { Name = "ItemName", Position = UDim2.fromOffset(rx, top), Size = UDim2.fromOffset(rw, 20), TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack })
	Hud.label(panel, state, 11, { Name = "ItemState", Position = UDim2.fromOffset(rx, top + 22), Size = UDim2.fromOffset(rw, 16), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.UI.Muted })
	Hud.label(panel, about, 11, { Name = "About", Position = UDim2.fromOffset(rx, top + 40), Size = UDim2.fromOffset(rw, 46), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamMedium })
	Hud.label(panel, saveLine(), 10, { Name = "SaveLine", Position = UDim2.fromOffset(rx, top + 88), Size = UDim2.fromOffset(rw, 30), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.UI.Muted, Font = Enum.Font.GothamMedium })
	local dirty = false
	for _, s in ipairs(C.CosmeticSlots) do
		dirty = dirty or Locker.preview[s] ~= saved()[s]
	end
	Hud.pill(panel, "Apply", Locker.busy and "SAVING…" or "APPLY", rw, 52, dirty and C.UI.Green or Color3.fromRGB(214, 208, 196),
		{ Position = UDim2.fromOffset(rx, h - 118) }).Activated:Connect(function()
		if dirty then
			Locker.apply()
		end
	end)
	Hud.pill(panel, "Cancel", "CANCEL", rw, 52, C.UI.Paper, { Position = UDim2.fromOffset(rx, h - 60) }).Activated:Connect(Locker.cancel)
	Locker.first = first
	local again = keep and panel:FindFirstChild(keep, true)
	if again or GuiService.SelectedObject == nil then
		ctx.Menus.focus(again or first)
	end
end

local function finishIntro()
	if not Locker.intro then
		return
	end
	Locker.intro = false
	RunService:UnbindFromRenderStep("BCLockerIntro")
	if introInput then
		introInput:Disconnect()
		introInput = nil
	end
	skipButton.Visible = false
	workspace.CurrentCamera.CFrame = Locker.view
	setDoor(1)
	Locker.open = true
	panel.Visible = true
	Locker.yaw = 0
	buildPreview()
	render()
end
Locker.skip = finishIntro

function Locker.enter()
	if Locker.open or Locker.intro or ctx.driving or ctx.cutscene then
		return false
	end
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	ctx.Menus.open("locker", Locker.close)
	Locker.intro, Locker.busy, Locker.focus, Locker.category = true, false, nil, "outfit"
	Locker.preview = table.clone(saved())
	setStatus("")
	setControls(false)
	ctx.cutscene = true
	local garage = workspace:FindFirstChild("Garage")
	door = garage and garage:FindFirstChild("LockerDoor")
	doorCF = door and door.CFrame
	local camera = workspace.CurrentCamera
	local from = camera.CFrame
	Locker.view = CFrame.lookAt(Map.point(C.Garage.LockerView), Map.point(C.Garage.Locker + Vector3.new(0, 3.6, 0)))
	if ctx.settings.reducedMotion then
		finishIntro() -- reduced motion: no camera travel or door swing, straight to the screen
		return true
	end
	skipButton.Visible = true
	local t0 = os.clock()
	RunService:BindToRenderStep("BCLockerIntro", Enum.RenderPriority.Camera.Value + 6, function()
		local f = math.clamp((os.clock() - t0) / C.Garage.LockerIntroSeconds, 0, 1)
		local e = f * f * (3 - 2 * f)
		camera.CFrame = from:Lerp(Locker.view, e)
		setDoor(e)
		if f >= 1 then
			finishIntro()
		end
	end)
	introInput = UserInputService.InputBegan:Connect(function(input, processed)
		local t = input.UserInputType
		if processed or input.KeyCode == C.Keys.MenuBack or input.KeyCode == C.Keys.PadMenuBack then
			return
		end
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Keyboard or t.Name:find("Gamepad") then
			finishIntro()
		end
	end)
	return true
end

function Locker.close()
	if not (Locker.open or Locker.intro) then
		return
	end
	Locker.open, Locker.intro, Locker.busy = false, false, false
	RunService:UnbindFromRenderStep("BCLockerIntro")
	if introInput then
		introInput:Disconnect()
		introInput = nil
	end
	skipButton.Visible = false
	panel.Visible = false
	if clone then
		clone:Destroy()
		clone = nil
	end
	if door and doorCF and door.Parent then
		door.CFrame = doorCF
	end
	dragging = nil
	ctx.cutscene = false
	setControls(true)
	ctx.Menus.closed("locker")
end

-- Read-only state for tests.
function Locker.snapshot()
	return { open = Locker.open, intro = Locker.intro, preview = table.clone(Locker.preview), saved = table.clone(saved()), status = Locker.status,
		busy = Locker.busy, lastAck = Locker.lastAck, clonePieces = clone and #Kit.pieces(clone) or -1,
		cloneStash = clone and clone:FindFirstChild(Kit.STASH) ~= nil or false, hasClone = clone ~= nil,
		cameraAtView = Locker.view ~= nil and (workspace.CurrentCamera.CFrame.Position - Locker.view.Position).Magnitude < 0.05,
		doorOpen = door ~= nil and doorCF ~= nil and (door.CFrame.Position - doorCF.Position).Magnitude > 0.5 }
end

function Locker.init(c)
	ctx, C, Hud = c, c.Config, c.Hud
	Map = require(c.shared.GarageMap)
	Kit = require(c.shared.CosmeticKit)
	panel = Hud.make("Frame", Hud.root, { Name = "LockerMenu", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 320), Visible = false, ZIndex = 50, Active = true })
	Hud.surface(panel)
	viewport = Hud.make("ViewportFrame", panel, { Name = "Preview", BackgroundColor3 = Color3.fromRGB(32, 38, 58), Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -1, -0.6), Active = true })
	Hud.corner(viewport, 12)
	previewCam = Instance.new("Camera")
	previewCam.FieldOfView = 34
	previewCam.Parent = viewport
	viewport.CurrentCamera = previewCam
	skipButton = Hud.pill(Hud.root, "SkipIntro", "SKIP", 90, 52, C.UI.Paper, { AnchorPoint = Vector2.new(1, 1), Visible = false, ZIndex = 60 })
	skipButton.Activated:Connect(finishIntro)
	Locker.panel = panel
	ctx.on("rescale", function()
		skipButton.Position = UDim2.fromOffset(Hud.W - 12, Hud.H - 12)
		if Locker.open then
			render()
		end
	end)
	ctx.on("profile", function()
		if Locker.open and not Locker.busy then
			render()
		end
	end)
	-- Turn the preview: drag (touch / mouse), gamepad right stick, or the < > buttons.
	viewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = { input = input, x = input.Position.X }
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = input.Position.X
		elseif dragging and (input == dragging.input or (input.UserInputType == Enum.UserInputType.MouseMovement and dragging.input.UserInputType == Enum.UserInputType.MouseButton1)) then
			Locker.rotate((input.Position.X - dragging.x) * 0.012)
			dragging.x = input.Position.X
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragging.input or input.UserInputType == dragging.input.UserInputType) then
			dragging = nil
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if Locker.open and math.abs(stick) > 0.2 then
			Locker.rotate(stick * dt * 2.5)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if Locker.open then
				local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
				if not root or (root.Position - Map.lockerPoint()).Magnitude > C.Garage.InteractionRange + 2 then
					Locker.close()
				end
			end
		end
	end)
end

return Locker
