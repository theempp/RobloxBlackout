-- Heist world layout (blockout). Shared: the server builds it; clients read it for the minimap, lasers
-- and parking glows. Units = studs, ground top y = 0, yaw in degrees (0 faces -Z, -90 faces +X).
-- City: 10 blocks (2 rows x 5 columns) along an east-west avenue (z -20..20); tower in block 0-north;
-- exit gate at the east end; barricades on the avenue force detours. ALL POSITIONS ARE PLACEHOLDERS.
local V = Vector3.new
local M = {}

M.Wall = { Height = 16, Thick = 2 }
M.Bounds = { min = V(-260, 0, -240), max = V(1140, 0, 240) }
M.Arrival = { spawn = V(-150, 0, 20), kart = V(-200, 0, -12), kartGap = 8, yaw = -90 } -- karts face +X
M.TowerSpawn = V(100, 0, 30) -- recall respawn (outside the front door)
M.Tower = { min = V(40, 0, 40), max = V(160, 0, 160), door = V(100, 0, 40), service = V(160, 0, 146) }
M.Gate = { pos = V(1062, 0, 0), halfX = 12, halfZ = 30 }
M.Barricades = { V(400, 0, 0), V(800, 0, 0) } -- 8 x 40 blockers across the avenue

-- Blocks: sidewalk slabs. kind: "tower" | "lotS" | "lotE" | "lotW" | nil (generic buildings).
M.Blocks = {}
for col = 0, 4 do
	for _, row in ipairs({ 1, -1 }) do
		local x0 = 20 + col * 200
		local z0 = row == 1 and 20 or -180
		local kind = (col == 0 and row == 1) and "tower" or (col == 0 and row == -1) and "lotS" or (col == 1 and row == 1) and "lotE" or nil
		table.insert(M.Blocks, { min = V(x0, 0, z0), max = V(x0 + 160, 0, z0 + 160), kind = kind, col = col, row = row })
	end
end
table.insert(M.Blocks, { min = V(-140, 0, 30), max = V(-30, 0, 170), kind = "lotW", col = -1, row = 1 })

-- Walls along X (fixed z) or Z (fixed x) with door gaps { {from, to} }. Returns boxes { c, s }.
local function wall(axis, at, a0, a1, gaps, h, y0)
	local out, cur = {}, a0
	h = h or M.Wall.Height
	y0 = y0 or 0
	local cuts = table.clone(gaps or {})
	table.sort(cuts, function(p, q)
		return p[1] < q[1]
	end)
	table.insert(cuts, { a1, a1 })
	for _, g in ipairs(cuts) do
		if g[1] > cur then
			local mid, len = (cur + g[1]) / 2, g[1] - cur
			if axis == "x" then
				table.insert(out, { c = V(mid, y0 + h / 2, at), s = V(len, h, M.Wall.Thick) })
			else
				table.insert(out, { c = V(at, y0 + h / 2, mid), s = V(M.Wall.Thick, h, len) })
			end
		end
		cur = math.max(cur, g[2])
	end
	return out
end
M.wall = wall

local function add(list, boxes)
	for _, b in ipairs(boxes) do
		table.insert(list, b)
	end
end

