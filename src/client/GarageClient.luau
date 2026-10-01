-- Local tutorial path, roll-up departure and the station request channel shared by the personal armory
-- (ArmoryClient) and locker (LockerClient). No network traffic while idle.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Garage = {}
local lp = Players.LocalPlayer
local ctx, C, Hud, Map, tutorial, text, skip, path
local pending, nextReq = {}, 0
local MESSAGES = {
	gun = "WELCOME · Follow the white arrows into the armory. Grab the free Dart-9.",
	friend = "GUIDE: Got your blaster? Come say hello outside the armory.",
	invite = "YOU: Ready for a run.  GUIDE: Join my practice squad! Talk to me again to accept.",
	kart = "GUIDE: We're a squad. Your kart is waiting by the bay. Walk up and choose DRIVE.",
	queue = "GUIDE: Drive to a HEIST pad, then press READY. Human squadmates join you on the pad.",
}
local REASONS = {
	far = "Move closer to the station.", locked = "You don't own that yet.", incompatible = "That doesn't fit.",
	invalid = "That item isn't available.", comingSoon = "Slots 4 and 5 unlock in a later update.",
	lastGun = "Keep at least one blaster equipped.", noProfile = "Your profile is still loading.",
	timeout = "No answer from the server.",
}
function Garage.reasonText(reason)
	return REASONS[reason] or "The server refused that change."
end
local function send(action, id, slot)
	ctx.remotes.GarageAction:FireServer(action, id, slot)
	ctx.netSends += 1
end
-- Station request with a server acknowledgement. done(ok, reason) runs exactly once: on the ack, or with
-- "timeout" if none arrives (e.g. a rate-limited request was dropped) so the UI can restore the saved setup.
function Garage.request(action, a, b, done)
	nextReq += 1
	local id = nextReq
	pending[id] = done or function() end
	ctx.remotes.GarageAction:FireServer(action, a, b, id)
	ctx.netSends += 1
	task.delay(C.Garage.AckTimeout, function()
		local fn = pending[id]
		if fn then
			pending[id] = nil
			fn(false, "timeout")
		end
	end)
	return id
end
-- Kept for callers/tests that open the armory by tab name.
function Garage.show(which)
	ctx.ArmoryClient.show(which)
end
function Garage.close()
	ctx.ArmoryClient.close()
end
local function target(stage)
	if stage == "gun" then return Map.point(C.Garage.GunWall + Vector3.new(5, -4, 0)) end
	if stage == "friend" or stage == "invite" then return Map.point(C.Garage.Friend) end
	if stage == "kart" then
		local folder = workspace:FindFirstChild("GarageKarts")
		local kart = folder and folder:FindFirstChild("GarageKart" .. lp.UserId)
		return kart and kart.PrimaryPart and kart.PrimaryPart.Position or Map.point(C.Garage.KartBay)
	end
	if stage == "queue" then return Vector3.new(C.Lobby.Pads[1].x, 0, C.Lobby.Pads[1].z) end
