-- Server bootstrap: remotes, profiles, receipts, guns, test range.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("BlackoutCrew")
local Config = require(shared.Config)
local Rules = require(shared.Rules)
local Net = require(shared.Net)
local Log = require(shared.Log)
local server = script.Parent
local Profiles = require(server.Profiles)
local Receipts = require(server.Receipts)
local Remotes = require(server.Remotes)

local remotes = Net.server()
local profiles = Profiles.new()
local S = require(server.ServerState)
S.remotes, S.profiles, S.Remotes, S.clientReports = remotes, profiles, Remotes, {}
server:SetAttribute("BCServerReady", false)

local function pushProfile(player)
	local d = profiles.loaded[player]
	if d then
		remotes.Profile:FireClient(player, { settings = d.settings, guns = d.guns, credits = d.credits })
	end
end
S.pushProfile = pushProfile

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
end)

MarketplaceService.ProcessReceipt = Receipts.handler({
	products = Config.Products,
	profiles = profiles,
	getPlayer = function(id)
		return Players:GetPlayerByUserId(id)
	end,
	onGranted = pushProfile,
})

local function join(player)
	if profiles:load(player) then
		pushProfile(player)
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
Log.info("Server", "ready", Config.Build, profiles.sessionOnly and "(session-only saves)" or "")
