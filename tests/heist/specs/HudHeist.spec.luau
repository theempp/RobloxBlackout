-- Heist HUD (§5e): layout math on real device sizes (both HUD scales), the squad palette, and the live
-- HUD through the client probe (placement, cards, colours, alarm meter, objective, dash timer,
-- proximity pings + Purge jam, results panel).
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local HudScale = require(RS.BlackoutCrew.HudScale)
local S = require(SSS.BlackoutCrew.ServerState)
local V = Vector3.new

local function hit(r, cx, cy, rad)
	local nx, ny = math.clamp(cx, r[1], r[1] + r[3]), math.clamp(cy, r[2], r[2] + r[4])
	return (Vector2.new(cx, cy) - Vector2.new(nx, ny)).Magnitude < rad + 2
end

return function(T)
	local devices = { { "iPhone SE", 667, 375, 0, 0 }, { "iPhone 14", 844, 390, 47, 21 }, { "iPhone XR", 896, 414, 48, 21 },
		{ "Android 20:9", 800, 360, 24, 0 }, { "iPad", 1024, 768, 0, 20 } }
	for _, large in ipairs({ false, true }) do
		for _, d in ipairs(devices) do
			local w, h = d[2] - 2 * d[4], d[3] - d[5]
			local Sc = HudScale.scale(w, h, large)
			local W, H = w / Sc, h / Sc
			local rects = { { "map", { 6, 72, 120, 120 } }, { "top", { W / 2 - 140, 4, 280, 52 } } }
			for i = 1, 4 do
				table.insert(rects, { "card" .. i, { 6, 72 + 120 + 4 + (i - 1) * 24, 150, 22 } })
			end
			local problems = {}
			local gearBottom = 40 + 26
			if rects[1][2][2] < gearBottom then
				table.insert(problems, "map over gear")
			end
			for _, r in ipairs(rects) do
				local b = r[2]
				if b[1] < 0 or b[2] < 0 or b[1] + b[3] > W or b[2] + b[4] > H then
					table.insert(problems, r[1] .. " off-screen")
				end
				for id, bt in pairs(C.Touch.Buttons) do
					if hit(b, bt.x * W, bt.y * H, HudScale.touchSize(bt.size, Sc, 1) / 2) then
						table.insert(problems, r[1] .. "+" .. id)
					end
				end
			end
			T.eq("HUD clear of buttons on " .. d[1] .. (large and " (large)" or ""), table.concat(problems, ","), "")
		end
	end

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
	T.check("minimap at a phone-readable size", h.map[3] >= 110 and h.map[3] == h.map[4], h.map[3])
	T.eq("one squad card (solo)", #h.cards, 1)
	T.eq("card colour = slot 1", h.colors[1]:upper(), hexes[1])
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
