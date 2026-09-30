-- 2 real clients in one heist (ExecuteMultiplayerTestAsync): duo scaling, slots + colours, parking spread,
-- teammate revive, hand-off, recall with a teammate standing (no wipe), the 2nd client drives its own kart
-- (its own physics), both HUDs show 2 cards + a slot-coloured tag, then both bank with the duo bonus.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local Alarm = require(RS.BlackoutCrew.Alarm)
local Payout = require(RS.BlackoutCrew.Payout)
local Parking = require(RS.BlackoutCrew.Parking)
local M = require(RS.BlackoutCrew.HeistMap)
local S = require(SSS.BlackoutCrew.ServerState)
local V = Vector3.new

local function waitFor(cond, t)
	local t0 = os.clock()
	repeat
		task.wait(0.05)
	until cond() or os.clock() - t0 > t
	return cond()
end

return function(T)
	T.eq("2 clients connected", #T.players, 2)
	local Heist = S.Heist
	waitFor(function()
		return Heist.run ~= nil and S.karts.byOwner[T.players[1]] ~= nil and S.karts.byOwner[T.players[2]] ~= nil
	end, 20)
	local run = Heist.run
	if not T.check("duo run started", run ~= nil and #run.players == 2) then
		return
	end
	local a, b = run.players[1], run.players[2] -- slot order
	T.check("both clients ready", T.clients[a] and T.clients[a].ready and T.clients[b] and T.clients[b].ready)
	T.check("slots 1 and 2", a:GetAttribute("BC_Slot") == 1 and b:GetAttribute("BC_Slot") == 2)
	T.eq("crew size 2", run.info.crewSize, 2)
	local want = Alarm.counts(1, 2, run.params.sentryMult, C.Enemies)
	T.eq("duo scaling (x0.75)", S.enemies.alive("sentry"), want.sentries)
	T.check("parking spots from 2 zones", Parking.zoneCount({ run.spots[a], run.spots[b] }) == 2)
	Heist.paused = true
	local I = S.interact
	local function near(p, q, off)
		local r = q.Character.HumanoidRootPart.Position
		T.cmdTo(p, "moveTo", r + (off or V(3, 0, 0)))
		return waitFor(function()
			return (p.Character.HumanoidRootPart.Position - r).Magnitude < 6
		end, 4)
	end
	-- HUDs: both clients show two squad cards + one teammate tag in the right colour.
	for _, p in ipairs({ a, b }) do
		local ok, h = false, nil
		waitFor(function()
			ok, h = T.cmdTo(p, "eval", "hud")
			return ok and h and #h.cards == 2 and h.tags == 1
		end, 4)
		T.check("HUD: 2 cards + teammate tag on slot " .. p:GetAttribute("BC_Slot"), ok and #h.cards == 2 and h.tags == 1)
		T.check("HUD colours slot 1/2", ok and h.colors[1]:upper() == C.Colors.Slots[1]:ToHex():upper() and h.colors[2]:upper() == C.Colors.Slots[2]:ToHex():upper())
	end
	-- Revive: A down, B holds REVIVE for 3 s.
	S.crew.down(a)
	T.check("B moved to A", near(b, a))
	T.check("REVIVE starts", I.start(b, "revive", a, 0))
	I.tick(S, run, 0, C.Actions.revive.hold - 0.2)
	T.check("not before 3 s", a:GetAttribute("BC_Downed") == true)
	I.tick(S, run, 0, C.Actions.revive.hold + 0.01)
	T.check("teammate revive", a:GetAttribute("BC_Downed") == nil and a:GetAttribute("BC_HP") == C.Downed.ReviveHP)
	T.eq("revive kept A's Override", a:GetAttribute("BC_Override"), C.Downed.Overrides)
	-- Hand-off: A carries the heavy item, gives it to B.
	local heavy = workspace.HeistLoot:FindFirstChild("Heavy1")
	S.loot.pickup(S, run, a, heavy)
	T.check("A carries", a:GetAttribute("BC_Heavy") == "Heavy1")
	T.check("GIVE starts", I.start(a, "handoff", b, 10))
	I.tick(S, run, 0, 10 + C.Actions.handoff.hold + 0.01)
	T.check("hand-off", a:GetAttribute("BC_Heavy") == nil and b:GetAttribute("BC_Heavy") == "Heavy1" and heavy:GetAttribute("Carrier") == b.UserId)
	T.near("B slowed, A free", b.Character.Humanoid.WalkSpeed + a.Character.Humanoid.WalkSpeed, C.Movement.WalkSpeed * (1 + C.Movement.HeavySpeedMult), 1e-3)
	-- Recall with a teammate standing: no wipe; A comes back at the entrance.
	a:SetAttribute("BC_Override", 0)
	S.crew.down(a)
	a:SetAttribute("BC_BleedEnd", workspace:GetServerTimeNow() - 1)
	S.crew.tick(S, run, 0.1)
	T.check("A recalled, run goes on", a:GetAttribute("BC_Recall") ~= nil and not run.ended)
	a:SetAttribute("BC_Recall", workspace:GetServerTimeNow() - 1)
	S.crew.tick(S, run, 0.1)
	T.check("A back up at the tower entrance", a:GetAttribute("BC_Recall") == nil and a.Character
		and (a.Character.HumanoidRootPart.Position - S.map.towerSpawn.Position).Magnitude < 8)
	-- B loads onto B's kart, drives it on B's own client.
	local kb = S.karts.byOwner[b]
	T.check("B next to own kart", (function()
		T.cmdTo(b, "moveTo", kb.root.Position + V(0, 2, 7))
		return waitFor(function()
			return (b.Character.HumanoidRootPart.Position - kb.root.Position).Magnitude < 9
		end, 4)
	end)())
	I.start(b, "load", kb.model, 20)
	I.tick(S, run, 0, 20 + C.Actions.load.hold + 0.01)
	T.check("B loaded", kb.model:GetAttribute("Heavy") == "Heavy1")
	I.start(b, "drive", kb.model, 30)
	I.tick(S, run, 0, 30.3)
	T.check("B driving", kb.model:GetAttribute("Driver") == b.UserId)
	local x0 = kb.root.Position.X
	waitFor(function()
		local ok, st = T.cmdTo(b, "eval", "kart")
		return ok and st.driving
	end, 3)
	T.cmdTo(b, "eval", "drive", 1, 0, false)
	T.check("2nd client drives its own kart", waitFor(function()
		return kb.root.Position.X - x0 > 20
	end, 4), kb.root.Position.X - x0)
	T.cmdTo(b, "eval", "drive", 0, 0, true)
	task.wait(0.8)
	T.cmdTo(b, "eval", "drive")
	-- Both bank: dash started long enough ago, karts at the gate (A's kart placed; A seated).
	run.loot.breached = true
	run.loot.small[a], run.loot.small[b] = 60, 30
	local ka = S.karts.byOwner[a]
	local credits0 = { [a] = S.profiles.loaded[a].credits, [b] = S.profiles.loaded[b].credits }
	for _, p in ipairs({ a, b }) do
		local k = S.karts.byOwner[p]
		run.dash[p] = { start = workspace:GetServerTimeNow() - 60, min = 0 }
		k.model:SetAttribute("Driver", p.UserId)
		if p == a then
			ka.root.Anchored = true
			ka.model:PivotTo(CFrame.new(M.Gate.pos + V(0, 1.4, 0)))
		end
	end
	T.cmdTo(b, "eval", "exit")
	waitFor(function()
		return kb.model:GetAttribute("Driver") == nil
	end, 3)
	kb.root.Anchored = true
	kb.model:PivotTo(CFrame.new(M.Gate.pos + V(0, 1.4, 8)))
	kb.model:SetAttribute("Driver", b.UserId)
	Heist.paused = false
	T.check("both banked -> run ends", waitFor(function()
		return run.ended
	end, 4) and run.outcome == "done")
	local wantA = Payout.compute({ small = 60, heavy = 0, crewSize = 2, difficulty = 1 }, C.Payout, C.Crew)
	local wantB = Payout.compute({ small = 30, heavy = C.Loot.HeavyValue, outcome = "clean", crewSize = 2, difficulty = 1 }, C.Payout, C.Crew)
	T.eq("A paid (duo bonus +8%)", S.profiles.loaded[a].credits - credits0[a], wantA)
	T.eq("B paid clean heavy + bonus", S.profiles.loaded[b].credits - credits0[b], wantB)
end
