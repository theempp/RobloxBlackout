-- Heist HUD (§5e): minimalist, corners/borders only; mid-screen only small centred-top items.
-- Minimap top-left under the settings gear (inside Roblox's safe insets): north-up, player-centred,
-- squad dots in slot colours, own parking spot, exit gate, the current objective pin, enemies pinged by
-- proximity (fade in 45 -> 30 studs; Purge jams it to 20 + flicker; hacked cameras drop off).
-- Squad cards under it: name + colour badge, HP bar (bleed-out ring when downed), heavy-loot icon,
-- kart-status dot; shrink to name + badge when calm. Top centre: alarm meter, objective, dash timer.
-- Teammates' name tags in slot colours. Results panel at run end. Texts/bars refresh at 10 Hz; per
-- frame only the map offset + own arrow move. Pooled markers, no per-frame allocation.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HeistHud = { cards = {}, pins = {}, pings = {} }
local ctx, C, Hud, M
local lp = Players.LocalPlayer
local MAP, SCALE = 120, 120 / 300 -- design units; 300 studs across
local STEP_TEXT = {
	park = "Drive to your glowing spot and park",
	vault = "Get into the Data Vault: grab the loot",
	load = "Take the loot to your kart and LOAD it",
	escape = "Drive to the exit gate",
	dash = "Reach the gate!",
	done = "Banked. Waiting for the crew",
}
local ALARM_COL = { Color3.fromRGB(220, 225, 240), Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 60, 70) }
local STATUS_COL = { hidden = Color3.fromRGB(150, 160, 170), spotted = Color3.fromRGB(255, 170, 40), sabotaged = Color3.fromRGB(255, 50, 60) }

local function frame(parent, props)
	local f = Hud.make("Frame", parent, { BorderSizePixel = 0, BackgroundColor3 = C.Colors.Panel })
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	return f
end

local function toMap(p)
	return UDim2.fromOffset(p.X * SCALE, p.Z * SCALE)
end

local function state()
	return workspace:FindFirstChild("HeistState")
end

local function squad()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("BC_Slot") then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return a:GetAttribute("BC_Slot") < b:GetAttribute("BC_Slot")
	end)
	return list
end

local function buildMap(root)
	local box = frame(root, { Name = "Minimap", Size = UDim2.fromOffset(MAP, MAP), BackgroundTransparency = 0.25, ClipsDescendants = true })
	Hud.corner(box, 10)
	Hud.stroke(box, C.Colors.Text, 1.5, 0.7)
	local world = frame(box, { Name = "World", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0) })
	for _, b in ipairs(M.Blocks) do
		local s = b.max - b.min
		frame(world, { Position = toMap(b.min), Size = UDim2.fromOffset(s.X * SCALE, s.Z * SCALE), BackgroundColor3 = Color3.fromRGB(60, 64, 80), BackgroundTransparency = 0.3 })
	end
	for _, r in ipairs(M.Rooms) do
		local s = r.max - r.min
		frame(world, { Position = toMap(r.min), Size = UDim2.fromOffset(s.X * SCALE, s.Z * SCALE), BackgroundColor3 = Color3.fromRGB(90, 96, 120), BackgroundTransparency = 0.2 })
	end
	local function pin(name, text, color)
		local p = Hud.label(world, text, 11, { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 0, BackgroundColor3 = color, TextColor3 = Color3.new(0, 0, 0), Font = Enum.Font.GothamBlack, ZIndex = 3 })
		Hud.corner(p, UDim.new(0.5, 0))
		return p
	end
	HeistHud.pins.gate = pin("GatePin", "G", Color3.fromRGB(0, 158, 115))
	HeistHud.pins.gate.Position = toMap(M.Gate.pos)
	HeistHud.pins.spot = pin("SpotPin", "P", C.Colors.Accent)
	HeistHud.pins.goal = pin("GoalPin", "!", Color3.fromRGB(255, 255, 255))
	for i = 1, 4 do
		local d = frame(world, { Name = "Mate" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(9, 9), ZIndex = 4, Visible = false })
		Hud.corner(d, UDim.new(0.5, 0))
		Hud.stroke(d, Color3.new(0, 0, 0), 1, 0.3)
		HeistHud.pins["mate" .. i] = d
	end
	for i = 1, 12 do
		local e = frame(world, { Name = "Ping" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7), Rotation = 45,
			BackgroundColor3 = Color3.fromRGB(255, 50, 60), ZIndex = 5, Visible = false })
		HeistHud.pings[i] = e
	end
	local me = Hud.label(box, "^", 16, { Name = "Me", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14),
		Font = Enum.Font.GothamBlack, ZIndex = 6 })
	HeistHud.map, HeistHud.world, HeistHud.me = box, world, me
