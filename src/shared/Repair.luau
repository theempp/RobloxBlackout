-- Kart repair minigame (§5d): a 3-step timing wheel. A needle sweeps one revolution per `period`;
-- tapping while it's inside the step's zone completes a step. Steps are shared across repairers, so two
-- teammates (~3 s) beat one (~6 s); the owner fixing their own kart has a slower needle (~10 s solo).
-- Server-validated: the tap carries the client's server-time stamp; the phase is recomputed here.
-- Pure.
local Repair = {}

function Repair.phase(t, t0, period)
	return ((t - t0) / period) % 1
end

-- Zone start for a repairer's step, deterministic from a seed (kart id x step x repairer).
function Repair.zone(seed, cfg)
	local r = Random.new(seed)
	return cfg.ZoneMin + r:NextNumber() * (cfg.ZoneMax - cfg.ZoneMin)
end

-- Is a tap at time `tap` (client stamp) a hit? `now` = server time on receipt.
function Repair.hit(tap, now, t0, period, zoneStart, cfg)
	if type(tap) ~= "number" or tap ~= tap or math.abs(tap - now) > cfg.Latency or tap < t0 then
		return false
	end
	local ph = Repair.phase(tap, t0, period)
	return ph >= zoneStart - cfg.Slack and ph <= zoneStart + cfg.ZoneWidth + cfg.Slack
end

function Repair.period(isOwner, cfg)
	return isOwner and cfg.SelfPeriod or cfg.Period
end

return Repair
