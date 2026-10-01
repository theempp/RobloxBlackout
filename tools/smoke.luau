-- Smoke-test a SHIPPING place (no test harness): server boots, client reports all modules OK, role content exists.
local s = Instance.new("Script")
s.Source = [==[
local S = require(game.ServerScriptService.BlackoutCrew.ServerState)
local P = game:GetService("Players")
local t = os.clock()
repeat task.wait(0.2) until (#P:GetPlayers() > 0 and S.clientReports and S.clientReports[P:GetPlayers()[1]]) or os.clock() - t > 40
local p = P:GetPlayers()[1]
local r = p and S.clientReports and S.clientReports[p]
local role = game.ServerScriptService.BlackoutCrew:GetAttribute("BCRole")
assert(r and #r.failed == 0 and #r.loaded == r.expected, "shipping client failed readiness")
assert(game.ServerScriptService.BlackoutCrew:GetAttribute("BCServerReady"), "shipping server not ready")
local extra
if role == "heist" then
	local t2 = os.clock()
	repeat task.wait(0.2) until (S.Heist and S.Heist.run) or os.clock() - t2 > 15
	extra = " heist=" .. tostring(S.Heist and S.Heist.run ~= nil) .. " karts=" .. tostring(S.karts and #S.karts.list)
		.. " enemies=" .. tostring(S.enemies and S.enemies.alive()) .. " phase=" .. tostring(workspace.HeistState:GetAttribute("Phase"))
else
	assert(S.Garage and workspace:FindFirstChild("Garage"), "shipping garage missing")
	assert(not workspace:FindFirstChild("Range"), "test range shipped")
	assert(not S.Weapons.state(p).loan[2], "range weapon loans leaked into shipping")
	extra = " garage=" .. tostring(workspace:FindFirstChild("Garage") ~= nil) .. " pads=" .. tostring(workspace:FindFirstChild("Lobby") ~= nil)
end
print("BC_SMOKE role=" .. tostring(role) .. " server=" .. tostring(game.ServerScriptService.BlackoutCrew:GetAttribute("BCServerReady"))
	.. " client=" .. (r and (#r.loaded .. "/" .. tostring(r.expected) .. " failed=" .. #r.failed) or "none")
	.. " gun=" .. tostring(S.Weapons and p and S.Weapons.states[p] and S.Weapons.states[p].gunId) .. extra)
game:GetService("StudioTestService"):EndTest({})
]==]
s.Parent = game.ServerScriptService
game:GetService("StudioTestService"):ExecutePlayModeAsync({})
print("BC_DONE")
