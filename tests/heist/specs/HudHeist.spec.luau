-- Heist HUD (§5e) on the HUD v2 reference: the squad palette, and the live HUD through the client probe
-- (minimap/objective/portraits/health/ammo placement, the restyled touch cluster, alarm meter, objective,
-- dash timer, proximity pings + Purge jam, results panel).
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local S = require(SSS.BlackoutCrew.ServerState)
local V = Vector3.new

return function(T)
	-- (Static HUD v2 layout on six phone sizes: HudRef.spec in the lobby suite.)
	-- Squad palette: 4 fixed, distinct, no red (alarm) / no yellow (roll-up door) hues.
	local hexes = {}
	for i, c in ipairs(C.Colors.Slots) do
		hexes[i] = c:ToHex():upper()
	end
	T.eq("Okabe-Ito slots", table.concat(hexes, ","), "56B4E9,E69F00,009E73,CC79A7")
	local badHue = {}
	for i, c in ipairs(C.Colors.Slots) do
		local hue = c:ToHSV() * 360
		if hue < 20 or hue > 340 or (hue > 45 and hue < 70) then
			table.insert(badHue, i)
		end
	end
	T.eq("no red/yellow slot hues", table.concat(badHue, ","), "")

	-- Live HUD
	local Heist = S.Heist
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until (Heist.run and not Heist.run.ended) or os.clock() - t0 > 10
	local run = Heist.run
	if not T.check("run", run ~= nil) then
		return
	end
	Heist.paused = true
	local player = T.player
	local ok, h = T.cmd("eval", "hud")
	if not T.check("hud probe", ok and type(h) == "table", h) then
		Heist.paused = false
		return
	end
	local W, H = h.screen[1], h.screen[2]
	T.check("minimap top-left", h.map[5] and h.map[1] < W * 0.12 and h.map[2] < H * 0.35)
	T.check("minimap at a phone-readable size", h.map[3] >= C.HudRef.Map.w * C.Hud.MinScale - 1 and h.map[4] >= C.HudRef.Map.h * C.Hud.MinScale - 1, h.map[3])
	T.check("objective under the map", h.objective[5] and h.objective[2] >= h.map[2] + h.map[4] and h.objective[1] < W * 0.12)
	T.eq("objective has every step", #h.steps, #C.HudRef.Steps)
	T.eq("objective title", h.title, C.HudRef.ObjectiveTitle)
	T.check("health + ammo top-right", h.health[1] + h.health[3] > W * 0.95 and h.health[2] < H * 0.15 and h.ammo[2] > h.health[2] and h.ammo[1] + h.ammo[3] > W * 0.95,
		string.format("screen %dx%d health %d,%d", W, H, h.health[1], h.health[2]))
	T.check("health number shown", tonumber(h.hp) ~= nil, h.hp)
	T.check("ammo in the v2 plate", tonumber(h.mag) ~= nil and tonumber(h.cap) ~= nil and h.oldAmmo == false, tostring(h.mag) .. "|" .. tostring(h.cap))
	T.check("stick bottom-left", h.stick[1] < W * 0.2 and h.stick[2] > H * 0.55)
	T.check("dock bottom-centre", math.abs(h.dock[2][1] + h.dock[2][3] / 2 - W / 2) < 2 and h.dock[2][2] > H * 0.8 and h.menuName == "menu")
	local cl = h.cluster
	T.check("fire / ADS / gun / jump in the bottom-right cluster", cl.fire and cl.ads and cl.weapon and cl.jump
		and cl.fire[1] > W * 0.75 and cl.fire[2] > H * 0.6 and cl.ads[2] < cl.fire[2] and cl.weapon[1] < cl.fire[1], cl.fire and cl.fire[1])
	T.eq("one squad portrait (solo)", #h.cards, 1)
	T.eq("portrait slot dot = slot 1", h.colors[1]:upper(), hexes[1])
	T.check("alarm meter centred-top", math.abs(h.top[1] + h.top[3] / 2 - W / 2) < W * 0.03 and h.top[2] < H * 0.12)
	T.check("objective shown", type(h.goal) == "string" and #h.goal > 0, h.goal)
	local st = player:GetAttribute("BC_KartStatus") or "hidden"
	T.check("kart dot reflects status", h.dot ~= nil, st)
	-- Dash timer
	player:SetAttribute("BC_DashEnd", workspace:GetServerTimeNow() + 42)
	task.wait(0.35)
	local _, h2 = T.cmd("eval", "hud")
	T.check("dash timer shows", h2 and h2.timer ~= nil and (h2.timer == "0:41" or h2.timer == "0:42"), h2 and h2.timer)
	player:SetAttribute("BC_DashEnd", nil)
	-- Proximity pings: next to a lobby camera (~9 studs) -> pinged; Purge jams to 20 studs.
	local cam = S.enemies.cameras[2] -- (camera 1 was hacked in Enemies.spec: hacked cameras drop off the map)
	local cp = cam.def.pos
	T.cmd("moveTo", V(cp.X - 6, 3, cp.Z + 6))
	task.wait(0.6)
	local _, h3 = T.cmd("eval", "hud")
	T.check("enemy pinged when close", h3 and h3.pings >= 1, h3 and h3.pings)
	T.cmd("moveTo", V(-150, 3, 20))
	task.wait(0.6)
	local _, h4 = T.cmd("eval", "hud")
	T.eq("nothing pinged far away", h4 and h4.pings, 0)
	-- Results panel
	S.remotes.HeistEvent:FireClient(player, "results", { outcome = "done", credits = 123, detail = { small = 30, heavy = 600, outcome = "clean", crewSize = 1 } })
	task.wait(0.4)
	local _, h5 = T.cmd("eval", "hud")
	T.check("results panel", h5 and h5.results == true and h5.resultCredits == "+123 CREDITS", h5 and h5.resultCredits)
	Heist.paused = false
end
