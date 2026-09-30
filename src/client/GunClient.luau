-- Client gun logic. Sends only aim (seq, origin, direction, ads) — the server decides hits and damage.
-- Locally predicts tracers + a grey hit marker using the SAME seeded spread as the server; server
-- confirms with Hit (damage numbers, white/yellow/red marker) and corrects ammo/gun via State.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local GunClient = { stats = nil, gunId = nil, ammo = {}, seq = 0, ads = false, confirmedHits = 0, shots = 0 }
local ctx, C, GunStats, Spread, Recoil, WheelLogic
local lp = Players.LocalPlayer
local trigger, consumed = false, false
local nextShot, drawnAt, reloadEnd = 0, 0, 0
local recoil
local wheel
local loadout = { "", "", "" }
local attachments = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function refreshFilter()
	local list = { workspace.CurrentCamera }
	if ctx.Fx and ctx.Fx.folder then
		table.insert(list, ctx.Fx.folder)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	params.FilterDescendantsInstances = list
end

local function targetOf(part)
	local m = part:FindFirstAncestorOfClass("Model")
	while m do
		if CollectionService:HasTag(m, "BC_Target") then
			return m
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function updateAmmo()
	local s = GunClient.stats
	if s then
		ctx.Hud.setAmmo(GunClient.ammo[GunClient.gunId], s.mag, reloadEnd > 0)
	end
end

local function equipLocal(slot, gunId)
	if gunId == "" or not C.GunsById[gunId] then
		return
	end
	local s = GunStats.resolve(gunId, attachments[gunId])
	GunClient.stats, GunClient.gunId, GunClient.slot = s, gunId, slot
	wheel.current = slot
	if GunClient.ammo[gunId] == nil or GunClient.ammo[gunId] > s.mag then
		GunClient.ammo[gunId] = s.mag
	end
	drawnAt = os.clock() + C.Fire.DrawTime
	reloadEnd = 0
	recoil = Recoil.new()
	GunClient.setAds(false)
	ctx.ViewModel.set(gunId)
	ctx.Hud.setGun(s.name)
	ctx.Hud.setReload(nil)
	updateAmmo()
	ctx.emit("equipped", slot, gunId)
end

function GunClient.setAds(on)
	on = on == true
	if on == GunClient.ads then
		return
	end
	GunClient.ads = on
	local s = GunClient.stats
	ctx.remotes.Aim:FireServer(on)
	ctx.netSends += 1
	ctx.CameraRig.setAds(on, s and s.adsFov)
	ctx.ViewModel.setAds(on, s and s.adsTime)
	ctx.Hud.setCrosshair(not on, s and 6 + GunStats.cone(s, false) * 3)
end

function GunClient.reload()
	local s = GunClient.stats
	if not s or reloadEnd > 0 or GunClient.ammo[GunClient.gunId] >= s.mag then
		return
	end
	reloadEnd = os.clock() + s.reload
	ctx.remotes.Reload:FireServer()
	ctx.netSends += 1
	updateAmmo()
end

function GunClient.equip(slot)
	local ok, reason = WheelLogic.select(wheel, slot, loadout)
	if ok then
		ctx.remotes.Equip:FireServer(slot)
		ctx.netSends += 1
		equipLocal(slot, loadout[slot])
	elseif reason == "comingSoon" then
		ctx.Hud.toast("Coming Soon — " .. (C.Wheel.Slots[slot].teaser or ""), 2)
	elseif reason == "empty" then
		ctx.Hud.toast("Empty slot — pick a blaster from the rack", 2)
	end
	return ok, reason
end

function GunClient.swapLast()
	local last = wheel.last
	if last then
		GunClient.equip(last)
	end
end

function GunClient.loadout()
	return loadout
end

-- Called by CameraRig every frame.
function GunClient.onLook(pitchDelta)
	if recoil and pitchDelta ~= 0 then
		Recoil.onLook(recoil, pitchDelta)
	end
end
function GunClient.recoverStep(dt)
	if not recoil or not GunClient.stats then
		return 0
	end
	return Recoil.step(recoil, GunClient.stats, dt, os.clock())
end

