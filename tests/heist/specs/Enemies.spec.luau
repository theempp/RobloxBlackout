-- Perception (pure) + the real tower AI driven step by step (loop paused): spot time, alert + sighting
-- bump + fire, walls block sight, noise draws investigation, cameras spot + call bots, hacked cameras
-- are blind, killed bots stay down, downed players are ignored, tower AI streams out after the breach.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local Perception = require(RS.BlackoutCrew.Perception)
local S = require(SSS.BlackoutCrew.ServerState)
local Targets = require(SSS.BlackoutCrew.Targets)
local V = Vector3.new
local EC = C.Enemies

return function(T)
	local look = V(0, 0, -1)
	T.check("in cone ahead", Perception.inCone(V(0, 0, 0), look, V(0, 0, -10), 70, 35))
	T.check("edge of 70 deg cone", Perception.inCone(V(0, 0, 0), look, V(math.tan(math.rad(34)) * 10, 0, -10), 70, 35)
		and not Perception.inCone(V(0, 0, 0), look, V(math.tan(math.rad(36)) * 10, 0, -10), 70, 35))
	T.check("out of range", not Perception.inCone(V(0, 0, 0), look, V(0, 0, -36), 70, 35))
	T.check("behind", not Perception.inCone(V(0, 0, 0), look, V(0, 0, 5), 70, 35))
	T.check("hears within noise radius", Perception.hears(V(0, 0, 0), V(0, 0, 14), 15) and not Perception.hears(V(0, 0, 0), V(0, 0, 16), 15))
	T.check("silence is silent", not Perception.hears(V(0, 0, 0), V(0, 0, 0), 0))
	local def = { yaw = 30, sweep = 45 }
	local lo, hi = math.huge, -math.huge
	for t = 0, 8, 0.1 do
		local y = Perception.cameraYaw(def, t, 8)
		lo, hi = math.min(lo, y), math.max(hi, y)
	end
	T.check("camera sweeps 90 deg (+-45)", math.abs(lo - (-15)) < 0.5 and math.abs(hi - 75) < 0.5)
	local sf, sp = Perception.accumulate(0, true, 0.3, 0.6)
	T.check("spot needs SpotTime", sf == 0.3 and not sp and select(2, Perception.accumulate(sf, true, 0.3, 0.6)))
	T.eq("losing sight resets", (Perception.accumulate(0.5, false, 0.1, 0.6)), 0)

	local Heist = S.Heist
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until (Heist.run and Heist.run.alarm) or os.clock() - t0 > 10
	local run = Heist.run
	local E = S.enemies
	local e
	for _, x in ipairs(E.list) do
		if x.kind == "sentry" and not x.dead then
			e = x
			break
		end
	end
	T.eq("4 cameras", #E.cameras, 4)
	if not T.check("a sentry is patrolling", e ~= nil) then
		return
	end
	T.check("sentry is a shootable robot", e.model:GetAttribute("Health") == EC.Sentry.Health and e.model:FindFirstChild("Head") ~= nil
		and game:GetService("CollectionService"):HasTag(e.model, "BC_Target"))
	Heist.paused = true
	local player = T.player
	-- Park the sentry in the lobby facing -X (no walls within 30 studs that way).
	local at = V(110, EC.Sentry.Hover, 65)
	e.model:PivotTo(CFrame.lookAt(at, at + V(-1, 0, 0)))
	e.ap.Position = at
	e.ao.CFrame = CFrame.lookAt(Vector3.zero, V(-1, 0, 0))
	e.state, e.seen, e.spottedAt, e.nextShot = "patrol", {}, {}, 0
	e.model:SetAttribute("State", "patrol")
	task.wait(0.3)
	local eye = e.model.Head.Position
	local front = { p = player, head = eye + V(-12, -0.5, 0), root = eye + V(-12, -2, 0) }
	run.alarm.value = 0
	local hp0 = player:GetAttribute("BC_HP")
	local now = os.clock()
	E.think(run, e, 0.3, now, workspace:GetServerTimeNow(), { front })
	T.check("not spotted before SpotTime", e.state ~= "alert")
	E.think(run, e, 0.4, now + 0.4, workspace:GetServerTimeNow(), { front })
	T.eq("spotted -> alert", e.state, "alert")
	T.eq("sighting bumps the alarm", run.alarm.value, C.Alarm.Bumps.sighting)
	T.eq("alert sentry fires", player:GetAttribute("BC_HP"), hp0 - EC.Sentry.Damage)
	T.check("shot published for tracers", e.model:GetAttribute("ShotAt") ~= nil and e.model:GetAttribute("TargetId") == player.UserId)
	T.eq("eye turns red", e.eye.Color, Color3.fromRGB(255, 40, 60))
	E.think(run, e, 0.1, now + 0.5, workspace:GetServerTimeNow(), { front })
	T.eq("fire interval respected", player:GetAttribute("BC_HP"), hp0 - EC.Sentry.Damage)
	E.think(run, e, 0.1, now + 0.4 + EC.Sentry.FireInterval + 0.01, workspace:GetServerTimeNow(), { front })
	T.eq("fires again after interval", player:GetAttribute("BC_HP"), hp0 - 2 * EC.Sentry.Damage)
	E.think(run, e, 0.1, now + 5, workspace:GetServerTimeNow(), { front })
	T.eq("same target: no second sighting bump", run.alarm.value, C.Alarm.Bumps.sighting)
	-- Losing the target: out of sight for LoseTime -> investigate -> patrol.
	E.think(run, e, 0.1, now + 10, workspace:GetServerTimeNow(), {})
	T.eq("target gone -> patrol", e.state, "patrol")
	T.check("walls block sight", not E.clear(V(100, 5, 65), V(50, 5, 110)) and E.clear(V(110, 5, 65), V(80, 5, 65)))
	local behind = { p = player, head = eye + V(10, -0.5, 0), root = eye + V(10, -2, 0) }
	E.think(run, e, 0.1, now + 11, workspace:GetServerTimeNow(), { behind })
	T.eq("quiet player behind: unnoticed", e.state, "patrol")
	S.crew.gunfireAt[player] = os.clock()
	E.think(run, e, 0.1, os.clock(), workspace:GetServerTimeNow(), { behind })
	T.eq("gunfire behind: investigate", e.state, "investigate")
	S.crew.gunfireAt[player] = nil
	-- Cameras
	local c = E.cameras[1]
	local sNow = workspace:GetServerTimeNow()
	local cl = Perception.look(Perception.cameraYaw(c.def, sNow, EC.Camera.Period), EC.Camera.Pitch)
	local inView = { p = player, head = c.def.pos + cl * 15, root = c.def.pos + cl * 15 - V(0, 1.5, 0) }
	run.alarm.value = 0
	c.cooldown, c.seen = 0, {}
	E.cameraStep(run, c, 0.5, os.clock(), sNow, { inView })
	T.eq("camera needs SpotTime", run.alarm.value, 0)
	E.cameraStep(run, c, 0.5, os.clock(), sNow, { inView })
	T.eq("camera spot = small bump", run.alarm.value, C.Alarm.Bumps.camera)
	T.check("camera spot published", c.model:GetAttribute("SpottedAt") ~= nil)
	c.model:SetAttribute("Hacked", true)
	c.cooldown, c.seen = 0, {}
	E.cameraStep(run, c, 1, os.clock(), sNow, { inView })
	E.cameraStep(run, c, 1, os.clock(), sNow, { inView })
	T.eq("hacked camera is blind", run.alarm.value, C.Alarm.Bumps.camera)
	-- Downed players are ignored; killed bots stay down.
	S.crew.down(player)
	local hpD = player:GetAttribute("BC_HP")
	E.tick(S, run, 0.1)
	T.eq("downed player not shot", player:GetAttribute("BC_HP"), hpD)
	S.crew.revive(player)
	Targets.damage(e.model, 99999)
	E.tick(S, run, 0.1)
	T.check("killed sentry marked dead", e.dead == true)
	task.wait(C.Range.RespawnTime + 0.5)
	T.check("NoRespawn: stays down", e.model:GetAttribute("Down") == true)
	-- Breached + nobody inside -> tower AI streams out (budget freed for the escape).
	run.loot.breached = true
	E.tick(S, run, 0.1)
	T.check("tower AI streams out", #E.list == 0 and run.towerCleared == true and workspace.HeistState:GetAttribute("TowerCleared") == true)
	run.loot.breached = false
	run.alarm.value = 0
	S.alarm.bump("camera")
	run.alarm.value = 0
	Heist.paused = false
end
