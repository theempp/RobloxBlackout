-- Lobby HUD (owner reference refs/hud/lobby-hud-reference.jpg), same matte plates as the heist HUD v2 (HudV2 helpers,
-- Config.HudRef.Colors; layout in Config.LobbyHud). Real data only:
--   top-left      player card: headshot, LVL = season tier (Economy.tier), XP inside the tier; SHOP / VIP / INVENTORY
--   top-right     Credits + Glitch Coins pills (Glitch "+" greyed: paid actions are off); SETTINGS + FRIENDS
--   bottom-left   DAILY REWARD plate with the live countdown -> opens DailyRewardUI (claim goes to DailyService)
--   bottom-centre squad row: you + the crew you are in (BC_CrewLeader/Index from Social), "+" opens the invite panel
--   bottom-right  CURRENT CONTRACT: your queue pad's heist + status, else a neutral line
-- VIP is visibly unavailable. Hidden while a menu is open or you are driving; the bottom row steps aside for the
-- tutorial card. Text refreshes at 2 Hz (timer at 1 s resolution); nothing runs per frame.
local Players = game:GetService("Players")

local LobbyHud = { buttons = {}, slots = {} }
local ctx, C, H, K, L, HudV2, D, E, HudScale
local lp = Players.LocalPlayer

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function clock(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%02d:%02d:%02d", sec // 3600, sec % 3600 // 60, sec % 60)
end

-- LVL mapping (stated in refs/hud/NOTES.md): LVL = Economy.tier = floor(xp / XpPerTier), 0..40; the bar shows XP inside it.
function LobbyHud.level(p)
	local xp = p and p.progress and p.progress.xp or 0
	local tier = E.tier({ progress = { xp = xp } })
	local per = C.Economy.XpPerTier
	if tier >= 40 then
		return tier, 1, "MAX"
	end
	local into = xp - tier * per
	return tier, into / per, string.format("%s / %s XP", comma(into), comma(per))
end

local function crew()
	local leader = lp:GetAttribute("BC_CrewLeader")
	local list = {}
	if leader then
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("BC_CrewLeader") == leader then
				table.insert(list, p)
			end
		end
		table.sort(list, function(a, b)
			return (a:GetAttribute("BC_CrewIndex") or 9) < (b:GetAttribute("BC_CrewIndex") or 9)
		end)
	end
	if not table.find(list, lp) then
		table.insert(list, 1, lp)
	end
	return list
end

local function caption(parent, text)
	return HudV2.label(H, K, parent, text, 7, { Name = "Caption", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(50, 9) })
end

local function build()
	local root = H.make("Frame", H.root, { Name = "LobbyHud", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	LobbyHud.root = root
	local B = LobbyHud.buttons

	-- player card
	local cd = L.Card
	local card = HudV2.plate(H, K, root, { Name = "PlayerCard", Position = UDim2.fromOffset(cd.x, cd.y + (cd.avatar - cd.h) / 2), Size = UDim2.fromOffset(cd.w, cd.h) }, 8)
	local av = H.make("Frame", root, { Name = "Avatar", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cd.x, cd.y + cd.avatar / 2), Size = UDim2.fromOffset(cd.avatar, cd.avatar),
		BackgroundColor3 = K.Edge, BorderSizePixel = 0, ZIndex = 3 })
	H.corner(av, UDim.new(0.5, 0))
	H.stroke(av, K.Rim, 1, 0.3)
	local face = H.make("ImageLabel", av, { Name = "Face", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundColor3 = Color3.fromRGB(60, 60, 64), BorderSizePixel = 0, ZIndex = 4,
		Image = lp.UserId > 0 and string.format(HudV2.THUMB, lp.UserId) or "" })
	H.corner(face, UDim.new(0.5, 0))
	local x0 = cd.avatar / 2 + 6
	HudV2.label(H, K, card, "LVL", 9, { Position = UDim2.fromOffset(x0, 4), Size = UDim2.fromOffset(22, 14), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = K.Muted, ZIndex = 2 })
	LobbyHud.lvl = HudV2.label(H, K, card, "0", 15, { Name = "Level", Position = UDim2.fromOffset(x0 + 22, 2), Size = UDim2.fromOffset(40, 17), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 })
	local track = H.make("Frame", card, { Position = UDim2.fromOffset(x0, 23), Size = UDim2.new(1, -x0 - 8, 0, 5), BackgroundColor3 = K.Edge, BorderSizePixel = 0, ZIndex = 2 })
	H.corner(track, 2)
	LobbyHud.xpFill = H.make("Frame", track, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = K.Bar, BorderSizePixel = 0, ZIndex = 3 })
	H.corner(LobbyHud.xpFill, 2)
	LobbyHud.xpText = HudV2.label(H, K, card, "", 7, { Name = "Xp", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 29), Size = UDim2.fromOffset(90, 9),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = K.Muted, Font = Enum.Font.GothamBold, ZIndex = 2 })

	-- round buttons: left column + right row
	local function round(name, text, caps)
		local b = HudV2.round(H, K, root, name, text, L.Column.d, UDim2.new(), "")
		b.TextSize = caps and 9 or 7
		if caps then
			caption(b, caps)
		end
		B[name] = b
		return b
	end
	round("shop", "SHOP", "SHOP")
	round("vip", "VIP", "VIP")
	round("inventory", "BAG", "INVENTORY")
	round("settings", "SETTINGS") -- the Jump button sits right under this row: label inside, no caption
	round("friends", "FRIENDS")
	if L.VipSoon then
		B.vip.BackgroundTransparency, B.vip.TextTransparency = 0.55, 0.55
		B.vip:SetAttribute("Soon", true)
	end

	-- currency pills
	local P = L.Pills
	local function pill(name, y, glyph)
		local f = HudV2.plate(H, K, root, { Name = name, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, y), Size = UDim2.fromOffset(P.w, P.h) }, 7)
		HudV2.label(H, K, f, glyph, 11, { Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(18, P.h), TextColor3 = K.Muted, ZIndex = 2 })
		return f, HudV2.label(H, K, f, "0", 13, { Name = "Amount", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(1, -30, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2 })
	end
	local _, credits = pill("Credits", P.y, "$")
	local glitch, coins = pill("GlitchCoins", P.y + P.h + P.gap, "◎")
	coins.Position = UDim2.new(1, -24, 0, 0)
	HudV2.label(H, K, glitch, "+", 14, { Name = "Plus", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(14, 14), TextColor3 = K.Muted,
		TextTransparency = 0.5, ZIndex = 2 }) -- paid top-up is off in the private test: greyed, not a button
	LobbyHud.credits, LobbyHud.coins = credits, coins

	-- bottom row
	local bottom = H.make("Frame", root, { Name = "Bottom", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	LobbyHud.bottom = bottom
	local dl = L.Daily
	local daily = HudV2.plate(H, K, bottom, { Name = "Daily", AnchorPoint = Vector2.new(0, 1), Text = "", AutoButtonColor = false, Selectable = true }, 8, "TextButton")
	daily:SetAttribute("TouchTarget", true)
	local gift = H.make("Frame", daily, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(dl.icon, dl.icon), BackgroundColor3 = K.Button,
		BorderSizePixel = 0, ZIndex = 3 })
	H.corner(gift, UDim.new(0.5, 0))
	H.stroke(gift, K.Edge, 3, 0)
	HudV2.label(H, K, gift, "GIFT", 8, { Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	HudV2.label(H, K, daily, "DAILY REWARD", 10, { Position = UDim2.fromOffset(dl.icon / 2 + 6, 5), Size = UDim2.new(1, -dl.icon / 2 - 10, 0, 13), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 })
	LobbyHud.dailyTimer = HudV2.label(H, K, daily, "", 10, { Name = "Timer", Position = UDim2.fromOffset(dl.icon / 2 + 6, 20), Size = UDim2.new(1, -dl.icon / 2 - 10, 0, 13),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = K.Muted, Font = Enum.Font.GothamBold, ZIndex = 2 })
	B.daily = daily

	for i = 1, C.Crew.MaxSize do
		local b = HudV2.round(H, K, bottom, "Squad" .. i, "+", L.Squad.d, UDim2.new(), "")
		b.TextSize = 18
		local f = H.make("ImageLabel", b, { Name = "Face", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, ZIndex = 3, Visible = false })
		H.corner(f, UDim.new(0.5, 0))
		LobbyHud.slots[i] = { button = b, face = f }
	end

	local ct = L.Contract
	local contract = HudV2.plate(H, K, bottom, { Name = "Contract", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -ct.y), Size = UDim2.fromOffset(ct.w, ct.h) }, 8)
	HudV2.label(H, K, contract, "CURRENT CONTRACT", 8, { Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -14, 0, 11), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 })
	local gem = H.make("Frame", contract, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(12, 28), Size = UDim2.fromOffset(6, 6), Rotation = 45, BackgroundTransparency = 1, ZIndex = 2 })
	H.stroke(gem, K.Ink, 1.5, 0)
	LobbyHud.contract = HudV2.label(H, K, contract, "", 8, { Name = "Line", Position = UDim2.fromOffset(20, 22), Size = UDim2.new(1, -24, 0, 12), TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 })
	LobbyHud.contractPlate = contract
end

-- Sizes that are touch targets grow to >= MinTouchPx physical pixels at small HUD scales (HudScale.touchSize).
function LobbyHud.layout()
	local S, W, Hh = H.S or 1, H.W or 800, H.H or 340
	local B = LobbyHud.buttons
	local col = L.Column
	local d = HudScale.touchSize(col.d, S, 1)
	local step = math.max(col.step, d + 14)
	for i, id in ipairs({ "shop", "vip", "inventory" }) do
		B[id].Size = UDim2.fromOffset(d, d)
		B[id].Position = UDim2.fromOffset(col.x, col.y + (i - 1) * step)
	end
	local r = L.Right
	local rd = HudScale.touchSize(r.d, S, 1)
	for i, id in ipairs({ "settings", "friends" }) do
		B[id].Size = UDim2.fromOffset(rd, rd)
		B[id].Position = UDim2.fromOffset(W - r.x - (i - 1) * math.max(r.step, rd + 8), r.y)
	end
	local dl = L.Daily
	local dh = HudScale.touchSize(dl.h, S, 1)
	B.daily.Size = UDim2.fromOffset(dl.w, dh)
	B.daily.Position = UDim2.new(0, dl.x + dl.icon / 2, 1, -dl.y)
	local sq = L.Squad
	local sd = HudScale.touchSize(sq.d, S, 1)
	local sstep = math.max(sq.step, sd + 4)
	local n = #LobbyHud.slots
	for i, s in ipairs(LobbyHud.slots) do
		s.button.Size = UDim2.fromOffset(sd, sd)
		s.button.Position = UDim2.fromOffset(W * sq.cx + (i - (n + 1) / 2) * sstep, Hh - sq.y - sd / 2)
	end
	LobbyHud.contractPlate.Size = UDim2.fromOffset(L.Contract.w, math.max(L.Contract.h, dh))
end

function LobbyHud.refresh()
	local p = ctx.profile
	local tier, frac, text = LobbyHud.level(p)
	LobbyHud.lvl.Text = tostring(tier)
	LobbyHud.xpFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	LobbyHud.xpText.Text = text
	LobbyHud.credits.Text = comma(p and p.credits or 0)
	LobbyHud.coins.Text = comma(p and p.glitchCoins or 0)
	-- daily
	if p and p.daily then
		local v = D.view(p, workspace:GetServerTimeNow())
		LobbyHud.dailyTimer.Text = v.canClaim and "CLAIM NOW" or clock(v.secondsLeft)
		LobbyHud.dailyTimer.TextColor3 = v.canClaim and C.DailyReward.Colors.Gold or K.Muted
	else
		LobbyHud.dailyTimer.Text = "--:--:--"
	end
	-- squad
	local list = crew()
	for i, s in ipairs(LobbyHud.slots) do
		local m = list[i]
		local image = m and m.UserId > 0 and string.format(HudV2.THUMB, m.UserId) or ""
		s.face.Visible = m ~= nil
		if s.face.Image ~= image then
			s.face.Image = image
		end
		s.button.Text = m and "" or "+"
		s.button:SetAttribute("Member", m and m.Name or nil)
	end
	-- contract
	local pad = lp:GetAttribute("BC_Pad")
	local st = pad and ctx.LobbyClient and ctx.LobbyClient.state(pad)
	LobbyHud.contract.Text = st and (st.label .. " · " .. st.status) or L.Neutral
	-- visibility
	local hidden = ctx.Menus.current ~= nil or ctx.driving == true
	LobbyHud.root.Visible = not hidden
	local tutorial = H.root:FindFirstChild("Tutorial")
	LobbyHud.bottom.Visible = not (tutorial and tutorial.Visible)
end

function LobbyHud.init(c)
	ctx = c
	C, H = ctx.Config, ctx.Hud
	K, L = C.HudRef.Colors, C.LobbyHud
	HudV2 = require(script.Parent.HudV2)
	D, E = require(ctx.shared.DailyReward), require(ctx.shared.Economy)
	HudScale = require(ctx.shared.HudScale)
	build()
	local B = LobbyHud.buttons
	B.shop.Activated:Connect(function()
		ctx.ShopClient.set(not ctx.ShopClient.open)
	end)
	B.vip.Activated:Connect(function()
		H.toast("VIP is unavailable in the private test", 2)
	end)
	-- The armory is a bench in the garage (it closes itself out of range and the server range-checks it), so
	-- INVENTORY opens it there and points the way elsewhere. Owner question: open it anywhere instead?
	local Map = require(ctx.shared.GarageMap)
	B.inventory.Activated:Connect(function()
		local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if root and Map.armoryNear(root.Position, C.Garage.InteractionRange) then
			ctx.ArmoryClient.show("loadout")
		else
			H.toast("Inventory opens at the armory bench", 2)
		end
	end)
	B.settings.Activated:Connect(function()
		ctx.emit("toggleSettings")
	end)
	local function social()
		ctx.SocialClient.open()
	end
	B.friends.Activated:Connect(social)
	for i, s in ipairs(LobbyHud.slots) do
		s.button.Activated:Connect(function()
			if i > 1 then
				social()
			end
		end)
	end

	-- Daily reward: the plate opens the screen; CLAIM sends only the request (DailyService decides everything).
	local UI = ctx.DailyRewardUI
	local function view()
		return ctx.profile and ctx.profile.daily and D.view(ctx.profile, workspace:GetServerTimeNow()) or nil
	end
	B.daily.Activated:Connect(function()
		UI.show(view())
	end)
	UI.onClaim = function()
		ctx.remotes.DailyClaim:FireServer()
		ctx.netSends += 1
	end
	ctx.remotes.DailyEvent.OnClientEvent:Connect(function(ok, message)
		LobbyHud.lastDaily = { ok = ok == true, message = message }
		if UI.open then
			UI.claimed(ok == true, type(message) == "string" and message or nil, view())
		elseif type(message) == "string" then
			H.toast(message, 3)
		end
		LobbyHud.refresh()
	end)

	ctx.on("rescale", LobbyHud.layout)
	ctx.on("profile", LobbyHud.refresh)
	ctx.on("menu", LobbyHud.refresh)
	ctx.on("driving", LobbyHud.refresh)
	LobbyHud.layout()
	LobbyHud.refresh()
	task.spawn(function()
		while true do
			task.wait(0.5)
			pcall(LobbyHud.refresh)
		end
	end)

	ctx.probe = ctx.probe or {}
	ctx.probe.lobbyHud = function(command)
		if command == "claim" then
			UI.onClaim()
			return true
		end
		LobbyHud.refresh()
		local function rect(g)
			return { g.AbsolutePosition.X, g.AbsolutePosition.Y, g.AbsoluteSize.X, g.AbsoluteSize.Y, g.Visible }
		end
		local out = { visible = LobbyHud.root.Visible, screen = { H.gui.AbsoluteSize.X, H.gui.AbsoluteSize.Y }, lvl = LobbyHud.lvl.Text, xp = LobbyHud.xpText.Text,
			credits = LobbyHud.credits.Text, coins = LobbyHud.coins.Text, daily = LobbyHud.dailyTimer.Text, contract = LobbyHud.contract.Text,
			vipSoon = B.vip:GetAttribute("Soon") == true, card = rect(LobbyHud.root.PlayerCard), contractRect = rect(LobbyHud.contractPlate), rects = {},
			gear = H.root:FindFirstChild("SettingsButton") ~= nil, oldShop = H.root:FindFirstChild("ShopButton") ~= nil, oldSocial = H.root:FindFirstChild("SocialButton") ~= nil,
			ammo = rect(H.ammoPanel), lastDaily = LobbyHud.lastDaily, claims = ctx.profile and ctx.profile.daily and ctx.profile.daily.claims, members = {} }
		for id, b in pairs(B) do
			out.rects[id] = rect(b)
		end
		for i, s in ipairs(LobbyHud.slots) do
			out.rects["squad" .. i] = rect(s.button)
			out.members[i] = s.button:GetAttribute("Member") or false
		end
		return out
	end
end

return LobbyHud
