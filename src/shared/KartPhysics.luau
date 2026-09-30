-- One-seat kart physics, ported from roblox 1 Vehicles.luau: 4-ray raycast suspension (spring/damper
-- per wheel), impulse lateral grip, speed-sensitive steering (Steer / (1 + (v/SteerFalloff)^2)),
-- grade assist, braking, coast drag. Shared: whoever owns the assembly steps it (the driver's client by
-- default; the server when Kart.ServerPhysics or no driver). Adds for karts: sabotage (flat tyres = no
-- drive), EMP (slow + one spin kick), auto-upright when flipped and slow.
-- state: { steer, flipT } per kart. input: { t = throttle -1..1, s = steer -1..1, b = brake bool }.
local KartPhysics = {}

function KartPhysics.newState()
	return { steer = 0, flipT = 0, spinAt = 0 }
end

-- Wheel mount points in kart space (x = side, z = forward is -Z).
function KartPhysics.wheels(cfg)
	local x, z = cfg.Track / 2, cfg.Wheelbase / 2
	return { Vector3.new(-x, cfg.MountY, -z), Vector3.new(x, cfg.MountY, -z), Vector3.new(-x, cfg.MountY, z), Vector3.new(x, cfg.MountY, z) }
end

-- mods: { sabotaged, emp (bool), spin (bool: apply the EMP kick this step) }
-- Returns speed (studs/s along the kart's look) and wheel contacts.
function KartPhysics.step(root, st, input, dt, cfg, rayParams, mods)
	dt = math.min(dt, 1 / 30)
	local cf = root.CFrame
	local up, look = cf.UpVector, cf.LookVector
	local mass = root.AssemblyMass
	local vel = root.AssemblyLinearVelocity
	local speed = vel:Dot(look)
	local g = workspace.Gravity
	local t, s, b = input.t or 0, input.s or 0, input.b == true
	if mods.sabotaged then
		t, s = 0, 0
	end
	st.steer += (s * math.rad(cfg.Steer) / (1 + (math.abs(speed) / cfg.SteerFalloff) ^ 2) - st.steer) * math.min(1, dt * 8)
	local contacts, normal = 0, Vector3.zero
	for i, w in ipairs(KartPhysics.wheels(cfg)) do
		local origin = cf:PointToWorldSpace(w)
		local hit = workspace:Raycast(origin, -up * cfg.RayLen, rayParams)
		if hit and hit.Normal:Dot(up) > 0.25 then
			contacts += 1
			normal += hit.Normal
			local dist = (origin - hit.Position).Magnitude
			local v = root:GetVelocityAtPosition(origin)
			local load = mass / 4 * math.clamp((cfg.Rest - dist) * cfg.Spring - v:Dot(hit.Normal) * cfg.Damp, 0, g * 3)
			root:ApplyImpulseAtPosition(hit.Normal * load * dt, origin)
			local yaw = i <= 2 and -st.steer or 0 -- front wheels steer
			local side = (cf * CFrame.Angles(0, yaw, 0)).RightVector
			side -= hit.Normal * side:Dot(hit.Normal)
			if side.Magnitude > 0.01 then
				side = side.Unit
				local grip = math.clamp(-v:Dot(side) * mass / 4 * cfg.Grip * (mods.emp and cfg.EmpGripMult or 1), -load * 1.3, load * 1.3)
				root:ApplyImpulseAtPosition(side * grip * dt, origin - up * 0.4)
			end
		end
	end
	if contacts > 0 and normal.Magnitude > 0.1 then
		local n = normal.Unit
		local f = look - n * look:Dot(n)
		local maxF = cfg.MaxSpeed * (mods.emp and cfg.EmpSpeedMult or 1)
		local accel
		if b then
			accel = -math.clamp(speed * 8, -cfg.Brake, cfg.Brake)
		elseif t * speed < -1 then
			accel = t * cfg.Brake -- pressing against the motion = brake first
		elseif t > 0 and speed < maxF then
			accel = t * cfg.Accel * (mods.emp and cfg.EmpAccelMult or 1)
		elseif t < 0 and speed > -cfg.Reverse then
			accel = t * cfg.Accel
		elseif speed > maxF then
			accel = -(speed - maxF) * 3 -- EMP bleeds speed down to the slowed cap
		else
			accel = -speed * cfg.Drag
		end
		if f.Magnitude > 0.01 then
			accel += g * f.Unit.Y -- grade assist: no stalling uphill, brakes hold on slopes
			root:ApplyImpulse(f.Unit * mass * accel * contacts / 4 * dt)
		end
	end
	if mods.spin then
		root.AssemblyAngularVelocity += up * cfg.EmpSpin -- EMP kick (rad/s), mass-independent
	end
	-- Auto-upright: flipped and nearly still for FlipTime -> set back on the wheels.
	if up.Y < 0.3 and vel.Magnitude < 6 then
		st.flipT += dt
		if st.flipT >= cfg.FlipTime then
			st.flipT = 0
			local p = root.Position
			local fwd = Vector3.new(look.X, 0, look.Z)
			fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, -1)
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			root.Parent:PivotTo(CFrame.lookAt(p + Vector3.new(0, 3, 0), p + Vector3.new(0, 3, 0) + fwd))
			return speed, contacts, true
		end
	else
		st.flipT = 0
	end
	return speed, contacts, false
end

-- Server-mode input validation (and the client's own clamp): finite, clamped, brake boolean.
function KartPhysics.cleanInput(t, s, b)
	local function f(x)
		return type(x) == "number" and x == x and math.abs(x) < math.huge and math.clamp(x, -1, 1) or 0
	end
	return { t = f(t), s = f(s), b = b == true }
end

return KartPhysics