end

local function buildCard(root, i)
	local c = frame(root, { Name = "Card" .. i, Size = UDim2.fromOffset(150, 22), BackgroundTransparency = 0.35, Visible = false })
	Hud.corner(c, 6)
	local badge = frame(c, { Name = "Badge", Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(8, 16) })
	Hud.corner(badge, 3)
	local name = Hud.label(c, "", 12, { Name = "Name", Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -44, 0, 14), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd })
	local hpBg = frame(c, { Name = "HpBg", Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -44, 0, 4), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3 })
	local hp = frame(hpBg, { Name = "Hp", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(90, 230, 120) })
	local heavy = frame(c, { Name = "Heavy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(9, 9),
		BackgroundColor3 = Color3.fromRGB(230, 159, 0), Visible = false })
	local dot = frame(c, { Name = "KartDot", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(9, 9) })
	Hud.corner(dot, UDim.new(0.5, 0))
	HeistHud.cards[i] = { frame = c, badge = badge, name = name, hpBg = hpBg, hp = hp, heavy = heavy, dot = dot }
end

local function buildTop(root)
	local top = frame(root, { Name = "TopCentre", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(220, 56), BackgroundTransparency = 1 })
	local meter = frame(top, { Name = "AlarmMeter", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(150, 14),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4 })
	Hud.corner(meter, 7)
	local fill = frame(meter, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = ALARM_COL[1] })
	Hud.corner(fill, 7)
	local tier = Hud.label(meter, "QUIET", 10, { Name = "Tier", Size = UDim2.fromScale(1, 1), TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.5, ZIndex = 2 })
	local goal = Hud.label(top, "", 12, { Name = "Objective", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.new(1, 60, 0, 16),
		TextStrokeTransparency = 0.5, Font = Enum.Font.GothamMedium })
	local timer = Hud.label(top, "", 20, { Name = "DashTimer", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 33), Size = UDim2.fromOffset(120, 22),
		TextStrokeTransparency = 0.4, Font = Enum.Font.GothamBlack, Visible = false })
	HeistHud.top, HeistHud.meter, HeistHud.fill, HeistHud.tier, HeistHud.goal, HeistHud.timer = top, meter, fill, tier, goal, timer
end

local function buildResults(root)
	local r = frame(root, { Name = "Results", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(260, 130), BackgroundTransparency = 0.15, Visible = false, ZIndex = 20 })
	Hud.corner(r, 12)
	local title = Hud.label(r, "", 22, { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 28), ZIndex = 21, Font = Enum.Font.GothamBlack })
	local credits = Hud.label(r, "", 26, { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 30), ZIndex = 21, TextColor3 = Color3.fromRGB(0, 200, 140), Font = Enum.Font.GothamBlack })
	local detail = Hud.label(r, "", 12, { Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 0, 44), ZIndex = 21, TextWrapped = true, TextColor3 = C.Colors.Muted })
	HeistHud.results = { frame = r, title = title, credits = credits, detail = detail }
end

-- Name tags over teammates in their slot colour (always with the name: colour is never the only cue).
local tags = {}
local function tag(p)
	local head = p.Character and p.Character:FindFirstChild("Head")
	local t = tags[p]
	if not head then
		return
	end
	if not t or t.Adornee ~= head then
		if t then
			t:Destroy()
		end
		t = Instance.new("BillboardGui")
		t.Name = "BC_Tag"
		t.Size = UDim2.fromOffset(120, 22)
		t.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		t.MaxDistance = 150
		t.AlwaysOnTop = true
		t.Adornee = head
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextStrokeTransparency = 0.3
		l.Parent = t
		t.Parent = lp.PlayerGui
		tags[p] = t
	end
	local slot = p:GetAttribute("BC_Slot")
	t.TextLabel.Text = p.DisplayName
	t.TextLabel.TextColor3 = C.Colors.Slots[slot] or C.Colors.Text
end

