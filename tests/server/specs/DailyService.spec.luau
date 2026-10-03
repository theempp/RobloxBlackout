-- Daily reward, server path: profile migration (schema 6), the client's claim through the DailyClaim remote
-- (rate-limited) into DailyService and the reply back to the lobby HUD, then the service rules on a fake clock:
-- next-day claim, failed save reverses, busy lock, lobby only. Pure claim rules: DailyReward.spec.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local D = require(RS.BlackoutCrew.DailyReward)
local Rules = require(RS.BlackoutCrew.Rules)
local S = require(SSS.BlackoutCrew.ServerState)

local function waitFor(fn, timeout)
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until fn() or os.clock() - t0 > (timeout or 3)
	return fn()
end

return function(T)
	local old = Rules.clean({ schemaVersion = 5, credits = 9 })
	T.check("schema 5 save gains a clean daily record", old.daily.claims == 0 and old.daily.last == 0 and old.credits == 9 and old.schemaVersion == C.Profile.SchemaVersion)
	local kept = Rules.clean({ daily = { claims = 3, last = 20000, keep = { spray_tag = true, fake = true } } })
	T.check("daily survives a save round trip", kept.daily.claims == 3 and kept.daily.last == 20000 and kept.daily.keep.spray_tag == true and kept.daily.keep.fake == nil)

	local p, Daily = T.player, S.Daily
	if not T.check("DailyService running", Daily ~= nil) then
		return
	end
	local function prof()
		return S.profiles.loaded[p]
	end
	prof().daily = D.clean(nil)
	S.pushProfile(p)
	local credits = prof().credits

	-- Remote path on the real clock: the client sends only the request.
	T.cmd("eval", "lobbyHud", "claim")
	T.check("claim via remote", waitFor(function()
		return prof().daily.claims == 1
	end), prof().daily.claims)
	T.eq("day 1 reward granted", prof().credits, credits + C.DailyReward.Rewards[1].amount)
	local h
	waitFor(function()
		local _, r = T.cmd("eval", "lobbyHud")
		h = r
		return type(r) == "table" and r.lastDaily ~= nil and r.claims == 1
	end)
	T.check("client got the reply + fresh profile", h and h.lastDaily and h.lastDaily.ok == true and h.claims == 1, h and h.lastDaily and h.lastDaily.message)
	T.check("plate shows the countdown after claiming", h and h.daily:match("^%d%d:%d%d:%d%d$") ~= nil, h and h.daily)
	T.cmd("eval", "lobbyHud", "claim")
	waitFor(function()
		local _, r = T.cmd("eval", "lobbyHud")
		h = r
		return type(r) == "table" and r.lastDaily and r.lastDaily.ok == false
	end)
	T.check("same-day claim refused", prof().daily.claims == 1 and h.lastDaily.ok == false, h.lastDaily.message)
	local dropped = S.Remotes.dropped.DailyClaim
	for _ = 1, 5 do
		T.cmd("eval", "lobbyHud", "claim")
	end
	task.wait(0.3)
	T.check("claim spam is rate-limited", S.Remotes.dropped.DailyClaim > dropped, S.Remotes.dropped.DailyClaim)
	T.eq("spam grants nothing", prof().daily.claims, 1)

	-- Service rules on a fake clock (after the real-clock part: these move `last` into the future).
	local now = os.time()
	local DAY = C.DailyReward.DayLength
	T.eq("next day claim", (Daily.claim(S, p, now + DAY)), true)
	T.eq("day 2 keepsake kept", prof().daily.keep[C.DailyReward.Rewards[2].item], true)
	local own = rawget(S.profiles, "save")
	S.profiles.save = function()
		return false
	end
	local okF, msgF = Daily.claim(S, p, now + 2 * DAY)
	S.profiles.save = own
	T.check("failed save reverses the claim", okF == false and prof().daily.claims == 2 and not prof().daily.keep[C.DailyReward.Rewards[3].item], msgF)
	Daily.busy[p] = true
	local okB, msgB = Daily.claim(S, p, now + 2 * DAY)
	Daily.busy[p] = nil
	T.check("busy lock", okB == false and msgB == "Please wait", msgB)
	local heist = { role = "heist", profiles = S.profiles, pushProfile = function() end }
	T.eq("heist server refuses", (Daily.claim(heist, p, now + 2 * DAY)), false)
	T.eq("clock rollback refused", (Daily.claim(S, p, now)), false)

	prof().daily = D.clean(nil) -- leave a fresh record for later specs
	S.pushProfile(p)
end
