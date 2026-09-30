-- Server cost of the heist loop (all systems, 10 Hz) and live AI / physics counts vs the budget.
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)
local S = require(SSS.BlackoutCrew.ServerState)

return function(T)
	local st = S.Heist.stats
	T.check("heist loop has ticked", st.n > 20, st.n)
	local mean = st.n > 0 and st.total / st.n * 1000 or 0
	print("BC_PERF", string.format("heist server tick mean=%.2fms max=%.2fms over %d ticks (10 Hz; Studio CLI)", mean, st.max * 1000, st.n))
	T.check("server tick well under budget (mean < 4 ms)", mean < 4, mean)
	local run = S.Heist.run
	if run and not run.ended then
		local moving = (run.towerCleared and 0 or S.enemies.alive()) + S.drones.alive(S.drones.repo) + S.drones.alive(S.drones.pursuit)
		T.check("moving AI within cap", moving <= C.Enemies.Cap, moving)
	end
	T.check("streaming on", workspace.StreamingEnabled)
	local parts = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print("BC_PERF", string.format("heist world parts=%d (blockout primitives)", parts))
	T.check("world stays a light blockout (< 1500 parts)", parts < 1500, parts)
end
