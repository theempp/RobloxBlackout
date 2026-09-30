-- Heist client: every module compiled and initialised (server pass != client OK); HUD touch targets.
return function(T)
	local c = T.client or {}
	T.check("client reported", T.client ~= nil)
	T.check("client ready", c.ready == true, c.failed)
	T.eq("all heist client modules loaded", c.modules, c.expected)
	local ui = c.ui or {}
	T.check("hud exists", ui.hud == true, ui.error)
	T.eq("touch targets >= 44px", ui.small, "")
	T.eq("no overlapping buttons", ui.overlaps, "")
	T.eq("no offscreen buttons", ui.offscreen, "")
end
