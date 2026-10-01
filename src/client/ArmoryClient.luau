-- Personal armory (revision stage 1): only this player's guns and attachments (the server pushes each profile
-- to its owner alone). LOADOUT: owned and locked blasters, wheel slots 1-3 (swap / remove), 4-5 Coming Soon.
-- BENCH: preview owned attachments; the stat widget compares saved vs preview FINAL stats (StatSheet ->
-- GunStats.resolve). Preview/cancel never touch saved equipment; APPLY is one server-validated request and a
-- rejection or missing ack restores the saved setup. Opened from the loadout terminal or the bench.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Armory = { open = false, tab = "loadout", selected = nil, preview = nil, busy = false, status = "" }
local ctx, C, Hud, Map, StatSheet, GunStats, GunModel
local lp = Players.LocalPlayer
local panel
local GOOD, BAD, TRADE = Color3.fromRGB(34, 130, 62), Color3.fromRGB(186, 52, 52), Color3.fromRGB(36, 104, 168)
local LOCKED_BG = Color3.fromRGB(214, 208, 196)

local function profile()
	return ctx.profile
end
local function saved(gunId)
	local p = profile()
	return p and p.attachments.equipped[gunId] or {}
end
local function owns(gunId)
	local p = profile()
	return p ~= nil and p.guns.owned[gunId] == true
end
local function slotOf(gunId)
	local p = profile()
	return p and table.find(p.guns.loadout, gunId) or nil
end
local function credits(n)
	local s = tostring(n)
	repeat
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end
local function ownedIds()
	local ids = {}
	for _, g in ipairs(C.Guns) do
		if owns(g.id) then
			table.insert(ids, g.id)
		end
	end
	return ids
end

local function label(parent, text, size, x, y, w, h, props)
	local l = Hud.label(parent, text, size, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true })
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

local function setStatus(text)
	Armory.status = text
end

-- Gun preview: the same primitive model as the wall/viewmodel, 3/4 view.
local function gunView(parent, gunId, x, y, w, h)
	local vf = Hud.make("ViewportFrame", parent, { Name = "GunView", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.fromRGB(45, 34, 28), Ambient = Color3.fromRGB(170, 170, 170), LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -0.5) })
	Hud.corner(vf, 10)
	local gun = C.GunsById[gunId]
	if not gun then
		return vf
	end
	local m = GunModel.build(gun)
	m.Parent = vf
	local cf, size = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = size.Magnitude * 1.9 + 0.5
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(1, 0.3, -0.25).Unit * dist, cf.Position)
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf
end

local render

local function request(action, a, b, okText)
	if Armory.busy then
		return
	end
	Armory.busy = true
	setStatus("Saving…")
	render()
	ctx.GarageClient.request(action, a, b, function(ok, why)
		Armory.busy = false
		if action == "setAttachments" then
			Armory.preview = nil -- saved on success; on failure the saved setup is shown again
		end
		if ok then
			setStatus(okText)
		else
			setStatus(ctx.GarageClient.reasonText(why) .. " Showing your saved setup.")
			ctx.Hud.toast(ctx.GarageClient.reasonText(why), 3)
		end
		Armory.lastAck = { action = action, ok = ok, reason = why }
		render()
	end)
end

-- Preview edits (local only; nothing is sent until APPLY).
function Armory.previewSlot(slot, attId)
	local gun = Armory.selected
	if not gun or Armory.busy then
		return false
	end
	local p = profile()
	if attId and not (p and p.attachments.owned[attId]) then
		setStatus("Locked: attachments arrive with the shop update.")
		render()
		return false
	end
	local nextPreview = table.clone(Armory.preview or saved(gun))
	nextPreview[slot] = attId
	Armory.preview = (not StatSheet.same(nextPreview, saved(gun))) and nextPreview or nil
	setStatus(Armory.preview and "Previewing. APPLY saves it, CANCEL drops it." or "")
	render()
	return true
end
function Armory.cancel()
	Armory.preview = nil
	setStatus("Preview cleared. Saved setup unchanged.")
	render()
end
function Armory.apply()
	if Armory.selected and Armory.preview then
		request("setAttachments", Armory.selected, Armory.preview, "Attachments saved.")
	end
end
function Armory.select(gunId)
	if Armory.busy or gunId == Armory.selected then
		return
	end
	if Armory.preview then
		setStatus("Unsaved preview dropped.")
	end
	Armory.selected, Armory.preview = gunId, nil
	render()
end
function Armory.equip(slot)
	local gun = Armory.selected
	local g = gun and C.GunsById[gun]
	if not g then
		return
	end
	if not owns(gun) then
		setStatus(g.name .. " unlocks with the shop update.")
		render()
		return
	end
	if slotOf(gun) == slot then
		setStatus(g.name .. " is already in slot " .. slot .. ".")
		render()
		return
	end
	request("equip", gun, slot, g.name .. " is in slot " .. slot .. ".")
