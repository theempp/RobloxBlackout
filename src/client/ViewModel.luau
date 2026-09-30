-- First-person blaster (placeholder primitives, no arms yet): hip/ADS blend, kickback spring,
-- look sway, muzzle flash. Anchored root + welded parts under the Camera (local only, not streamed).
local RunService = game:GetService("RunService")

local ViewModel = {}
local ctx, C, GunModel
local camera = workspace.CurrentCamera
local model, root, muzzle, flash
local HIP = CFrame.new(0.72, -0.72, -1.45)
local ADS = CFrame.new(0, -0.38, -1.05) -- sight line (top accent strip) on the screen centre
local adsAlpha, adsTarget, adsTime = 0, 0, 0.15
local back, backVel, flashT = 0, 0, 0
local lastLook = Vector3.zero
local sway = Vector2.zero

function ViewModel.set(gunId)
	if model then
		model:Destroy()
		model = nil
	end
	local g = C.GunsById[gunId]
	if not g then
		return
	end
	model = GunModel.build(g)
	root = model.PrimaryPart
	root.Anchored = true
	muzzle = root:FindFirstChild("Muzzle")
	flash = Instance.new("Part")
	flash.Name = "Flash"
	flash.Size = Vector3.new(0.25, 0.25, 0.4)
	flash.Material = Enum.Material.Neon
	flash.Color = g.accent
	flash.Transparency = 1
	flash.CanCollide, flash.CanQuery, flash.CanTouch, flash.CastShadow, flash.Massless = false, false, false, false, true
	flash.CFrame = root.CFrame * CFrame.new(g.muzzle - Vector3.new(0, 0, 0.2))
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = root, flash
	w.Parent = flash
	flash.Parent = model
	model.Parent = camera
end

function ViewModel.setAds(on, time)
	adsTarget = on and 1 or 0
	adsTime = math.max(time or 0.15, 0.01)
end

function ViewModel.kick(visual)
	backVel += (visual or 1) * 3
end

function ViewModel.flash()
	flashT = 0.04
end

function ViewModel.adsProgress()
	return adsAlpha
end

function ViewModel.rootPart()
	return root
end

-- World position of the muzzle (tracer start); falls back to just below the camera.
function ViewModel.muzzle()
	if muzzle then
		return muzzle.WorldPosition
	end
	return camera.CFrame * Vector3.new(0.5, -0.5, -2)
end

function ViewModel.init(c)
	ctx = c
	C = ctx.Config
	GunModel = require(ctx.shared.GunModel)
	RunService:BindToRenderStep("BCViewModel", Enum.RenderPriority.Camera.Value + 2, function(dt)
		if not root then
			return
		end
		local step = dt / adsTime
		adsAlpha = adsTarget > adsAlpha and math.min(adsTarget, adsAlpha + step) or math.max(adsTarget, adsAlpha - step)
		backVel += (-back * 300 - backVel * 30) * dt
		back += backVel * dt
		local look = camera.CFrame.LookVector
		local d = camera.CFrame:VectorToObjectSpace(look - lastLook)
		lastLook = look
		local motion = ctx.settings.reducedMotion and 0 or 1
		sway = sway:Lerp(Vector2.new(-d.X * 2, d.Y * 2) * motion, math.min(1, dt * 10))
		local base = HIP:Lerp(ADS, adsAlpha)
		root.CFrame = camera.CFrame * base * CFrame.new(sway.X * (1 - adsAlpha), sway.Y * (1 - adsAlpha), back)
			* CFrame.Angles(back * 0.6, 0, 0)
		if flashT > 0 then
			flashT -= dt
			flash.Transparency = flashT > 0 and 0.1 or 1
		end
	end)
end

return ViewModel
