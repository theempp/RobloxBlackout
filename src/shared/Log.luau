-- Leveled logging with duplicate suppression. Log.info("Guns", "equipped", id)
local Config = require(script.Parent.Config)
local Log = {}
local LEVELS = { debug = 1, info = 2, warn = 3 }
local seen: { [string]: number } = {}

local function emit(level, tag, ...)
	if LEVELS[level] < (LEVELS[Config.Log.Level] or 2) then
		return
	end
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	local msg = "[BC:" .. tag .. "] " .. table.concat(parts, " ", 1, parts.n)
	local now = os.clock()
	if (seen[msg] or -math.huge) > now - 5 then
		return -- same line within 5s: drop (keeps spammy paths from flooding the output)
	end
	seen[msg] = now
	if level == "warn" then
		warn(msg)
	else
		print(msg)
	end
end

function Log.debug(tag, ...)
	emit("debug", tag, ...)
end
function Log.info(tag, ...)
	emit("info", tag, ...)
end
function Log.warn(tag, ...)
	emit("warn", tag, ...)
end

return Log
