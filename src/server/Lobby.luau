-- Minimal lobby (§11, Build 2): queue pads beside the test range. Stand on a pad = join its squad
-- (a crew); the countdown ends -> release each profile lock, teleport the squad to a reserved Heist
-- server with crew size + difficulty + roster (retry once), re-acquire locks if it fails.
-- Pad state reaches clients as attributes (no per-tick remotes). Occupancy is polled at 4 Hz
-- from root positions (Touched is unreliable for players standing still).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local Crews = require(shared.Crews)
local Queue = require(shared.Queue)
local Log = require(shared.Log)
local L = Config.Lobby

local Lobby = { pads = {}, parts = {}, launches = {}, paused = false } -- paused: tests drive tick() themselves

local function now()
	return workspace:GetServerTimeNow()
end

local function publish(pad)
	local part = Lobby.parts[pad.id]
	local names = {}
	for _, m in ipairs(pad.members) do
		table.insert(names, m.DisplayName)
		m:SetAttribute("BC_Pad", pad.id)
	end
	part:SetAttribute("Count", #pad.members)
	part:SetAttribute("Names", table.concat(names, "\n"))
	part:SetAttribute("Deadline", pad.deadline or 0)
	part:SetAttribute("Launching", pad.launching)
	local ready = 0
	for _, m in ipairs(pad.members) do
		if pad.ready[m] then
			ready += 1
		end
	end
	part:SetAttribute("Ready", ready)
	part:SetAttribute("Difficulty", pad.difficulty)
end

function Lobby.build(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	for _, def in ipairs(L.Pads) do
		local p = Instance.new("Part")
		p.Name = "Pad" .. def.id
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.4, L.PadRadius * 2, L.PadRadius * 2)
		p.CFrame = CFrame.new(def.x, 0.2, def.z) * CFrame.Angles(0, 0, math.rad(90))
		p.Anchored = true
		p.CanCollide = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Config.Colors.Accent
		p.Transparency = 0.35
		p:SetAttribute("PadId", def.id)
		p:SetAttribute("Max", L.MaxSquad)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(160, 40)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
		gui.MaxDistance = 90
		local t = Instance.new("TextLabel")
		t.Name = "Label"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Config.Colors.Text
		t.TextStrokeTransparency = 0.4
		t.Text = "HEIST " .. def.id
		t.Parent = gui
		gui.Parent = p
		p.Parent = folder
		Lobby.parts[def.id] = p
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

local function onPad(root)
	for id, part in pairs(Lobby.parts) do
		local d = root.Position - part.Position
		if Vector2.new(d.X, d.Z).Magnitude <= L.PadRadius and math.abs(d.Y) <= L.PadHeight then
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
			publish(pad)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		local pad = Lobby.padOf(p)
		if pad then
			pad:leave(p, now())
			publish(pad)
		end
		Lobby.crews:remove(p)
		S.teleport:forget(p)
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