-- Tower: lobby (z 40-90) -> corridor (x 94-106) -> laser hall (z 100-135) -> Data Vault (z 135-160).
-- Security office off the lobby (x 40-65). Service door (east, vault) stays shut until the vault is breached.
M.TowerWalls = {}
add(M.TowerWalls, wall("x", 40, 40, 160, { { 94, 106 } })) -- front, main door
add(M.TowerWalls, wall("x", 160, 40, 160))
add(M.TowerWalls, wall("z", 40, 40, 160))
add(M.TowerWalls, wall("z", 160, 40, 160, { { 140, 152 } })) -- service door gap
add(M.TowerWalls, wall("x", 90, 40, 160, { { 45, 55 }, { 94, 106 } })) -- lobby north: office door, corridor
add(M.TowerWalls, wall("z", 65, 90, 135)) -- office east / laser hall west
add(M.TowerWalls, wall("x", 130, 40, 65)) -- office north
add(M.TowerWalls, wall("z", 94, 90, 100))
add(M.TowerWalls, wall("z", 106, 90, 100))
add(M.TowerWalls, wall("x", 100, 65, 135, { { 94, 106 } })) -- laser hall south
add(M.TowerWalls, wall("z", 135, 100, 135)) -- laser hall east
add(M.TowerWalls, wall("x", 135, 55, 160, { { 90, 110 } })) -- vault south (gauntlet exit)
add(M.TowerWalls, wall("z", 55, 135, 160)) -- vault west
M.ServiceDoor = { c = V(160, 8, 146), s = V(2, 16, 12) }
M.Rooms = { -- minimap + "inside tower" tests
	{ name = "Lobby", min = V(40, 0, 40), max = V(160, 0, 90) },
	{ name = "Office", min = V(40, 0, 90), max = V(65, 0, 130) },
	{ name = "Corridor", min = V(94, 0, 90), max = V(106, 0, 100) },
	{ name = "Lasers", min = V(65, 0, 100), max = V(135, 0, 135) },
	{ name = "Vault", min = V(55, 0, 135), max = V(160, 0, 160) },
}

-- Lasers (Data Vault wing). a/b = endpoints; move = offset amplitude; period seconds (0 = static).
-- Position at time t: a/b + move * sin(2*pi*t*speedMult/period + phase). Tier raises speedMult.
M.Lasers = {
	{ a = V(66, 1.2, 106), b = V(134, 1.2, 106), move = V(0, 0, 0), period = 0 }, -- knee beam: jump it
	{ a = V(66, 3.4, 114), b = V(134, 3.4, 114), move = V(0, 0, 4.5), period = 4.5 }, -- sweeping torso beam
	{ a = V(78, 0, 122), b = V(78, 9, 122), move = V(7, 0, 0), period = 5 }, -- sliding vertical fence
	{ a = V(100, 0, 122), b = V(100, 9, 122), move = V(7, 0, 0), period = 5, phase = math.pi },
	{ a = V(122, 0, 122), b = V(122, 9, 122), move = V(7, 0, 0), period = 5 },
	{ a = V(66, 1.2, 130), b = V(134, 1.2, 130), move = V(0, 0, 0), period = 0 },
}
M.LaserPanel = V(105, 4, 95) -- corridor wall; hack = lasers off for a while
M.Terminal = V(44, 3, 116) -- security office; hack = alarm drops one tier

M.HeavyPedestals = { V(80, 0, 150), V(95, 0, 150), V(110, 0, 150), V(125, 0, 150) }
M.SmallLoot = {
	V(55, 3.2, 60), V(75, 3.2, 46), V(125, 3.2, 46), V(150, 3.2, 70),
	V(46, 3.2, 100), V(60, 3.2, 124),
	V(60, 3.2, 142), V(60, 3.2, 156), V(95, 3.2, 158), V(125, 3.2, 158), V(150, 3.2, 156), V(140, 3.2, 140),
}

-- Guard set A. Sentry routes are closed loops (ground); watchers fly (y = 11). Order = spawn priority.
M.GuardSets = {
	A = {
		sentries = {
			{ V(55, 0, 55), V(145, 0, 55), V(145, 0, 80), V(55, 0, 80) }, -- lobby
			{ V(65, 0, 142), V(145, 0, 142), V(145, 0, 155), V(65, 0, 155) }, -- vault
			{ V(145, 0, 80), V(55, 0, 80), V(55, 0, 55), V(145, 0, 55) }, -- lobby, opposite phase
			{ V(47, 0, 97), V(60, 0, 97), V(60, 0, 125), V(47, 0, 125) }, -- office
			{ V(145, 0, 155), V(65, 0, 155), V(65, 0, 142), V(145, 0, 142) }, -- vault, opposite phase
			{ V(50, 0, 62), V(100, 0, 62), V(150, 0, 62), V(100, 0, 62) }, -- lobby centre line
		},
		watchers = {
			{ V(50, 11, 50), V(150, 11, 50), V(150, 11, 85), V(50, 11, 85) },
			{ V(62, 11, 140), V(152, 11, 140), V(152, 11, 156), V(62, 11, 156) },
		},
		cameras = { -- pos, centre yaw (deg), sweep half-angle
			{ pos = V(157, 12, 43), yaw = 45, sweep = 45 },
			{ pos = V(43, 12, 87), yaw = -135, sweep = 45 },
			{ pos = V(132, 12, 103), yaw = 45, sweep = 45 },
			{ pos = V(57, 12, 158), yaw = -135, sweep = 45 },
		},
	},
}

