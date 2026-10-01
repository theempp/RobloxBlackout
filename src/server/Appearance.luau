-- Puts each player's saved, validated cosmetics on their character in BOTH places: when the profile loads
-- (heist arrival included), on every spawn, after the avatar finishes loading, and when the locker changes
-- them. Late avatar clothing is stashed while an outfit is on. Cosmetic only: nothing here touches speed,
-- noise, perception or any other gameplay value.
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Kit = require(shared.CosmeticKit)

local Appearance = { applied = 0 }
local S

function Appearance.refresh(player)
	local d = S.profiles.loaded[player]
	local char = player.Character
	if not d or not char or not char.Parent then
		return false
	end
	Kit.apply(char, d.cosmetics.equipped)
	Appearance.applied += 1
	return true
end

local function watch(player, char)
	Appearance.refresh(player)
	char.ChildAdded:Connect(function(x)
		local d = S.profiles.loaded[player]
		if Kit.isClothing(x) and d and d.cosmetics.equipped.outfit then
			task.defer(Appearance.refresh, player)
		end
	end)
end

function Appearance.init(s)
	S = s
	local function hook(p)
		p.CharacterAdded:Connect(function(c)
			watch(p, c)
		end)
		p.CharacterAppearanceLoaded:Connect(function()
			Appearance.refresh(p)
		end)
		if p.Character then
			watch(p, p.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	table.insert(S.onJoin, Appearance.refresh) -- profile just loaded (the character may have spawned first)
end

return Appearance
