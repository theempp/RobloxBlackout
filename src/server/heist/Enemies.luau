-- Tower AI (§5b, §5h): Sentry bots on patrol loops, sweeping Cameras (hackable, shootable), Watcher
-- drones (Tier 2+). Guard set A routes come from HeistMap. Bots are physics assemblies driven by
-- server-owned AlignPosition/AlignOrientation, so clients get smooth motion from normal physics
-- replication; brains think at 10 Hz. No pathfinding: bots follow their loop, stop and turn to
-- investigate noise, hold and fire when alerted (cheap, and nothing to get stuck on). Cameras sweep as
-- a pure function of server time (clients turn the head locally: zero replication). Everything is a
-- BC_Target robot (NoRespawn). Counts = shared Alarm.counts(tier, crew, twist) under the cap. When the
-- whole crew is out of a breached tower, tower AI streams out, freeing the budget for the escape.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local M = require(shared.HeistMap)
local Alarm = require(shared.Alarm)
local Perception = require(shared.Perception)
local E = Config.Enemies
local V = Vector3.new

local Enemies = { list = {}, cameras = {}, shots = 0 }
local S
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
local EYE = { patrol = Color3.fromRGB(220, 230, 255), investigate = Color3.fromRGB(255, 190, 40), alert = Color3.fromRGB(255, 40, 60) }

local function part(parent, name, size, cf, color, material, root)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide, p.CanTouch, p.CastShadow = false, false, false
	p.Anchored = root == nil
	if root then
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = root, p
		w.Parent = p
	end
	p.Parent = parent
	return p
end

local function robot(kind, pos, cfg)
	local m = Instance.new("Model")
	m.Name = kind
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local cf = CFrame.new(pos)
	local root = part(m, "Root", V(1.6, 1.6, 1.6), cf, Color3.new(), nil, nil)
	root.Anchored, root.Transparency, root.CanQuery = false, 1, false
	local dark, grey = Color3.fromRGB(36, 38, 48), Color3.fromRGB(118, 124, 140)
	local eye
	if kind == "sentry" then
		part(m, "Body", V(2.2, 2.4, 1.6), cf * CFrame.new(0, 0.4, 0), grey, nil, root)
		part(m, "Skirt", V(2.6, 0.5, 2), cf * CFrame.new(0, -1.1, 0), dark, nil, root)
		part(m, "Head", V(1.5, 1.1, 1.3), cf * CFrame.new(0, 2.2, 0), grey, nil, root)
		eye = part(m, "Eye", V(1.1, 0.22, 0.1), cf * CFrame.new(0, 2.3, -0.67), EYE.patrol, Enum.Material.Neon, root)
	else
		part(m, "Body", V(2.6, 0.6, 2.6), cf, dark, nil, root)
		for _, o in ipairs({ V(1.8, 0.3, 1.8), V(-1.8, 0.3, 1.8), V(1.8, 0.3, -1.8), V(-1.8, 0.3, -1.8) }) do
			part(m, "Rotor", V(1.4, 0.1, 1.4), cf * CFrame.new(o), grey, nil, root).CanQuery = false
		end
		part(m, "Head", V(1.1, 0.8, 1.1), cf * CFrame.new(0, -0.6, 0), grey, nil, root)
		eye = part(m, "Eye", V(0.7, 0.2, 0.1), cf * CFrame.new(0, -0.6, -0.56), EYE.patrol, Enum.Material.Neon, root)
	end
	eye.CanQuery = false
	local att = Instance.new("Attachment")
	att.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e6
	ap.MaxVelocity = cfg.Speed
	ap.Responsiveness = 40
	ap.Position = pos
	ap.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e6
	ao.MaxAngularVelocity = math.rad(cfg.TurnRate)
	ao.Responsiveness = 30
	ao.CFrame = CFrame.new()
	ao.Parent = root
	m.PrimaryPart = root
	m:SetAttribute("Kind", kind)
	m:SetAttribute("MaxHealth", cfg.Health)
	m:SetAttribute("Health", cfg.Health)
	m:SetAttribute("Down", false)
	m:SetAttribute("NoRespawn", true)
	m:SetAttribute("State", "patrol")
	CollectionService:AddTag(m, "BC_Target")
	CollectionService:AddTag(m, "BC_Enemy")
	m.Parent = Enemies.folder
	root:SetNetworkOwner(nil) -- after parenting (Build 1 gotcha)
	return m, root, ap, ao, eye
