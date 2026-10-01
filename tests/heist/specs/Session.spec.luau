-- Heist session: TeleportData validation, roster, late joiners, start rules, pay-once, save schema 2.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local Rules = require(RS.BlackoutCrew.Rules)
local Session = require(SSS.BlackoutCrew.heist.Session)

return function(T)
	local good = { crewSize = 2, difficulty = "normal", roster = { 101, 202 }, runId = "r1" }
	local j = Session.cleanJoin(good)
	T.check("valid join data", j and j.crewSize == 2 and j.roster[202] == 2 and j.order[1] == 101)
	local bad = {
		{ "not a table", 5 },
		{ "crew 0", { crewSize = 0, difficulty = "normal", roster = {}, runId = "r" } },
		{ "crew 5", { crewSize = 5, difficulty = "normal", roster = { 1, 2, 3, 4, 5 }, runId = "r" } },
		{ "fractional crew", { crewSize = 1.5, difficulty = "normal", roster = { 1 }, runId = "r" } },
		{ "unknown difficulty", { crewSize = 1, difficulty = "insane", roster = { 1 }, runId = "r" } },
		{ "roster length", { crewSize = 2, difficulty = "normal", roster = { 1 }, runId = "r" } },
		{ "duplicate ids", { crewSize = 2, difficulty = "normal", roster = { 1, 1 }, runId = "r" } },
		{ "non-number id", { crewSize = 1, difficulty = "normal", roster = { "x" }, runId = "r" } },
		{ "no run id", { crewSize = 1, difficulty = "normal", roster = { 1 } } },
		{ "NaN crew", { crewSize = 0 / 0, difficulty = "normal", roster = {}, runId = "r" } },
	}
	for _, b in ipairs(bad) do
		T.check("reject " .. b[1], Session.cleanJoin(b[2]) == nil)
	end

	local clock = 0
	local started, skipped = nil, {}
	local function new()
		started, skipped = nil, {}
		return Session.new({
			now = function()
				return clock
			end,
			onStart = function(players, info)
				started = { players = players, info = info }
			end,
			onSkip = function(p, why)
				table.insert(skipped, why)
			end,
		})
	end
	local p1, p2, p3 = { UserId = 101 }, { UserId = 202 }, { UserId = 303 }
	local s = new()
	T.eq("roster member joins", s:arrive(p2, good), "joined")
	T.eq("stranger skipped", s:arrive(p3, good), "skipped")
	T.check("tick waits for roster", not s:tick())
	T.eq("second member joins (no data needed)", s:arrive(p1, nil), "joined")
	T.check("all here starts", s:tick() and started ~= nil)
	T.check("slots follow roster order", started.players[1] == p1 and started.players[2] == p2)
	T.check("run info", started.info.crewSize == 2 and started.info.difficulty == "normal" and started.info.runId == "r1" and started.info.live)
	T.eq("late joiner skipped", s:arrive({ UserId = 101 }, good), "late")
	T.check("skip reasons", skipped[1] == "roster" and skipped[2] == "late")

	clock = 0
	s = new()
	s:arrive(p1, good)
	clock = C.Heist.ArrivalTimeout - 0.1
	T.check("no start before timeout", not s:tick())
	clock = C.Heist.ArrivalTimeout
	T.check("timeout starts with who's here", s:tick() and started.info.crewSize == 1)

	clock = 0
	s = new()
	s:arrive(p3, nil)
	T.check("local: no data accepted", s.info == nil and #s.players == 1)
	clock = C.Heist.LocalStartDelay
	T.check("local start after delay", s:tick() and not started.info.live and started.info.difficulty == C.Lobby.DefaultDifficulty)

	local profiles = { loaded = { [p3] = Rules.defaultProfile() } }
	local g1 = s:grant(profiles, { [p3] = 250.7 })
	T.check("grant", g1[p3] == 250 and profiles.loaded[p3].credits == 250 and profiles.loaded[p3].heist.runs == 1)
	local g2 = s:grant(profiles, { [p3] = 250 })
	T.check("second grant pays nothing", g2[p3] == nil and profiles.loaded[p3].credits == 250)
	local s2 = new()
	s2:arrive(p1, nil)
	s2:start()
	local g3 = s2:grant({ loaded = { [p1] = Rules.defaultProfile() } }, { [p1] = -50 })
	T.check("negative reward clamps to 0", g3[p1] == 0)

	-- Save schema 2: heist block validated; a schema-1 save migrates with defaults.
	local v1 = Rules.clean({ schemaVersion = 1, credits = 700 })
	T.check("v1 save migrates", v1.credits == 700 and v1.heist.runs == 0 and v1.heist.lastObvious == false and v1.schemaVersion == C.Profile.SchemaVersion and v1.tutorial.done == false)
	local v2 = Rules.clean({ schemaVersion = 2, heist = { runs = 5.9, lastObvious = true } })
	T.check("heist block kept", v2.heist.runs == 5 and v2.heist.lastObvious == true)
	local junk = Rules.clean({ heist = { runs = -3, lastObvious = "yes" } })
	T.check("heist block cleaned", junk.heist.runs == 0 and junk.heist.lastObvious == false)
end
