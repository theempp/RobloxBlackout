-- First-person blaster (no arms): the locked v2 meshes (GunModel.buildFirstPerson, built async per equip) or the
-- primitive model for guns without art. ADS puts the gun's own Sight point on the screen centre (FrontSight on the
-- same line), so irons/optics line up per gun. Motion: draw, walk bob, look sway, per-gun recoil spring (kick back,
-- rise, roll), slide / bolt / mag animation, reload tilt. Scope guns (fp.scope) hide the model once ADS passes
-- Config.ViewModel.ScopeShowAt and the Hud draws the full-view reticle instead. All tuning: Config.ViewModel + Guns[i].fp.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ViewModel = { status = nil }
local ctx, C, VM, GunModel
local camera = workspace.CurrentCamera
local model, root, muzzle, flash, gun, fp
local groups = {} -- name -> { weld, base }
local parts = {} -- every BasePart (for hiding)
local sight, buildToken = Vector3.zero, nil
local adsAlpha, adsTarget, adsTime = 0, 0, 0.15
local drawT = 1
local kb, kbv, kr, krv, kz, kzv = 0, 0, 0, 0, 0, 0 -- kick: back (studs), rise (deg), roll (deg) + velocities
local cycleT, cycleDur, empty = math.huge, 0, false
local reloadT, reloadDur = math.huge, 0
local flashT, rollSign = 0, 1
local lastLook = Vector3.zero
local sway = Vector2.zero
local bobPhase = 0
local hidden = false

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function setVisible(on)
	hidden = not on
	for _, p in ipairs(parts) do
		p.LocalTransparencyModifier = on and 0 or 1
	end
	for _, d in ipairs(model and model:GetDescendants() or {}) do
		if d:IsA("SurfaceGui") then
			d.Enabled = on
		end
	end
end

local function attach(m, g)
	model = m
	root = m.PrimaryPart
	root.Anchored = true
	muzzle = root:FindFirstChild("Muzzle")
	local s = root:FindFirstChild("Sight")
	sight = s and s.Position or Vector3.new(0, (g.muzzle.Y or 0.1) + 0.2, 0)
	table.clear(groups)
	table.clear(parts)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			local w = d:FindFirstChildOfClass("Weld")
			local grp = d:GetAttribute("Group")
			if w and (grp == "Mover" or grp == "Mag") then
				groups[d] = { weld = w, base = w.C0, group = grp }
			end
		end
	end
	flash = Instance.new("Part")
	flash.Name = "Flash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.16, 0.16, 0.16)
	flash.Material = Enum.Material.SmoothPlastic
	flash.Color = C.Colors.Puff
	flash.Transparency = 1
	flash.CanCollide, flash.CanQuery, flash.CanTouch, flash.CastShadow, flash.Massless = false, false, false, false, true
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = root, flash, CFrame.new(g.muzzle - Vector3.new(0, 0, 0.12))
	w.Parent = flash
	flash.Parent = m
	setVisible(true)
	m.Parent = (ctx.holstered or ctx.driving) and nil or camera
end