local function refresh()
	local st = state()
	local phase = st and st:GetAttribute("Phase")
	local running = phase == "running"
	local sNow = workspace:GetServerTimeNow()
	HeistHud.map.Visible = running
	HeistHud.top.Visible = running
	-- Alarm
	local AC = C.Alarm
	local v, t = st and st:GetAttribute("Alarm") or 0, st and st:GetAttribute("Tier") or 1
	HeistHud.fill.Size = UDim2.fromScale(math.clamp((v - (t - 1) * AC.PerTier) / AC.PerTier, 0.04, 1), 1)
	HeistHud.fill.BackgroundColor3 = ALARM_COL[t] or ALARM_COL[1]
	HeistHud.tier.Text = AC.Tiers[t] or ""
	-- Objective / downed / dash
	local stepName = lp:GetAttribute("BC_Step")
	local text = STEP_TEXT[stepName] or ""
	if lp:GetAttribute("BC_Downed") then
		local left = math.max(0, math.ceil((lp:GetAttribute("BC_BleedEnd") or sNow) - sNow))
		text = string.format("DOWNED %ds: %s", left, (lp:GetAttribute("BC_Override") or 0) > 0 and "hold OVERRIDE or wait for a revive" or "wait for a revive")
	elseif lp:GetAttribute("BC_Recall") then
		text = string.format("RECALLED: back at the entrance in %ds", math.max(0, math.ceil(lp:GetAttribute("BC_Recall") - sNow)))
	end
	HeistHud.goal.Text = text
	local dashEnd = lp:GetAttribute("BC_DashEnd")
	HeistHud.timer.Visible = dashEnd ~= nil
	if dashEnd then
		local left = math.max(0, dashEnd - sNow)
		HeistHud.timer.Text = string.format("%d:%02d", left // 60, math.floor(left % 60))
		HeistHud.timer.TextColor3 = left < 15 and Color3.fromRGB(255, 80, 80) or C.Colors.Text
	end
	-- Pins: own spot, objective
	local slot = lp:GetAttribute("BC_Slot")
	local spot = lp:GetAttribute("BC_Spot") and M.spotById(lp:GetAttribute("BC_Spot"))
	HeistHud.pins.spot.Visible = spot ~= nil
	if spot then
		HeistHud.pins.spot.Position = toMap(spot.pos)
		HeistHud.pins.spot.BackgroundColor3 = C.Colors.Slots[slot] or C.Colors.Accent
	end
	local goalPos = stepName == "park" and spot and spot.pos or stepName == "vault" and (M.Tower.min + M.Tower.max) / 2 + Vector3.new(0, 0, 45)
		or stepName == "load" and spot and spot.pos or (stepName == "escape" or stepName == "dash") and M.Gate.pos or nil
	HeistHud.pins.goal.Visible = goalPos ~= nil and stepName ~= "park" and stepName ~= "load"
	if goalPos then
		HeistHud.pins.goal.Position = toMap(goalPos)
	end
	-- Squad: dots + cards
	local list = squad()
	local calm = t == 1
	for i = 1, 4 do
		local p = list[i]
		local dot, card = HeistHud.pins["mate" .. i], HeistHud.cards[i]
		local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local col = p and C.Colors.Slots[p:GetAttribute("BC_Slot")] or C.Colors.Text
		dot.Visible = root ~= nil and p ~= lp
		if root then
			dot.Position = toMap(root.Position)
			dot.BackgroundColor3 = col
		end
		card.frame.Visible = p ~= nil
		if p then
			card.badge.BackgroundColor3 = col
			card.name.Text = p.DisplayName
			local downed, recall = p:GetAttribute("BC_Downed"), p:GetAttribute("BC_Recall")
			local hp = (p:GetAttribute("BC_HP") or C.Downed.MaxHP) / C.Downed.MaxHP
			local hurt = hp < 1 or downed or recall
			local compact = calm and not hurt and not p:GetAttribute("BC_Heavy") and not p:GetAttribute("BC_Loaded")
			card.frame.Size = UDim2.fromOffset(compact and 110 or 150, compact and 18 or 22)
			card.hpBg.Visible = not compact
			if downed then
				local left = math.clamp(((p:GetAttribute("BC_BleedEnd") or sNow) - sNow) / C.Downed.BleedOut, 0, 1)
				card.hp.Size = UDim2.fromScale(left, 1) -- bleed-out
				card.hp.BackgroundColor3 = Color3.fromRGB(255, 60, 70)
			elseif recall then
				card.hp.Size = UDim2.fromScale(0, 1)
			else
				card.hp.Size = UDim2.fromScale(hp, 1)
				card.hp.BackgroundColor3 = Color3.fromRGB(90, 230, 120)
			end
			card.heavy.Visible = p:GetAttribute("BC_Heavy") ~= nil or p:GetAttribute("BC_Loaded") == true
			card.heavy.BackgroundTransparency = p:GetAttribute("BC_Loaded") and 0 or 0.5
			card.dot.BackgroundColor3 = STATUS_COL[p:GetAttribute("BC_KartStatus") or "hidden"] or STATUS_COL.hidden
			if p ~= lp then
				tag(p)
			end
		end
	end
	for p, t2 in pairs(tags) do
		if not p.Parent or not p:GetAttribute("BC_Slot") then
			t2:Destroy()
			tags[p] = nil
		end
	end
end

-- Enemy pings: proximity only (no line of sight; cheap). Purge jams the radar.
local function pings(myPos)
	local st = state()
	local purge = st and st:GetAttribute("Tier") == #C.Alarm.Tiers
	local far, full = purge and 20 or 45, purge and 12 or 30
	local n = 0
	local function add(pos)
		local d = (pos - myPos).Magnitude
		if d <= far and n < #HeistHud.pings then
			n += 1
			local e = HeistHud.pings[n]
			local a = math.clamp((far - d) / (far - full), 0, 1)
			if purge and math.random() < 0.3 then
				a *= 0.2 -- flicker
			end
			e.Visible = true
			e.BackgroundTransparency = 1 - a
			e.Position = toMap(pos)
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("BC_Enemy")) do
		local p = m.PrimaryPart
		if p and not m:GetAttribute("Down") then
			add(p.Position)
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("BC_Camera")) do
		local h = m.PrimaryPart
		if h and not m:GetAttribute("Hacked") and not m:GetAttribute("Down") then
			add(h.Position)
		end
	end
	for i = n + 1, #HeistHud.pings do
		HeistHud.pings[i].Visible = false
	end
	return n
