-- Queue pads (revision stage 1). Each pad's backboard is drawn locally from the pad's attributes (the server
-- publishes them on change; nothing is sent per tick): heist label, mode, occupancy, countdown and every
-- member with READY state. The HUD panel for your own pad shows the same plus the READY toggle (button,
-- Enter or gamepad R1). Your ready state is always read back from the server's list. Refresh: 4 Hz.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LobbyClient = { boards = {} }
local ctx, C, Hud
local lp = Players.LocalPlayer
local READY, WAIT = Color3.fromRGB(146, 221, 128), Color3.fromRGB(255, 190, 97)

local function split(s)
	return (type(s) == "string" and s ~= "") and string.split(s, "\n") or {}
end

-- Parsed state of pad `id` (tests read this too).
function LobbyClient.state(id)
	local lobby = workspace:FindFirstChild("Lobby")
	local part = lobby and lobby:FindFirstChild("Pad" .. id)
	if not part then
		return nil
	end
	local names, ready, ids = split(part:GetAttribute("Names")), split(part:GetAttribute("ReadyList")), split(part:GetAttribute("Ids"))
	local members = {}
	for i, n in ipairs(names) do
		members[i] = { name = n, ready = ready[i] == "1", me = ids[i] == tostring(lp.UserId) }
	end
	local count = part:GetAttribute("Count") or 0
	local left = math.max(0, math.ceil((part:GetAttribute("Deadline") or 0) - workspace:GetServerTimeNow()))
	local launching = part:GetAttribute("Launching") == true
	local status
	if launching then
		status = "LAUNCHING"
	elseif count == 0 then
		status = "WAITING FOR CREW"
	elseif (part:GetAttribute("Ready") or 0) >= count then
		status = "ALL READY · " .. left .. "s"
	else
		status = "LAUNCH IN " .. left .. "s"
	end
	return { id = id, part = part, label = part:GetAttribute("Label") or "HEIST", mode = part:GetAttribute("Mode") or "", count = count,
		max = part:GetAttribute("Max") or C.Lobby.MaxSquad, members = members, status = status, launching = launching }
end

local function text(parent, name, s, size, x, y, w, h, props)
	local l = Instance.new("TextLabel")
	l.Name, l.Text, l.TextSize, l.Font, l.TextColor3 = name, s, size, Enum.Font.GothamBold, C.UI.Ink
	l.BackgroundTransparency, l.Position, l.Size = 1, UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- Backboard: a local SurfaceGui on the server-built board part (rebuilt if the part streams back in).
local function board(id)
	local b = LobbyClient.boards[id]
	local lobby = workspace:FindFirstChild("Lobby")
	local decor = lobby and lobby:FindFirstChild("Decor_" .. id)
	local part = decor and decor:FindFirstChild("Board")
	if not part then
		return nil
	end
	if b and b.gui.Parent == part then
		return b
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face = "LiveBoard", Enum.NormalId.Front
	gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
	gui.LightInfluence, gui.MaxDistance = 0, 150
	local bg = Instance.new("Frame")
	bg.Name, bg.Size, bg.BackgroundColor3, bg.BorderSizePixel = "Paper", UDim2.fromScale(1, 1), C.UI.Paper, 0
	bg.Parent = gui
	local px = part.Size.X * 40
	b = { gui = gui, rows = {} }
	b.title = text(bg, "Title", "", 40, 20, 10, px - 240, 50, { Font = Enum.Font.GothamBlack })
	local chip = Instance.new("Frame")
	chip.Name, chip.Position, chip.Size, chip.BackgroundColor3 = "ModeChip", UDim2.fromOffset(px - 200, 14), UDim2.fromOffset(180, 42), WAIT
	Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 12)
	chip.Parent = bg
	b.mode = text(chip, "Mode", "", 26, 0, 0, 180, 42, { TextXAlignment = Enum.TextXAlignment.Center })
	b.count = text(bg, "Count", "", 64, 20, 62, 170, 72, { Font = Enum.Font.GothamBlack })
	b.status = text(bg, "Status", "", 30, 200, 74, px - 220, 50)
	for i = 1, C.Lobby.MaxSquad do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local x, y = 20 + col * (px - 40) / 2, 146 + row * 46
		local dot = Instance.new("Frame")
		dot.Name, dot.Position, dot.Size, dot.BorderSizePixel = "Dot" .. i, UDim2.fromOffset(x, y + 8), UDim2.fromOffset(24, 24), 0
		Instance.new("UICorner", dot).CornerRadius = UDim.new(0.5, 0)
		dot.Parent = bg
		b.rows[i] = { dot = dot, name = text(bg, "Name" .. i, "", 26, x + 32, y, (px - 40) / 2 - 150, 40, { TextTruncate = Enum.TextTruncate.AtEnd }),
			tag = text(bg, "Tag" .. i, "", 22, x + (px - 40) / 2 - 116, y, 110, 40, { TextXAlignment = Enum.TextXAlignment.Right }) }
	end
	gui.Adornee, gui.Parent = part, part
	LobbyClient.boards[id] = b
	return b
