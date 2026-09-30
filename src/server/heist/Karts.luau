-- One-seat karts (§3b, §7): one per player, lined up at the arrival, entered with the DRIVE action
-- (no touch-to-sit, so nobody takes your kart). Physics: the driver's client steps shared KartPhysics
-- on its own assembly (network owner = driver); Config.Kart.ServerPhysics switches to v0.3's
-- server-owned model with a validated KartInput remote. The server owns all kart state as attributes:
-- Parked, Sabotaged (+RoughEver for payout), SabotageFill, EmpUntil/EmpAt, Heavy, Driver. It also
-- rubber-bands a driver whose kart repeatedly outruns MaxSpeed. Repair minigame is validated here.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local M = require(shared.HeistMap)
local KartPhysics = require(shared.KartPhysics)
local Parking = require(shared.Parking)
local Repair = require(shared.Repair)
local Twists = require(shared.Twists)
local K, RC = Config.Kart, Config.Repair
local V = Vector3.new

local Karts = { byOwner = {}, list = {}, rubberBands = 0, rejectedInputs = 0 }
local S
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function weldPart(model, root, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = root.CFrame * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide, p.CanTouch, p.CastShadow, p.Massless = false, false, false, true
	p.Anchored = false
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = root, p
	w.Parent = p
	p.Parent = model
	return p
end

-- Matte black, numbered, chunky (§7). Chassis = physics root; everything else is massless decoration.
function Karts.build(owner, slot, cf)
	local m = Instance.new("Model")
	m.Name = "Kart" .. slot
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 4 karts max: always known to every client
	local black, dark, glow = Color3.fromRGB(22, 22, 26), Color3.fromRGB(40, 42, 50), Config.Colors.Slots[slot] or Config.Colors.Accent
	local root = Instance.new("Part")
	root.Name = "Chassis"
	root.Size = V(5, 0.8, 9.6)
	root.CFrame = cf
	root.Color = black
	root.Material = Enum.Material.SmoothPlastic
	root.CustomPhysicalProperties = PhysicalProperties.new(2, 0.2, 0, 1, 1)
	root.Anchored = true
	root.Parent = m
	m.PrimaryPart = root
	weldPart(m, root, "Nose", V(4.2, 0.9, 2.4), CFrame.new(0, 0.5, -4.4) * CFrame.Angles(math.rad(-12), 0, 0), black)
	weldPart(m, root, "Pod", V(5.2, 1, 3.6), CFrame.new(0, 0.7, 0.6), black)
	weldPart(m, root, "Wing", V(5.4, 0.25, 1.2), CFrame.new(0, 2.6, 4.6), dark)
	for _, x in ipairs({ -2.2, 2.2 }) do
		weldPart(m, root, "Strut", V(0.25, 1.8, 0.4), CFrame.new(x, 1.6, 4.6), dark)
	end
	weldPart(m, root, "Hoop", V(3, 0.3, 0.3), CFrame.new(0, 2.9, 1.9), dark)
	for _, w in ipairs(KartPhysics.wheels(K)) do
		weldPart(m, root, "Wheel", V(1, 1.8, 1.8), CFrame.new(w.X * 1.08, -0.1, w.Z) * CFrame.Angles(0, 0, math.rad(90)), black, nil, Enum.PartType.Cylinder)
	end
	weldPart(m, root, "Underglow", V(4.4, 0.1, 8.4), CFrame.new(0, -0.45, 0), glow, Enum.Material.Neon)
	local plate = weldPart(m, root, "Plate", V(1.8, 0.8, 0.1), CFrame.new(0, 0.6, 4.86), Color3.fromRGB(230, 230, 220))
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = black
	t.Text = string.format("%02d", slot)
	t.Parent = sg
	sg.Parent = plate
	-- §17 engraving zone: one swappable decal slot on the hood (texture swap = rename).
	weldPart(m, root, "BrandZone", V(2.4, 0.05, 1.4), CFrame.new(0, 0.97, -2.2), black).Transparency = 1
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = V(2, 0.4, 2)
	seat.CFrame = root.CFrame * CFrame.new(0, 0.8, 0.4)
	seat.MaxSpeed, seat.Torque, seat.TurnSpeed = 0, 0, 0 -- we drive, not the seat
	seat.HeadsUpDisplay = false
	seat.CanTouch = false -- no touch-to-sit: DRIVE action only
	seat.Transparency = 1
	seat.Massless = true
	seat.Anchored = false
	local sw = Instance.new("WeldConstraint")
	sw.Part0, sw.Part1 = root, seat
	sw.Parent = seat
	seat.Parent = m
	m:SetAttribute("Owner", owner.UserId)
	m:SetAttribute("Slot", slot)
	m:SetAttribute("Parked", false)
	m:SetAttribute("Sabotaged", false)
	m:SetAttribute("RoughEver", false)
	m:SetAttribute("SabotageFill", 0)
	m:SetAttribute("EmpUntil", 0)
	m:SetAttribute("EmpAt", 0)
	CollectionService:AddTag(m, "BC_Kart")
	m.Parent = Karts.folder
	return m, root, seat
end

local function setAnchored(k, on)
	k.root.Anchored = on
	if not on and RunService:IsRunning() then
		k.root:SetNetworkOwner(nil)
	end
end

function Karts.status(k)
	local m = k.model
	return m:GetAttribute("Sabotaged") and "sabotaged" or (m:GetAttribute("SabotageFill") or 0) > 0 and "spotted" or "hidden"
end

local function publishStatus(k)
	local st = Karts.status(k)
	if k.owner:GetAttribute("BC_KartStatus") ~= st then
		k.owner:SetAttribute("BC_KartStatus", st)
	end
end
Karts.publishStatus = publishStatus

-- DRIVE (Interact effect): seat the owner, hand the assembly to their client (or keep it, server mode).
function Karts.enter(_, _, player, model)
	local k = Karts.byOwner[player]
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not k or k.model ~= model or not hum or model:GetAttribute("Sabotaged") then
		return false
	end
	setAnchored(k, false)
	k.seat:Sit(hum)
	model:SetAttribute("Parked", false)
	model:SetAttribute("Driver", player.UserId)
	player:SetAttribute("BC_Driving", true)
	S.crew.refresh(player)
	k.lastGood, k.lastPos, k.lastT, k.strikes = k.root.CFrame, k.root.Position, os.clock(), 0
	if RunService:IsRunning() then
		k.root:SetNetworkOwner(not K.ServerPhysics and player or nil)
	end
	return true
end

local function exited(k)
	local m = k.model
	m:SetAttribute("Driver", nil)
	k.owner:SetAttribute("BC_Driving", nil)
	S.crew.refresh(k.owner)
	k.input = nil
	if RunService:IsRunning() and not k.root.Anchored then
		k.root:SetNetworkOwner(nil)
	end
	local flat = k.root.Position - k.spot.pos
	if Vector2.new(flat.X, flat.Z).Magnitude <= Config.Parking.Radius then
		setAnchored(k, true)
		m:SetAttribute("Parked", true) -- stays here the whole heist (§3b)
	end
	k.idleT = 0
end

function Karts.spawn(run, player, slot, spot)
	local a = M.Arrival
	local cf = CFrame.new(a.kart + V(0, 1.2, (slot - 1) * a.kartGap)) * CFrame.Angles(0, math.rad(a.yaw), 0)
	local m, root, seat = Karts.build(player, slot, cf)
	local k = { model = m, root = root, seat = seat, owner = player, slot = slot, spot = spot, state = KartPhysics.newState(),
		repairers = {}, steps = 0, idleT = 0, strikes = 0 }
	Karts.byOwner[player] = k
	table.insert(Karts.list, k)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not seat.Occupant and m:GetAttribute("Driver") then
			exited(k)
		end
	end)
	publishStatus(k)
	return k
