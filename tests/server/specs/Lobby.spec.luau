-- Lobby: queue pad logic, teleport adapter (fake TeleportService), and the real pad with the test player.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local C = require(RS.BlackoutCrew.Config)
local Crews = require(RS.BlackoutCrew.Crews)
local Queue = require(RS.BlackoutCrew.Queue)
local Teleport = require(SSS.BlackoutCrew.Teleport)
local S = require(SSS.BlackoutCrew.ServerState)
local L = C.Lobby

local function fakeService(failures)
	local f = { reserved = 0, calls = {}, failures = failures or 0 }
	function f:ReserveServer(placeId)
		self.reserved += 1
		return "code" .. self.reserved
	end
	function f:TeleportAsync(placeId, players, options)
		table.insert(self.calls, { placeId = placeId, players = players, options = options })
		if self.failures > 0 then
			self.failures -= 1
			error("fake teleport failure")
		end
	end
	return f
end

local function adapter(service, studio, onGiveUp)
	local waits = {}
	local t = Teleport.new({ service = service, places = { Lobby = 11, Heist = 22 }, studio = studio, retries = 1, retryDelay = 2,
		wait = function(s)
			table.insert(waits, s)
		end,
		makeOptions = function(code, data)
			return { code = code, data = data }
		end, onGiveUp = onGiveUp })
	return t, waits
end

return function(T)
	-- Queue pad
	local crews = Crews.new(4, 30)
	local q = Queue.new("X", L, crews)
	local a, b, c, d, e = {}, {}, {}, {}, {}
	T.check("join", q:join(a, 0))
	T.near("first join starts countdown", q.deadline, L.Countdown)
	q:join(b, 15)
	T.near("newcomer grace", q.deadline, 15 + L.JoinGrace)
	q:setReady(a, true, 16)
	T.near("not all ready: unchanged", q.deadline, 15 + L.JoinGrace)
	q:setReady(b, true, 16)
	T.near("all ready shortens", q.deadline, 16 + L.ReadyCountdown)
	q:join(c, 17)
	T.check("newcomer unreadies squad", not q:allReady())
	q:join(d, 17)
	T.near("full squad shortens", q.deadline, math.min(17 + L.JoinGrace, 17 + L.FullCountdown))
	local ok, why = q:join(e, 17)
	T.check("5th refused", not ok and why == "full")
	T.check("pad squad is a crew", crews:size(a) == 4 and crews:crewOf(d) == a)
	T.eq("no launch early", q:tick(20), nil)
	T.eq("launch at zero", q:tick(q.deadline), "launch")
	T.eq("launch fires once", q:tick(q.deadline + 1), nil)
	local ok2, why2 = q:join(e, 30)
	T.check("late joiner refused while launching", not ok2 and why2 == "launching")
	T.check("leave ignored while launching", not q:leave(a, 30) and q:has(a))
	local data = q:launchData(function(p)
		return p == a and 1 or p == b and 2 or p == c and 3 or 4
	end)
	T.check("launch data", data.crewSize == 4 and data.difficulty == L.DefaultDifficulty and data.roster[1] == 1 and data.roster[4] == 4)
	q:reset()
	T.check("reset frees crews", #q.members == 0 and crews:crewOf(a) == nil and q.deadline == nil and not q.launching)
	q:join(a, 50)
	q:leave(a, 51)
	T.check("empty pad has no countdown", q.deadline == nil)

	-- Teleport adapter
	local f0 = fakeService(0)
	local tl = adapter(f0, true)
	local okL, modeL = tl:toHeist({ a }, {})
	T.check("studio = local, no calls", not okL and modeL == "local" and #f0.calls == 0 and f0.reserved == 0)
	local tz = adapter(f0, false)
	tz.opts.places = { Lobby = 0, Heist = 0 }
	T.check("place 0 = local", select(2, tz:toHeist({ a }, {})) == "local")

	local f1 = fakeService(0)
	local t1 = adapter(f1, false)
	local ok1, mode1 = t1:toHeist({ a, b }, { crewSize = 2 })
	T.check("live teleport", ok1 and mode1 == "live" and f1.reserved == 1 and #f1.calls == 1)
	T.check("reserved code + data passed", f1.calls[1].options.code == "code1" and f1.calls[1].options.data.crewSize == 2 and f1.calls[1].placeId == 22)

	local f2, waits2 = fakeService(1), nil
	local t2
	t2, waits2 = adapter(f2, false)
	local ok2b = t2:toHeist({ a }, {})
	T.check("sync failure retried once then ok", ok2b and #f2.calls == 2 and #waits2 == 1 and waits2[1] == 2)

	local f3 = fakeService(5)
	local t3 = adapter(f3, false)
	local ok3, mode3 = t3:toHeist({ a }, {})
	T.check("gives up after one retry", not ok3 and mode3 == "failed" and #f3.calls == 2)

	local gaveUp = {}
	local f4 = fakeService(0)
	local t4 = adapter(f4, false, function(players, msg)
		table.insert(gaveUp, players[1])
	end)
	t4:toLobby({ a }, {})
	T.check("lobby return not reserved", f4.reserved == 0 and f4.calls[1].placeId == 11)
	T.eq("async failure retried", t4:initFailed(a, "x"), "retried")
	T.eq("second async failure gives up", t4:initFailed(a, "x"), "gaveUp")
	T.check("give-up callback", gaveUp[1] == a)
	T.eq("unknown player ignored", t4:initFailed(b, "x"), "unknown")

	-- Real pad with the test player (a temporary pad under their feet; the server can't move them).
	local Lobby = S.Lobby
	local player = T.player
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	T.check("lobby built", workspace:FindFirstChild("Lobby") and workspace.Lobby:FindFirstChild("PadA") ~= nil)
	if not (Lobby and root) then
		return
	end
	local part = workspace.Lobby.PadA:Clone()
	part.Name = "PadT"
	part.Position = root.Position - Vector3.new(0, 2.8, 0)
	part.Parent = workspace.Lobby
	Lobby.parts.T = part
	Lobby.pads.T = Queue.new("T", L, Lobby.crews)
	local pad = Lobby.pads.T
	local ok5 = pcall(Lobby.tick, S)
	T.check("standing on pad joins squad", ok5 and pad:has(player) and player:GetAttribute("BC_Pad") == "T")
	T.eq("pad publishes count", part:GetAttribute("Count"), 1)
	pad.deadline = workspace:GetServerTimeNow() - 1
	local nLaunch = #Lobby.launches
	Lobby.tick(S)
	local t0 = os.clock()
	repeat
		task.wait(0.05)
	until #Lobby.launches > nLaunch or os.clock() - t0 > 3
	local last = Lobby.launches[#Lobby.launches]
	T.check("studio launch = local, pad resets", last and last.mode == "local" and #pad.members == 0 and player:GetAttribute("BC_Pad") == nil)

	-- Forced live mode with a failing service: lock handed off, then taken back.
	local real = S.teleport
	local f6 = fakeService(9)
	S.teleport = adapter(f6, false)
	C.Places.Heist = 22
	Lobby.tick(S)
	T.check("rejoin pad", pad:has(player))
	Lobby.launch(S, pad)
	C.Places.Heist = 0
	S.teleport = real
	T.check("failed live launch retried once", #f6.calls == 2)
	T.check("profile lock taken back", S.profiles.loaded[player] ~= nil)
	T.check("pad reset after failure", #pad.members == 0 and not pad.launching)

	Lobby.parts.T, Lobby.pads.T = nil, nil
	part:Destroy()
end
