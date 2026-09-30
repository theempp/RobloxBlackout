-- Runs last. Full local-mode flow on the real run: dash -> gate (anti-teleport: too fast isn't banked)
-- -> banked -> run ends -> payout saved; replay -> fresh run (forced Blackout) -> crew wipe -> "caught".
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local M = require(RS.BlackoutCrew.HeistMap)
local Payout = require(RS.BlackoutCrew.Payout)
local S = require(SSS.BlackoutCrew.ServerState)
local V = Vector3.new

local function waitRun(Heist, notThis, t)
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until (Heist.run and Heist.run ~= notThis and not Heist.run.ended and S.karts.byOwner[game:GetService("Players"):GetPlayers()[1]]) or os.clock() - t0 > t
	return Heist.run ~= notThis and Heist.run or nil
end

return function(T)
	local Heist = S.Heist
	local player = T.player
	local run = waitRun(Heist, nil, 10)
	if not T.check("local run with the test player", run ~= nil and run.players[1] == player) then
		return
	end
	T.eq("slot attribute", player:GetAttribute("BC_Slot"), 1)
	T.eq("phase running", workspace.HeistState:GetAttribute("Phase"), "running")
	Heist.paused = true
	local k = S.karts.byOwner[player]
	local d = S.profiles.loaded[player]
	local before = d.credits
	run.loot.breached = true
	run.loot.small[player] = 90
	if not k.model:GetAttribute("Heavy") then -- Escape.spec loaded Heavy1 already; make sure
		local h = workspace.HeistLoot:FindFirstChild("Heavy1")
		S.loot.pickup(S, run, player, h)
		S.loot.load(S, run, player, k.model)
	end
	-- Drive off the spot -> dash starts (server can't move a driven kart, so it's placed first).
	k.root.Anchored = true
	k.model:PivotTo(CFrame.new(k.spot.pos + V(30, 1.4, 0)))
	k.model:SetAttribute("Driver", player.UserId)
	S.escape.tick(S, run)
	T.check("dash starts off the spot", run.dash[player] ~= nil and player:GetAttribute("BC_DashEnd") ~= nil)
	T.eq("HUD step: dash", player:GetAttribute("BC_Step"), "dash")
	-- Teleport straight into the gate: faster than possible -> not banked.
	k.model:PivotTo(CFrame.new(M.Gate.pos + V(0, 1.4, 0)))
	S.escape.tick(S, run)
	T.check("too-fast arrival isn't banked", run.resolved[player] == nil and run.suspicious == 1)
	run.dash[player].start -= run.dash[player].min + 1
	local wantGate = Payout.compute({ small = 90, heavy = C.Loot.HeavyValue, outcome = k.model:GetAttribute("RoughEver") and "rough" or "clean",
		crewSize = 1, difficulty = 1 }, C.Payout, C.Crew)
	Heist.paused = false
	local t1 = os.clock()
	repeat
		task.wait(0.05)
	until run.ended or os.clock() - t1 > 3
	T.check("banked at the gate ends the run", run.ended and run.outcome == "done" and run.resolved[player] == "gate")
	T.eq("outcome rough (sabotaged earlier)", run.outcomes[player], k.model:GetAttribute("RoughEver") and "rough" or "clean")
	T.eq("payout saved: small 100% + heavy tier", d.credits - before, wantGate)
	T.eq("phase done", workspace.HeistState:GetAttribute("Phase"), "done")
	T.check("second finish pays nothing", Heist.finish(S, "done", { [player] = 999 }) == nil and d.credits - before == wantGate)
	T.eq("run counted", d.heist.runs, 1)
	k.model:SetAttribute("Driver", nil)

	-- Local mode replays: after ReturnDelay a fresh run starts (forced Blackout).
	C.Twists.Force = "blackout"
	local run2 = waitRun(Heist, run, C.Heist.ReturnDelay + C.Heist.LocalStartDelay + 10)
	C.Twists.Force = nil
	if not T.check("local run restarts", run2 ~= nil) then
		return
	end
	T.eq("forced twist", run2.twist, "blackout")
	T.near("blackout lighting", game:GetService("Lighting").Brightness, C.Twists.blackout.lighting.Brightness, 1e-3)
	T.eq("twist on HUD state", workspace.HeistState:GetAttribute("Twist"), "BLACKOUT")
	T.check("player reset for the new run", player:GetAttribute("BC_Downed") == nil and player:GetAttribute("BC_HP") == C.Downed.MaxHP
		and player:GetAttribute("BC_Heavy") == nil and player:GetAttribute("BC_Loaded") == nil and player:GetAttribute("BC_Resolved") == nil)
	T.check("fresh loot", workspace.HeistLoot:FindFirstChild("Heavy1") ~= nil and workspace.HeistLoot.Heavy1:GetAttribute("Carrier") == nil)
	T.check("fresh enemies + drones", #S.enemies.list >= 1 and not run2.towerCleared and S.drones.alive(S.drones.repo) >= 2)
	T.check("fresh kart, not sabotaged", S.karts.byOwner[player] and S.karts.byOwner[player].model:GetAttribute("RoughEver") == false)
	T.eq("service door shut again", S.map.serviceDoor.CanCollide, true)

	-- Crew wipe (§5c): small 100% + held heavy "caught" 50%.
	local before2 = d.credits
	S.loot.pickup(S, run2, player, workspace.HeistLoot.Heavy1)
	run2.loot.small[player] = 60
	player:SetAttribute("BC_Override", 0)
	S.crew.down(player)
	local t2 = os.clock()
	repeat
		task.wait(0.05)
	until run2.ended or os.clock() - t2 > 3
	T.check("crew wipe ends the run", run2.ended and run2.outcome == "failed")
	T.eq("phase failed", workspace.HeistState:GetAttribute("Phase"), "failed")
	T.eq("paid: small 100% + heavy caught 50%", d.credits - before2, math.floor(60 + C.Loot.HeavyValue * C.Payout.HeavyMult.caught))
	T.eq("two runs counted", d.heist.runs, 2)
end
