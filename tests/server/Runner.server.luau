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
local clientReport
report.OnServerEvent:Connect(function(_, data)
	clientReport = data
end)

local function finish(summary)
	print("BC_TOTAL", summary)
	pcall(function()
		STS:EndTest({ summary = summary })
	end)
end

local ok, err = pcall(function()
	local deadline = os.clock() + 45
	repeat
		task.wait(0.1)
	until (#Players:GetPlayers() > 0 and Players:GetPlayers()[1].Character) or os.clock() > deadline
	local player = Players:GetPlayers()[1]
	assert(player and player.Character, "no player character within 45s")
	player.Character:WaitForChild("Humanoid")
	repeat
		task.wait(0.1)
	until clientReport or os.clock() > deadline + 30

	local pass, total = 0, 0
	local specs = script.Parent.specs:GetChildren()
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)
	for _, spec in ipairs(specs) do
		local p, t = 0, 0
		local T = { player = player, client = clientReport }
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
		pass += p
		total += t
	end
	if clientReport and clientReport.perf then
		local f = clientReport.perf
		print("BC_PERF", string.format("meanFPS=%.1f p95ms=%.1f frames=%d (Studio CLI; not a phone number)", f.meanFPS, f.p95ms, f.frames))
	end
	finish(pass .. "/" .. total)
end)
if not ok then
	print("BC_FATAL", tostring(err))
	finish("0/0")
end
