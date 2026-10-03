-- Daily reward (Getaway Route): pure server-authoritative rules (profile field `daily`, server DailyService).
-- The client sends only "claim"; day, reward and amount come from Config + the server clock.
-- Soft streak: `claims` is the lifetime count and never resets, missed days just pause it. Cycle position =
-- claims % 7, so the next reward is always the next unclaimed stop on the route.
local C = require(script.Parent.Config)
local DR = C.DailyReward
local D = {}

function D.dayNumber(now: number): number
	return math.floor(now / DR.DayLength)
end

-- Sanitise the saved record. `keep` holds keepsake item ids (no Config table for those yet).
function D.clean(raw: any)
	raw = type(raw) == "table" and raw or {}
	local function n(x, cap)
		return type(x) == "number" and x == x and math.clamp(math.floor(x), 0, cap) or 0
	end
	local out = { claims = n(raw.claims, DR.MaxClaims), last = n(raw.last, 1e9), keep = {} }
	for _, r in ipairs(DR.Rewards) do
		if r.kind == "keepsake" and type(raw.keep) == "table" and raw.keep[r.item] == true then
			out.keep[r.item] = true
		end
	end
	return out
end

-- Everything the screen shows. Pure: same input, same output.
function D.view(d: any, now: number)
	local daily = d.daily
	local day = D.dayNumber(now)
	local claimedToday = daily.claims > 0 and daily.last >= day
	local can = not claimedToday and daily.last <= day
	-- Claimed stops in the cycle being shown: after a claim today that is the stop just taken (7 once the vault is claimed).
	local shown = claimedToday and ((daily.claims - 1) % #DR.Rewards + 1) or daily.claims % #DR.Rewards
	local days = {}
	for i, r in ipairs(DR.Rewards) do
		local state = i <= shown and "claimed" or (can and i == shown + 1 and "today" or "locked")
		days[i] = { day = i, state = state, reward = r }
	end
	local nextIndex = (daily.claims % #DR.Rewards) + (claimedToday and 1 or 2)
	return {
		days = days, canClaim = can, streak = daily.claims, shown = shown,
		today = can and DR.Rewards[shown + 1] or nil, todayDay = can and shown + 1 or nil,
		tomorrow = DR.Rewards[(nextIndex - 1) % #DR.Rewards + 1],
		secondsLeft = (day + 1) * DR.DayLength - now,
	}
end

-- Mutates the loaded profile (caller saves, and reverses on a failed save like EconomyService).
function D.claim(d: any, now: number)
	local v = D.view(d, now)
	if not v.canClaim then
		return false, d.daily.last > D.dayNumber(now) and "Clock changed: try again later" or "Come back tomorrow", nil
	end
	local r = v.today
	if r.kind == "credits" then
		d.credits = math.min(C.Profile.MaxCurrency, d.credits + r.amount)
	elseif r.kind == "token" then
		d.progress.tokens = math.min(1000, d.progress.tokens + r.amount)
	elseif r.kind == "cosmetic" then
		if not C.CosmeticsById[r.item] then
			return false, "Reward unavailable", nil
		end
		d.cosmetics.owned[r.item] = true
	elseif r.kind == "keepsake" then
		d.daily.keep[r.item] = true
	else
		return false, "Reward unavailable", nil
	end
	d.daily.claims = math.min(DR.MaxClaims, d.daily.claims + 1)
	d.daily.last = D.dayNumber(now)
	return true, "Claimed: " .. r.name, r
end

-- "12H 36M" / "36M" / "<1M" for the small next-reward pill.
function D.timerText(seconds: number): string
	local m = math.ceil(math.max(0, seconds) / 60)
	if m <= 0 then
		return "<1M"
	end
	return m >= 60 and string.format("%dH %02dM", m // 60, m % 60) or string.format("%dM", m)
end

return D
