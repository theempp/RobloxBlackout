-- Resolve a gun + equipped attachments into final stats (server and client use the same function).
-- Resolve once at equip time, never per shot.
local Config = require(script.Parent.Config)
local GunStats = {}

-- Which direction is "better" per stat; used to prove attachments are sidegrades (a buff AND a cost).
GunStats.LOWER_BETTER = { adsTime = true, reload = true, recoilUp = true, recoilSide = true, hipSpread = true, adsFov = true }
GunStats.HIGHER_BETTER = { range = true, falloffStart = true, mag = true, adsSpeedMult = true, damage = true }

function GunStats.resolve(gunId, equipped)
	local g = Config.GunsById[gunId]
	if not g then
		return nil
	end
	local s = table.clone(g)
	s.recoil = table.clone(g.recoil)
	s.recoil.side = table.clone(g.recoil.side)
	s.attachments = {}
	if type(equipped) == "table" then
		for slot, attId in pairs(equipped) do
			local a = Config.AttachmentsById[attId]
			if a and a.slot == slot and table.find(g.slots, slot) then
				s.attachments[slot] = attId
				for stat, m in pairs(a.mods) do
					if stat == "recoilUp" then
						s.recoil.up *= m
					elseif stat == "recoilSide" then
						for i, v in ipairs(s.recoil.side) do
							s.recoil.side[i] = v * m
						end
					elseif type(s[stat]) == "number" then
						s[stat] *= m
					end
				end
			end
		end
	end
	s.mag = math.max(1, math.floor(s.mag + 0.5))
	s.range = math.min(s.range, Config.Fire.MaxRange)
	s.falloffStart = math.min(s.falloffStart, s.range)
	s.interval = 60 / s.rpm
	return s
end

function GunStats.damageAt(s, dist, head)
	local m = 1
	if dist > s.falloffStart then
		local t = math.clamp((dist - s.falloffStart) / math.max(s.range - s.falloffStart, 1e-3), 0, 1)
		m = 1 + (s.minDamageMult - 1) * t
	end
	return s.damage * m * (head and s.headMult or 1)
end

-- Cone half-angle (degrees) for one pellet.
function GunStats.cone(s, ads)
	return s.pelletSpread + (ads and s.adsSpread or s.hipSpread)
end

return GunStats
