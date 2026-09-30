-- Runs last (specs sort by name): the real local-mode run ends by crew wipe (§5c fail rule) through the
-- live 10 Hz loop, pays small loot 100% + held heavy loot "caught" 50%, saves, and never pays twice.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local S = require(SSS.BlackoutCrew.ServerState)

return function(T)
	local Heist = S.Heist
	local player = T.player
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until (Heist.run and Heist.run.loot) or os.clock() - t0 > 10
	local run = Heist.run
	T.check("local run started with the test player", run ~= nil and run.players[1] == player)
	if not run then
		return
	end
	T.eq("slot attribute", player:GetAttribute("BC_Slot"), 1)
	T.eq("phase running", workspace.HeistState:GetAttribute("Phase"), "running")
	local heavy = workspace.HeistLoot:FindFirstChild("Heavy1")
	S.loot.pickup(S, run, player, heavy)
	run.loot.small[player] = 60
	local d = S.profiles.loaded[player]
	local before = d.credits
	player:SetAttribute("BC_Override", 0)
	S.crew.down(player)
	local t1 = os.clock()
	repeat
		task.wait(0.05)
	until run.ended or os.clock() - t1 > 3
	T.check("crew wipe ends the run", run.ended and run.outcome == "failed")
	T.eq("phase failed", workspace.HeistState:GetAttribute("Phase"), "failed")
	local want = math.floor(60 + C.Loot.HeavyValue * C.Payout.HeavyMult.caught)
	T.eq("paid: small 100% + heavy caught 50%", d.credits - before, want)
	T.check("second finish pays nothing", Heist.finish(S, "done", { [player] = 999 }) == nil and d.credits - before == want)
	T.eq("run counted", d.heist.runs, 1)

	-- Local mode replays: after ReturnDelay the run resets and a fresh one starts (forced Blackout).
	C.Twists.Force = "blackout"
	local t2 = os.clock()
	repeat
		task.wait(0.2)
	until (Heist.run and Heist.run ~= run) or os.clock() - t2 > C.Heist.ReturnDelay + C.Heist.LocalStartDelay + 10
	C.Twists.Force = nil
	local run2 = Heist.run
	T.check("local run restarts", run2 ~= nil and run2 ~= run and not run2.ended)
	if run2 then
		T.eq("forced twist", run2.twist, "blackout")
		T.near("blackout lighting", game:GetService("Lighting").Brightness, C.Twists.blackout.lighting.Brightness, 1e-3)
		T.eq("twist on HUD state", workspace.HeistState:GetAttribute("Twist"), "BLACKOUT")
		T.check("player reset for the new run", player:GetAttribute("BC_Downed") == nil and player:GetAttribute("BC_HP") == C.Downed.MaxHP
			and player:GetAttribute("BC_Heavy") == nil and player:GetAttribute("BC_Override") == C.Downed.Overrides)
		T.check("fresh loot", workspace.HeistLoot:FindFirstChild("Heavy1") ~= nil and workspace.HeistLoot.Heavy1:GetAttribute("Carrier") == nil)
		T.check("fresh enemies", #S.enemies.list >= 1 and not run2.towerCleared)
		T.eq("service door shut again", S.map.serviceDoor.CanCollide, true)
	end
end