end

-- Server-physics mode input (validated): only the seated owner; finite + clamped; stale -> neutral.
function Karts.input(player, t, s, b)
	local k = Karts.byOwner[player]
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not k or not hum or hum.SeatPart ~= k.seat or not K.ServerPhysics then
		Karts.rejectedInputs += 1
		return false
	end
	k.input = KartPhysics.cleanInput(t, s, b)
	k.inputAt = os.clock()
	return true
end

-- Repair (§5d). REPAIR action opens a repairer entry; taps are validated against the server's phase.
local function repairEvent(k, p, done)
	local r = k.repairers[p]
	S.remotes.HeistEvent:FireClient(p, "repair", { kart = k.model, done = done, steps = k.steps, need = RC.Steps,
		t0 = r and r.t0, period = r and r.period, zone = r and r.zone, width = RC.ZoneWidth })
end

local function newStep(k, p, t0)
	local r = k.repairers[p]
	r.t0 = t0
	r.n += 1
	r.zone = Repair.zone(k.slot * 1000 + r.n * 17 + p.UserId % 997, RC)
end

function Karts.beginRepair(_, _, player, model)
	local k
	for _, x in ipairs(Karts.list) do
		if x.model == model then
			k = x
		end
	end
	if not k or not model:GetAttribute("Sabotaged") then
		return false
	end
	k.repairers[player] = { period = Repair.period(player == k.owner, RC), n = 0 }
	newStep(k, player, workspace:GetServerTimeNow())
	repairEvent(k, player, false)
	return true
