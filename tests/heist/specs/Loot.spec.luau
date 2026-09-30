-- Loot + carry: pure rules (speeds, noise, context-action priority/validation), then the real run with
-- the test player (the probe moves the client-owned character; the server drives the hold timer).
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local Carry = require(RS.BlackoutCrew.Carry)
local Actions = require(RS.BlackoutCrew.Actions)
local S = require(SSS.BlackoutCrew.ServerState)
local V = Vector3.new
local MV = C.Movement

return function(T)
	T.eq("walk", Carry.walkSpeed({}, MV), 16)
	T.eq("sneak", Carry.walkSpeed({ sneak = true }, MV), 8)
	T.near("heavy ~40% slower", Carry.walkSpeed({ heavy = true }, MV), 9.6)
	T.near("heavy + sneak", Carry.walkSpeed({ heavy = true, sneak = true }, MV), 4.8)
	T.eq("downed crawl", Carry.walkSpeed({ downed = true, heavy = true }, MV), MV.CrawlSpeed)
	T.check("heavy holsters", Carry.holstered({ heavy = true }) and Carry.holstered({ downed = true }) and not Carry.holstered({ sneak = true }))
	T.eq("noise still", Carry.noise({ moving = false }, MV), 0)
	T.eq("noise sneak", Carry.noise({ moving = true, sneak = true }, MV), 6)
	T.eq("noise walk", Carry.noise({ moving = true }, MV), 15)
	T.eq("noise gunfire", Carry.noise({ moving = false, gunfire = true }, MV), 60)

	local A = C.Actions
	local me = { pos = V(0, 0, 0) }
	local world = {
		mates = { { inst = "mate", pos = V(3, 0, 0), downed = true } },
		karts = { { inst = "kart", pos = V(4, 0, 0), mine = false, sabotaged = true } },
		hacks = { { inst = "cam", pos = V(2, 0, 0) } },
		loot = { { inst = "gold", pos = V(1, 0, 0), heavy = true } },
	}
	T.eq("revive beats everything", (Actions.best(me, world, A)), "revive")
	world.mates[1].downed = false
	T.eq("repair next", (Actions.best(me, world, A)), "repair")
	world.karts[1].sabotaged = false
	T.eq("hack before pickup", (Actions.best(me, world, A)), "hack")
	world.hacks[1].hacked = true
	T.eq("pickup", (Actions.best(me, world, A)), "pickup")
	world.loot[1].pos = V(50, 0, 0)
	T.eq("out of reach = nothing", (Actions.best(me, world, A)), nil)
	local carrying = { pos = V(0, 0, 0), heavy = true }
	world.loot[1].pos = V(1, 0, 0)
	T.eq("carrying: can't grab more, can hand off", (Actions.best(carrying, world, A)), "handoff")
	world.karts[1].mine = true
	T.eq("carrying near own kart: load", (Actions.best(carrying, world, A)), "load")
	world.mates, world.karts = {}, {}
	T.eq("carrying alone: drop", (Actions.best(carrying, world, A)), "drop")
	T.eq("downed: override only", (Actions.best({ pos = V(0, 0, 0), downed = true, overrideLeft = 1 }, world, A)), "override")
	T.eq("downed without override: nothing", (Actions.best({ pos = V(0, 0, 0), downed = true, overrideLeft = 0 }, world, A)), nil)
	T.check("driving blocks actions", not Actions.check("pickup", { pos = V(0, 0, 0), driving = true }, world.loot[1], A))
	T.check("no driving a sabotaged kart", not Actions.check("drive", me, { pos = V(1, 0, 0), mine = true, sabotaged = true }, A))
	T.check("no driving someone else's kart", not Actions.check("drive", me, { pos = V(1, 0, 0), mine = false }, A))

	-- Real run
	local Heist = S.Heist
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until (Heist.run and Heist.run.loot) or os.clock() - t0 > 10
	local run = Heist.run
	local player = T.player
	T.check("run with loot", run ~= nil and run.loot ~= nil)
	if not run then
		return
	end
	local I = S.interact
	local root = player.Character.HumanoidRootPart
	local function go(pos)
		T.cmd("moveTo", pos)
		local t = os.clock()
		repeat
			task.wait(0.05)
		until (root.Position - pos).Magnitude < 2.5 or os.clock() - t > 4
		return (root.Position - pos).Magnitude < 2.5
	end
	local heavy = workspace.HeistLoot:FindFirstChild("Heavy1")
	T.check("heavy loot spawned per player", heavy ~= nil and workspace.HeistLoot:FindFirstChild("Heavy2") == nil)
	T.check("service door shut before breach", S.map.serviceDoor.CanCollide == true)
	local far = workspace.HeistLoot:FindFirstChild("Small1")
	T.check("far item refused", not I.start(player, "pickup", far, 0))
	local p = heavy:GetPivot().Position
	T.check("moved to vault", go(V(p.X, 3, p.Z - 4)))
	T.check("hold starts", I.start(player, "pickup", heavy, 0))
	I.tick(S, run, 0, 0.5)
	T.check("not done before hold time", player:GetAttribute("BC_Heavy") == nil and I.holds[player] ~= nil)
	I.tick(S, run, 0, 1.01)
	T.eq("heavy picked up", player:GetAttribute("BC_Heavy"), "Heavy1")
	T.near("heavy walk speed", player.Character.Humanoid.WalkSpeed, 9.6, 1e-3)
	T.check("carried on the back", heavy:GetAttribute("Carrier") == player.UserId and heavy.PrimaryPart:FindFirstChild("CarryWeld") ~= nil)
	local _, why = S.Weapons.fire(player, 999, player.Character.Head.Position, V(0, 0, -1), false)
	T.eq("gun holstered while carrying", why, "holstered")
	T.check("vault breach opens service door", S.map.serviceDoor.CanCollide == false and workspace.HeistState:GetAttribute("ServiceOpen") == true)
	local okProbe, probe = T.cmd("eval", "action")
	T.check("client offers DROP while carrying", okProbe and probe.kind == "drop" and probe.shown == true, probe and probe.kind)
	player:SetAttribute("BC_Sneak", true)
	S.crew.refresh(player)
	T.near("heavy + sneak speed", player.Character.Humanoid.WalkSpeed, 4.8, 1e-3)
	player:SetAttribute("BC_Sneak", nil)
	S.crew.refresh(player)
	T.check("drop", I.start(player, "drop", nil, 10))
	I.tick(S, run, 0, 10.31)
	T.check("dropped", player:GetAttribute("BC_Heavy") == nil and heavy:GetAttribute("Carrier") == nil and heavy.PrimaryPart.Anchored)
	T.check("dropped in front, on the floor", (heavy:GetPivot().Position - root.Position).Magnitude < 7 and math.abs(heavy:GetPivot().Position.Y - 1) < 0.6)
	T.near("speed restored", player.Character.Humanoid.WalkSpeed, 16, 1e-3)
	T.check("gun back", select(2, S.Weapons.fire(player, 999, player.Character.Head.Position, V(0, 0, -1), false)) ~= "holstered")

	-- Walk away mid-hold = cancelled.
	I.start(player, "pickup", heavy, 20)
	go(V(100, 3, 60))
	I.tick(S, run, 0, 20.2)
	T.check("walking away cancels the hold", I.holds[player] == nil and player:GetAttribute("BC_Heavy") == nil)

	local small = workspace.HeistLoot:FindFirstChild("Small1")
	local sp = small.Position
	T.check("moved to desk", go(V(sp.X, 3, sp.Z - 3.5)))
	local okP, pr = T.cmd("eval", "action")
	T.check("client offers GRAB near loot", okP and pr.kind == "pickup" and pr.shown == true, pr and pr.kind)
	I.start(player, "pickup", small, 30)
	I.tick(S, run, 0, 30.5)
	T.check("small loot counts at pickup", player:GetAttribute("BC_Small") == C.Loot.SmallValue and small.Parent == nil)
	go(V(-150, 3, 20))
	local okN, pn = T.cmd("eval", "action")
	T.check("nothing in reach: button hidden", okN and pn.kind == nil and pn.shown == false)

	-- Noise (§5h)
	local now = os.clock()
	T.eq("standing still is silent", S.crew.noise(player, now), 0)
	S.crew.gunfireAt[player] = now
	T.eq("gunfire noise", S.crew.noise(player, now), C.Movement.Noise.Gunfire)
	S.crew.gunfireAt[player] = nil
end
