-- Per-player heist state on the server: movement speed (walk / sneak / heavy / downed), gun holster,
-- sneak toggle, noise radius (§5h). State lives in Player attributes so every client's HUD and the
-- shared action rules read the same thing: BC_Slot, BC_Sneak, BC_Heavy, BC_Downed, BC_Driving.
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local Carry = require(shared.Carry)
local MV = Config.Movement

local Crew = { gunfireAt = {} }
local S

function Crew.state(player)
	return {
		heavy = player:GetAttribute("BC_Heavy") ~= nil,
		sneak = player:GetAttribute("BC_Sneak") == true,
		downed = player:GetAttribute("BC_Downed") == true,
		driving = player:GetAttribute("BC_Driving") == true,
	}
end

function Crew.refresh(player)
	local st = Crew.state(player)
	S.Weapons.setHolstered(player, Carry.holstered(st))
	S.Weapons.applySpeed(player)
end

-- Current noise radius: recent gunfire 60, else sneak 6 / walk 15 while moving, still 0.
function Crew.noise(player, now)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0
	end
	local v = root.AssemblyLinearVelocity
	local st = Crew.state(player)
	st.moving = Vector2.new(v.X, v.Z).Magnitude > MV.MovingSpeed
	st.gunfire = now - (Crew.gunfireAt[player] or -math.huge) < MV.GunfireNoiseTime
	return Carry.noise(st, MV)
end

function Crew.init(s)
	S = s
	S.crew = Crew
	S.Weapons.baseSpeed = function(player)
		return Carry.walkSpeed(Crew.state(player), MV)
	end
	S.Remotes.bind(S.remotes, "Sneak", function(player, on)
		player:SetAttribute("BC_Sneak", on == true)
		Crew.refresh(player)
	end)
	local function hook(player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Humanoid")
			Crew.refresh(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
end

local ATTRS = { "BC_Sneak", "BC_Heavy", "BC_Downed", "BC_Driving", "BC_Small", "BC_Loaded", "BC_Override", "BC_HP", "BC_BleedEnd", "BC_Recall", "BC_Step" }

function Crew.start(_, run)
	for _, p in ipairs(run.players) do
		for _, a in ipairs(ATTRS) do
			p:SetAttribute(a, nil)
		end
		Crew.refresh(p)
	end
end

function Crew.reset()
	for _, p in ipairs(Players:GetPlayers()) do
		for _, a in ipairs(ATTRS) do
			p:SetAttribute(a, nil)
		end
		p:SetAttribute("BC_Slot", nil)
		Crew.refresh(p)
	end
end

return Crew
