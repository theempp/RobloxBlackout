-- Suspension + ride (KartPhysics, virtual body on the test lab: TrackKit.lab far from the city).
-- Measures per scenario: body vertical accel (g) + jerk, settle time, oscillation after a disturbance,
-- rest height/level/jitter, collider clearance (no bottoming), wheel past full bump (no tyre clipping),
-- roll/pitch limits, air time + landing peak + no pogo, slope climb/hold, and 30/45/60 fps agreement.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)
local KartPhysics = require(RS.BlackoutCrew.KartPhysics)
local TrackKit = require(RS.BlackoutCrew.TrackKit)
local K = C.Kart
local V = Vector3.new

local ORIGIN = V(3000, 300, 3000)

return function(T)
	local folder = Instance.new("Folder")
	folder.Name = "KartLab"
	folder.Parent = workspace
	local lanes = TrackKit.lab(folder, ORIGIN)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local cast = KartPhysics.caster(params)
	local G = KartPhysics.geo(K)
	local gk = K.Gravity
	local cs = K.Geo.Collider.Size

	local function groundAt(p)
		local hit = workspace:Raycast(p + V(0, 4, 0), V(0, -12, 0), params)
		return hit and hit.Position.Y or -math.huge
	end

	-- opts: v0, T, dt, input(t, st, b, d) -> input, lift, place (extra CFrame offset from the lane start)
	local function run(lane, opts)
		local dt = opts.dt or 1 / 60
		local start = lane.start * (opts.place or CFrame.new())
		local st = KartPhysics.newState()
		local b = { cf = KartPhysics.restCF(start * CFrame.new(0, opts.lift or 0, 0), K), v = start.LookVector * (opts.v0 or 0),
			w = Vector3.zero, m = G.mass, com = G.com }
		local rec = { t = {}, cf = {}, v = {}, ay = {}, contacts = {}, clear = math.huge, over = -math.huge, x = {}, d = {} }
		local vPrev = b.v
		for f = 1, math.floor(opts.T / dt + 0.5) do
			local tt = f * dt
			local d = (b.cf.Position - start.Position):Dot(start.LookVector)
			local inp = opts.input and opts.input(tt, st, b, d) or { t = 0, s = 0, b = false }
			KartPhysics.simulate(b, st, inp, dt, K, cast, {})
			local cf = b.cf
			table.insert(rec.t, tt)
			table.insert(rec.cf, cf)
			table.insert(rec.v, b.v)
			table.insert(rec.ay, (b.v.Y - vPrev.Y) / dt / gk)
			table.insert(rec.contacts, st.contacts)
			table.insert(rec.d, d)
			table.insert(rec.x, { st.x[1], st.x[2], st.x[3], st.x[4] })
			vPrev = b.v
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local p = cf * V(sx * cs.X / 2, -cs.Y / 2, sz * cs.Z / 2)
					rec.clear = math.min(rec.clear, p.Y - groundAt(p))
				end
			end
			for i = 1, 4 do
				if st.on[i] then
					rec.over = math.max(rec.over, st.x[i] - G.travel)
				end
			end
		end
		rec.st, rec.b = st, b
		return rec
	end

	local function hold(speed)
		return function(_, st)
			return { t = math.clamp((speed - st.speed) / 4, -1, 1), s = 0, b = false }
		end
	end
	local function angles(cf) -- pitch, roll (deg) of a CFrame vs world up
		local look, right = cf.LookVector, cf.RightVector
		return math.deg(math.asin(math.clamp(look.Y, -1, 1))), math.deg(math.asin(math.clamp(right.Y, -1, 1)))
	end
	local function stats(rec, i0, i1)
		i0, i1 = i0 or 1, i1 or #rec.t
		local s = { peakA = 0, peakJ = 0, pitch = 0, roll = 0, rms = 0 }
		for i = math.max(i0, 2), i1 do
			local a = rec.ay[i]
			s.peakA = math.max(s.peakA, math.abs(a))
			s.peakJ = math.max(s.peakJ, math.abs(a - rec.ay[i - 1]) / (rec.t[i] - rec.t[i - 1]))
			s.rms += a * a
			local p, r = angles(rec.cf[i])
			s.pitch, s.roll = math.max(s.pitch, math.abs(p)), math.max(s.roll, math.abs(r))
		end
		s.rms = math.sqrt(s.rms / math.max(1, i1 - math.max(i0, 2) + 1))
		return s
	end
	-- After index i0: settle time (|y - yRest| < tol and |vy| < 0.15 from then on) and oscillation count.
	local function settle(rec, i0, yRest, tol)
		tol = tol or 0.02
		local last, n, sign = i0, 0, 0
		for i = i0, #rec.t do
			local e = rec.cf[i].Position.Y - yRest
			if math.abs(e) > tol or math.abs(rec.v[i].Y) > 0.15 then
				last = i
			end
			if math.abs(e) > 0.01 then
				local sg = e > 0 and 1 or -1
				if sign ~= 0 and sg ~= sign then
					n += 1
				end
				sign = sg
			end
		end
		return rec.t[last] - rec.t[i0], n
	end
	local function firstIndex(rec, cond)
		for i = 1, #rec.t do
			if cond(i) then
				return i
			end
		end
		return #rec.t
	end
	local function line(name, s)
		local parts = {}
		for k, v in pairs(s) do
			table.insert(parts, string.format("%s=%.3f", k, v))
		end
		table.sort(parts)
		print("BC_SUSP", name, table.concat(parts, " "))
	end

	-- Rest: dropped 0.5 studs onto the flat pad.
	local rest = run(lanes.flat, { lift = 0.5, T = 4 })
	local restY = rest.cf[#rest.cf].Position.Y
	local groundY = lanes.flat.start.Y
	local restOff = restY - groundY -- CoM height above flat ground at rest
	local wantRest = KartPhysics.restCF(lanes.flat.start, K).Y - groundY -- root (collider centre) height
	local tSet, nOsc = settle(rest, 1, restY, 0.01)
	local p, r = angles(rest.cf[#rest.cf])
	local jitter = 0
	for i = #rest.t - 120, #rest.t do
		jitter = math.max(jitter, math.abs(rest.cf[i].Position.Y - restY), rest.v[i].Magnitude)
	end
	line("rest", { height = restOff, want = wantRest, settle = tSet, osc = nOsc, pitch = p, roll = r, jitter = jitter, clear = rest.clear })
	T.near("rest height = RAZOR ride height + StaticDrop", restOff, wantRest, 0.03)
	T.check("rest: level", math.abs(p) < 0.5 and math.abs(r) < 0.5, string.format("%.2f/%.2f", p, r))
	T.check("rest: settles from a 0.5 drop < 1.2 s, <= 1 overshoot", tSet < 1.2 and nOsc <= 1, string.format("%.2fs %d", tSet, nOsc))
	T.check("rest: no jitter (2 s still)", jitter < 0.002, jitter)

	-- Speed humps at 40: two 0.35 x 4 humps.
	local bumps = run(lanes.bumps, { v0 = 40, T = 5, input = hold(40) })
	local i1 = firstIndex(bumps, function(i)
		return bumps.d[i] > 34 + 4 + 60 + 4 + 8
	end)
	local sb = stats(bumps)
	local tB, nB = settle(bumps, i1, groundY - groundY + lanes.bumps.start.Y + restOff)
	sb.settle, sb.osc, sb.clear, sb.over = tB, nB, bumps.clear, bumps.over
	line("bumps", sb)
	T.check("humps: body accel peak < 1.5 g", sb.peakA < 1.5, sb.peakA)
	T.check("humps: settles < 1 s after, <= 1 overshoot", tB < 1 and nB <= 1, string.format("%.2fs %d", tB, nB))
	T.check("humps: no bottoming (collider clear)", bumps.clear > 0.02, bumps.clear)
	T.check("humps: pitch < 6 deg", sb.pitch < 6, sb.pitch)

	-- Potholes (0.4 deep, one side then the other) at 35.
	local holes = run(lanes.potholes, { v0 = 35, T = 4, input = hold(35) })
	local sh = stats(holes)
	local yaw = math.deg(math.acos(math.clamp(holes.cf[#holes.cf].LookVector:Dot(lanes.potholes.start.LookVector), -1, 1)))
	sh.clear, sh.over, sh.yaw = holes.clear, holes.over, yaw
	line("potholes", sh)
	T.check("potholes: body accel peak < 1.5 g", sh.peakA < 1.5, sh.peakA)
	T.check("potholes: keeps heading (< 3 deg)", yaw < 3, yaw)
	T.check("potholes: no bottoming", holes.clear > 0.02, holes.clear)

	-- Curb under the left wheels (0.3, square drop off) at 30.
	local curb = run(lanes.curbs, { v0 = 30, T = 4, input = hold(30) })
	local sc = stats(curb)
	local ic = firstIndex(curb, function(i)
		return curb.d[i] > 34 + 30 + 6
	end)
	local tC, nC = settle(curb, ic, lanes.curbs.start.Y + restOff)
	sc.settle, sc.osc, sc.clear, sc.over = tC, nC, curb.clear, curb.over
	line("curb", sc)
	T.check("curb: roll < 7 deg, never flips", sc.roll < 7 and curb.cf[#curb.cf].UpVector.Y > 0.95, sc.roll)
	T.check("curb: settles < 1 s, <= 1 overshoot", tC < 1 and nC <= 1, string.format("%.2fs %d", tC, nC))

	-- Washboard (40 ridges 0.12 high every 1.5) at 40: the body is isolated, no build-up.
	local wash = run(lanes.washboard, { v0 = 40, T = 3.5, input = hold(40) })
	local w0 = firstIndex(wash, function(i)
		return wash.d[i] > 34
	end)
	local w1 = firstIndex(wash, function(i)
		return wash.d[i] > 34 + 60 - K.Geo.Hubs[3].Z - 2
	end)
	local sw = stats(wash, w0, w1)
	local third = math.floor((w1 - w0) / 3)
	local function amp(a, b2)
		local lo, hi = math.huge, -math.huge
		for i = a, b2 do
			local y = wash.cf[i].Position.Y
			lo, hi = math.min(lo, y), math.max(hi, y)
		end
		return hi - lo
	end
	sw.amp1, sw.amp3 = amp(w0 + third, w0 + 2 * third), amp(w0 + 2 * third, w1)
	sw.clear = wash.clear
	line("washboard", sw)
	T.check("washboard: body accel rms < 0.35 g", sw.rms < 0.35, sw.rms)
	T.check("washboard: no build-up (late amp <= 1.5x mid)", sw.amp3 <= sw.amp1 * 1.5 + 0.005, string.format("%.3f/%.3f", sw.amp1, sw.amp3))
	T.check("washboard: body motion < 0.1 studs", sw.amp3 < 0.1, sw.amp3)

	-- Jump: 15 deg kicker (2.14 tall) at 45 -> flat landing.
	local jump = run(lanes.jump, { v0 = 45, T = 4, input = hold(45) })
	local ja = firstIndex(jump, function(i)
		return jump.contacts[i] == 0
	end)
	local jl = firstIndex(jump, function(i)
		return i > ja and jump.contacts[i] > 0
	end)
	local air = jump.t[jl] - jump.t[ja]
	local sj = stats(jump, jl, math.min(#jump.t, jl + 30))
	local pogo = 0
	for i = jl + 12, #jump.t do
		if jump.contacts[i] == 0 then
			pogo += 1
		end
	end
	local tJ, nJ = settle(jump, jl, lanes.jump.start.Y + restOff)
	local pa = select(1, angles(jump.cf[jl]))
	sj.air, sj.pogo, sj.settle, sj.osc, sj.clear, sj.over, sj.landPitch = air, pogo, tJ, nJ, jump.clear, jump.over, pa
	line("jump", sj)
	T.check("jump: airborne > 0.25 s", air > 0.25, air)
	T.check("jump: landing peak < 4 g (kart g)", sj.peakA < 4, sj.peakA)
	T.check("jump: no pogo (wheels stay down after landing)", pogo == 0, pogo)
	T.check("jump: settles < 1.2 s, <= 1 overshoot", tJ < 1.2 and nJ <= 1, string.format("%.2fs %d", tJ, nJ))
	T.check("jump: lands nose-level (|pitch| < 12)", math.abs(pa) < 12, pa)
	T.check("jump: no bottoming", jump.clear > 0.0, jump.clear)

	-- Slope 10 deg: climbs at speed; brake holds still mid-slope.
	local slope = run(lanes.slope, { v0 = 35, T = 2.4, input = hold(35) })
	local vTop = slope.v[#slope.v].Magnitude
	line("slope", { vTop = vTop, clear = slope.clear })
	T.check("slope: climbs without stalling (> 28)", vTop > 28, vTop)
	local onSlope = lanes.slope.start * CFrame.new(0, 3.53, -34 - 20) * CFrame.Angles(math.rad(10), 0, 0)
	local holdRec = run(lanes.slope, { place = lanes.slope.start:ToObjectSpace(onSlope), lift = 0.2, T = 3, input = function()
		return { t = 0, s = 0, b = true }
	end })
	local creep = (holdRec.cf[#holdRec.cf].Position - holdRec.cf[90].Position).Magnitude
	line("slopeHold", { creep = creep })
	T.check("slope: brake holds (creep < 0.05 over 1.5 s)", creep < 0.05, creep)

	-- Flat: full brake from 60 (pitch), hard turn at 40 (roll).
	local brk = run(lanes.flat, { v0 = 60, T = 2, input = function()
		return { t = 0, s = 0, b = true }
	end })
	local sbk = stats(brk)
	local turn = run(lanes.flat, { v0 = 40, T = 3, input = function(_, st)
		return { t = math.clamp((40 - st.speed) / 4, -1, 1), s = 1, b = false }
	end })
	local stn = stats(turn)
	line("brakeTurn", { brakePitch = sbk.pitch, stopV = brk.v[#brk.v].Magnitude, turnRoll = stn.roll, upY = turn.cf[#turn.cf].UpVector.Y })
	T.check("brake: dives < 4 deg, stops", sbk.pitch < 4 and brk.v[#brk.v].Magnitude < 1, sbk.pitch)
	T.check("hard turn at 40: rolls < 7 deg, stays upright", stn.roll < 7 and turn.cf[#turn.cf].UpVector.Y > 0.97, stn.roll)

	-- No tyre clipping: a wheel never has to sink below the ground past the visual limit (full bump + 0.12).
	local over = math.max(bumps.over, holes.over, curb.over, wash.over, jump.over, slope.over)
	T.check("wheels never past full bump + 0.12 (no visual clipping)", over <= 0.12, over)

	-- Frame-rate independence: same open-loop drive over the humps at 60, 30 and 45 fps.
	local function drive()
		return { t = 0.6, s = 0, b = false }
	end
	local r60 = run(lanes.bumps, { v0 = 40, T = 3, dt = 1 / 60, input = drive })
	local r30 = run(lanes.bumps, { v0 = 40, T = 3, dt = 1 / 30, input = drive })
	local r45 = run(lanes.bumps, { v0 = 40, T = 3, dt = 1 / 45, input = drive })
	local d30, d45 = 0, 0
	for i = 1, #r30.t do
		d30 = math.max(d30, (r30.cf[i].Position - r60.cf[i * 2].Position).Magnitude)
	end
	for i = 1, #r45.t, 3 do -- t = i/45 = (i/3)/15 -> 60 fps frame 4i/3
		local j = math.floor(i * 4 / 3 + 0.5)
		if math.abs(r60.t[j] - r45.t[i]) < 1e-6 then
			d45 = math.max(d45, (r45.cf[i].Position - r60.cf[j].Position).Magnitude)
		end
	end
	local p60, p30 = stats(r60).peakA, stats(r30).peakA
	line("fps", { d30 = d30, d45 = d45, peak60 = p60, peak30 = p30 })
	T.check("30 fps = 60 fps (same substeps)", d30 < 1e-4, d30)
	T.check("45 fps within 0.05 studs of 60", d45 < 0.05, d45)

	folder:Destroy()
end
