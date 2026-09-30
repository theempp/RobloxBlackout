-- HUD scale + touch-target rules (ported from roblox 1 rescale): design units 800x340,
-- S = clamp(min(vp.X*.55, vp.Y)/340, .85, 1.6) * (large 1.15). Touch targets are rounded UP so
-- they stay >= MinTouchPx physical pixels after all scaling.
local Config = require(script.Parent.Config)
local H = Config.Hud
local HudScale = {}

function HudScale.scale(vpX, vpY, large)
	return math.clamp(math.min(vpX * H.WidthFactor, vpY) / H.DesignHeight, H.MinScale, H.MaxScale) * (large and H.LargeMult or 1)
end

-- Final size in design units for a button of `size` units at user scale `userScale`.
function HudScale.touchSize(size, S, userScale)
	return math.max(size * (userScale or 1), math.ceil(H.MinTouchPx / S))
end

return HudScale
