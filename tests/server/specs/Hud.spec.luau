-- HUD scale + touch targets (pure), plus the client probes: compile/readiness and on-screen button sizes.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)
local HudScale = require(RS.BlackoutCrew.HudScale)

return function(T)
	T.near("iPhone XR landscape scale", HudScale.scale(896, 414, false), math.min(896 * 0.55, 414) / 340)
	T.eq("tiny screen clamps to min", HudScale.scale(480, 270, false), C.Hud.MinScale)
	T.eq("tablet clamps to max", HudScale.scale(2732, 2048, false), C.Hud.MaxScale)
	T.near("large HUD multiplier", HudScale.scale(896, 414, true), HudScale.scale(896, 414, false) * C.Hud.LargeMult)
	local worst = math.huge
	for S = C.Hud.MinScale, C.Hud.MaxScale * C.Hud.LargeMult, 0.01 do
		for u = C.Touch.UserScale[1], C.Touch.UserScale[2], 0.05 do
			for _, b in pairs(C.Touch.Buttons) do
				worst = math.min(worst, HudScale.touchSize(b.size, S, u) * S)
			end
		end
	end
	T.check("every button >= MinTouchPx at every scale", worst >= C.Hud.MinTouchPx, worst)

	local c = T.client or {}
	T.check("client compiled + initialised all modules", c.ready == true and c.modules == c.expected and c.expected > 0,
		tostring(c.modules) .. "/" .. tostring(c.expected) .. " " .. tostring(c.failed))
	T.check("HUD exists on client", c.hud == true, c.uiError)
	T.check("HUD buttons visible", (c.buttons or 0) >= 5, c.buttons)
	T.check("no on-screen button under 44px", c.small == "" and (c.minButton or 0) >= C.Hud.MinTouchPx, tostring(c.small) .. " min=" .. tostring(c.minButton))
end
