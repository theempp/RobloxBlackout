-- Heist world blockout from shared HeistMap (primitives only, neon over dynamic lights, no shadows
-- casting from trims). Built once at server start; per-run state (service door, laser hack) resets.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local M = require(shared.HeistMap)
local V = Vector3.new

local Map = {}
local COL = {
	road = Color3.fromRGB(30, 32, 40), walk = Color3.fromRGB(52, 54, 64), wall = Color3.fromRGB(58, 60, 72),
	tower = Color3.fromRGB(38, 40, 52), building = Color3.fromRGB(44, 46, 58), trim = Color3.fromRGB(64, 220, 255),
	trim2 = Color3.fromRGB(255, 80, 190), desk = Color3.fromRGB(80, 84, 98), gate = Color3.fromRGB(0, 158, 115),
	block = Color3.fromRGB(230, 159, 0), door = Color3.fromRGB(120, 30, 40),
}

local function box(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if material == Enum.Material.Neon then
		p.CastShadow = false
		p.CanQuery = false
	end
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end
Map.box = box

local function slab(parent, name, min, max, color, top)
	local s = max - min
	return box(parent, name, V(s.X, 0.5, s.Z), V((min.X + max.X) / 2, (top or 0.1) - 0.25, (min.Z + max.Z) / 2), color, Enum.Material.Concrete)
end

local function building(parent, min, max, h)
	local s = max - min
	local c = V((min.X + max.X) / 2, h / 2, (min.Z + max.Z) / 2)
	box(parent, "Building", V(s.X, h, s.Z), c, COL.building, Enum.Material.Concrete)
	box(parent, "Trim", V(s.X + 0.2, 0.6, s.Z + 0.2), c + V(0, h / 2 - 3, 0), COL.trim, Enum.Material.Neon)
end

-- Garage in local space: -Z (look) faces the opening; back wall, two sides, roof.
local function garage(parent, g)
	local sz, h = M.GarageSize, M.GarageSize.Y
	local cf = CFrame.lookAt(g.at, g.at + g.open)
	local f = Instance.new("Model")
	f.Name = "Garage"
	box(f, "Back", V(sz.X, h, 1), cf * CFrame.new(0, h / 2, sz.Z / 2), COL.wall)
	for _, sgn in ipairs({ -1, 1 }) do
		box(f, "Side", V(1, h, sz.Z), cf * CFrame.new(sgn * sz.X / 2, h / 2, 0), COL.wall)
	end
	box(f, "Roof", V(sz.X + 2, 1, sz.Z + 2), cf * CFrame.new(0, h + 0.5, 0), COL.wall)
	box(f, "Trim", V(sz.X, 0.4, 0.4), cf * CFrame.new(0, h - 0.5, -sz.Z / 2), COL.trim2, Enum.Material.Neon)
	f.Parent = parent
end

local function lighting()
	Lighting.ClockTime = 21
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(55, 55, 75)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 72, 95)
	Lighting.FogColor = Color3.fromRGB(20, 18, 34)
	Lighting.FogStart = 250
	Lighting.FogEnd = 900 -- hides distant blocks: fewer pixels, not fewer parts (streaming does that)
	Lighting.GlobalShadows = false -- mobile perf first; revisit at the visual review
	Map.lighting = { ClockTime = 21, Brightness = 1.2, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
end

function Map.buildCity(root)
	local city = Instance.new("Folder")
	city.Name = "City"
	city.Parent = root
	local b = M.Bounds
	box(city, "Ground", V(b.max.X - b.min.X, 1, b.max.Z - b.min.Z), V((b.min.X + b.max.X) / 2, -0.5, (b.min.Z + b.max.Z) / 2), COL.road, Enum.Material.Asphalt)
	for _, e in ipairs({ { V(b.min.X, 0, 0), V(2, 20, b.max.Z - b.min.Z) }, { V(b.max.X, 0, 0), V(2, 20, b.max.Z - b.min.Z) },
		{ V((b.min.X + b.max.X) / 2, 0, b.min.Z), V(b.max.X - b.min.X, 20, 2) }, { V((b.min.X + b.max.X) / 2, 0, b.max.Z), V(b.max.X - b.min.X, 20, 2) } }) do
		box(city, "Perimeter", e[2], e[1] + V(0, 10, 0), COL.wall, Enum.Material.Concrete)
	end
	local heights = { 46, 72, 38, 60, 84, 52, 66, 40, 58, 76 }
	for i, blk in ipairs(M.Blocks) do
		slab(city, "Block", blk.min, blk.max, COL.walk)
		if not blk.kind then
			local mid = (blk.min.X + blk.max.X) / 2
			building(city, blk.min + V(8, 0, 8), V(mid - 6, 0, blk.max.Z - 8), heights[i % #heights + 1])
			building(city, V(mid + 6, 0, blk.min.Z + 8), blk.max - V(8, 0, 8), heights[(i + 3) % #heights + 1])
		end
	end
	for _, g in ipairs(M.Garages) do
		garage(city, g)
	end
	for _, sb in ipairs(M.SneakBuildings) do
		local f = Instance.new("Model")
		f.Name = "SneakBuilding"
		local min, max = sb.min, sb.max
		for _, w in ipairs({
			M.wall("x", min.Z, min.X, max.X, nil, 12), M.wall("x", max.Z, min.X, max.X, nil, 12),
			M.wall("z", min.X, min.Z, max.Z, { { sb.doors[1].Z - 5, sb.doors[1].Z + 5 } }, 12),
			M.wall("z", max.X, min.Z, max.Z, { { sb.doors[2].Z - 5, sb.doors[2].Z + 5 } }, 12),
		}) do
			for _, seg in ipairs(w) do
				box(f, "Wall", seg.s, seg.c, COL.wall, Enum.Material.Concrete)
			end
		end
		local s = max - min
		box(f, "Roof", V(s.X + 2, 1, s.Z + 2), V((min.X + max.X) / 2, 12.5, (min.Z + max.Z) / 2), COL.wall)
		f.Parent = city
	end
	for _, at in ipairs(M.Barricades) do
		box(city, "Barricade", V(8, 5, 40), at + V(0, 2.5, 0), COL.block, Enum.Material.SmoothPlastic)
		box(city, "BarricadeGlow", V(8.2, 0.6, 40.2), at + V(0, 4.2, 0), COL.trim2, Enum.Material.Neon)
	end
	local g = M.Gate
	for _, sgn in ipairs({ -1, 1 }) do
		box(city, "GatePost", V(3, 18, 3), g.pos + V(0, 9, sgn * (g.halfZ + 2)), COL.gate, Enum.Material.Neon)
	end
	box(city, "GateBeam", V(3, 3, g.halfZ * 2 + 7), g.pos + V(0, 19, 0), COL.gate, Enum.Material.Neon)
end

function Map.buildTower(root)
	local t = Instance.new("Folder")
	t.Name = "Tower"
	t.Parent = root
	for _, w in ipairs(M.TowerWalls) do
		box(t, "Wall", w.s, w.c, COL.tower, Enum.Material.Concrete)
	end
	local min, max = M.Tower.min, M.Tower.max
	local s, c = max - min, (min + max) / 2
	local H = M.Wall.Height
	box(t, "Ceiling", V(s.X + 2, 1, s.Z + 2), V(c.X, H + 0.5, c.Z), COL.tower, Enum.Material.Concrete)
	box(t, "Facade", V(s.X - 10, 70, s.Z - 10), V(c.X, H + 1 + 35, c.Z), COL.tower, Enum.Material.Glass, { Transparency = 0.1 })
	for i = 1, 3 do
		box(t, "FacadeTrim", V(s.X - 9.6, 0.8, s.Z - 9.6), V(c.X, H + 1 + i * 20, c.Z), COL.trim, Enum.Material.Neon)
	end
	box(t, "DoorGlow", V(12, 0.6, 0.6), M.Tower.door + V(0, H - 1, -1.4), COL.trim, Enum.Material.Neon)
	-- Room ceiling strips (emissive, no light objects)
	for _, r in ipairs(M.Rooms) do
		local rs, rc = r.max - r.min, (r.min + r.max) / 2
		box(t, "Strip", V(math.max(2, rs.X - 8), 0.3, 1), V(rc.X, H - 0.2, rc.Z), Color3.fromRGB(200, 210, 255), Enum.Material.Neon)
	end
	local sd = M.ServiceDoor
	Map.serviceDoor = box(t, "ServiceDoor", sd.s, sd.c, COL.door, Enum.Material.SmoothPlastic)
	for _, p in ipairs(M.SmallLoot) do
		box(t, "Desk", V(4, 3, 2.5), V(p.X, 1.5, p.Z), COL.desk)
	end
	for _, p in ipairs(M.HeavyPedestals) do
		box(t, "Pedestal", V(3.2, 1, 3.2), p + V(0, 0.5, 0), COL.desk)
	end
	-- Laser emitters: small posts at both ends of each beam's rest position (beams are client-rendered).
	for _, l in ipairs(M.Lasers) do
		for _, e in ipairs({ l.a, l.b }) do
			box(t, "Emitter", V(1, 1, 1), e, Color3.fromRGB(120, 20, 30), Enum.Material.SmoothPlastic, { CanCollide = false })
		end
	end
	local panel = box(t, "LaserPanel", V(0.6, 2.4, 2), M.LaserPanel, Color3.fromRGB(255, 70, 70), Enum.Material.Neon, { CanQuery = true })
	panel:SetAttribute("Kind", "laserPanel")
	panel:SetAttribute("Range", 7)
	CollectionService:AddTag(panel, "BC_Hackable")
	local term = box(t, "Terminal", V(2, 3, 1.4), M.Terminal, Color3.fromRGB(86, 180, 233), Enum.Material.Neon, { CanQuery = true })
	term:SetAttribute("Kind", "terminal")
	term:SetAttribute("Range", 7)
	CollectionService:AddTag(term, "BC_Hackable")
	Map.laserPanel, Map.terminal = panel, term
end

function Map.setServiceDoor(open)
	Map.serviceDoor.CanCollide = not open
	Map.serviceDoor.Transparency = open and 0.85 or 0
	workspace.HeistState:SetAttribute("ServiceOpen", open)
end

function Map.init(S)
	local folder = Instance.new("Folder")
	folder.Name = "HeistMap"
	folder.Parent = workspace
	Map.folder = folder
	lighting()
	Map.buildCity(folder)
	Map.buildTower(folder)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ArrivalSpawn"
	spawn.Size = V(10, 1, 10)
	spawn.CFrame = CFrame.new(M.Arrival.spawn - V(0, 0.45, 0))
	spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
	spawn.Color = Config.Colors.Panel
	spawn.Parent = folder
	local tspawn = spawn:Clone()
	tspawn.Name = "TowerSpawn"
	tspawn.CFrame = CFrame.new(M.TowerSpawn - V(0, 0.45, 0))
	tspawn.Enabled = false -- only used as a RespawnLocation for recalled players
	tspawn.Parent = folder
	Map.arrival, Map.towerSpawn = spawn, tspawn
	Map.setServiceDoor(false)
end

function Map.reset(S)
	Map.setServiceDoor(false)
end

return Map
