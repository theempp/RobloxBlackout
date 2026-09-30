-- Repair minigame (§5d): a dial with a sweeping needle and this step's zone; TAP while the needle is in
-- the zone. The server started the step (t0, period, zone) and re-checks every tap's server-time stamp.
local RunService = game:GetService("RunService")

local RepairUI = { open = nil, taps = 0 }

function RepairUI.init(ctx)
	local C, Hud = ctx.Config, ctx.Hud
	local RC = C.Repair
	local Repair = require(ctx.shared.Repair)
	local panel = Hud.make("Frame", Hud.root, { Name = "RepairPanel", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = C.Colors.Panel, BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false })
	Hud.corner(panel, UDim.new(0.5, 0))
	local dots = {}
	for i = 1, 8 do
		dots[i] = Hud.make("Frame", panel, { Size = UDim2.fromOffset(9, 9), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(0, 158, 115) })
		Hud.corner(dots[i], UDim.new(0.5, 0))
	end
	local needle = Hud.make("Frame", panel, { Size = UDim2.fromOffset(4, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = C.Colors.Text, BorderSizePixel = 0 })
	local label = Hud.label(panel, "", 14, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, 4) })
	-- TAP sits bottom-centre under the dial: clear of FIRE / ADS / the weapon button and the left stick.
	-- (The dial is the one mid-screen element, and only while repairing.)
	local tap = Hud.button(Hud.root, "RepairTap", "TAP", 84, { Visible = false })
	local function place()
		panel.Position = UDim2.fromOffset(Hud.W / 2, Hud.H * 0.4)
		tap.Position = UDim2.fromOffset(Hud.W / 2, Hud.H * 0.8)
	end
	ctx.on("rescale", place)
	place()
	local function close()
		RepairUI.open = nil
		panel.Visible, tap.Visible = false, false
	end
	tap.Activated:Connect(function()
		local o = RepairUI.open
		if o then
			RepairUI.taps += 1
			ctx.remotes.Repair:FireServer(o.kart, workspace:GetServerTimeNow())
			ctx.netSends += 1
		end
	end)
	ctx.remotes.HeistEvent.OnClientEvent:Connect(function(kind, d)
		if kind ~= "repair" or type(d) ~= "table" then
			return
		end
		if d.done or d.closed then
			close()
			if d.done then
				ctx.Hud.toast("Kart repaired", 2)
			end
			return
		end
		RepairUI.open = d
		panel.Visible, tap.Visible = true, true
		label.Text = string.format("REPAIR %d/%d", d.steps or 0, d.need or RC.Steps)
		for i, dot in ipairs(dots) do
			local a = 2 * math.pi * (d.zone + d.width * (i - 1) / (#dots - 1)) - math.pi / 2
			dot.Position = UDim2.new(0.5, math.cos(a) * 58, 0.5, math.sin(a) * 58)
		end
	end)
	ctx.on("driving", function(on)
		if on then
			close()
		end
	end)
	RunService.RenderStepped:Connect(function()
		local o = RepairUI.open
		if o and o.t0 then
			needle.Rotation = Repair.phase(workspace:GetServerTimeNow(), o.t0, o.period) * 360
		end
	end)
	ctx.probe = ctx.probe or {}
	ctx.probe.repair = function()
		return { open = RepairUI.open ~= nil, tapShown = tap.Visible, taps = RepairUI.taps }
	end
end

return RepairUI
