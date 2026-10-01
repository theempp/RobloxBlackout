-- Perf overlay (settings toggle / F7): fps, p95 frame time, memory, ping, remote sends per second.
-- Benchmark = ported frame probe (skip ProbeSkip s, sample ProbeSample s -> mean fps + p95), shown on
-- screen for the owner's phone test and printed as BC_FRAME_PROFILE. Fixed ring buffer, no per-frame tables.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local PerfOverlay = {}
local ctx, C, Hud
local N = 240
local ring = table.create(N, 0)
local sorted = table.create(N, 0)
local head, count = 0, 0
local label
local acc, frames = 0, 0
local sendsAt, sendsPrev = 0, 0

local function desc(a, b)
	return a > b
end

local function p95(n)
	for i = 1, n do
		sorted[i] = ring[i]
	end
	for i = n + 1, N do
		sorted[i] = 0
	end
	table.sort(sorted, desc)
	return sorted[math.max(1, math.ceil(n * 0.05))]
end

function PerfOverlay.benchmark()
	local P = C.Perf
	Hud.toast("Benchmark: hold still " .. (P.ProbeSkip + P.ProbeSample) .. " s…", P.ProbeSkip + 1)
	local samples, total, elapsed = {}, 0, 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < P.ProbeSkip then
			return
		end
		table.insert(samples, dt)
		total += dt
		if total >= P.ProbeSample then
			conn:Disconnect()
			table.sort(samples)
			local mean = #samples / total
			local p = samples[math.ceil(#samples * 0.95)] * 1000
			local msg = string.format("meanFPS=%.1f p95ms=%.1f frames=%d", mean, p, #samples)
			print("BC_FRAME_PROFILE", msg)
			Hud.toast("Benchmark: " .. msg, 12)
			PerfOverlay.last = { meanFPS = mean, p95ms = p, frames = #samples }
		end
	end)
end

function PerfOverlay.init(c)
	ctx = c
	C = ctx.Config
	Hud = ctx.Hud
	label = Hud.label(Hud.root, "", 12, { Name = "Perf", Position = UDim2.fromOffset(74, 20), Size = UDim2.fromOffset(420, 18),
		TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Code, TextStrokeTransparency = 0.4, TextColor3 = C.Colors.Text, Visible = false })
	ctx.on("settings", function(s)
		label.Visible = s.perfOverlay
	end)
	ctx.on("togglePerf", function()
		ctx.settings.perfOverlay = not ctx.settings.perfOverlay
		ctx.emit("settings", ctx.settings)
	end)
	ctx.on("benchmark", PerfOverlay.benchmark)
	RunService.RenderStepped:Connect(function(dt)
		head = head % N + 1
		ring[head] = dt
		count = math.min(count + 1, N)
		acc += dt
		frames += 1
		if acc >= C.Perf.OverlayRate then
			if label.Visible then
				local now = os.clock()
				local rate = (ctx.netSends - sendsPrev) / math.max(now - sendsAt, 1e-3)
				sendsAt, sendsPrev = now, ctx.netSends
				label.Text = string.format("FPS %d | p95 %.0fms | %dMB | ping %dms | net %d/s",
					math.floor(frames / acc + 0.5), p95(count) * 1000, Stats:GetTotalMemoryUsageMb(),
					Players.LocalPlayer:GetNetworkPing() * 2000, rate)
			end
			acc, frames = 0, 0
		end
	end)
end

return PerfOverlay
