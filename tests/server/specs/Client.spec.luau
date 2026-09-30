-- Client probes: compile/readiness (server pass != client OK), end-to-end fire through the real input
-- path with server confirmation, ADS FOV, Coming Soon slot refusal, wheel open/close.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)

return function(T)
	local c = T.client or {}
	T.check("client report received", T.client ~= nil)
	T.check("client compiled + initialised all modules", c.ready == true and c.modules == c.expected and c.expected > 0,
		tostring(c.modules) .. "/" .. tostring(c.expected) .. " " .. tostring(c.failed))
	T.check("e2e ran without error", c.e2eError == nil, c.e2eError)
	T.eq("spawned with free blaster", c.e2eGun, "dart9")
	T.check("aim-assist cone detects target under reticle", c.e2eAimOnTarget == true)
	T.eq("semi-auto: one trigger pull = one shot", c.e2eShots, 1)
	T.eq("client ammo decremented once", c.e2eAmmoDelta, 1)
	T.check("server confirmed the hit", (c.e2eConfirmed or 0) >= 1, c.e2eConfirmed)
	T.check("ADS on", c.adsOn == true)
	T.check("ADS zooms FOV", (c.adsFov or 99) < C.Camera.Fov - 5, c.adsFov)
	T.check("hip FOV restored", math.abs((c.hipFov or 0) - C.Camera.Fov) < 3, c.hipFov)
	T.eq("Coming Soon slot refused", c.comingSoon, "comingSoon")
	T.check("wheel opens and closes", c.wheelOpened == true and c.wheelClosed == true)
end
