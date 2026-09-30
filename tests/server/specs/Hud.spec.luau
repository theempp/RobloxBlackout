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

	-- Default layout on real device sizes (landscape px, minus approximate safe insets): circular buttons
	-- must not overlap each other, the settings gear (40,40 r26) or the ammo panel (top-right 170x50).
	local devices = { { "iPhone SE", 667, 375, 0, 0 }, { "iPhone 14", 844, 390, 47, 21 }, { "iPhone XR", 896, 414, 48, 21 },
		{ "Android 20:9", 800, 360, 24, 0 }, { "iPad", 1024, 768, 0, 20 } }
	for _, d in ipairs(devices) do
		local w, h = d[2] - 2 * d[4], d[3] - d[5]
		local S = HudScale.scale(w, h, false)
		local W, H = w / S, h / S
		local circles = { { "gear", 40, 40, 26 } }
		for id, b in pairs(C.Touch.Buttons) do
			if not b.optional then
				table.insert(circles, { id, b.x * W, b.y * H, HudScale.touchSize(b.size, S, 1) / 2 })
			end
		end
		local problems = {}
		for i, a in ipairs(circles) do
			if a[2] - a[4] < 0 or a[3] - a[4] < 0 or a[2] + a[4] > W or a[3] + a[4] > H then
				table.insert(problems, a[1] .. " off-screen")
			end
			if a[2] + a[4] > W - 180 and a[3] - a[4] < 56 then
				table.insert(problems, a[1] .. " under ammo panel")
			end
			for j = i + 1, #circles do
				local b = circles[j]
				if (Vector2.new(a[2], a[3]) - Vector2.new(b[2], b[3])).Magnitude < a[4] + b[4] + 2 then
					table.insert(problems, a[1] .. "+" .. b[1])
				end
			end
		end
		T.eq("default layout clean on " .. d[1], table.concat(problems, ","), "")
	end

	local c = T.client or {}
	T.check("HUD exists on client", c.hud == true, c.uiError)
	T.check("HUD buttons visible", (c.buttons or 0) >= 5, c.buttons)
	T.eq("no overlapping buttons", c.overlaps, "")
	T.eq("no off-screen buttons", c.offscreen, "")
	T.check("hip viewmodel in lower-right, in front", c.vmHip == true)
	T.check("ADS viewmodel centred", c.vmAds == true, "blend=" .. tostring(c.adsBlend))
	T.check("no on-screen button under 44px", c.small == "" and (c.minButton or 0) >= C.Hud.MinTouchPx, tostring(c.small) .. " min=" .. tostring(c.minButton))
end
