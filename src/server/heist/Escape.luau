-- Escape (§5d). Each player's ~75 s gate timer starts when they drive their kart off its spot after the
-- vault breach. Reaching the gate in time banks everything: heavy loot Clean (kart never sabotaged,
-- 100% + bonus) or Rough (sabotaged + repaired, 90%); out of time = Timed-out (50%). Small loot always
-- 100%. When everyone is resolved (or the RunCap safety net hits) the run ends: payout per player,
-- Credits saved (Heist.finish -> Session.grant -> save). Also publishes each player's objective step
-- (BC_Step) for the HUD: park -> vault -> load -> escape -> dash -> done.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local M = require(shared.HeistMap)
local X, K = Config.Escape, Config.Kart

local Escape = {}
local S

function Escape.inGate(pos)
	local g = M.Gate
	return math.abs(pos.X - g.pos.X) <= g.halfX and math.abs(pos.Z - g.pos.Z) <= g.halfZ and math.abs(pos.Y - g.pos.Y) <= 8
end

-- Fastest plausible dash (anti-teleport): straight line spot -> gate at MaxSpeed x MinDashMult.
function Escape.minDash(spotPos)
	return (M.Gate.pos - spotPos).Magnitude / (K.MaxSpeed * X.MinDashMult)
end

function Escape.outcome(how, kartModel, hasHeavy)
	if not hasHeavy then
		return nil
	end
	if how == "gate" then
		return kartModel and kartModel:GetAttribute("RoughEver") and "rough" or "clean"
	end
	return "timeout"
end

function Escape.resolve(run, p, how)
	if run.resolved[p] then
		return
	end
	run.resolved[p] = how
	local k = S.karts.byOwner[p]
	local item = run.loot.loaded[p] or run.loot.heavyOf[p]
	run.outcomes[p] = Escape.outcome(how, k and k.model, item ~= nil)
	p:SetAttribute("BC_DashEnd", nil)
	p:SetAttribute("BC_Resolved", how)
	S.notify(p, how == "gate" and "BANKED! Wait for your crew." or "Out of time: heavy loot pays 50%.")
end

local function step(run, p)
	if run.resolved[p] then
		return "done"
	elseif run.dash[p] then
		return "dash"
	elseif p:GetAttribute("BC_Heavy") then
		return "load"
	elseif p:GetAttribute("BC_Loaded") then
		return "escape"
	end
	local k = S.karts.byOwner[p]
	if k and not k.model:GetAttribute("Parked") and not run.loot.breached then
		return "park"
	end
	return "vault"
end

function Escape.tick(_, run)
	local sNow = workspace:GetServerTimeNow()
	for _, p in ipairs(run.players) do
		if not run.resolved[p] then
			local k = S.karts.byOwner[p]
			local driving = k and k.model:GetAttribute("Driver") == p.UserId
			local d = run.dash[p]
			if d then
				if driving and Escape.inGate(k.root.Position) then
					if sNow - d.start >= d.min then
						Escape.resolve(run, p, "gate")
					elseif not d.flagged then
						d.flagged = true -- faster than physically possible: not banked (times out)
						run.suspicious = (run.suspicious or 0) + 1
					end
				elseif sNow >= d.start + X.DashTime then
					Escape.resolve(run, p, "timeout")
				end
			elseif run.loot.breached and driving then
				local flat = k.root.Position - k.spot.pos
				if Vector2.new(flat.X, flat.Z).Magnitude > Config.Parking.Radius then
					run.dash[p] = { start = sNow, min = Escape.minDash(k.spot.pos) }
					p:SetAttribute("BC_DashEnd", sNow + X.DashTime)
				end
			end
		end
		local st = step(run, p)
		if p:GetAttribute("BC_Step") ~= st then
			p:SetAttribute("BC_Step", st)
		end
	end
	if sNow - run.started >= X.RunCap then
		for _, p in ipairs(run.players) do
			Escape.resolve(run, p, "timeout")
		end
	end
	local all = #run.players > 0
	for _, p in ipairs(run.players) do
		if not run.resolved[p] then
			all = false
		end
	end
	if all then
		local amounts, detail = S.Heist.amounts(run, function(p)
			return run.outcomes[p]
		end)
		S.Heist.finish(S, "done", amounts, detail)
	end
end

function Escape.init(s)
	S = s
	S.escape = Escape
end

function Escape.start(_, run)
	run.dash, run.resolved, run.outcomes = {}, {}, {}
	for _, p in ipairs(run.players) do
		p:SetAttribute("BC_Resolved", nil)
		p:SetAttribute("BC_DashEnd", nil)
	end
end

function Escape.reset()
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		p:SetAttribute("BC_Resolved", nil)
		p:SetAttribute("BC_DashEnd", nil)
		p:SetAttribute("BC_Step", nil)
	end
end

return Escape
