-- Context actions (§5f [CONFIRM]): one HOLD button that appears only when something is in reach.
-- Priority (REC): revive > repair > hack > pick up; the rest slot in around them. Pure and shared:
-- the client picks what to show from the same rules the server uses to validate.
--
-- me:      { pos, downed, overrideLeft, heavy (bool), driving }
-- world:   { mates = { {id, pos, downed, heavy} }, karts = { {id, pos, mine, sabotaged, heavy, occupied} },
--            hacks = { {id, pos, range, hacked} }, loot = { {id, pos, heavy} } }
local Actions = {}
Actions.Priority = { "override", "revive", "repair", "load", "hack", "pickup", "handoff", "drive", "drop" }

local function near(a, b, r)
	return (a - b).Magnitude <= r
end

-- Is `kind` on `target` allowed for `me`? cfg = Config.Actions.
function Actions.check(kind, me, target, cfg)
	local a = cfg[kind]
	if not a or me.driving then
		return false
	end
	if kind == "override" then
		return me.downed and (me.overrideLeft or 0) > 0
	end
	if me.downed then
		return false
	end
	if kind == "drop" then
		return me.heavy == true
	end
	if not target or not near(me.pos, target.pos, target.range or a.range) then
		return false
	end
	if kind == "revive" then
		return target.downed == true
	elseif kind == "repair" then
		return target.sabotaged == true and not target.occupied
	elseif kind == "load" then
		return me.heavy and target.mine and not target.heavy and not target.sabotaged
	elseif kind == "hack" then
		return not target.hacked and not me.heavy
	elseif kind == "pickup" then
		return not me.heavy
	elseif kind == "handoff" then
		return me.heavy and not target.heavy and not target.downed
	elseif kind == "drive" then
		return target.mine and not target.sabotaged and not target.occupied and not me.heavy
	end
	return false
end

local SOURCES = { revive = "mates", repair = "karts", load = "karts", hack = "hacks", pickup = "loot", handoff = "mates", drive = "karts" }

-- Snapshot from replicated state (attributes + CollectionService tags), identical on client and server.
-- Entries carry `inst` (Player, kart Model, hackable part, loot Model/part) as their id.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local function pivot(x)
	return x:IsA("Model") and x:GetPivot().Position or x.Position
end

function Actions.gather(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end
	local me = { pos = root.Position, downed = player:GetAttribute("BC_Downed") == true, overrideLeft = player:GetAttribute("BC_Override") or 0,
		heavy = player:GetAttribute("BC_Heavy") ~= nil, driving = player:GetAttribute("BC_Driving") == true }
	local world = { mates = {}, karts = {}, hacks = {}, loot = {} }
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p ~= player and p:GetAttribute("BC_Slot") and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then
			table.insert(world.mates, { inst = p, pos = r.Position, downed = p:GetAttribute("BC_Downed") == true, heavy = p:GetAttribute("BC_Heavy") ~= nil })
		end
	end
	for _, k in ipairs(CollectionService:GetTagged("BC_Kart")) do
		if k.PrimaryPart then
			table.insert(world.karts, { inst = k, pos = k.PrimaryPart.Position, mine = k:GetAttribute("Owner") == player.UserId,
				sabotaged = k:GetAttribute("Sabotaged") == true, heavy = k:GetAttribute("Heavy") ~= nil, occupied = k:GetAttribute("Driver") ~= nil })
		end
	end
	for _, h in ipairs(CollectionService:GetTagged("BC_Hackable")) do
		if h:IsDescendantOf(workspace) then
			table.insert(world.hacks, { inst = h, pos = pivot(h), range = h:GetAttribute("Range"), hacked = h:GetAttribute("Hacked") == true })
		end
	end
	for _, l in ipairs(CollectionService:GetTagged("BC_Loot")) do
		if l:IsDescendantOf(workspace) and not l:GetAttribute("Carrier") and not l:GetAttribute("Loaded") then
			table.insert(world.loot, { inst = l, pos = pivot(l), heavy = l:GetAttribute("Heavy") == true, hold = l:GetAttribute("Hold") })
		end
	end
	return me, world
end

-- Find the snapshot entry for an instance (server validation of a client-chosen target).
function Actions.entry(world, inst)
	for _, list in pairs(world) do
		for _, e in ipairs(list) do
			if e.inst == inst then
				return e
			end
		end
	end
	return nil
end

-- Best available action: kind, target (nearest valid target of the highest-priority kind).
function Actions.best(me, world, cfg)
	for _, kind in ipairs(Actions.Priority) do
		local list = SOURCES[kind] and world[SOURCES[kind]]
		if not list then
			if Actions.check(kind, me, nil, cfg) then
				return kind, nil
			end
		else
			local best, bestD = nil, math.huge
			for _, t in ipairs(list) do
				local d = (t.pos - me.pos).Magnitude
				if d < bestD and Actions.check(kind, me, t, cfg) then
					best, bestD = t, d
				end
			end
			if best then
				return kind, best
			end
		end
	end
	return nil, nil
end

return Actions
