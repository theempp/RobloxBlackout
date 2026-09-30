-- Directive drones outside the tower (§3b, §5d).
-- Repo drones: short loops (~22 s) over the stash zones, 2 + 1 per alarm tier (max 4, under the AI cap).
-- A parked/abandoned kart seen continuously fills its sabotage ring in SabotageTime[tier] seconds
-- (4 / 3 / 2.5), draining at half speed out of sight; full = sabotaged (flat tyres / lock-down). They
-- ignore the parking glows (those are client-only). No towing, no impound.
-- Pursuit drones: chase karts on their dash and EMP them (spin + slow, no kills). They only use the AI
-- budget left after tower AI + repo drones, so they mostly appear once the tower AI has streamed out.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local M = require(shared.HeistMap)
local Alarm = require(shared.Alarm)
local Perception = require(shared.Perception)
local RD, PD = Config.Drones.Repo, Config.Drones.Pursuit
local V = Vector3.new

local Drones = { repo = {}, pursuit = {}, emps = 0 }
local S
local los = RaycastParams.new()
los.FilterType = Enum.RaycastFilterType.Exclude

local function perimeter(loop)
	local n = 0
	for i = 1, #loop do
		n += (loop[i % #loop + 1] - loop[i]).Magnitude
	end
	return n
end

local function build(kind, pos, speed, health, turn)
	local m, root, ap, ao, eye = S.enemies.robot("drone", pos, { Speed = speed, TurnRate = turn, Health = health }, Drones.folder)
	m.Name = kind
	m:SetAttribute("Kind", kind)
	return { model = m, root = root, ap = ap, ao = ao, eye = eye }
end

function Drones.spawnRepo(i)
	local loop = M.RepoLoops[i]
	local d = build("repo", loop[1], perimeter(loop) / RD.LoopTime, RD.Health, RD.TurnRate)
	d.loop, d.wp = loop, 2
	table.insert(Drones.repo, d)
	return d
end

local function alive(list)
	local n = 0
	for _, d in ipairs(list) do
		if not d.dead then
			n += 1
		end
	end
	return n
end
Drones.alive = alive

function Drones.budget(run)
	local tower = run.towerCleared and 0 or S.enemies.alive()
	return Config.Enemies.Cap - tower - alive(Drones.repo) - alive(Drones.pursuit)
end

-- Repo count follows the tier (never shrinks when a hack drops it).
function Drones.reinforce(run)
	local want = Alarm.counts(run.alarm and run.alarm:tier() or 1, run.info.crewSize, run.params.sentryMult, Config.Enemies).repo
	local used = {}
	for _, d in ipairs(Drones.repo) do
		if not d.dead then
			used[d.loop] = true
		end
	end
	for i = 1, #M.RepoLoops do
		if alive(Drones.repo) >= want then
			break
		end
		if not used[M.RepoLoops[i]] then
			Drones.spawnRepo(i)
		end
	end
end

local function face(d, dir)
	if Vector2.new(dir.X, dir.Z).Magnitude > 0.1 then
		d.ao.CFrame = CFrame.lookAt(Vector3.zero, V(dir.X, 0, dir.Z))
	end
end

-- Does repo drone d see kart k right now? (cone pitched down, range, clear line; roofs hide karts)
function Drones.sees(d, k)
	local eye = d.eye.Position
	local look = (d.root.CFrame * CFrame.Angles(math.rad(RD.Pitch), 0, 0)).LookVector
	local target = k.root.Position + V(0, 1, 0)
	if not Perception.inCone(eye, look, target, RD.Cone, RD.Range) then
		return false
	end
	local hit = workspace:Raycast(eye, target - eye, los)
	return hit == nil or hit.Instance:IsDescendantOf(k.model)
end

local function sabotageStep(run, dt)
	local tier = run.alarm and run.alarm:tier() or 1
	local full = RD.SabotageTime[tier]
	for _, k in ipairs(S.karts.list) do
		local m = k.model
		if not m:GetAttribute("Driver") and not m:GetAttribute("Sabotaged") then
			local seen = false
			for _, d in ipairs(Drones.repo) do
				if not d.dead and Drones.sees(d, k) then
					seen = true
					break
				end
			end
			local nf = math.clamp((k.fill or 0) + (seen and dt / full or -dt * RD.DrainMult / full), 0, 1)
			k.fill = nf
			if nf >= 1 then
				k.fill = 0
				S.karts.sabotage(k)
			else
				local shown = nf > 0 and math.max(0.02, math.floor(nf * 50 + 0.5) / 50) or 0 -- 0.02 steps: low traffic
				if m:GetAttribute("SabotageFill") ~= shown then
					m:SetAttribute("SabotageFill", shown)
					S.karts.publishStatus(k)
				end
			end
		end
	end
end

local function dashingKarts(run)
	local out = {}
	for p in pairs(run.dash or {}) do
		local k = S.karts.byOwner[p]
		if k and not run.resolved[p] and k.model:GetAttribute("Driver") == p.UserId then
			table.insert(out, k)
		end
	end
	return out
end

function Drones.tick(_, run, dt)
	local now, sNow = os.clock(), workspace:GetServerTimeNow()
	local list = { Drones.folder, S.karts.folder }
	for _, p in ipairs(run.players) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	los.FilterDescendantsInstances = list
	Drones.reinforce(run)
	for _, d in ipairs(Drones.repo) do
		if not d.dead and (d.model.Parent == nil or d.model:GetAttribute("Down")) then
			d.dead = true
			d.ap.Enabled, d.ao.Enabled = false, false
		end
		if not d.dead then
			local goal = d.loop[d.wp]
			if (goal - d.root.Position).Magnitude < 2 then
				d.wp = d.wp % #d.loop + 1
				goal = d.loop[d.wp]
			end
			d.ap.Position = goal
			face(d, goal - d.root.Position)
		end
	end
	sabotageStep(run, dt)
	-- Pursuit
	local targets = dashingKarts(run)
	local tier = run.alarm and run.alarm:tier() or 1
	if #targets > 0 then
		while alive(Drones.pursuit) < PD.PerTier[tier] and Drones.budget(run) > 0 do
			local k = targets[1]
			local d = build("pursuit", k.root.Position + V(-40, 30, 0), PD.Speed, PD.Health, PD.TurnRate)
			d.cooldown = now + 2
			table.insert(Drones.pursuit, d)
		end
	else
		for _, d in ipairs(Drones.pursuit) do
			d.dead = true
			d.model:Destroy()
		end
		table.clear(Drones.pursuit)
	end
	for _, d in ipairs(Drones.pursuit) do
		if not d.dead and (d.model.Parent == nil or d.model:GetAttribute("Down")) then
			d.dead = true
			d.ap.Enabled, d.ao.Enabled = false, false
		end
		if not d.dead and #targets > 0 then
			local best, bd = nil, math.huge
			for _, k in ipairs(targets) do
				local dist = (k.root.Position - d.root.Position).Magnitude
				if dist < bd then
					best, bd = k, dist
				end
			end
			local kp, kv = best.root.Position, best.root.AssemblyLinearVelocity
			d.ap.Position = kp + V(0, PD.Height, 0) - kv * 0.25
			face(d, kp - d.root.Position)
			local flat = kp - d.root.Position
			if Vector2.new(flat.X, flat.Z).Magnitude <= PD.EmpRange and now >= (d.cooldown or 0) then
				d.cooldown = now + PD.Cooldown
				Drones.emp(best, sNow)
			end
		end
	end
end

function Drones.emp(k, sNow)
	Drones.emps += 1
	k.model:SetAttribute("EmpUntil", sNow + Config.Kart.EmpTime)
	k.model:SetAttribute("EmpAt", sNow)
	S.notify(k.owner, "EMP!")
end

function Drones.init(s)
	S = s
	S.drones = Drones
	Drones.folder = Instance.new("Folder")
	Drones.folder.Name = "Drones"
	Drones.folder.Parent = workspace
end

function Drones.start(_, run)
	Drones.reset()
	Drones.reinforce(run)
end

function Drones.reset()
	table.clear(Drones.repo)
	table.clear(Drones.pursuit)
	Drones.folder:ClearAllChildren()
end

return Drones
