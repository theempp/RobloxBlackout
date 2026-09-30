-- Lobby pad panel (small, centered-top per §5e): squad names, countdown, READY toggle.
-- Reads the pad's attributes (the server publishes them); refreshes at 4 Hz, not per frame.
local Players = game:GetService("Players")

local LobbyClient = {}
local ctx, C, Hud
local lp = Players.LocalPlayer

function LobbyClient.init(c)
	ctx = c
	C = ctx.Config
	Hud = ctx.Hud
	local panel = Hud.make("Frame", Hud.root, { Name = "PadPanel", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(250, 92),
		BackgroundColor3 = C.Colors.Panel, BackgroundTransparency = 0.3, BorderSizePixel = 0, Visible = false })
	Hud.corner(panel, 10)
	local title = Hud.label(panel, "", 15, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -90, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })
	local names = Hud.label(panel, "", 12, { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -90, 0, 58), TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Colors.Muted, Font = Enum.Font.GothamMedium })
	local ready = Hud.button(panel, "ReadyButton", "READY", 58, { Position = UDim2.new(1, -42, 0.5, 0), TextSize = 12 })
	LobbyClient.panel, LobbyClient.readyButton = panel, ready
	local on = false

	local function refresh()
		local id = lp:GetAttribute("BC_Pad")
		local lobby = workspace:FindFirstChild("Lobby")
		local part = id and lobby and lobby:FindFirstChild("Pad" .. id)
		if not part then
			panel.Visible, on = false, false
			return
		end
		panel.Visible = true
		local left = math.max(0, math.ceil((part:GetAttribute("Deadline") or 0) - workspace:GetServerTimeNow()))
		local launching = part:GetAttribute("Launching")
		title.Text = string.format("HEIST %s  %d/%d  %s", id, part:GetAttribute("Count") or 0, part:GetAttribute("Max") or 4,
			launching and "LAUNCHING" or (left .. "s"))
		names.Text = (part:GetAttribute("Names") or "") .. "\nStep off the pad to leave"
		ready.Text = on and "CANCEL" or "READY"
		ready.BackgroundColor3 = on and Color3.fromRGB(0, 158, 115) or C.Colors.Panel
	end
	ready.Activated:Connect(function()
		on = not on
		ctx.remotes.Queue:FireServer("ready", on)
		ctx.netSends += 1
		refresh()
	end)
	ctx.on("rescale", function()
		panel.Position = UDim2.fromOffset(Hud.W / 2, 84)
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			refresh()
		end
	end)
end

return LobbyClient
