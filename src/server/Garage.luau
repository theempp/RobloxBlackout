-- 3A onboarding, personal armory and locker. All interaction progress is verified on the server: every
-- station request uses the requesting player's own profile, whitelists ids against Config, checks
-- ownership, compatibility and interaction range (Remotes rate-limits it). A request may carry a number id;
-- the server answers GarageEvent("ack", id, ok, reason) so the client confirms or restores the saved setup.
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage").BlackoutCrew
local C = require(shared.Config)
local Rules = require(shared.Rules)
local Map = require(shared.GarageMap)
local Track = require(shared.TrackKit)
local Crews = require(shared.Crews)
local Karts = require(script.Parent.GarageKarts)
local Garage = { tutorials = {} }
local S
local function aliveRoot(p)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	return root and hum and hum.Health > 0 and root or nil
end
local function near(p, point)
	local root = aliveRoot(p)
	return root ~= nil and (root.Position - point).Magnitude <= C.Garage.InteractionRange
end
local function nearArmory(p)
	local root = aliveRoot(p)
	return root ~= nil and Map.armoryNear(root.Position, C.Garage.InteractionRange)
end
local function stage(p, value)
	p:SetAttribute("BC_Tutorial", value)
end
local function prompt(part, action, callback, object)
	local p = Instance.new("ProximityPrompt")
	p.ActionText, p.ObjectText, p.MaxActivationDistance = action, object or part.Name, C.Garage.InteractionRange
	p.RequiresLineOfSight, p.HoldDuration, p.Parent = false, 0.2, part
	p.Triggered:Connect(callback)
end
-- Saved loadout/attachments changed: redraw from the profile (never a range loan) and resend state.
local function rearm(p, slot)
	S.Weapons.state(p).loan = {}
	S.Weapons.equip(p, slot or S.Weapons.state(p).slot)
	S.Weapons.push(p)
	S.pushProfile(p)
end
function Garage.finish(p)
	local d = S.profiles.loaded[p]
	if not d then return false end
	d.tutorial.done = true
	Garage.tutorials[p] = nil
	stage(p, "done")
	S.pushProfile(p)
	return true
end
-- Returns ok, reason ("noProfile" | "invalid" | "far" | "locked" | "incompatible" | "comingSoon" | "lastGun").
function Garage.action(p, action, a, b)
	local d = S.profiles.loaded[p]
	if not d then return false, "noProfile" end
	if type(action) ~= "string" then return false, "invalid" end
	local st = p:GetAttribute("BC_Tutorial")
	if action == "skip" then return Garage.finish(p) end
	if action == "gun" then
		local panel = type(a) == "string" and Map.guns[a]
		if not panel then return false, "invalid" end
		if not near(p, panel.Position) then return false, "far" end
		if not d.guns.owned[a] then S.notify(p, "Gun purchases unlock with the economy update."); return false, "locked" end
		for i = 2, 3 do if d.guns.loadout[i] == a then d.guns.loadout[i] = "" end end
		d.guns.loadout[1] = a
		rearm(p, 1)
		if st == "gun" then stage(p, "friend") end
		return true
	elseif action == "talk" and st == "friend" and near(p, Map.point(C.Garage.Friend)) then
		stage(p, "invite")
		return true
	elseif action == "invite" and st == "invite" and near(p, Map.point(C.Garage.Friend)) then
		-- Per-player scripted friend: uses the real invite/accept rules, never enters the teleport roster.
		local crews, npc = Crews.new(C.Crew.MaxSize, C.Crew.InviteTtl), {}
		crews:invite(npc, p, os.clock())
		if not crews:accept(p, os.clock()) then return false end
		Garage.tutorials[p] = { crews = crews, npc = npc }
		stage(p, "kart")
		Karts.spawn(p)
		return true
	elseif action == "kart" and near(p, Map.point(C.Garage.KartBay)) then
		Karts.spawn(p)
		return true
	elseif action == "equip" then -- owned gun a into loadout slot b; if a sits in another slot the two swap
		if not nearArmory(p) then return false, "far" end
		local def = type(b) == "number" and C.Wheel.Slots[b]
		if not def then return false, "invalid" end
		if not def.usable then return false, "comingSoon" end
		if type(a) ~= "string" or not C.GunsById[a] then return false, "invalid" end
		if not d.guns.owned[a] then return false, "locked" end
		local from = table.find(d.guns.loadout, a)
		if from then d.guns.loadout[from] = d.guns.loadout[b] end
		d.guns.loadout[b] = a
		rearm(p, b)
		return true
	elseif action == "clear" then -- empty loadout slot a; at least one blaster always stays equipped
		if not nearArmory(p) then return false, "far" end
		local def = type(a) == "number" and C.Wheel.Slots[a]
		if not def or not def.usable then return false, "invalid" end
		if d.guns.loadout[a] == "" then return true end
		local left
		for i = 1, 3 do if i ~= a and d.guns.loadout[i] ~= "" then left = left or i end end
		if not left then return false, "lastGun" end
		d.guns.loadout[a] = ""
		rearm(p, S.Weapons.state(p).slot == a and left or nil)
		return true
	elseif action == "attach" then -- toggle one owned attachment on gun b
		local att = type(a) == "string" and C.AttachmentsById[a]
		local gun = type(b) == "string" and C.GunsById[b]
		if not att or not gun then return false, "invalid" end
		if not nearArmory(p) then return false, "far" end
		if not d.attachments.owned[a] or not d.guns.owned[b] then return false, "locked" end
		if not table.find(gun.slots, att.slot) then return false, "incompatible" end
		local equipped = d.attachments.equipped[b] or {}
		if equipped[att.slot] == a then equipped[att.slot] = nil else equipped[att.slot] = a end
		d.attachments.equipped[b] = equipped
		rearm(p)
		return true
	elseif action == "setAttachments" then -- full replacement for gun a: b = { slot = attachmentId }, all-or-nothing
		if type(a) ~= "string" or not C.GunsById[a] then return false, "invalid" end
		if not nearArmory(p) then return false, "far" end
		if not d.guns.owned[a] then return false, "locked" end
		local clean, why = Rules.attachmentProposal(a, b, d.attachments.owned)
		if not clean then return false, why end
		d.attachments.equipped[a] = clean
		rearm(p)
		return true
	elseif action == "cosmetics" then -- full replacement: a = { outfit = id, disguise = id, mask = id }
		if not near(p, Map.locker.Position) then return false, "far" end
		local clean, why = Rules.cosmeticProposal(a, d.cosmetics.owned)
		if not clean then return false, why end
		d.cosmetics.equipped = clean
		S.Appearance.refresh(p)
		S.pushProfile(p)
		return true
	end
	return false, "invalid"
