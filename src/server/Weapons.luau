-- Server-authoritative hitscan. The client sends only aim (seq, origin, direction, ads flag).
-- The server checks: arg types/finite, alive, gun equipped + drawn, seq monotonic, reload/ammo,
-- fire rate (token bucket + min gap), origin near the head, then applies deterministic spread,
-- raycasts within the gun's range, and requires a clear line from the head to each hit.
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local GunStats = require(shared.GunStats)
local GunModel = require(shared.GunModel)
local Spread = require(shared.Spread)
local Targets = require(script.Parent.Targets)
local F = Config.Fire

local Weapons = { states = {}, clock = os.clock }
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

-- Player characters never block or take shots (no PvP; teammates don't body-block).
local function refreshFilter()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	params.FilterDescendantsInstances = list
end

local function finiteV(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

function Weapons.state(player)
	local st = Weapons.states[player]
	if not st then
		local now = Weapons.clock()
		st = { slot = 1, gunId = nil, stats = nil, ammo = {}, reloadEnd = 0, drawnAt = 0, allowance = F.Bunch,
			allowAt = now, lastShot = -math.huge, lastSeq = 0, ads = false,
			loan = Config.Range.LoanAllGuns and table.clone(Config.Range.DefaultLoan) or {} }
		Weapons.states[player] = st
	end
	return st
end

-- Effective gun id in a slot: range loan overrides the profile loadout.
function Weapons.gunInSlot(player, slot)
	local st = Weapons.state(player)
	if st.loan[slot] then
		return st.loan[slot]
	end
	local d = Weapons.profiles and Weapons.profiles.loaded[player]
	return d and d.guns.loadout[slot] or ""
end

function Weapons.loadout(player)
	return { Weapons.gunInSlot(player, 1), Weapons.gunInSlot(player, 2), Weapons.gunInSlot(player, 3) }
end

local function settle(st, now)
	if st.reloadEnd > 0 and now >= st.reloadEnd - F.Grace then
		st.ammo[st.gunId] = st.stats.mag
		st.reloadEnd = 0
	end
end

local function attachWorldGun(player, gunId)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local old = char:FindFirstChild("BCWorldGun")
	if old then
		old:Destroy()
	end
	local gun = Config.GunsById[gunId]
	if not gun then
		return
	end
	local m = GunModel.build(gun)
	m.Name = "BCWorldGun"
	local w = Instance.new("Weld")
	w.Part0 = root
	w.Part1 = m.PrimaryPart
	w.C0 = CFrame.new(0.75, 0.35, -1.0) -- placeholder hip-hold pose (no third-person aim animation yet)
	w.Parent = m.PrimaryPart
	m.Parent = char
end

function Weapons.equip(player, slot)
	if type(slot) ~= "number" or slot % 1 ~= 0 then
		return false, "badArgs"
	end
	local def = Config.Wheel.Slots[slot]
	if not def then
		return false, "invalid"
	end
	if not def.usable then
		return false, "comingSoon"
	end
	local gunId = Weapons.gunInSlot(player, slot)
	if gunId == "" or not Config.GunsById[gunId] then
		return false, "empty"
	end
	local st = Weapons.state(player)
	local d = Weapons.profiles and Weapons.profiles.loaded[player]
	local equipped = d and d.guns.owned[gunId] and d.attachments.equipped[gunId] or nil
	st.slot, st.gunId = slot, gunId
	st.stats = GunStats.resolve(gunId, equipped)
	if st.ammo[gunId] == nil or st.ammo[gunId] > st.stats.mag then
		st.ammo[gunId] = st.stats.mag
	end
	st.reloadEnd = 0
	st.drawnAt = Weapons.clock() + F.DrawTime
	Weapons.setAds(player, false)
	attachWorldGun(player, gunId)
	return true
end

function Weapons.loan(player, gunId)
	if not Config.Range.LoanAllGuns or type(gunId) ~= "string" or not Config.GunsById[gunId] then
		return false, "noLoan"
	end
	local st = Weapons.state(player)
	st.loan[st.slot] = gunId
	return Weapons.equip(player, st.slot)
end

function Weapons.reload(player)
	local st = Weapons.states[player]
	if not st or not st.stats then
		return false, "noGun"
	end
	local now = Weapons.clock()
	settle(st, now)
	if st.reloadEnd > 0 then
		return false, "reloading"
	end
	if st.ammo[st.gunId] >= st.stats.mag then
		return false, "full"
	end
	st.reloadEnd = now + st.stats.reload
	return true
end

function Weapons.setAds(player, on)
	local st = Weapons.state(player)
	st.ads = on == true
	Weapons.applySpeed(player)
end

-- One writer for WalkSpeed: base (heist: walk/sneak/heavy/downed via Weapons.baseSpeed) x ADS slow.
function Weapons.applySpeed(player)
	local st = Weapons.state(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local base = Weapons.baseSpeed and Weapons.baseSpeed(player) or Config.Movement.WalkSpeed
		hum.WalkSpeed = base * ((st.ads and st.stats) and st.stats.adsSpeedMult or 1)
	end
end

-- No wall between the shooter's head and the hit point (stops origin-spoofing around corners).
function Weapons.clearLine(from, to, model)
	local delta = to - from
	local dist = delta.Magnitude
	if dist < 0.1 then
		return true
	end
	local res = workspace:Raycast(from, delta.Unit * (dist - 0.05), params)
	return res == nil or res.Instance:IsDescendantOf(model)
end

-- Returns ok, reason, hits, endPoint. hits = { {p = Vector3, d = damage, h = headshot, k = killed} }
function Weapons.fire(player, seq, origin, dir, ads)
	if type(seq) ~= "number" or seq ~= seq or seq % 1 ~= 0 then
		return false, "badArgs"
	end
	if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or not finiteV(origin) or not finiteV(dir) then
		return false, "badArgs"
	end
	local mag = dir.Magnitude
	if mag < 0.5 or mag > 2 then
		return false, "badArgs"
	end
	ads = ads == true
	local st = Weapons.states[player]
	if not st or not st.stats then
		return false, "noGun"
	end
	if st.holstered then
		return false, "holstered" -- heavy loot, downed or driving
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	if not hum or hum.Health <= 0 or not head then
		return false, "dead"
	end
	if seq <= st.lastSeq or seq > st.lastSeq + F.MaxSeqJump then
		return false, "seq"
	end
	local now = Weapons.clock()
	if now < st.drawnAt - F.Grace then
		return false, "drawing"
	end
	settle(st, now)
	if st.reloadEnd > 0 then
		return false, "reloading"
	end
	local ammo = st.ammo[st.gunId]
	if ammo <= 0 then
		return false, "empty"
	end
	local s = st.stats
	st.allowance = math.min(F.Bunch, st.allowance + (now - st.allowAt) / s.interval)
	st.allowAt = now
	if st.allowance < 1 or now - st.lastShot < s.interval * F.MinGap then
		return false, "rate"
	end
	if (origin - head.Position).Magnitude > F.OriginTolerance then
		return false, "origin"
	end
	st.allowance -= 1
	st.lastShot = now
	st.lastSeq = seq
	st.ammo[st.gunId] = ammo - 1

	local hits, byModel = {}, {}
	local cone = GunStats.cone(s, ads)
	local endPoint = origin + dir.Unit * s.range
	for i = 1, s.pellets do
		local d = Spread.direction(dir, cone, Spread.seed(player.UserId, seq, i))
		local res = workspace:Raycast(origin, d * s.range, params)
		if i == 1 then
			endPoint = res and res.Position or origin + d * s.range
		end
		if res then
			local model = Targets.fromPart(res.Instance)
			if model and not model:GetAttribute("Down") and Weapons.clearLine(head.Position, res.Position, model) then
				local isHead = res.Instance.Name == "Head"
				local dmg = GunStats.damageAt(s, (res.Position - origin).Magnitude, isHead)
				local h = byModel[model]
				if not h then
					h = { p = res.Position, d = 0, h = false, k = false, model = model }
					byModel[model] = h
					table.insert(hits, h)
				end
				h.d += dmg
				h.h = h.h or isHead
			end
		end
	end
	for _, h in ipairs(hits) do
		local dealt, killed = Targets.damage(h.model, h.d)
		h.d = math.floor(dealt + 0.5)
		h.k = killed
		h.model = nil
	end
	return true, nil, hits, endPoint
end

function Weapons.stateMessage(player, reason)
	local st = Weapons.state(player)
	return { slot = st.slot, gun = st.gunId or "", ammo = st.gunId and st.ammo[st.gunId] or 0,
		reloading = st.reloadEnd > 0, loadout = Weapons.loadout(player), reason = reason, holstered = st.holstered == true }
end

-- Heavy loot / downed / driving holster the gun (§5b). Pushed to the client, enforced in fire().
function Weapons.setHolstered(player, on)
	local st = Weapons.state(player)
	on = on == true
	if (st.holstered == true) ~= on then
		st.holstered = on
		if on then
			Weapons.setAds(player, false)
		end
		if Weapons.push then
			Weapons.push(player)
		end
	end
end

function Weapons.init(S)
	Weapons.profiles = S.profiles
	local remotes, Remotes = S.remotes, S.Remotes
	local function onChar(player)
		player.CharacterAdded:Connect(function()
			refreshFilter()
			task.defer(function()
				local st = Weapons.states[player]
				if st and st.gunId then
					st.reloadEnd = 0
					attachWorldGun(player, st.gunId)
					Weapons.setAds(player, false)
				end
			end)
		end)
		player.CharacterRemoving:Connect(function()
			task.defer(refreshFilter)
		end)
	end
	Players.PlayerAdded:Connect(onChar)
	for _, p in ipairs(Players:GetPlayers()) do
		onChar(p)
	end
	refreshFilter()
	Players.PlayerRemoving:Connect(function(p)
		Weapons.states[p] = nil
		task.defer(refreshFilter)
	end)

	local function push(player, reason)
		remotes.State:FireClient(player, Weapons.stateMessage(player, reason))
	end
	Weapons.push = push
	Remotes.bind(remotes, "Fire", function(player, seq, origin, dir, ads)
		local ok, reason, hits, endPoint = Weapons.fire(player, seq, origin, dir, ads)
		if ok and Weapons.onFired then
			Weapons.onFired(player, origin) -- heist: noise + alarm (§5h, §5b)
		end
		if ok then
			if #hits > 0 then
				remotes.Hit:FireClient(player, seq, hits)
			end
			for _, other in ipairs(Players:GetPlayers()) do
				local c = other ~= player and other.Character
				if c and c.PrimaryPart and (c.PrimaryPart.Position - origin).Magnitude < F.FxRadius then
					remotes.FX:FireClient(other, player, Weapons.states[player].gunId, origin, endPoint)
				end
			end
		elseif reason == "empty" or reason == "reloading" or reason == "noGun" or reason == "drawing" then
			local st = Weapons.state(player)
			local now = os.clock()
			if now - (st.lastCorrection or 0) > 0.5 then
				st.lastCorrection = now
				push(player, reason)
			end
		end
	end)
	Remotes.bind(remotes, "Reload", function(player)
		Weapons.reload(player)
	end)
	Remotes.bind(remotes, "Aim", function(player, on)
		if Weapons.states[player] and Weapons.states[player].stats then
			Weapons.setAds(player, on == true)
		end
	end)
	Remotes.bind(remotes, "Equip", function(player, slot)
		local ok, reason = Weapons.equip(player, slot)
		push(player, not ok and reason or nil)
	end)
	Remotes.bind(remotes, "RangeEquip", function(player, gunId)
		local ok, reason = Weapons.loan(player, gunId)
		push(player, not ok and reason or nil)
	end)
end

return Weapons
