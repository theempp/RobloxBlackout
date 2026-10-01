-- KartPhysics (§3b, §7): one module for the driver-owned client and the ServerPhysics/server modes.
-- simulate(): fixed-step rigid body, n = ceil(dt / Step) substeps of dt / n (30 and 60 fps run the same
-- substeps). Per wheel and substep: a sphere cast along the suspension axis (bridges holes, rolls up
-- edges, smooth over seams); a spring preloaded to sit at static; bump/rebound damping with a digressive
-- knee (the damper sees body motion + the road-profile rate through a short tyre lag); a progressive
-- bump stop; a hard stop that cancels the closing speed (no bounce); anti-roll bars; a tyre slip curve
-- inside a friction circle. Air: arcade pitch/roll self-levelling. step() = live mode: the Roblox assembly
-- keeps collisions + replication; we set its velocities each frame (the AntiGravity VectorForce cancels
-- Roblox gravity so Kart.Gravity rules) and fold any collision change back in next frame.
-- input: { t = throttle -1..1, s = steer -1..1, b = brake bool }. mods: { sabotaged, emp, spin }.
local KartPhysics = {}

local V3 = Vector3.new
local Y = Vector3.yAxis
local cache = setmetatable({}, { __mode = "k" })

-- Derived geometry (root space) for a Config.Kart table. Call invalidate(cfg) after changing Geo/Susp.
function KartPhysics.geo(cfg)
	local g = cache[cfg]
	if g then
		return g
	end
	local G, S = cfg.Geo, cfg.Susp
	local travel = S.Droop + S.Bump
	local k = (2 * math.pi * S.Freq) ^ 2
	g = { travel = travel, castLen = S.CastMargin + travel, k = k, cb = 2 * S.BumpZeta * math.sqrt(k), cr = 2 * S.ReboundZeta * math.sqrt(k), wheels = {} }
	local cc = G.Collider.Center
	for i, hub in ipairs(G.Hubs) do
		local static = hub - cc - Y * S.StaticDrop
		local full = static + Y * S.Bump
		g.wheels[i] = { design = hub - cc, static = static, top = full + Y * S.CastMargin,
			cast = full + Y * (S.CastMargin - (G.WheelRadius - S.CastRadius)), front = i <= 2 }
	end
	-- Mass props of the bare kart (collider + ballast), root space; live mode reads the real assembly.
	local C, B = G.Collider, G.Ballast
	local mc, mb = C.Size.X * C.Size.Y * C.Size.Z * G.ColliderDensity, B.Size.X * B.Size.Y * B.Size.Z * B.Density
	g.mass, g.com = mc + mb, (B.Center - cc) * (mb / (mc + mb))
	cache[cfg] = g
	return g
end

function KartPhysics.invalidate(cfg)
	cache[cfg] = nil
end

-- Hub positions in the kart frame (FL, FR, RL, RR).
function KartPhysics.wheels(cfg)
	return cfg.Geo.Hubs
end

