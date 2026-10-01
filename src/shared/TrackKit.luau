-- TrackKit: modular kart-track pieces (anchored primitives, matte, no neon). Every piece takes a ground
-- CFrame `at` (its start, facing along at.LookVector) and returns the CFrame where it ends, so pieces
-- chain. Used by the suspension test lab (lab()) and the garage track (§9).
local TrackKit = {}
local V = Vector3.new
TrackKit.ROAD = Color3.fromRGB(46, 46, 52)
TrackKit.CURB = Color3.fromRGB(200, 200, 200)
TrackKit.CURB2 = Color3.fromRGB(170, 40, 46)

local function block(parent, name, size, cf, color, cls)
	local p = Instance.new(cls or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color or TrackKit.ROAD
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
TrackKit.block = block

-- Flat road, top surface at at.Y, `thick` deep.
function TrackKit.straight(parent, at, length, width, thick)
	thick = thick or 2
	block(parent, "Road", V(width, thick, length), at * CFrame.new(0, -thick / 2, -length / 2))
	return at * CFrame.new(0, 0, -length)
end

-- Ramp rising `rise` (negative = falling) over `length`, filled down `depth` below its low edge.
function TrackKit.ramp(parent, at, length, rise, width, depth)
	depth = depth or 2
	local h = math.abs(rise)
	local cf = at * CFrame.new(0, rise / 2, -length / 2)
	if rise > 0 then
		cf *= CFrame.Angles(0, math.pi, 0) -- WedgePart is tallest at +Z: turn it so the top is ahead
	end
	block(parent, "Ramp", V(width, h, length), cf, nil, "WedgePart")
	local lowY = math.min(0, rise)
	block(parent, "RampBase", V(width, depth, length), at * CFrame.new(0, lowY - depth / 2, -length / 2))
	return at * CFrame.new(0, rise, -length)
end

-- Rounded speed hump (up + down wedges) sitting on a road.
function TrackKit.hump(parent, at, height, length, width)
	local half = length / 2
	block(parent, "HumpUp", V(width, height, half), at * CFrame.new(0, height / 2, -half / 2) * CFrame.Angles(0, math.pi, 0), TrackKit.CURB, "WedgePart")
	block(parent, "HumpDown", V(width, height, half), at * CFrame.new(0, height / 2, -half * 1.5), TrackKit.CURB, "WedgePart")
	return at * CFrame.new(0, 0, -length)
end

-- Curb strip along the road at lateral offset x: bevelled in, flat top, square end (drop off).
function TrackKit.curb(parent, at, x, height, length, width, bevel)
	bevel = bevel or 0.6
	block(parent, "CurbIn", V(width, height, bevel), at * CFrame.new(x, height / 2, -bevel / 2) * CFrame.Angles(0, math.pi, 0), TrackKit.CURB2, "WedgePart")
	for i = 0, math.ceil((length - bevel) / 2) - 1 do -- red/white blocks, 2 studs each
		local l = math.min(2, length - bevel - i * 2)
		block(parent, "Curb", V(width, height, l), at * CFrame.new(x, height / 2, -bevel - i * 2 - l / 2), i % 2 == 0 and TrackKit.CURB or TrackKit.CURB2)
	end
	return at * CFrame.new(0, 0, -length)
end

-- Washboard: `n` ridges (height x 0.5 long) every `pitch` studs across the road.
function TrackKit.washboard(parent, at, n, pitch, height, width)
	for i = 0, n - 1 do
		block(parent, "Ridge", V(width, height, 0.5), at * CFrame.new(0, height / 2, -pitch * i - pitch / 2))
	end
	return at * CFrame.new(0, 0, -pitch * n)
end

-- Road with a pothole (depth x len x holeW) at lateral offset x; total length `length`, hole centred.
function TrackKit.pothole(parent, at, length, width, x, holeW, len, depth)
	local before = (length - len) / 2
	TrackKit.straight(parent, at, before, width)
	local mid = at * CFrame.new(0, 0, -before)
	local left, right = -width / 2, width / 2
	local h0, h1 = x - holeW / 2, x + holeW / 2
	if h0 > left then
		block(parent, "Road", V(h0 - left, 2, len), mid * CFrame.new((left + h0) / 2, -1, -len / 2))
	end
	if right > h1 then
		block(parent, "Road", V(right - h1, 2, len), mid * CFrame.new((h1 + right) / 2, -1, -len / 2))
	end
	block(parent, "HoleFloor", V(holeW, 2, len), mid * CFrame.new(x, -depth - 1, -len / 2), Color3.fromRGB(30, 30, 34))
	TrackKit.straight(parent, mid * CFrame.new(0, 0, -len), before, width)
	return at * CFrame.new(0, 0, -length)
end

-- Suspension test lab: parallel lanes (driving -Z), each starting with a 40-stud run-up. Returns
-- { [name] = { start = ground CFrame, at = feature start distance } }. Numbers = Config-free fixtures.
function TrackKit.lab(parent, origin)
	local lanes, W = {}, 16
	local function lane(i, name)
		local at = CFrame.new(origin + V((i - 1) * 40, 0, 0))
		lanes[name] = { start = at * CFrame.new(0, 0, -6), at = 40 }
		return TrackKit.straight(parent, at, 40, W)
	end
	-- flat: wide pad for rest, braking and cornering
	block(parent, "Pad", V(220, 2, 500), CFrame.new(origin + V(-150, -1, -120)))
	lanes.flat = { start = CFrame.new(origin + V(-150, 0, -20)), at = 0 }
	local e = lane(1, "bumps")
	e = TrackKit.straight(parent, TrackKit.hump(parent, e, 0.35, 4, W), 60, W)
	e = TrackKit.straight(parent, TrackKit.hump(parent, e, 0.35, 4, W), 120, W)
	e = lane(2, "potholes")
	e = TrackKit.pothole(parent, e, 30, W, 1.925, 2.4, 2.6, 0.4) -- under the right wheels
	e = TrackKit.pothole(parent, e, 30, W, -1.925, 2.4, 2.6, 0.4) -- left
	e = TrackKit.straight(parent, e, 120, W)
	e = lane(3, "curbs")
	TrackKit.curb(parent, e, -1.925, 0.3, 30, 1.6) -- left wheels ride a 0.3 curb, square drop at the end
	e = TrackKit.straight(parent, e, 150, W)
	e = lane(4, "washboard")
	e = TrackKit.washboard(parent, e, 40, 1.5, 0.12, W)
	TrackKit.straight(parent, lanes.washboard.start * CFrame.new(0, 0, -34), 60, W) -- road under the ridges
	e = TrackKit.straight(parent, e, 120, W)
	e = lane(5, "jump")
	e = TrackKit.ramp(parent, e, 8, 2.14, W) -- 15 deg kicker, square edge: flat landing below
	TrackKit.straight(parent, e * CFrame.new(0, -2.14, 0), 160, W)
	e = lane(6, "slope")
	e = TrackKit.ramp(parent, e, 40, 7.05, W) -- 10 deg
	e = TrackKit.straight(parent, e, 20, W, 9)
	e = TrackKit.ramp(parent, e, 40, -7.05, W)
	TrackKit.straight(parent, e, 100, W)
	return lanes
end

return TrackKit
