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
	cs.emit("adsToggle")
	task.wait(0.4)
	data.adsOn = gc.ads
	data.adsFov = workspace.CurrentCamera.FieldOfView
	cs.emit("adsToggle")
	task.wait(0.3)
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
