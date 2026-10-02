-- Test-build client probe: compile/readiness probe, UI size probe, short frame probe, remote flood.
if not workspace:GetAttribute("BCTesting") then
	return
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

local t0 = os.clock()
repeat
	task.wait(0.1)
until lp:GetAttribute("BCClientReady") ~= nil or os.clock() - t0 > 30
local data = {
	ready = lp:GetAttribute("BCClientReady") == true,
	modules = lp:GetAttribute("BCClientModules") or 0,
	expected = lp:GetAttribute("BCClientExpected") or -1,
	failed = lp:GetAttribute("BCClientFailed") or "no report",
}
task.wait(1)

-- UI audit (startup and on demand): visible touch buttons in our HUD must be >= 44 px, must not overlap and
-- must stay on screen. Buttons scrolled out of a ScrollingFrame are clipped to it (hidden parts don't count).
local function shown(b, gui)
	local a = b.Parent
	while a and a ~= gui do
		if a:IsA("GuiObject") and not a.Visible then
			return false
		end
		a = a.Parent
	end
	return b.Visible
end
local function visibleRect(b, gui)
	local x0, y0 = b.AbsolutePosition.X, b.AbsolutePosition.Y
	local x1, y1 = x0 + b.AbsoluteSize.X, y0 + b.AbsoluteSize.Y
	local a = b.Parent
	while a and a ~= gui do
		if a:IsA("ScrollingFrame") or (a:IsA("GuiObject") and a.ClipsDescendants) then
			local p0, p1 = a.AbsolutePosition, a.AbsolutePosition + a.AbsoluteSize
			x0, y0, x1, y1 = math.max(x0, p0.X), math.max(y0, p0.Y), math.min(x1, p1.X), math.min(y1, p1.Y)
		end
		a = a.Parent
	end
	return x0, y0, x1, y1
end
local function audit()
	local gui = lp.PlayerGui:FindFirstChild("BlackoutCrewHud")
	local r = { hud = gui ~= nil, buttons = 0, minButton = math.huge, small = {}, overlaps = {}, offscreen = {} }
	local rects = {}
	local screen = gui and gui.AbsoluteSize or Vector2.zero
	for _, b in ipairs(gui and gui:GetDescendants() or {}) do
		if b:IsA("GuiButton") and b:GetAttribute("TouchTarget") and shown(b, gui) and b.AbsoluteSize.X > 0 then
			local x0, y0, x1, y1 = visibleRect(b, gui)
			if x1 - x0 > 1 and y1 - y0 > 1 then
				local s = math.min(b.AbsoluteSize.X, b.AbsoluteSize.Y)
				r.buttons += 1
				r.minButton = math.min(r.minButton, s)
				if s < 44 then
					table.insert(r.small, b.Name .. "=" .. math.floor(s))
				end
				if x0 < -1 or y0 < -1 or x1 > screen.X + 1 or y1 > screen.Y + 1 then
					table.insert(r.offscreen, b.Name)
				end
				for _, o in ipairs(rects) do
					if x0 < o[3] - 0.5 and x1 > o[1] + 0.5 and y0 < o[4] - 0.5 and y1 > o[2] + 0.5 then
						table.insert(r.overlaps, o[5] .. "+" .. b.Name)
					end
				end
				table.insert(rects, { x0, y0, x1, y1, b.Name })
			end
		end
	end
	r.small, r.overlaps, r.offscreen = table.concat(r.small, ","), table.concat(r.overlaps, ","), table.concat(r.offscreen, ",")
	return r
end
local ok, err = pcall(function()
	local gui = lp.PlayerGui:FindFirstChild("BlackoutCrewHud")
	data.hud = gui ~= nil
	data.buttons, data.minButton, data.small = 0, math.huge, {}
	if gui then
		for _, b in ipairs(gui:GetDescendants()) do
			if b:IsA("GuiButton") and b.Visible and b:GetAttribute("TouchTarget") then
				local vis = true
				local a = b.Parent
				while a and a ~= gui do
					if a:IsA("GuiObject") and not a.Visible then
						vis = false
					end
					a = a.Parent
				end
				if vis then
					local s = math.min(b.AbsoluteSize.X, b.AbsoluteSize.Y)
					data.buttons += 1
					data.minButton = math.min(data.minButton, s)
					if s < 44 then
						table.insert(data.small, b.Name .. "=" .. math.floor(s))
					end
				end
			end
		end
	end
	data.small = table.concat(data.small, ",")
	-- Layout audit: visible buttons must not overlap each other or leave the screen.
	local rects, bad, off = {}, {}, {}
	local screen = gui and gui.AbsoluteSize or Vector2.zero
	for _, b in ipairs(gui and gui:GetDescendants() or {}) do
		if b:IsA("GuiButton") and b:GetAttribute("TouchTarget") and b.Visible and b.Parent.Visible ~= false and b.AbsoluteSize.X > 0 then
			local shown = true
			local a = b.Parent
			while a and a ~= gui do
				if a:IsA("GuiObject") and not a.Visible then
					shown = false
				end
				a = a.Parent
			end
			if shown then
				local p0, p1 = b.AbsolutePosition, b.AbsolutePosition + b.AbsoluteSize
				if p0.X < -1 or p0.Y < -1 or p1.X > screen.X + 1 or p1.Y > screen.Y + 1 then
					table.insert(off, b.Name)
				end
				for _, r in ipairs(rects) do
					if p0.X < r[3] and p1.X > r[1] and p0.Y < r[4] and p1.Y > r[2] then
						table.insert(bad, r[5] .. "+" .. b.Name)
					end
				end
				table.insert(rects, { p0.X, p0.Y, p1.X, p1.Y, b.Name })
			end
		end
	end
	data.overlaps, data.offscreen = table.concat(bad, ","), table.concat(off, ",")
end)
data.uiError = not ok and tostring(err) or nil

-- End-to-end through the real input path: aim at a range dummy, pull the trigger, wait for the
-- server-confirmed Hit. Runs BEFORE the flood (the flood empties the Fire rate-limit bucket).
local okE2E, errE2E = pcall(function()
	local cs = require(lp.PlayerScripts:WaitForChild("BlackoutCrew"):WaitForChild("ClientState"))
	local gc, rig = cs.GunClient, cs.CameraRig
	local t1 = os.clock()
	repeat
		task.wait(0.1)
	until (gc and gc.stats) or os.clock() - t1 > 10
	local target = workspace:WaitForChild("Range", 10):WaitForChild("Static10", 10)
	local body = target and target:WaitForChild("Body", 5)
	data.e2eGun = gc.gunId
	rig.lookAt(body.Position)
	task.wait(0.8) -- draw time + camera settle
	data.e2eAimOnTarget = rig.assistActive(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.LookVector)
	local ammo0, hits0, shots0 = gc.ammo[gc.gunId], gc.confirmedHits, gc.shots
	cs.emit("fire", true)
	task.wait(0.1)
	cs.emit("fire", false)
	local t2 = os.clock()
	repeat
		task.wait(0.05)
	until gc.confirmedHits > hits0 or os.clock() - t2 > 3
	data.e2eShots = gc.shots - shots0
	data.e2eAmmoDelta = ammo0 - gc.ammo[gc.gunId]
	data.e2eConfirmed = gc.confirmedHits - hits0
	local cam = workspace.CurrentCamera
	local vm = cs.ViewModel.rootPart()
	local vp = cam.ViewportSize
	local hip = vm and cam:WorldToViewportPoint(vm.Position)
	data.vmHip = hip and hip.Z > 0 and hip.X > vp.X * 0.5 and hip.Y > vp.Y * 0.5 and hip.X < vp.X and hip.Y < vp.Y
	cs.emit("adsToggle")
	-- Wait for the blend to finish, not a fixed time: the unfocused CLI window throttles rendering.
	local t3 = os.clock()
	repeat
		task.wait(0.05)
	until (cs.ViewModel.adsProgress() >= 0.999 and cam.FieldOfView < cs.Config.Camera.Fov - 5) or os.clock() - t3 > 4
	data.adsBlend = cs.ViewModel.adsProgress()
	local ads = vm and cam:WorldToViewportPoint(vm.Position)
	data.vmAds = ads and ads.Z > 0 and math.abs(ads.X - vp.X / 2) < vp.X * 0.08
	data.adsOn = gc.ads
	data.adsFov = workspace.CurrentCamera.FieldOfView
	cs.emit("adsToggle")
	local t4 = os.clock()
	repeat
		task.wait(0.05)
	until (cs.ViewModel.adsProgress() <= 0.001 and cam.FieldOfView > cs.Config.Camera.Fov - 3) or os.clock() - t4 > 4
	data.hipFov = workspace.CurrentCamera.FieldOfView
	data.comingSoon = select(2, gc.equip(4))
	data.wheelOpenable = cs.Wheel ~= nil
	cs.emit("wheelOpen")
	data.wheelOpened = cs.Wheel.open
	cs.emit("wheelRelease")
	data.wheelClosed = not cs.Wheel.open
end)
data.e2eError = not okE2E and tostring(errE2E) or nil

-- Remote flood: 60 Fire events in one frame; the server's rate limiter must drop most of them.
local remotes = RS:FindFirstChild("BlackoutCrew") and RS.BlackoutCrew:FindFirstChild("Remotes")
if remotes and remotes:FindFirstChild("Fire") then
	for i = 1, 60 do
		remotes.Fire:FireServer(1e6 + i, Vector3.zero, Vector3.new(0, 0, -1), false)
	end
	data.flooded = 60
end

-- Frame probe (short in tests; the CLI window is throttled so this is not a phone number).
local samples, total, elapsed = {}, 0, 0
local done = false
local conn
conn = RunService.RenderStepped:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 then
		return
	end
	table.insert(samples, dt)
	total += dt
	if total >= 3 then
		conn:Disconnect()
		done = true
	end
end)
repeat
	task.wait(0.1)
