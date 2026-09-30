-- Kart: input validation, physics on a server-owned test kart (south outer road), the real
-- driver-owned path (client steps physics via the probe), parking on exit, and the overspeed rubber-band.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local KartPhysics = require(RS.BlackoutCrew.KartPhysics)
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
	local start = CFrame.new(260, 2.5, -210) * CFrame.Angles(0, math.rad(-90), 0)
	local m, root, seat = Karts.build(player, 4, start)
	local k = { model = m, root = root, seat = seat, owner = player, slot = 4, spot = { pos = V(0, 0, 0) }, state = KartPhysics.newState(),
		repairers = {}, steps = 0, idleT = 0, strikes = 0, testInput = { t = 0, s = 0, b = true } }
	table.insert(Karts.list, k)
	root.Anchored = false
	root:SetNetworkOwner(nil)
	task.wait(1.5)
	local rideY = root.Position.Y - 0.4 -- chassis bottom above the road
	T.check("suspension holds the chassis up", rideY > 0.2 and rideY < 1.2, rideY)
	T.check("settles upright", root.CFrame.UpVector.Y > 0.97)
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
	kk.model:PivotTo(CFrame.new(kk.spot.pos + V(0, 1.4, 0)) * CFrame.Angles(0, math.rad(kk.spot.yaw), 0))
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
