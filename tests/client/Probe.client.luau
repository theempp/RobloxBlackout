-- Test-build client probe: compile/readiness probe, UI size probe, short frame probe, remote flood.
if not workspace:GetAttribute("BCTesting") then
	return
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

local t0 = os.clock()
repeat
	task.wait(0.1)
until lp:GetAttribute("BCClientReady") ~= nil or os.clock() - t0 > 30
local data = {
	ready = lp:GetAttribute("BCClientReady") == true,
	modules = lp:GetAttribute("BCClientModules") or 0,
	expected = lp:GetAttribute("BCClientExpected") or -1,
	failed = lp:GetAttribute("BCClientFailed") or "no report",
}
task.wait(1)

-- UI probe: every visible button in our HUD must be >= MinTouchPx physical pixels.
local ok, err = pcall(function()
	local gui = lp.PlayerGui:FindFirstChild("BlackoutCrewHud")
	data.hud = gui ~= nil
	data.buttons, data.minButton, data.small = 0, math.huge, {}
	if gui then
		for _, b in ipairs(gui:GetDescendants()) do
			if b:IsA("GuiButton") and b.Visible and b:GetAttribute("TouchTarget") then
				local vis = true
				local a = b.Parent
				while a and a ~= gui do
					if a:IsA("GuiObject") and not a.Visible then
						vis = false
					end
					a = a.Parent
				end
				if vis then
					local s = math.min(b.AbsoluteSize.X, b.AbsoluteSize.Y)
					data.buttons += 1
					data.minButton = math.min(data.minButton, s)
					if s < 44 then
						table.insert(data.small, b.Name .. "=" .. math.floor(s))
					end
				end
			end
		end
	end
	data.small = table.concat(data.small, ",")
end)
data.uiError = not ok and tostring(err) or nil

-- Remote flood: 60 Fire events in one frame; the server's rate limiter must drop most of them.
local remotes = RS:FindFirstChild("BlackoutCrew") and RS.BlackoutCrew:FindFirstChild("Remotes")
if remotes and remotes:FindFirstChild("Fire") then
	for i = 1, 60 do
		remotes.Fire:FireServer(1e6 + i, Vector3.zero, Vector3.new(0, 0, -1), false)
	end
	data.flooded = 60
end

-- Frame probe (short in tests; the CLI window is throttled so this is not a phone number).
local samples, total, elapsed = {}, 0, 0
local done = false
local conn
conn = RunService.RenderStepped:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 then
		return
	end
	table.insert(samples, dt)
	total += dt
	if total >= 3 then
		conn:Disconnect()
		done = true
	end
end)
repeat
	task.wait(0.1)
until done or os.clock() - t0 > 60
if #samples > 0 then
	table.sort(samples)
	data.perf = { meanFPS = #samples / total, p95ms = samples[math.ceil(#samples * 0.95)] * 1000, frames = #samples }
end
RS:WaitForChild("BCTestReport"):FireServer(data)
