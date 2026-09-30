-- Alarm meter (§5b): 3 tiers, Quiet -> Lockdown -> Purge. Gunfire = big bump, camera sighting = small,
-- downed teammate = medium, slow time creep. The meter only ever rises on its own; a tier drops only
-- via the hack objective (security terminal). Pure: time passed in via dt.
local Alarm = {}
Alarm.__index = Alarm

-- cfg = Config.Alarm; mult = difficulty x twist (e.g. Short Fuse 2x) scaling bumps and creep.
function Alarm.new(cfg, mult)
	return setmetatable({ cfg = cfg, mult = mult or 1, value = 0, max = cfg.PerTier * #cfg.Tiers }, Alarm)
end

function Alarm:tier()
	return math.clamp(math.floor(self.value / self.cfg.PerTier) + 1, 1, #self.cfg.Tiers)
end

-- kindMult lets a twist scale one kind (Loud Floor: gunfire x2).
function Alarm:bump(kind, kindMult)
	local b = self.cfg.Bumps[kind]
	if not b then
		return self:tier()
	end
	self.value = math.min(self.max, self.value + b * self.mult * (kindMult or 1))
	return self:tier()
end

function Alarm:creep(dt)
	self.value = math.min(self.max, self.value + self.cfg.Creep * self.mult * dt)
	return self:tier()
end

-- Hack: drop one tier (to the middle of the tier below); at Quiet it resets the meter.
function Alarm:hackDrop()
	local t = self:tier()
	self.value = t > 1 and (t - 2) * self.cfg.PerTier + self.cfg.PerTier * 0.5 or 0
	return self:tier()
end

-- Enemy counts for a tier (§5b): per-tier table x twist sentry mult, crew scaling (x0.5 solo, x0.75 duo)
-- on tower AI, repo drones by tier (§5d), then the cap trims watchers first, then sentries (never below 1).
function Alarm.counts(tier, crewSize, sentryMult, cfg)
	local base = cfg.Counts[math.clamp(tier, 1, #cfg.Counts)]
	local scale = cfg.CrewScale[math.clamp(crewSize, 1, #cfg.CrewScale)]
	local function scaled(n)
		return n > 0 and math.max(1, math.floor(n * scale + 0.5)) or 0
	end
	local s = scaled(base.sentries * (sentryMult or 1))
	local w = scaled(base.watchers)
	local r = base.repo
	while s + w + r > cfg.Cap and w > 0 do
		w -= 1
	end
	while s + w + r > cfg.Cap and s > 1 do
		s -= 1
	end
	return { sentries = s, watchers = w, repo = math.min(r, cfg.Cap - s - w) }
end

return Alarm