end

local function spawn(run, kind, route, startWp)
	local cfg = kind == "sentry" and E.Sentry or E.Watcher
	local hover = kind == "sentry" and cfg.Hover or 0
	local wp = startWp or 1
	local pos = route[wp] + V(0, hover, 0)
	local m, root, ap, ao, eye = robot(kind, pos, cfg)
	local e = { kind = kind, cfg = cfg, model = m, root = root, ap = ap, ao = ao, eye = eye, route = route, hover = hover,
		wp = wp % #route + 1, state = "patrol", seen = {}, spottedAt = {}, lastSeen = 0, nextShot = 0, until_ = 0 }
	table.insert(Enemies.list, e)
	return e
end

local function camera(i, def)
	local m = Instance.new("Model")
	m.Name = "Camera" .. i
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local grey = Color3.fromRGB(118, 124, 140)
	part(m, "Mount", V(0.6, 0.6, 0.6), CFrame.new(def.pos + V(0, 0.8, 0)), grey)
	local head = part(m, "Head", V(1, 0.8, 1.6), CFrame.new(def.pos) * CFrame.Angles(0, math.rad(def.yaw), 0), grey)
	head.CanQuery = true
	local lens = part(m, "Eye", V(0.5, 0.5, 0.1), head.CFrame * CFrame.new(0, 0, -0.82), EYE.alert, Enum.Material.Neon)
	lens.CanQuery = false
	m.PrimaryPart = head
	m:SetAttribute("Kind", "camera")
	m:SetAttribute("Def", i)
	m:SetAttribute("Range", E.Camera.HackRange)
	m:SetAttribute("MaxHealth", E.Camera.Health)
	m:SetAttribute("Health", E.Camera.Health)
	m:SetAttribute("Down", false)
	m:SetAttribute("NoRespawn", true)
	m:SetAttribute("Hacked", false)
	CollectionService:AddTag(m, "BC_Target")
	CollectionService:AddTag(m, "BC_Hackable")
	CollectionService:AddTag(m, "BC_Camera")
	m.Parent = Enemies.folder
	return { def = def, model = m, seen = {}, cooldown = 0 }
end

local function setState(e, st)
	if e.state ~= st then
		e.state = st
		e.model:SetAttribute("State", st)
		e.eye.Color = EYE[st]
	end
end

function Enemies.alive(kind)
	local n = 0
	for _, e in ipairs(Enemies.list) do
		if (not kind or e.kind == kind) and not e.dead then
			n += 1
		end
	end
	return n
end

-- Spawn up to the counts for the current tier (Alarm.counts: crew scaling, twist, cap).
function Enemies.reinforce(run)
	if run.towerCleared then
		return
	end
	local set = M.GuardSets.A
	local want = Alarm.counts(run.alarm and run.alarm:tier() or 1, run.info.crewSize, run.params.sentryMult, E)
	run.counts = want
	local used = {}
	for _, e in ipairs(Enemies.list) do
		if not e.dead then
			used[e.route] = (used[e.route] or 0) + 1
		end
	end
	local function fill(kind, routes, n)
		local k = 0
		while Enemies.alive(kind) < n and k < 20 do
			k += 1
			local best, uses = nil, math.huge
			for _, r in ipairs(routes) do
				if (used[r] or 0) < uses then
					best, uses = r, used[r] or 0
				end
			end
			used[best] = (used[best] or 0) + 1
			spawn(run, kind, best, uses > 0 and math.floor(#best / 2) + 1 or 1) -- reused route: opposite side
		end
	end
	fill("sentry", set.sentries, want.sentries)
	fill("watcher", set.watchers, want.watchers)
end

local function refreshFilter()
	local list = { Enemies.folder }
	local loot, beams = workspace:FindFirstChild("HeistLoot"), workspace:FindFirstChild("KartsFolder")
	if loot then
		table.insert(list, loot)
	end
	if beams then
		table.insert(list, beams)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	losParams.FilterDescendantsInstances = list
end

local function clear(from, to)
	return workspace:Raycast(from, to - from, losParams) == nil
end
Enemies.clear = clear

-- Players an enemy may notice: in the run, standing, not recalling.
local function targets(run)
	local out = {}
	for _, p in ipairs(run.players) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local head = p.Character and p.Character:FindFirstChild("Head")
		if root and head and not p:GetAttribute("BC_Downed") and not p:GetAttribute("BC_Recall") then
			table.insert(out, { p = p, root = root.Position, head = head.Position })
		end
	end
	return out
end

local function spot(run, e, p)
	local now = os.clock()
	if now - (e.spottedAt[p] or -math.huge) >= Config.Alarm.SightingCooldown then
		e.spottedAt[p] = now
		S.alarm.bump("sighting")
	end
end

-- Brain step for one bot. Exposed for tests.
function Enemies.think(run, e, dt, now, sNow, tlist)
	local pos = e.root.Position
	local eye = e.model.Head.Position
	local cf = e.root.CFrame
	local look = e.kind == "watcher" and (cf * CFrame.Angles(math.rad(e.cfg.Pitch), 0, 0)).LookVector or cf.LookVector
	local vision = run.params.visionMult or 1
	local seenTarget
	for _, t in ipairs(tlist) do
		local sees = Perception.inCone(eye, look, t.head, e.cfg.Cone, e.cfg.Range * vision) and clear(eye, t.head)
		local spotted
		e.seen[t.p], spotted = Perception.accumulate(e.seen[t.p] or 0, sees, dt, e.cfg.SpotTime)
		if spotted and not seenTarget then
			seenTarget = t
		elseif not sees and e.state == "patrol" and Perception.hears(pos, t.root, S.crew.noise(t.p, now)) then
			setState(e, "investigate")
			e.lookAt, e.until_ = t.root, now + e.cfg.InvestigateTime
		end
	end
	if seenTarget then
		if e.state ~= "alert" or e.target ~= seenTarget.p then
			spot(run, e, seenTarget.p)
		end
		setState(e, "alert")
		e.target, e.lastSeen, e.lookAt = seenTarget.p, now, seenTarget.root
	end
	if e.state == "alert" then
		local t
		for _, x in ipairs(tlist) do
			if x.p == e.target then
				t = x
			end
		end
		if not t then
			setState(e, "patrol")
			e.target = nil
		else
			e.lookAt = t.root
			local los = (t.head - eye).Magnitude <= e.cfg.AttackRange and clear(eye, t.head)
			if los then
				e.lastSeen = now
				if now >= e.nextShot then
					e.nextShot = now + e.cfg.FireInterval
					Enemies.shots += 1
					e.model:SetAttribute("ShotAt", sNow)
					e.model:SetAttribute("TargetId", t.p.UserId)
					S.crew.damage(t.p, e.cfg.Damage, e.kind)
				end
			elseif now - e.lastSeen > e.cfg.LoseTime then
				setState(e, "investigate")
				e.target, e.until_ = nil, now + e.cfg.InvestigateTime
			end
		end
	elseif e.state == "investigate" and now >= e.until_ then
		setState(e, "patrol")
	end
	-- Motion: patrol walks the loop; investigate/alert hold position and face the point of interest.
	local goal = e.route[e.wp] + V(0, e.hover, 0)
	if e.state == "patrol" then
		local flat = goal - pos
		if Vector2.new(flat.X, flat.Z).Magnitude < 1.5 then
			e.wp = e.wp % #e.route + 1
			goal = e.route[e.wp] + V(0, e.hover, 0)
		end
		e.ap.Position = goal
		e.lookAt = goal
	else
		e.ap.Position = pos
	end
	local d = (e.lookAt or goal) - pos
	if Vector2.new(d.X, d.Z).Magnitude > 0.1 then
		e.ao.CFrame = CFrame.lookAt(Vector3.zero, V(d.X, 0, d.Z))
	end
end

local function cameraStep(run, c, dt, now, sNow, tlist)
	local m = c.model
	if m:GetAttribute("Down") or m:GetAttribute("Hacked") then
		return
	end
	local cc = E.Camera
	local look = Perception.look(Perception.cameraYaw(c.def, sNow, cc.Period), cc.Pitch)
	for _, t in ipairs(tlist) do
		local sees = Perception.inCone(c.def.pos, look, t.head, cc.Cone, cc.Range * (run.params.visionMult or 1)) and clear(c.def.pos, t.head)
		local spotted
		c.seen[t.p], spotted = Perception.accumulate(c.seen[t.p] or 0, sees, dt, cc.SpotTime)
		if spotted and now >= c.cooldown then
			c.cooldown = now + cc.Cooldown
			m:SetAttribute("SpottedAt", sNow)
			S.alarm.bump("camera")
			for _, e in ipairs(Enemies.list) do -- call nearby bots to look
				if not e.dead and e.state == "patrol" and (e.root.Position - t.root).Magnitude <= cc.CallRadius then
					setState(e, "investigate")
					e.lookAt, e.until_ = t.root, now + e.cfg.InvestigateTime
				end
			end
		end
	end
end

Enemies.cameraStep = cameraStep

function Enemies.streamOut(run)
	run.towerCleared = true
	for _, e in ipairs(Enemies.list) do
		e.dead = true
		e.model:Destroy()
	end
	table.clear(Enemies.list)
	workspace.HeistState:SetAttribute("TowerCleared", true)
end

function Enemies.tick(_, run, dt)
	local now, sNow = os.clock(), workspace:GetServerTimeNow()
	refreshFilter()
	local tlist = targets(run)
	for _, e in ipairs(Enemies.list) do
		if not e.dead and (e.model.Parent == nil or e.model:GetAttribute("Down")) then
			e.dead = true
			e.ap.Enabled, e.ao.Enabled = false, false -- wreck drops where it died
		end
		if not e.dead then
			Enemies.think(run, e, dt, now, sNow, tlist)
		end
	end
	for _, c in ipairs(Enemies.cameras) do
		cameraStep(run, c, dt, now, sNow, tlist)
	end
	-- Tower AI streams out once the vault is breached and nobody standing is inside (§5d).
	if not run.towerCleared and run.loot and run.loot.breached then
		local inside = false
		for _, p in ipairs(run.players) do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if root and not p:GetAttribute("BC_Recall") and M.inTower(root.Position) then
				inside = true
			end
		end
		if not inside then
			Enemies.streamOut(run)
		end
	end
end

function Enemies.init(s)
	S = s
	S.enemies = Enemies
	Enemies.folder = Instance.new("Folder")
	Enemies.folder.Name = "Enemies"
	Enemies.folder.Parent = workspace
	S.hacks.camera = function(_, _, _, m)
		m:SetAttribute("Hacked", true) -- off for the run; drops off the minimap
		return true
	end
end

function Enemies.start(_, run)
	Enemies.reset()
	workspace.HeistState:SetAttribute("TowerCleared", false)
	for i, def in ipairs(M.GuardSets.A.cameras) do
		table.insert(Enemies.cameras, camera(i, def))
	end
	Enemies.reinforce(run)
end

function Enemies.reset()
	table.clear(Enemies.list)
	table.clear(Enemies.cameras)
	Enemies.folder:ClearAllChildren()
end

return Enemies
