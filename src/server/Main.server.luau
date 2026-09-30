-- Server bootstrap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("BlackoutCrew")
local Net = require(shared.Net)
local Log = require(shared.Log)

local remotes = Net.server()
local server = script.Parent
local ctx = { remotes = remotes, Config = require(shared.Config), Log = Log }
server:SetAttribute("BCServerReady", true)
Log.info("Server", "ready", ctx.Config.Build)
