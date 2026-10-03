-- HUD v2 reference layout (pure math on Config.HudRef): on real phone sizes every widget stays on screen, no two
-- overlap, and every touch target is >= MinTouchPx physical pixels. Staged module: nothing renders it yet.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)
local HudScale = require(RS.BlackoutCrew.HudScale)
local HR = C.HudRef

local function rectsFor(W, H, S)
	local r = {} -- { name, x, y, w, h, circle }
	local function add(name, x, y, w, h, circle)
		table.insert(r, { name = name, x = x, y = y, w = w, h = h, circle = circle })
	end
	local m, ti = HR.Map, HR.TopInset
	add("map", m.x, m.y + ti, m.w, m.h)
	add("objective", HR.Objective.x, m.y + ti + m.h + 6, HR.Objective.w + 14, 22 + 4 * 12 + 2)
	local s = HR.Squad
	for i = 1, s.max do
		add("portrait" .. i, s.x + (i - 1) * s.step, s.y + ti - 4, s.d, s.d + 11)
	end
	add("health", W - 8 - HR.Health.w, HR.Health.y, HR.Health.w, HR.Health.h)
	add("ammo", W - 8 - HR.Ammo.w, HR.Ammo.y, HR.Ammo.w, HR.Ammo.h)
	add("stick", HR.Stick.x, H - HR.Stick.y - HR.Stick.outer, HR.Stick.outer, HR.Stick.outer, true)
	for id, b in pairs(HR.Buttons) do
		local d = HudScale.touchSize(b.d, S, 1)
		add(id, W - b.x - d / 2, H - b.y - d / 2, d, d, true)
	end
	local d = HudScale.touchSize(HR.Dock.d, S, 1)
	local step = math.max(HR.Dock.step, d + 4)
	for i, id in ipairs({ "inventory", "menu", "map" }) do
		add("dock_" .. id, W / 2 + (i - 2) * step - d / 2, H - HR.Dock.y - d, d, d, true)
	end
	return r
end

local function overlap(a, b)
	if a.circle and b.circle then
		return (Vector2.new(a.x + a.w / 2, a.y + a.h / 2) - Vector2.new(b.x + b.w / 2, b.y + b.h / 2)).Magnitude < a.w / 2 + b.w / 2
	end
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

return function(T)
	local devices = { { "iPhone SE", 667, 375, 0, 0 }, { "iPhone 14", 844, 390, 47, 21 }, { "iPhone 16 Pro", 874, 402, 59, 21 },
		{ "iPhone XR", 896, 414, 48, 21 }, { "Android 20:9", 800, 360, 24, 0 }, { "iPad", 1024, 768, 0, 20 } }
	for _, d in ipairs(devices) do
		local w, h = d[2] - 2 * d[4], d[3] - d[5]
		local S = HudScale.scale(w, h, false)
		local W, H = w / S, h / S
		local problems = {}
		local rects = rectsFor(W, H, S)
		for i, a in ipairs(rects) do
			if a.x < 0 or a.y < 0 or a.x + a.w > W or a.y + a.h > H then
				table.insert(problems, a.name .. " off-screen")
			end
			for j = i + 1, #rects do
				if overlap(a, rects[j]) then
					table.insert(problems, a.name .. "+" .. rects[j].name)
				end
			end
		end
		T.eq("HUD v2 layout clean on " .. d[1], table.concat(problems, ","), "")
	end
	-- every interactive piece keeps the physical touch minimum at the extremes of HUD scale
	local worst = math.huge
	for S = C.Hud.MinScale, C.Hud.MaxScale * C.Hud.LargeMult, 0.01 do
		for _, b in pairs(HR.Buttons) do
			worst = math.min(worst, HudScale.touchSize(b.d, S, 1) * S)
		end
		worst = math.min(worst, HudScale.touchSize(HR.Dock.d, S, 1) * S)
	end
	T.check("HUD v2 buttons >= MinTouchPx at every scale", worst >= C.Hud.MinTouchPx, worst)
	for _, id in ipairs({ "fire", "aim", "swap", "sprint" }) do
		T.check("button configured: " .. id, HR.Buttons[id] ~= nil and HR.Buttons[id].d > 0)
	end
end