until done or os.clock() - t0 > 60
if #samples > 0 then
	table.sort(samples)
	data.perf = { meanFPS = #samples / total, p95ms = samples[math.ceil(#samples * 0.95)] * 1000, frames = #samples }
end
-- Commands after the baseline probe exercise the real lobby client and network path.
RS:WaitForChild("BCTestCmd").OnClientEvent:Connect(function(id, name, ...)
	local args = table.pack(...)
	local ok, res = pcall(function()
		local cs = require(lp.PlayerScripts.BlackoutCrew.ClientState)
		if name == "moveTo" then
			lp:RequestStreamAroundAsync(args[1], 3)
			local root = lp.Character.HumanoidRootPart
			root.CFrame = CFrame.new(args[1])
			root.AssemblyLinearVelocity = Vector3.zero
			return true
		elseif name == "garage" then
			cs.remotes.GarageAction:FireServer(table.unpack(args, 1, args.n))
			return true
		elseif name == "ready" then
			cs.remotes.Queue:FireServer("ready", true)
			return true
		elseif name == "eval" then
			return cs.probe[args[1]](table.unpack(args, 2, args.n))
		elseif name == "menus" then
			cs.GarageClient.show("loadout")
			local armory = cs.ArmoryClient.open or cs.Menus.current == nil -- far from the armory it may refuse/close at once
			cs.SettingsUI.set(true)
			local exclusive = cs.SettingsUI.open and not cs.ArmoryClient.open and cs.Menus.current == "settings"
			local brakes = cs.KartClient.input().b
			cs.Wheel.show()
			exclusive = exclusive and cs.Wheel.open and not cs.SettingsUI.open and cs.cursorFree
			cs.Wheel.release()
			return { exclusive = exclusive and armory, brakes = brakes, restored = cs.Menus.current == nil and not cs.cursorFree }
		elseif name == "garageUI" then
			return { ready = cs.GarageClient ~= nil, open = cs.ArmoryClient.open, menu = cs.ArmoryClient.panel ~= nil, locker = cs.LockerClient.panel ~= nil }
		elseif name == "state" then
			local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
			return { menu = cs.Menus.current, cursorFree = cs.cursorFree, cutscene = cs.cutscene == true,
				prompts = game:GetService("ProximityPromptService").Enabled, alive = hum ~= nil and hum.Health > 0,
				fireShown = cs.Controls.buttons.fire and cs.Controls.buttons.fire.Visible, crosshair = cs.Hud.cross.Visible,
				equipped = cs.profile and cs.profile.cosmetics.equipped }
		elseif name == "setting" then
			cs.settings[args[1]] = args[2]
			cs.emit("settings", cs.settings)
			return true
		elseif name == "look" then -- point the first-person camera at a world position
			cs.CameraRig.lookAt(args[1])
			return true
		elseif name == "menuBack" then -- what the Back binding (Backspace / gamepad B) runs
			cs.Menus.closeCurrent()
			return cs.Menus.current == nil
		elseif name == "gunTris" then -- measured render cost: Stats.SceneTriangleCount with vs without each model in view
			local GunModel = require(RS.BlackoutCrew.GunModel)
			local St, RunS, cam = game:GetService("Stats"), game:GetService("RunService"), workspace.CurrentCamera
			local function frames(n) for _ = 1, n do RunS.RenderStepped:Wait() end end
			local function measure(m)
				local best = math.huge
				for _ = 1, 3 do
					m.Parent = nil
					frames(3)
					local base = St.SceneTriangleCount
					m:PivotTo(cam.CFrame * CFrame.new(0, 0, -7) * CFrame.Angles(0, math.rad(90), 0))
					m.Parent = cam
					frames(3)
					best = math.min(best, St.SceneTriangleCount - base)
				end
				m:Destroy()
				return best
			end
			local out = {}
			local AS = game:GetService("AssetService")
			local e1 = AS:CreateEditableMesh()
			out.direct = tostring(e1)
			if e1 then e1:Destroy() end
			out.memMb = game:GetService("Stats"):GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
			for _, g in ipairs(cs.Config.Guns) do
				local fp, kind = GunModel.buildFirstPerson(g)
				fp.PrimaryPart.Anchored = true
				local w = GunModel.build(g)
				w.PrimaryPart.Anchored = true
				local meshes, sizeOk = 0, true
				for _, d in ipairs(fp:GetDescendants()) do
					if d:IsA("MeshPart") then meshes += 1 end
				end
				out[g.id] = { kind = kind, status = GunModel.fpStatus[g.id], fp = measure(fp), world = measure(w), meshes = meshes, art = fp:GetAttribute("Tris") }
			end
			return out
		elseif name == "stageGuns" then -- photo staging: fixed camera (cutscene), HUD + viewmodel hidden, guns on a grey backdrop
			local GunModel = require(RS.BlackoutCrew.GunModel)
			local cam = workspace.CurrentCamera
			local old = workspace:FindFirstChild("BCStage")
			if old then old:Destroy() end
			local f = Instance.new("Folder")
			f.Name = "BCStage"
			local at = CFrame.new(0, 400, 0)
			local back = Instance.new("Part")
			back.Anchored, back.Size, back.Color, back.Material = true, Vector3.new(40, 30, 1), Color3.fromRGB(128, 128, 132), Enum.Material.SmoothPlastic
			back.CFrame = at * CFrame.new(0, 0, -12)
			back.Parent = f
			local ids = args[1] or { "dart9", "buzz", "ranger", "needle" }
			for i, id in ipairs(ids) do
				local m = GunModel.buildFirstPerson(cs.Config.GunsById[id])
				m.PrimaryPart.Anchored = true
				local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
				m:PivotTo(at * CFrame.new(-2.6 + col * 4.6, 1.3 - row * 2.4, -7) * CFrame.Angles(0, math.rad(args[2] or 90), 0) * CFrame.Angles(math.rad(args[3] or 0), 0, 0))
				m.Parent = f
			end
			f.Parent = workspace
			cs.cutscene = true
			for _, g in ipairs(lp.PlayerGui:GetChildren()) do
				if g:IsA("ScreenGui") then g.Enabled = false end
			end
			for _, d in ipairs(cam:GetChildren()) do
				if d:IsA("Model") then d.Parent = nil end
			end
			task.spawn(function()
				for _ = 1, 3000 do
					cam.CameraType = Enum.CameraType.Scriptable
					cam.FieldOfView = 50
					cam.CFrame = at
					game:GetService("RunService").RenderStepped:Wait()
				end
			end)
			return true
		elseif name == "gunEquip" then -- range loan -> the real server equip path; waits for the view model to finish building
			local G = cs.GunClient
			cs.remotes.RangeEquip:FireServer(args[1])
			local t = os.clock()
			repeat task.wait(0.05) until (G.gunId == args[1] and cs.ViewModel.model() ~= nil) or os.clock() - t > 6
			task.wait(cs.Config.Fire.DrawTime + 0.15)
			return { gun = G.gunId, status = cs.ViewModel.status, built = cs.ViewModel.model() ~= nil }
		elseif name == "elimReplay" then
			local before = cs.GunClient.eliminations
			for _ = 1, 3 do cs.GunClient.confirmElimination(args[1]) end
			return cs.GunClient.eliminations - before
		elseif name == "gunState" then
			local cam = workspace.CurrentCamera
			local m = cs.ViewModel.model()
			local root = m and m.PrimaryPart
			local vp = cam.ViewportSize
			local function px(att)
				local a = root and root:FindFirstChild(att)
				if not a then return nil end
				local v, on = cam:WorldToViewportPoint(a.WorldPosition)
				return { x = v.X - vp.X / 2, y = v.Y - vp.Y / 2, on = on, z = v.Z }
			end
			local hiddenParts, shown = 0, 0
			for _, d in ipairs(m and m:GetDescendants() or {}) do
				if d:IsA("BasePart") and d.Transparency < 1 then
					if d.LocalTransparencyModifier >= 1 then hiddenParts += 1 else shown += 1 end
				end
			end
			local e = cs.Hud.elim
			return { gun = cs.GunClient.gunId, ads = cs.GunClient.ads, alpha = cs.ViewModel.adsProgress(), fov = cam.FieldOfView,
				scoped = cs.ViewModel.scoped(), scopeGui = cs.Hud.scopeGui.Enabled, hidden = hiddenParts, shown = shown,
				cross = cs.Hud.cross.Visible, sight = px("Sight"), front = px("FrontSight"), muzzle = px("Muzzle"),
				elimShown = cs.Hud.elimShown, eliminations = cs.GunClient.eliminations, menu = cs.Menus.current,
				elimRect = { x = e.AbsolutePosition.X - vp.X / 2, y = e.AbsolutePosition.Y + game:GetService("GuiService"):GetGuiInset().Y - vp.Y / 2, w = e.AbsoluteSize.X, h = e.AbsoluteSize.Y },
				status = cs.ViewModel.status, sfx = cs.GunSfx.played, ammo = cs.GunClient.ammo[cs.GunClient.gunId] }
		elseif name == "gunAds" then -- input-equivalent ADS toggle; waits n seconds
			cs.GunClient.setAds(args[1] == true)
			if args[2] then task.wait(args[2]) end
			return cs.ViewModel.adsProgress()
		elseif name == "adsSpam" then -- rapid toggles, ends released
			for i = 1, args[1] do
				cs.GunClient.setAds(i % 2 == 1)
				task.wait(args[2] or 0.03)
			end
			cs.GunClient.setAds(false)
			return true
		elseif name == "gunSwap" then
			cs.GunClient.equip(args[1])
			game:GetService("RunService").RenderStepped:Wait()
			return true
		elseif name == "openMenu" then
			cs.SettingsUI.set(true)
			game:GetService("RunService").RenderStepped:Wait()
			local r = { fov = workspace.CurrentCamera.FieldOfView, alpha = cs.ViewModel.adsProgress(), scoped = cs.ViewModel.scoped(), menu = cs.Menus.current }
			cs.SettingsUI.set(false)
			return r
		elseif name == "uiAudit" then
			return audit()
		elseif name == "armory" then
			local A, op = cs.ArmoryClient, args[1]
			if op == "show" then
				A.show(args[2])
			elseif op == "preview" then
				A.previewSlot(args[2], args[3])
			elseif op == "request" then -- a raw station request through the real ack channel
				local done
				cs.GarageClient.request(args[2], args[3], args[4], function(ok, why) done = { ok = ok, reason = why } end)
				local t = os.clock()
				repeat task.wait(0.05) until done or os.clock() - t > 5
				return done
			elseif op == "flood" then -- n requests in one frame; the server's bucket drops most, unanswered ones time out
				local acked, timedOut = 0, 0
				for _ = 1, args[2] do
					cs.GarageClient.request("clear", 99, nil, function(_, why) if why == "timeout" then timedOut += 1 else acked += 1 end end)
				end
				local t = os.clock()
				repeat task.wait(0.1) until acked + timedOut >= args[2] or os.clock() - t > 8
				return { acked = acked, timedOut = timedOut }
			elseif op ~= "snapshot" then
				A[op](args[2])
			end
			if op == "apply" or op == "equip" or op == "remove" then
				local t = os.clock()
				repeat task.wait(0.05) until not A.busy or os.clock() - t > 5
			end
			return A.snapshot()
		elseif name == "locker" then
			local L, op = cs.LockerClient, args[1]
			if op == "pick" then
				return { ok = L.pick(args[2], args[3]), snap = L.snapshot() }
			elseif op ~= "snapshot" then
				L[op]()
			end
			if op == "apply" then
				local t = os.clock()
				repeat task.wait(0.05) until not L.busy or os.clock() - t > 5
			end
			return L.snapshot()
		elseif name == "pad" then
			cs.LobbyClient.refresh()
			local st = cs.LobbyClient.state(args[1])
			local b = cs.LobbyClient.boards[args[1]]
			local rows = {}
			for i, r in ipairs(b and b.rows or {}) do
				rows[i] = r.name.Text .. "|" .. r.tag.Text
			end
			return st and { count = st.count, status = st.status, label = st.label, mode = st.mode, members = st.members,
				board = b and { count = b.count.Text, status = b.status.Text, title = b.title.Text, rows = rows, onPart = b.gui.Parent ~= nil } }
		end
		error("unknown command " .. name)
	end)
	RS.BCTestReport:FireServer({ cmdId = id, ok = ok, res = res })
end)
RS:WaitForChild("BCTestReport"):FireServer(data)
