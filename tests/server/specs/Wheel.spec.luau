-- Weapon wheel: 5 fixed slots (2L/2R/1T), drag-select, tap vs hold, swap-last, Coming Soon.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)
local WL = require(RS.BlackoutCrew.WheelLogic)

return function(T)
	for _, slot in ipairs(C.Wheel.Slots) do
		local a = math.rad(slot.angle)
		T.eq("drag toward slot " .. slot.index, WL.pick(math.cos(a) * 60, math.sin(a) * 60), slot.index)
		local b = math.rad(slot.angle + 20)
		T.eq("drag near slot " .. slot.index, WL.pick(math.cos(b) * 60, math.sin(b) * 60), slot.index)
	end
	T.eq("straight down = no slot", WL.pick(0, 80), nil)
	T.eq("deadzone = no slot", WL.pick(5, -5), nil)
	T.eq("left tie -> lower index", WL.pick(-80, 0), 1)
	T.eq("short press = tap", WL.classify(0.1), "tap")
	T.eq("long press = hold", WL.classify(C.Wheel.HoldTime + 0.05), "hold")

	local loadout = { "P1", "A2", "" }
	local st = WL.new(1)
	T.eq("coming soon slot 4", select(2, WL.select(st, 4, loadout)), "comingSoon")
	T.eq("coming soon slot 5", select(2, WL.select(st, 5, loadout)), "comingSoon")
	T.eq("empty slot", select(2, WL.select(st, 3, loadout)), "empty")
	T.eq("same slot", select(2, WL.select(st, 1, loadout)), "same")
	T.eq("swap with no history", select(2, WL.swapLast(st, loadout)), "noLast")
	T.check("select slot 2", WL.select(st, 2, loadout) and st.current == 2 and st.last == 1)
	T.check("tap swaps to last", WL.swapLast(st, loadout) and st.current == 1 and st.last == 2)
	T.check("tap again swaps back", WL.swapLast(st, loadout) and st.current == 2)
	T.eq("invalid index", select(2, WL.select(st, 7, loadout)), "invalid")
end
