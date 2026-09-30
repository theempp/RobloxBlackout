-- Enemy senses (§5h). Vision = cone (total angle) + range + clear line of sight (caller supplies the
-- ray test); hearing = the player's current noise radius reaches the listener. Pure math.
local Perception = {}

function Perception.inCone(eye, look, target, coneDeg, range)
	local d = target - eye
	local dist = d.Magnitude
	if dist > range then
		return false
	end
	if dist < 1e-3 then
		return true
	end
	return look.Unit:Dot(d / dist) >= math.cos(math.rad(coneDeg / 2))
end

function Perception.hears(listener, source, noiseRadius)
	return noiseRadius > 0 and (source - listener).Magnitude <= noiseRadius
end

-- Sweeping camera: yaw (deg) at server time t.
function Perception.cameraYaw(def, t, period)
	return def.yaw + def.sweep * math.sin(2 * math.pi * t / period)
end

-- Look vector for a yaw (deg, 0 = -Z) and pitch (deg, negative = down).
function Perception.look(yawDeg, pitchDeg)
	return (CFrame.Angles(0, math.rad(yawDeg), 0) * CFrame.Angles(math.rad(pitchDeg), 0, 0)).LookVector
end

-- Suspicion: seen continuously for spotTime -> spotted. Returns new seenFor, spotted.
function Perception.accumulate(seenFor, seen, dt, spotTime)
	if not seen then
		return 0, false
	end
	seenFor += dt
	return seenFor, seenFor >= spotTime
end

return Perception
