-- Which place this build is: "lobby" or "heist". Baked into each place file by its project
-- (ReplicatedStorage.BCPlace StringValue), so it works in Studio where PlaceId is 0.
local Place = {}

function Place.role()
	local v = game:GetService("ReplicatedStorage"):FindFirstChild("BCPlace")
	return (v and v:IsA("StringValue") and v.Value == "heist") and "heist" or "lobby"
end

return Place
