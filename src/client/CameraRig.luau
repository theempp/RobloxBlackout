-- First-person camera we fully own (Scriptable), so aim input, ADS sensitivity, aim assist and recoil
-- all act on one yaw/pitch pair. Look input: touch drag on the right half (or starting on Fire),
-- mouse delta (cursor locked), right stick. Recoil rotates the AIM; a separate spring kicks only the view.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local CameraRig = { yaw = 0, pitch = 0, ads = false }
local ctx, C, CAM, AA
local camera = workspace.CurrentCamera
local pendingX, pendingY = 0, 0 -- accumulated look input in degrees (x = right, y = down)
local stick = Vector2.zero
local aimTouches = {}
local fov, adsFov = 70, 70
local kick, kickVel = 0, 0 -- visual-only view kick (degrees)
local hidden = {} -- local character parts hidden in first person
local targets, aimParts = {}, {}

local function onTarget(model)
	aimParts[model] = model:FindFirstChild("Body") or model:FindFirstChild("Head") or model.PrimaryPart
	table.insert(targets, model)
end
local function offTarget(model)
	local i = table.find(targets, model)
	if i then
		table.remove(targets, i)
	end
	aimParts[model] = nil
end

-- Is the reticle inside an assist cone around any live target?
local function assistActive(camPos, look)
	for _, m in ipairs(targets) do
		local p = aimParts[m]
		if p and p.Parent and not m:GetAttribute("Down") then
			local v = p.Position - camPos
			local dist = v.Magnitude
			if dist > 1 and dist < AA.MaxRange then
				local limit = math.rad(AA.RadiusDeg) + math.atan(1.5 / dist)
				if look:Dot(v) / dist >= math.cos(limit) then
					return true
				end
			end
		end
	end
	return false
end
CameraRig.assistActive = assistActive

function CameraRig.adoptTouch(input)
	aimTouches[input] = true
end
function CameraRig.releaseTouch(input)
	aimTouches[input] = nil
end

-- Recoil: rotate the aim (up, right in degrees) and push the view spring.
function CameraRig.kick(up, right, visual)
	CameraRig.pitch = math.clamp(CameraRig.pitch + up, -CAM.PitchLimit, CAM.PitchLimit)
	CameraRig.yaw -= right
	kickVel += (visual or 1) * 60
end

function CameraRig.setAds(on, targetFov)
	CameraRig.ads = on
	adsFov = targetFov or CAM.Fov
end

-- Point the camera at a world position (spawn facing, tests).
function CameraRig.lookAt(pos)
	local from = camera.CFrame.Position
	local v = (pos - from).Unit
	CameraRig.yaw = math.deg(math.atan2(-v.X, -v.Z))
	CameraRig.pitch = math.deg(math.asin(math.clamp(v.Y, -1, 1)))
end

local function hideCharacter(char)
	table.clear(hidden)
	local function add(d)
		if d:IsA("BasePart") or d:IsA("Decal") then
			table.insert(hidden, d)
		end
	end
	for _, d in ipairs(char:GetDescendants()) do
		add(d)
	end
	char.DescendantAdded:Connect(add)
end

