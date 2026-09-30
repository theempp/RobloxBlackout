-- Client-side enemy visuals, no extra network traffic: camera heads sweep from shared server time (the
-- same function the server's detection uses) with a faint view line; enemy shots draw a tracer when
-- the model's ShotAt attribute changes. Pooled parts; skipped when far away.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EnemyView = {}

function EnemyView.init(ctx)
	local C = ctx.Config
	local M = require(ctx.shared.HeistMap)
	local Perception = require(ctx.shared.Perception)
	local CC = C.Enemies.Camera
	local folder = Instance.new("Folder")
	folder.Name = "EnemyFx"
	folder.Parent = workspace
	local lines = {}
	local function line(i)
		local p = lines[i]
		if not p then
			p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(255, 60, 60)
			p.Transparency = 0.75
			p.Size = Vector3.new(0.12, 0.12, 1)
			p.Parent = folder
			lines[i] = p
		end
		return p
	end
	local tracers, nextTracer = {}, 1
	for i = 1, 8 do
		local t = line(100 + i):Clone()
		t.Transparency = 1
		t.Color = Color3.fromRGB(255, 120, 60)
		t.Parent = folder
		tracers[i] = { part = t, life = 0 }
	end
	local function tracer(from, to)
		local tr = tracers[nextTracer]
		nextTracer = nextTracer % #tracers + 1
		tr.part.Size = Vector3.new(0.15, 0.15, (to - from).Magnitude)
		tr.part.CFrame = CFrame.lookAt((from + to) / 2, to)
		tr.part.Transparency = 0.2
		tr.life = 0.08
	end
	local function watch(m)
		if m:GetAttribute("Kind") == "camera" then
			return
		end
		m:GetAttributeChangedSignal("ShotAt"):Connect(function()
			local head = m:FindFirstChild("Head")
			local target = Players:GetPlayerByUserId(m:GetAttribute("TargetId") or 0)
			local tHead = target and target.Character and target.Character:FindFirstChild("Head")
			if head and tHead then
				tracer(head.Position, tHead.Position)
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal("BC_Enemy"):Connect(watch)
	for _, m in ipairs(CollectionService:GetTagged("BC_Enemy")) do
		watch(m)
	end
	local centre = (M.Tower.min + M.Tower.max) / 2
	RunService.RenderStepped:Connect(function(dt)
		for _, tr in ipairs(tracers) do
			if tr.life > 0 then
				tr.life -= dt
				if tr.life <= 0 then
					tr.part.Transparency = 1
				end
			end
		end
		local near = (workspace.CurrentCamera.CFrame.Position - centre).Magnitude < 170
		local sNow = workspace:GetServerTimeNow()
		for i, m in ipairs(CollectionService:GetTagged("BC_Camera")) do
			local def = M.GuardSets.A.cameras[m:GetAttribute("Def") or 0]
			local head = m:FindFirstChild("Head")
			local l = line(i)
			if not def or not head or not near then
				l.Transparency = 1
			else
				local off = m:GetAttribute("Hacked") or m:GetAttribute("Down")
				local look = Perception.look(off and def.yaw or Perception.cameraYaw(def, sNow, CC.Period), off and -60 or CC.Pitch)
				head.CFrame = CFrame.lookAt(def.pos, def.pos + look)
				local eye = m:FindFirstChild("Eye")
				if eye then
					eye.CFrame = head.CFrame * CFrame.new(0, 0, -0.82)
					eye.Color = off and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(255, 40, 60)
				end
				l.Transparency = off and 1 or 0.75
				local len = CC.Range * 0.6
				l.Size = Vector3.new(0.12, 0.12, len)
				l.CFrame = CFrame.lookAt(def.pos + look * (len / 2), def.pos + look * len)
			end
		end
	end)
end

return EnemyView
