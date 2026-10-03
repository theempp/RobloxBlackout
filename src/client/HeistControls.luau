-- Heist inputs: the context HOLD button (§5f) + Sneak toggle. The button appears only when something
-- is in reach (shared Actions rules on the replicated snapshot, 5 Hz). Holding sends Action start/stop
-- and fills the button locally; the server runs the real timer and replies (HeistEvent "action").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HeistControls = { kind = nil, target = nil, holding = nil, sneak = false, results = {} }
local ctx, C, Actions
local lp = Players.LocalPlayer

local function send(...)
	ctx.remotes.Action:FireServer(...)
	ctx.netSends += 1
end

function HeistControls.begin()
	local kind, target = HeistControls.kind, HeistControls.target
	if not kind or HeistControls.holding or ctx.cursorFree then -- menus suppress context actions
		return
	end
	local dur = (target and target.hold) or C.Actions[kind].hold
	HeistControls.holding = { kind = kind, t0 = os.clock(), dur = dur }
	send("start", kind, target and target.inst)
	ctx.emit("actionStart", kind, target and target.inst)
end

function HeistControls.finish()
	if HeistControls.holding then
		HeistControls.holding = nil
		send("stop")
	end
end

local function toggleSneak()
	HeistControls.sneak = not HeistControls.sneak
	ctx.remotes.Sneak:FireServer(HeistControls.sneak)
	ctx.netSends += 1
	local b = ctx.Controls.buttons.sneak
	if b then
		b.BackgroundColor3 = HeistControls.sneak and C.Colors.Accent or (b:GetAttribute("RestFill") or C.Colors.Panel)
	end
end
HeistControls.toggleSneak = toggleSneak

function HeistControls.refresh()
	local me, world = Actions.gather(lp)
	local kind, target
	if me and workspace:FindFirstChild("HeistState") and workspace.HeistState:GetAttribute("Phase") == "running" then
		kind, target = Actions.best(me, world, C.Actions)
	end
	HeistControls.kind, HeistControls.target = kind, target
	ctx.Controls.setContext("action", kind ~= nil, kind and C.Actions[kind].label or "")
	if HeistControls.holding and HeistControls.holding.kind ~= kind then
		HeistControls.finish() -- target walked away / changed: release
	end
end

function HeistControls.init(c)
	ctx = c
	C = ctx.Config
	Actions = require(ctx.shared.Actions)
	local Controls = ctx.Controls
	local btn = Controls.buttons.action
	local fill = ctx.Hud.make("Frame", btn, { Name = "Fill", BorderSizePixel = 0, BackgroundColor3 = C.Colors.Accent, BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(1, 0), ZIndex = btn.ZIndex })
	ctx.Hud.corner(fill, UDim.new(0.5, 0))
	Controls.press("action", HeistControls.begin, HeistControls.finish)
	Controls.press("sneak", toggleSneak)
	ctx.on("actionPress", function(down)
		if down then
			HeistControls.begin()
		else
			HeistControls.finish()
		end
	end)
	ctx.on("sneakToggle", toggleSneak)
	ctx.remotes.HeistEvent.OnClientEvent:Connect(function(kind, data)
		if kind == "action" and type(data) == "table" then
			HeistControls.holding = nil
			table.insert(HeistControls.results, data)
			if not data.ok and data.why == "invalid" then
				ctx.Hud.toast("Can't do that here", 1.5)
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		local h = HeistControls.holding
		local f = h and (h.dur > 0 and math.clamp((os.clock() - h.t0) / h.dur, 0, 1) or 1) or 0
		fill.Size = UDim2.fromScale(1, f)
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			pcall(HeistControls.refresh)
		end
	end)
	ctx.probe = ctx.probe or {}
	ctx.probe.action = function()
		HeistControls.refresh()
		return { kind = HeistControls.kind, target = HeistControls.target and HeistControls.target.inst.Name or nil,
			shown = ctx.Controls.buttons.action.Visible }
	end
end

return HeistControls
