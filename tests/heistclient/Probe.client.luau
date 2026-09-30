-- Heist test-build client probe: compile/readiness, HUD touch-target audit, then answers server
-- commands over BCTestCmd (the server can't move a client-owned character; the client can).
if not workspace:GetAttribute("BCTesting") then
	return
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
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

-- Visible touch targets: >= MinTouchPx, on screen, no overlaps.
local function audit()
	local gui = lp.PlayerGui:FindFirstChild("BlackoutCrewHud")
	local out = { hud = gui ~= nil, buttons = 0, small = {}, overlaps = {}, offscreen = {} }
	if not gui then
		return out
	end
	local screen, rects = gui.AbsoluteSize, {}
	for _, b in ipairs(gui:GetDescendants()) do
		if b:IsA("GuiButton") and b:GetAttribute("TouchTarget") and b.Visible and b.AbsoluteSize.X > 0 then
			local shown, a = true, b.Parent
			while a and a ~= gui do
				if a:IsA("GuiObject") and not a.Visible then
					shown = false
				end
				a = a.Parent
			end
			if shown then
				out.buttons += 1
				local s = math.min(b.AbsoluteSize.X, b.AbsoluteSize.Y)
				if s < 44 then
					table.insert(out.small, b.Name .. "=" .. math.floor(s))
				end
				local p0, p1 = b.AbsolutePosition, b.AbsolutePosition + b.AbsoluteSize
				if p0.X < -1 or p0.Y < -1 or p1.X > screen.X + 1 or p1.Y > screen.Y + 1 then
					table.insert(out.offscreen, b.Name)
				end
				for _, r in ipairs(rects) do
					if p0.X < r[3] and p1.X > r[1] and p0.Y < r[4] and p1.Y > r[2] then
						table.insert(out.overlaps, r[5] .. "+" .. b.Name)
					end
				end
				table.insert(rects, { p0.X, p0.Y, p1.X, p1.Y, b.Name })
			end
		end
	end
	out.small, out.overlaps, out.offscreen = table.concat(out.small, ","), table.concat(out.overlaps, ","), table.concat(out.offscreen, ",")
	return out
end
local okA, a = pcall(audit)
data.ui = okA and a or { error = tostring(a) }

-- Short frame probe in the live heist (enemies, drones, karts, HUD) + remote sends/s at idle.
-- Studio CLI numbers are not phone numbers; the harness flags throttled (unfocused) runs as invalid.
do
	local RunService = game:GetService("RunService")
	local cs0 = require(lp.PlayerScripts:WaitForChild("BlackoutCrew"):WaitForChild("ClientState"))
	local samples, total, elapsed, done = {}, 0, 0, false
	local sends0 = cs0.netSends
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
	local t1 = os.clock()
	repeat
		task.wait(0.1)
	until done or os.clock() - t1 > 30
	if #samples > 0 then
		table.sort(samples)
		data.perf = { meanFPS = #samples / total, p95ms = samples[math.ceil(#samples * 0.95)] * 1000, frames = #samples,
			sendsPerSec = (cs0.netSends - sends0) / math.max(total + 1, 1) }
	end
end

-- Server -> probe commands. Each returns a table over BCTestReport as { cmd = name, ... }.
local report = RS:WaitForChild("BCTestReport")
local cs = require(lp.PlayerScripts:WaitForChild("BlackoutCrew"):WaitForChild("ClientState"))
local handlers = {}
function handlers.moveTo(pos)
	local char = lp.Character
	char:PivotTo(CFrame.new(pos))
	char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	return { at = char.HumanoidRootPart.Position }
end
function handlers.audit()
	return audit()
end
function handlers.emit(name, ...)
	cs.emit(name, ...)
	return {}
end
function handlers.eval(key, ...)
	local f = cs.probe and cs.probe[key]
	return f and f(...) or { missing = key }
end
local cmd = RS:WaitForChild("BCTestCmd", 30)
if cmd then
	cmd.OnClientEvent:Connect(function(id, name, ...)
		local ok, res = pcall(handlers[name], ...)
		report:FireServer({ cmdId = id, ok = ok, res = ok and res or tostring(res) })
	end)
end
report:FireServer(data)
