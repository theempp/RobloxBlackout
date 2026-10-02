-- Alarm on the server (shared Alarm meter): creep each tick, bumps from gunfire (Weapons.onFired),
-- cameras, sightings, downed players and lasers. A tier change speeds the lasers up and calls
-- reinforcements. The security terminal hack drops one tier (then cools down). The HUD reads
-- HeistState attributes Alarm (rounded) / Tier; nothing is sent per tick.
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local Alarm = require(shared.Alarm)
local AC = Config.Alarm

local Security = {}
local S

local function state()
	return workspace.HeistState
end

local function publish(run)
	local st = state()
	local v = math.floor(run.alarm.value + 0.5)
	if st:GetAttribute("Alarm") ~= v then
		st:SetAttribute("Alarm", v)
	end
	local t = run.alarm:tier()
	if st:GetAttribute("Tier") ~= t then
		st:SetAttribute("Tier", t)
	end
end

local function onTier(run, before, after)
	publish(run)
	state():SetAttribute("LaserSpeed", Config.Lasers.SpeedByTier[after] * (run.params.laserMult or 1))
	if after > before then
		for _, p in ipairs(run.players) do
			S.notify(p, "ALARM: " .. AC.Tiers[after])
		end
		if S.enemies then
			S.enemies.reinforce(run)
		end
	end
end

function Security.bump(kind)
	local run = S.Heist.run
	if not run or run.ended or not run.alarm then
		return
	end
	local before = run.alarm:tier()
	local after = run.alarm:bump(kind, run.params and run.params.bumpMult and run.params.bumpMult[kind])
	if after ~= before then
		onTier(run, before, after)
	else
		publish(run)
	end
end

function Security.tick(_, run, dt)
	local before = run.alarm:tier()
	local after = run.alarm:creep(dt)
	if after ~= before then
		onTier(run, before, after)
	else
		publish(run)
	end
	local term = S.map.terminal
	if term:GetAttribute("Hacked") and workspace:GetServerTimeNow() >= (term:GetAttribute("ReadyAt") or 0) then
		term:SetAttribute("Hacked", false)
	end
end

function Security.init(s)
	S = s
	S.alarm = Security
	S.Weapons.onFired = function(player)
		local run = S.Heist.run
		if run and not run.ended and run.alarm and player:GetAttribute("BC_Slot") then
			S.crew.gunfireAt[player] = os.clock()
			Security.bump("gunfire")
		end
	end
	S.hacks.terminal = function(_, run, _, term)
		local before = run.alarm:tier()
		local after = run.alarm:hackDrop()
		term:SetAttribute("Hacked", true)
		term:SetAttribute("ReadyAt", workspace:GetServerTimeNow() + AC.HackCooldown)
		onTier(run, before, after)
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("BC_Slot") then
				S.notify(p, "Security hacked: alarm " .. AC.Tiers[after])
			end
		end
		return true
	end
end

function Security.start(_, run)
	local diff = Config.Difficulty[run.info.difficulty] or Config.Difficulty.normal
	run.alarm = Alarm.new(AC, diff.alarm * (run.params and run.params.alarmMult or 1))
	S.map.terminal:SetAttribute("Hacked", false)
	state():SetAttribute("LaserSpeed", Config.Lasers.SpeedByTier[1] * (run.params.laserMult or 1))
	publish(run)
end

return Security
