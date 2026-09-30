-- Escape: parking draw rules, repair timing, payout tiers (pure); then on the live run: drone sabotage
-- fill/drain -> sabotaged, repair minigame (server-validated taps), loading heavy loot, pursuit + EMP.
-- (Banking at the gate ends the run, so it's exercised in Zz_Flow.)
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local M = require(RS.BlackoutCrew.HeistMap)
local Parking = require(RS.BlackoutCrew.Parking)
local Repair = require(RS.BlackoutCrew.Repair)
local Payout = require(RS.BlackoutCrew.Payout)
local S = require(SSS.BlackoutCrew.ServerState)
local V = Vector3.new
local RC = C.Repair

return function(T)
	-- Parking draw (§5d)
	local spread, noRepeat, unique, exact = true, true, true, true
	for seed = 1, 300 do
		for n = 1, 4 do
			local who = {}
			for i = 1, n do
				who[i] = { lastObvious = (seed + i) % 2 == 0 }
			end
			local spots = Parking.draw(M.Spots, who, seed)
			if #spots ~= n then
				exact = false
			end
			if n >= 2 and Parking.zoneCount(spots) < 2 then
				spread = false
			end
			local ids = {}
			for i, s in ipairs(spots) do
				if ids[s.id] then
					unique = false
				end
				ids[s.id] = true
				if who[i].lastObvious and s.quality == "obvious" then
					noRepeat = false
				end
			end
		end
	end
	T.check("squad-size spots", exact)
	T.check("2+ players always span >= 2 zones", spread)
	T.check("no obvious spot twice in a row", noRepeat)
	T.check("no shared spots", unique)
	T.eq("same seed, same spots", Parking.draw(M.Spots, { {}, {} }, 7)[2].id, Parking.draw(M.Spots, { {}, {} }, 7)[2].id)
	local varied = {}
	for seed = 1, 40 do
		varied[Parking.draw(M.Spots, { {} }, seed)[1].id] = true
	end
	local nVaried = 0
	for _ in pairs(varied) do
		nVaried += 1
	end
	T.check("spots differ per round", nVaried >= 8, nVaried)

	-- Repair timing (§5d): 3 steps; perfect taps land at zone centre.
	T.check("hit in zone", Repair.hit(10 + 2.9 * 0.6, 10 + 2.9 * 0.6, 10, 2.9, 0.55, RC))
	T.check("miss outside", not Repair.hit(10 + 2.9 * 0.3, 10 + 2.9 * 0.3, 10, 2.9, 0.55, RC))
	T.check("stale stamp rejected", not Repair.hit(10 + 2.9 * 0.6, 10 + 2.9 * 0.6 + RC.Latency + 0.1, 10, 2.9, 0.55, RC))
	T.check("stamp before step start rejected", not Repair.hit(9, 9.1, 10, 2.9, 0.55, RC))
	local function avg(period)
		local tot = 0
		for i = 1, 200 do
			tot += (Repair.zone(i, RC) + RC.ZoneWidth / 2) * period
		end
		return tot / 200 * RC.Steps
	end
	local one, self = avg(RC.Period), avg(RC.SelfPeriod)
	T.check("one teammate ~6 s", one > 4.5 and one < 7, one)
	T.check("solo self-repair ~10 s", self > 8 and self < 11.5, self)
	T.check("owner is slower", Repair.period(true, RC) > Repair.period(false, RC))

	-- Payout tiers (§5d)
	local P, CR = C.Payout, C.Crew
	T.eq("clean = 100% + bonus", Payout.compute({ small = 90, heavy = 600, outcome = "clean", crewSize = 1 }, P, CR), math.floor(90 + 600 * P.HeavyMult.clean))
	T.eq("rough = 90%", Payout.compute({ small = 0, heavy = 600, outcome = "rough", crewSize = 1 }, P, CR), 540)
	T.eq("timed out = 50%", Payout.compute({ small = 0, heavy = 600, outcome = "timeout", crewSize = 1 }, P, CR), 300)
	T.eq("caught = 50%", Payout.compute({ small = 0, heavy = 600, outcome = "caught", crewSize = 1 }, P, CR), 300)
	T.eq("small loot always 100%", Payout.compute({ small = 120, heavy = 0, crewSize = 1 }, P, CR), 120)
	T.eq("crew of 4 = +24%", Payout.compute({ small = 1000, heavy = 0, crewSize = 4 }, P, CR), 1240)
	T.check("avg clean run ~1,000 Credits (§5g)", Payout.compute({ small = 120, heavy = 600, outcome = "clean", crewSize = 2 }, P, CR) >= 800)

	-- Live run
	local Heist = S.Heist
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until (Heist.run and S.karts.byOwner[T.player]) or os.clock() - t0 > 10
	local run = Heist.run
	local player = T.player
	local k = S.karts.byOwner[player]
	if not T.check("kart", run and k) then
		return
	end
	Heist.paused = true
	T.check("spot assigned + published", run.spots[player] ~= nil and player:GetAttribute("BC_Spot") == run.spots[player].id)
	local okG, g = T.cmd("eval", "glow")
	T.check("own spot beacon shown", okG and g.spot == run.spots[player].id and g.own == true)
	T.check("repo drones: 2 at Quiet", S.drones.alive(S.drones.repo) == 2, S.drones.alive(S.drones.repo))
	-- Park a repo drone 25 up / 17 behind the kart, looking at it: continuous sighting fills the ring.
	local d = S.drones.repo[1]
	local kp = k.root.Position
	local dronePos = kp + V(17, 25, 0)
	d.model:PivotTo(CFrame.lookAt(dronePos, dronePos + V(-1, 0, 0)))
	d.ap.Position, d.ao.CFrame = dronePos, CFrame.lookAt(Vector3.zero, V(-1, 0, 0))
	task.wait(0.3)
	T.check("drone sees the kart", S.drones.sees(d, k))
	local full = C.Drones.Repo.SabotageTime[1]
	local function step(dt)
		d.model:PivotTo(CFrame.lookAt(dronePos, dronePos + V(-1, 0, 0))) -- hold it over the kart (tick steers it home)
		S.drones.tick(S, run, dt)
	end
	step(full / 2)
	T.near("fill after half the time", k.fill, 0.5, 0.02)
	T.eq("status spotted", player:GetAttribute("BC_KartStatus"), "spotted")
	d.model:PivotTo(CFrame.new(dronePos + V(0, 0, 400)))
	S.drones.tick(S, run, full / 2)
	T.near("drains at half speed out of sight", k.fill, 0.25, 0.02)
	step(full * 0.8)
	T.check("full ring = sabotaged", k.model:GetAttribute("Sabotaged") == true and k.model:GetAttribute("RoughEver") == true)
	T.eq("status sabotaged", player:GetAttribute("BC_KartStatus"), "sabotaged")
	T.check("sabotaged kart can't be driven", not S.interact.start(player, "drive", k.model, 0))

	-- Repair minigame: REPAIR opens it on the client; server-validated taps; 3 steps.
	T.cmd("moveTo", k.root.Position + V(0, 2, 7))
	local t1 = os.clock()
	repeat
		task.wait(0.05)
	until (player.Character.HumanoidRootPart.Position - k.root.Position).Magnitude < 9 or os.clock() - t1 > 3
	T.check("REPAIR starts", S.interact.start(player, "repair", k.model, 0) and k.repairers[player] ~= nil)
	task.wait(0.4)
	local okR, rs = T.cmd("eval", "repair")
	T.check("client minigame open", okR and rs.open == true and rs.tapShown == true)
	local r = k.repairers[player]
	T.check("owner gets the slow needle", r.period == RC.SelfPeriod)
	local miss = r.t0 + r.period * math.max(0, r.zone - 0.2)
	T.eq("off-zone tap misses", S.karts.repairTap(player, k.model, miss, miss), "miss")
	for i = 1, RC.Steps do
		r = k.repairers[player]
		local tap = r.t0 + r.period * (r.zone + RC.ZoneWidth / 2)
		local res = S.karts.repairTap(player, k.model, tap, tap + 0.1)
		T.eq("step " .. i, res, i < RC.Steps and "step" or "repaired")
	end
	T.check("repaired, still Rough for payout", k.model:GetAttribute("Sabotaged") == false and k.model:GetAttribute("RoughEver") == true)
	task.wait(0.4)
	local _, rs2 = T.cmd("eval", "repair")
	T.check("minigame closes", rs2 and rs2.open == false)
	T.eq("status hidden again", player:GetAttribute("BC_KartStatus"), "hidden")

	-- Load heavy loot onto your kart: banks it there, one per kart.
	local heavy = workspace.HeistLoot:FindFirstChild("Heavy1")
	S.loot.pickup(S, run, player, heavy)
	T.check("LOAD", S.interact.start(player, "load", k.model, 0))
	S.interact.tick(S, run, 0, C.Actions.load.hold + 0.01)
	T.check("loaded on the kart", k.model:GetAttribute("Heavy") == "Heavy1" and player:GetAttribute("BC_Loaded") == true and player:GetAttribute("BC_Heavy") == nil)
	T.check("rides on the kart", heavy.PrimaryPart:FindFirstChild("CarryWeld") ~= nil and heavy:GetAttribute("Loaded") == true)

	-- Pursuit + EMP: a dash spawns pursuers from the free budget; in range they EMP the kart.
	run.dash[player] = { start = workspace:GetServerTimeNow(), min = 0 }
	k.model:SetAttribute("Driver", player.UserId)
	S.drones.tick(S, run, 0.1)
	T.check("pursuit drone joins the dash", S.drones.alive(S.drones.pursuit) >= 1)
	T.check("AI cap respected", S.drones.budget(run) >= 0, S.drones.budget(run))
	local pd = S.drones.pursuit[1]
	local e0 = S.drones.emps
	pd.cooldown = 0
	pd.model:PivotTo(CFrame.new(k.root.Position + V(3, 12, 0)))
	S.drones.tick(S, run, 0.1)
	T.eq("EMP in range", S.drones.emps, e0 + 1)
	T.check("EMP published on the kart", workspace:GetServerTimeNow() < k.model:GetAttribute("EmpUntil"))
	run.dash[player] = nil
	k.model:SetAttribute("Driver", nil)
	S.drones.tick(S, run, 0.1)
	T.eq("pursuers leave when no dash", #S.drones.pursuit, 0)
	T.cmd("moveTo", V(-150, 3, 20))
	task.wait(0.4)
	Heist.paused = false
end
