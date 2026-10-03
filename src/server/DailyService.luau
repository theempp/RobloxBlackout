-- Daily reward claim (lobby only). Serial per player like EconomyService.transact: busy lock, snapshot, claim on the
-- server clock, save, restore the snapshot if the save fails, then push the profile. The client sends no data.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local D = require(RS.BlackoutCrew.DailyReward)
local Rules = require(RS.BlackoutCrew.Rules)
local Service = { busy = {} }

function Service.claim(S, p, now: number?)
	if Service.busy[p] then
		return false, "Please wait"
	end
	local d = S.profiles.loaded[p]
	if not d or S.role ~= "lobby" then
		return false, "Claim it in the garage"
	end
	Service.busy[p] = true
	local before = Rules.clean(d)
	local ok, message = D.claim(d, now or os.time())
	if ok and not S.profiles:save(p, false) then
		S.profiles.loaded[p] = before
		ok, message = false, "Save failed; claim reversed"
	end
	Service.busy[p] = nil
	S.pushProfile(p)
	return ok, message
end

function Service.init(S)
	S.Daily = Service
	S.Remotes.bind(S.remotes, "DailyClaim", function(p)
		local ok, message = Service.claim(S, p)
		S.remotes.DailyEvent:FireClient(p, ok, message)
	end)
	Players.PlayerRemoving:Connect(function(p)
		Service.busy[p] = nil
	end)
end

return Service
