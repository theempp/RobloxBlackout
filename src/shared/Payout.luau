-- Payout (§5d, resolves §2 vs §3b): loot never hits zero; small loot always 100%. Heavy loot, banked
-- per player at the gate: Clean = 100% + bonus, Rough (sabotaged, repaired) = 90%, Timed-out/caught
-- = 50%. "Caught" (brief undefined) = the crew wiped while you held or had loaded heavy loot.
-- Crew haul bonus (+8%/extra member, cap 24%) and difficulty apply to the total. Pure.
local Payout = {}

-- p = { small, heavy = value or 0, outcome = "clean"|"rough"|"timeout"|"caught"|nil, crewSize, difficulty }
function Payout.compute(p, cfg, crewCfg)
	local heavy = 0
	if (p.heavy or 0) > 0 and p.outcome then
		heavy = p.heavy * (cfg.HeavyMult[p.outcome] or 0)
	end
	local base = (p.small or 0) + heavy
	local bonus = math.min(math.max((p.crewSize or 1) - 1, 0) * crewCfg.BonusPerMember, crewCfg.BonusCap)
	return math.floor(base * (1 + bonus) * (p.difficulty or 1) + 1e-6)
end

return Payout
