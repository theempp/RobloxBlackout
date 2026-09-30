-- Laser math (pure) + the real gauntlet layout: beams span the hall, jumping clears knee beams.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local M = require(RS.BlackoutCrew.HeistMap)
local Lasers = require(RS.BlackoutCrew.Lasers)
local Gauntlet = require(SSS.BlackoutCrew.heist.Gauntlet)
local V = Vector3.new

return function(T)
	local static = { a = V(0, 1, 0), b = V(10, 1, 0), move = V(0, 0, 4), period = 0 }
	local a, b = Lasers.at(static, 123, 2)
	T.check("static beam never moves", a == static.a and b == static.b)
	local mover = { a = V(0, 1, 0), b = V(10, 1, 0), move = V(0, 0, 4), period = 4 }
	local a1 = Lasers.at(mover, 1, 1)
	T.near("moving beam at quarter period = full offset", a1.Z, 4, 1e-6)
	local a2 = Lasers.at(mover, 0.5, 2)
	T.near("speed x2 halves the period", a2.Z, 4, 1e-6)
	local ph = Lasers.at({ a = V(0, 1, 0), b = V(1, 1, 0), move = V(0, 0, 4), period = 4, phase = math.pi }, 1, 1)
	T.near("phase shifts", ph.Z, -4, 1e-6)
	T.near("segDist mid", Lasers.segDist(V(5, 3, 0), V(0, 0, 0), V(10, 0, 0)), 3)
	T.near("segDist past end", Lasers.segDist(V(13, 4, 0), V(0, 0, 0), V(10, 0, 0)), 5)
	local knee = M.Lasers[1]
	T.check("standing touches knee beam", Lasers.touches(V(100, 3, knee.a.Z), knee.a, knee.b, C.Lasers))
	T.check("jumping clears knee beam", not Lasers.touches(V(100, 7, knee.a.Z), knee.a, knee.b, C.Lasers))
	T.check("off the beam line: clear", not Lasers.touches(V(100, 3, knee.a.Z + 2), knee.a, knee.b, C.Lasers))

	local room
	for _, r in ipairs(M.Rooms) do
		if r.name == "Lasers" then
			room = r
		end
	end
	local inside, spans = true, true
	for i, def in ipairs(M.Lasers) do
		for _, t in ipairs({ 0, 1.1, 2.3, 3.7 }) do
			local p, q = Lasers.at(def, t, C.Lasers.SpeedByTier[3])
			for _, e in ipairs({ p, q }) do
				if not M.inRect(e, room.min - V(1, 0, 1), room.max + V(1, 0, 1)) then
					inside = false
				end
			end
		end
		if def.a.Y == def.b.Y and math.abs(def.b.X - def.a.X) < (room.max.X - room.min.X) - 4 then
			spans = false -- horizontal beams must block the whole width
		end
	end
	T.check("beams stay in the laser hall", inside)
	T.check("horizontal beams span the hall", spans)
	T.check("tiers speed lasers up", C.Lasers.SpeedByTier[1] < C.Lasers.SpeedByTier[2] and C.Lasers.SpeedByTier[2] < C.Lasers.SpeedByTier[3])
	T.eq("gauntlet speed clamps tiers", Gauntlet.speed(9), C.Lasers.SpeedByTier[#C.Lasers.SpeedByTier])
	T.check("real layout: knee beam hit found", Gauntlet.touching(V(100, 3, knee.a.Z), 0, 1) ~= nil)
	-- Vertical fence has a gap wide enough to walk through at every sampled time.
	local gapOk = true
	for t = 0, 5, 0.25 do
		local xs = {}
		for i = 3, 5 do
			local p = Lasers.at(M.Lasers[i], t, 1)
			table.insert(xs, p.X)
		end
		table.sort(xs)
		local widest = math.max(xs[1] - room.min.X, xs[2] - xs[1], xs[3] - xs[2], room.max.X - xs[3])
		if widest < 6 then
			gapOk = false
		end
	end
	T.check("fence always leaves a >= 6 stud gap", gapOk)
end
