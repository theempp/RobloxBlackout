-- Test-build client probe: compile/readiness probe, UI size probe, short frame probe, remote flood.
if not workspace:GetAttribute("BCTesting") then
	return
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

local t0 = os.clock()
repeat
	task.wait(0.1)
until lp:GetAttribute("BCClientReady") ~= nil or os.clock() - t0 > 30
local data = {
	ready = lp:GetAttribute("BCClientReady") == true,
	modules = lp:GetAttribute("BCClientModules") or 0,
	expected = lp:GetAttribute("BCClientExpected") or -1,
	failed = lp:GetAttribute("BCClientFailed") or "no report",
}
task.wait(1)

-- UI probe: every visible button in our HUD must be >= MinTouchPx physical pixels.
local ok, err = pcall(function()
	local gui = lp.PlayerGui:FindFirstChild("BlackoutCrewHud")
	data.hud = gui ~= nil
	data.buttons, data.minButton, data.small = 0, math.huge, {}
	if gui then
		for _, b in ipairs(gui:GetDescendants()) do
			if b:IsA("GuiButton") and b.Visible and b:GetAttribute("TouchTarget") then
				local vis = true
				local a = b.Parent
				while a and a ~= gui do
					if a:IsA("GuiObject") and not a.Visible then
						vis = false
					end
					a = a.Parent
				end
				if vis then
					local s = math.min(b.AbsoluteSize.X, b.AbsoluteSize.Y)
					data.buttons += 1
					data.minButton = math.min(data.minButton, s)
					if s < 44 then
						table.insert(data.small, b.Name .. "=" .. math.floor(s))
					end
				end
			end
		end
	end
	data.small = table.concat(data.small, ",")
	-- Layout audit: visible buttons must not overlap each other or leave the screen.
	local rects, bad, off = {}, {}, {}
	local screen = gui and gui.AbsoluteSize or Vector2.zero
	for _, b in ipairs(gui and gui:GetDescendants() or {}) do
		if b:IsA("GuiButton") and b:GetAttribute("TouchTarget") and b.Visible and b.Parent.Visible ~= false and b.AbsoluteSize.X > 0 then
			local shown = true
			local a = b.Parent
			while a and a ~= gui do
				if a:IsA("GuiObject") and not a.Visible then
					shown = false
				end
				a = a.Parent
			end
			if shown then
				local p0, p1 = b.AbsolutePosition, b.AbsolutePosition + b.AbsoluteSize
				if p0.X < -1 or p0.Y < -1 or p1.X > screen.X + 1 or p1.Y > screen.Y + 1 then
					table.insert(off, b.Name)
				end
				for _, r in ipairs(rects) do
					if p0.X < r[3] and p1.X > r[1] and p0.Y < r[4] and p1.Y > r[2] then
						table.insert(bad, r[5] .. "+" .. b.Name)
					end
				end
				table.insert(rects, { p0.X, p0.Y, p1.X, p1.Y, b.Name })
			end
		end
	end
	data.overlaps, data.offscreen = table.concat(bad, ","), table.concat(off, ",")
end)
data.uiError = not ok and tostring(err) or nil

-- End-to-end through the real input path: aim at a range dummy, pull the trigger, wait for the
-- server-confirmed Hit. Runs BEFORE the flood (the flood empties the Fire rate-limit bucket).
local okE2E, errE2E = pcall(function()
	local cs = require(lp.PlayerScripts:WaitForChild("BlackoutCrew"):WaitForChild("ClientState"))
	local gc, rig = cs.GunClient, cs.CameraRig
	local t1 = os.clock()
	repeat
		task.wait(0.1)
	until (gc and gc.stats) or os.clock() - t1 > 10
	local target = workspace:WaitForChild("Range", 10):WaitForChild("Static10", 10)
	local body = target and target:WaitForChild("Body", 5)
	data.e2eGun = gc.gunId
	rig.lookAt(body.Position)
	task.wait(0.8) -- draw time + camera settle
	data.e2eAimOnTarget = rig.assistActive(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.LookVector)
	local ammo0, hits0, shots0 = gc.ammo[gc.gunId], gc.confirmedHits, gc.shots
	cs.emit("fire", true)
	task.wait(0.1)
	cs.emit("fire", false)
	local t2 = os.clock()
	repeat
		task.wait(0.05)
	until gc.confirmedHits > hits0 or os.clock() - t2 > 3
	data.e2eShots = gc.shots - shots0
	data.e2eAmmoDelta = ammo0 - gc.ammo[gc.gunId]
	data.e2eConfirmed = gc.confirmedHits - hits0
	local cam = workspace.CurrentCamera
	local vm = cs.ViewModel.rootPart()
	local vp = cam.ViewportSize
	local hip = vm and cam:WorldToViewportPoint(vm.Position)
	data.vmHip = hip and hip.Z > 0 and hip.X > vp.X * 0.5 and hip.Y > vp.Y * 0.5 and hip.X < vp.X and hip.Y < vp.Y
	cs.emit("adsToggle")
	-- Wait for the blend to finish, not a fixed time: the unfocused CLI window throttles rendering.
	local t3 = os.clock()
	repeat
		task.wait(0.05)
	until (cs.ViewModel.adsProgress() >= 0.999 and cam.FieldOfView < cs.Config.Camera.Fov - 5) or os.clock() - t3 > 4
	data.adsBlend = cs.ViewModel.adsProgress()
	local ads = vm and cam:WorldToViewportPoint(vm.Position)
	data.vmAds = ads and ads.Z > 0 and math.abs(ads.X - vp.X / 2) < vp.X * 0.08
	data.adsOn = gc.ads
	data.adsFov = workspace.CurrentCamera.FieldOfView
	cs.emit("adsToggle")
	local t4 = os.clock()
	repeat
		task.wait(0.05)
	until (cs.ViewModel.adsProgress() <= 0.001 and cam.FieldOfView > cs.Config.Camera.Fov - 3) or os.clock() - t4 > 4
	data.hipFov = workspace.CurrentCamera.FieldOfView
	data.comingSoon = select(2, gc.equip(4))
	data.wheelOpenable = cs.Wheel ~= nil
	cs.emit("wheelOpen")
	data.wheelOpened = cs.Wheel.open
	cs.emit("wheelRelease")
	data.wheelClosed = not cs.Wheel.open
end)
data.e2eError = not okE2E and tostring(errE2E) or nil

-- Remote flood: 60 Fire events in one frame; the server's rate limiter must drop most of them.
local remotes = RS:FindFirstChild("BlackoutCrew") and RS.BlackoutCrew:FindFirstChild("Remotes")
if remotes and remotes:FindFirstChild("Fire") then
	for i = 1, 60 do
		remotes.Fire:FireServer(1e6 + i, Vector3.zero, Vector3.new(0, 0, -1), false)
	end
	data.flooded = 60
end

-- Frame probe (short in tests; the CLI window is throttled so this is not a phone number).
local samples, total, elapsed = {}, 0, 0
local done = false
local conn
conn = RunService.RenderStepped:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 then
		return
	end
	table.insert(samples, dt)
	total += dt
	if total >= 3 then
		conn:Disconnect()
		done = true
	end
end)
repeat
	task.wait(0.1)
until done or os.clock() - t0 > 60
if #samples > 0 then
	table.sort(samples)
	data.perf = { meanFPS = #samples / total, p95ms = samples[math.ceil(#samples * 0.95)] * 1000, frames = #samples }
end
RS:WaitForChild("BCTestReport"):FireServer(data)
