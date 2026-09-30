-- Deterministic spread: the server applies it authoritatively; the client computes the identical
-- direction for its predicted tracer/hit marker. Seeded by (userId, shot seq, pellet).
local Spread = {}

function Spread.seed(userId, seq, pellet)
	return (math.abs(userId) % 1000003) * 131071 + (seq % 1000000) * 17 + pellet
end

-- Uniform sample inside a cone of half-angle coneDeg around dir.
function Spread.direction(dir, coneDeg, seed)
	local d = dir.Unit
	if coneDeg <= 0 then
		return d
	end
	local r = Random.new(seed)
	local ang = math.rad(coneDeg) * math.sqrt(r:NextNumber())
	local phi = 2 * math.pi * r:NextNumber()
	local ref = math.abs(d.Y) < 0.99 and Vector3.yAxis or Vector3.xAxis
	local right = d:Cross(ref).Unit
	local up = right:Cross(d)
	return (d * math.cos(ang) + (right * math.cos(phi) + up * math.sin(phi)) * math.sin(ang)).Unit
end

return Spread
