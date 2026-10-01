local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)
local Rules = require(RS.BlackoutCrew.Rules)
local Map = require(RS.BlackoutCrew.GarageMap)
local S = require(game.ServerScriptService.BlackoutCrew.ServerState)
return function(T)
	local p, G, K = T.player, S.Garage, S.GarageKarts
	local d = S.profiles.loaded[p]
	local function waitFor(fn, seconds)
		local deadline = os.clock() + (seconds or 3)
		repeat if fn() then return true end; task.wait(0.05) until os.clock() > deadline
		return false
	end
	local function move(at)
		local ok = T.cmd("moveTo", at)
		return ok and waitFor(function() return (p.Character.HumanoidRootPart.Position - at).Magnitude < 4 end)
	end
	local clean = Rules.clean({ schemaVersion = 2, credits = 42 })
	T.check("old saves gain onboarding without losing credits", not clean.tutorial.done and clean.credits == 42)
	T.check("only boolean completion is accepted", not Rules.clean({ tutorial = { done = "true" } }).tutorial.done)
	T.check("completion persists through validation", Rules.clean({ tutorial = { done = true } }).tutorial.done)
	T.check("garage built with tall rooms and showcase", Map.model:FindFirstChild("HallCeiling") and Map.model:FindFirstChild("DroneShowcase") ~= nil)
	local matte, lights = true, 0
	for _, x in ipairs(Map.model:GetDescendants()) do
		if x:IsA("BasePart") and x.Material == Enum.Material.Neon then matte = false end
		if x:IsA("Light") then lights += 1 end
	end
	T.check("garage has no neon or dynamic lights", matte and lights == 0)
	local continuous, low, high = true, math.huge, -math.huge
	for i, segment in ipairs(Map.segments) do
		local nextSegment = Map.segments[i % #Map.segments + 1]
		continuous = continuous and (segment.finish.Position - nextSegment.start.Position).Magnitude < 0.01
		low, high = math.min(low, segment.start.Y), math.max(high, segment.start.Y)
	end
	T.check("track closes without endpoint gaps", continuous)
	T.check("track has multiple levels", high - low >= 18)
	T.check("shipping spawn faces roll-up door", Map.spawn.CFrame.LookVector:Dot((Map.door.Position - Map.spawn.Position).Unit) > 0.98)
	local _, ui = T.cmd("garageUI")
	T.check("garage client and menu initialise", ui and ui.ready and ui.menu)
	local okMenus, menus = T.cmd("menus")
	T.check("armory, settings and wheel are mutually exclusive", okMenus and menus.exclusive)
	T.check("menus brake driving input", okMenus and menus.brakes)
	local saved = { guns = d.guns, attachments = d.attachments, tutorial = d.tutorial, credits = d.credits }
	local original = p.Character.HumanoidRootPart.Position
	S.Lobby.paused = true
	d.guns, d.attachments, d.tutorial = Rules.defaultProfile().guns, { owned = {}, equipped = {} }, { done = false }
	p:SetAttribute("BC_Tutorial", "gun")
	T.check("remote gun action rejected from range", not G.action(p, "gun", "dart9"))
	T.check("tutorial cannot skip to invite", not G.action(p, "invite"))
	T.check("rejected actions leave stage unchanged", p:GetAttribute("BC_Tutorial") == "gun")
	T.check("walk into armory", move(Map.guns.dart9.Position + Vector3.new(4, 0, 0)))
	T.cmd("garage", "gun", "dart9")
	T.check("free gun advances tutorial through remote", waitFor(function() return p:GetAttribute("BC_Tutorial") == "friend" end))
	T.check("free gun equipped without loan", S.Weapons.state(p).gunId == "dart9" and next(S.Weapons.state(p).loan) == nil)
	T.check("unowned gun cannot be equipped", not G.action(p, "gun", "buzz") and not d.guns.owned.buzz)
	move(Map.point(C.Garage.Friend) + Vector3.new(0, 3, 3))
	T.cmd("garage", "talk")
	T.check("guide conversation", waitFor(function() return p:GetAttribute("BC_Tutorial") == "invite" end))
	T.cmd("garage", "invite")
	T.check("practice squad uses invite acceptance", waitFor(function() return G.tutorials[p] and G.tutorials[p].crews:size(p) == 2 end))
	T.check("NPC is outside live teleport squad", S.Lobby.crews:crewOf(p) == nil)
	local k = K.byOwner[p]
	T.check("tutorial creates owner's kart", k and k.model:GetAttribute("Owner") == p.UserId)
	T.check("kart refuses another owner", not K.enter(p, { owner = {} }))
	if k then
		move(k.root.Position + Vector3.new(0, 2, 6))
		T.eq("garage spawns Blackout Vortex", k.model:GetAttribute("Visual"), "vortex")
		T.check("garage owner can darken LEDs", K.action(p, "lights") and k.model:GetAttribute("LightsOn") == false)
		T.check("garage owner can open doors", K.action(p, "doors") and k.model:GetAttribute("DoorsOpen") == true)
		K.action(p, "lights")
		K.action(p, "doors")
		T.check("enter lobby kart", K.enter(p, k))
		T.check("seating advances to queue", waitFor(function() return p:GetAttribute("BC_Tutorial") == "queue" end))
		local st
		T.check("lobby uses kart client and touch buttons", waitFor(function()
			local ok
			ok, st = T.cmd("eval", "kart")
			return ok and st.driving and st.gasShown and not st.fireShown
		end))
		local at = k.root.Position
		T.cmd("eval", "drive", 1, 0, false)
		T.check("lobby kart drives with client physics", waitFor(function() return (k.root.Position - at).Magnitude > 12 end, 4))
		T.cmd("eval", "drive")
		T.cmd("eval", "exit")
		T.check("exit restores driver state", waitFor(function() return not p:GetAttribute("BC_Driving") and not S.Weapons.state(p).holstered end))
	end
	move(Map.terminal.Position + Vector3.new(0, 2, 4))
	T.check("loadout rejects locked gun", not G.action(p, "equip", "buzz", 2))
	T.check("loadout rejects Coming Soon slot", not G.action(p, "equip", "dart9", 4))
	T.check("loadout equips owned gun in selected slot", G.action(p, "equip", "dart9", 2) and d.guns.loadout[2] == "dart9" and d.guns.loadout[1] == "")
	move(Map.bench.Position + Vector3.new(0, 2, 5))
	local a = C.Attachments[1]
	T.check("bench rejects unowned attachment", not G.action(p, "attach", a.id, "dart9"))
	local compatible
	for _, att in ipairs(C.Attachments) do if table.find(C.GunsById.dart9.slots, att.slot) then compatible = att; break end end
	if compatible then
		d.attachments.owned[compatible.id] = true
		T.check("bench applies owned compatible attachment", G.action(p, "attach", compatible.id, "dart9"))
		T.check("bench toggles attachment off", G.action(p, "attach", compatible.id, "dart9") and d.attachments.equipped.dart9[compatible.slot] == nil)
	end
	local pad = S.Lobby.parts.A
	move(pad.Position + Vector3.new(0, 3, 0))
	S.Lobby.tick(S)
	T.cmd("ready")
	T.check("ready at real queue pad completes tutorial", waitFor(function() return d.tutorial.done end))
	T.eq("track and tutorial give no currency", d.credits, saved.credits)
	S.Lobby.pads.A:leave(p, workspace:GetServerTimeNow())
	p:SetAttribute("BC_Pad", nil)
	p:SetAttribute("BC_Tutorial", "gun")
	d.tutorial.done = false
	T.check("skip is available immediately", G.action(p, "skip") and d.tutorial.done and p:GetAttribute("BC_Tutorial") == "done")
	K.remove(p)
	T.eq("kart removed on cleanup", K.byOwner[p], nil)
	d.guns, d.attachments, d.tutorial = saved.guns, saved.attachments, saved.tutorial
	S.Weapons.states[p] = nil
	S.Weapons.equip(p, 1)
	S.Weapons.push(p)
	S.pushProfile(p)
	move(original)
	p:SetAttribute("BC_Tutorial", saved.tutorial.done and "done" or "gun")
	S.Lobby.paused = false
end
