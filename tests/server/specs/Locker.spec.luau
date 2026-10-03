-- Locker room (revision stage 1): catalog sanity, schema-4 migration/validation, server-applied pieces
-- (outfit stash/restore, massless, non-colliding, matte), station validation (range, ownership, slots,
-- all-or-nothing), no gameplay effect, respawn persistence, and the real client: entry transition, skip,
-- reduced motion, preview isolation, apply/cancel/rejection recovery, input/camera restore, death cleanup.
-- Restores cosmetics, settings and position (the respawn leaves a fresh character, which later specs use).
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local C = require(RS.BlackoutCrew.Config)
local Rules = require(RS.BlackoutCrew.Rules)
local Kit = require(RS.BlackoutCrew.CosmeticKit)
local Map = require(RS.BlackoutCrew.GarageMap)
local S = require(game.ServerScriptService.BlackoutCrew.ServerState)

return function(T)
	local p, G = T.player, S.Garage
	local d = S.profiles.loaded[p]
	local function waitFor(fn, seconds)
		local deadline = os.clock() + (seconds or 3)
		repeat if fn() then return true end; task.wait(0.05) until os.clock() > deadline
		return false
	end
	local function move(at)
		local ok = T.cmd("moveTo", at)
		return ok and waitFor(function()
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			return root and (root.Position - at).Magnitude < 4
		end)
	end
	local function torso()
		return p.Character and (p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso"))
	end

	-- 1. Catalog
	local ids, free, matte, small = {}, {}, true, true
	for _, c in ipairs(C.Cosmetics) do
		ids[c.id] = (ids[c.id] or 0) + 1
		if c.free then free[c.slot] = (free[c.slot] or 0) + 1 end
		small = small and #(c.parts or {}) <= 4 and (c.slot ~= "outfit" or (c.colors and c.colors.torso and c.colors.arms and c.colors.legs) ~= nil)
		small = small and table.find(C.CosmeticSlots, c.slot) ~= nil and C.CosmeticsById[c.id] == c
	end
	for _, n in pairs(ids) do matte = matte and n == 1 end
	T.check("catalog ids unique, slots valid, outfits fully coloured, <= 4 pieces", matte and small)
	T.check("every slot has a free starter item", (free.outfit or 0) >= 1 and (free.disguise or 0) >= 1 and (free.mask or 0) >= 1)
	T.check("locked items carry no price (economy deferred)", (function()
		for _, c in ipairs(C.Cosmetics) do if c.price ~= nil then return false end end
		return true
	end)())

	-- 2. Migration + validation
	local old = Rules.clean({ schemaVersion = 3, credits = 9, tutorial = { done = true }, settings = { sfx = false }, receipts = { r1 = true },
		guns = { owned = { A2 = true }, loadout = { "A2", "", "" } }, cosmetics = { owned = { hat = true } } })
	T.check("schema 3 save migrates without losing data", old.schemaVersion == C.Profile.SchemaVersion and C.Profile.SchemaVersion >= 4 and old.credits == 9
		and old.tutorial.done and old.settings.sfx == false and old.receipts.r1 and old.guns.loadout[1] == "A2")
	T.check("migrated save: own look, free starters owned, unknown ids dropped", next(old.cosmetics.equipped) == nil and old.cosmetics.owned.fit_crew
		and old.cosmetics.owned.hat == nil)
	local eq = Rules.clean({ cosmetics = { equipped = { outfit = "fit_crew", disguise = "dis_maint", mask = "fit_night", hat = "mask_bandana" } } }).cosmetics.equipped
	T.check("equipped: owned kept, locked / wrong-slot / unknown-slot dropped", eq.outfit == "fit_crew" and eq.disguise == nil and eq.mask == nil and eq.hat == nil)
	local bought = Rules.clean({ cosmetics = { owned = { dis_maint = true }, equipped = { disguise = "dis_maint" } } }).cosmetics.equipped
	T.eq("an owned (future shop) item stays equipped", bought.disguise, "dis_maint")
	local round = Rules.clean(Http:JSONDecode(Http:JSONEncode(Rules.clean({ cosmetics = { equipped = { mask = "mask_visor", outfit = "fit_night" } } }))))
	T.check("equipped survives a JSON save round trip", round.cosmetics.equipped.mask == "mask_visor" and round.cosmetics.equipped.outfit == "fit_night")
	local owned = Rules.freeCosmetics()
	T.eq("request: not a table", select(2, Rules.cosmeticProposal("fit_crew", owned)), "invalid")
	T.eq("request: unknown slot", select(2, Rules.cosmeticProposal({ hat = "mask_bandana" }, owned)), "invalid")
	T.eq("request: item in the wrong slot", select(2, Rules.cosmeticProposal({ mask = "fit_crew" }, owned)), "incompatible")
	T.eq("request: locked item", select(2, Rules.cosmeticProposal({ disguise = "dis_maint" }, owned)), "locked")

	-- 3. Pieces on the real character (server)
	local char = p.Character
	local savedCos = Http:JSONDecode(Http:JSONEncode(d.cosmetics))
	local clothes = 0
	for _, x in ipairs(char:GetChildren()) do if Kit.isClothing(x) then clothes += 1 end end
	local before = torso().Color
	local n = Kit.apply(char, { outfit = "fit_crew", disguise = "dis_courier", mask = "mask_bandana" })
	local pieces = Kit.pieces(char)
	local inert = #pieces > 0
	for _, x in ipairs(pieces) do
		local w = x:FindFirstChildOfClass("Weld")
		inert = inert and x.Massless and not x.CanCollide and not x.CanQuery and not x.CanTouch and x.Material == Enum.Material.SmoothPlastic
			and w ~= nil and w.Part0 and w.Part0:IsDescendantOf(char)
	end
	T.check("disguise + mask pieces built", n == 6 and #pieces == 6, n)
	T.check("pieces are massless, non-colliding, unqueryable, matte and welded", inert)
	T.check("outfit recolours the torso and hides avatar clothing", torso().Color == C.CosmeticsById.fit_crew.colors.torso and (function()
		for _, x in ipairs(char:GetChildren()) do if Kit.isClothing(x) then return false end end
		return true
	end)())
	local head = char:FindFirstChild("Head")
	T.check("mask sits on the head", (function()
		for _, x in ipairs(pieces) do
			if x:GetAttribute(Kit.TAG) == "mask" and (x.Position - head.Position).Magnitude > head.Size.Magnitude then return false end
		end
		return true
	end)())
	Kit.apply(char, { outfit = "fit_crew", disguise = "dis_courier", mask = "mask_bandana" })
	T.eq("re-applying does not stack pieces", #Kit.pieces(char), 6)
	Kit.apply(char, {})
	local back = 0
	for _, x in ipairs(char:GetChildren()) do if Kit.isClothing(x) then back += 1 end end
	T.check("removing restores colours and clothing", #Kit.pieces(char) == 0 and torso().Color == before and back == clothes)

	-- 4. Station requests + gameplay neutrality
	local original = p.Character.HumanoidRootPart.Position
	move(Map.point(C.Garage.Spawn) + Vector3.new(0, 3, 0))
	T.eq("far from the locker: refused", select(2, G.action(p, "cosmetics", { outfit = "fit_crew" })), "far")
	T.check("walk to the locker", move(Map.lockerPoint() + Vector3.new(-6, 0, 0)))
	d.cosmetics.equipped = {}
	T.eq("locked item refused", select(2, G.action(p, "cosmetics", { disguise = "dis_maint" })), "locked")
	T.eq("wrong slot refused", select(2, G.action(p, "cosmetics", { mask = "fit_crew" })), "incompatible")
	T.eq("unknown slot refused", select(2, G.action(p, "cosmetics", { hat = "mask_bandana" })), "invalid")
	T.check("one bad slot rejects the whole look", not G.action(p, "cosmetics", { outfit = "fit_night", disguise = "dis_maint" }) and next(d.cosmetics.equipped) == nil)
	local hum = p.Character:FindFirstChildOfClass("Humanoid")
	local root = p.Character.HumanoidRootPart
	local speed, hip, mass = hum.WalkSpeed, hum.HipHeight, root.AssemblyMass
	T.check("valid look saved and worn", G.action(p, "cosmetics", { outfit = "fit_night", mask = "mask_visor", disguise = "dis_courier" })
		and d.cosmetics.equipped.mask == "mask_visor" and #Kit.pieces(p.Character) == 6 and torso().Color == C.CosmeticsById.fit_night.colors.torso)
	T.check("cosmetics change no gameplay value (speed, hip height, mass)", hum.WalkSpeed == speed and hum.HipHeight == hip and math.abs(root.AssemblyMass - mass) < 1e-3,
		string.format("%s %s %s", hum.WalkSpeed, hum.HipHeight, root.AssemblyMass - mass))
	G.action(p, "cosmetics", { outfit = "fit_night", mask = "mask_visor" })

	-- 5. Respawn keeps the saved look
	p:LoadCharacter()
	T.check("respawned character wears the saved look", waitFor(function()
		local c = p.Character
		local t = c and (c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"))
		return c and c:FindFirstChild("HumanoidRootPart") and #Kit.pieces(c) == 2 and t and t.Color == C.CosmeticsById.fit_night.colors.torso
	end, 10))
	waitFor(function() local _, st = T.cmd("state"); return st and st.alive end, 5)

	-- 6. Client: entry transition, skip, preview isolation, apply / cancel / rejection, restore
	move(Map.lockerPoint() + Vector3.new(-6, 0, 0))
	T.cmd("setting", "reducedMotion", false)
	S.remotes.GarageEvent:FireClient(p, "locker") -- what the locker's prompt sends
	local snap
	T.check("entry plays a short transition", waitFor(function()
		local _, s2 = T.cmd("locker", "snapshot")
		snap = s2
		return s2 and (s2.intro or s2.open)
	end, 2) and snap.intro == true, snap and tostring(snap.open))
	local _, st = T.cmd("state")
	T.check("transition suppresses input and owns the camera", st and st.menu == "locker" and st.cursorFree and st.cutscene and st.prompts == false)
	_, snap = T.cmd("locker", "skip")
	T.check("skip opens the screen with the live preview", snap and snap.open and not snap.intro and snap.hasClone and snap.cameraAtView and snap.doorOpen)
	T.check("preview starts from the saved look", snap and snap.preview.mask == "mask_visor" and snap.clonePieces == 2)
	local _, audit = T.cmd("uiAudit")
	T.check("locker: touch targets >= 44 px, no overlaps, on screen", audit and audit.small == "" and audit.overlaps == "" and audit.offscreen == "" and audit.buttons >= 8,
		audit and (audit.small .. "|" .. audit.overlaps .. "|" .. audit.offscreen .. "|" .. audit.buttons))
	local _, pick = T.cmd("locker", "pick", "mask", "mask_bandana")
	T.check("preview dresses only the local clone", pick and pick.ok and pick.snap.preview.mask == "mask_bandana" and pick.snap.clonePieces == 2
		and d.cosmetics.equipped.mask == "mask_visor" and p.Character:FindFirstChild("BC_mask1") ~= nil
		and (p.Character.BC_mask1.Size - p.Character.Head.Size * C.CosmeticsById.mask_visor.parts[1].size).Magnitude < 1e-3)
	_, pick = T.cmd("locker", "pick", "disguise", "dis_maint")
	T.check("locked item cannot be previewed", pick and pick.ok == false and pick.snap.preview.disguise == nil)
	_, pick = T.cmd("locker", "pick", "outfit", nil)
	T.check("own-look preview restores avatar clothing on the clone", pick and pick.ok and pick.snap.preview.outfit == nil and pick.snap.cloneStash == false)
	_, snap = T.cmd("locker", "cancel")
	T.check("cancel returns to the saved look", snap and snap.preview.mask == "mask_visor" and snap.preview.outfit == "fit_night")
	T.cmd("locker", "pick", "outfit", "fit_crew")
	_, snap = T.cmd("locker", "apply")
	T.check("apply saves through the server", snap and snap.lastAck and snap.lastAck.ok and d.cosmetics.equipped.outfit == "fit_crew"
		and torso().Color == C.CosmeticsById.fit_crew.colors.torso and snap.saved.outfit == "fit_crew")
	T.cmd("locker", "pick", "mask", "mask_bandana")
	d.cosmetics.owned.mask_bandana = nil -- ownership changes server-side after the preview (race)
	_, snap = T.cmd("locker", "apply")
	T.check("rejected apply shows the saved look again", snap and snap.lastAck and snap.lastAck.ok == false and snap.lastAck.reason == "locked"
		and snap.preview.mask == "mask_visor" and d.cosmetics.equipped.mask == "mask_visor" and snap.status:find("saved look") ~= nil, snap and snap.status)
	d.cosmetics.owned.mask_bandana = true
	_, snap = T.cmd("locker", "close")
	_, st = T.cmd("state")
	T.check("close restores camera, input and prompts", snap and not snap.open and not snap.doorOpen and st and st.menu == nil and not st.cursorFree
		and not st.cutscene and st.prompts == true)
	T.cmd("setting", "reducedMotion", true)
	S.remotes.GarageEvent:FireClient(p, "locker")
	T.check("reduced motion skips the transition", waitFor(function()
		local _, s2 = T.cmd("locker", "snapshot")
		snap = s2
		return s2 and s2.open
	end, 2) and not snap.intro and snap.cameraAtView)
	p.Character:FindFirstChildOfClass("Humanoid").Health = 0
	T.check("death closes the locker and restores input", waitFor(function()
		local _, s2 = T.cmd("state")
		return s2 and s2.menu == nil and not s2.cursorFree and not s2.cutscene
	end, 4))
	T.cmd("setting", "reducedMotion", false)
	p:LoadCharacter()
	waitFor(function()
		local _, s2 = T.cmd("state")
		return s2 and s2.alive and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	end, 10)

	-- Restore
	d.cosmetics = savedCos
	S.Appearance.refresh(p)
	S.pushProfile(p)
	move(original)
end