end

function HeistHud.init(c)
	ctx = c
	C, Hud = ctx.Config, ctx.Hud
	M = require(ctx.shared.HeistMap)
	local root = Hud.root
	buildMap(root)
	for i = 1, 4 do
		buildCard(root, i)
	end
	buildTop(root)
	buildResults(root)
	local function place()
		HeistHud.map.Position = UDim2.fromOffset(6, 72) -- under the settings gear (top-left, inside safe insets)
		for i = 1, 4 do
			HeistHud.cards[i].frame.Position = UDim2.fromOffset(6, 72 + MAP + 4 + (i - 1) * 24)
		end
		HeistHud.top.Position = UDim2.fromOffset(Hud.W / 2, 4)
		HeistHud.results.frame.Position = UDim2.fromOffset(Hud.W / 2, Hud.H * 0.42)
	end
	ctx.on("rescale", place)
	place()
	ctx.remotes.HeistEvent.OnClientEvent:Connect(function(kind, d)
		if kind == "results" and type(d) == "table" then
			local r = HeistHud.results
			r.title.Text = d.outcome == "done" and "HEIST COMPLETE" or "CREW DOWN"
			r.credits.Text = "+" .. tostring(d.credits or 0) .. " CREDITS"
			local x = d.detail
			r.detail.Text = x and string.format("Loot %d  |  Heavy %s  |  Crew x%d\nReturning to the lobby...", x.small or 0,
				x.outcome and (x.outcome:upper() .. " " .. (x.heavy or 0)) or "none", x.crewSize or 1) or "Returning to the lobby..."
			r.frame.Visible = true
			task.delay(C.Heist.ReturnDelay, function()
				r.frame.Visible = false
			end)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local p = r.Position
			HeistHud.world.Position = UDim2.fromOffset(MAP / 2 - p.X * SCALE, MAP / 2 - p.Z * SCALE)
			local look = workspace.CurrentCamera.CFrame.LookVector
			HeistHud.me.Rotation = math.deg(math.atan2(look.X, -look.Z))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(function()
				refresh()
				local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
				HeistHud.lastPings = r and pings(r.Position) or 0
			end)
			if not ok then
				ctx.Log.warn("HeistHud", err)
			end
		end
	end)
	ctx.probe = ctx.probe or {}
	ctx.probe.hud = function()
		refresh()
		local function rect(g)
			return { g.AbsolutePosition.X, g.AbsolutePosition.Y, g.AbsoluteSize.X, g.AbsoluteSize.Y, g.Visible }
		end
		local cards, colors = {}, {}
		for i = 1, 4 do
			local cd = HeistHud.cards[i]
			if cd.frame.Visible then
				table.insert(cards, rect(cd.frame))
				table.insert(colors, cd.badge.BackgroundColor3:ToHex())
			end
		end
		return { map = rect(HeistHud.map), top = rect(HeistHud.meter), cards = cards, colors = colors, screen = { Hud.gui.AbsoluteSize.X, Hud.gui.AbsoluteSize.Y },
			tier = HeistHud.tier.Text, goal = HeistHud.goal.Text, timer = HeistHud.timer.Visible and HeistHud.timer.Text or nil, pings = HeistHud.lastPings,
			dot = HeistHud.cards[1].dot.BackgroundColor3:ToHex(), results = HeistHud.results.frame.Visible, resultCredits = HeistHud.results.credits.Text,
			tags = (function()
				local n = 0
				for _ in pairs(tags) do
					n += 1
				end
				return n
			end)() }
	end
end

return HeistHud
