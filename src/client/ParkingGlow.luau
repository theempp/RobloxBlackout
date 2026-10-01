-- Parking glows (§5d, client-side only: drones never see them). Own spot = bright beacon in your slot
-- colour, visible through walls (AlwaysOnTop marker + beam); teammates' spots = faint ring within
-- GlowRange. Also every kart's sabotage ring (fill bar / SABOTAGED) so the crew can react.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ParkingGlow = {}

function ParkingGlow.init(ctx)
	local C = ctx.Config
	local M = require(ctx.shared.HeistMap)
	local lp = Players.LocalPlayer
	local folder = Instance.new("Folder")
	folder.Name = "ParkingGlow"
	folder.Parent = workspace
	local marks = {}
	local function mark(id)
		local m = marks[id]
		if m then
			return m
		end
		local s = M.spotById(id)
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, C.Parking.Radius * 2, C.Parking.Radius * 2)
		ring.CFrame = CFrame.new(s.pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
		ring.Material = Enum.Material.SmoothPlastic
		ring.Parent = folder
		local beam = ring:Clone()
		beam.Shape = Enum.PartType.Block
		beam.Size = Vector3.new(0.8, 80, 0.8)
		beam.CFrame = CFrame.new(s.pos + Vector3.new(0, 40, 0))
		beam.Parent = folder
		local bb = Instance.new("BillboardGui")
		bb.AlwaysOnTop = true -- through walls
		bb.Size = UDim2.fromOffset(46, 46)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
		bb.Adornee = ring
		local dot = Instance.new("TextLabel")
		dot.Size = UDim2.fromScale(1, 1)
		dot.BackgroundTransparency = 0.1
		dot.Font = Enum.Font.GothamBlack
		dot.TextScaled = true
		dot.Text = "P"
		dot.TextColor3 = Color3.new(1, 1, 1)
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.5, 0)
		cr.Parent = dot
		dot.Parent = bb
		bb.Parent = ring
		m = { ring = ring, beam = beam, bb = bb, dot = dot, pos = s.pos }
		marks[id] = m
		return m
	end
	local bars = {}
	local function bar(k)
		local b = bars[k]
		if b or not k.PrimaryPart then
			return b
		end
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(90, 22)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 140
		bb.Adornee = k.PrimaryPart
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.new(0, 0, 0)
		bg.BackgroundTransparency = 0.35
		bg.BorderSizePixel = 0
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = bg
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Parent = bg
		bg.Parent = bb
		bb.Parent = folder
		b = { bb = bb, fill = fill, text = t }
		bars[k] = b
		return b
	end
	task.spawn(function()
		while true do
			task.wait(0.1)
			local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			local mine = lp:GetAttribute("BC_Spot")
			local seen = {}
			for _, p in ipairs(Players:GetPlayers()) do
				local id, slot = p:GetAttribute("BC_Spot"), p:GetAttribute("BC_Slot")
				if id and slot and M.spotById(id) then
					seen[id] = true
					local m = mark(id)
					local col = C.Colors.Slots[slot] or C.Colors.Accent
					local own = id == mine
					local d = root and (root.Position - m.pos).Magnitude or math.huge
					m.ring.Color, m.beam.Color, m.dot.BackgroundColor3 = col, col, col
					m.ring.Transparency = own and 0.15 or (d <= C.Parking.GlowRange and 0.65 or 1)
					m.beam.Transparency = own and 0.55 or 1
					m.bb.Enabled = own
				end
			end
			for id, m in pairs(marks) do
				if not seen[id] then
					m.ring.Transparency, m.beam.Transparency, m.bb.Enabled = 1, 1, false
				end
			end
			for _, k in ipairs(CollectionService:GetTagged("BC_Kart")) do
				local b = bar(k)
				if b then
					local fill, sab = k:GetAttribute("SabotageFill") or 0, k:GetAttribute("Sabotaged")
					b.bb.Enabled = sab or fill > 0
					b.fill.Size = UDim2.fromScale(sab and 1 or fill, 1)
					b.text.Text = sab and "SABOTAGED" or "SPOTTED"
				end
			end
			for k, b in pairs(bars) do
				if not k.Parent then
					b.bb:Destroy()
					bars[k] = nil
				end
			end
		end
	end)
	ctx.probe = ctx.probe or {}
	ctx.probe.glow = function()
		local id = lp:GetAttribute("BC_Spot")
		local m = id and marks[id]
		return { spot = id, own = m ~= nil and m.bb.Enabled and m.ring.Transparency < 0.5 }
	end
end

return ParkingGlow
