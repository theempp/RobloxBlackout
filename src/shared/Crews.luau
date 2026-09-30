-- Crews (ported from roblox 1 GameService: invite/accept/leave, cap 4, haul bonus). A lobby queue pad's
-- squad is a crew; the heist rebuilds it from the teleport roster. Pure: players are opaque keys and
-- time is passed in, so tests use plain tables and fake clocks. Change from v0.3: a departing leader
-- promotes the next member instead of disbanding (a pad squad shouldn't vanish when one player steps off).
local Crews = {}
Crews.__index = Crews

function Crews.new(maxSize, inviteTtl)
	return setmetatable({ max = maxSize, ttl = inviteTtl, leaderOf = {}, lists = {}, invites = {} }, Crews)
end

function Crews:crewOf(p)
	return self.leaderOf[p]
end

-- Members in join order (leader first). A player in no crew is a crew of one.
function Crews:members(p)
	local leader = self.leaderOf[p]
	return leader and table.clone(self.lists[leader]) or { p }
end

function Crews:size(p)
	local leader = self.leaderOf[p]
	return leader and #self.lists[leader] or 1
end

-- Direct join (queue pads: standing on the pad is the consent). leader = nil starts a new crew.
function Crews:join(p, leader)
	if self.leaderOf[p] then
		return false, "inCrew"
	end
	if leader == nil or leader == p then
		self.lists[p] = { p }
		self.leaderOf[p] = p
		return true
	end
	if self.leaderOf[leader] ~= leader then
		return false, "noCrew"
	end
	local list = self.lists[leader]
	if #list >= self.max then
		return false, "full"
	end
	table.insert(list, p)
	self.leaderOf[p] = leader
	self.invites[p] = nil
	return true
end

function Crews:invite(from, to, now)
	if from == to or self.leaderOf[to] then
		return false, "target"
	end
	local leader = self.leaderOf[from]
	if leader and leader ~= from then
		return false, "notLeader"
	end
	if self:size(from) >= self.max then
		return false, "full"
	end
	self.invites[to] = { from = from, expires = now + self.ttl }
	return true
end

function Crews:accept(p, now)
	local inv = self.invites[p]
	self.invites[p] = nil
	if not inv or inv.expires < now or self.leaderOf[p] then
		return false, "invite"
	end
	local leader = inv.from
	local lead = self.leaderOf[leader]
	if lead and lead ~= leader then
		return false, "notLeader"
	end
	if not lead then
		self:join(leader, nil)
	end
	return self:join(p, leader)
end

function Crews:leave(p)
	local leader = self.leaderOf[p]
	if not leader then
		return
	end
	local list = self.lists[leader]
	table.remove(list, table.find(list, p))
	self.leaderOf[p] = nil
	if leader == p then
		self.lists[p] = nil
		local heir = list[1]
		if heir then
			self.lists[heir] = list
			for _, m in ipairs(list) do
				self.leaderOf[m] = heir
			end
		end
	end
end

-- Player gone: leave + clear pending invites to or from them.
function Crews:remove(p)
	self:leave(p)
	self.invites[p] = nil
	for to, inv in pairs(self.invites) do
		if inv.from == p then
			self.invites[to] = nil
		end
	end
end

-- Haul bonus (§4 crews): +BonusPerMember per extra member, capped.
function Crews.bonus(crewSize, perMember, cap)
	return math.min(math.max(crewSize - 1, 0) * perMember, cap)
end

return Crews