end

local function drawBoard(id)
	local st = LobbyClient.state(id)
	local b = st and board(id)
	if not b then
		return
	end
	b.title.Text = st.label .. " · PAD " .. id
	b.mode.Text = st.mode ~= "" and st.mode or "HEIST"
	b.count.Text = st.count .. "/" .. st.max
	b.status.Text = st.status
	for i, row in ipairs(b.rows) do
		local m = st.members[i]
		row.name.Text = m and ((m.me and "YOU · " or "") .. m.name) or "Open spot"
		row.name.TextColor3 = m and C.UI.Ink or C.UI.Muted
		row.tag.Text = m and (m.ready and "READY" or "NOT READY") or ""
		row.tag.TextColor3 = m and m.ready and Color3.fromRGB(34, 130, 62) or C.UI.Muted
		row.dot.BackgroundColor3 = not m and C.Lobby.Colors.Empty or (m.ready and READY or WAIT)
	end
end

function LobbyClient.init(c)
	ctx = c
	C = ctx.Config
	Hud = ctx.Hud
	local panel = Hud.make("Frame", Hud.root, { Name = "PadPanel", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(300, 128),
		BackgroundColor3 = C.UI.Paper, BorderSizePixel = 0, Visible = false })
	Hud.surface(panel)
	local title = Hud.label(panel, "", 14, { Name = "Title", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -90, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack })
	local status = Hud.label(panel, "", 13, { Name = "Status", Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -90, 0, 16), TextXAlignment = Enum.TextXAlignment.Left })
	local names = Hud.label(panel, "", 11, { Name = "Members", Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -90, 0, 64), TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.UI.Muted, Font = Enum.Font.GothamMedium, RichText = true })
	local hint = Hud.label(panel, "Step off the pad to leave", 10, { Name = "Hint", Position = UDim2.fromOffset(12, 108), Size = UDim2.new(1, -90, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.UI.Muted, Font = Enum.Font.GothamMedium })
	local ready = Hud.button(panel, "ReadyButton", "READY", 58, { Position = UDim2.new(1, -42, 0.5, 0), TextSize = 12, TextWrapped = true })
	LobbyClient.panel, LobbyClient.readyButton = panel, ready
	LobbyClient.meReady = false

	local function refresh()
		local id = lp:GetAttribute("BC_Pad")
		for _, def in ipairs(C.Lobby.Pads) do
			drawBoard(def.id)
		end
		local st = id and LobbyClient.state(id)
		if not st then
			panel.Visible, LobbyClient.meReady = false, false
			return
		end
		panel.Visible = ctx.Menus.current == nil
		local lines, me = {}, false
		for _, m in ipairs(st.members) do
			me = me or (m.me and m.ready)
			table.insert(lines, string.format('%s%s  <font color="#%s">%s</font>', m.name, m.me and " (you)" or "", m.ready and "22823E" or "8A7A6A",
				m.ready and "READY" or "not ready"))
		end
		LobbyClient.meReady = me
		title.Text = st.label .. " · " .. (st.mode ~= "" and st.mode or "HEIST")
		status.Text = st.count .. "/" .. st.max .. " · " .. st.status
		names.Text = table.concat(lines, "\n")
		hint.Text = "Step off the pad to leave" .. (ctx.inputKind == "Gamepad" and " · R1 = ready" or ctx.inputKind == "Keyboard" and " · Enter = ready" or "")
		ready.Text = me and "CANCEL" or "READY"
		ready.BackgroundColor3 = me and C.UI.Green or C.UI.Orange
	end
	LobbyClient.refresh = refresh
	local function toggleReady()
		if not lp:GetAttribute("BC_Pad") or ctx.Menus.current then return end
		ctx.remotes.Queue:FireServer("ready", not LobbyClient.meReady)
		ctx.netSends += 1
	end
	LobbyClient.toggleReady = toggleReady
	ready.Activated:Connect(toggleReady)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and (input.KeyCode == C.Keys.LobbyReady or input.KeyCode == C.Keys.PadReady) then toggleReady() end
	end)
	ctx.on("rescale", function()
		panel.Position = UDim2.fromOffset(Hud.W / 2, 84)
	end)
	ctx.on("menu", refresh)
	task.spawn(function()
		while true do
			task.wait(0.25)
			refresh()
		end
	end)
end

return LobbyClient