-- Parking pool (§5d REC-AUTO): 3 zones x 5 = 1 obvious (near the exits), 2 medium, 2 hidden (garages).
local function spot(id, zone, quality, x, z, yaw)
	return { id = id, zone = zone, quality = quality, pos = V(x, 0, z), yaw = yaw }
end
M.Spots = {
	spot("S1", "S", "obvious", 100, -10, -90), spot("S2", "S", "medium", 60, -62, 0), spot("S3", "S", "medium", 140, -62, 0),
	spot("S4", "S", "hidden", 52, -152, 0), spot("S5", "S", "hidden", 148, -152, 0),
	spot("W1", "W", "obvious", 0, 70, 180), spot("W2", "W", "medium", -60, 62, 90), spot("W3", "W", "medium", -60, 118, 90),
	spot("W4", "W", "hidden", -118, 150, 90), spot("W5", "W", "hidden", -118, 48, 90),
	spot("E1", "E", "obvious", 196, 150, 180), spot("E2", "E", "medium", 244, 58, 0), spot("E3", "E", "medium", 244, 162, 180),
	spot("E4", "E", "hidden", 356, 160, -90), spot("E5", "E", "hidden", 356, 42, -90),
}
-- Garages hide the "hidden" spots from repo drones (roof blocks line of sight): 3 walls + roof,
-- open side faces `open` (unit vector toward the road).
M.Garages = {
	{ at = V(52, 0, -152), open = V(0, 0, 1) }, { at = V(148, 0, -152), open = V(0, 0, 1) },
	{ at = V(-118, 0, 150), open = V(1, 0, 0) }, { at = V(-118, 0, 48), open = V(1, 0, 0) },
	{ at = V(356, 0, 160), open = V(-1, 0, 0) }, { at = V(356, 0, 42), open = V(-1, 0, 0) },
}
M.GarageSize = V(16, 10, 18)
-- Sneak buildings (§5d "sneak through 2-3 buildings"): doorways on both ends, between the tower's
-- service exit and zone E.
M.SneakBuildings = {
	{ min = V(268, 0, 60), max = V(312, 0, 100), doors = { V(268, 0, 80), V(312, 0, 80) } },
	{ min = V(268, 0, 112), max = V(312, 0, 152), doors = { V(268, 0, 132), V(312, 0, 132) } },
}

-- Repo drone loops (y = 28) over the stash zones; order = spawn priority (2 + 1 per alarm tier, max 4).
M.RepoLoops = {
	{ V(30, 28, -30), V(170, 28, -30), V(170, 28, -110), V(30, 28, -110) }, -- zone S
	{ V(212, 28, 30), V(262, 28, 30), V(262, 28, 172), V(212, 28, 172) }, -- zone E
	{ V(-84, 28, 40), V(-10, 28, 40), V(-10, 28, 160), V(-84, 28, 160) }, -- zone W
	{ V(-20, 28, -12), V(380, 28, -12), V(380, 28, 12), V(-20, 28, 12) }, -- avenue sweep
}

function M.inRect(p, min, max)
	return p.X >= min.X and p.X <= max.X and p.Z >= min.Z and p.Z <= max.Z
end

function M.inTower(p)
	return M.inRect(p, M.Tower.min, M.Tower.max) and p.Y < M.Wall.Height + 4
end

function M.spotById(id)
	for _, s in ipairs(M.Spots) do
		if s.id == id then
			return s
		end
	end
	return nil
end

return M
