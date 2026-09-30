-- Runs last (specs sort by name): the real local-mode run with the test player, end to end.
local SSS = game:GetService("ServerScriptService")
local S = require(SSS.BlackoutCrew.ServerState)

return function(T)
	local Heist = S.Heist
	local player = T.player
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until (Heist and Heist.run) or os.clock() - t0 > 10
	local run = Heist and Heist.run
	T.check("local run started with the test player", run ~= nil and run.players[1] == player)
	if not run then
		return
	end
	T.eq("slot attribute", player:GetAttribute("BC_Slot"), 1)
	T.eq("phase running", workspace.HeistState:GetAttribute("Phase"), "running")

	-- Payout + save at run end, granted once.
	local d = S.profiles.loaded[player]
	local before = d.credits
	local g = Heist.finish(S, "done", { [player] = 321 })
	T.check("finish grants", g and g[player] == 321 and d.credits == before + 321)
	T.check("second finish pays nothing", Heist.finish(S, "done", { [player] = 321 }) == nil and d.credits == before + 321)
	T.eq("phase done", workspace.HeistState:GetAttribute("Phase"), "done")
	T.eq("run counted", d.heist.runs, 1)
end
