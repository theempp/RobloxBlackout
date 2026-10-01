-- Test runner (test build only). Runs every spec in BCTests.specs inside one Play session,
-- prints BC_SUITE <name> pass/total, BC_FAIL lines and BC_TOTAL, then ends the Play test.
if not workspace:GetAttribute("BCTesting") then
	return
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local STS = game:GetService("StudioTestService")

-- Client probe reports arrive here (compile probe, UI probe, frame probe).
local report = Instance.new("RemoteEvent")
report.Name = "BCTestReport"
report.Parent = RS
-- Server -> probe commands (heist probe): T.cmd(name, ...) waits for the matching reply.
local cmd = Instance.new("RemoteEvent")
cmd.Name = "BCTestCmd"
cmd.Parent = RS
local multi = workspace:GetAttribute("BCMulti") -- 2-client run (tools/run_multi.luau)
local reports = {}
local replies, nextId = {}, 0
report.OnServerEvent:Connect(function(plr, data)
	if type(data) == "table" and data.cmdId then
		replies[data.cmdId] = data
	else
		reports[plr] = data
	end
end)
if multi then
	pcall(function() -- gather every client before the local session starts (no one is a late joiner)
		require(game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew"):WaitForChild("Config")).Heist.LocalStartDelay = 60
	end)
end

local function finish(summary)
	print("BC_TOTAL", summary)
	pcall(function()
		STS:EndTest({ summary = summary })
	end)
end

local ok, err = pcall(function()
	local need = multi or 1
	local deadline = os.clock() + (multi and 90 or 45)
	local function ready()
		local list = Players:GetPlayers()
		if #list < need then
			return false
		end
		for _, p in ipairs(list) do
			if not p.Character or not reports[p] then
				return false
			end
		end
		return true
	end
	repeat
		task.wait(0.1)
	until ready() or os.clock() > deadline
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	local player = players[1]
	assert(player and player.Character, "no player character in time")
	player.Character:WaitForChild("Humanoid")
	player.Character:WaitForChild("Head")
	local clientReport = reports[player]
	if multi then
		pcall(function()
			local S = require(game:GetService("ServerScriptService").BlackoutCrew.ServerState)
			if S.session and S.session.state == "waiting" then
				S.session:start()
			end
		end)
	end

	local pass, total = 0, 0
	local specs = (multi and script.Parent:FindFirstChild("multi") or script.Parent.specs):GetChildren()
	local only = script.Parent:FindFirstChild("Only") -- tools/test.py --spec A,B (iteration runs)
	if only and not multi then
		local keep = {}
		for _, s in ipairs(specs) do
			if table.find(string.split(only.Value, ","), (s.Name:gsub("%.spec$", ""))) then
				table.insert(keep, s)
			end
		end
		specs = keep
	end
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)
	for _, spec in ipairs(specs) do
		local p, t = 0, 0
		local T = { player = player, client = clientReport, players = players, clients = reports }
		function T.cmdTo(target, name, ...)
			nextId += 1
			local id = nextId
			cmd:FireClient(target, id, name, ...)
			local t = os.clock()
			repeat
				task.wait(0.05)
			until replies[id] or os.clock() - t > 8
			local r = replies[id]
			return r ~= nil and r.ok, r and r.res
		end
		function T.cmd(name, ...)
			return T.cmdTo(player, name, ...)
		end
		function T.check(name, cond, detail)
			t += 1
			if cond then
				p += 1
			else
				print("BC_FAIL", spec.Name .. ":", name, detail ~= nil and ("(" .. tostring(detail) .. ")") or "")
			end
			return cond
		end
		function T.eq(name, got, want)
			return T.check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
		end
		function T.near(name, got, want, eps)
			return T.check(name, type(got) == "number" and math.abs(got - want) <= (eps or 1e-6),
				"got " .. tostring(got) .. ", want " .. tostring(want))
		end
		local okSpec, e = pcall(function()
			require(spec)(T)
		end)
		if not okSpec then
			t += 1
			print("BC_FAIL", spec.Name .. ": crashed", tostring(e))
		end
		print("BC_SUITE", spec.Name, p .. "/" .. t)
		pcall(function() -- a crashed spec must not leave a system's loop paused for the next one
			local S = require(game:GetService("ServerScriptService").BlackoutCrew.ServerState)
			if S.Heist then
				S.Heist.paused = false
			end
			if S.Lobby then
				S.Lobby.paused = false
			end
		end)
		pass += p
		total += t
	end
	if clientReport and clientReport.perf then
		local f = clientReport.perf
		print("BC_PERF", string.format("meanFPS=%.1f p95ms=%.1f frames=%d%s (Studio CLI; not a phone number)", f.meanFPS, f.p95ms, f.frames,
			f.sendsPerSec and string.format(" idleSends/s=%.2f", f.sendsPerSec) or ""))
	end
	finish(pass .. "/" .. total)
end)
if not ok then
	print("BC_FATAL", tostring(err))
	finish("0/0")
end