end
function Armory.remove()
	local k = Armory.selected and slotOf(Armory.selected)
	if k then
		request("clear", k, nil, "Slot " .. k .. " emptied.")
	end
end

local function statWidget(x, y, w, h)
	local box = Hud.make("ScrollingFrame", panel, { Name = "Stats", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4 })
	local rows = StatSheet.compare(Armory.selected, saved(Armory.selected), Armory.preview)
	local previewing = Armory.preview ~= nil
	local cw = w - 8
	local cols = previewing and { 0, 0.42, 0.6, 0.78 } or { 0, 0.62 }
	local function line(i, texts, colors, bold, bg)
		local f = Hud.make("Frame", box, { Name = "Row" .. i, Position = UDim2.fromOffset(0, (i - 1) * 17), Size = UDim2.fromOffset(cw, 17),
			BackgroundColor3 = bg or C.UI.Paper, BackgroundTransparency = bg and 0 or 1, BorderSizePixel = 0 })
		for j, t in ipairs(texts) do
			local x0 = cols[j] * cw
			local x1 = (cols[j + 1] or 1) * cw
			Hud.label(f, t, 11, { Name = "C" .. j, Position = UDim2.fromOffset(x0 + 2, 0), Size = UDim2.fromOffset(x1 - x0 - 4, 17),
				TextXAlignment = j == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, TextColor3 = colors and colors[j] or C.UI.Ink,
				Font = (bold or j > 1) and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextTruncate = Enum.TextTruncate.AtEnd })
		end
		return f
	end
	line(1, previewing and { "STAT", "SAVED", "NEW", "CHANGE" } or { "STAT", "SAVED" }, nil, true)
	local tradeoff = false
	for i, r in ipairs(rows or {}) do
		local dirColor = r.dir == "better" and GOOD or r.dir == "worse" and BAD or r.dir == "tradeoff" and TRADE or C.UI.Muted
		tradeoff = tradeoff or r.dir == "tradeoff"
		local name = r.label .. (r.key == "zoom" and " *" or "")
		local f = previewing and line(i + 1, { name, r.curText, r.newText, r.deltaText }, { C.UI.Ink, C.UI.Muted, r.delta ~= 0 and dirColor or C.UI.Ink, dirColor },
			false, r.delta ~= 0 and Color3.fromRGB(255, 236, 200) or nil) or line(i + 1, { name, r.curText })
		f:SetAttribute("Key", r.key)
		f:SetAttribute("Dir", r.dir)
	end
	local note = "* Zoom is a tradeoff: more zoom narrows your view."
	if previewing then
		note = (tradeoff and "Blue = tradeoff. " or "") .. "Green = better, red = worse. " .. note
	end
	Hud.label(box, note, 10, { Name = "Note", Position = UDim2.fromOffset(0, (#(rows or {}) + 1) * 17 + 2), Size = UDim2.fromOffset(cw, 30), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.UI.Muted, Font = Enum.Font.GothamMedium })
	return box, rows
end

function render()
	if not Armory.open or not panel then
		return
	end
	for _, x in ipairs(panel:GetChildren()) do
		if x:IsA("GuiObject") then
			x:Destroy()
		end
	end
	local keep = GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) and GuiService.SelectedObject.Name
	local w, h = math.min(Hud.W - 16, 720), math.min(Hud.H - 12, 330)
	panel.Size = UDim2.fromOffset(w, h)
	local p = profile()
	local bench = Armory.tab == "bench"
	local first
	local tabL = Hud.pill(panel, "TabLoadout", "LOADOUT", 112, 52, bench and C.UI.Paper or C.UI.Orange, { Position = UDim2.fromOffset(8, 8) })
	local tabB = Hud.pill(panel, "TabBench", "BENCH", 100, 52, bench and C.UI.Orange or C.UI.Paper, { Position = UDim2.fromOffset(126, 8) })
	tabL.Activated:Connect(function() Armory.setTab("loadout") end)
	tabB.Activated:Connect(function() Armory.setTab("bench") end)
	label(panel, Armory.status ~= "" and Armory.status or (bench and "ATTACHMENT BENCH · your attachments" or "LOADOUT · your blasters"), 11, 234, 8, w - 234 - 106, 52,
		{ Name = "Status", TextColor3 = C.UI.Muted, TextYAlignment = Enum.TextYAlignment.Center })
	Hud.pill(panel, "Close", "CLOSE", 90, 52, C.UI.Pink, { Position = UDim2.fromOffset(w - 98, 8) }).Activated:Connect(Armory.close)
	if not p then
		label(panel, "Loading your profile…", 14, 8, 70, w - 16, 30)
		return
	end
	local ids = ownedIds()
	if not Armory.selected or not C.GunsById[Armory.selected] or (bench and not owns(Armory.selected)) then
		Armory.selected = (ctx.GunClient and owns(ctx.GunClient.gunId or "") and ctx.GunClient.gunId) or ids[1]
	end
	local gun = Armory.selected and C.GunsById[Armory.selected]
	local top, bodyH = 68, h - 76
	local cx, rw = 196, 236
	local cw = w - rw - 8 - 8 - cx
	-- Left column
	local list = Hud.make("ScrollingFrame", panel, { Name = "List", Position = UDim2.fromOffset(8, top), Size = UDim2.fromOffset(180, bodyH), BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5 })
	local y = 0
	if not bench then
		for _, g in ipairs(C.Guns) do
			local mine = owns(g.id)
			local k = slotOf(g.id)
			local sub = mine and (g.class .. (k and (" · SLOT " .. k) or "")) or (credits(g.price) .. " Credits · shop later")
			local b = Hud.pill(list, "Gun_" .. g.id, g.name:upper() .. "\n" .. sub, 172, 52, g.id == Armory.selected and C.UI.Blue or (mine and C.UI.Paper or LOCKED_BG),
				{ Position = UDim2.fromOffset(0, y), TextSize = 12, TextColor3 = mine and C.UI.Ink or C.UI.Muted })
			b.Activated:Connect(function() Armory.select(g.id) end)
			first = first or b
			y += 58
		end
	elseif gun then
		local owned = p.attachments.owned
		local any = false
		for _, a in ipairs(C.Attachments) do
			any = any or (owned[a.id] == true)
		end
		if not any then
			label(list, "No attachments owned yet. They arrive with the shop update; locked ones are shown for reference.", 11, 0, y, 172, 44, { TextColor3 = C.UI.Muted })
			y += 48
		end
		local cur = Armory.preview or saved(gun.id)
		local keep = saved(gun.id)
		for _, slot in ipairs(gun.slots) do
			label(list, slot:upper() .. (keep[slot] and (" · saved: " .. C.AttachmentsById[keep[slot]].name) or " · saved: none"), 11, 0, y, 172, 16, { Name = "Head_" .. slot })
			y += 18
			local chips = { { id = nil, name = "NONE" } }
			for _, a in ipairs(C.Attachments) do
				if a.slot == slot then
					table.insert(chips, a)
				end
			end
			for i, a in ipairs(chips) do
				local mine = a.id == nil or owned[a.id] == true
				local on = cur[slot] == a.id
				local b = Hud.pill(list, "Chip_" .. slot .. "_" .. (a.id or "none"), a.name .. (mine and "" or "\nLOCKED"), 84, 52,
					on and C.UI.Blue or (mine and C.UI.Paper or LOCKED_BG),
					{ Position = UDim2.fromOffset(((i - 1) % 2) * 88, y + math.floor((i - 1) / 2) * 58), TextSize = 11, TextColor3 = mine and C.UI.Ink or C.UI.Muted })
				b:FindFirstChildOfClass("UIStroke").Thickness = keep[slot] == a.id and 4 or 2
				b.Activated:Connect(function() Armory.previewSlot(slot, a.id) end)
				first = first or b
			end
			y += math.ceil(#chips / 2) * 58 + 4
		end
	end
	-- Centre column
	if gun then
		gunView(panel, gun.id, cx, top, cw, 96)
		label(panel, gun.name:upper(), 15, cx, top + 100, cw, 20, { Name = "GunName", Font = Enum.Font.GothamBlack })
		label(panel, gun.class .. (owns(gun.id) and "" or " · locked"), 11, cx, top + 120, cw, 16, { TextColor3 = C.UI.Muted })
		if bench then
			local function cycle(dir)
				local i = table.find(ids, gun.id) or 1
				Armory.select(ids[(i - 1 + dir) % #ids + 1])
			end
			Hud.pill(panel, "PrevGun", "<", 52, 52, C.UI.Paper, { Position = UDim2.fromOffset(cx, top + 140) }).Activated:Connect(function() cycle(-1) end)
			Hud.pill(panel, "NextGun", ">", 52, 52, C.UI.Paper, { Position = UDim2.fromOffset(cx + cw - 52, top + 140) }).Activated:Connect(function() cycle(1) end)
			local half = (cw - 8) / 2
			local apply = Hud.pill(panel, "Apply", Armory.busy and "SAVING…" or "APPLY", half, 52, Armory.preview and C.UI.Green or LOCKED_BG,
				{ Position = UDim2.fromOffset(cx, h - 60), AutoButtonColor = Armory.preview ~= nil })
			apply.Activated:Connect(Armory.apply)
			Hud.pill(panel, "Cancel", "CANCEL", half, 52, C.UI.Paper, { Position = UDim2.fromOffset(cx + half + 8, h - 60) }).Activated:Connect(Armory.cancel)
		else
			local s = GunStats.resolve(gun.id, saved(gun.id))
			label(panel, string.format("%d dmg · %d rpm · %d rds\n%d studs · reload %.2f s", s.damage * s.pellets, s.rpm, s.mag, s.range, s.reload), 11,
				cx, top + 140, cw, 34, { Name = "QuickStats" })
			local k = slotOf(gun.id)
			if k then
				Hud.pill(panel, "Remove", "REMOVE FROM SLOT " .. k, cw, 52, C.UI.Paper, { Position = UDim2.fromOffset(cx, h - 60) }).Activated:Connect(Armory.remove)
			end
		end
	end
	-- Right column
	if bench and gun then
		statWidget(w - rw - 8, top, rw, bodyH)
	elseif not bench then
		for k = 1, 3 do
			local id = p.guns.loadout[k]
			local g = C.GunsById[id or ""]
			local b = Hud.pill(panel, "Slot" .. k, "SLOT " .. k .. " · " .. (g and g.name:upper() or "EMPTY"), rw, 52,
				(id ~= "" and id == Armory.selected) and C.UI.Green or C.UI.Paper, { Position = UDim2.fromOffset(w - rw - 8, top + (k - 1) * 58) })
			b.Activated:Connect(function() Armory.equip(k) end)
		end
		label(panel, "SLOTS 4–5 · COMING SOON\n" .. (C.Wheel.Slots[4].teaser or ""), 11, w - rw - 8, top + 3 * 58, rw, 34, { TextColor3 = C.UI.Muted })
		label(panel, "Tap a slot to put the selected blaster there. A blaster already in another slot swaps places.", 10, w - rw - 8, top + 3 * 58 + 38, rw, 40,
			{ TextColor3 = C.UI.Muted, Font = Enum.Font.GothamMedium })
	end
	Armory.first = first or tabL
	local again = keep and panel:FindFirstChild(keep, true)
	if again or GuiService.SelectedObject == nil then
		ctx.Menus.focus(again or Armory.first) -- gamepad keeps its place across re-renders
	end
end

function Armory.setTab(tab)
	if Armory.busy or Armory.tab == tab then
		return
	end
	Armory.tab, Armory.preview = tab, nil
	setStatus("")
	render()
	ctx.Menus.focus(Armory.first)
end

function Armory.show(which)
	if ctx.driving or ctx.cutscene then
		return
	end
	ctx.Menus.open("armory", Armory.close)
	Armory.open, Armory.busy, Armory.preview = true, false, nil
	Armory.tab = which == "bench" and "bench" or "loadout"
	setStatus("")
	panel.Visible = true
	render()
	ctx.Menus.focus(Armory.first)
end

function Armory.close()
	if not Armory.open then
		return
	end
	Armory.open, Armory.preview = false, nil
	panel.Visible = false
	ctx.Menus.closed("armory")
end

-- Read-only view of what the widget shows (tests).
function Armory.snapshot()
	local rows = Armory.selected and StatSheet.compare(Armory.selected, saved(Armory.selected), Armory.preview)
	return { open = Armory.open, tab = Armory.tab, selected = Armory.selected, preview = Armory.preview and table.clone(Armory.preview) or nil,
		saved = table.clone(saved(Armory.selected or "")), busy = Armory.busy, status = Armory.status, rows = rows, lastAck = Armory.lastAck }
end

function Armory.init(c)
	ctx, C, Hud = c, c.Config, c.Hud
	Map = require(c.shared.GarageMap)
	StatSheet = require(c.shared.StatSheet)
	GunStats = require(c.shared.GunStats)
	GunModel = require(c.shared.GunModel)
	panel = Hud.make("Frame", Hud.root, { Name = "ArmoryMenu", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 320), Visible = false, ZIndex = 50, Active = true })
	Hud.surface(panel)
	Armory.panel = panel
	ctx.on("profile", function()
		if Armory.open and not Armory.busy then
			if Armory.preview and StatSheet.same(Armory.preview, saved(Armory.selected)) then
				Armory.preview = nil
			end
			render()
		end
	end)
	ctx.on("rescale", function()
		if Armory.open then
			render()
		end
	end)
	ctx.on("driving", function(on)
		if on then
			Armory.close()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if Armory.open then
				local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
				if not root or not Map.armoryNear(root.Position, C.Garage.InteractionRange + 2) then
					Armory.close()
				end
			end
		end
	end)
end

return Armory
