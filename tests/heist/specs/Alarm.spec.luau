-- Alarm meter (pure), enemy counts (scaling + cap, exhaustive), and the server wiring:
-- real gunfire bumps it, the terminal hack drops a tier, a tier rise speeds lasers + reinforces.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local Alarm = require(RS.BlackoutCrew.Alarm)
local S = require(SSS.BlackoutCrew.ServerState)
local AC, E = C.Alarm, C.Enemies

return function(T)
	local a = Alarm.new(AC, 1)
	T.eq("starts quiet", a:tier(), 1)
	T.check("gunfire > downed > camera", AC.Bumps.gunfire > AC.Bumps.downed and AC.Bumps.downed > AC.Bumps.camera)
	a:bump("gunfire")
	T.eq("gunfire bump", a.value, AC.Bumps.gunfire)
	a:bump("nonsense")
	T.eq("unknown bump ignored", a.value, AC.Bumps.gunfire)
	a:creep(10)
	T.near("creep", a.value, AC.Bumps.gunfire + AC.Creep * 10)
	a.value = AC.PerTier - 1
	T.eq("tier 2 at threshold", a:bump("camera"), 2)
	a:creep(1e6)
	T.check("capped at Purge", a.value == AC.PerTier * #AC.Tiers and a:tier() == 3)
	T.eq("hack drops one tier", a:hackDrop(), 2)
	T.eq("hack again", a:hackDrop(), 1)
	T.eq("hack at quiet empties", (function()
		a.value = 40
		a:hackDrop()
		return a.value
	end)(), 0)
	local fast = Alarm.new(AC, 2)
	fast:bump("camera")
	T.eq("mult scales bumps", fast.value, AC.Bumps.camera * 2)
	local loud = Alarm.new(AC, 1)
	loud:bump("gunfire", 2)
	T.eq("per-kind mult", loud.value, AC.Bumps.gunfire * 2)

	local full = Alarm.counts(1, 4, 1, E)
	T.check("quiet full crew", full.sentries == 2 and full.watchers == 0 and full.repo == 2)
	local solo = Alarm.counts(1, 1, 1, E)
	T.check("solo x0.5", solo.sentries == 1)
	local duo = Alarm.counts(2, 2, 1, E)
	T.check("duo x0.75", duo.sentries == 2 and duo.watchers == 1)
	T.check("repo 2 +1 per tier", Alarm.counts(2, 4, 1, E).repo == 3 and Alarm.counts(3, 4, 1, E).repo == 4)
	local capOk, least = true, true
	for tier = 1, 3 do
		for crew = 1, 4 do
			for _, mult in ipairs({ 1, 2 }) do
				local c = Alarm.counts(tier, crew, mult, E)
				if c.sentries + c.watchers + c.repo > E.Cap then
					capOk = false
				end
				if c.sentries < 1 then
					least = false
				end
			end
		end
	end
	T.check("cap never exceeded (all tiers x crews x twist)", capOk)
	T.check("always at least one sentry", least)
	local dp = Alarm.counts(1, 4, 2, E)
	T.eq("double patrol doubles sentries", dp.sentries, 4)

	-- Server wiring
	local Heist = S.Heist
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until (Heist.run and Heist.run.alarm) or os.clock() - t0 > 10
	local run = Heist.run
	if not T.check("run has an alarm", run and run.alarm ~= nil) then
		return
	end
	Heist.paused = true
	local player = T.player
	run.alarm.value = 0
	local ok = S.Weapons.fire(player, S.Weapons.state(player).lastSeq + 1, player.Character.Head.Position, Vector3.new(0, 0, -1), false)
	if ok then
		S.Weapons.onFired(player, player.Character.Head.Position)
	end
	T.eq("real gunfire bumps the alarm", run.alarm.value, AC.Bumps.gunfire)
	T.eq("published", workspace.HeistState:GetAttribute("Alarm"), AC.Bumps.gunfire)
	T.check("gunfire is loud", S.crew.noise(player, os.clock()) == C.Movement.Noise.Gunfire)
	S.crew.gunfireAt[player] = nil
	local sentries0 = S.enemies.alive("sentry")
	run.alarm.value = AC.PerTier - 1
	S.alarm.bump("camera")
	T.eq("tier published", workspace.HeistState:GetAttribute("Tier"), 2)
	T.eq("lasers speed up", workspace.HeistState:GetAttribute("LaserSpeed"), C.Lasers.SpeedByTier[2])
	local want = Alarm.counts(2, run.info.crewSize, run.params.sentryMult, E)
	T.check("tier rise reinforces", S.enemies.alive("sentry") == want.sentries and S.enemies.alive("watcher") == want.watchers
		and S.enemies.alive("sentry") >= sentries0, S.enemies.alive("sentry") .. "/" .. S.enemies.alive("watcher"))
	local term = S.map.terminal
	T.check("terminal hack drops a tier", S.interact.effects.hack(S, run, player, term) and run.alarm:tier() == 1)
	T.check("terminal cools down", term:GetAttribute("Hacked") == true)
	local me, world = require(RS.BlackoutCrew.Actions).gather(player)
	local entry = require(RS.BlackoutCrew.Actions).entry(world, term)
	T.check("cooling terminal not hackable", entry and not require(RS.BlackoutCrew.Actions).check("hack", { pos = entry.pos }, entry, C.Actions))
	run.alarm.value = 0
	S.alarm.bump("camera")
	Heist.paused = false
end
