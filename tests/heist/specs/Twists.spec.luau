-- Twist engine (pure merge + deterministic pick) and the live run's twist wiring.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local Twists = require(RS.BlackoutCrew.Twists)
local Alarm = require(RS.BlackoutCrew.Alarm)
local S = require(SSS.BlackoutCrew.ServerState)

return function(T)
	local base = { alarmMult = 1, sentryMult = 1, visionMult = 1, bumpMult = { gunfire = 1 } }
	local b = Twists.apply(base, C.Twists.blackout)
	T.near("blackout: bots see less", b.visionMult, 0.6)
	T.check("blackout: no lighting/name in params", b.lighting == nil and b.name == nil)
	T.eq("base untouched", base.visionMult, 1)
	local d = Twists.apply(base, C.Twists.doublePatrol)
	T.check("double patrol: sentries x2 only", d.sentryMult == 2 and d.visionMult == 1 and d.alarmMult == 1)
	local loud = Twists.apply(base, { bumpMult = { gunfire = 2 }, alarmMult = 2 })
	T.check("engine: per-kind + global mults (3C twists)", loud.bumpMult.gunfire == 2 and loud.alarmMult == 2 and base.bumpMult.gunfire == 1)
	T.eq("no twist = base", Twists.apply(base, nil).visionMult, 1)
	T.eq("seed stable", Twists.seed("abc"), Twists.seed("abc"))
	T.check("seed differs", Twists.seed("abc") ~= Twists.seed("abd"))
	local seen = {}
	for i = 1, 200 do
		local id = Twists.pick(Twists.seed("run" .. i), C.Twists)
		seen[id] = (seen[id] or 0) + 1
	end
	T.check("both Build 2 twists get picked", (seen.blackout or 0) > 40 and (seen.doublePatrol or 0) > 40)
	T.eq("pick is deterministic", Twists.pick(123, C.Twists), Twists.pick(123, C.Twists))
	T.eq("force", Twists.pick(1, { Enabled = { "blackout", "doublePatrol" }, Force = "doublePatrol", doublePatrol = {} }), "doublePatrol")
	T.eq("only enabled ids", Twists.pick(1, { Enabled = {} }), nil)

	local run = S.Heist.run
	if not T.check("run", run ~= nil) then
		return
	end
	T.eq("twist published", workspace.HeistState:GetAttribute("Twist"), C.Twists[run.twist].name)
	T.eq("sentry mult follows twist", run.params.sentryMult, run.twist == "doublePatrol" and 2 or 1)
	T.near("vision follows twist", run.params.visionMult, run.twist == "blackout" and 0.6 or 1)
	local want = Alarm.counts(run.countsTier or 1, run.info.crewSize, run.params.sentryMult, C.Enemies)
	T.check("enemy counts use the twist", run.counts and run.counts.sentries == want.sentries,
		run.counts and (run.counts.sentries .. " vs " .. want.sentries .. " @tier " .. tostring(run.countsTier)))
end
