-- Carry + movement rules (§5b, §5h). One heavy item per player, ~40% slower, gun holstered,
-- drop / hand-off allowed, solo-able (no forced 2-person lift). Heavy loot banks when loaded on
-- your own kart (1 per kart). Small loot counts the moment it's picked up. Pure.
local Carry = {}

-- state: { heavy, sneak, downed, driving }
function Carry.walkSpeed(state, cfg)
	if state.downed then
		return cfg.CrawlSpeed
	end
	local s = state.sneak and cfg.SneakSpeed or cfg.WalkSpeed
	return state.heavy and s * cfg.HeavySpeedMult or s
end

function Carry.holstered(state)
	return state.heavy or state.downed or state.driving or false
end

-- Noise radius (§5h): sneak 6, walk 15 while moving; recent gunfire 60 overrides; still = 0.
function Carry.noise(state, cfg)
	if state.gunfire then
		return cfg.Noise.Gunfire
	end
	if not state.moving then
		return 0
	end
	return state.sneak and cfg.Noise.Sneak or cfg.Noise.Walk
end

return Carry
