-- Heist world blockout (primitives only). Built once at server start; Build 2 step 1: ground + arrival.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)

local Map = {}

function Map.init(S)
	local folder = Instance.new("Folder")
	folder.Name = "HeistMap"
	folder.Parent = workspace
	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = Vector3.new(1400, 1, 600)
	ground.CFrame = CFrame.new(440, -0.5, 0)
	ground.Anchored = true
	ground.Color = Color3.fromRGB(30, 32, 40)
	ground.Material = Enum.Material.Asphalt
	ground.Parent = folder
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ArrivalSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(-150, -0.45, 20)
	spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
	spawn.Color = Config.Colors.Panel
	spawn.Parent = folder
	Map.folder, Map.arrival = folder, spawn
end

return Map
