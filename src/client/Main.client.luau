-- Client bootstrap. Small modules, each required and initialised in its own scope (the old 1,320-line
-- monolith hit Luau's 200-register limit). Readiness is reported so a server-only test pass can't hide
-- a client that failed to compile.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("BlackoutCrew")
local Net = require(shared:WaitForChild("Net"))
local Rules = require(shared:WaitForChild("Rules"))
local Place = require(shared:WaitForChild("Place"))
local ORDER = { "Hud", "CameraRig", "Fx", "ViewModel", "Controls", "GunClient", "Wheel", "SettingsUI", "PerfOverlay" }
local ROLE_MODULES = { lobby = { "LobbyClient" }, heist = { "HeistControls", "LaserView", "EnemyView", "KartClient", "RepairUI", "ParkingGlow" } }

local lp = Players.LocalPlayer
local ctx = require(script.Parent:WaitForChild("ClientState"))
ctx.Config = require(shared.Config)
ctx.Log = require(shared.Log)
ctx.remotes = Net.client()
ctx.shared = shared
ctx.settings = Rules.defaultSettings()
ctx.netSends = 0 -- remote sends (perf overlay)
ctx.cursorFree = false -- true while a menu/wheel needs the mouse
ctx.role = Place.role()
for _, name in ipairs(ROLE_MODULES[ctx.role]) do
	table.insert(ORDER, name)
end

-- Tiny event bus: ctx.on("fire", fn) / ctx.emit("fire", true)
local handlers = {}
function ctx.on(name, fn)
	handlers[name] = handlers[name] or {}
	table.insert(handlers[name], fn)
end
function ctx.emit(name, ...)
	for _, fn in ipairs(handlers[name] or {}) do
		local ok, err = pcall(fn, ...)
		if not ok then
			ctx.Log.warn("Client", "handler", name, err)
		end
	end
end

-- Input kind drives touch HUD visibility and aim assist.
local function kindOf(t)
	if t == Enum.UserInputType.Touch then
		return "Touch"
	elseif t.Name:find("Gamepad") then
		return "Gamepad"
	elseif t == Enum.UserInputType.Keyboard or t.Name:find("Mouse") then
		return "Keyboard"
	end
	return nil
end
ctx.inputKind = UserInputService.TouchEnabled and "Touch" or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and "Gamepad" or "Keyboard")
UserInputService.LastInputTypeChanged:Connect(function(t)
	local k = kindOf(t)
	if k and k ~= ctx.inputKind then
		ctx.inputKind = k
		ctx.emit("inputKind", k)
	end
end)

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

ctx.remotes.Profile.OnClientEvent:Connect(function(p)
	if type(p) == "table" then
		ctx.profile = p
		ctx.settings = Rules.cleanSettings(p.settings)
		ctx.emit("settings", ctx.settings)
		ctx.emit("profile", p)
	end
end)
ctx.remotes.Notify.OnClientEvent:Connect(function(text)
	if ctx.Hud and type(text) == "string" then
		ctx.Hud.toast(text, 4)
	end
end)
function ctx.saveSettings()
	ctx.remotes.SaveSettings:FireServer(ctx.settings)
	ctx.netSends += 1
end

lp:SetAttribute("BCClientModules", #loaded)
lp:SetAttribute("BCClientExpected", #ORDER)
lp:SetAttribute("BCClientFailed", table.concat(failed, " | "))
lp:SetAttribute("BCClientReady", #failed == 0)
ctx.remotes.ClientReady:FireServer({ loaded = loaded, failed = failed, expected = #ORDER })
