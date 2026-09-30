-- Smoke-test the SHIPPING place (no test harness): server boots, client reports all modules OK.
local s = Instance.new("Script")
s.Source = [==[
local S = require(game.ServerScriptService.BlackoutCrew.ServerState)
local P = game:GetService("Players")
local t = os.clock()
repeat task.wait(0.2) until (#P:GetPlayers() > 0 and S.clientReports and S.clientReports[P:GetPlayers()[1]]) or os.clock() - t > 40
local p = P:GetPlayers()[1]
local r = p and S.clientReports and S.clientReports[p]
print("BC_SMOKE server=" .. tostring(game.ServerScriptService.BlackoutCrew:GetAttribute("BCServerReady"))
	.. " client=" .. (r and (#r.loaded .. "/" .. tostring(r.expected) .. " failed=" .. #r.failed) or "none")
	.. " gun=" .. tostring(S.Weapons and p and S.Weapons.states[p] and S.Weapons.states[p].gunId)
	.. " range=" .. tostring(workspace:FindFirstChild("Range") ~= nil))
game:GetService("StudioTestService"):EndTest({})
]==]
s.Parent = game.ServerScriptService
game:GetService("StudioTestService"):ExecutePlayModeAsync({})
print("BC_DONE")
