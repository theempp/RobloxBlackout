-- Lobby queue pad (§11). Standing on the pad = joining its squad (a crew). The first join starts the
-- countdown; a newcomer always gets JoinGrace seconds; everyone READY or a full squad shortens it.
-- At zero the squad launches (crew size + difficulty + roster). Joins are refused while launching:
-- late arrivals wait for the next squad. Pure: players are opaque keys, time is passed in.
local Queue = {}
Queue.__index = Queue

function Queue.new(id, cfg, crews)
	return setmetatable({ id = id, cfg = cfg, crews = crews, members = {}, ready = {}, deadline = nil,
		launching = false, difficulty = cfg.DefaultDifficulty }, Queue)
end

function Queue:has(p)
	return table.find(self.members, p) ~= nil
end

function Queue:allReady()
	for _, m in ipairs(self.members) do
		if not self.ready[m] then
			return false
		end
	end
	return #self.members > 0
end

function Queue:retime(now, joined)
	local c = self.cfg
	if #self.members == 0 then
		self.deadline = nil
		return
	end
	if not self.deadline then
		self.deadline = now + c.Countdown
	elseif joined then
		self.deadline = math.max(self.deadline, now + c.JoinGrace)
	end
	if self:allReady() then
		self.deadline = math.min(self.deadline, now + c.ReadyCountdown)
	elseif #self.members >= c.MaxSquad then
		self.deadline = math.min(self.deadline, now + c.FullCountdown)
	end
end

function Queue:join(p, now)
	if self.launching then
		return false, "launching"
	end
	if self:has(p) then
		return false, "already"
	end
	if #self.members >= self.cfg.MaxSquad then
		return false, "full"
	end
	local ok, why = self.crews:join(p, self.members[1])
	if not ok then
		return false, why
	end
	table.insert(self.members, p)
	self:retime(now, true)
	return true
end

-- Leaving is ignored while launching: the teleport owns the squad until it succeeds or the pad resets.
function Queue:leave(p, now)
	local i = table.find(self.members, p)
	if not i or self.launching then
		return false
	end
	table.remove(self.members, i)
	self.ready[p] = nil
	self.crews:leave(p)
	self:retime(now, false)
	return true
end

function Queue:setReady(p, on, now)
	if not self:has(p) or self.launching then
		return false
	end
	self.ready[p] = on == true
	self:retime(now, false)
	return true
end

function Queue:remaining(now)
	return self.deadline and math.max(0, self.deadline - now) or nil
end

-- Returns "launch" exactly once when the countdown ends.
function Queue:tick(now)
	if not self.launching and self.deadline and now >= self.deadline and #self.members > 0 then
		self.launching = true
		return "launch"
	end
	return nil
end

function Queue:launchData(keyOf)
	local roster = {}
	for _, m in ipairs(self.members) do
		table.insert(roster, keyOf and keyOf(m) or m)
	end
	return { crewSize = #self.members, difficulty = self.difficulty, roster = roster }
end

function Queue:reset()
	for _, m in ipairs(self.members) do
		self.crews:leave(m)
	end
	self.members, self.ready, self.deadline, self.launching = {}, {}, nil, false
end

return Queue
