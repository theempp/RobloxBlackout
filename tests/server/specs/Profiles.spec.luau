-- Rules.clean per field + Profiles session-lock logic.
-- Lock tests use an in-memory store (JSON round-trip): memory store, NO live-persistence evidence.
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local C = require(RS.BlackoutCrew.Config)
local Rules = require(RS.BlackoutCrew.Rules)
local Profiles = require(game.ServerScriptService.BlackoutCrew.Profiles)

local function fakeStore()
	local s = { data = {}, fail = 0, calls = 0 }
	function s:UpdateAsync(key, fn)
		self.calls += 1
		if self.fail > 0 then
			self.fail -= 1
			error("fake outage")
		end
		local old = self.data[key] and Http:JSONDecode(Http:JSONEncode(self.data[key])) or nil
		local new = fn(old)
		if new == nil then
			return nil
		end
		self.data[key] = Http:JSONDecode(Http:JSONEncode(new))
		return self.data[key]
	end
	return s
end

local function fakePlayer(id)
	local attrs = {}
	return { UserId = id, Parent = game, attrs = attrs, SetAttribute = function(_, k, v)
		attrs[k] = v
	end }
end

return function(T)
	local free = next(Rules.freeGuns())
	local d = Rules.clean(nil)
	T.eq("garbage -> schemaVersion", d.schemaVersion, C.Profile.SchemaVersion)
	T.check("garbage -> free gun owned", d.guns.owned[free] == true)
	T.eq("garbage -> loadout[1] free", d.guns.loadout[1], free)
	T.eq("string profile -> default credits", Rules.clean("x").credits, 0)

	T.eq("credits negative", Rules.clean({ credits = -5 }).credits, 0)
	T.eq("credits NaN", Rules.clean({ credits = 0 / 0 }).credits, 0)
	T.eq("credits inf", Rules.clean({ credits = math.huge }).credits, 0)
	T.eq("credits capped", Rules.clean({ credits = 1e20 }).credits, C.Profile.MaxCurrency)
	T.eq("credits string rejected", Rules.clean({ credits = "100" }).credits, 0)
	T.eq("credits floored", Rules.clean({ credits = 12.7 }).credits, 12)
	T.eq("glitchCoins validated", Rules.clean({ glitchCoins = -1 }).glitchCoins, 0)
	T.eq("glitchCoins kept", Rules.clean({ glitchCoins = 40 }).glitchCoins, 40)

	local g = Rules.clean({ guns = { owned = { buzz = true, fake_gun = true, ranger = "yes" }, loadout = { "buzz", "ranger", "buzz" } } })
	T.check("owned gun kept", g.guns.owned.buzz == true)
	T.check("unknown gun stripped", g.guns.owned.fake_gun == nil)
	T.check("non-true owned stripped", g.guns.owned.ranger == nil)
	T.check("free gun always owned", g.guns.owned[free] == true)
	T.eq("loadout owned kept", g.guns.loadout[1], "buzz")
	T.eq("loadout unowned cleared", g.guns.loadout[2], "")
	T.eq("loadout duplicate cleared", g.guns.loadout[3], "")
	T.eq("empty loadout -> free", Rules.clean({ guns = { loadout = { "", "", "" } } }).guns.loadout[1], free)
	T.eq("loadout wrong type ignored", Rules.clean({ guns = { loadout = "buzz" } }).guns.loadout[1], free)

	local a = Rules.clean({
		guns = { owned = { buzz = true } },
		attachments = {
			owned = { ext_mag = true, vert_grip = true, fake = true, red_dot = true },
			equipped = {
				buzz = { mag = "ext_mag", grip = "red_dot", optic = "scope2x" },
				dart9 = { grip = "vert_grip" },
				ranger = { mag = "ext_mag" },
			},
		},
	})
	T.check("attachment owned kept", a.attachments.owned.ext_mag == true)
	T.check("unknown attachment stripped", a.attachments.owned.fake == nil)
	T.eq("equipped valid slot kept", a.attachments.equipped.buzz and a.attachments.equipped.buzz.mag, "ext_mag")
	T.check("equipped wrong slot dropped", a.attachments.equipped.buzz.grip == nil)
	T.check("equipped unowned attachment dropped", a.attachments.equipped.buzz.optic == nil)
	T.check("slot not allowed on gun dropped", a.attachments.equipped.dart9 == nil)
	T.check("unowned gun attachments dropped", a.attachments.equipped.ranger == nil)

	T.check("karts whitelist retains starter only", Rules.clean({ karts = { owned = { any = true } } }).karts.owned.any == nil and Rules.clean({}).karts.owned.base == true)
	local cos = Rules.clean({ cosmetics = { owned = { hat = true } } }).cosmetics.owned
	T.check("cosmetics whitelist: unknown stripped, free starters owned", cos.hat == nil and cos.fit_crew == true and cos.dis_maint == nil)
	local w = Rules.clean({ wheel = { freeSpins = -3, pity = 1e9, season = 2.5 } })
	T.eq("wheel freeSpins clamped", w.wheel.freeSpins, 0)
	T.eq("wheel pity capped", w.wheel.pity, C.Profile.MaxCounter)
	T.eq("wheel season floored", w.wheel.season, 2)

	local s = Rules.clean({ settings = {
		aimAssist = "no", perfOverlay = true, sensitivity = 99, adsSensitivity = 0 / 0,
		layout = { fire = { x = 2, y = -1, s = 9 }, bogus = { x = 0.5, y = 0.5, s = 1 }, ads = { x = 0 / 0, y = 0.5, s = 1 } },
	} }).settings
	T.eq("settings wrong type ignored", s.aimAssist, C.Settings.Bools.aimAssist)
	T.eq("settings bool kept", s.perfOverlay, true)
	T.eq("sensitivity clamped", s.sensitivity, C.Settings.Numbers.sensitivity[3])
	T.eq("NaN sensitivity -> default", s.adsSensitivity, C.Settings.Numbers.adsSensitivity[1])
	T.check("layout clamped", s.layout.fire and s.layout.fire.x == 1 and s.layout.fire.y == 0 and s.layout.fire.s == C.Touch.UserScale[2])
	T.check("layout unknown id dropped", s.layout.bogus == nil)
	T.check("layout NaN dropped", s.layout.ads == nil)
	local cs = Rules.cleanSettings({ credits = 999, sfx = false }, d.settings)
	T.check("cleanSettings ignores server fields", cs.credits == nil and cs.sfx == false)

	local receipts = {}
	for i = 1, 800 do
		receipts["r" .. i] = true
	end
	receipts.bad = 1
	local r = Rules.clean({ receipts = receipts }).receipts
	local n = 0
	for _ in pairs(r) do
		n += 1
	end
	T.eq("receipts capped at 500", n, C.Profile.ReceiptCap)
	T.check("receipt non-true dropped", r.bad == nil)
	local _, newer = Rules.clean({ schemaVersion = C.Profile.SchemaVersion + 1 })
	T.check("newer schema flagged", newer == true)
	local round = Rules.clean(Http:JSONDecode(Http:JSONEncode(g)))
	T.eq("JSON round-trip stable", Http:JSONEncode(round), Http:JSONEncode(Rules.clean(g)))
	T.eq("payout solo", Rules.payout(1000, 1), 1000)
	T.eq("payout 4 = +24%", Rules.payout(1000, 4), 1240)
	T.eq("payout capped", Rules.payout(1000, 6), 1240)

	-- Lock transforms
	local now = 1000
	local got = Profiles.acquire(nil, "A", now)
	T.check("acquire empty", got and got.lock.token == "A" and got.lock.expires == now + C.Profile.LockSeconds)
	T.check("acquire blocked by live lock", Profiles.acquire({ data = {}, lock = { token = "B", expires = now + 10 } }, "A", now) == nil)
	T.check("acquire takes expired lock", Profiles.acquire({ data = {}, lock = { token = "B", expires = now - 1 } }, "A", now) ~= nil)
	T.check("acquire refuses newer schema", Profiles.acquire({ data = { schemaVersion = 99 } }, "A", now) == nil)
	T.check("commit wrong token refused", Profiles.commit({ lock = { token = "B" } }, "A", {}, false, now) == nil)
	local c = Profiles.commit({ lock = { token = "A" } }, "A", { credits = 5 }, true, now)
	T.check("commit release clears lock", c and c.lock == nil and c.data.credits == 5)

	-- Instances against the memory store
	local studio = Profiles.new({ sessionOnly = true })
	local sp = fakePlayer(1)
	T.check("session-only load", studio:load(sp) ~= nil and sp.attrs.SaveStatus == "SESSION ONLY")
	local store = fakeStore()
	local fails = {}
	local function inst(job)
		return Profiles.new({ sessionOnly = false, store = store, jobId = job, retryDelay = function()
			return 0
		end, onFail = function(p, msg)
			table.insert(fails, p.UserId .. ":" .. msg)
		end })
	end
	local s1, s2 = inst("server1"), inst("server2")
	local p1 = fakePlayer(42)
	T.check("(memory store) load acquires lock", s1:load(p1) ~= nil and p1.attrs.SaveStatus == "SAVED")
	s1.loaded[p1].credits = 777
	T.check("(memory store) save keeps lock", s1:save(p1, false) and store.data.u42.lock ~= nil)
	local p1b = fakePlayer(42)
	T.check("(memory store) second server blocked", s2:load(p1b) == nil and #fails == 1)
	T.check("(memory store) release", s1:save(p1, true) and store.data.u42.lock == nil)
	local loaded = s2:load(p1b)
	T.eq("(memory store) other server sees saved credits", loaded and loaded.credits, 777)
	store.fail = 1
	local s3, p3 = inst("server3"), fakePlayer(7)
	T.check("(memory store) retry survives one outage", s3:load(p3) ~= nil)
	-- Lobby -> heist hand-off: the saved look travels with the released profile.
	local s4, s5, p4, p4b = inst("lobby"), inst("heist"), fakePlayer(77), fakePlayer(77)
	s4:load(p4)
	s4.loaded[p4].cosmetics.equipped = { outfit = "fit_night", mask = "mask_bandana" }
	s4:save(p4, true)
	local arrived = s5:load(p4b)
	T.check("(memory store) equipped cosmetics survive the lobby -> heist hand-off", arrived and arrived.cosmetics.equipped.outfit == "fit_night"
		and arrived.cosmetics.equipped.mask == "mask_bandana")
	store.data.u7.lock.token = "thief"
	local before = #fails
	T.check("(memory store) save after lost lock refused", s3:save(p3, false) == false and #fails == before + 1)
end
