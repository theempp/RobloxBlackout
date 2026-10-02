-- KartVisuals (§7): every kart near the camera gets live wheels each frame: suspension travel (the wheel
-- stays on the ground, so it rides up into the arch on bumps), spin with ground speed, front-wheel steer
-- and the steering wheel. The local driver's kart reads its physics state (exact); other karts are
-- estimated from one ray per wheel + their replicated motion (steer from yaw rate). Visual only: Motor6D
-- Transforms never replicate.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local KartVisuals = { own = {}, updated = 0 } -- own[model] = physics state of the kart this client steps
local ctx, K, KartPhysics, KartModel
local vis = setmetatable({}, { __mode = "k" })
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local refreshAt = 0

local function refresh()
	local list = CollectionService:GetTagged("BC_KartVisual")
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	params.FilterDescendantsInstances = list
end

-- Wheel motor transforms from compression x (from full droop), spin and steer (rad, + = right).
function KartVisuals.apply(m, x, spin, steer, doorAlpha)
	local root = m.PrimaryPart
	if not root then
		return
	end
	local S = K.Susp
	for i, name in ipairs(KartModel.WHEELS) do
		local j = root:FindFirstChild("M_" .. name)
		local knuckle = root:FindFirstChild("M_Knuckle_" .. name:sub(-2))
		local travel = CFrame.new(0, x[i] - S.Droop - S.StaticDrop, 0) * CFrame.Angles(0, i <= 2 and -steer or 0, 0)
		if j then
			j.Transform = travel * CFrame.Angles(spin[i], 0, 0)
		end
		if knuckle then knuckle.Transform = travel end
	end
	local turn = CFrame.fromAxisAngle(KartModel.columnAxis(), -steer * K.Geo.SteerRatio)
	local angle = math.rad(K.DoorAngle) * (doorAlpha or 0)
	for _, j in ipairs(root:GetChildren()) do
		if j:IsA("Motor6D") then
			if j.Name:sub(1, 7) == "M_Steer" then
				j.Transform = turn
			elseif j.Name:sub(1, 8) == "M_Door_L" then
				j.Transform = CFrame.fromAxisAngle(Vector3.new(-0.32, 0, 1).Unit, angle)
			elseif j.Name:sub(1, 8) == "M_Door_R" then
				j.Transform = CFrame.fromAxisAngle(Vector3.new(0.32, 0, 1).Unit, -angle)
			end
		end
	end
end

local function lights(m, v)
	local on = m:GetAttribute("LightsOn") ~= false
	if v.lights == on then return end
	v.lights = on
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("VortexLED") then
			p.Material = Enum.Material.SmoothPlastic
			p.Color = on and Color3.fromRGB(243, 248, 255) or Color3.fromRGB(23, 25, 28)
		end
	end
end

local function doors(m, v, dt)
	local goal = m:GetAttribute("DoorsOpen") and 1 or 0
	v.door = (v.door or 0) + (goal - (v.door or 0)) * math.min(1, dt * 5)
	return v.door
end

local function estimate(m, dt)
	local root = m.PrimaryPart
	local g = KartPhysics.geo(K)
	local v = vis[m]
	if not v then
		v = { x = { K.Susp.Droop, K.Susp.Droop, K.Susp.Droop, K.Susp.Droop }, spin = { 0, 0, 0, 0 }, steer = 0 }
		vis[m] = v
	end
	local cf = root.CFrame
	local up, look = cf.UpVector, cf.LookVector
	local r = K.Geo.WheelRadius
	local vel, w = root.AssemblyLinearVelocity, root.AssemblyAngularVelocity
	for i = 1, 4 do
		local o = cf * g.wheels[i].top
		local hit = workspace:Raycast(o, -up * (g.castLen + r + 0.3), params)
		if hit then
			v.x[i] = math.clamp(g.castLen + r - hit.Distance, 0, g.travel + 0.12)
		else
			v.x[i] = math.max(0, v.x[i] - K.Susp.VisualDroopRate * dt)
		end
		local vp = vel + w:Cross(o - root.Position)
		v.spin[i] = (v.spin[i] - vp:Dot(look) / r * dt) % (2 * math.pi)
	end
	local fwd = vel:Dot(look)
	local yaw = w:Dot(up)
	local want = math.abs(fwd) > 2 and -math.atan(yaw * 7 / fwd) or 0 -- bicycle model (wheelbase 7)
	want = math.clamp(want, -math.rad(K.Steer), math.rad(K.Steer))
	v.steer += (want - v.steer) * math.min(1, dt * 10)
		KartVisuals.apply(m, v.x, v.spin, v.steer, doors(m, v, dt))
		lights(m, v)
end

local function frame(dt)
	local now = os.clock()
	if now > refreshAt then
		refreshAt = now + 0.5
		refresh()
	end
	local cam = workspace.CurrentCamera.CFrame.Position
	local n = 0
	for _, m in ipairs(CollectionService:GetTagged("BC_KartVisual")) do
		local root = m.PrimaryPart
		if root and (root.Position - cam).Magnitude < 250 then
			local st = KartVisuals.own[m]
			if st then
				local x = {}
				for i = 1, 4 do -- airborne wheels hang at droop smoothly, not snap
					local prev = vis[m] and vis[m].x[i] or st.x[i]
					x[i] = st.on[i] and math.min(st.x[i], KartPhysics.geo(K).travel + 0.12) or math.max(0, prev - K.Susp.VisualDroopRate * dt)
				end
					local v = vis[m] or {}
					v.x, v.spin, v.steer = x, st.spin, st.steer
					vis[m] = v
					KartVisuals.apply(m, x, st.spin, st.steer, doors(m, v, dt))
					lights(m, v)
			else
				estimate(m, dt)
			end
			n += 1
		end
	end
	KartVisuals.updated = n
end

function KartVisuals.init(c)
	ctx = c
	K = ctx.Config.Kart
	KartPhysics = require(ctx.shared.KartPhysics)
	KartModel = require(ctx.shared.KartModel)
	RunService.PreSimulation:Connect(frame) -- joint transforms apply in the simulation step
	ctx.probe = ctx.probe or {}
	ctx.probe.kartVisuals = function()
		local out = { updated = KartVisuals.updated, karts = {} }
		for _, m in ipairs(CollectionService:GetTagged("BC_KartVisual")) do
			local root, v = m.PrimaryPart, vis[m]
			if root and v then
				local gap = {} -- tyre bottom height above the ground under it (negative = clipping)
				for i, name in ipairs(KartModel.WHEELS) do
					local wp = m:FindFirstChild(name)
					local hit = wp and workspace:Raycast(wp.Position + Vector3.yAxis * 2, Vector3.yAxis * -6, params)
					gap[i] = hit and (wp.Position.Y - K.Geo.WheelRadius - hit.Position.Y) or 99
				end
				out.karts[m.Name] = { x = v.x, steer = v.steer, gap = gap }
			end
		end
		return out
	end
end

return KartVisuals
