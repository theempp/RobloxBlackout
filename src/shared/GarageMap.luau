-- Garage layout shared by the server, tutorial and client cutscene. Matte finishes follow the owner override.
local C = require(script.Parent.Config)
local Track = require(script.Parent.TrackKit)
local GunModel = require(script.Parent.GunModel)
local G = C.Garage
local V = Vector3.new
local Map = {}

function Map.point(v)
	return G.Origin + v
end
function Map.frame(v)
	return CFrame.new(Map.point(v))
end
-- Station positions from Config (the client never builds the map, so no part lookups here).
-- Armory = the loadout terminal or the attachment bench (either opens the personal armory).
function Map.armoryNear(pos, range)
	return (pos - Map.point(G.Bench)).Magnitude <= range or (pos - Map.point(G.Terminal)).Magnitude <= range
end
function Map.lockerPoint()
	return Map.point(G.Locker + V(1, 3.5, 0)) -- centre of the station locker
end
function Map.build()
	local m = Instance.new("Model")
	m.Name = "Garage"
	local dark, wood, yellow = Color3.fromRGB(25, 26, 30), Color3.fromRGB(45, 34, 28), Color3.fromRGB(230, 176, 40)
	local function block(name, size, pos, color)
		local p = Track.block(m, name, size, Map.frame(pos), color or dark)
		p.CastShadow = false
		return p
	end
	local function sign(p, text)
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.StudsOffsetWorldSpace, gui.MaxDistance = UDim2.fromOffset(180, 36), V(0, p.Size.Y / 2 + 3, 0), 75
		gui.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Font, label.TextScaled, label.TextColor3 = Enum.Font.GothamBold, true, Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.2
		label.Text, label.Parent, gui.Parent = text, gui, p
	end
	block("Floor", V(300, 2, 250), V(0, -1, 0), wood).Material = Enum.Material.WoodPlanks
	-- Asymmetric facade leaves an open passage for the elevated track.
	block("FacadeRight", V(44, 45, 2), V(38, 22.5, -42), wood)
	block("FacadeLeft", V(13, 45, 2), V(-53.5, 22.5, -42), wood)
	block("FacadeFin", V(8, 45, 2), V(-20, 22.5, -42), wood)
	block("DoorHeader", V(32, 25, 2), V(0, 32.5, -42), wood)
	block("HallCeiling", V(120, 2, 80), V(0, 45, 0))
	block("ArmoryCeiling", V(50, 2, 40), V(-87, 25, 5))
	block("ArmoryBack", V(2, 25, 40), V(-112, 12.5, 5), wood)
	block("ArmoryNorth", V(50, 25, 2), V(-87, 12.5, -15), wood)
	block("ArmorySouth", V(50, 25, 2), V(-87, 12.5, 25), wood)
	-- Open, wide armory entry (no door). Offset partitions break the long view.
	block("ArmoryEntryNorth", V(2, 25, 10), V(-62, 12.5, -10))
	block("ArmoryEntrySouth", V(2, 25, 10), V(-62, 12.5, 20))
	block("LoungePartition", V(30, 18, 2), V(30, 9, 35), wood)
	block("LoungeBench", V(22, 2, 4), V(30, 1, 31))
	for _, x in ipairs({ -58, 58 }) do
		for _, z in ipairs({ -36, 36 }) do
			block("Column", V(2, 45, 2), V(x, 22.5, z))
		end
	end
	Map.door = block("RollUpDoor", V(32, 20, 1), G.Door, yellow)
	for y = -8, 8, 2 do
		block("DoorRib", V(31, 0.15, 0.1), G.Door + V(0, y, 0.6), dark).Parent = Map.door
	end
	sign(Map.door, "BLACKOUT CREW")
	Map.bench = block("AttachmentBench", V(12, 3, 5), G.Bench, wood)
	sign(Map.bench, "ATTACHMENT BENCH")
	Map.terminal = block("WheelTerminal", V(3, 4, 3), G.Terminal)
	sign(Map.terminal, "LOADOUT")
	Map.guns = {}
	for i, gun in ipairs(C.Guns) do
		local at = G.GunWall + V(0, 0, (i - 1) * 5)
		local panel = block("GunPanel_" .. gun.id, V(0.4, 5, 4.6), at, Color3.fromRGB(65, 61, 56))
		local model = GunModel.build(gun)
		model:PivotTo(Map.frame(at + V(1, 0, 0)) * CFrame.Angles(0, math.pi / 2, 0))
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored, p.CanCollide = true, false end
		end
		model.Parent = m
		sign(panel, gun.name .. (gun.price == 0 and " · FREE" or " · " .. gun.price .. " Credits"))
		Map.guns[gun.id] = panel
	end
	-- Locker room (revision stage 1): open entry from the main hall, tall ceiling, a bank of lockers. The
	-- centre locker is the player's station (personal UI; the door swings locally during the entry).
	block("LockerCeiling", V(24, 2, 28), V(74, 20, 18))
	block("LockerNorth", V(24, 20, 2), V(74, 10, 4), wood)
	block("LockerSouth", V(24, 20, 2), V(74, 10, 32), wood)
	block("LockerBack", V(2, 20, 28), V(87, 10, 18), wood)
	block("LockerEntryNorth", V(2, 20, 6), V(62, 10, 7))
	block("LockerEntrySouth", V(2, 20, 6), V(62, 10, 29))
	block("LockerBench", V(2.4, 1.2, 12), V(73, 0.6, 18), wood)
	local front = G.Locker.X
	for k = -3, 3 do
		local z = G.Locker.Z + k * 3
		local body = block(k == 0 and "Locker" or "LockerCabinet", V(2, 7, 2.8), V(front + 1, 3.5, z), Color3.fromRGB(30, 31, 35)) -- k = 0: Map.lockerPoint()
		local door = block(k == 0 and "LockerDoor" or "LockerCabinetDoor", V(0.2, 6.4, 2.6), V(front - 0.1, 3.5, z),
			k == 0 and Color3.fromRGB(255, 190, 97) or Color3.fromRGB(58, 58, 64))
		if k == 0 then
			Map.locker, Map.lockerDoor = body, door
		end
	end
	sign(Map.locker, "YOUR LOCKER")
	sign(block("LockerHeader", V(2, 3, 16), V(62, 18.5, 18), wood), "LOCKER ROOM")
	local stand = block("DroneShowcase", V(14, 2, 12), V(43, 1, -17))
	block("DroneBody", V(4, 1.5, 6), V(43, 6, -17), Color3.fromRGB(85, 87, 92))
	block("DroneRotor", V(13, 0.2, 1), V(43, 7, -17))
	sign(stand, "DRONE · COMING SOON")
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.Anchored, spawn.Transparency = "GarageSpawn", V(8, 1, 8), true, 1
	spawn.CFrame, spawn.Neutral, spawn.Duration = Map.frame(G.Spawn - V(0, 0.5, 0)), true, 0
	spawn.Enabled = workspace:GetAttribute("BCTesting") ~= true
	spawn.Parent = m
	Map.spawn = spawn
	-- One continuous, crossing circuit: perimeter -> elevated cross-garage bridge -> lower return.
	local track = Instance.new("Folder")
	track.Name, track.Parent = "Track", m
	Map.segments = {}
	local nodes = G.TrackNodes
	for i, a in ipairs(nodes) do
		local b = nodes[i % #nodes + 1]
		local flat = V(b.X - a.X, 0, b.Z - a.Z)
		local cf = CFrame.lookAt(Map.point(a), Map.point(a) + flat)
		local finish
		if math.abs(b.Y - a.Y) > 0.01 then
			finish = Track.ramp(track, cf, flat.Magnitude, b.Y - a.Y, G.TrackWidth)
		else
			finish = Track.straight(track, cf, flat.Magnitude, G.TrackWidth)
		end
		table.insert(Map.segments, { start = cf, finish = finish })
		-- Square junctions give full kart turning room; edge rails on the long runs.
		Track.block(track, "Junction", V(G.TrackWidth, 2, G.TrackWidth), CFrame.new(Map.point(a) - V(0, 1, 0)))
		for _, side in ipairs({ -1, 1 }) do
			local mid = (Map.point(a) + Map.point(b)) / 2 + cf.RightVector * side * G.TrackWidth / 2
			local railCF = CFrame.lookAt(mid, Map.point(b) + cf.RightVector * side * G.TrackWidth / 2)
			Track.block(track, "Rail", V(0.5, 1.4, (b - a).Magnitude - G.TrackWidth), railCF * CFrame.new(0, 0.8, 0), yellow)
		end
	end
	sign(block("TrackEntry", V(3, 3, 1), V(89, 1.5, 88), yellow), "FREE DRIVE · TRACK ENTRY")
	m.Parent = workspace
	Map.model = m
	return m
end
return Map
