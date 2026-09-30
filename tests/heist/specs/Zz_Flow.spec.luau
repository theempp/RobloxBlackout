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
end