end

function Karts.repairTap(player, model, tap, now)
	now = now or workspace:GetServerTimeNow()
	for _, k in ipairs(Karts.list) do
		local r = k.model == model and k.repairers[player]
		if r then
			if Repair.hit(tap, now, r.t0, r.period, r.zone, RC) then
				k.steps += 1
				if k.steps >= RC.Steps then
					k.steps = 0
					model:SetAttribute("Sabotaged", false) -- RoughEver stays: payout Rough (90%)
					model:SetAttribute("SabotageFill", 0)
					k.fill = 0
					publishStatus(k)
					for p in pairs(k.repairers) do
						repairEvent(k, p, true)
					end
					table.clear(k.repairers)
					return "repaired"
				end
				newStep(k, player, now)
				for p in pairs(k.repairers) do
					repairEvent(k, p, false)
				end
				return "step"
			end
			newStep(k, player, now + RC.MissPenalty)
			repairEvent(k, player, false)
			return "miss"
		end
	end
	return "none"
end

function Karts.sabotage(k)
	k.model:SetAttribute("Sabotaged", true)
	k.model:SetAttribute("RoughEver", true)
	k.model:SetAttribute("SabotageFill", 0)
	publishStatus(k)
	S.notify(k.owner, "Your kart was sabotaged! Repair it before the escape.")
end

-- Server-owned physics (server mode, tests, empty karts rolling): PreSimulation, like the old Heartbeat loop.
local function physicsStep(dt)
	local sNow = workspace:GetServerTimeNow()
	for _, k in ipairs(Karts.list) do
		local m = k.model
		local driverOwned = m:GetAttribute("Driver") and not K.ServerPhysics
		local input = k.testInput or k.input
		if not k.root.Anchored and not driverOwned and k.root.Parent then
			if k.input and os.clock() - (k.inputAt or 0) > K.InputTimeout then
				input = { t = 0, s = 0, b = true } -- stale server-mode input: brake
			end
			local emp = sNow < (m:GetAttribute("EmpUntil") or 0)
			local spin = (m:GetAttribute("EmpAt") or 0) > (k.spunAt or 0)
			if spin then
				k.spunAt = m:GetAttribute("EmpAt")
			end
			KartPhysics.step(k.root, k.state, input or { t = 0, s = 0, b = true }, dt, K, rayParams,
				{ sabotaged = m:GetAttribute("Sabotaged"), emp = emp, spin = spin })
		end
	end
end

