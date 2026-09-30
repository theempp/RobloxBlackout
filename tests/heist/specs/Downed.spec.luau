-- Health, downed, Override, recall (§5c) on the real player; the fail rule as a predicate
-- (the full crew-wipe run end is exercised last, in Zz_Flow). Loop paused: this spec owns the clock.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local S = require(SSS.BlackoutCrew.ServerState)
local D = C.Downed

return function(T)
	local Heist = S.Heist
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until (Heist.run and Heist.run.alarm) or os.clock() - t0 > 10
	local run = Heist.run
	if not T.check("run", run ~= nil) then
		return
	end
	Heist.paused = true
	local player = T.player
	local Crew, I = S.crew, S.interact
	T.eq("full health", player:GetAttribute("BC_HP"), D.MaxHP)
	T.eq("one Override", player:GetAttribute("BC_Override"), D.Overrides)
	Crew.damage(player, 30, "test")
	T.eq("damage", player:GetAttribute("BC_HP"), 70)
	Crew.lastHit[player] = os.clock() - D.RegenDelay - 1
	Crew.tick(S, run, 1)
	T.eq("regen after delay", player:GetAttribute("BC_HP"), 70 + D.RegenRate)
	run.alarm.value = 0
	Crew.damage(player, 500, "test")
	T.check("downed at 0", player:GetAttribute("BC_Downed") == true and player:GetAttribute("BC_HP") == 0)
	T.near("bleed-out timer", player:GetAttribute("BC_BleedEnd") - workspace:GetServerTimeNow(), D.BleedOut, 0.5)
	T.eq("downed bumps the alarm (medium)", run.alarm.value, C.Alarm.Bumps.downed)
	T.near("crawl", player.Character.Humanoid.WalkSpeed, C.Movement.CrawlSpeed, 1e-3)
	T.eq("can't shoot downed", select(2, S.Weapons.fire(player, 6000, player.Character.Head.Position, Vector3.new(0, 0, -1), false)), "holstered")
	Crew.damage(player, 10, "test")
	T.eq("no damage while downed", player:GetAttribute("BC_HP"), 0)
	T.check("downed + Override left = not wiped", not Crew.wiped(run))
	T.check("Override hold", I.start(player, "override", nil, 0))
	I.tick(S, run, 0, C.Actions.override.hold + 0.01)
	T.check("Override revives", not player:GetAttribute("BC_Downed") and player:GetAttribute("BC_HP") == D.ReviveHP and player:GetAttribute("BC_Override") == 0)
	T.near("walk speed back", player.Character.Humanoid.WalkSpeed, C.Movement.WalkSpeed, 1e-3)
	Crew.down(player)
	T.check("no Override left: can't self-revive", not I.start(player, "override", nil, 1))
	T.check("whole crew down, no Override = wiped", Crew.wiped(run))
	-- Recall (driven directly: ticking here would end the run on the wipe rule)
	Crew.recall(run, player)
	T.check("recalling", player:GetAttribute("BC_Recall") ~= nil and player:GetAttribute("BC_Downed") == nil)
	T.check("recalling counts as down", Crew.wiped(run))
	local oldChar = player.Character
	Crew.respawn(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	T.check("respawned as a new character", player.Character ~= oldChar and root ~= nil)
	T.check("at the tower entrance", root and (root.Position - S.map.towerSpawn.Position).Magnitude < 8, root and tostring(root.Position))
	T.check("back up, full HP", player:GetAttribute("BC_Recall") == nil and player:GetAttribute("BC_HP") == D.MaxHP)
	T.check("not wiped once standing", not Crew.wiped(run))
	player:SetAttribute("BC_Override", D.Overrides)
	T.cmd("moveTo", Vector3.new(-150, 3, 20)) -- back to the arrival spawn for later specs
	task.wait(0.5)
	run.alarm.value = 0
	Heist.paused = false
end
