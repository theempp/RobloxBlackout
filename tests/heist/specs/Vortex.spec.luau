-- The shipped Vortex asset must import into Studio and drive the existing kart rig.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)
local KartModel = require(RS.BlackoutCrew.KartModel)

return function(T)
	local tpl = KartModel.template()
	if not T.check("Vortex template imported", tpl ~= nil) then return end
	local frame, why = KartModel.templateFrame(tpl)
	if not T.check("Vortex frame and hub alignment", frame ~= nil, why) then return end
	local count, white, black = 0, 0, 0
	local shaped = 0
	for _, p in ipairs(tpl:GetDescendants()) do
		if p:IsA("BasePart") then
			count += 1
			if p:IsA("MeshPart") then
				shaped += 1
				T.check("uploaded body mesh " .. p.Name, p.MeshId:match("^rbxassetid://%d+$") ~= nil)
			end
			if p.Color.R > 0.7 and p.Color.G > 0.7 and p.Color.B > 0.7 then white += 1 end
			if p.Color.R < 0.2 and p.Color.G < 0.2 and p.Color.B < 0.2 then black += 1 end
		end
	end
	T.eq("18 sculpted Studio meshes replace the angular body", shaped, 18)
	T.check("complete dark body and white strips", count >= 110 and white >= 12 and black >= 90,
		string.format("parts=%d white=%d black=%d", count, white, black))
	T.check("wheel bars and raised fender strips removed", tpl:FindFirstChild("Spoke_FL_0") == nil
		and tpl:FindFirstChild("Fender_FL") == nil and tpl:FindFirstChild("FenderEdge_FL") == nil)
	T.check("swept windshields and side glass close the cockpit", tpl:FindFirstChild("Door_L_Glass") and tpl:FindFirstChild("Door_R_Glass")
		and tpl.Door_L_Glass.Size.Z > 2.4 and tpl.Door_R_Glass.Size.Z > 2.4
		and tpl:FindFirstChild("Door_L_SideGlass") and tpl:FindFirstChild("Door_R_SideGlass")
		and tpl:FindFirstChild("Door_L_RoofGlass") and tpl:FindFirstChild("Door_R_RoofGlass"))
	T.check("central halo replaces old glass roof", tpl:FindFirstChild("HaloFront") and tpl:FindFirstChild("HaloCrown")
		and tpl:FindFirstChild("HaloRear_L") and tpl:FindFirstChild("HaloRear_R") and not tpl:FindFirstChild("CanopyRoof"))
	local bridge, cover, close = tpl:FindFirstChild("RearRoofBridge"), tpl:FindFirstChild("EngineCover"), tpl:FindFirstChild("RearClosure")
	local function span(p)
		local z = frame:PointToObjectSpace(p.Position).Z
		return z - p.Size.Z / 2, z + p.Size.Z / 2
	end
	local joined = false
	if bridge and cover and close then
		local _, b1 = span(bridge)
		local c0, c1 = span(cover)
		local t0 = span(close)
		joined = b1 >= c0 and c1 >= t0
	end
	T.check("bodywork bridges cockpit, engine and tail", joined)
	local char = T.player.Character
	local pos = char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position or Vector3.new(0, 500, 0)
	local m, root, seat = KartModel.build(1, CFrame.new(pos))
	m.Parent = workspace
	T.eq("Vortex visual selected", m:GetAttribute("Visual"), "vortex")
	T.check("single seat and cockpit steering", seat:IsA("VehicleSeat") and m:FindFirstChild("Steer") ~= nil and root:FindFirstChild("M_Steer") ~= nil)
	local motors, beams, leds = 0, 0, 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Motor6D") then motors += 1 end
		if d:IsA("Beam") and d.Name:match("^ControlArm_") then beams += 1 end
		if d:IsA("BasePart") and d:GetAttribute("VortexLED") then leds += 1 end
	end
	T.check("articulated butterfly doors", root:FindFirstChild("M_Door_L_Shell") ~= nil and root:FindFirstChild("M_Door_R_Shell") ~= nil)
	T.eq("visible moving control arms", beams, 20)
	T.check("wheel and door rig within budget", motors >= 20 and motors <= 44 and KartModel.tris(m) <= C.TriBudget.Kart,
		string.format("motors=%d tris=%d", motors, KartModel.tris(m)))
	T.eq("12 named white LEDs tagged for driver toggle", leds, 12)
	T.eq("visual chassis locator stays invisible", m.Chassis.Transparency, 1)
	local k = { model = m, root = root, seat = seat, owner = T.player }
	T.check("non-owner cannot use vehicle", KartModel.action(k, nil, "lights") == false)
	local before = m:GetAttribute("LightsOn")
	T.check("owner LED control", KartModel.action(k, T.player, "lights") and m:GetAttribute("LightsOn") ~= before)
	T.check("owner door control", KartModel.action(k, T.player, "doors") and m:GetAttribute("DoorsOpen") == true)
	root.AssemblyLinearVelocity = Vector3.new(5, 0, 0)
	KartModel.closeMovingDoors(k)
	T.check("doors close on motion", m:GetAttribute("DoorsOpen") == false)
	m:Destroy()
end