local function refreshRays()
	local list = { Karts.folder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local loot = workspace:FindFirstChild("HeistLoot")
	if loot then
		table.insert(list, loot)
	end
	rayParams.FilterDescendantsInstances = list
end

-- 10 Hz: anti-cheat speed check on driver-owned karts, repair range, idle anchoring, status.
function Karts.tick(_, run, dt)
	local now = os.clock()
	refreshRays()
	for _, k in ipairs(Karts.list) do
		local m = k.model
		if m:GetAttribute("Driver") and not K.ServerPhysics and k.lastT then
			local elapsed = now - k.lastT
			if elapsed >= 0.2 then
				local d = k.root.Position - k.lastPos
				local v = Vector2.new(d.X, d.Z).Magnitude / elapsed
				if v > K.MaxSpeed * K.SpeedTolerance then
					k.strikes += 1
					if k.strikes >= K.Strikes then
						Karts.rubberBand(k)
					end
				else
					k.strikes = 0
					k.lastGood = k.root.CFrame
				end
				k.lastPos, k.lastT = k.root.Position, now
			end
		elseif not m:GetAttribute("Driver") and not k.root.Anchored then
			k.idleT = k.root.AssemblyLinearVelocity.Magnitude < 1 and k.idleT + dt or 0
			if k.idleT >= K.IdleAnchor and not k.testInput then
				setAnchored(k, true)
			end
		end
		for p in pairs(k.repairers) do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if not root or (root.Position - k.root.Position).Magnitude > Config.Actions.repair.range + 2 or p:GetAttribute("BC_Downed") then
				k.repairers[p] = nil
				S.remotes.HeistEvent:FireClient(p, "repair", { kart = m, closed = true })
			end
		end
	end
end

function Karts.rubberBand(k)
	Karts.rubberBands += 1
	k.strikes = 0
	local driver = k.owner
	k.root:SetNetworkOwner(nil)
	k.model:PivotTo(k.lastGood)
	k.root.AssemblyLinearVelocity, k.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	k.lastPos, k.lastT = k.root.Position, os.clock()
	task.delay(0.5, function()
		if k.model.Parent and k.model:GetAttribute("Driver") == driver.UserId and not K.ServerPhysics then
			k.root:SetNetworkOwner(driver)
		end
	end)
end

function Karts.init(s)
	S = s
	S.karts = Karts
	Karts.folder = Instance.new("Folder")
	Karts.folder.Name = "KartsFolder"
	Karts.folder.Parent = workspace
	S.interact.effects.drive = Karts.enter
	S.interact.effects.repair = Karts.beginRepair
	S.Remotes.bind(S.remotes, "KartInput", Karts.input)
	S.Remotes.bind(S.remotes, "Repair", function(player, model, tap)
		Karts.repairTap(player, model, tap)
	end)
	RunService.PreSimulation:Connect(physicsStep)
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function(c)
			c.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- squad always on the minimap
		end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			p.Character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end
		p.CharacterAdded:Connect(function(c)
			c.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
	end
end

-- Parking draw (§5d) from the pool; remembers "had an obvious spot" in the profile for next run.
function Karts.start(_, run)
	Karts.reset()
	local who = {}
	for i, p in ipairs(run.players) do
		local d = S.profiles.loaded[p]
		who[i] = { lastObvious = d and d.heist and d.heist.lastObvious or false }
	end
	local spots = Parking.draw(M.Spots, who, Twists.seed(run.info.runId .. "park"))
	run.spots = {}
	for i, p in ipairs(run.players) do
		run.spots[p] = spots[i]
		p:SetAttribute("BC_Spot", spots[i].id)
		local d = S.profiles.loaded[p]
		if d and d.heist then
			d.heist.lastObvious = spots[i].quality == "obvious"
		end
		Karts.spawn(run, p, run.slot[p], spots[i])
	end
	refreshRays()
end

function Karts.leave(_, _, player)
	local k = Karts.byOwner[player]
	if k then
		k.model:Destroy()
		Karts.byOwner[player] = nil
		table.remove(Karts.list, table.find(Karts.list, k))
	end
end

function Karts.reset()
	for _, k in ipairs(Karts.list) do
		if k.owner then
			k.owner:SetAttribute("BC_Driving", nil)
			k.owner:SetAttribute("BC_KartStatus", nil)
			k.owner:SetAttribute("BC_Spot", nil)
			local hum = k.owner.Character and k.owner.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.SeatPart == k.seat then
				hum.Sit = false
			end
		end
	end
	table.clear(Karts.byOwner)
	table.clear(Karts.list)
	Karts.folder:ClearAllChildren()
end

return Karts
