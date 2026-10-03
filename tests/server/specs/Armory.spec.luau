-- Personal armory (revision stage 1): stat widget accuracy against GunStats.resolve, station validation
-- (ownership, ids, compatibility, range, all-or-nothing), slot swap/remove, per-player isolation, acks and
-- rate limiting, then the real client panel: preview isolation, cancel, apply, rejection recovery, UI audit.
-- Restores every profile field, the weapon state and the player's position it touches.
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local C = require(RS.BlackoutCrew.Config)
local Rules = require(RS.BlackoutCrew.Rules)
local GunStats = require(RS.BlackoutCrew.GunStats)
local StatSheet = require(RS.BlackoutCrew.StatSheet)
local Map = require(RS.BlackoutCrew.GarageMap)
local S = require(game.ServerScriptService.BlackoutCrew.ServerState)
local Remotes = require(game.ServerScriptService.BlackoutCrew.Remotes)

local function byKey(rows)
	local t = {}
	for _, r in ipairs(rows or {}) do
		t[r.key] = r
	end
	return t
end

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
		return ok and waitFor(function() return (p.Character.HumanoidRootPart.Position - at).Magnitude < 4 end)
	end

	-- 1. Stat widget = resolved final stats, for every gun x every single attachment and a full set.
	local defs = byKey(StatSheet.ROWS)
	local count, rowsOk, deltaOk = 0, true, true
	for _, g in ipairs(C.Guns) do
		local combos, full = { {} }, {}
		for _, a in ipairs(C.Attachments) do
			if table.find(g.slots, a.slot) then
				table.insert(combos, { [a.slot] = a.id })
				full[a.slot] = full[a.slot] or a.id
			end
		end
		table.insert(combos, full)
		for _, combo in ipairs(combos) do
			local rows = StatSheet.compare(g.id, {}, combo)
			local s0, s1 = GunStats.resolve(g.id, {}), GunStats.resolve(g.id, combo)
			for _, r in ipairs(rows) do
				local def = defs[r.key]
				count += 1
				rowsOk = rowsOk and r.cur == def.get(s0) and r.new == def.get(s1)
				deltaOk = deltaOk and r.delta == StatSheet.round(StatSheet.round(r.new, def.digits) - StatSheet.round(r.cur, def.digits), def.digits)
			end
		end
	end
	T.check("stat rows equal resolved final stats (every gun x attachment)", rowsOk and count > 100, count)
	T.check("deltas equal the difference of the shown values", deltaOk)
	local r = byKey(StatSheet.compare("P1", {}, { mag = "ext_mag" }))
	T.check("ext mag: magazine rounded 12 -> 17 rds, better", r.mag.curText == "12" and r.mag.newText == "17" and r.mag.deltaText == "+5" and r.mag.dir == "better",
		r.mag.newText .. " " .. r.mag.deltaText)
	T.check("ext mag: reload 1.40 -> 1.68 s, worse", r.reload.newText == "1.68 s" and r.reload.deltaText == "+0.28 s" and r.reload.dir == "worse", r.reload.deltaText)
	T.check("units on every row (label or value)", (function()
		for _, row in ipairs(StatSheet.ROWS) do
			if row.unit == "" and not row.label:find("%(") and row.key ~= "damage" then return false end
		end
		return true
	end)())
	r = byKey(StatSheet.compare("P1", {}, { optic = "scope2x" }))
	T.check("more zoom is a tradeoff, not 'better'", r.zoom.delta > 0 and r.zoom.dir == "tradeoff" and r.adsTime.dir == "worse")
	r = byKey(StatSheet.compare("A2", {}, { barrel = "compensator", grip = "angled_grip" }))
	local nested = GunStats.resolve("A2", { barrel = "compensator", grip = "angled_grip" })
	T.check("nested recoil (up and side pattern) resolved", math.abs(r.recoilUp.new - nested.recoil.up) < 1e-9 and r.recoilUp.dir == "better"
		and r.recoilSide.dir == "worse")
	T.check("no preview = no deltas", (function()
		for _, row in ipairs(StatSheet.compare("A1", { optic = "red_dot" }, nil)) do
			if row.delta ~= 0 or row.dir ~= "same" then return false end
		end
		return true
	end)())
	local maxRange = C.Fire.MaxRange
	C.Fire.MaxRange = 170
	r = byKey(StatSheet.compare("P1", {}, { barrel = "long_barrel" }))
	T.check("range capped by Config.Fire.MaxRange", r.range.new == 170 and r.range.cur == 160)
	C.Fire.MaxRange = 50
	r = byKey(StatSheet.compare("P1", {}, { barrel = "long_barrel" }))
	T.check("full-damage range capped to range", r.falloffStart.new == 50 and r.range.new == 50)
	C.Fire.MaxRange = maxRange

	-- 2. Request validation (pure).
	local owned = { red_dot = true, ext_mag = true }
	T.eq("proposal: not a table", select(2, Rules.attachmentProposal("P1", "red_dot", owned)), "invalid")
	T.eq("proposal: unknown id", select(2, Rules.attachmentProposal("P1", { optic = "laser9000" }, owned)), "invalid")
	T.eq("proposal: attachment in the wrong slot", select(2, Rules.attachmentProposal("P1", { mag = "red_dot" }, owned)), "incompatible")
	T.eq("proposal: slot the gun lacks", select(2, Rules.attachmentProposal("P1", { grip = "vert_grip" }, { vert_grip = true })), "incompatible")
	T.eq("proposal: not owned", select(2, Rules.attachmentProposal("P1", { optic = "scope2x" }, owned)), "locked")
	T.eq("proposal: unknown gun", select(2, Rules.attachmentProposal("nope", {}, owned)), "invalid")
	local clean = Rules.attachmentProposal("P1", { optic = "red_dot", mag = "ext_mag" }, owned)
	T.check("proposal: valid set kept", clean and clean.optic == "red_dot" and clean.mag == "ext_mag")

	-- 3. Station actions on the real player (test-only grants, restored below).
	local saved = Http:JSONDecode(Http:JSONEncode({ guns = d.guns, attachments = d.attachments }))
	local original = p.Character.HumanoidRootPart.Position
	local ghost = {}
	S.profiles.loaded[ghost] = Rules.defaultProfile()
	local ghostBefore = Http:JSONEncode(S.profiles.loaded[ghost])
	d.guns.owned.A2 = true
	d.guns.loadout = { "P1", "", "" }
	d.attachments.owned = { red_dot = true, ext_mag = true, compensator = true }
	d.attachments.equipped = {}
	move(Map.point(C.Garage.Spawn) + Vector3.new(0, 3, 0))
	T.eq("far from the armory: refused", select(2, G.action(p, "setAttachments", "P1", { optic = "red_dot" })), "far")
	T.check("walk to the bench", move(Map.bench.Position + Vector3.new(0, 2, 5)))
	T.eq("unowned gun refused", select(2, G.action(p, "setAttachments", "A1", {})), "locked")
	T.eq("unowned attachment refused", select(2, G.action(p, "setAttachments", "P1", { optic = "scope2x" })), "locked")
	T.eq("incompatible slot refused", select(2, G.action(p, "setAttachments", "P1", { grip = "vert_grip" })), "incompatible")
	T.eq("unknown id refused", select(2, G.action(p, "setAttachments", "P1", { optic = "laser9000" })), "invalid")
	T.check("one bad entry rejects the whole set", not G.action(p, "setAttachments", "P1", { optic = "red_dot", grip = "vert_grip" })
		and next(d.attachments.equipped.P1 or {}) == nil)
	T.check("valid set applied", G.action(p, "setAttachments", "P1", { optic = "red_dot", mag = "ext_mag" })
		and d.attachments.equipped.P1.optic == "red_dot" and d.attachments.equipped.P1.mag == "ext_mag")
	local w = S.Weapons.state(p)
	T.check("drawn gun re-resolved with the saved set", w.gunId == "P1" and w.stats.mag == 17 and next(w.loan) == nil, tostring(w.gunId) .. " " .. tostring(w.stats and w.stats.mag))
	T.check("empty set removes all", G.action(p, "setAttachments", "P1", {}) and next(d.attachments.equipped.P1) == nil)
	T.check("equip into slot 2", G.action(p, "equip", "A2", 2) and d.guns.loadout[1] == "P1" and d.guns.loadout[2] == "A2")
	T.check("equip a gun already slotted swaps places", G.action(p, "equip", "P1", 2) and d.guns.loadout[1] == "A2" and d.guns.loadout[2] == "P1")
	T.check("clear a slot", G.action(p, "clear", 1) and d.guns.loadout[1] == "" and d.guns.loadout[2] == "P1")
	T.eq("last blaster cannot be removed", select(2, G.action(p, "clear", 2)), "lastGun")
	T.eq("Coming Soon slot refused", select(2, G.action(p, "equip", "A2", 4)), "comingSoon")
	T.eq("locked gun refused", select(2, G.action(p, "equip", "A1", 1)), "locked")
	T.eq("bad slot refused", select(2, G.action(p, "equip", "A2", 2.5)), "invalid")
	T.eq("another player's profile untouched", Http:JSONEncode(S.profiles.loaded[ghost]), ghostBefore)
	S.profiles.loaded[ghost] = nil

	-- 4. Real remote path: acks, rejection reasons, rate limiting with client timeouts.
	local _, ack = T.cmd("armory", "request", "setAttachments", "P1", { optic = "scope2x" })
	T.check("remote rejection is acknowledged with a reason", ack and ack.ok == false and ack.reason == "locked", ack and ack.reason)
	_, ack = T.cmd("armory", "request", "setAttachments", "P1", { optic = "red_dot" })
	T.check("remote success is acknowledged", ack and ack.ok == true and d.attachments.equipped.P1.optic == "red_dot")
	task.wait(1.2) -- refill the GarageAction bucket
	local dropped0 = Remotes.dropped.GarageAction
	local _, flood = T.cmd("armory", "flood", 30)
	T.check("flood: server drops excess station requests", Remotes.dropped.GarageAction - dropped0 >= 15, Remotes.dropped.GarageAction - dropped0)
	T.check("flood: every request ends (ack or client timeout)", flood and flood.acked + flood.timedOut == 30 and flood.timedOut >= 15,
		flood and (flood.acked .. "/" .. flood.timedOut))
	task.wait(1.2)

	-- 5. The real panel: preview isolation, cancel, apply, rejection recovery, audit, input restore.
	d.attachments.equipped.P1 = {}
	S.pushProfile(p)
	local _, snap = T.cmd("armory", "show", "bench")
	T.check("bench opens on the drawn blaster", snap and snap.open and snap.tab == "bench" and snap.selected == "P1", snap and snap.selected)
	local _, st = T.cmd("state")
	T.check("menu suppresses firing, prompts, touch fire button and crosshair", st and st.menu == "armory" and st.cursorFree and st.prompts == false and not st.fireShown
		and not st.crosshair)
	local _, audit = T.cmd("uiAudit")
	T.check("bench: touch targets >= 44 px, no overlaps, on screen", audit and audit.small == "" and audit.overlaps == "" and audit.offscreen == "" and audit.buttons >= 8,
		audit and (audit.small .. "|" .. audit.overlaps .. "|" .. audit.offscreen .. "|" .. audit.buttons))
	_, snap = T.cmd("armory", "preview", "mag", "ext_mag")
	local rows = snap and byKey(snap.rows)
	T.check("preview shows saved vs proposed final stats", rows and rows.mag and rows.mag.cur == 12 and rows.mag.new == 17 and rows.mag.dir == "better")
	T.check("preview leaves the saved setup alone", next(d.attachments.equipped.P1) == nil and S.Weapons.state(p).stats.mag == 12 and snap and next(snap.saved) == nil)
	_, snap = T.cmd("armory", "preview", "mag", "quick_mag")
	T.check("locked attachment cannot be previewed", snap and snap.preview and snap.preview.mag == "ext_mag")
	_, snap = T.cmd("armory", "cancel")
	T.check("cancel drops the preview, nothing saved", snap and snap.preview == nil and next(d.attachments.equipped.P1) == nil)
	T.cmd("armory", "preview", "mag", "ext_mag")
	_, snap = T.cmd("armory", "apply")
	T.check("apply saves after the server ack", snap and snap.lastAck and snap.lastAck.ok and snap.preview == nil and d.attachments.equipped.P1.mag == "ext_mag"
		and snap.saved.mag == "ext_mag")
	T.cmd("armory", "preview", "optic", "red_dot")
	d.attachments.owned.red_dot = nil -- ownership changes server-side after the client previewed (race)
	_, snap = T.cmd("armory", "apply")
	T.check("rejected apply restores the saved setup", snap and snap.lastAck and snap.lastAck.ok == false and snap.lastAck.reason == "locked"
		and snap.preview == nil and snap.saved.optic == nil and d.attachments.equipped.P1.optic == nil and snap.status:find("saved setup") ~= nil,
		snap and snap.status)
	_, snap = T.cmd("armory", "setTab", "loadout")
	_, audit = T.cmd("uiAudit")
	T.check("loadout tab: touch targets >= 44 px, no overlaps, on screen", audit and audit.small == "" and audit.overlaps == "" and audit.offscreen == "",
		audit and (audit.small .. "|" .. audit.overlaps .. "|" .. audit.offscreen))
	T.cmd("armory", "select", "A2")
	_, snap = T.cmd("armory", "equip", 1)
	T.check("loadout tab equips through the server", snap and snap.lastAck and snap.lastAck.ok and d.guns.loadout[1] == "A2")
	T.cmd("menuBack")
	_, st = T.cmd("state")
	T.check("back closes the armory and restores input", st and st.menu == nil and not st.cursorFree and st.prompts == true and st.crosshair)
	T.cmd("armory", "show", "loadout")
	move(Map.point(C.Garage.Spawn) + Vector3.new(0, 3, 0))
	T.check("walking away closes the armory", waitFor(function()
		local _, s2 = T.cmd("armory", "snapshot")
		return s2 and not s2.open
	end, 3))

	-- Restore everything this spec touched.
	d.guns, d.attachments = saved.guns, saved.attachments
	S.Weapons.states[p] = nil
	S.Weapons.equip(p, 1)
	S.Weapons.push(p)
	S.pushProfile(p)
	move(original)
end
