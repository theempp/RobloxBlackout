-- Heist blockout: tower, 10-block city, parking pool (§5d), gate; spots sit on open ground.
local RS = game:GetService("ReplicatedStorage")
local M = require(RS.BlackoutCrew.HeistMap)

return function(T)
	local blocks = 0
	for _, b in ipairs(M.Blocks) do
		if b.col >= 0 then
			blocks += 1
		end
	end
	T.eq("10 city blocks (8-10)", blocks, 10)
	local zones, q = {}, {}
	for _, s in ipairs(M.Spots) do
		zones[s.zone] = (zones[s.zone] or 0) + 1
		q[s.zone .. s.quality] = (q[s.zone .. s.quality] or 0) + 1
	end
	T.eq("15 parking spots", #M.Spots, 15)
	for _, z in ipairs({ "S", "W", "E" }) do
		T.check("zone " .. z .. " = 1 obvious, 2 medium, 2 hidden", zones[z] == 5 and q[z .. "obvious"] == 1 and q[z .. "medium"] == 2 and q[z .. "hidden"] == 2)
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { workspace:FindFirstChild("HeistLoot") }
	local clear, covered, open = true, 0, 0
	for _, s in ipairs(M.Spots) do
		local down = workspace:Raycast(s.pos + Vector3.new(0, 4, 0), Vector3.new(0, -8, 0), rp)
		if not down or down.Instance.Name ~= "Ground" and down.Instance.Name ~= "Block" then
			clear = false
		end
		local up = workspace:Raycast(s.pos + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), rp)
		if s.quality == "hidden" and up then
			covered += 1
		elseif s.quality ~= "hidden" and not up then
			open += 1
		end
	end
	T.check("every spot is drivable floor", clear)
	T.eq("hidden spots are roofed", covered, 6)
	T.eq("obvious/medium spots are open sky", open, 9)
	local map = workspace:FindFirstChild("HeistMap")
	T.check("tower built", map and map:FindFirstChild("Tower") and #map.Tower:GetChildren() > 20)
	T.check("gate built", map and map.City:FindFirstChild("GateBeam") ~= nil)
	T.check("hackables tagged", #game:GetService("CollectionService"):GetTagged("BC_Hackable") >= 2)
	T.check("inTower", M.inTower(Vector3.new(100, 3, 100)) and not M.inTower(Vector3.new(100, 3, 30)))
	T.check("front door open", not workspace:Raycast(Vector3.new(100, 3, 30), Vector3.new(0, 0, 20), rp))
	T.check("arrival spawn", map and map:FindFirstChild("ArrivalSpawn") ~= nil and map.TowerSpawn.Enabled == false)
	T.check("streaming on", workspace.StreamingEnabled)
end