-- Equip: drop the old model first (frees the device's mesh budget), then build the new one off the input path.
function ViewModel.set(gunId)
	buildToken = {}
	local token = buildToken
	if model then
		model:Destroy()
		model, root, muzzle, flash = nil, nil, nil, nil
	end
	table.clear(groups)
	table.clear(parts)
	gun = C.GunsById[gunId]
	if not gun then
		return
	end
	fp = gun.fp or {}
	drawT, cycleT, reloadT, empty = 0, math.huge, math.huge, false
	kb, kbv, kr, krv, kz, kzv = 0, 0, 0, 0, 0, 0
	local g = gun
	task.spawn(function()
		local m, kind = GunModel.buildFirstPerson(g)
		if buildToken ~= token then
			m:Destroy()
			return
		end
		ViewModel.status = kind
		attach(m, g)
	end)
end

function ViewModel.setAds(on, time)
	adsTarget = on and 1 or 0
	adsTime = math.max(time or 0.15, 0.01)
end

-- Instant reset (swap / death / menu / holster): no lingering zoom or scope.
function ViewModel.snapAds()
	adsTarget, adsAlpha = 0, 0
	if hidden and model then
		setVisible(true)
	end
end

function ViewModel.adsProgress()
	return adsAlpha
end

function ViewModel.scoped()
	return fp ~= nil and fp.scope == true and adsAlpha >= VM.ScopeShowAt
end

function ViewModel.kick(visual)
	local k = (fp and fp.kick) or VM.Kick
	local adsDamp = 1 - 0.45 * adsAlpha
	local v = visual or 1
	kbv += k.back * 40 * v * adsDamp
	krv += k.rise * 40 * adsDamp
	rollSign = -rollSign
	kzv += k.roll * 40 * rollSign * adsDamp
end

-- Mover after a shot: slide (pistol) or bolt cycle (bolt-action).
function ViewModel.cycle()
	local m = fp and fp.mover
	if m then
		cycleT, cycleDur = -(m.delay or 0), m.time
	end
end

function ViewModel.setEmpty(on)
	empty = on == true
end

function ViewModel.reload(duration)
	reloadT, reloadDur = 0, math.max(duration or 1, 0.2)
end

function ViewModel.cancelReload()
	reloadT = math.huge
end

function ViewModel.flash()
	flashT = 0.05
end

function ViewModel.rootPart()
	return root
end

function ViewModel.model()
	return model
end

-- Camera-space offset of the grip origin when fully aimed: Sight point on the view axis, eye relief in front.
function ViewModel.adsOffset()
	return Vector3.new(-sight.X, -sight.Y, -(fp and fp.eye or VM.Eye) - sight.Z)
end

-- World position of the muzzle (tracer start); falls back to just below the camera.
function ViewModel.muzzle()
	if muzzle and model and model.Parent then
		return muzzle.WorldPosition
	end
	return camera.CFrame * Vector3.new(0.5, -0.5, -2)
end

local function moverOffset(info)
	local m = fp.mover
	if info.group == "Mag" then
		if reloadT >= reloadDur then
			return CFrame.identity, false
		end
		local t = reloadT / reloadDur
		local out = t < 0.2 and 0 or t < 0.38 and smooth((t - 0.2) / 0.18) or t < 0.62 and 1 or t < 0.82 and 1 - smooth((t - 0.62) / 0.2) or 0
		return CFrame.new(0, -VM.Reload.magDrop * out, 0.08 * out), out > 0.97
	end
	if not m then
		return CFrame.identity, false
	end
	if m.kind == "slide" then
		local s = 0
		if empty then
			s = 1
		elseif cycleT < m.time * 2 then
			s = cycleT < m.time and smooth(cycleT / m.time) or 1 - smooth((cycleT - m.time) / m.time)
		end
		return CFrame.new(0, 0, m.travel * s), false
	elseif m.kind == "bolt" then
		local t = cycleT / m.time
		if t < 0 or t >= 1 then
			return CFrame.identity, false
		end
		local lift = t < 0.22 and smooth(t / 0.22) or t < 0.78 and 1 or 1 - smooth((t - 0.78) / 0.22)
		local pull = (t < 0.22 or t >= 0.78) and 0 or t < 0.5 and smooth((t - 0.22) / 0.28) or 1 - smooth((t - 0.5) / 0.28)
		local p = root:FindFirstChild("Mover") and root.Mover.Position or Vector3.zero
		return CFrame.new(0, 0, m.travel * pull) * CFrame.new(p) * CFrame.Angles(0, 0, math.rad(m.lift * lift)) * CFrame.new(-p), false
	end
	return CFrame.identity, false
end

function ViewModel.init(c)
	ctx = c
	C = ctx.Config
	VM = C.ViewModel
	GunModel = require(ctx.shared.GunModel)
	ctx.on("holster", function(on)
		if model then
			model.Parent = (on or ctx.driving) and nil or camera
		end
	end)
	RunService:BindToRenderStep("BCViewModel", Enum.RenderPriority.Camera.Value + 2, function(dt)
		dt = math.min(dt, 0.1)
		local step = dt / adsTime
		adsAlpha = adsTarget > adsAlpha and math.min(adsTarget, adsAlpha + step) or math.max(adsTarget, adsAlpha - step)
		if not root or not model.Parent then
			return
		end
		local motion = ctx.settings.reducedMotion and 0 or 1
		local k = (fp and fp.kick) or VM.Kick
		-- recoil springs (critically-damped-ish; per-gun stiffness/damping = weight of the gun)
		kbv += (-kb * k.spring - kbv * k.damp) * dt
		kb += kbv * dt
		krv += (-kr * k.spring - krv * k.damp) * dt
		kr += krv * dt
		kzv += (-kz * k.spring - kzv * k.damp) * dt
		kz += kzv * dt
		drawT = math.min(1, drawT + dt / math.max(C.Fire.DrawTime, 0.05))
		cycleT += dt
		if reloadT < reloadDur then
			reloadT += dt
		end
		if flashT > 0 then
			flashT -= dt
			flash.Transparency = flashT > 0 and 0.45 or 1
		end
		-- look sway + walk bob (hip only; reduced in ADS; off with reduced motion)
		local look = camera.CFrame.LookVector
		local d = camera.CFrame:VectorToObjectSpace(look - lastLook)
		lastLook = look
		sway = sway:Lerp(Vector2.new(-d.X, d.Y) * VM.Sway.look * motion, math.min(1, dt * 10))
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local speed = hrp and Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude or 0
		local moving = math.clamp(speed / C.Movement.WalkSpeed, 0, 1.2)
		bobPhase += dt * VM.Bob.rate * 2 * math.pi * moving
		local a = smooth(adsAlpha)
		local bobAmp = VM.Bob.amp * (fp.bob or 1) * moving * motion * (1 - a * (1 - VM.Bob.adsMult))
		local bob = Vector3.new(math.sin(bobPhase) * bobAmp, -math.abs(math.cos(bobPhase)) * bobAmp, 0)
		local swayK = 1 - a * (1 - VM.Sway.ads)
		-- base pose: hip -> sight-aligned ADS
		local hip = fp.hip or VM.Hip
		local pose = CFrame.new(hip:Lerp(ViewModel.adsOffset(), a))
		local dr = 1 - smooth(drawT)
		if dr > 0 then
			pose *= CFrame.new(0, -VM.Draw.drop * dr * motion, 0) * CFrame.Angles(math.rad(-VM.Draw.tilt * dr * motion), 0, math.rad(12 * dr * motion))
		end
		if reloadT < reloadDur then
			local t = reloadT / reloadDur
			local e = math.sin(math.pi * math.clamp(t, 0, 1)) * motion
			pose *= CFrame.new(0, -VM.Reload.dip * e, 0) * CFrame.Angles(math.rad(VM.Reload.tilt * e), 0, math.rad(VM.Reload.roll * e))
		end
		root.CFrame = camera.CFrame * pose * CFrame.new(bob + Vector3.new(sway.X * swayK, sway.Y * swayK, kb))
			* CFrame.Angles(math.rad(kr), 0, math.rad(kz * motion))
		for _, info in pairs(groups) do
			local off, hideMag = moverOffset(info)
			info.weld.C0 = off * info.base
			if info.group == "Mag" then
				info.weld.Part1.LocalTransparencyModifier = (hideMag or hidden) and 1 or 0
			end
		end
		-- scope guns: the model would block the sight picture -> hidden once the reticle takes over
		local scoped = ViewModel.scoped()
		if scoped ~= hidden then
			setVisible(not scoped)
		end
	end)
end

return ViewModel
