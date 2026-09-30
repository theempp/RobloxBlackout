--!strict
-- Token bucket per key. take(key, now) -> true if allowed. Pure (caller passes time) so it is testable.
local RateLimit = {}
RateLimit.__index = RateLimit

export type Bucket = typeof(setmetatable({} :: { rate: number, burst: number, state: { [any]: { number } } }, RateLimit))

function RateLimit.new(rate: number, burst: number): Bucket
	return setmetatable({ rate = rate, burst = burst, state = {} }, RateLimit)
end

function RateLimit.take(self: Bucket, key: any, now: number, cost: number?): boolean
	local s = self.state[key]
	if not s then
		s = { self.burst, now }
		self.state[key] = s
	end
	s[1] = math.min(self.burst, s[1] + (now - s[2]) * self.rate)
	s[2] = now
	local c = cost or 1
	if s[1] < c then
		return false
	end
	s[1] -= c
	return true
end

function RateLimit.forget(self: Bucket, key: any)
	self.state[key] = nil
end

return RateLimit
