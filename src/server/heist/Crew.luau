-- Per-player heist state on the server: movement speed (walk / sneak / heavy / downed), gun holster,
-- sneak toggle, noise radius (§5h). State lives in Player attributes so every client's HUD and the
-- shared action rules read the same thing: BC_Slot, BC_Sneak, BC_Heavy, BC_Downed, BC_Driving.
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local Carry = require(shared.Carry)
local MV = Config.Movement
local D = Config.Downed

local Crew = { gunfireAt = {}, lastHit = {}, hp = {} } -- hp: float per player; BC_HP shows it rounded up

local function setHp(player, hp)
	Crew.hp[player] = hp
	local shown = math.ceil(hp)
	if player:GetAttribute("BC_HP") ~= shown then
		player:SetAttribute("BC_HP", shown)
	end
end
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

-- Health + downed (§5c). HP lives in BC_HP (integer). Enemies/lasers call damage(); at 0 -> downed:
-- crawl, holstered, bleed-out timer (BC_BleedEnd, server time), medium alarm bump.
function Crew.damage(player, amount, source)
	local run = S.Heist.run
	if not run or run.ended or not player:GetAttribute("BC_Slot") or player:GetAttribute("BC_Downed") or player:GetAttribute("BC_Recall") then
		return
	end
	Crew.lastHit[player] = os.clock()
	local hp = (Crew.hp[player] or D.MaxHP) - amount
	if hp <= 0 then
		Crew.down(player, source)
	else
		setHp(player, hp)
	end
end

function Crew.down(player)
	setHp(player, 0)
	player:SetAttribute("BC_Downed", true)
	player:SetAttribute("BC_BleedEnd", workspace:GetServerTimeNow() + D.BleedOut)
	if S.interact then
		S.interact.holds[player] = nil
	end
	Crew.refresh(player)
	if S.alarm then
		S.alarm.bump("downed")
	end
end

function Crew.revive(player)
	player:SetAttribute("BC_Downed", nil)
	player:SetAttribute("BC_BleedEnd", nil)
	setHp(player, D.ReviveHP)
	Crew.lastHit[player] = os.clock()
	Crew.refresh(player)
end

-- Bleed-out -> recalled: drop carried loot, frozen for Recall seconds, then respawn at the tower entrance.
function Crew.recall(run, player)
	player:SetAttribute("BC_Downed", nil)
	player:SetAttribute("BC_BleedEnd", nil)
	player:SetAttribute("BC_Recall", workspace:GetServerTimeNow() + D.Recall)
	S.loot.dropFor(run, player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
	end
	Crew.refresh(player)
end

function Crew.respawn(player)
	player:SetAttribute("BC_Recall", nil)
	player:LoadCharacter()
	local char = player.Character
	if char then
		char:PivotTo(CFrame.new(S.map.towerSpawn.Position + Vector3.new(0, 3.5, 0)))
	end
	setHp(player, D.MaxHP)
	Crew.refresh(player)
end

-- §5c: the run fails only if the whole crew is down at once (downed or recalling) and nobody can Override.
function Crew.wiped(run)
	if #run.players == 0 then
		return false
	end
	for _, p in ipairs(run.players) do
		local downed = p:GetAttribute("BC_Downed") == true
		if not downed and not p:GetAttribute("BC_Recall") then
			return false
		end
		if downed and (p:GetAttribute("BC_Override") or 0) > 0 then
			return false
		end
	end
	return true
end

function Crew.tick(_, run, dt)
	local now, sNow = os.clock(), workspace:GetServerTimeNow()
	for _, p in ipairs(run.players) do
		if p:GetAttribute("BC_Downed") then
			if sNow >= (p:GetAttribute("BC_BleedEnd") or math.huge) then
				Crew.recall(run, p)
			end
		elseif p:GetAttribute("BC_Recall") then
			if sNow >= p:GetAttribute("BC_Recall") then
				Crew.respawn(p)
			end
		else
			local hp = Crew.hp[p] or D.MaxHP
			if hp < D.MaxHP and now - (Crew.lastHit[p] or 0) >= D.RegenDelay then
				setHp(p, math.min(D.MaxHP, hp + D.RegenRate * dt))
			end
		end
	end
	if Crew.wiped(run) then
		S.Heist.fail(S, "crew down")
	end
end

function Crew.init(s)
	S = s
	S.crew = Crew
	S.Weapons.baseSpeed = function(player)
		return Carry.walkSpeed(Crew.state(player), MV)
	end
	S.interact.effects.revive = function(_, _, _, mate)
		Crew.revive(mate)
		return true
	end
	S.interact.effects.override = function(_, _, player)
		local n = player:GetAttribute("BC_Override") or 0
		if n <= 0 then
			return false
		end
		player:SetAttribute("BC_Override", n - 1)
		Crew.revive(player)
		return true
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
		setHp(p, D.MaxHP)
		p:SetAttribute("BC_Override", D.Overrides)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = false
		end
		Crew.refresh(p)
	end
end

function Crew.reset()
	table.clear(Crew.hp)
	for _, p in ipairs(Players:GetPlayers()) do
		for _, a in ipairs(ATTRS) do
			p:SetAttribute(a, nil)
		end
		p:SetAttribute("BC_Slot", nil)
		Crew.refresh(p)
	end
end

return Crew
