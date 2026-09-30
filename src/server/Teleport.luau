-- TeleportService behind an adapter (§11). Heist: reserve a private server and pass crew size +
-- difficulty + roster as TeleportData; lobby return: party teleport to a public lobby server.
-- A failed teleport is retried once, both the synchronous error and the async TeleportInitFailed,
-- then the caller is told (onGiveUp). Place id 0 (unpublished) or Studio = "local": nothing is
-- teleported. Tests inject a fake service, clock and options factory.
local Teleport = {}
Teleport.__index = Teleport

local function realOptions(code, data)
	local o = Instance.new("TeleportOptions")
	if code then
		o.ReservedServerAccessCode = code
	end
	o:SetTeleportData(data)
	return o
end

-- opts: service, places {Lobby, Heist}, studio, retries, retryDelay, wait, makeOptions, onGiveUp(players, why)
function Teleport.new(opts)
	opts.makeOptions = opts.makeOptions or realOptions
	opts.wait = opts.wait or task.wait
	return setmetatable({ opts = opts, pending = {}, attempts = 0 }, Teleport)
end

function Teleport:mode(placeId)
	return (self.opts.studio or not placeId or placeId == 0) and "local" or "live"
end

-- Returns ok, mode ("live" | "local" | "failed"), err. Yields.
function Teleport:send(players, placeId, data, reserved)
	if self:mode(placeId) == "local" then
		return false, "local"
	end
	local o = self.opts
	local lastErr
	for attempt = 1, 1 + o.retries do
		self.attempts += 1
		local options
		local ok, err = pcall(function()
			local code = reserved and o.service:ReserveServer(placeId) or nil
			options = o.makeOptions(code, data)
			o.service:TeleportAsync(placeId, players, options)
		end)
		if ok then
			for _, p in ipairs(players) do
				self.pending[p] = { placeId = placeId, options = options, retried = attempt > 1 }
			end
			return true, "live"
		end
		lastErr = err
		if attempt <= o.retries then
			o.wait(o.retryDelay)
		end
	end
	return false, "failed", lastErr
end

-- Async half of "retry once" (TeleportService.TeleportInitFailed). Returns what it did.
function Teleport:initFailed(player, message)
	local p = self.pending[player]
	if not p then
		return "unknown"
	end
	if not p.retried then
		p.retried = true
		self.attempts += 1
		local ok = pcall(function()
			self.opts.service:TeleportAsync(p.placeId, { player }, p.options)
		end)
		if ok then
			return "retried"
		end
	end
	self.pending[player] = nil
	if self.opts.onGiveUp then
		self.opts.onGiveUp({ player }, tostring(message))
	end
	return "gaveUp"
end

function Teleport:forget(player)
	self.pending[player] = nil
end

function Teleport:toHeist(players, data)
	return self:send(players, self.opts.places.Heist, data, true)
end

function Teleport:toLobby(players, data)
	return self:send(players, self.opts.places.Lobby, data, false)
end

return Teleport
