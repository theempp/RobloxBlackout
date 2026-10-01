-- Lobby queue pads (§11; revision stage 1 presentation). Stand on a raised pad = join its squad (a crew);
-- the countdown ends -> release each profile lock, teleport the squad to a reserved Heist server with crew
-- size + difficulty + roster (retry once), re-acquire locks if it fails.
-- Pad state reaches clients as attributes (no per-tick remotes); each client draws the backboards from
-- them. Standing circles (empty / taken / ready) are recoloured here on change. Occupancy is polled at
-- 4 Hz from root positions inside the platform footprint (Touched is unreliable for players standing still).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local Crews = require(shared.Crews)
local Queue = require(shared.Queue)
local Log = require(shared.Log)
local L = Config.Lobby

local Lobby = { pads = {}, parts = {}, decor = {}, launches = {}, paused = false } -- paused: tests drive tick() themselves

local function now()
	return workspace:GetServerTimeNow()
end

local function publish(pad)
	local part = Lobby.parts[pad.id]
	local names, flags, ids, ready = {}, {}, {}, 0
	for _, m in ipairs(pad.members) do
		table.insert(names, m.DisplayName)
		table.insert(flags, pad.ready[m] and "1" or "0")
		table.insert(ids, tostring(m.UserId))
		m:SetAttribute("BC_Pad", pad.id)
		if pad.ready[m] then
			ready += 1
		end
	end
	part:SetAttribute("Count", #pad.members)
	part:SetAttribute("Names", table.concat(names, "\n"))
	part:SetAttribute("ReadyList", table.concat(flags, "\n")) -- aligned with Names
	part:SetAttribute("Ids", table.concat(ids, "\n"))
	part:SetAttribute("Deadline", pad.deadline or 0)
	part:SetAttribute("Launching", pad.launching)
	part:SetAttribute("Ready", ready)
	part:SetAttribute("Difficulty", pad.difficulty)
	local decor = Lobby.decor[pad.id]
	for i, circle in ipairs(decor and decor.circles or {}) do
		local m = pad.members[i]
		circle.Color = not m and L.Colors.Empty or (pad.ready[m] and L.Colors.Ready or L.Colors.Taken)
	end
end
Lobby.publish = publish

local function piece(parent, name, size, cf, color, shape)
	local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	p.Name, p.Size, p.CFrame, p.Anchored = name, size, cf, true
	p.Material, p.Color, p.CastShadow = Enum.Material.SmoothPlastic, color, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = parent
	return p
end

-- One pad: raised platform (the occupancy part) + ramps (front, outer side), four standing circles, a
-- backboard facing the spawn and a static overhead label. Flat contrasting colours, no neon or lights.
local function buildPad(folder, def)
	local size = L.PadSize
	local base = CFrame.new(def.x, size.Y / 2, def.z)
	local p = piece(folder, "Pad" .. def.id, size, base, L.Colors.Platform)
	p:SetAttribute("PadId", def.id)
	p:SetAttribute("Max", L.MaxSquad)
	p:SetAttribute("Label", def.label or "HEIST")
	p:SetAttribute("Mode", def.mode or "")
	local decor = Instance.new("Model")
	decor.Name = "Decor_" .. def.id
	local h, ramp = size.Y, 3
	piece(decor, "RampFront", Vector3.new(size.X, h, ramp), base * CFrame.new(0, 0, size.Z / 2 + ramp / 2) * CFrame.Angles(0, math.pi, 0), L.Colors.Platform, "Wedge")
	local outer = def.x < Config.Garage.Origin.X and -1 or 1
	piece(decor, "RampSide", Vector3.new(size.Z, h, ramp), base * CFrame.new(outer * (size.X / 2 + ramp / 2), 0, 0) * CFrame.Angles(0, -outer * math.pi / 2, 0),
		L.Colors.Platform, "Wedge")
	local circles = {}
	for i = 1, L.MaxSquad do
		local x = (i - (L.MaxSquad + 1) / 2) * (size.X / (L.MaxSquad + 0.5))
		circles[i] = piece(decor, "Spot" .. i, Vector3.new(0.12, 3.4, 3.4), base * CFrame.new(x, h / 2 + 0.06, 1.5) * CFrame.Angles(0, 0, math.pi / 2),
			L.Colors.Empty, "Cylinder")
		circles[i].CanCollide, circles[i].CanQuery, circles[i].CanTouch = false, false, false
	end
	local back = base * CFrame.new(0, 0, -size.Z / 2 - 0.5)
	for _, side in ipairs({ -1, 1 }) do
		piece(decor, "Post", Vector3.new(0.6, 8.5, 0.6), back * CFrame.new(side * (size.X / 2 - 1), 4.25, 0), L.Colors.Board)
	end
	-- Front face (-Z of the part) turned toward the spawn: clients mount the live SurfaceGui on it.
	local board = piece(decor, "Board", Vector3.new(size.X - 3, 6, 0.4), back * CFrame.new(0, 5, 0) * CFrame.Angles(0, math.pi, 0), L.Colors.Board)
	board.CanQuery, board.CanTouch = false, false
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Size, gui.StudsOffsetWorldSpace = "ModeLabel", UDim2.fromOffset(220, 56), Vector3.new(0, 5, 0)
	gui.MaxDistance, gui.AlwaysOnTop = 120, false
	local t = Instance.new("TextLabel")
	t.Name, t.Size, t.BackgroundTransparency = "Label", UDim2.fromScale(1, 0.62), 1
	t.Font, t.TextScaled, t.TextColor3, t.TextStrokeTransparency = Enum.Font.GothamBlack, true, Config.Colors.Text, 0.3
	t.Text, t.Parent = (def.label or "HEIST") .. " " .. def.id, gui
	local m = t:Clone()
	m.Name, m.Position, m.Size, m.Font = "Mode", UDim2.fromScale(0, 0.62), UDim2.fromScale(1, 0.38), Enum.Font.GothamBold
	m.Text, m.Parent = (def.mode or "") .. " · CREW 1-" .. L.MaxSquad, gui
	gui.Parent = board
	decor.Parent = folder
	Lobby.parts[def.id] = p
	Lobby.decor[def.id] = { model = decor, circles = circles, board = board }
	return p
end

function Lobby.build(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	for _, def in ipairs(L.Pads) do
		buildPad(folder, def)
	end
	folder.Parent = parent or workspace
	return folder
end

function Lobby.padOf(player)
	for _, pad in pairs(Lobby.pads) do
		if pad:has(player) then
			return pad
		end
	end
	return nil
end

-- Inside the platform footprint (+ margin), from just below its top to PadHeight above it.
function Lobby.inside(part, pos)
	local l = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size / 2
	return math.abs(l.X) <= half.X + L.PadMargin and math.abs(l.Z) <= half.Z + L.PadMargin and l.Y >= -L.PadMargin and l.Y <= L.PadHeight
end

local function onPad(root)
	for id, part in pairs(Lobby.parts) do
		if Lobby.inside(part, root.Position) then
			return Lobby.pads[id]
		end
	end
	return nil
end

function Lobby.launch(S, pad)
	local players = table.clone(pad.members)
	local data = pad:launchData(function(p)
		return p.UserId
	end)
	data.runId = HttpService:GenerateGUID(false)
	if S.Garage then
		for _, p in ipairs(players) do S.remotes.GarageEvent:FireClient(p, "depart") end
		task.wait(Config.Garage.CutsceneSeconds)
	end
	local live = S.teleport:mode(Config.Places.Heist) == "live"
	if live then
		for _, p in ipairs(players) do
			S.profiles:save(p, true) -- hand the session lock to the heist server
		end
	end
	local ok, mode, err = S.teleport:toHeist(players, data)
	table.insert(Lobby.launches, { data = data, ok = ok, mode = mode, players = #players })
	if ok then
		Log.info("Lobby", "squad", pad.id, "teleporting", #players)
		task.delay(Config.Teleport.PadResetAfter, function()
			if pad.launching then
				pad:reset()
				publish(pad)
			end
		end)
		return
	end
	for _, p in ipairs(players) do
		if p.Parent then
			if live then
				S.rejoin(p) -- teleport failed after the retry: take the lock back
			end
			S.notify(p, mode == "local" and "Studio: the heist teleport needs published places. Open build/heist.rbxlx to play the heist."
				or "Teleport failed twice. Try again.")
		end
		p:SetAttribute("BC_Pad", nil)
	end
	Log.warn("Lobby", "launch", mode, err)
	pad:reset()
	publish(pad)
end

function Lobby.tick(S)
	local t = now()
	local where = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		where[p] = root and onPad(root) or nil
	end
	for id, pad in pairs(Lobby.pads) do
		local changed = false
		for _, m in ipairs(table.clone(pad.members)) do
			if where[m] ~= pad and pad:leave(m, t) then
				m:SetAttribute("BC_Pad", nil)
				changed = true
			end
		end
		for p, target in pairs(where) do
			if target == pad and not pad:has(p) then
				local ok, why = pad:join(p, t)
				if ok then
					changed = true
				elseif why ~= "inCrew" and (p:GetAttribute("BC_PadRefused") or "") ~= id then
					S.notify(p, why == "full" and "That squad is full." or "That squad is launching. Wait for the next one.")
				end
				p:SetAttribute("BC_PadRefused", not ok and id or nil)
			end
		end
		if pad:tick(t) == "launch" then
			changed = true
			task.spawn(Lobby.launch, S, pad)
		end
		if changed then
			publish(pad)
		end
	end
end

-- Disconnect: leave the pad (the countdown retimes or cancels) and forget crew/teleport state.
function Lobby.drop(S, p)
	local pad = Lobby.padOf(p)
	if pad then
		pad:leave(p, now())
		publish(pad)
	end
	Lobby.crews:remove(p)
	S.teleport:forget(p)
end

function Lobby.init(S)
	Lobby.crews = Crews.new(Config.Crew.MaxSize, Config.Crew.InviteTtl)
	for _, def in ipairs(L.Pads) do
		Lobby.pads[def.id] = Queue.new(def.id, L, Lobby.crews)
	end
	Lobby.build(workspace)
	for _, pad in pairs(Lobby.pads) do
		publish(pad)
	end
	S.Remotes.bind(S.remotes, "Queue", function(player, action, on)
		local pad = Lobby.padOf(player)
		if pad and action == "ready" then
			pad:setReady(player, on == true, now())
			if on == true and S.Garage and player:GetAttribute("BC_Tutorial") == "queue" then S.Garage.finish(player) end
			publish(pad)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		Lobby.drop(S, p)
	end)
	task.spawn(function()
		while true do
			task.wait(L.Tick)
			local ok, err = true, nil
			if not Lobby.paused then
				ok, err = pcall(Lobby.tick, S)
			end
			if not ok then
				Log.warn("Lobby", "tick", err)
			end
		end
	end)
end

return Lobby
