-- Applies the run's twist to the world: Blackout's lighting (server Lighting replicates), restored on reset.
-- Param flips (vision, sentries) are already in run.params (Heist.start); this only does the visuals.
local Lighting = game:GetService("Lighting")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)

local Twist = {}
local S, saved

function Twist.init(s)
	S = s
end

function Twist.start(_, run)
	local def = run.twist and Config.Twists[run.twist]
	workspace.HeistState:SetAttribute("Twist", def and def.name or "")
	if def and def.lighting then
		saved = saved or {}
		for k, v in pairs(def.lighting) do
			saved[k] = saved[k] == nil and Lighting[k] or saved[k]
			Lighting[k] = v
		end
	end
	for _, p in ipairs(run.players) do
		if def then
			S.notify(p, "TWIST: " .. def.name)
		end
	end
end

function Twist.reset()
	if saved then
		for k, v in pairs(saved) do
			Lighting[k] = v
		end
		saved = nil
	end
end

return Twist
