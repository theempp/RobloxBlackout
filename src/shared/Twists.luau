-- Twist engine (§5c): one twist per run, mostly param flips. A twist's fields merge onto the run's base
-- params: *Mult numbers multiply, bumpMult tables merge per kind, anything else overrides. Build 2
-- enables Blackout + Double Patrol; the other four (Laser Storm, Short Fuse, Glitch Surge, Loud Floor)
-- are 3C content on the same engine. Pure and deterministic per run seed.
local Twists = {}

function Twists.pick(seed, cfg)
	if cfg.Force and cfg[cfg.Force] then
		return cfg.Force
	end
	local ids = cfg.Enabled
	if #ids == 0 then
		return nil
	end
	return ids[Random.new(seed):NextInteger(1, #ids)]
end

function Twists.apply(base, twist)
	local out = table.clone(base)
	out.bumpMult = table.clone(base.bumpMult or {})
	for k, v in pairs(twist or {}) do
		if k == "bumpMult" then
			for kind, m in pairs(v) do
				out.bumpMult[kind] = (out.bumpMult[kind] or 1) * m
			end
		elseif type(v) == "number" and k:sub(-4) == "Mult" then
			out[k] = (out[k] or 1) * v
		elseif k ~= "name" and k ~= "lighting" then
			out[k] = v
		end
	end
	return out
end

-- Stable 31-bit seed from a run id string.
function Twists.seed(runId)
	local h = 5381
	for i = 1, #runId do
		h = (h * 33 + string.byte(runId, i)) % 2147483647
	end
	return h
end

return Twists
