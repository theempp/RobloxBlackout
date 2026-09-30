-- Heist place orchestrator: session (roster, late joiners) -> run -> payout -> save -> return.
-- Systems plug in through Heist.systems: each may define start(S, run), tick(S, run, dt), stop(S, run).
-- One 10 Hz server loop drives everything (no per-system Heartbeat connections).
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local Log = require(shared.Log)
local Payout = require(shared.Payout)
local Twists = require(shared.Twists)
local Session = require(script.Parent.Session)
local H = Config.Heist

local Heist = { systems = {}, run = nil, results = {}, paused = false } -- paused: specs drive ticks themselves

local function now()
	return workspace:GetServerTimeNow()
end

function Heist.state()
	return workspace:FindFirstChild("HeistState")
end

-- Run-wide values the HUD reads (attributes replicate; no per-tick remotes).
function Heist.set(key, value)
	Heist.state():SetAttribute(key, value)
end

local function newSession(S)
	S.session = Session.new({
		now = os.clock,
		onStart = function(players, info)
			Heist.start(S, players, info)
		end,
		onSkip = function(player, why)
			Heist.skip(S, player, why)
		end,
	})
end

function Heist.skip(S, player, why)
	player:SetAttribute("BC_Skipped", why)
	S.notify(player, "This heist already started. Sending you back to the lobby.")
	task.delay(2, function()
		if not player.Parent then
			return
		end
		local ok, mode = S.teleport:toLobby({ player }, {})
		if not ok and mode ~= "local" then
			player:Kick("This heist already started.")
		end
	end)
end

function Heist.start(S, players, info)
	local run = { players = players, info = info, started = now(), slot = {}, ended = false, outcome = nil }
	run.twist = Twists.pick(Twists.seed(info.runId), Config.Twists)
	run.params = Twists.apply({ alarmMult = 1, sentryMult = 1, visionMult = 1, bumpMult = {} }, run.twist and Config.Twists[run.twist])
	for i, p in ipairs(players) do
		run.slot[p] = i
		p:SetAttribute("BC_Slot", i)
	end
	Heist.run = run
	Heist.set("Phase", "running")
	Heist.set("CrewSize", info.crewSize)
	Heist.set("Difficulty", info.difficulty)
	Heist.set("Started", run.started)
	Heist.set("Twist", run.twist and Config.Twists[run.twist].name or "")
	for _, sys in ipairs(Heist.systems) do
		if sys.start then
			sys.start(S, run)
		end
	end
	Log.info("Heist", "run", info.runId, "crew", info.crewSize, info.live and "live" or "local")
end

-- End the run: outcome = "done" | "failed". amounts = { [player] = credits } (Payout system fills it).
function Heist.finish(S, outcome, amounts, detail)
	local run = Heist.run
	if not run or run.ended then
		return nil -- idempotent: a second finish never pays twice
	end
	run.ended, run.outcome = true, outcome
	for _, sys in ipairs(Heist.systems) do
		if sys.stop then
			sys.stop(S, run)
		end
	end
	local granted = S.session:grant(S.profiles, amounts or {})
	Heist.set("Phase", outcome)
	for p, amt in pairs(granted) do
		task.spawn(function()
			S.profiles:save(p, false) -- save at run end, not on the next autosave
			S.pushProfile(p)
		end)
		S.remotes.HeistEvent:FireClient(p, "results", { outcome = outcome, credits = amt, detail = detail and detail[p] })
	end
	table.insert(Heist.results, { outcome = outcome, granted = granted })
	task.delay(H.ReturnDelay, Heist.returnToLobby, S)
	return granted
end

-- Per-player credits. heavyOutcome(player, item) -> "clean" | "rough" | "timeout" | "caught" | nil.
function Heist.amounts(run, heavyOutcome)
	local amounts, detail = {}, {}
	local diff = (Config.Difficulty[run.info.difficulty] or Config.Difficulty.normal).payout
	for _, p in ipairs(run.players) do
		local item = run.loot and (run.loot.loaded[p] or run.loot.heavyOf[p])
		local d = { small = run.loot and run.loot.small[p] or 0, heavy = item and item:GetAttribute("Value") or 0,
			outcome = item and heavyOutcome(p, item) or nil, crewSize = run.info.crewSize, difficulty = diff }
		amounts[p] = Payout.compute(d, Config.Payout, Config.Crew)
		detail[p] = d
	end
	return amounts, detail
end

-- Crew wiped (§5c): small loot still pays 100%; heavy loot you held or loaded counts as "caught" (50%).
function Heist.fail(S, why)
	local run = Heist.run
	if not run or run.ended then
		return nil
	end
	run.failReason = why
	local amounts, detail = Heist.amounts(run, function()
		return "caught"
	end)
	return Heist.finish(S, "failed", amounts, detail)
end

function Heist.returnToLobby(S)
	local players = table.clone(S.session.players)
	if S.teleport:mode(Config.Places.Lobby) == "live" then
		for _, p in ipairs(players) do
			S.profiles:save(p, true) -- hand the lock back to the lobby server
		end
		local roster = {}
		for _, p in ipairs(players) do
			table.insert(roster, p.UserId)
		end
		local ok = S.teleport:toLobby(players, { crew = roster })
		if not ok then
			for _, p in ipairs(players) do
				S.rejoin(p)
				S.notify(p, "Couldn't reach the lobby. Leave from the menu; your Credits are saved.")
			end
		end
		return
	end
	Heist.reset(S) -- local: go again without publishing
end

function Heist.reset(S)
	Heist.run = nil
	Heist.set("Phase", "waiting")
	for _, sys in ipairs(Heist.systems) do
		if sys.reset then
			sys.reset(S)
		end
	end
	newSession(S)
	for _, p in ipairs(Players:GetPlayers()) do
		if S.profiles.loaded[p] then
			p:SetAttribute("BC_Skipped", nil)
			S.session:arrive(p, nil)
		end
	end
end

function Heist.init(S)
	local state = Instance.new("Folder")
	state.Name = "HeistState"
	state.Parent = workspace
	Heist.set("Phase", "waiting")
	for _, name in ipairs(H.Systems) do
		table.insert(Heist.systems, require(script.Parent[name]))
	end
	for _, sys in ipairs(Heist.systems) do
		if sys.init then
			sys.init(S, Heist)
		end
	end
	newSession(S)
	table.insert(S.onJoin, function(player)
		local data = player:GetJoinData()
		S.session:arrive(player, type(data) == "table" and data.TeleportData or nil)
	end)
	S.onTeleportGiveUp = function(players)
		for _, p in ipairs(players) do
			S.rejoin(p)
		end
	end
	Players.PlayerRemoving:Connect(function(p)
		S.session:leave(p)
		S.teleport:forget(p)
		local run = Heist.run
		if run and not run.ended then
			for _, sys in ipairs(Heist.systems) do
				if sys.leave then
					sys.leave(S, run, p)
				end
			end
			local i = table.find(run.players, p)
			if i then
				table.remove(run.players, i) -- nobody waits on (or wipes because of) a player who left
			end
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(H.Tick)
			local t = os.clock()
			local dt = math.min(t - last, 0.5)
			last = t
			local ok, err = pcall(function()
				if Heist.paused then
					return
				end
				S.session:tick()
				local run = Heist.run
				if run and not run.ended then
					for _, sys in ipairs(Heist.systems) do
						if sys.tick then
							sys.tick(S, run, dt)
						end
					end
				end
			end)
			if not ok then
				Log.warn("Heist", "tick", err)
			end
		end
	end)
end

return Heist