end
local function refreshPath()
	local stage = lp:GetAttribute("BC_Tutorial")
	local goal = target(stage)
	local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	tutorial.Visible = goal ~= nil and not workspace:GetAttribute("BCTesting") and not ctx.Menus.current
	text.Text = MESSAGES[stage] or ""
	-- Reuse a small local pool. Two bends take players through the open armory entrance.
	local points = {}
	if root and goal and tutorial.Visible then
		local from = Vector3.new(root.Position.X, 0.08, root.Position.Z)
		table.insert(points, from)
		if stage == "gun" and from.X > C.Garage.Origin.X - 60 then
			table.insert(points, Map.point(Vector3.new(-56, 0.08, 5)))
		elseif (stage == "friend" or stage == "invite") and from.X < C.Garage.Origin.X - 62 then
			table.insert(points, Map.point(Vector3.new(-56, 0.08, 5)))
		end
		table.insert(points, Vector3.new(goal.X, 0.08, goal.Z))
	end
	local n = 0
	for j = 1, #points - 1 do
		local delta = points[j + 1] - points[j]
		if delta.Magnitude > 0.1 then
			for d = 3, delta.Magnitude, 6 do
				n += 1
				if n > #path then break end
				local at = points[j] + delta.Unit * d
				path[n].CFrame = CFrame.lookAt(at, at + delta)
				path[n].Transparency = 0.15
			end
		end
	end
	for i = math.min(n, #path) + 1, #path do path[i].Transparency = 1 end
	for _, p in ipairs(path) do p.SurfaceGui.Enabled = p.Transparency < 1 end
end
local function depart()
	ctx.Menus.closeCurrent()
	if ctx.settings.reducedMotion then Hud.toast("Squad ready — heading out!", C.Garage.CutsceneSeconds); return end
	local start = os.clock()
	local garage = workspace:FindFirstChild("Garage")
	local door = garage and garage:FindFirstChild("RollUpDoor")
	local original = door and door.CFrame
	local ribs = {}
	for _, rib in ipairs(door and door:GetChildren() or {}) do
		if rib:IsA("BasePart") then ribs[rib] = rib.CFrame end
	end
	local visual = require(ctx.shared.KartModel).build(1, Map.frame(Vector3.new(0, 0, -28)), { name = "DepartureKart" })
	for _, p in ipairs(visual:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide, p.CanTouch, p.CanQuery = false, false, false end
	end
	visual.Parent = workspace
	ctx.cutscene = true
	RunService:BindToRenderStep("BCDeparture", Enum.RenderPriority.Camera.Value + 5, function()
		local f = math.clamp((os.clock() - start) / C.Garage.CutsceneSeconds, 0, 1)
		local lift = Vector3.new(0, math.min(1, (os.clock() - start) / 0.7) * 20, 0)
		if door then door.CFrame = original + lift end
		for rib, cf in pairs(ribs) do rib.CFrame = cf + lift end
		-- Down the lane between the queue pads and out of the roll-up door.
		visual:PivotTo(Map.frame(Vector3.new(0, 0, -28 - f * 40)) * CFrame.Angles(0, math.rad(15 * math.sin(f * math.pi) * f), 0))
		local cam = workspace.CurrentCamera
		cam.CFrame = CFrame.lookAt(Map.point(Vector3.new(0, 6, -12)), Map.point(Vector3.new(0, 2.5, -34 - f * 20)))
	end)
	task.delay(C.Garage.CutsceneSeconds, function()
		RunService:UnbindFromRenderStep("BCDeparture")
		ctx.cutscene = false
		visual:Destroy()
		if door and door.Parent then door.CFrame = original end
		for rib, cf in pairs(ribs) do if rib.Parent then rib.CFrame = cf end end
	end)
end
function Garage.init(c)
	ctx, C, Hud = c, c.Config, c.Hud
	Map = require(c.shared.GarageMap)
	tutorial = Hud.make("Frame", Hud.root, { Name = "Tutorial", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(420, 68), BackgroundColor3 = C.UI.Paper, Visible = false })
	Hud.surface(tutorial, true)
	text = Hud.label(tutorial, "", 12, { Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -74, 1, -8), TextWrapped = true })
	skip = Hud.button(tutorial, "SkipTutorial", "SKIP", 54, { Position = UDim2.new(1, -32, 0.5, 0), TextSize = 11 })
	skip.Activated:Connect(function() send("skip") end)
	UserInputService.InputBegan:Connect(function(input, processed)
		-- Backspace closes an open menu first (Menus); it only skips the tutorial with no menu open.
		if not processed and not ctx.Menus.current and input.KeyCode == C.Keys.TutorialSkip and MESSAGES[lp:GetAttribute("BC_Tutorial")] ~= nil then send("skip") end
	end)
	path = {}
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "TutorialPath", workspace
	for i = 1, 32 do
		local p = Instance.new("Part")
		p.Name, p.Size = "WhiteArrow", Vector3.new(2, 0.05, 3)
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p.Material, p.Color, p.Transparency = Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), 1
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.Parent = Enum.NormalId.Top, p
		local arrow = Instance.new("TextLabel")
		arrow.Size, arrow.BackgroundTransparency, arrow.Text, arrow.TextScaled = UDim2.fromScale(1, 1), 1, "^", true
		arrow.TextColor3, arrow.Parent = Color3.new(0, 0, 0), gui
		p.Parent = folder
		path[i] = p
	end
	ctx.remotes.GarageEvent.OnClientEvent:Connect(function(which, id, ok, reason)
		if which == "ack" then
			local fn = type(id) == "number" and pending[id]
			if fn then
				pending[id] = nil
				fn(ok == true, reason)
			end
		elseif which == "depart" then
			depart()
		elseif which == "loadout" or which == "bench" then
			ctx.ArmoryClient.show(which)
		elseif which == "locker" then
			ctx.LockerClient.enter()
		end
	end)
	task.spawn(function()
		while true do
			refreshPath()
			task.wait(0.25)
		end
	end)
	Garage.tutorial = tutorial
end
return Garage
