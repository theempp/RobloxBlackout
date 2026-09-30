-- Kart driving on the client (§3b; touch per §5f). Left thumb = the Roblox thumbstick, which steers and
-- throttles through the VehicleSeat; GAS / BRAKE / EXIT on the right; keyboard W/S/A/D (+ Shift brake);
-- gamepad sticks/triggers. By default this client owns the kart and steps the shared physics itself
-- (no network round trip on phones). In Config.Kart.ServerPhysics mode it sends validated input at 15 Hz.
-- Chase camera; EMP spin kick when the kart's EmpAt changes.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local KartClient = { kart = nil, testInput = nil, speed = 0, steps = 0 }
local ctx, C, K, KartPhysics
local lp = Players.LocalPlayer
local state, spunAt = nil, 0
local gas, brake = false, false
local camPos
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function myKart()
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local m = seat and seat.Parent
	if m and CollectionService:HasTag(m, "BC_Kart") and m:GetAttribute("Owner") == lp.UserId then
		return m
	end
	return nil
end

local function setDriving(m)
	KartClient.kart = m
	local on = m ~= nil
	if ctx.driving ~= on then
		ctx.driving = on
		state = on and KartPhysics.newState() or nil
		spunAt = m and (m:GetAttribute("EmpAt") or 0) or 0
		camPos = nil
		gas, brake = false, false
		ctx.emit("driving", on)
		ctx.Controls.layout()
		if not on then
			workspace.CurrentCamera.FieldOfView = C.Camera.Fov
		end
	end
end

function KartClient.input()
	if KartClient.testInput then
		return KartClient.testInput
	end
	local m = KartClient.kart
	local seat = m and m:FindFirstChild("Seat")
	local t, s = seat and seat.ThrottleFloat or 0, seat and seat.SteerFloat or 0
	local b = brake or UserInputService:IsKeyDown(C.Keys.KartBrake)
	if gas or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, C.Keys.PadGas) then
		t = 1
	end
	if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, C.Keys.PadBrake) then
		b = true
	end
	if b and KartClient.speed < 1 then
		b, t = false, -1 -- held brake at a stop = reverse
	end
	return KartPhysics.cleanInput(t, s, b)
end

local function physics(dt)
	local m = KartClient.kart
	if not m or K.ServerPhysics or m:GetAttribute("Driver") ~= lp.UserId then
		return
	end
	local root = m.PrimaryPart
	local list = { workspace:FindFirstChild("KartsFolder"), workspace:FindFirstChild("HeistLoot"), workspace:FindFirstChild("LaserBeams") }
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(list, p.Character)
	end
	rayParams.FilterDescendantsInstances = list
	local sNow = workspace:GetServerTimeNow()
	local empAt = m:GetAttribute("EmpAt") or 0
	local spin = empAt > spunAt
	if spin then
		spunAt = empAt
	end
	KartClient.speed = KartPhysics.step(root, state, KartClient.input(), dt, K, rayParams,
		{ sabotaged = m:GetAttribute("Sabotaged"), emp = sNow < (m:GetAttribute("EmpUntil") or 0), spin = spin })
	KartClient.steps += 1
end

local function camera(dt)
	local m = KartClient.kart
	local root = m and m.PrimaryPart
	if not root then
		return
	end
	local cam = workspace.CurrentCamera
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local cc = K.Camera
	local target = root.Position - flat * cc.Back + Vector3.new(0, cc.Up, 0)
	camPos = camPos and camPos:Lerp(target, math.min(1, dt * cc.Lerp)) or target
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(camPos, root.Position + flat * cc.Ahead + Vector3.new(0, 2, 0))
	cam.FieldOfView = cc.Fov + math.clamp(KartClient.speed / K.MaxSpeed, 0, 1) * 8
	if K.ServerPhysics then
		KartClient.speed = root.AssemblyLinearVelocity:Dot(look)
	end
end

function KartClient.init(c)
	ctx = c
	C = ctx.Config
	K = C.Kart
	KartPhysics = require(ctx.shared.KartPhysics)
	local Controls = ctx.Controls
	Controls.press("gas", function()
		gas = true
	end, function()
		gas = false
	end)
	Controls.press("brake", function()
		brake = true
	end, function()
		brake = false
	end)
	Controls.press("exit", function()
		local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Sit = false
			hum.Jump = true
		end
	end)
	RunService.PreSimulation:Connect(function(dt)
		setDriving(myKart())
		physics(dt)
	end)
	RunService:BindToRenderStep("BCKartCam", Enum.RenderPriority.Camera.Value + 3, function(dt)
		if ctx.driving then
			camera(dt)
		end
	end)
	task.spawn(function()
		local last, n = nil, 0
		while true do
			task.wait(1 / K.InputRate)
			if K.ServerPhysics and KartClient.kart then
				local i = KartClient.input()
				local key = i.t .. ":" .. i.s .. ":" .. tostring(i.b)
				n += 1
				if key ~= last or n % 4 == 0 then -- changes at once; a keep-alive every ~0.27 s beats the 0.5 s timeout
					last = key
					ctx.remotes.KartInput:FireServer(i.t, i.s, i.b)
					ctx.netSends += 1
				end
			end
		end
	end)
	ctx.probe = ctx.probe or {}
	ctx.probe.kart = function()
		return { driving = ctx.driving == true, steps = KartClient.steps, speed = KartClient.speed,
			gasShown = Controls.buttons.gas.Visible, fireShown = Controls.buttons.fire.Visible, camType = workspace.CurrentCamera.CameraType.Name }
	end
	ctx.probe.exit = function()
		local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Sit = false
			hum.Jump = true
		end
		return {}
	end
	ctx.probe.drive = function(t, s, b)
		KartClient.testInput = t and KartPhysics.cleanInput(t, s, b) or nil
		return {}
	end
end

return KartClient
