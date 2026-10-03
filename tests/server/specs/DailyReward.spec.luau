-- Daily reward rules (pure): claim/streak/reset logic, soft streak, wrap, clock safety, reward table integrity.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)
local D = require(RS.BlackoutCrew.DailyReward)
local Rules = require(RS.BlackoutCrew.Rules)

local DAY = C.DailyReward.DayLength
local function profile()
	local p = Rules.defaultProfile()
	p.daily = D.clean(nil)
	return p
end
local function states(v)
	local s = {}
	for i, x in ipairs(v.days) do
		s[i] = x.state:sub(1, 1)
	end
	return table.concat(s)
end

return function(T)
	local R = C.DailyReward.Rewards
	T.eq("seven stops", #R, 7)
	T.eq("day 7 is the Static Face mask", R[7].item, "static_7")
	local ok = true
	for _, r in ipairs(R) do
		if r.kind == "cosmetic" and not C.CosmeticsById[r.item] then
			ok = false
		end
		if r.kind == "keepsake" and type(r.item) ~= "string" then
			ok = false
		end
		if (r.kind == "credits" or r.kind == "token") and not (type(r.amount) == "number" and r.amount > 0) then
			ok = false
		end
		if r.kind == "glitch" then
			ok = false
		end
	end
	T.check("every reward valid, no Glitch Coins", ok)

	-- Fresh profile: Day 1 is today, nothing claimed.
	local p = profile()
	local t0 = 20000 * DAY + 3600
	local v = D.view(p, t0)
	T.eq("fresh: today is day 1", states(v), "tllllll")
	T.eq("fresh: can claim", v.canClaim, true)
	T.eq("fresh: tomorrow is day 2", v.tomorrow.item, "spray_tag")

	-- Claim day 1; second claim the same day fails; timer counts to the next UTC midnight.
	local good, msg = D.claim(p, t0)
	T.check("claim day 1", good, msg)
	T.eq("day 1 credits", p.credits, Rules.defaultProfile().credits + R[1].amount)
	T.eq("claimed once", states(D.view(p, t0)), "cllllll")
	T.eq("no double claim", (D.claim(p, t0 + 5)), false)
	T.eq("timer to midnight", D.view(p, t0).secondsLeft, DAY - 3600)
	T.eq("timer text", D.timerText(12 * 3600 + 36 * 60), "12H 36M")
	T.eq("timer text minutes", D.timerText(36 * 60 - 1), "36M")
	T.eq("timer text floor", D.timerText(0), "<1M")

	-- Next day: day 2 (keepsake). Missing days pause, never reset.
	T.check("day 2 next day", (D.claim(p, t0 + DAY)))
	T.check("keepsake stored", p.daily.keep.spray_tag == true)
	local late = t0 + 9 * DAY -- a week of missed days
	local v3 = D.view(p, late)
	T.eq("missed days: streak paused, day 3 today", states(v3), "cctllll")
	T.eq("streak never punished", v3.streak, 2)
	T.check("day 3 after a long gap", (D.claim(p, late)))
	T.eq("lifetime claims", p.daily.claims, 3)

	-- Walk to day 7 and wrap.
	local now = late
	for day = 4, 7 do
		now += DAY
		T.check("claim day " .. day, (D.claim(p, now)))
	end
	T.check("vault grants the mask", p.cosmetics.owned.static_7 == true)
	T.eq("vault claimed: all seven shown", states(D.view(p, now)), "ccccccc")
	T.eq("tomorrow wraps to day 1", D.view(p, now).tomorrow.name, R[1].name)
	local nextDay = D.view(p, now + DAY)
	T.eq("new cycle starts at day 1", states(nextDay), "tllllll")
	T.check("claim day 1 of cycle 2", (D.claim(p, now + DAY)))
	T.eq("streak keeps counting", p.daily.claims, 8)

	-- Token reward feeds the existing earned-token spin (day 5 reward).
	local q = profile()
	q.daily.claims = 4
	local tokens = q.progress.tokens
	T.check("claim day 5", (D.claim(q, t0)))
	T.eq("token granted", q.progress.tokens, tokens + 1)

	-- Credits cap; clock rolled back is refused and never double pays.
	local r = profile()
	r.credits = C.Profile.MaxCurrency - 10
	D.claim(r, t0)
	T.eq("credits capped", r.credits, C.Profile.MaxCurrency)
	local refused, why = D.claim(r, t0 - DAY)
	T.eq("past clock refused", refused, false)
	T.check("past clock message", why ~= nil and why ~= "")

	-- clean(): garbage in, safe record out.
	local dirty = D.clean({ claims = -5, last = 0 / 0, keep = { spray_tag = true, hack = true, ping_icon = "yes" } })
	T.eq("clean claims", dirty.claims, 0)
	T.eq("clean last", dirty.last, 0)
	T.check("clean keeps only known items", dirty.keep.spray_tag == true and dirty.keep.hack == nil and dirty.keep.ping_icon == nil)
	T.eq("clean huge claims", D.clean({ claims = 1e12 }).claims, C.DailyReward.MaxClaims)
	T.eq("clean non-table", D.clean("x").claims, 0)
end
