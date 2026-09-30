-- Laser gauntlet (Data Vault wing). Beams are pure functions of server time (shared Lasers), so this
-- hit test and every client's render agree with no replication. Touch = damage + alarm bump, once per
-- Cooldown. Hacking the corridor panel turns them off for HackOff seconds, then they re-arm.
-- Sampled twice per 10 Hz tick so a fast beam can't skip past a player between samples.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local M = require(shared.HeistMap)
local Lasers = require(shared.Lasers)
local LZ = Config.Lasers

local Gauntlet = { hits = 0 }
local S
local lasersRoom
for _, r in ipairs(M.Rooms) do
	if r.name == "Lasers" then
		lasersRoom = r
	end
end

local function state()
	return workspace.HeistState
end

function Gauntlet.speed(tier)
	return LZ.SpeedByTier[math.clamp(tier or 1, 1, #LZ.SpeedByTier)]
end

function Gauntlet.off(now)
	return now < (state():GetAttribute("LasersOffUntil") or 0)
end

-- Returns the index of a beam touching `rootPos` at time t, or nil.
function Gauntlet.touching(rootPos, t, mult)
	for i, def in ipairs(M.Lasers) do
		local a, b = Lasers.at(def, t, mult)
		if Lasers.touches(rootPos, a, b, LZ) then
			return i
		end
	end
	return nil
end

function Gauntlet.tick(_, run, dt)
	local now = workspace:GetServerTimeNow()
	local panel = S.map.laserPanel
	if panel:GetAttribute("Hacked") and not Gauntlet.off(now) then
		panel:SetAttribute("Hacked", false) -- re-armed
	end
	if Gauntlet.off(now) then
		return
	end
	local mult = state():GetAttribute("LaserSpeed") or 1
	run.laserHitAt = run.laserHitAt or {}
	for _, p in ipairs(run.players) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and not p:GetAttribute("BC_Downed") and M.inRect(root.Position, lasersRoom.min, lasersRoom.max)
			and now - (run.laserHitAt[p] or -math.huge) >= LZ.Cooldown then
			local hit = Gauntlet.touching(root.Position, now, mult) or Gauntlet.touching(root.Position, now - dt / 2, mult)
			if hit then
				run.laserHitAt[p] = now
				Gauntlet.hits += 1
				if S.crew.damage then
					S.crew.damage(p, LZ.Damage, "laser")
				end
				if S.alarm then
					S.alarm.bump("laser")
				end
				S.remotes.HeistEvent:FireClient(p, "laser", hit)
			end
		end
	end
end

function Gauntlet.init(s)
	S = s
	S.map = require(script.Parent.Map)
	S.hacks.laserPanel = function(_, _, _, panel)
		state():SetAttribute("LasersOffUntil", workspace:GetServerTimeNow() + LZ.HackOff)
		panel:SetAttribute("Hacked", true)
		return true
	end
end

function Gauntlet.start()
	state():SetAttribute("LasersOffUntil", 0)
	state():SetAttribute("LaserSpeed", Gauntlet.speed(1))
	S.map.laserPanel:SetAttribute("Hacked", false)
end

return Gauntlet
