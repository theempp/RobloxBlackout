-- Gun sounds from Config.Sfx: own shots (2D, pooled per gun so automatic fire overlaps without allocating), bolt /
-- reload / dry click, and teammates' shots (3D, small pool, distance-capped). Respects the SFX setting.
-- Current ids are built-in placeholders (Config.Sfx.Placeholder); real per-gun audio = owner-approved uploads.
local SoundService = game:GetService("SoundService")

local GunSfx = { played = 0 }
local ctx, S
local folder
local pools, poolIndex = {}, {}
local others, otherIndex = {}, 0
local named = {}

local function make(def, parent)
	local snd = Instance.new("Sound")
	snd.SoundId = def.id
	snd.Volume = def.volume or 0.5
	snd.PlaybackSpeed = def.speed or 1
	snd.Parent = parent
	return snd
end

local function enabled()
	return ctx.settings.sfx ~= false
end

function GunSfx.shot(gunId)
	if not enabled() then
		return
	end
	local pool = pools[gunId]
	if not pool then
		local def = S.Shot[gunId] or S.Shot.default
		pool = {}
		for i = 1, S.PoolPerGun do
			pool[i] = make(def, folder)
		end
		pools[gunId], poolIndex[gunId] = pool, 0
	end
	poolIndex[gunId] = poolIndex[gunId] % #pool + 1
	local snd = pool[poolIndex[gunId]]
	snd.TimePosition = 0
	snd:Play()
	GunSfx.played += 1
end

-- "Bolt" | "Reload" | "Dry", optionally delayed (bolt cycle starts after the shot).
function GunSfx.play(name, delay)
	if not enabled() or not named[name] then
		return
	end
	local snd = named[name]
	if delay and delay > 0 then
		task.delay(delay, function()
			snd.TimePosition = 0
			snd:Play()
		end)
	else
		snd.TimePosition = 0
		snd:Play()
	end
	GunSfx.played += 1
end

function GunSfx.other(gunId, origin)
	if not enabled() or typeof(origin) ~= "Vector3" then
		return
	end
	local cam = workspace.CurrentCamera
	if (cam.CFrame.Position - origin).Magnitude > S.OtherMaxDistance then
		return
	end
	otherIndex = otherIndex % #others + 1
	local o = others[otherIndex]
	local def = S.Shot[gunId] or S.Shot.default
	o.att.WorldPosition = origin
	o.snd.SoundId, o.snd.Volume, o.snd.PlaybackSpeed = def.id, (def.volume or 0.5) * 0.8, def.speed or 1
	o.snd.TimePosition = 0
	o.snd:Play()
end

function GunSfx.init(c)
	ctx = c
	S = ctx.Config.Sfx
	folder = Instance.new("Folder")
	folder.Name = "BCGunSfx"
	folder.Parent = SoundService
	for _, name in ipairs({ "Bolt", "Reload", "Dry" }) do
		named[name] = make(S[name], folder)
	end
	for i = 1, S.OtherShots do
		local att = Instance.new("Attachment")
		att.Name = "BCShotSfx" .. i
		att.Parent = workspace.Terrain
		local snd = make(S.Shot.default, att)
		snd.RollOffMaxDistance = S.OtherMaxDistance
		others[i] = { att = att, snd = snd }
	end
end

return GunSfx
