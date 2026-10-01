-- Loot (§5b): one heavy item per player on the vault pedestals, small loot on desks. Heavy: carried on
-- the back (welded, massless), ~40% slower + holstered (Crew.refresh), drop / hand-off allowed, loads
-- onto your own kart (banks there, 1 per kart). Small loot counts the moment it's picked up. The first
-- heavy pickup breaches the vault: the service door opens. Recall/leave drops what you carry.
local CollectionService = game:GetService("CollectionService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local M = require(shared.HeistMap)
local LC = Config.Loot

local Loot = {}
local S, Map

local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function makeHeavy(i, pos)
	local m = Instance.new("Model")
	m.Name = "Heavy" .. i
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local crate = part(m, "Crate", Vector3.new(2.6, 2, 2.6), CFrame.new(pos), Color3.fromRGB(28, 28, 34))
	local band = part(m, "Band", Vector3.new(2.7, 0.4, 2.7), CFrame.new(pos + Vector3.new(0, 0.5, 0)), Color3.fromRGB(230, 159, 0), Enum.Material.SmoothPlastic)
	band.CanCollide, band.CanQuery = false, false
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = crate, band
	w.Parent = band
	m.PrimaryPart = crate
	m:SetAttribute("Heavy", true)
	m:SetAttribute("Value", LC.HeavyValue)
	m:SetAttribute("Hold", LC.HeavyHold)
	CollectionService:AddTag(m, "BC_Loot")
	m.Parent = Loot.folder
	return m
end

local function makeSmall(i, pos)
	local p = part(Loot.folder, "Small" .. i, Vector3.new(0.9, 0.6, 0.9), CFrame.new(pos), Color3.fromRGB(0, 158, 115), Enum.Material.SmoothPlastic)
	p.CanCollide = false
	p:SetAttribute("Heavy", false)
	p:SetAttribute("Value", LC.SmallValue)
	CollectionService:AddTag(p, "BC_Loot")
	return p
end

local function setPhysics(m, carried)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = not carried and p.Name == "Crate"
			p.Massless = carried
			p.CanQuery = not carried and p.Name == "Crate"
		end
	end
end

local function unweld(m)
	local w = m.PrimaryPart:FindFirstChild("CarryWeld")
	if w then
		w:Destroy()
	end
end

local function attach(m, toPart, offset)
	unweld(m)
	setPhysics(m, true)
	m:PivotTo(toPart.CFrame * offset)
	local w = Instance.new("WeldConstraint")
	w.Name = "CarryWeld"
	w.Part0, w.Part1 = toPart, m.PrimaryPart
	w.Parent = m.PrimaryPart
end

-- Put a heavy item on the floor at `pos` (raycast down so it never floats or sinks).
local function place(m, pos)
	unweld(m)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { m, Loot.folder }
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), rp)
	local y = hit and hit.Position.Y or pos.Y
	setPhysics(m, false)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	m:PivotTo(CFrame.new(pos.X, y + 1, pos.Z))
end

function Loot.carrying(run, player)
	return run.loot.heavyOf[player]
end

local function take(run, player, m)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	attach(m, root, LC.CarryOffset)
	m:SetAttribute("Carrier", player.UserId)
	run.loot.heavyOf[player] = m
	player:SetAttribute("BC_Heavy", m.Name)
	S.crew.refresh(player)
	if not run.loot.breached then
		run.loot.breached = true
		Map.setServiceDoor(true) -- vault breached: service exit opens
	end
	return true
end

local function release(run, player)
	local m = run.loot.heavyOf[player]
	run.loot.heavyOf[player] = nil
	player:SetAttribute("BC_Heavy", nil)
	S.crew.refresh(player)
	if m then
		m:SetAttribute("Carrier", nil)
	end
	return m
end

function Loot.pickup(_, run, player, item)
	if item:GetAttribute("Heavy") then
		return take(run, player, item)
	end
	local v = item:GetAttribute("Value") or 0
	run.loot.small[player] = (run.loot.small[player] or 0) + v
	player:SetAttribute("BC_Small", run.loot.small[player])
	item:Destroy()
	return true
end

function Loot.drop(_, run, player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local m = release(run, player)
	if m and root then
		place(m, (root.CFrame * CFrame.new(0, 0, -3.5)).Position)
	end
	return m ~= nil
end

function Loot.handoff(_, run, player, mate)
	local m = release(run, player)
	return m ~= nil and take(run, mate, m)
end

-- Load onto your own kart: banks the heavy item (§5b). Kart holds one.
function Loot.load(_, run, player, kart)
	local m = release(run, player)
	if not m or not kart.PrimaryPart then
		return false
	end
	attach(m, kart.PrimaryPart, CFrame.new(0, 2.2, 3.2))
	m:SetAttribute("Loaded", true)
	kart:SetAttribute("Heavy", m.Name)
	run.loot.loaded[player] = m
	player:SetAttribute("BC_Loaded", true)
	return true
end

-- Recall / disconnect: drop what you carry where you stand.
function Loot.dropFor(run, player)
	if run.loot.heavyOf[player] then
		Loot.drop(S, run, player)
	end
end

function Loot.init(s)
	S = s
	Map = require(script.Parent.Map)
	Loot.folder = Instance.new("Folder")
	Loot.folder.Name = "HeistLoot"
	Loot.folder.Parent = workspace
	S.loot = Loot
	local fx = S.interact.effects
	fx.pickup, fx.drop, fx.handoff, fx.load = Loot.pickup, Loot.drop, Loot.handoff, Loot.load
end

function Loot.start(_, run)
	Loot.folder:ClearAllChildren()
	run.loot = { small = {}, heavyOf = {}, loaded = {}, breached = false }
	for i = 1, math.min(run.info.crewSize, #M.HeavyPedestals) do
		makeHeavy(i, M.HeavyPedestals[i] + Vector3.new(0, 2, 0))
	end
	for i, p in ipairs(M.SmallLoot) do
		makeSmall(i, p + Vector3.new(0, 0.5, 0))
	end
	for _, p in ipairs(run.players) do
		run.loot.small[p] = 0
		p:SetAttribute("BC_Small", 0)
	end
end

function Loot.leave(_, run, player)
	Loot.dropFor(run, player)
end

function Loot.reset()
	Loot.folder:ClearAllChildren()
end

return Loot
