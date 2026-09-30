-- Pooled local effects: tracers, impact flashes, floating damage numbers. Fixed pools created once;
-- one per-frame loop fades them (no instances or tweens created while shooting).
-- Emissive neon only, no dynamic lights (mobile).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Fx = {}
local ctx, C, P
local PARK = CFrame.new(0, -5000, 0)
local tracers, impacts, numbers = {}, {}, {}
local ti, ii, ni = 0, 0, 0

local function neon(folder, size)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.Transparency = 1
	p.CFrame = PARK
	p.Parent = folder
	return p
end

function Fx.tracer(from, to, color)
	ti = ti % #tracers + 1
	local t = tracers[ti]
	local len = (to - from).Magnitude
	if len < 0.5 then
		return
	end
	t.part.Size = Vector3.new(0.07, 0.07, len)
	t.part.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
	t.part.Color = color
	t.part.Transparency = 0.1
	t.life = P.TracerTime
end

function Fx.impact(pos, color)
	ii = ii % #impacts + 1
	local t = impacts[ii]
	t.part.CFrame = CFrame.new(pos)
	t.part.Color = color or C.Colors.Foam
	t.part.Transparency = 0
	t.life = 0.12
end

function Fx.damage(pos, amount, kind)
	ni = ni % #numbers + 1
	local n = numbers[ni]
	n.att.WorldPosition = pos
	n.label.Text = tostring(amount)
	n.label.TextColor3 = C.Colors[kind == "kill" and "Kill" or kind == "head" and "Head" or "Hit"]
	n.label.TextSize = kind == "head" and 26 or 20
	n.gui.Enabled = true
	n.life = 0.7
end

function Fx.init(c)
	ctx = c
	C = ctx.Config
	P = C.Perf
	local folder = Instance.new("Folder")
	folder.Name = "BCFx"
	folder.Parent = workspace
	Fx.folder = folder
	for i = 1, P.TracerPool do
		tracers[i] = { part = neon(folder, Vector3.new(0.07, 0.07, 1)), life = 0 }
	end
	for i = 1, P.ImpactPool do
		impacts[i] = { part = neon(folder, Vector3.new(0.35, 0.35, 0.35)), life = 0 }
	end
	for i = 1, P.MarkerPool do
		local att = Instance.new("Attachment")
		att.Parent = workspace.Terrain
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(80, 30)
		gui.AlwaysOnTop = true
		gui.Enabled = false
		gui.Adornee = att
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		numbers[i] = { att = att, gui = gui, label = label, life = 0 }
	end

	-- Other players' shots (unreliable remote): tracer from their approximate muzzle.
	ctx.remotes.FX.OnClientEvent:Connect(function(shooter, gunId, origin, endPoint)
		if typeof(origin) ~= "Vector3" or typeof(endPoint) ~= "Vector3" then
			return
		end
		local g = C.GunsById[gunId]
		Fx.tracer(origin + Vector3.new(0, -0.4, 0), endPoint, g and g.accent or C.Colors.Accent)
	end)

	RunService.RenderStepped:Connect(function(dt)
		for _, t in ipairs(tracers) do
			if t.life > 0 then
				t.life -= dt
				if t.life <= 0 then
					t.part.Transparency = 1
					t.part.CFrame = PARK
				end
			end
		end
		for _, t in ipairs(impacts) do
			if t.life > 0 then
				t.life -= dt
				t.part.Transparency = 1 - t.life / 0.12
				if t.life <= 0 then
					t.part.CFrame = PARK
				end
			end
		end
		for _, n in ipairs(numbers) do
			if n.life > 0 then
				n.life -= dt
				n.gui.StudsOffsetWorldSpace = Vector3.new(0, (0.7 - n.life) * 2.5, 0)
				n.label.TextTransparency = n.life < 0.25 and 1 - n.life / 0.25 or 0
				if n.life <= 0 then
					n.gui.Enabled = false
				end
			end
		end
	end)
end

return Fx