end
function Garage.init(s)
	S = s
	Map.build()
	Karts.init(S)
	S.GarageKarts = Karts
	for id, panel in pairs(Map.guns) do prompt(panel, "Equip " .. C.GunsById[id].name, function(p) Garage.action(p, "gun", id) end) end
	prompt(Map.bench, "Attachments", function(p) if near(p, Map.bench.Position) then S.remotes.GarageEvent:FireClient(p, "bench") end end)
	prompt(Map.terminal, "Set loadout", function(p) if near(p, Map.terminal.Position) then S.remotes.GarageEvent:FireClient(p, "loadout") end end)
	prompt(Map.locker, "Open locker", function(p) if near(p, Map.locker.Position) then S.remotes.GarageEvent:FireClient(p, "locker") end end, "Locker")
	local friend = Track.block(Map.model, "Guide", Vector3.new(2, 4, 1.5), Map.frame(C.Garage.Friend + Vector3.new(0, 2, 0)), Color3.fromRGB(190, 186, 174))
	Track.block(Map.model, "GuideHead", Vector3.new(1.5, 1.5, 1.5), friend.CFrame * CFrame.new(0, 2.75, 0), Color3.fromRGB(90, 91, 99))
	prompt(friend, "Talk / Join squad", function(p)
		Garage.action(p, p:GetAttribute("BC_Tutorial") == "invite" and "invite" or "talk")
	end)
	local bay = Track.block(Map.model, "KartBay", Vector3.new(3, 1, 3), Map.frame(C.Garage.KartBay + Vector3.new(-5, 0.5, 0)), C.Colors.Accent)
	prompt(bay, "Get your kart", function(p) Garage.action(p, "kart") end)
	S.Remotes.bind(S.remotes, "GarageAction", function(p, action, a, b, req)
		local ok, why = Garage.action(p, action, a, b)
		if type(req) == "number" and req == req and req % 1 == 0 then
			S.remotes.GarageEvent:FireClient(p, "ack", req, ok == true, (not ok) and (why or "invalid") or nil)
		end
	end)
	table.insert(S.onJoin, function(p)
		local d = S.profiles.loaded[p]
		stage(p, d.tutorial.done and "done" or "gun")
		p:GetAttributeChangedSignal("BC_Driving"):Connect(function()
			if p:GetAttribute("BC_Tutorial") == "kart" and p:GetAttribute("BC_Driving") then stage(p, "queue") end
		end)
	end)
	Players.PlayerRemoving:Connect(function(p) Garage.tutorials[p] = nil end)
end
return Garage
