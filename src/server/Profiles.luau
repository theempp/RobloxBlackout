-- Player saves (ported from roblox 1 Profiles.luau): UpdateAsync + session lock, autosave, retries,
-- BindToClose flush, kick on failed load/save. Studio = session-only by design (never enable Studio API
-- access to test saves; live persistence is tested on a private published place only).
-- Instance-based with an injectable store so the lock logic is testable with an in-memory store.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local Rules = require(shared.Rules)
local Log = require(shared.Log)
local P = Config.Profile

local Profiles = {}
Profiles.__index = Profiles

-- Pure lock transforms (UpdateAsync callbacks). Returning nil cancels the write.
function Profiles.acquire(old, token, now)
	if type(old) == "table" and type(old.lock) == "table" and (old.lock.expires or 0) > now and old.lock.token ~= token then
		return nil -- another live server holds the session
	end
	local data = type(old) == "table" and (old.data or old) or nil
	local clean, newer = Rules.clean(data)
	if newer then
		return nil
	end
	return { data = clean, lock = { token = token, expires = now + P.LockSeconds } }
end

function Profiles.commit(old, token, snapshot, release, now)
	if type(old) ~= "table" or type(old.lock) ~= "table" or old.lock.token ~= token then
		return nil -- we lost the lock: never overwrite another session's data
	end
	return { data = snapshot, lock = (not release) and { token = token, expires = now + P.LockSeconds } or nil }
end

-- opts: store (UpdateAsync adapter) | sessionOnly, onFail(player, msg), retryDelay(attempt), now()
function Profiles.new(opts)
	opts = opts or {}
	local sessionOnly = opts.sessionOnly
	if sessionOnly == nil then
		sessionOnly = RunService:IsStudio() or not P.Persistence
	end
	local self = setmetatable({
		loaded = {},
		tokens = {},
		saving = {},
		sessionOnly = sessionOnly,
		store = opts.store or (not sessionOnly and DataStoreService:GetDataStore(P.StoreName)) or nil,
		onFail = opts.onFail or function(player, msg)
			player:Kick(msg)
		end,
		retryDelay = opts.retryDelay or function(attempt)
			return attempt * P.RetryDelay
		end,
		now = opts.now or os.time,
		jobId = opts.jobId or game.JobId,
	}, Profiles)
	return self
end

function Profiles:key(player)
	return "u" .. player.UserId
end

function Profiles:load(player)
	if self.sessionOnly then
		self.loaded[player] = Rules.defaultProfile()
		player:SetAttribute("SaveStatus", "SESSION ONLY")
		return self.loaded[player]
	end
	local token = self.jobId .. ":" .. HttpService:GenerateGUID(false)
	local key = self:key(player)
	for attempt = 1, P.Retries do
		local result
		local ok, err = pcall(function()
			result = self.store:UpdateAsync(key, function(old)
				return Profiles.acquire(old, token, self.now())
			end)
		end)
		if ok and type(result) == "table" and type(result.lock) == "table" and result.lock.token == token then
			if not player.Parent then -- left while loading: release the lock
				pcall(function()
					self.store:UpdateAsync(key, function(old)
						return Profiles.commit(old, token, old and old.data, true, self.now())
					end)
				end)
				return nil
			end
			self.loaded[player] = Rules.clean(result.data)
			self.tokens[player] = token
			player:SetAttribute("SaveStatus", "SAVED")
			return self.loaded[player]
		end
		Log.warn("Profiles", "load retry", player.UserId, attempt, err)
		task.wait(self.retryDelay(attempt))
	end
	self.onFail(player, "Your save is busy or unavailable. Please reconnect in a moment.")
	return nil
end

function Profiles:save(player, release)
	if self.sessionOnly then
		if release then
			self.loaded[player] = nil
		end
		return true
	end
	while self.saving[player] do
		task.wait(0.1)
	end
	local p, token = self.loaded[player], self.tokens[player]
	if not p or not token then
		return false
	end
	self.saving[player] = true
	local snapshot = Rules.clean(p)
	local success = false
	for attempt = 1, P.Retries do
		local result
		local ok = pcall(function()
			result = self.store:UpdateAsync(self:key(player), function(old)
				return Profiles.commit(old, token, snapshot, release, self.now())
			end)
		end)
		if ok and result then
			success = true
			break
		end
		task.wait(self.retryDelay(attempt) / 2)
	end
	self.saving[player] = nil
	player:SetAttribute("SaveStatus", success and "SAVED" or "SAVE RETRY")
	if release then
		self.loaded[player] = nil
		self.tokens[player] = nil
	elseif not success then
		self.onFail(player, "Saving is temporarily unavailable. Reconnect to protect your progress.")
	end
	return success
end

function Profiles:start()
	task.spawn(function()
		while task.wait(P.AutosaveSeconds) do
			for player in pairs(self.loaded) do
				task.spawn(self.save, self, player, false)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in pairs(self.loaded) do
			pending += 1
			task.spawn(function()
				self:save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + P.CloseTimeout
		repeat
			task.wait(0.1)
		until pending == 0 or os.clock() > deadline
	end)
end

return Profiles
