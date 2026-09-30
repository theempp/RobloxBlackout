-- Parking draw (§5d REC-AUTO): each round draws squad-size spots from the 15-spot pool, from at least
-- 2 zones when the squad has 2+ players, and never gives a player an obvious spot twice in a row.
-- Pure + deterministic per seed. players[i] = { lastObvious = bool } -> spots[i].
local Parking = {}

function Parking.draw(pool, players, seed)
	local rng = Random.new(seed)
	local order = table.clone(pool)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local taken, out, zones = {}, {}, {}
	for i, p in ipairs(players) do
		local pick
		for pass = 1, 2 do -- pass 1 enforces zone spread; pass 2 relaxes it if the pool can't
			for _, s in ipairs(order) do
				local okObvious = not (p.lastObvious and s.quality == "obvious")
				local okZone = pass == 2 or i ~= 2 or not zones[s.zone]
				if not taken[s.id] and okObvious and okZone then
					pick = s
					break
				end
			end
			if pick then
				break
			end
		end
		taken[pick.id] = true
		zones[pick.zone] = true
		out[i] = pick
	end
	return out
end

function Parking.zoneCount(spots)
	local z, n = {}, 0
	for _, s in ipairs(spots) do
		if not z[s.zone] then
			z[s.zone] = true
			n += 1
		end
	end
	return n
end

return Parking
