-- Laser gauntlet math (pure). Beams move as a function of shared server time, so the server's hit
-- test and every client's render agree with zero replication. Tier speeds them up (§5b).
local Lasers = {}

function Lasers.at(def, t, speedMult)
	if not def.period or def.period <= 0 then
		return def.a, def.b
	end
	local o = def.move * math.sin(2 * math.pi * t * (speedMult or 1) / def.period + (def.phase or 0))
	return def.a + o, def.b + o
end

-- Distance from point p to segment ab.
function Lasers.segDist(p, a, b)
	local ab = b - a
	local len2 = ab:Dot(ab)
	local u = len2 > 0 and math.clamp((p - a):Dot(ab) / len2, 0, 1) or 0
	return (a + ab * u - p).Magnitude
end

-- A character touches a beam if any body sample (feet/torso/head offsets from the root) is within radius.
function Lasers.touches(root, a, b, cfg)
	for _, dy in ipairs(cfg.Samples) do
		if Lasers.segDist(root + Vector3.new(0, dy, 0), a, b) < cfg.Radius then
			return true
		end
	end
	return false
end

return Lasers
