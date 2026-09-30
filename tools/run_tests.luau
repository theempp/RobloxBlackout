-- Studio CLI entry (edit mode): start one Play session; ServerScriptService.BCTests.Runner does the work.
assert(game:GetService("ServerScriptService"):FindFirstChild("BCTests"), "test build missing BCTests")
workspace:SetAttribute("BCTesting", true)
local ok, res = pcall(function()
	return game:GetService("StudioTestService"):ExecutePlayModeAsync({})
end)
print("BC_PLAY", ok and "ended" or ("error " .. tostring(res)))
print("BC_DONE")