local function shoot(now)
	local s = GunClient.stats
	local aim = ctx.CameraRig.aimCF
	if not aim then
		return
	end
	GunClient.seq += 1
	GunClient.shots += 1
	local seq = GunClient.seq
	GunClient.ammo[GunClient.gunId] -= 1
	nextShot = (now - nextShot < s.interval) and nextShot + s.interval or now + s.interval
	local origin, dir = aim.Position, aim.LookVector
	local cone = GunStats.cone(s, GunClient.ads)
	local muzzle = ctx.ViewModel.muzzle()
	local predicted = false
	for i = 1, s.pellets do
		local d = Spread.direction(dir, cone, Spread.seed(lp.UserId, seq, i))
		local res = workspace:Raycast(origin, d * s.range, params)
		local hitPos = res and res.Position or origin + d * s.range
		if i <= 3 then
			ctx.Fx.tracer(muzzle, hitPos, C.GunsById[GunClient.gunId].accent)
		end
		if res then
			local m = targetOf(res.Instance)
			if m and not m:GetAttribute("Down") then
				predicted = true
			end
			if i <= 3 then
				ctx.Fx.impact(res.Position, m and C.Colors.Foam or C.Colors.Muted)
			end
		end
	end
	if predicted then
		ctx.Hud.hitMarker("predict")
	end
	ctx.remotes.Fire:FireServer(seq, origin, dir, GunClient.ads)
	ctx.netSends += 1
	local up, side = Recoil.onShot(recoil, s, now)
	ctx.CameraRig.kick(up, side, s.recoil.visual)
	ctx.ViewModel.kick(s.recoil.visual)
	ctx.ViewModel.flash()
	updateAmmo()
	if GunClient.ammo[GunClient.gunId] <= 0 then
		GunClient.reload() -- auto-reload on empty
	end
end

local function tick()
	local s = GunClient.stats
	if not s then
		return
	end
	local now = os.clock()
	if reloadEnd > 0 then
		if now >= reloadEnd then
			reloadEnd = 0
			GunClient.ammo[GunClient.gunId] = s.mag
			ctx.Hud.setReload(nil)
			updateAmmo()
		else
			ctx.Hud.setReload(1 - (reloadEnd - now) / s.reload)
		end
	end
	if trigger and (s.auto or not consumed) and now >= nextShot and now >= drawnAt and reloadEnd == 0 and not ctx.cursorFree
		and not ctx.holstered then
		if GunClient.ammo[GunClient.gunId] > 0 then
			shoot(now)
			consumed = true
		else
			GunClient.reload()
		end
	end
end

function GunClient.init(c)
	ctx = c
	C = ctx.Config
	GunStats = require(ctx.shared.GunStats)
	Spread = require(ctx.shared.Spread)
	Recoil = require(ctx.shared.Recoil)
	WheelLogic = require(ctx.shared.WheelLogic)
	wheel = WheelLogic.new(1)
	recoil = Recoil.new()

	ctx.on("fire", function(down)
		trigger = down
		if down then
			consumed = false
		end
	end)
	ctx.on("ads", GunClient.setAds)
	ctx.on("adsToggle", function()
		GunClient.setAds(not GunClient.ads)
	end)
	ctx.on("reload", GunClient.reload)
	ctx.on("swapLast", GunClient.swapLast)
	ctx.on("equip", GunClient.equip)
	ctx.on("profile", function(p)
		attachments = type(p.attachments) == "table" and p.attachments.equipped or {}
	end)

	ctx.remotes.State.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" then
			return
		end
		if type(msg.loadout) == "table" then
			loadout = msg.loadout
			ctx.emit("loadout", loadout)
		end
		if (msg.holstered == true) ~= (ctx.holstered == true) then
			ctx.holstered = msg.holstered == true
			if ctx.holstered then
				GunClient.setAds(false)
			end
			ctx.emit("holster", ctx.holstered)
		end
		if msg.gun ~= "" and (msg.gun ~= GunClient.gunId or msg.slot ~= GunClient.slot) then
			equipLocal(msg.slot, msg.gun) -- server switched us (join, range loan)
		end
		if msg.reason == "empty" or msg.reason == "reloading" then
			GunClient.ammo[msg.gun] = msg.ammo -- server ammo is the truth
			updateAmmo()
		elseif msg.reason == "comingSoon" then
			ctx.Hud.toast("Coming Soon", 2)
		end
	end)
	ctx.remotes.Hit.OnClientEvent:Connect(function(_, hits)
		if type(hits) ~= "table" then
			return
		end
		local best = "hit"
		for _, h in ipairs(hits) do
			local kind = h.k and "kill" or h.h and "head" or "hit"
			GunClient.confirmedHits += 1
			ctx.Fx.damage(h.p, h.d, kind)
			if kind == "kill" or (kind == "head" and best == "hit") then
				best = kind
			end
		end
		ctx.Hud.hitMarker(best)
	end)

	lp.CharacterAdded:Connect(function()
		task.defer(refreshFilter)
		GunClient.setAds(false)
	end)
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function()
			task.defer(refreshFilter)
		end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= lp then
			p.CharacterAdded:Connect(function()
				task.defer(refreshFilter)
			end)
		end
	end
	refreshFilter()
	RunService.Heartbeat:Connect(tick)
end

return GunClient
