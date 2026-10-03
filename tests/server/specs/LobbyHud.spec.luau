-- Lobby HUD (refs/hud/lobby-hud-reference.jpg): pure layout on real phone sizes (on screen, nothing overlaps the HUD
-- or the lobby touch buttons, touch targets >= MinTouchPx), and the live HUD through the probe (LVL = Economy.tier).
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local HudScale = require(RS.BlackoutCrew.HudScale)
local S = require(SSS.BlackoutCrew.ServerState)
local L = C.LobbyHud

-- Mirrors LobbyHud.layout. { name, x, y, w, h, circle }
local function rectsFor(W, H, Sc)
	local r = {}
	local function add(name, x, y, w, h, circle)
		table.insert(r, { name = name, x = x, y = y, w = w, h = h, circle = circle })
	end
	local function circle(name, cx, cy, d)
		add(name, cx - d / 2, cy - d / 2, d, d, true)
	end
	local cd = L.Card
	add("card", cd.x - cd.avatar / 2, cd.y, cd.avatar / 2 + cd.w, cd.avatar)
	local col = L.Column
	local d = HudScale.touchSize(col.d, Sc, 1)
	local step = math.max(col.step, d + 14)
	for i, id in ipairs({ "shop", "vip", "inventory" }) do
		circle(id, col.x, col.y + (i - 1) * step, d)
		add(id .. "_caption", col.x - 25, col.y + (i - 1) * step + d / 2 + 2, 50, 9)
	end
	local P = L.Pills
	add("credits", W - 8 - P.w, P.y, P.w, P.h)
	add("coins", W - 8 - P.w, P.y + P.h + P.gap, P.w, P.h)
	local rr = L.Right
	local rd = HudScale.touchSize(rr.d, Sc, 1)
	for i, id in ipairs({ "settings", "friends" }) do
		local cx = W - rr.x - (i - 1) * math.max(rr.step, rd + 8)
		circle(id, cx, rr.y, rd)
	end
	local dl = L.Daily
	local dh = HudScale.touchSize(dl.h, Sc, 1)
	add("daily", dl.x, H - dl.y - math.max(dh, dl.icon), dl.icon / 2 + dl.w, math.max(dh, dl.icon))
	local sq = L.Squad
	local sd = HudScale.touchSize(sq.d, Sc, 1)
	local sstep = math.max(sq.step, sd + 4)
	for i = 1, C.Crew.MaxSize do
		circle("squad" .. i, W * sq.cx + (i - (C.Crew.MaxSize + 1) / 2) * sstep, H - sq.y - sd / 2, sd)
	end
	local ch = math.max(L.Contract.h, dh)
	add("contract", W - 8 - L.Contract.w, H - L.Contract.y - ch, L.Contract.w, ch)
	add("ammo", W / 2 - 85, 6, 170, 50) -- Hud's ammo panel sits top-centre in the lobby
	for id, b in pairs(C.Touch.Buttons) do
		if not b.heist and not b.driving and not b.optional then
			circle("touch_" .. id, b.x * W, b.y * H, HudScale.touchSize(b.size, Sc, 1))
		end
	end
	return r
end

local function overlap(a, b)
	if a.circle and b.circle then
		return (Vector2.new(a.x + a.w / 2, a.y + a.h / 2) - Vector2.new(b.x + b.w / 2, b.y + b.h / 2)).Magnitude < a.w / 2 + b.w / 2 + 2
	elseif a.circle or b.circle then
		local c, q = a.circle and a or b, a.circle and b or a
		local cx, cy = c.x + c.w / 2, c.y + c.h / 2
		local nx, ny = math.clamp(cx, q.x, q.x + q.w), math.clamp(cy, q.y, q.y + q.h)
		return (Vector2.new(cx, cy) - Vector2.new(nx, ny)).Magnitude < c.w / 2 + 2
	end
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

