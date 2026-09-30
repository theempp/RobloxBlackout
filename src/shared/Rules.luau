-- Save validation (ported pattern from roblox 1 Rules.clean). Everything is rebuilt from raw data:
-- unknown ids are dropped (whitelisted against Config), numbers are finite/clamped, and only
-- `settings` is ever client-writable (via Rules.cleanSettings).
local Config = require(script.Parent.Config)
local P = Config.Profile
local Rules = {}

function Rules.finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

local function count(n, max)
	if not Rules.finite(n) then
		return nil
	end
	return math.clamp(math.floor(n), 0, max)
end

function Rules.find(list, id)
	for _, x in ipairs(list) do
		if x.id == id then
			return x
		end
	end
	return nil
end

-- Payout with crew bonus: +8% per extra member, capped at +24% (Config.Crew).
function Rules.payout(base, crewCount)
	local c = Config.Crew
	return math.floor(base * (1 + math.min(math.max(crewCount - 1, 0) * c.BonusPerMember, c.BonusCap)) + 1e-9)
end

function Rules.freeGuns()
	local owned = {}
	for _, g in ipairs(Config.Guns) do
		if g.price == 0 then
			owned[g.id] = true
		end
	end
	return owned
end

function Rules.defaultSettings()
	local s = { layout = {} }
	for k, v in pairs(Config.Settings.Bools) do
		s[k] = v
	end
	for k, v in pairs(Config.Settings.Numbers) do
		s[k] = v[1]
	end
	return s
end

function Rules.defaultProfile()
	local free = Rules.freeGuns()
	local first = next(free) or ""
	return {
		schemaVersion = P.SchemaVersion,
		credits = 0,
		glitchCoins = 0,
		guns = { owned = free, loadout = { first, "", "" } },
		attachments = { owned = {}, equipped = {} },
		karts = { owned = {} },
		cosmetics = { owned = {} },
		wheel = { freeSpins = 0, pity = 0, season = 0 },
		heist = { runs = 0, lastObvious = false }, -- schema 2
		settings = Rules.defaultSettings(),
		receipts = {},
	}
end

local function ownedSet(src, list)
	local out = {}
	if type(src) == "table" then
		for id, v in pairs(src) do
			if v == true and type(id) == "string" and Rules.find(list, id) then
				out[id] = true
			end
		end
	end
	return out
end

-- Client-writable subset. `base` = current settings (defaults if nil); raw fields override when valid.
function Rules.cleanSettings(raw, base)
	local s = Rules.defaultSettings()
	if type(base) == "table" then
		for k in pairs(s) do
			if base[k] ~= nil then
				s[k] = base[k]
			end
		end
	end
	if type(raw) ~= "table" then
		return s
	end
	for k in pairs(Config.Settings.Bools) do
		if type(raw[k]) == "boolean" then
			s[k] = raw[k]
		end
	end
	for k, v in pairs(Config.Settings.Numbers) do
		if Rules.finite(raw[k]) then
			s[k] = math.clamp(raw[k], v[2], v[3])
		end
	end
	if type(raw.layout) == "table" then
		local layout, lo, hi = {}, Config.Touch.UserScale[1], Config.Touch.UserScale[2]
		for id, e in pairs(raw.layout) do
			if type(id) == "string" and Config.Touch.Buttons[id] and type(e) == "table"
				and Rules.finite(e.x) and Rules.finite(e.y) and Rules.finite(e.s) then
				layout[id] = { x = math.clamp(e.x, 0, 1), y = math.clamp(e.y, 0, 1), s = math.clamp(e.s, lo, hi) }
			end
		end
		s.layout = layout
	elseif type(base) == "table" and type(base.layout) == "table" then
		s.layout = base.layout
	end
	return s
end

-- Returns (profile, newerSchema). newerSchema=true means the save came from a newer server build:
-- the caller must not save over it.
function Rules.clean(raw)
	local p = Rules.defaultProfile()
	if type(raw) ~= "table" then
		return p, false
	end
	local newer = Rules.finite(raw.schemaVersion) and raw.schemaVersion > P.SchemaVersion
	p.credits = count(raw.credits, P.MaxCurrency) or 0
	p.glitchCoins = count(raw.glitchCoins, P.MaxCurrency) or 0

	local guns = type(raw.guns) == "table" and raw.guns or {}
	for id in pairs(ownedSet(guns.owned, Config.Guns)) do
		p.guns.owned[id] = true
	end
	if type(guns.loadout) == "table" then
		local used, loadout = {}, { "", "", "" }
		for i = 1, 3 do
			local id = guns.loadout[i]
			if type(id) == "string" and p.guns.owned[id] and not used[id] then
				loadout[i] = id
				used[id] = true
			end
		end
		if loadout[1] == "" and loadout[2] == "" and loadout[3] == "" then
			loadout[1] = p.guns.loadout[1]
		end
		p.guns.loadout = loadout
	end

	local att = type(raw.attachments) == "table" and raw.attachments or {}
	p.attachments.owned = ownedSet(att.owned, Config.Attachments)
	if type(att.equipped) == "table" then
		for gunId, slots in pairs(att.equipped) do
			local gun = type(gunId) == "string" and Config.GunsById[gunId]
			if gun and p.guns.owned[gunId] and type(slots) == "table" then
				local e = {}
				for slot, attId in pairs(slots) do
					local a = type(attId) == "string" and Config.AttachmentsById[attId]
					if a and a.slot == slot and table.find(gun.slots, slot) and p.attachments.owned[attId] then
						e[slot] = attId
					end
				end
				if next(e) then
					p.attachments.equipped[gunId] = e
				end
			end
		end
	end

	p.karts.owned = ownedSet(type(raw.karts) == "table" and raw.karts.owned, Config.Karts)
	p.cosmetics.owned = ownedSet(type(raw.cosmetics) == "table" and raw.cosmetics.owned, Config.Cosmetics)

	if type(raw.wheel) == "table" then
		p.wheel.freeSpins = count(raw.wheel.freeSpins, P.MaxCounter) or 0
		p.wheel.pity = count(raw.wheel.pity, P.MaxCounter) or 0
		p.wheel.season = count(raw.wheel.season, P.MaxCurrency) or 0
	end

	if type(raw.heist) == "table" then
		p.heist.runs = count(raw.heist.runs, P.MaxCurrency) or 0
		p.heist.lastObvious = raw.heist.lastObvious == true
	end

	p.settings = Rules.cleanSettings(raw.settings)

	if type(raw.receipts) == "table" then
		local n = 0
		for k, v in pairs(raw.receipts) do
			if n >= P.ReceiptCap then
				break
			end
			if type(k) == "string" and v == true then
				p.receipts[k] = true
				n += 1
			end
		end
	end
	return p, newer
end

return Rules
