-- Weapon wheel logic (UI-free, testable). Drag-select math ported from roblox 1 and rewritten for
-- 5 fixed slots (2 left / 2 right / 1 top). Tap = swap to last-used; hold = radial.
local Config = require(script.Parent.Config)
local W = Config.Wheel
local WheelLogic = {}

-- Screen-space vector from the wheel centre (y down) -> slot index, or nil (deadzone / no slot there).
function WheelLogic.pick(dx, dy)
	if dx * dx + dy * dy < W.DeadzonePx * W.DeadzonePx then
		return nil
	end
	local a = math.deg(math.atan2(dy, dx))
	local best, bestDiff = nil, math.huge
	for _, slot in ipairs(W.Slots) do
		local diff = math.abs(((a - slot.angle + 180) % 360) - 180)
		if diff < bestDiff then -- strict: ties go to the lower index
			best, bestDiff = slot.index, diff
		end
	end
	if bestDiff > W.MaxSectorDeg then
		return nil
	end
	return best
end

function WheelLogic.classify(heldSeconds)
	return heldSeconds < W.HoldTime and "tap" or "hold"
end

function WheelLogic.new(current)
	return { current = current or 1, last = nil }
end

-- loadout: { gunId | "" } for the usable slots. Returns ok, reason.
function WheelLogic.select(st, index, loadout)
	local slot = W.Slots[index]
	if not slot then
		return false, "invalid"
	end
	if not slot.usable then
		return false, "comingSoon"
	end
	if (loadout[index] or "") == "" then
		return false, "empty"
	end
	if index == st.current then
		return false, "same"
	end
	st.last = st.current
	st.current = index
	return true
end

function WheelLogic.swapLast(st, loadout)
	if not st.last then
		return false, "noLast"
	end
	return WheelLogic.select(st, st.last, loadout)
end

return WheelLogic
