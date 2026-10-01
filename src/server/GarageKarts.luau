-- Lobby karts share the heist model, physics and client controls. No rewards or lap timers.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Tags = game:GetService("CollectionService")
local shared = game:GetService("ReplicatedStorage").BlackoutCrew
local C = require(shared.Config)
local Model = require(shared.KartModel)
local Physics = require(shared.KartPhysics)
local Map = require(shared.GarageMap)
local Karts = { byOwner = {} }
local S
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function mass(k, character)
	for _, p in ipairs(k.massless or {}) do if p.Parent then p.Massless = false end end
	k.massless = {}
	for _, p in ipairs(character and character:GetDescendants() or {}) do
		if p:IsA("BasePart") and not p.Massless then
			p.Massless = true
			table.insert(k.massless, p)
		end
	end
end
function Karts.exit(k)
	k.model:SetAttribute("Driver", nil)
	k.owner:SetAttribute("BC_Driving", nil)
	mass(k)
	if S.Weapons.states[k.owner] then S.Weapons.setHolstered(k.owner, false) end
	k.state, k.input, k.idle = Physics.newState(), nil, 0
	if k.root.Parent and not k.root.Anchored then k.root:SetNetworkOwner(nil) end
end
function Karts.remove(p)
	local k = Karts.byOwner[p]
	if k then
		Karts.exit(k)
		k.model:Destroy()
		Karts.byOwner[p] = nil
	end
end
function Karts.spawn(p)
	local k = Karts.byOwner[p]
	if k then return k end
	local used = {}
	for _, other in pairs(Karts.byOwner) do used[other.slot] = true end
	local slot = 1
	while used[slot] do slot += 1 end
	local cf = Map.frame(C.Garage.KartBay + Vector3.new((slot - 1) % 4 * C.Garage.KartGap, 0, math.floor((slot - 1) / 4) * C.Garage.KartGap))
	local m, root, seat = Model.build((slot - 1) % 4 + 1, cf, { name = "GarageKart" .. p.UserId, number = slot })
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:SetAttribute("Owner", p.UserId)
	Tags:AddTag(m, "BC_Kart")
	m.Parent = Karts.folder
	k = { owner = p, model = m, root = root, seat = seat, slot = slot, home = cf, state = Physics.newState(), idle = 0 }
	Karts.byOwner[p] = k
	Model.doorPrompt(k)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText, prompt.HoldDuration, prompt.MaxActivationDistance = "Drive", "Your kart", 0.2, C.Garage.InteractionRange
	prompt.RequiresLineOfSight, prompt.Parent = false, seat
	prompt.Triggered:Connect(function(player) Karts.enter(player, k) end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not seat.Occupant and m:GetAttribute("Driver") then Karts.exit(k) end
	end)
	return k
end
function Karts.enter(p, k)
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if k.owner ~= p or not hum or hum.Health <= 0 or not root or (root.Position - k.seat.Position).Magnitude > C.Garage.InteractionRange then return false end
	k.root.Anchored = false
	k.state = Physics.newState()
	mass(k, p.Character)
	k.seat:Sit(hum)
	k.model:SetAttribute("Driver", p.UserId)
	p:SetAttribute("BC_Driving", true)
	S.Weapons.setHolstered(p, true)
	if C.Kart.ServerPhysics then k.root:SetNetworkOwner(nil) else k.root:SetNetworkOwner(p) end
	return true
end
function Karts.input(p, t, steer, brake)
	local k = Karts.byOwner[p]
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if not C.Kart.ServerPhysics or not k or not hum or hum.SeatPart ~= k.seat then return false end
	k.input, k.inputAt = Physics.cleanInput(t, steer, brake), os.clock()
	return true
end
function Karts.action(p, action)
	return Model.action(Karts.byOwner[p], p, action)
end
function Karts.init(s)
	S = s
	Karts.folder = Instance.new("Folder")
	Karts.folder.Name, Karts.folder.Parent = "GarageKarts", workspace
	S.Remotes.bind(S.remotes, "KartInput", Karts.input)
	S.Remotes.bind(S.remotes, "KartAction", Karts.action)
	Players.PlayerRemoving:Connect(Karts.remove)
	local function player(p)
		p.CharacterRemoving:Connect(function() Karts.remove(p) end)
	end
	Players.PlayerAdded:Connect(player)
	for _, p in ipairs(Players:GetPlayers()) do player(p) end
	RunService.PreSimulation:Connect(function(dt)
		local ignore = { Karts.folder }
		for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ignore, p.Character) end end
		params.FilterDescendantsInstances = ignore
		for _, k in pairs(Karts.byOwner) do
			local root = k.root
			Model.closeMovingDoors(k)
			if not root.Anchored then
				local driver = k.model:GetAttribute("Driver")
				if not driver or C.Kart.ServerPhysics then
					local input = k.input and os.clock() - k.inputAt < C.Kart.InputTimeout and k.input or { t = 0, s = 0, b = true }
					Physics.step(root, k.state, input, dt, C.Kart, params, {})
				end
				if root.Position.Y < C.Garage.ResetBelow then
					if k.seat.Occupant then k.seat.Occupant.Sit = false end
					Karts.exit(k)
					k.model:PivotTo(k.home)
					root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
					root.Anchored = true
					Physics.antiGravity(root, false)
				elseif not driver then
					k.idle = root.AssemblyLinearVelocity.Magnitude < 1 and k.idle + dt or 0
					if k.idle > C.Kart.IdleAnchor then
						root.Anchored = true
						Physics.antiGravity(root, false)
					end
				end
			end
		end
	end)
end
return Karts