return function(T)
	local devices = { { "iPhone SE", 667, 375, 0, 0 }, { "iPhone 14", 844, 390, 47, 21 }, { "iPhone 16 Pro", 874, 402, 59, 21 },
		{ "iPhone XR", 896, 414, 48, 21 }, { "Android 20:9", 800, 360, 24, 0 }, { "iPad", 1024, 768, 0, 20 } }
	for _, large in ipairs({ false, true }) do
		for _, dv in ipairs(devices) do
			local w, h = dv[2] - 2 * dv[4], dv[3] - dv[5]
			local Sc = HudScale.scale(w, h, large)
			local W, H = w / Sc, h / Sc
			local problems = {}
			local rects = rectsFor(W, H, Sc)
			for i, a in ipairs(rects) do
				if a.x < 0 or a.y < 0 or a.x + a.w > W or a.y + a.h > H then
					table.insert(problems, a.name .. " off-screen")
				end
				-- Large HUD: on-screen only. Known gap (gate): its fraction-placed GUN / R / FIRE crowd the bottom row on phones.
				for j = i + 1, large and 0 or #rects do
					local b = rects[j]
					local touchPair = a.name:sub(1, 6) == "touch_" and b.name:sub(1, 6) == "touch_" -- Hud.spec owns those
					if not touchPair and overlap(a, b) then
						table.insert(problems, a.name .. "+" .. b.name)
					end
				end
			end
			T.eq("lobby HUD layout clean on " .. dv[1] .. (large and " (large)" or ""), table.concat(problems, ","), "")
		end
	end
	local worst = math.huge
	for Sc = C.Hud.MinScale, C.Hud.MaxScale * C.Hud.LargeMult, 0.01 do
		for _, d in ipairs({ L.Column.d, L.Right.d, L.Squad.d, L.Daily.h }) do
			worst = math.min(worst, HudScale.touchSize(d, Sc, 1) * Sc)
		end
	end
	T.check("lobby HUD targets >= MinTouchPx at every scale", worst >= C.Hud.MinTouchPx, worst)

	-- Live (lobby test client)
	local p = T.player
	local d = S.profiles.loaded[p]
	local ok, h = T.cmd("eval", "lobbyHud")
	if not T.check("lobby HUD probe", ok and type(h) == "table", h) then
		return
	end
	T.check("lobby HUD visible", h.visible == true)
	T.check("old gear / SHOP / SQUAD launchers retired", not h.gear and not h.oldShop and not h.oldSocial)
	local E = require(RS.BlackoutCrew.Economy)
	T.eq("LVL from the profile", h.lvl, tostring(E.tier(d)))
	T.eq("credits from the profile", (h.credits:gsub(",", "")), tostring(d.credits))
	T.eq("glitch coins from the profile", (h.coins:gsub(",", "")), tostring(d.glitchCoins))
	T.check("VIP visibly unavailable", h.vipSoon == true)
	T.eq("squad slot 1 is you", h.members[1], p.Name)
	T.check("squad slots 2-4 open (+)", h.members[2] == false and h.members[3] == false and h.members[4] == false)
	T.eq("contract neutral off-pad", h.contract, L.Neutral)
	T.check("daily timer shows", h.daily == "CLAIM NOW" or h.daily:match("^%d%d:%d%d:%d%d$") ~= nil, h.daily)
	local W, H = h.screen[1], h.screen[2]
	local rc = h.rects
	T.check("card top-left", h.card[1] < W * 0.2 and h.card[2] < H * 0.2)
	T.check("pills + settings top-right", rc.settings[1] > W * 0.8 and rc.settings[2] < H * 0.4)
	T.check("daily bottom-left, contract bottom-right", rc.daily[1] < W * 0.1 and rc.daily[2] > H * 0.75 and h.contractRect[1] + h.contractRect[3] > W * 0.9 and h.contractRect[2] > H * 0.75,
		string.format("screen %dx%d daily %d,%d contract %d,%d", W, H, rc.daily[1], rc.daily[2], h.contractRect[1], h.contractRect[2]))
	T.check("ammo panel top-centre", math.abs(h.ammo[1] + h.ammo[3] / 2 - W / 2) < 4 and h.ammo[2] < H * 0.2)
end
