-- Server bootstrap: remotes, profiles, receipts, guns, teleport adapter, then the place role:
-- lobby (range + queue pads) or heist (the run). Role is baked per place build (shared/Place).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local shared = ReplicatedStorage:WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local Rules = require(shared.Rules)
local Net = require(shared.Net)
local Log = require(shared.Log)
local Place = require(shared.Place)
local server = script.Parent
local Profiles = require(server.Profiles)
local Receipts = require(server.Receipts)
local Remotes = require(server.Remotes)
local Weapons = require(server.Weapons)
local Teleport = require(server.Teleport)
local Appearance = require(server.Appearance)

local remotes = Net.server()
local profiles = Profiles.new()
local S = require(server.ServerState)
S.remotes, S.profiles, S.Remotes, S.clientReports = remotes, profiles, Remotes, {}
S.role = Place.role()
Config.Range.LoanAllGuns = workspace:GetAttribute("BCTesting") == true
S.onJoin = {} -- role hooks, called after the profile loads
server:SetAttribute("BCServerReady", false)
server:SetAttribute("BCRole", S.role)

local function pushProfile(player)
	local d = profiles.loaded[player]
	if d then
		remotes.Profile:FireClient(player, { settings = d.settings, guns = d.guns, attachments = d.attachments, cosmetics = d.cosmetics, credits = d.credits, glitchCoins = d.glitchCoins, progress = d.progress, wheel = d.wheel, karts = d.karts, daily = d.daily })
	end
end
S.pushProfile = pushProfile

function S.notify(player, text)
	remotes.Notify:FireClient(player, text)
end

Remotes.bind(remotes, "SaveSettings", function(player, raw)
	local d = profiles.loaded[player]
	if d then
		d.settings = Rules.cleanSettings(raw, d.settings) -- the only client-writable profile field
	end
end)
Remotes.bind(remotes, "ClientReady", function(player, report)
	S.clientReports[player] = type(report) == "table" and report or {}
	if type(report) == "table" and type(report.failed) == "table" and #report.failed > 0 then
		Log.warn("Server", "client modules failed for", player.Name, table.concat(report.failed, " | "))
	end
	pushProfile(player)
	if S.Weapons then
		S.Weapons.push(player) -- resend gun state in case the join push arrived before the client listened
	end
end)

MarketplaceService.ProcessReceipt = Receipts.handler({
	products = Config.Products,
 grant = function(data,product) return require(shared.Economy).receiptGrant(data,product) end,
	profiles = profiles,
	getPlayer = function(id)
		return Players:GetPlayerByUserId(id)
	end,
	onGranted = pushProfile,
})

require(server.EconomyService).init(S)
require(server.Telemetry).init(S)

Weapons.init(S)
S.Weapons = Weapons
Appearance.init(S)
S.Appearance = Appearance

S.teleport = Teleport.new({
	service = TeleportService,
	places = Config.Places,
	studio = RunService:IsStudio(),
	retries = Config.Teleport.Retries,
	retryDelay = Config.Teleport.RetryDelay,
	onGiveUp = function(players, why)
		if S.onTeleportGiveUp then
			S.onTeleportGiveUp(players, why)
		end
	end,
})
TeleportService.TeleportInitFailed:Connect(function(player, _, message)
	S.teleport:initFailed(player, message)
end)

local function join(player)
	if profiles:load(player) then
		pushProfile(player)
		Weapons.equip(player, 1)
		Weapons.push(player)
		for _, hook in ipairs(S.onJoin) do
			task.spawn(hook, player)
		end
	end
end
-- Take a released session lock back (a teleport that failed after its retry).
function S.rejoin(player)
	if not profiles.loaded[player] and profiles:load(player) then
		pushProfile(player)
	end
end

if S.role == "heist" then
	S.Heist = require(server.heist.Heist)
	S.Heist.init(S)
else
	if workspace:GetAttribute("BCTesting") then S.range = require(server.Range).build(S) end
	S.Garage = require(server.Garage)
	S.Garage.init(S)
	S.Lobby = require(server.Lobby)
	S.Lobby.init(S)
	require(server.Social).init(S)
	require(server.DailyService).init(S)
	S.onTeleportGiveUp = function(players, why)
		for _, p in ipairs(players) do
			S.rejoin(p)
			S.notify(p, "Teleport failed twice. Try again.")
		end
		Log.warn("Lobby", "teleport gave up", why)
	end
end

Players.PlayerAdded:Connect(join)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(join, p)
end
Players.PlayerRemoving:Connect(function(player)
	profiles:save(player, true)
	S.clientReports[player] = nil
end)
profiles:start()

server:SetAttribute("BCServerReady", true)
Log.info("Server", "ready", Config.Build, S.role, profiles.sessionOnly and "(session-only saves)" or "")
