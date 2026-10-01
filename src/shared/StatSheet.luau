-- Armory stat widget data: current vs proposed FINAL stats, both from GunStats.resolve (rounded magazine,
-- capped range/falloff, nested recoil). Deltas are taken from the displayed (rounded) values so the text
-- always adds up. dir: "better" | "worse" | "tradeoff" (zoom: narrower view, not a pure gain) | "same".
local Config = require(script.Parent.Config)
local GunStats = require(script.Parent.GunStats)
local StatSheet = {}

local function meanAbs(list)
	local t = 0
	for _, v in ipairs(list) do
		t += math.abs(v)
	end
	return #list > 0 and t / #list or 0
end

-- zoom = how much larger things look when aiming than at the hip camera FOV.
function StatSheet.zoom(adsFov)
	local hip = math.rad(Config.Camera.Fov / 2)
	return math.tan(hip) / math.tan(math.rad(adsFov / 2))
end

-- good: "up" = higher is better, "down" = lower is better, "tradeoff" = neither.
-- Units ride on the label when long (rpm, rounds, studs) and on the values when short, so every row
-- states its unit and the columns still fit a phone.
StatSheet.ROWS = {
	{ key = "damage", label = "Damage / shot", unit = "", digits = 0, good = "up", get = function(s) return s.damage * s.pellets end },
	{ key = "rpm", label = "Fire rate (rpm)", unit = "", digits = 0, good = "up", get = function(s) return s.rpm end },
	{ key = "mag", label = "Magazine (rds)", unit = "", digits = 0, good = "up", get = function(s) return s.mag end },
	{ key = "reload", label = "Reload", unit = " s", digits = 2, good = "down", get = function(s) return s.reload end },
	{ key = "range", label = "Range (studs)", unit = "", digits = 0, good = "up", get = function(s) return s.range end },
	{ key = "falloffStart", label = "Full dmg (studs)", unit = "", digits = 0, good = "up", get = function(s) return s.falloffStart end },
	{ key = "adsTime", label = "Aim time", unit = " s", digits = 2, good = "down", get = function(s) return s.adsTime end },
	{ key = "zoom", label = "Aim zoom", unit = "x", digits = 2, good = "tradeoff", get = function(s) return StatSheet.zoom(s.adsFov) end },
	{ key = "adsSpeedMult", label = "Aim move speed", unit = "%", digits = 0, good = "up", get = function(s) return s.adsSpeedMult * 100 end },
	{ key = "hipSpread", label = "Hip spread", unit = "°", digits = 2, good = "down", get = function(s) return s.hipSpread end },
	{ key = "recoilUp", label = "Recoil (up)", unit = "°", digits = 2, good = "down", get = function(s) return s.recoil.up end },
	{ key = "recoilSide", label = "Recoil (side)", unit = "°", digits = 2, good = "down", get = function(s) return meanAbs(s.recoil.side) end },
}

local function round(v, digits)
	local m = 10 ^ digits
	return math.floor(v * m + 0.5) / m
end
StatSheet.round = round

local function fmt(v, digits)
	return string.format("%." .. digits .. "f", v)
end

-- Rows for gunId with `current` vs `proposed` attachment maps (slot -> id). proposed = nil: no preview.
function StatSheet.compare(gunId, current, proposed)
	local a = GunStats.resolve(gunId, current)
	if not a then
		return nil
	end
	local b = proposed and GunStats.resolve(gunId, proposed) or a
	local rows = {}
	for _, r in ipairs(StatSheet.ROWS) do
		local cur, new = r.get(a), r.get(b)
		local shownCur, shownNew = round(cur, r.digits), round(new, r.digits)
		local delta = round(shownNew - shownCur, r.digits)
		local dir = "same"
		if delta ~= 0 then
			if r.good == "tradeoff" then
				dir = "tradeoff"
			elseif (delta > 0) == (r.good == "up") then
				dir = "better"
			else
				dir = "worse"
			end
		end
		table.insert(rows, {
			key = r.key, label = r.label, unit = r.unit, cur = cur, new = new, delta = delta, dir = dir,
			curText = fmt(shownCur, r.digits) .. r.unit, newText = fmt(shownNew, r.digits) .. r.unit,
			deltaText = delta ~= 0 and ((delta > 0 and "+" or "-") .. fmt(math.abs(delta), r.digits) .. r.unit) or "",
		})
	end
	return rows, a, b
end

-- True when two attachment maps are the same set.
function StatSheet.same(x, y)
	x, y = x or {}, y or {}
	for k, v in pairs(x) do
		if y[k] ~= v then
			return false
		end
	end
	for k, v in pairs(y) do
		if x[k] ~= v then
			return false
		end
	end
	return true
end

return StatSheet
