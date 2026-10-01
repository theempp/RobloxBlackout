-- Renders the gauntlet beams locally from shared server time: the same function the server hit-tests,
-- so no beam positions are ever sent. Skips work when the camera is far from the tower.
local RunService = game:GetService("RunService")

local LaserView = { beams = {} }

function LaserView.init(ctx)
	local M = require(ctx.shared.HeistMap)
	local Lasers = require(ctx.shared.Lasers)
	local folder = Instance.new("Folder")
	folder.Name = "LaserBeams"
	folder.Parent = workspace
	for i = 1, #M.Lasers do
		local p = Instance.new("Part")
		p.Name = "Beam" .. i
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(255, 40, 60)
		p.Size = Vector3.new(0.18, 0.18, 1)
		p.Parent = folder
		LaserView.beams[i] = p
	end
	local centre = (M.Tower.min + M.Tower.max) / 2
	RunService.RenderStepped:Connect(function()
		local st = workspace:FindFirstChild("HeistState")
		local cam = workspace.CurrentCamera
		local near = st and (cam.CFrame.Position - centre).Magnitude < 160
		local now = workspace:GetServerTimeNow()
		local off = not near or now < (st:GetAttribute("LasersOffUntil") or 0)
		local mult = st and st:GetAttribute("LaserSpeed") or 1
		for i, def in ipairs(M.Lasers) do
			local p = LaserView.beams[i]
			if off then
				p.Transparency = 1
			else
				local a, b = Lasers.at(def, now, mult)
				p.Transparency = 0.1
				p.Size = Vector3.new(0.18, 0.18, (b - a).Magnitude)
				local dir = b - a
				p.CFrame = CFrame.lookAt((a + b) / 2, b, math.abs(dir.Unit.Y) > 0.9 and Vector3.xAxis or Vector3.yAxis)
			end
		end
	end)
end

return LaserView
