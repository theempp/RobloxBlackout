-- Studio CLI entry (edit mode): one Play session with 2 clients; BCTests.Runner runs tests/heist/multi.
assert(game:GetService("ServerScriptService"):FindFirstChild("BCTests"), "test build missing BCTests")
workspace:SetAttribute("BCTesting", true)
workspace:SetAttribute("BCMulti", 2)
local ok, res = pcall(function()
	return game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, {})
end)
print("BC_PLAY", ok and "ended" or ("error " .. tostring(res)))
print("BC_DONE")
