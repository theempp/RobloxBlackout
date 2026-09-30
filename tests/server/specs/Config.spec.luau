-- Config: every tunable present, finite and internally consistent.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)
local Net = require(RS.BlackoutCrew.Net)

return function(T)
	local bad = {}
	local function walk(t, path, seen)
		seen = seen or {}
		if seen[t] then
			return
		end
		seen[t] = true
		for k, v in pairs(t) do
			if type(v) == "number" and (v ~= v or math.abs(v) == math.huge) then
				table.insert(bad, path .. "." .. tostring(k))
			elseif type(v) == "table" then
				walk(v, path .. "." .. tostring(k), seen)
			end
		end
	end
	walk(C, "Config")
	T.check("all numbers finite", #bad == 0, table.concat(bad, ","))

	T.eq("6 guns", #C.Guns, 6)
	local prices, free, ids = {}, 0, {}
	for _, g in ipairs(C.Guns) do
		table.insert(prices, g.price)
		if g.price == 0 then
			free += 1
		end
		T.check(g.id .. " unique id", not ids[g.id])
		ids[g.id] = true
		for _, k in ipairs({ "damage", "headMult", "rpm", "mag", "reload", "range", "falloffStart", "pellets", "adsFov", "adsTime", "adsSpeedMult" }) do
			T.check(g.id .. "." .. k .. " > 0", type(g[k]) == "number" and g[k] > 0, g[k])
		end
		T.check(g.id .. " falloff within range", g.falloffStart <= g.range)
		T.check(g.id .. " range within cap", g.range <= C.Fire.MaxRange)
		T.check(g.id .. " recoil pattern", #g.recoil.side > 0 and g.recoil.up > 0 and g.recoil.up <= C.Recoil.MaxKickDeg)
		T.check(g.id .. " recover in [0,1]", g.recoil.recover >= 0 and g.recoil.recover <= 1)
		T.check(g.id .. " has shape + muzzle", #g.shape > 0 and typeof(g.muzzle) == "Vector3")
		for _, s in ipairs(g.slots) do
			T.check(g.id .. " slot " .. s .. " valid", table.find(C.AttachmentSlots, s) ~= nil)
		end
	end
	table.sort(prices)
	T.eq("prices 0/1k/3k/6k/10k/15k", table.concat(prices, ","), "0,1000,3000,6000,10000,15000")
	T.eq("exactly one free gun", free, 1)

	local usable, left, right, top = 0, 0, 0, 0
	for _, s in ipairs(C.Wheel.Slots) do
		local a = math.rad(s.angle)
		if s.usable then
			usable += 1
		else
			T.check("slot " .. s.index .. " teaser", type(s.teaser) == "string" and #s.teaser > 0)
		end
		if math.abs(math.cos(a)) < 0.1 and math.sin(a) < 0 then
			top += 1
		elseif math.cos(a) < 0 then
			left += 1
		else
			right += 1
		end
		T.check("slot " .. s.index .. " not near bottom", math.abs(((s.angle - 90 + 180) % 360) - 180) > 45)
	end
	T.eq("5 wheel slots", #C.Wheel.Slots, 5)
	T.eq("3 usable slots", usable, 3)
	T.check("layout 2L/2R/1T", left == 2 and right == 2 and top == 1, left .. "/" .. right .. "/" .. top)

	for name in pairs(C.Touch.Buttons) do
		local b = C.Touch.Buttons[name]
		T.check("button " .. name .. " on screen", b.x >= 0 and b.x <= 1 and b.y >= 0 and b.y <= 1)
	end
	for _, n in ipairs(Net.Events) do
		if n ~= "Hit" and n ~= "State" and n ~= "Profile" then
			T.check("rate limit for " .. n, C.RateLimits[n] ~= nil)
		end
	end
	T.check("store name", C.Profile.StoreName == "BlackoutCrew_Profile_v1")
	T.check("place has StreamingEnabled", workspace.StreamingEnabled == true)
end
