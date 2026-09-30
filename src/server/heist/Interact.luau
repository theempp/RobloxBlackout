-- Server half of the context HOLD button (§5f). A start is validated with the same shared rules the
-- client used (Actions.check on a fresh snapshot); the hold timer runs here and is re-validated every
-- tick (walk away / get downed = cancelled); completion calls the effect the owning system registered.
-- One hold per player. Client: Action("start", kind, inst) / Action("stop"); result -> HeistEvent "action".
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local Actions = require(shared.Actions)

local Interact = { holds = {}, effects = {}, log = {} }
local S

function Interact.validate(player, kind, inst)
	local me, world = Actions.gather(player)
	if not me then
		return false
	end
	local entry = inst ~= nil and Actions.entry(world, inst) or nil
	return Actions.check(kind, me, entry, Config.Actions), entry
end

local function reply(player, kind, ok, why)
	table.insert(Interact.log, { player = player, kind = kind, ok = ok, why = why })
	if #Interact.log > 50 then
		table.remove(Interact.log, 1)
	end
	S.remotes.HeistEvent:FireClient(player, "action", { kind = kind, ok = ok, why = why })
end

function Interact.cancel(player, why)
	local h = Interact.holds[player]
	if h then
		Interact.holds[player] = nil
		reply(player, h.kind, false, why)
	end
end

-- Returns true if the hold started. `now` is injectable for tests.
function Interact.start(player, kind, inst, now)
	local run = S.Heist.run
	if type(kind) ~= "string" or not Config.Actions[kind] or not run or run.ended or not S.session:has(player) then
		return false
	end
	local ok, entry = Interact.validate(player, kind, inst)
	if not ok then
		reply(player, kind, false, "invalid")
		return false
	end
	local dur = (entry and entry.hold) or Config.Actions[kind].hold
	Interact.holds[player] = { kind = kind, inst = inst, t0 = now or os.clock(), dur = dur }
	if dur <= 0 then
		Interact.tick(S, run, 0, now)
	end
	return true
end

function Interact.tick(_, run, _, now)
	now = now or os.clock()
	for player, h in pairs(Interact.holds) do
		local ok = Interact.validate(player, h.kind, h.inst)
		if not ok then
			Interact.cancel(player, "invalid")
		elseif now - h.t0 >= h.dur then
			Interact.holds[player] = nil
			local effect = Interact.effects[h.kind]
			local done = effect ~= nil and effect(S, run, player, h.inst) ~= false
			reply(player, h.kind, done, done and nil or "failed")
		end
	end
end

function Interact.init(s)
	S = s
	S.interact = Interact
	-- Hacks dispatch on the target's Kind attribute; owning systems fill S.hacks[kind].
	S.hacks = {}
	Interact.effects.hack = function(_, run, player, inst)
		local fn = S.hacks[inst:GetAttribute("Kind")]
		return fn ~= nil and fn(S, run, player, inst)
	end
	S.Remotes.bind(S.remotes, "Action", function(player, verb, kind, inst)
		if verb == "stop" then
			Interact.cancel(player, "released")
		elseif verb == "start" then
			Interact.start(player, kind, inst)
		end
	end)
end

function Interact.leave(_, _, player)
	Interact.holds[player] = nil
end

function Interact.reset()
	table.clear(Interact.holds)
end

return Interact
