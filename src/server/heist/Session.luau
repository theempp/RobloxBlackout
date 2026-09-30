-- Heist session (§11): who is in this run. The first arrival's TeleportData (validated, never trusted)
-- sets the roster, crew size and difficulty; the run starts when the whole roster is here or after
-- ArrivalTimeout. Anyone arriving after the start, or not on the roster, is a late joiner: skipped
-- (sent back to the lobby). No TeleportData (Studio / unpublished) = "local": whoever arrives within
-- LocalStartDelay plays. Rewards are granted once per player per run, saved, then the crew returns
-- to the lobby together (local: the run restarts so Studio playtests can go again).
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local H = Config.Heist

local Session = {}
Session.__index = Session

local function int(n, lo, hi)
	return type(n) == "number" and n == n and n % 1 == 0 and n >= lo and n <= hi
end

-- Returns { crewSize, difficulty, roster = {[userId] = slot}, order = {userId}, runId } or nil.
function Session.cleanJoin(raw)
	if type(raw) ~= "table" or not int(raw.crewSize, 1, Config.Crew.MaxSize) then
		return nil
	end
	if type(raw.difficulty) ~= "string" or not Config.Difficulty[raw.difficulty] then
		return nil
	end
	if type(raw.runId) ~= "string" or #raw.runId == 0 or #raw.runId > 64 then
		return nil
	end
	if type(raw.roster) ~= "table" or #raw.roster ~= raw.crewSize then
		return nil
	end
	local roster, order = {}, {}
	for i = 1, raw.crewSize do
		local id = raw.roster[i]
		if not int(id, -1e15, 1e15) or roster[id] then
			return nil
		end
		roster[id] = i
		order[i] = id
	end
	return { crewSize = raw.crewSize, difficulty = raw.difficulty, roster = roster, order = order, runId = raw.runId }
end

-- opts: now(), onStart(players, info), onSkip(player, why)
function Session.new(opts)
	return setmetatable({ opts = opts, state = "waiting", players = {}, info = nil, firstAt = nil, paid = {}, skipped = {} }, Session)
end

function Session:has(player)
	return table.find(self.players, player) ~= nil
end

function Session:arrive(player, rawTeleportData)
	if self.state ~= "waiting" then
		self.skipped[player] = "late"
		self.opts.onSkip(player, "late")
		return "late"
	end
	if not self.info then
		self.info = Session.cleanJoin(rawTeleportData) -- first valid data wins; later arrivals can't rewrite it
	end
	if self.info and not self.info.roster[player.UserId] then
		self.skipped[player] = "roster"
		self.opts.onSkip(player, "roster")
		return "skipped"
	end
	if not self:has(player) then
		table.insert(self.players, player)
	end
	self.firstAt = self.firstAt or self.opts.now()
	return "joined"
end

function Session:leave(player)
	local i = table.find(self.players, player)
	if i then
		table.remove(self.players, i)
	end
end

function Session:allHere()
	if not self.info then
		return false
	end
	local here = 0
	for _, p in ipairs(self.players) do
		if self.info.roster[p.UserId] then
			here += 1
		end
	end
	return here >= self.info.crewSize
end

-- Starts the run when due. Returns true on the tick that started it.
function Session:tick()
	if self.state ~= "waiting" or #self.players == 0 then
		return false
	end
	local waited = self.opts.now() - self.firstAt
	if self:allHere() or waited >= (self.info and H.ArrivalTimeout or H.LocalStartDelay) then
		self:start()
		return true
	end
	return false
end

-- Slots follow roster order (compacted over who actually arrived); local = arrival order.
function Session:start()
	self.state = "running"
	local order = self.players
	if self.info then
		order = table.clone(self.players)
		table.sort(order, function(a, b)
			return self.info.roster[a.UserId] < self.info.roster[b.UserId]
		end)
		self.players = order
	end
	local info = {
		crewSize = #order, -- scale to who is actually here
		difficulty = self.info and self.info.difficulty or Config.Lobby.DefaultDifficulty,
		runId = self.info and self.info.runId or ("local-" .. math.floor(self.opts.now())),
		live = self.info ~= nil,
	}
	self.run = info
	self.opts.onStart(order, info)
end

-- Grant each player's reward exactly once per run. amounts = { [player] = credits }. Returns granted map.
function Session:grant(profiles, amounts)
	local granted = {}
	for _, p in ipairs(self.players) do
		local d = profiles.loaded[p]
		local amt = math.max(0, math.floor(amounts[p] or 0))
		if d and not self.paid[p] then
			self.paid[p] = true
			d.credits = math.min(d.credits + amt, Config.Profile.MaxCurrency)
			d.heist = d.heist or { runs = 0, lastObvious = false }
			d.heist.runs = math.min(d.heist.runs + 1, Config.Profile.MaxCurrency)
			granted[p] = amt
		end
	end
	self.state = "ended"
	return granted
end

return Session
