-- Kart: RAZOR model build (template + placeholder paths, budget, decal zones, no neon), input validation,
-- live physics on a server-owned test kart (south outer road), the real driver-owned path (client steps
-- physics via the probe, wheels follow the ground), parking on exit, and the overspeed rubber-band.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local KartPhysics = require(RS.BlackoutCrew.KartPhysics)
local KartModel = require(RS.BlackoutCrew.KartModel)
local S = require(SSS.BlackoutCrew.ServerState)
local K = C.Kart
local V = Vector3.new

local function speedOf(root)
	return root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector)
end

local function waitFor(cond, t)
	local t0 = os.clock()
	repeat
		task.wait(0.05)
	until cond() or os.clock() - t0 > t
	return cond()
end

return function(T)
	local ci = KartPhysics.cleanInput(0 / 0, math.huge, "yes")
	T.check("junk input -> neutral", ci.t == 0 and ci.s == 0 and ci.b == false)
	local cl = KartPhysics.cleanInput(5, -3, true)
	T.check("input clamped", cl.t == 1 and cl.s == -1 and cl.b == true)
	T.eq("4 wheels", #KartPhysics.wheels(K), 4)

	-- Model: placeholder path (no RazorKart.rbxmx yet), then a fake RAZOR template (Parts in the FBX layout).
	local G = K.Geo
	local existing = KartModel.template()
	if existing then existing.Parent = nil end -- exercise the fallback even after the owner imports RAZOR
	local pm = KartModel.build(1, CFrame.new(0, 500, 0))
	local neon, zones = 0, 0
	for _, d in ipairs(pm:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			neon += 1
		end
	end
	for _, d in ipairs(pm:GetDescendants()) do
		if d:GetAttribute("Zone") then
			zones += 1
		end
	end
	T.check("placeholder kart (no template)", KartModel.template() == nil and pm:GetAttribute("Visual") == "placeholder")
	T.check("tri budget (placeholder + RAZOR)", KartModel.tris(pm) <= C.TriBudget.Kart and G.Tris <= C.TriBudget.Kart, KartModel.tris(pm))
	T.check("no neon on the kart", neon == 0, neon)
	T.eq("§17 decal zones hood + rear", zones, 2)
	local okWheels = true
	for i, name in ipairs(KartModel.WHEELS) do
		local wp = pm:FindFirstChild(name)
		local want = (pm.PrimaryPart.CFrame * CFrame.new(-G.Collider.Center)) * G.Hubs[i]
		okWheels = okWheels and wp and pm.PrimaryPart:FindFirstChild("M_" .. name) ~= nil and (wp.Position - want).Magnitude < 0.01
	end
	T.check("wheels on Motor6Ds at the measured RAZOR hubs", okWheels)
	T.check("pivot = ground point at rest", (pm:GetPivot().Position - V(0, 500, 0)).Magnitude < 1e-3)
	pm:Destroy()
	local assets = RS:FindFirstChild("BlackoutCrewAssets")
	local tpl = Instance.new("Model")
	tpl.Name = C.KartModel.Template
	local tf = CFrame.new(40, 7, -9) * CFrame.Angles(0, math.rad(33), 0) -- anywhere: the frame comes from Chassis
	local function tp(name, size, at, rot)
		local p = Instance.new(name == "Chassis" and "MeshPart" or "Part")
		p.Name, p.Size, p.CFrame = name, size, tf * CFrame.new(at) * (rot or CFrame.new())
		p.Material = Enum.Material.Neon
		p.Parent = tpl
		return p
	end
	local chassis = tp("Chassis", G.Chassis.Size, G.Chassis.Center)
	local surface = Instance.new("SurfaceAppearance")
	surface.Parent = chassis
	Instance.new("PointLight").Parent = chassis
	for i, name in ipairs(KartModel.WHEELS) do
		tp(name, V(G.WheelWidth, 1.84, 1.84), G.Hubs[i], G.Hubs[i].X < 0 and CFrame.Angles(0, math.pi, 0) or nil)
	end
	tp("Steer", V(0.7, 0.2, 0.7), G.SteerHub)
	tp("HeadlightStrips", V(3.6, 0.1, 0.4), V(0, 1, -4.9))
	tp("TailStrips", V(2.4, 0.2, 0.1), V(0, 1.55, 5))
	tp("Underglow", V(4, 0.05, 8), V(0, 0.22, 0))
	tp("Collision", V(4.9, 1.95, 11), V(0, 1.125, 0))
	tp("DecalPlates", V(1.9, 2.1, 9.4), V(0, 1.4, 0.4))
	tpl.Parent = assets
	local rm = KartModel.build(2, CFrame.new(0, 500, 0))
	local hubsOk = true
	for i, name in ipairs(KartModel.WHEELS) do
		local want = (rm.PrimaryPart.CFrame * CFrame.new(-G.Collider.Center)) * G.Hubs[i]
		hubsOk = hubsOk and rm:FindFirstChild(name) and (rm[name].Position - want).Magnitude < 0.01
	end
	T.check("template: used, wheels re-seated on the hubs", rm:GetAttribute("Visual") == "vortex" and hubsOk)
	T.check("RAZOR template: Collision + Underglow dropped, lights matte", rm:FindFirstChild("Collision") == nil and rm:FindFirstChild("Underglow") == nil
		and rm.HeadlightStrips.Material ~= Enum.Material.Neon and rm.TailStrips.Material ~= Enum.Material.Neon)
	T.check("RAZOR template: visuals massless, non-colliding", rm.Chassis.Massless and not rm.Chassis.CanCollide and not rm.Wheel_FL.CanQuery)
	T.check("template keeps PBR appearance and removes emissive materials/lights", rm.Chassis:FindFirstChildOfClass("SurfaceAppearance") ~= nil and rm.Chassis.Material ~= Enum.Material.Neon and rm.Chassis:FindFirstChildOfClass("PointLight") == nil)
	rm:Destroy()
	tpl.Wheel_FR.CFrame *= CFrame.new(0, 0.5, 0) -- a pivot/axes problem
	local bad = KartModel.build(3, CFrame.new(0, 500, 0))
	T.check("RAZOR template off its hubs -> placeholder", bad:GetAttribute("Visual") == "placeholder")
	bad:Destroy()
	tpl:Destroy()
	if existing then existing.Parent = assets end

	local Heist = S.Heist
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until (Heist.run and S.karts.byOwner[T.player]) or os.clock() - t0 > 10
	local run = Heist.run
	local player = T.player
	local Karts = S.karts
	if not T.check("player has a kart", run and Karts.byOwner[player] ~= nil) then
		return
	end
	T.check("kart per player at the arrival", #Karts.list == #run.players)

	-- Test kart on the south outer road (60 studs wide, open along X), facing +X.
	local start = CFrame.new(260, 0, -210) * CFrame.Angles(0, math.rad(-90), 0) -- ground point, facing +X
	local m, root, seat = Karts.build(player, 4, start * CFrame.new(0, 1, 0))
	local k = { model = m, root = root, seat = seat, owner = player, slot = 4, spot = { pos = V(0, 0, 0) }, state = KartPhysics.newState(),
		repairers = {}, steps = 0, idleT = 0, strikes = 0, testInput = { t = 0, s = 0, b = true } }
	table.insert(Karts.list, k)
	root.Anchored = false
	root:SetNetworkOwner(nil)
	task.wait(1.5)
	local rideErr = root.Position.Y - KartPhysics.restCF(start, K).Y
	T.check("live: rests at the ride height (velocity bridge)", math.abs(rideErr) < 0.05, rideErr)
	T.check("settles upright", root.CFrame.UpVector.Y > 0.995)
	T.near("anti-gravity cancels Roblox gravity", root.AntiGravity.Force.Y, root.AssemblyMass * workspace.Gravity, 1e-3)
	local x0 = root.Position.X
	k.testInput = { t = 1, s = 0, b = false }
	task.wait(3)
	local v = speedOf(root)
	T.check("accelerates to ~MaxSpeed", v > K.MaxSpeed * 0.8 and v < K.MaxSpeed * 1.08, v)
	T.check("drives forward", root.Position.X - x0 > 60, root.Position.X - x0)
	T.check("stays upright at speed", root.CFrame.UpVector.Y > 0.95)
	k.testInput = { t = 0, s = 0, b = true }
	T.check("brakes to a stop", waitFor(function()
		return math.abs(speedOf(root)) < 5
	end, 2))
	local yaw0 = root.CFrame.LookVector
	k.testInput = { t = 0.7, s = 1, b = false }
	task.wait(1.5)
	local turned = math.deg(math.acos(math.clamp(yaw0:Dot(root.CFrame.LookVector), -1, 1)))
	T.check("steers", turned > 30, turned)
	k.testInput = { t = 0, s = 0, b = true }
	waitFor(function()
		return math.abs(speedOf(root)) < 2
	end, 2)
	k.testInput = { t = -1, s = 0, b = false }
	task.wait(1.5)
	local rv = speedOf(root)
	T.check("reverses, capped", rv < -5 and rv > -K.Reverse - 3, rv)
	k.testInput = { t = 0, s = 0, b = true }
	waitFor(function()
		return math.abs(speedOf(root)) < 2
	end, 2)
	m:SetAttribute("Sabotaged", true)
	k.testInput = { t = 1, s = 0, b = false }
	task.wait(1)
	T.check("sabotaged kart won't drive", math.abs(speedOf(root)) < 2, speedOf(root))
	m:SetAttribute("Sabotaged", false)
	-- EMP at speed: capped to MaxSpeed x EmpSpeedMult and a spin kick.
	m:PivotTo(start)
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	task.wait(2.5)
	local sNow = workspace:GetServerTimeNow()
	m:SetAttribute("EmpUntil", sNow + 2)
	m:SetAttribute("EmpAt", sNow)
	task.wait(0.1)
	T.check("EMP spins", math.abs(root.AssemblyAngularVelocity.Y) > 2, root.AssemblyAngularVelocity.Y)
	task.wait(1.3)
	T.check("EMP slows", math.abs(speedOf(root)) < K.MaxSpeed * K.EmpSpeedMult + 6, speedOf(root))
	-- Flipped + still -> auto-upright.
	k.testInput = { t = 0, s = 0, b = true }
	m:PivotTo(CFrame.new(root.Position + V(0, 3, 0)) * CFrame.Angles(0, 0, math.pi))
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	T.check("auto-upright when flipped", waitFor(function()
		return root.CFrame.UpVector.Y > 0.9
	end, K.FlipTime + 2.5))
	table.remove(Karts.list, table.find(Karts.list, k))
	m:Destroy()

	-- Input remote (server-physics mode only): wrong mode / not seated -> rejected.
	local r0 = Karts.rejectedInputs
	T.check("input refused in client-physics mode", Karts.input(player, 1, 0, false) == false and Karts.rejectedInputs == r0 + 1)
	K.ServerPhysics = true
	T.check("input refused when not seated in own kart", Karts.input(player, 1, 0, false) == false)
	K.ServerPhysics = false

	-- The real kart, driver-owned: DRIVE -> the client steps physics.
	Heist.paused = true
	local kk = Karts.byOwner[player]
	local kp = kk.root.Position
	T.cmd("moveTo", kp + V(0, 2, 7))
	waitFor(function()
		return (player.Character.HumanoidRootPart.Position - kp).Magnitude < 9
	end, 3)
	T.check("DRIVE hold", S.interact.start(player, "drive", kk.model, 0))
	S.interact.tick(S, run, 0, C.Actions.drive.hold + 0.01)
	T.check("seated in own kart", player.Character.Humanoid.SeatPart == kk.seat and kk.model:GetAttribute("Driver") == player.UserId
		and player:GetAttribute("BC_Driving") == true)
	T.eq("gun holstered in the kart", select(2, S.Weapons.fire(player, S.Weapons.state(player).lastSeq + 1, player.Character.Head.Position, V(0, 0, -1), false)), "holstered")
	local ok1, st
	waitFor(function()
		ok1, st = T.cmd("eval", "kart")
		return ok1 and st.driving == true
	end, 3) -- the seat weld takes a moment to replicate
	T.check("client in kart mode", ok1 and st.driving == true and st.gasShown == true and st.fireShown == false, ok1 and st.driving)
	local _, v0 = T.cmd("eval", "vortex")
	T.check("Vortex LEDs visible while on", v0 and v0.lit >= 12, v0 and v0.lit)
	T.check("driver switches LEDs off", Karts.action(player, "lights") and kk.model:GetAttribute("LightsOn") == false)
	task.wait(0.15)
	local _, v1 = T.cmd("eval", "vortex")
	T.eq("all exterior LEDs dark in client view", v1 and v1.lit, 0)
	Karts.action(player, "lights")
	T.check("driver opens butterfly doors", Karts.action(player, "doors") and kk.model:GetAttribute("DoorsOpen") == true)
	task.wait(0.35)
	local _, v2 = T.cmd("eval", "vortex")
	T.check("door motors articulate on client", v2 and v2.doorAngle > 0.1, v2 and v2.doorAngle)
	Karts.action(player, "doors")
	T.cmd("eval", "vortex", "view")
	task.wait(0.15)
	local _, vp = T.cmd("eval", "vortex")
	T.check("cockpit view is inside car", vp and vp.cockpit and vp.cameraGap < 3, vp and vp.cameraGap)
	T.cmd("eval", "drive", 0, 1, false)
	task.wait(0.35)
	local _, vs = T.cmd("eval", "vortex")
	T.check("visible wheel turns with steering input", vs and vs.steerAngle > 0.1, vs and vs.steerAngle)
	T.cmd("eval", "drive", 0, 0, false)
	T.cmd("eval", "vortex", "view")
	local okA, ui = T.cmd("audit")
	T.check("kart HUD: buttons >= 44px, no overlaps, on screen", okA and ui.buttons >= 3 and ui.small == "" and ui.overlaps == "" and ui.offscreen == "",
		okA and (ui.buttons .. " " .. ui.small .. "|" .. ui.overlaps .. "|" .. ui.offscreen))
	local x1 = kk.root.Position.X
	T.cmd("eval", "drive", 1, 0, false)
	waitFor(function()
		return kk.root.Position.X - x1 > 25
	end, 4)
	local _, st2 = T.cmd("eval", "kart")
	T.check("driver's client steps the physics", st2 and st2.steps > 30, st2 and st2.steps)
	local okV, kv = T.cmd("eval", "kartVisuals")
	local mine = okV and kv.karts[kk.model.Name]
	local minGap = 99
	for _, g in ipairs(mine and mine.gap or {}) do
		minGap = math.min(minGap, g)
	end
	T.check("client: wheels follow the ground (no clipping, no float)", mine ~= nil and minGap > -0.06 and minGap < 0.1, minGap)
	T.check("kart moved under client physics", kk.root.Position.X - x1 > 25, kk.root.Position.X - x1)
	T.cmd("eval", "drive", 0, 0, true)
	task.wait(1.2)
	-- Anti-cheat: two samples far above MaxSpeed -> rubber-band to the last good spot.
	local rb0 = Karts.rubberBands
	local good = kk.lastGood
	kk.lastPos, kk.lastT = kk.root.Position - V(K.MaxSpeed * 3, 0, 0), os.clock() - 0.5
	Karts.tick(S, run, 0.1)
	kk.lastPos, kk.lastT = kk.root.Position - V(K.MaxSpeed * 3, 0, 0), os.clock() - 0.5
	Karts.tick(S, run, 0.1)
	T.eq("overspeed -> rubber-band", Karts.rubberBands, rb0 + 1)
	T.check("snapped to last good", (kk.root.Position - good.Position).Magnitude < 3)
	task.wait(0.7)
	T.cmd("eval", "drive")
	T.cmd("eval", "exit")
	T.check("exit leaves the kart", waitFor(function()
		return kk.model:GetAttribute("Driver") == nil
	end, 3) and player:GetAttribute("BC_Driving") == nil)
	local _, st3 = T.cmd("eval", "kart")
	T.check("client back on foot", st3 and st3.driving == false and st3.fireShown == true)
	T.check("not parked away from the spot", kk.model:GetAttribute("Parked") == false)
	-- Park: kart on its spot, drive in and out.
	kk.root.Anchored = true
	kk.model:PivotTo(CFrame.new(kk.spot.pos) * CFrame.Angles(0, math.rad(kk.spot.yaw), 0))
	T.cmd("moveTo", kk.spot.pos + V(0, 3, 7))
	waitFor(function()
		return (player.Character.HumanoidRootPart.Position - kk.spot.pos).Magnitude < 9
	end, 3)
	S.interact.start(player, "drive", kk.model, 10)
	S.interact.tick(S, run, 0, 10.3)
	task.wait(0.8)
	T.cmd("eval", "exit")
	T.check("exit on the spot parks the kart", waitFor(function()
		return kk.model:GetAttribute("Parked") == true
	end, 3) and kk.root.Anchored == true)
	T.cmd("moveTo", V(-150, 3, 20))
	task.wait(0.5)
	Heist.paused = false
end
