-- Heist arrival (revision stage 1): the profile the lobby released carries the saved look; the heist place
-- applies it to the arriving character from the same validated data, and it changes no gameplay value.
-- Restores the player's cosmetics and character pieces before returning (later heist specs share this world).
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local C = require(RS.BlackoutCrew.Config)
local Rules = require(RS.BlackoutCrew.Rules)
local Kit = require(RS.BlackoutCrew.CosmeticKit)
local S = require(game.ServerScriptService.BlackoutCrew.ServerState)

return function(T)
	local p = T.player
	local d = S.profiles.loaded[p]
	T.check("heist place runs the appearance hook on arrival", S.Appearance ~= nil and table.find(S.onJoin, S.Appearance.refresh) ~= nil)
	if not (d and S.Appearance and p.Character) then
		return
	end
	local saved = Http:JSONDecode(Http:JSONEncode(d.cosmetics))
	-- What the lobby saved, after a real JSON save/load and the heist's own validation.
	local lobby = Rules.defaultProfile()
	lobby.cosmetics.equipped = { outfit = "fit_night", disguise = "dis_courier", mask = "mask_bandana" }
	local arrived = Rules.clean(Http:JSONDecode(Http:JSONEncode(lobby)))
	local hum = p.Character:FindFirstChildOfClass("Humanoid")
	local speed = hum.WalkSpeed
	d.cosmetics = arrived.cosmetics
	T.check("arriving character wears the saved look", S.Appearance.refresh(p) and #Kit.pieces(p.Character) == 6
		and (p.Character:FindFirstChild("UpperTorso") or p.Character.Torso).Color == C.CosmeticsById.fit_night.colors.torso)
	T.eq("disguise leaves heist movement alone", hum.WalkSpeed, speed)
	d.cosmetics.equipped = { disguise = "dis_maint" } -- not owned: the heist must not trust it either
	d.cosmetics = Rules.clean({ cosmetics = d.cosmetics }).cosmetics
	S.Appearance.refresh(p)
	T.eq("heist re-validates: an unowned item is never worn", #Kit.pieces(p.Character), 0)
	d.cosmetics = saved
	S.Appearance.refresh(p)
	T.eq("restored", #Kit.pieces(p.Character), 0)
end