local function step(dt)
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if ctx.cutscene then -- a cutscene (departure, locker) owns the camera; menus over it still need the cursor
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = ctx.cursorFree or ctx.inputKind ~= "Keyboard"
		return
	end
	if ctx.driving then -- KartClient owns the camera
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		for _, p in ipairs(hidden) do
			p.LocalTransparencyModifier = ctx.KartClient and ctx.KartClient.cockpit and 1 or 0
		end
		return
	end
	UserInputService.MouseBehavior = (ctx.inputKind == "Keyboard" and not ctx.cursorFree) and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = ctx.cursorFree or ctx.inputKind ~= "Keyboard"

	local s = ctx.settings
	if stick.Magnitude > CAM.GamepadDeadzone then
		local m = (stick.Magnitude - CAM.GamepadDeadzone) / (1 - CAM.GamepadDeadzone)
		local d = stick.Unit * (m * m) * CAM.GamepadSens * dt -- squared response curve
		pendingX += d.X
		pendingY -= d.Y
	end
	local dx, dy = pendingX, pendingY
	pendingX, pendingY = 0, 0
	local camCF = camera.CFrame
	if dx ~= 0 or dy ~= 0 then
		local k = s.sensitivity
		if CameraRig.ads then
			k *= s.adsSensitivity * (fov / CAM.Fov) -- FOV-proportional so ADS feels consistent
		end
		if s.aimAssist and AA.Enabled and (ctx.inputKind ~= "Keyboard" or not AA.TouchAndGamepadOnly)
			and assistActive(camCF.Position, camCF.LookVector) then
			k *= AA.SlowFactor -- slow-down only, never pulls
		end
		dx *= k
		dy *= k
	end
	CameraRig.yaw -= dx
	local pitchDelta = -dy
	if ctx.GunClient then
		ctx.GunClient.onLook(pitchDelta)
		pitchDelta += ctx.GunClient.recoverStep(dt)
	end
	CameraRig.pitch = math.clamp(CameraRig.pitch + pitchDelta, -CAM.PitchLimit, CAM.PitchLimit)

	local target = CameraRig.ads and adsFov or CAM.Fov
	fov += (target - fov) * math.min(1, CAM.FovLerp * dt)
	camera.FieldOfView = fov

	-- critically-damped-ish spring for the visual kick
	kickVel += (-kick * 400 - kickVel * 2 * C.Recoil.VisualReturn) * dt
	kick += kickVel * dt
	if ctx.settings.reducedMotion then
		kick = 0
	end

	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local rotY = CFrame.Angles(0, math.rad(CameraRig.yaw), 0)
	if root then
		local eye = root.Position + Vector3.new(0, CAM.EyeFromRoot, 0)
		CameraRig.aimCF = CFrame.new(eye) * rotY * CFrame.Angles(math.rad(CameraRig.pitch), 0, 0) -- shots use this (no view kick)
		camera.CFrame = CameraRig.aimCF * CFrame.Angles(math.rad(kick), 0, 0)
		root.CFrame = CFrame.new(root.Position) * rotY
		for _, p in ipairs(hidden) do
			p.LocalTransparencyModifier = 1
		end
	end
end

function CameraRig.init(c)
	ctx = c
	C = ctx.Config
	CAM, AA = C.Camera, C.AimAssist
	fov = CAM.Fov
	camera.CameraType = Enum.CameraType.Scriptable
	for _, m in ipairs(CollectionService:GetTagged("BC_Target")) do
		onTarget(m)
	end
	CollectionService:GetInstanceAddedSignal("BC_Target"):Connect(onTarget)
	CollectionService:GetInstanceRemovedSignal("BC_Target"):Connect(offTarget)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if ctx.inputKind == "Keyboard" and not ctx.cursorFree then
				pendingX += input.Delta.X * CAM.MouseSens
				pendingY += input.Delta.Y * CAM.MouseSens
			end
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.TouchStarted:Connect(function(input, gp)
		if not gp and not ctx.cursorFree and input.Position.X > camera.ViewportSize.X * 0.5 then
			aimTouches[input] = true
		end
	end)
	UserInputService.TouchMoved:Connect(function(input)
		if aimTouches[input] and not ctx.cursorFree then
			pendingX += input.Delta.X * CAM.TouchSens
			pendingY += input.Delta.Y * CAM.TouchSens
		end
	end)
	UserInputService.TouchEnded:Connect(function(input)
		aimTouches[input] = nil
	end)

	local lp = Players.LocalPlayer
	local function onChar(char)
		local hum = char:WaitForChild("Humanoid")
		hum.AutoRotate = false
		local root = char:WaitForChild("HumanoidRootPart")
		local _, y = root.CFrame:ToOrientation()
		CameraRig.yaw, CameraRig.pitch = math.deg(y), 0
		hideCharacter(char)
	end
	lp.CharacterAdded:Connect(onChar)
	if lp.Character then
		task.spawn(onChar, lp.Character)
	end
	RunService:BindToRenderStep("BCCamera", Enum.RenderPriority.Camera.Value + 1, step)
end

return CameraRig
