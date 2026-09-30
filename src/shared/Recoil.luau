-- Per-blaster deterministic recoil. Each shot rotates the AIM (not just the view) by a fixed pattern,
-- so the player learns it and counters by dragging down. After the spray, part of the climb recovers;
-- whatever the player already countered is not recovered again (no overshoot below the target).
-- Pure: caller passes time, so it is testable.
local Config = require(script.Parent.Config)
local Recoil = {}

-- Kick for shot i (1-based) in degrees: up, right.
function Recoil.kick(s, i)
	local r = s.recoil
	local side = r.side[(i - 1) % #r.side + 1]
	local up = r.up * (1 + r.grow * math.min(i - 1, 10))
	local cap = Config.Recoil.MaxKickDeg
	return math.min(up, cap), math.clamp(side, -cap, cap)
end

function Recoil.new()
	return { index = 0, last = -math.huge, climb = 0, recoverLeft = 0, recoverRate = 0 }
end

function Recoil.onShot(st, s, now)
	if now - st.last > Config.Recoil.ResetAfter then
		st.index = 0
		st.climb = 0
	end
	st.index += 1
	st.last = now
	st.recoverLeft = 0
	local up, side = Recoil.kick(s, st.index)
	st.climb += up
	return up, side
end

-- Player look input this frame (degrees, + = up). Dragging down counters the climb, so recovery
-- only returns what the player did NOT already compensate.
function Recoil.onLook(st, pitchDelta)
	if pitchDelta < 0 then
		if st.recoverLeft > 0 then
			st.recoverLeft = math.max(0, st.recoverLeft + pitchDelta)
		elseif st.climb > 0 then
			st.climb = math.max(0, st.climb + pitchDelta)
		end
	end
end

-- Returns the pitch change (<= 0) to apply this frame.
function Recoil.step(st, s, dt, now)
	if st.climb > 0 and st.recoverLeft == 0 and now - st.last > s.interval * 1.2 then
		st.recoverLeft = st.climb * s.recoil.recover
		st.recoverRate = st.recoverLeft / math.max(s.recoil.recoverTime, 1e-3)
		st.climb = 0
	end
	if st.recoverLeft <= 0 then
		return 0
	end
	local d = math.min(st.recoverLeft, st.recoverRate * dt)
	st.recoverLeft -= d
	return -d
end

return Recoil
