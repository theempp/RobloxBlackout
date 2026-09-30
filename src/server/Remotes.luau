-- Binds client->server remotes: per-player token bucket (Config.RateLimits) + pcall guard.
-- Excess events are dropped silently and counted (tests and the perf overlay read the counters).
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local RateLimit = require(shared.RateLimit)
local Log = require(shared.Log)

local Remotes = { dropped = {}, accepted = {}, errors = {} }
local buckets = {}

Players.PlayerRemoving:Connect(function(player)
	for _, b in pairs(buckets) do
		b:forget(player)
	end
end)

function Remotes.bind(remotes, name, handler)
	local cfg = assert(Config.RateLimits[name], "no rate limit for " .. name)
	local bucket = RateLimit.new(cfg[1], cfg[2])
	buckets[name] = bucket
	Remotes.dropped[name], Remotes.accepted[name], Remotes.errors[name] = 0, 0, 0
	remotes[name].OnServerEvent:Connect(function(player, ...)
		if not bucket:take(player, os.clock()) then
			Remotes.dropped[name] += 1
			return
		end
		Remotes.accepted[name] += 1
		local ok, err = pcall(handler, player, ...)
		if not ok then
			Remotes.errors[name] += 1
			Log.warn("Remotes", name, "handler error", err)
		end
	end)
end

return Remotes
