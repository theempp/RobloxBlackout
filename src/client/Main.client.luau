-- Client bootstrap. Small modules, each required and initialised in its own scope (the old 1,320-line
-- monolith hit Luau's 200-register limit). Readiness is reported so a server-only test pass can't hide
-- a client that failed to compile.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BlackoutCrew")
local Net = require(shared:WaitForChild("Net"))
local ORDER = {}

local lp = Players.LocalPlayer
local ctx = { Config = require(shared.Config), Log = require(shared.Log), remotes = Net.client(), shared = shared }
local loaded, failed = {}, {}
for _, name in ipairs(ORDER) do
	local ok, mod = pcall(function()
		return require(script.Parent:WaitForChild(name, 10))
	end)
	if ok and type(mod) == "table" then
		ctx[name] = mod
		table.insert(loaded, name)
	else
		table.insert(failed, name .. ": " .. tostring(mod))
	end
end
for _, name in ipairs(loaded) do
	local mod = ctx[name]
	if mod.init then
		local ok, err = pcall(mod.init, ctx)
		if not ok then
			table.insert(failed, name .. ".init: " .. tostring(err))
		end
	end
end
for _, f in ipairs(failed) do
	ctx.Log.warn("Client", "module failed", f)
end
local report = { loaded = loaded, failed = failed, expected = #ORDER }
lp:SetAttribute("BCClientModules", #loaded)
lp:SetAttribute("BCClientExpected", #ORDER)
lp:SetAttribute("BCClientFailed", table.concat(failed, " | "))
lp:SetAttribute("BCClientReady", #failed == 0)
ctx.remotes.ClientReady:FireServer(report)