-- Root CFrame of a kart resting on the ground at groundCF (the model's pivot is set to this point).
function KartPhysics.restCF(groundCF, cfg)
	return groundCF * CFrame.new(cfg.Geo.Collider.Center + Y * cfg.Susp.StaticDrop)
end

function KartPhysics.newState()
	return { steer = 0, flipT = 0, airT = 0, contacts = 0, speed = 0, x = { 0, 0, 0, 0 }, pf = { 0, 0, 0, 0 },
		on = { false, false, false, false }, spin = { 0, 0, 0, 0 }, wspin = { 0, 0, 0, 0 }, load = { 0, 0, 0, 0 } }
end

local function curve(a, slide) -- normalised slip -> grip: rises to 1 at the peak, eases to `slide` by 3x peak
	if a < 1 then
		return a * (2 - a)
	end
	local t = math.min((a - 1) / 2, 1)
	return 1 - (1 - slide) * t * t * (3 - 2 * t)
end

local function damper(v, c, knee, digress)
	local a = math.abs(v)
	return math.sign(v) * c * (a < knee and a or knee + (a - knee) * digress)
end

local function substep(b, st, inp, h, cfg, cast, mods, first)
	local g, S, T = KartPhysics.geo(cfg), cfg.Susp, cfg.Tyre
	local cf, m = b.cf, b.m
	local up, look = cf.UpVector, cf.LookVector
	local c = cf * b.com
	local v, w = b.v, b.w
	local gk = cfg.Gravity
	local speed = v:Dot(look)
	local t, s, brake = inp.t or 0, inp.s or 0, inp.b == true
	if mods.sabotaged then
		t, s = 0, 0
	end
	st.steer += (s * math.rad(cfg.Steer) / (1 + (math.abs(speed) / cfg.SteerFalloff) ^ 2) - st.steer) * math.min(1, h * cfg.SteerRate)
	local I = cfg.Inertia * m
	local function invI(tq)
		local l = cf:VectorToObjectSpace(tq)
		return cf:VectorToWorldSpace(V3(l.X / I.X, l.Y / I.Y, l.Z / I.Z))
	end
	-- Pass 1: ground contact per wheel (sphere centre sits WheelRadius - CastRadius above the tyre bottom).
	local X, N, Q, on = { 0, 0, 0, 0 }, {}, {}, { false, false, false, false }
	local contacts, nSum = 0, Vector3.zero
	for i = 1, 4 do
		local o = cf * g.wheels[i].cast
		local hit = cast(o, -up * g.castLen, S.CastRadius)
		if hit then
			local n = o - up * hit.Distance - hit.Position
			n = n.Magnitude > 1e-4 and n.Unit or up
			if n:Dot(up) > 0.35 then -- steeper = a wall: the chassis collider handles it
				on[i], X[i], N[i], Q[i] = true, g.castLen - hit.Distance, n, hit.Position
				contacts += 1
				nSum += n
			end
		end
	end
	st.landing = contacts == 0 and cfg.Air.LandingTime or math.max(0, (st.landing or 0) - h)
	-- Longitudinal intent.
	local maxF = cfg.MaxSpeed * (mods.emp and cfg.EmpSpeedMult or 1)
	local brakeAmt, driveA = 0, 0
	if brake then
		brakeAmt = 1
	elseif t * speed < -1 then
		brakeAmt = math.abs(t) -- pressing against the motion = brake first
	elseif t > 0 then
		driveA = t * cfg.Accel * (mods.emp and cfg.EmpAccelMult or 1) * math.clamp((maxF - speed) / (maxF * cfg.TopTaper), 0, 1)
	elseif t < 0 then
		driveA = t * cfg.Accel * math.clamp((speed + cfg.Reverse) / (cfg.Reverse * cfg.TopTaper), 0, 1)
	end
	if speed > maxF + 0.5 then
		brakeAmt = math.max(brakeAmt, math.min(1, (speed - maxF) * 3 / cfg.Brake)) -- EMP bleeds speed to the slowed cap
	end
	-- Pass 2: suspension + tyre forces at each contact.
	local cc = cfg.Geo.Collider.Center
	local zc, zf, zr = b.com.Z + cc.Z, cfg.Geo.Hubs[1].Z, cfg.Geo.Hubs[3].Z
	local shareF = math.clamp((zr - zc) / (zr - zf), 0.2, 0.8) / 2
	local F, Tq = V3(0, -m * gk, 0), Vector3.zero
	local grip = T.Mu * (mods.emp and cfg.EmpGripMult or 1)
	local peak = math.rad(T.PeakSlip)
	local r = cfg.Geo.WheelRadius
	for i = 1, 4 do
		local wg = g.wheels[i]
		if on[i] then
			local x, n, q = X[i], N[i], Q[i]
			local mq = m * (wg.front and shareF or 0.5 - shareF)
			local vm = v + w:Cross(cf * wg.static - c)
			local cdb = -vm:Dot(up) -- compression rate from body motion
			local p = st.on[i] and (x - st.x[i]) / h - cdb or 0 -- + road-profile rate, through the tyre lag
			st.pf[i] += (p - st.pf[i]) * math.min(1, h / S.TyreLag)
			local xd = cdb + st.pf[i]
			local j = i % 2 == 1 and i + 1 or i - 1 -- axle partner
			local fa = mq * (gk + g.k * (x - S.Droop) + damper(xd, st.landing > 0 and g.cr * cfg.Air.LandingDamp or (xd > 0 and g.cb or g.cr), S.Knee, st.landing > 0 and 1 or S.Digress)
				+ g.k * (wg.front and S.ARBFront or S.ARBRear) * (x - X[j]))
			local z = x - (g.travel - S.StopZone)
			if z > 0 then
				fa += mq * gk * S.StopG * math.min(z / S.StopZone, 1) ^ 2
			end
			local nm = math.clamp(fa, 0, mq * gk * S.MaxLoadG) / math.max(n:Dot(up), 0.5)
			local Fn = n * nm
			local heading = wg.front and CFrame.fromAxisAngle(up, -st.steer) * look or look
			local fw = heading - n * heading:Dot(n)
			fw = fw.Magnitude > 1e-3 and fw.Unit or look
			local side = fw:Cross(n)
			local vq = v + w:Cross(q - c)
			local vl, vs = vq:Dot(fw), vq:Dot(side)
			local mu = grip * nm
			local slip = math.atan2(math.abs(vs), math.max(math.abs(vl), T.LowSpeed))
			local fy = -math.sign(vs) * math.min(mu * curve(slip / peak, T.Slide), m * 0.25 * math.abs(vs) / h)
			local fx = driveA * m * (wg.front and (1 - cfg.DriveRear) / 2 or cfg.DriveRear / 2)
			local stopF = m * 0.25 * math.abs(vl) / h -- never reverse a wheel within one substep
			if brakeAmt > 0 then
				fx -= math.sign(vl) * math.min(brakeAmt * cfg.Brake * m * 0.25, stopF)
			elseif t == 0 then
				fx -= math.sign(vl) * math.min((cfg.Drag * math.abs(vl) + cfg.Roll) * m * 0.25, stopF)
			end
			local fxMax = math.sqrt(math.max(mu * mu - fy * fy, (0.3 * mu) ^ 2)) -- friction circle, lateral first
			fx = math.clamp(fx, -fxMax, fxMax)
			local ft = fw * fx + side * fy
			F += Fn + ft
			Tq += (q - c):Cross(Fn) + (q + n * T.RollCenter - c):Cross(ft)
			if x > g.travel then -- past full bump: cancel the closing speed at the contact (no bounce)
				local rq = q - c
				local vc = -(v + w:Cross(rq)):Dot(n) + math.min((x - g.travel) * S.StopBias / h, S.StopBiasMax)
				if vc > 0 then
					local rn = rq:Cross(n)
					local J = n * (vc / (1 / m + rn:Dot(invI(rn))))
					v += J / m
					w += invI(rq:Cross(J))
				end
			end
			st.load[i] = nm
			st.wspin[i] = -vl / r
		else
			st.pf[i], st.load[i] = 0, 0
			st.wspin[i] *= 1 - math.min(1, h * 1.5)
		end
		st.x[i], st.on[i] = X[i], on[i]
		st.spin[i] = (st.spin[i] + st.wspin[i] * h) % (2 * math.pi)
	end
	if contacts > 0 then
		local nA = nSum.Unit
		local fg = look - nA * look:Dot(nA)
		if fg.Magnitude > 0.05 then
			fg = fg.Unit
			F += fg * (m * gk * fg.Y * cfg.GradeAssist * contacts / 4) -- grade assist: no stalling uphill, holds on slopes
		end
		st.airT = 0
		if contacts < 4 then
			-- Damp take-off rotation while an axle unloads; rear spring force must not catapult the nose down.
			w -= (w - Y * w:Dot(Y)) * math.min(1, cfg.Air.Damp * (1 - contacts / 4) * h)
		end
	else
		st.airT += h
		F -= v * (m * cfg.AirDrag)
		if st.airT > cfg.Air.After then -- self-levelling (pitch/roll only; yaw stays free)
			w += (up:Cross(Y) * cfg.Air.Level - (w - Y * w:Dot(Y)) * cfg.Air.Damp) * h
		end
	end
	if first and mods.spin then
		w += up * cfg.EmpSpin -- EMP kick (rad/s), mass-independent
	end
	v += F * (h / m)
	w += invI(Tq) * h
	local wm = w.Magnitude
	local rot = cf.Rotation
	if wm > 1e-7 then
		rot = CFrame.fromAxisAngle(w / wm, wm * h) * rot
	end
	b.cf = CFrame.new(c + v * h) * rot * CFrame.new(-b.com)
	b.v, b.w = v, w
	st.contacts, st.speed = contacts, speed
end

-- Advances body b = { cf (root CFrame), v (CoM velocity), w (angular velocity), m, com (root space) }.
-- Returns substeps run, simulated time, flipped (auto-upright fired).
function KartPhysics.simulate(b, st, input, dt, cfg, cast, mods)
	dt = math.min(dt, cfg.Step * cfg.MaxSubsteps)
	if dt <= 0 then
		return 0, 0, false
	end
	local n = math.max(1, math.ceil(dt / cfg.Step - 1e-6))
	local h = dt / n
	for k = 1, n do
		substep(b, st, input, h, cfg, cast, mods, k == 1)
	end
	local R = cfg.Rest
	if st.contacts == 4 and (input.t or 0) == 0 and b.v.Magnitude < R.Speed and b.w.Magnitude < R.Spin then
		b.v, b.w = Vector3.zero, Vector3.zero -- at rest: no creep, no jitter
	end
	-- Auto-upright: flipped and nearly still for FlipTime -> set back on the wheels.
	if b.cf.UpVector.Y < 0.3 and b.v.Magnitude < 6 then
		st.flipT += dt
		if st.flipT >= cfg.FlipTime then
			st.flipT = 0
			local p, look = b.cf.Position + V3(0, 3, 0), b.cf.LookVector
			local fwd = V3(look.X, 0, look.Z)
			fwd = fwd.Magnitude > 0.1 and fwd.Unit or V3(0, 0, -1)
			b.cf, b.v, b.w = CFrame.lookAt(p, p + fwd), Vector3.zero, Vector3.zero
			return n, dt, true
		end
	else
		st.flipT = 0
	end
	return n, dt, false
end

local casters = setmetatable({}, { __mode = "k" })
function KartPhysics.caster(params)
	local f = casters[params]
	if not f then
		f = function(o, d, radius)
			return workspace:Spherecast(o, radius, d, params)
		end
		casters[params] = f
	end
	return f
end

-- Live mode on a Roblox assembly (whoever owns it calls this every PreSimulation).
function KartPhysics.step(root, st, input, dt, cfg, rayParams, mods)
	local b = st.body or {}
	st.body = b
	local cf0 = root.CFrame
	b.cf, b.m = cf0, root.AssemblyMass
	b.com = cf0:PointToObjectSpace(root.AssemblyCenterOfMass)
	local vR, wR = root.AssemblyLinearVelocity, root.AssemblyAngularVelocity
	if st.vSet then -- what Roblox changed since our last set (collisions) is folded into our end state
		b.v, b.w = st.vEnd + (vR - st.vSet), st.wEnd + (wR - st.wSet)
	else
		b.v, b.w = vR, wR
	end
	local c0 = cf0 * b.com
	local n, span, flipped = KartPhysics.simulate(b, st, input, dt, cfg, KartPhysics.caster(rayParams), mods)
	if flipped then
		root.CFrame = b.cf
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		st.vSet = nil
	elseif n > 0 then
		local vA = (b.cf * b.com - c0) / span -- average over the frame: Roblox then lands on our end pose
		local axis, ang = (b.cf.Rotation * cf0.Rotation:Inverse()):ToAxisAngle()
		local wA = axis * (ang / span)
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = vA, wA
		st.vSet, st.wSet, st.vEnd, st.wEnd = vA, wA, b.v, b.w
	end
	KartPhysics.antiGravity(root, true)
	return st.speed, st.contacts, flipped
end

-- On while someone steps the kart (cancels Roblox gravity); off when it is left to plain Roblox physics.
function KartPhysics.antiGravity(root, on)
	local f = root:FindFirstChild("AntiGravity")
	if f then
		local want = on and V3(0, root.AssemblyMass * workspace.Gravity, 0) or Vector3.zero
		if f.Force ~= want then
			f.Force = want
		end
	end
end

-- Server-mode input validation (and the client's own clamp): finite, clamped, brake boolean.
function KartPhysics.cleanInput(t, s, b)
	local function f(x)
		return type(x) == "number" and x == x and math.abs(x) < math.huge and math.clamp(x, -1, 1) or 0
	end
	return { t = f(t), s = f(s), b = b == true }
end

return KartPhysics
