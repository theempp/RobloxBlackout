-- Every tunable in the game lives here. ALL NUMBERS ARE PLACEHOLDERS until the owner's phone gun-feel test.
-- Units: studs, seconds, degrees. Product id 0 = hidden/disabled.
local Config = {}

Config.Build = "build2"

-- Places + teleport (§11). Place ids = publish target [OPEN owner]; 0 = unpublished -> "local" mode:
-- nothing teleports (Studio: open build/heist.rbxlx to play the heist directly).
Config.Places = { Lobby = 0, Heist = 0 }
Config.Teleport = { Retries = 1, RetryDelay = 2, PadResetAfter = 20 }

-- Crews (ported from roblox 1): cap 4; haul bonus +8% per extra member, capped at +24% (§4).
Config.Crew = { MaxSize = 4, InviteTtl = 30, BonusPerMember = 0.08, BonusCap = 0.24 }

-- Difficulty is passed at teleport (§11) but the brief never defines levels: one placeholder level.
Config.Difficulty = { normal = { ai = 1, alarm = 1, payout = 1 } }

-- Minimal lobby: queue pads beside the range spawn. Countdown seconds.
Config.Lobby = {
	Pads = { { id = "A", x = -40, z = 28 }, { id = "B", x = 40, z = 28 } },
	PadRadius = 7,
	PadHeight = 8,
	MaxSquad = 4,
	Countdown = 20, -- first join starts it
	JoinGrace = 8, -- a newcomer always gets this long
	ReadyCountdown = 3, -- everyone on the pad pressed READY
	FullCountdown = 5, -- squad full
	DefaultDifficulty = "normal",
	Tick = 0.25,
}

-- Heist server: session + loop. Systems run in this order each tick.
Config.Heist = {
	Tick = 0.1,
	ArrivalTimeout = 25, -- live: start without missing roster members after this
	LocalStartDelay = 3, -- Studio/unpublished: gather whoever joins within this
	ReturnDelay = 12, -- results screen, then back to the lobby (local: the run restarts)
	Systems = { "Map", "Twist", "Interact", "Crew", "Loot", "Gauntlet", "Security", "Enemies", "Karts", "Drones", "Escape" },
}

-- Profiles / persistence (ported from roblox 1 Profiles.luau)
Config.Profile = {
	StoreName = "BlackoutCrew_Profile_v1",
	Persistence = true, -- live DataStore outside Studio; Studio is always session-only
	SchemaVersion = 2, -- 2: heist { runs, lastObvious }
	LockSeconds = 180,
	AutosaveSeconds = 55,
	Retries = 3,
	RetryDelay = 2, -- seconds x attempt
	CloseTimeout = 25,
	ReceiptCap = 500,
	MaxCurrency = 1e8,
	MaxCounter = 1000, -- wheel spins/pity sanity cap
}

-- Branding: one swappable layer. Set DecalId when final art is approved; until then a text plate is used.
Config.Branding = { Name = "BLACKOUT CREW", Monogram = "DG", DecalId = "" }

-- Robux products (none in Build 1). Shape: { id = productId, credits = n }. id 0 = hidden.
Config.Products = {} :: { { id: number, credits: number } }

-- Whitelists for profile ids that later builds fill in.
Config.Karts = {} :: { { id: string } }
Config.Cosmetics = {} :: { { id: string } }

Config.Camera = {
	Mode = "FirstPerson", -- Build 1 decision (brief is silent; §6 budgets a first-person gun). Owner may veto.
	Fov = 70,
	EyeFromRoot = 1.9, -- camera height above HumanoidRootPart (R15 head centre + 0.4); root-based = no walk-anim bob
	PitchLimit = 80,
	TouchSens = 0.30, -- degrees per pixel of drag (x user sensitivity)
	MouseSens = 0.22, -- degrees per mouse delta pixel
	GamepadSens = 200, -- degrees/second at full stick
	GamepadDeadzone = 0.15,
	FovLerp = 18, -- per second
}

Config.AimAssist = {
	Enabled = true, -- default; player toggle in settings
	RadiusDeg = 4.5, -- cone around a target's centre where look speed is slowed
	SlowFactor = 0.55, -- look speed multiplier inside the cone (slow-down only, never pulls)
	MaxRange = 250,
	TouchAndGamepadOnly = true,
}

-- Movement + noise (§5h REC-AUTO): walk 16, sneak 8 (toggle); heavy loot ~40% slower (§5b).
-- Noise radius: sneak 6, walk 15 while moving, gunfire 60 for GunfireNoiseTime seconds.
Config.Movement = {
	WalkSpeed = 16,
	SneakSpeed = 8,
	HeavySpeedMult = 0.6,
	CrawlSpeed = 3, -- downed
	Noise = { Sneak = 6, Walk = 15, Gunfire = 60 },
	GunfireNoiseTime = 1.5,
	MovingSpeed = 1.5, -- horizontal studs/s above which a player counts as moving
}

Config.Fire = {
	OriginTolerance = 6, -- max studs between claimed shot origin and server-side head
	Bunch = 2, -- shots of rate allowance banked for network jitter (token bucket capacity)
	MinGap = 0.5, -- and never two shots closer than interval * MinGap
	Grace = 0.1, -- reload/draw completion slack for one-way latency
	DrawTime = 0.3, -- after equip before firing is allowed
	MaxSeqJump = 1000,
	MaxRange = 500, -- absolute cap regardless of gun
	FxRadius = 250, -- other players within this get tracer FX
}

Config.Recoil = {
	ResetAfter = 0.35, -- idle seconds before the pattern index resets
	MaxKickDeg = 3, -- sanity cap for any single kick
	VisualReturn = 14, -- viewmodel kick spring return speed
}

-- Per-player remote rate limits: { per second, burst }.
Config.RateLimits = {
	Fire = { 20, 30 },
	Reload = { 3, 5 },
	Aim = { 10, 14 },
	Equip = { 6, 8 },
	SaveSettings = { 1, 3 },
	ClientReady = { 1, 2 },
	RangeEquip = { 3, 5 },
	Queue = { 4, 6 },
	Action = { 10, 16 },
	Sneak = { 4, 6 },
	KartInput = { 20, 30 }, -- server-physics mode only
	Repair = { 6, 10 },
}

-- Tri budgets (§6 REC-AUTO, verify on low-end phone) and per-primitive estimates used to check them.
Config.TriBudget = { FirstPersonGun = 5000, WorldGun = 1500, Kart = 8000 }
Config.TriEstimate = { Block = 12, Wedge = 8, Cylinder = 96, Ball = 480 }

Config.Colors = {
	Body = Color3.fromRGB(28, 28, 32), -- matte black
	Foam = Color3.fromRGB(255, 120, 40), -- dart tips
	Hit = Color3.fromRGB(255, 255, 255),
	Predict = Color3.fromRGB(200, 200, 200),
	Head = Color3.fromRGB(255, 214, 64),
	Kill = Color3.fromRGB(255, 70, 70),
	Text = Color3.fromRGB(255, 255, 255),
	Panel = Color3.fromRGB(14, 16, 24),
	Accent = Color3.fromRGB(64, 220, 255),
	Muted = Color3.fromRGB(150, 158, 180),
	-- Squad slots (§5e REC-AUTO, Okabe-Ito, CVD-distinguishable; no red = alarm, no yellow = roll-up door).
	-- Same colour on tag, minimap dot, parking glow, kart underglow. Always shown with the name.
	Slots = { Color3.fromHex("56B4E9"), Color3.fromHex("E69F00"), Color3.fromHex("009E73"), Color3.fromHex("CC79A7") },
}

--[[ Guns. Fictional names, placeholder foam-tactical primitives.
 recoil: kick per shot i = (side[(i-1) % #side + 1], up * (1 + grow * min(i-1, 10))) degrees (x right, y up).
 Deterministic and learnable; the player counters by dragging down. recover = fraction of the spray's
 vertical climb returned after firing stops, over recoverTime.
 shape parts: { kind, size, pos, color = "Body"|"Accent"|"Foam" } in studs, muzzle along -Z. ]]
export type Gun = {
	id: string, name: string, class: string, price: number, auto: boolean,
	damage: number, headMult: number, rpm: number, mag: number, reload: number,
	range: number, falloffStart: number, minDamageMult: number, pellets: number,
	hipSpread: number, adsSpread: number, pelletSpread: number,
	adsFov: number, adsTime: number, adsSpeedMult: number,
	recoil: { up: number, grow: number, side: { number }, recover: number, recoverTime: number, visual: number },
	slots: { string }, accent: Color3, shape: { any }, muzzle: Vector3,
}

local function part(kind, sx, sy, sz, px, py, pz, color)
	return { kind = kind, size = Vector3.new(sx, sy, sz), pos = Vector3.new(px, py, pz), color = color or "Body" }
end

Config.Guns = {
	{
		id = "dart9", name = "Dart-9", class = "Sidearm", price = 0, auto = false,
		damage = 24, headMult = 1.6, rpm = 420, mag = 12, reload = 1.4,
		range = 160, falloffStart = 60, minDamageMult = 0.6, pellets = 1,
		hipSpread = 1.0, adsSpread = 0, pelletSpread = 0,
		adsFov = 58, adsTime = 0.12, adsSpeedMult = 0.85,
		recoil = { up = 0.9, grow = 0, side = { 0.10, -0.10 }, recover = 0.7, recoverTime = 0.2, visual = 1.0 },
		slots = { "optic", "barrel", "mag" }, accent = Color3.fromRGB(64, 220, 255),
		muzzle = Vector3.new(0, 0.1, -1.05),
		shape = {
			part("Block", 0.25, 0.35, 1.2, 0, 0.1, -0.4), part("Block", 0.22, 0.55, 0.3, 0, -0.25, -0.05),
			part("Cylinder", 0.16, 0.16, 0.3, 0, 0.1, -1.0, "Foam"), part("Block", 0.27, 0.06, 0.9, 0, 0.29, -0.4, "Accent"),
		},
	},
	{
		id = "buzz", name = "Buzzline", class = "SMG", price = 1000, auto = true,
		damage = 14, headMult = 1.5, rpm = 780, mag = 30, reload = 1.8,
		range = 120, falloffStart = 40, minDamageMult = 0.55, pellets = 1,
		hipSpread = 2.0, adsSpread = 0.2, pelletSpread = 0,
		adsFov = 62, adsTime = 0.14, adsSpeedMult = 0.8,
		recoil = { up = 0.35, grow = 0.04, side = { 0.05, 0.12, 0.18, 0.10, -0.08, -0.2, -0.22, -0.05, 0.14, 0.2 }, recover = 0.5, recoverTime = 0.3, visual = 0.6 },
		slots = { "optic", "barrel", "mag", "grip" }, accent = Color3.fromRGB(120, 255, 90),
		muzzle = Vector3.new(0, 0.12, -1.35),
		shape = {
			part("Block", 0.3, 0.4, 1.5, 0, 0.1, -0.55), part("Block", 0.2, 0.5, 0.25, 0, -0.25, -0.1),
			part("Block", 0.18, 0.7, 0.22, 0, -0.35, -0.55), part("Block", 0.24, 0.24, 0.6, 0, 0.05, 0.45),
			part("Cylinder", 0.16, 0.16, 0.3, 0, 0.12, -1.3, "Foam"), part("Block", 0.32, 0.06, 1.2, 0, 0.32, -0.55, "Accent"),
		},
	},
	{
		id = "ranger", name = "Ranger", class = "Rifle", price = 3000, auto = true,
		damage = 20, headMult = 1.6, rpm = 600, mag = 28, reload = 2.1,
		range = 250, falloffStart = 90, minDamageMult = 0.65, pellets = 1,
		hipSpread = 2.2, adsSpread = 0, pelletSpread = 0,
		adsFov = 50, adsTime = 0.18, adsSpeedMult = 0.75,
		recoil = { up = 0.5, grow = 0.05, side = { 0, 0.08, 0.15, 0.2, 0.1, -0.1, -0.2, -0.25, -0.1, 0.1 }, recover = 0.5, recoverTime = 0.35, visual = 0.8 },
		slots = { "optic", "barrel", "mag", "grip" }, accent = Color3.fromRGB(255, 80, 200),
		muzzle = Vector3.new(0, 0.12, -1.95),
		shape = {
			part("Block", 0.3, 0.42, 2.1, 0, 0.1, -0.8), part("Block", 0.2, 0.5, 0.25, 0, -0.25, -0.1),
			part("Block", 0.2, 0.6, 0.25, 0, -0.35, -0.75), part("Block", 0.26, 0.4, 0.8, 0, 0, 0.6),
			part("Cylinder", 0.16, 0.16, 0.35, 0, 0.12, -1.9, "Foam"), part("Block", 0.32, 0.06, 1.8, 0, 0.33, -0.8, "Accent"),
			part("Block", 0.14, 0.18, 0.3, 0, 0.4, -0.3),
		},
	},
	{
		id = "scatter", name = "Scatterpop", class = "Shotgun", price = 6000, auto = false,
		damage = 9, headMult = 1.3, rpm = 75, mag = 6, reload = 2.6,
		range = 70, falloffStart = 20, minDamageMult = 0.4, pellets = 8,
		hipSpread = 1.5, adsSpread = 0, pelletSpread = 4.5,
		adsFov = 60, adsTime = 0.16, adsSpeedMult = 0.8,
		recoil = { up = 2.2, grow = 0, side = { 0.3, -0.3 }, recover = 0.8, recoverTime = 0.35, visual = 2.0 },
		slots = { "optic", "barrel", "grip" }, accent = Color3.fromRGB(255, 200, 40),
		muzzle = Vector3.new(0, 0.12, -1.75),
		shape = {
			part("Block", 0.36, 0.45, 1.9, 0, 0.1, -0.7), part("Block", 0.22, 0.5, 0.25, 0, -0.25, -0.1),
			part("Block", 0.3, 0.26, 0.6, 0, -0.12, -1.0, "Accent"), part("Block", 0.28, 0.42, 0.8, 0, 0, 0.6),
			part("Cylinder", 0.3, 0.3, 0.3, 0, 0.12, -1.7, "Foam"),
		},
	},
	{
		id = "needle", name = "Needlepoint", class = "Marksman", price = 10000, auto = false,
		damage = 48, headMult = 2.0, rpm = 220, mag = 10, reload = 2.4,
		range = 400, falloffStart = 200, minDamageMult = 0.75, pellets = 1,
		hipSpread = 3.0, adsSpread = 0, pelletSpread = 0,
		adsFov = 32, adsTime = 0.24, adsSpeedMult = 0.65,
		recoil = { up = 1.8, grow = 0, side = { 0.15, -0.05, 0.1 }, recover = 0.85, recoverTime = 0.3, visual = 1.6 },
		slots = { "optic", "barrel", "mag", "grip" }, accent = Color3.fromRGB(160, 110, 255),
		muzzle = Vector3.new(0, 0.12, -2.45),
		shape = {
			part("Block", 0.28, 0.4, 2.6, 0, 0.1, -1.05), part("Block", 0.2, 0.5, 0.25, 0, -0.25, -0.1),
			part("Block", 0.18, 0.55, 0.22, 0, -0.3, -0.6), part("Block", 0.26, 0.42, 0.9, 0, 0, 0.65),
			part("Cylinder", 0.22, 0.22, 0.7, 0, 0.45, -0.5), part("Cylinder", 0.14, 0.14, 0.3, 0, 0.12, -2.4, "Foam"),
			part("Block", 0.3, 0.06, 2.2, 0, 0.31, -1.05, "Accent"),
		},
	},
	{
		id = "rattler", name = "Rattler", class = "Heavy", price = 15000, auto = true,
		damage = 17, headMult = 1.4, rpm = 660, mag = 80, reload = 4.2,
		range = 220, falloffStart = 80, minDamageMult = 0.6, pellets = 1,
		hipSpread = 2.8, adsSpread = 0.35, pelletSpread = 0,
		adsFov = 52, adsTime = 0.28, adsSpeedMult = 0.55,
		recoil = { up = 0.42, grow = 0.03, side = { 0.12, 0.2, 0.1, -0.05, -0.18, -0.2, -0.08, 0.1 }, recover = 0.4, recoverTime = 0.45, visual = 0.9 },
		slots = { "optic", "barrel", "mag", "grip" }, accent = Color3.fromRGB(255, 70, 70),
		muzzle = Vector3.new(0, 0.12, -2.15),
		shape = {
			part("Block", 0.42, 0.55, 2.3, 0, 0.1, -0.85), part("Block", 0.22, 0.5, 0.25, 0, -0.3, -0.1),
			part("Cylinder", 0.6, 0.6, 0.35, 0, -0.35, -0.6, "Accent"), part("Block", 0.3, 0.45, 0.9, 0, 0, 0.65),
			part("Block", 0.2, 0.55, 0.22, 0, -0.35, -1.3), part("Cylinder", 0.18, 0.18, 0.35, 0, 0.12, -2.1, "Foam"),
			part("Block", 0.44, 0.06, 1.8, 0, 0.4, -0.85, "Accent"),
		},
	},
} :: { Gun }

-- Attachments are sidegrades: every one has at least one buff and one cost. mods multiply gun stats;
-- recoilUp / recoilSide scale the recoil pattern.
Config.AttachmentSlots = { "optic", "barrel", "mag", "grip" }
Config.Attachments = {
	{ id = "red_dot", name = "Red Dot", slot = "optic", mods = { adsTime = 0.85, adsFov = 1.08 } },
	{ id = "scope2x", name = "2x Scope", slot = "optic", mods = { adsFov = 0.75, adsTime = 1.25, adsSpeedMult = 0.95 } },
	{ id = "long_barrel", name = "Long Barrel", slot = "barrel", mods = { range = 1.2, falloffStart = 1.2, adsTime = 1.1 } },
	{ id = "compensator", name = "Compensator", slot = "barrel", mods = { recoilUp = 0.85, hipSpread = 1.15 } },
	{ id = "ext_mag", name = "Extended Mag", slot = "mag", mods = { mag = 1.4, reload = 1.2 } },
	{ id = "quick_mag", name = "Quick Mag", slot = "mag", mods = { reload = 0.8, mag = 0.85 } },
	{ id = "vert_grip", name = "Vertical Grip", slot = "grip", mods = { recoilUp = 0.88, adsSpeedMult = 0.95 } },
	{ id = "angled_grip", name = "Angled Grip", slot = "grip", mods = { adsTime = 0.85, recoilSide = 1.2 } },
}

-- Weapon wheel: 5 slots, 2 left / 2 right / 1 top (no bottom slot: the thumb covers it).
-- Angles in screen degrees (0 = right, -90 = up). Slots 4-5 are faded "Coming Soon".
Config.Wheel = {
	Slots = {
		{ index = 1, angle = -150, usable = true },
		{ index = 2, angle = -90, usable = true },
		{ index = 3, angle = -30, usable = true },
		{ index = 4, angle = 150, usable = false, teaser = "Unlocks Season 1 Week 3" },
		{ index = 5, angle = 30, usable = false, teaser = "Unlocks Season 1 Week 3" },
	},
	HoldTime = 0.25, -- tap shorter than this = swap to last-used; longer = radial
	DeadzonePx = 22, -- drag distance before a slot is picked
	MaxSectorDeg = 45, -- beyond this from every slot = no pick (e.g. straight down)
	Radius = 100, -- design units
}

-- HUD: design units 800x340 scaled by S = clamp(min(vp.X*.55, vp.Y)/340, MinScale, MaxScale) (ported).
Config.Hud = {
	DesignHeight = 340,
	WidthFactor = 0.55,
	MinScale = 0.85,
	MaxScale = 1.6,
	LargeMult = 1.15,
	MinTouchPx = 44, -- physical pixels after all scaling
}

-- Touch buttons: centre as fraction of the HUD root (safe-inset area), size in design units.
-- Players can move/resize each (settings.layout); user scale is clamped to UserScale.
Config.Touch = {
	UserScale = { 0.6, 1.6 },
	FireDragAims = true, -- dragging from the Fire button also aims
	ForceShow = false, -- show touch buttons without a touchscreen (tests force this on)
	Buttons = {
		fire = { x = 0.885, y = 0.72, size = 86, label = "FIRE" },
		ads = { x = 0.765, y = 0.585, size = 60, label = "ADS" },
		reload = { x = 0.765, y = 0.87, size = 50, label = "R" },
		jump = { x = 0.935, y = 0.43, size = 56, label = "JUMP" },
		weapon = { x = 0.65, y = 0.86, size = 58, label = "GUN" },
		-- Mirrored, off by default. Right of the heist minimap (§5e puts the map top-left) so the claw-grip
		-- index finger still reaches it without covering the map.
		fireLeft = { x = 0.34, y = 0.4, size = 64, label = "FIRE", optional = true },
		-- Heist only. action = context HOLD button (§5f), shown only when something is in reach.
		action = { x = 0.64, y = 0.62, size = 72, label = "", heist = true, context = true },
		sneak = { x = 0.935, y = 0.25, size = 50, label = "SNEAK", heist = true },
		-- Kart (shown only while driving; left thumb = Roblox stick steers + throttles).
		gas = { x = 0.885, y = 0.72, size = 86, label = "GAS", heist = true, driving = true },
		brake = { x = 0.75, y = 0.8, size = 62, label = "BRAKE", heist = true, driving = true },
		exit = { x = 0.935, y = 0.25, size = 50, label = "EXIT", heist = true, driving = true },
	},
}

Config.Keys = {
	Fire = Enum.UserInputType.MouseButton1,
	Ads = Enum.UserInputType.MouseButton2,
	Reload = Enum.KeyCode.R,
	SwapLast = Enum.KeyCode.Q,
	Wheel = Enum.KeyCode.Tab,
	Slots = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three },
	PerfOverlay = Enum.KeyCode.F7,
	Settings = Enum.KeyCode.P,
	PadFire = Enum.KeyCode.ButtonR2,
	PadAds = Enum.KeyCode.ButtonL2,
	PadReload = Enum.KeyCode.ButtonX,
	PadSwap = Enum.KeyCode.ButtonY,
	Action = Enum.KeyCode.E,
	Sneak = Enum.KeyCode.C,
	PadAction = Enum.KeyCode.ButtonB,
	PadSneak = Enum.KeyCode.ButtonL3,
	PadGas = Enum.KeyCode.ButtonR2,
	PadBrake = Enum.KeyCode.ButtonL2,
	KartBrake = Enum.KeyCode.LeftShift,
}

-- Context actions (§5f [CONFIRM] interpretation): hold seconds + reach (studs). A target's own
-- Hold / Range attributes override (heavy loot 1.0 s; cameras are mounted high). Revive 3 s (§5c).
Config.Actions = {
	override = { hold = 2, label = "OVERRIDE" },
	revive = { hold = 3, range = 7, label = "REVIVE" },
	repair = { hold = 0, range = 9, label = "REPAIR" }, -- opens the timing-wheel minigame (§5d)
	load = { hold = 1, range = 10, label = "LOAD" },
	hack = { hold = 2.5, range = 7, label = "HACK" },
	pickup = { hold = 0.4, range = 7, label = "GRAB" },
	handoff = { hold = 0.8, range = 7, label = "GIVE" },
	drive = { hold = 0.2, range = 9, label = "DRIVE" },
	drop = { hold = 0.3, label = "DROP" },
}

-- Loot (§5b, §5d, §5g placeholders): avg clean run ~1,000 Credits per player incl. bonuses.
Config.Loot = {
	HeavyValue = 600,
	SmallValue = 30,
	HeavyHold = 1.0,
	CarryOffset = CFrame.new(0, 0.4, 1.7), -- behind the back, relative to the root
}

-- Alarm (§5b): 3 tiers of PerTier points. Bumps: gunfire big, camera small, downed medium; slow creep.
-- Tiers drop only via the terminal hack. Sighting = a sentry/watcher spotting someone (same as camera).
Config.Alarm = {
	PerTier = 100,
	Tiers = { "QUIET", "LOCKDOWN", "PURGE" },
	Bumps = { gunfire = 30, camera = 10, sighting = 10, downed = 20, laser = 8 },
	Creep = 0.25, -- points per second (~6.7 min from empty to Lockdown on creep alone)
	HackCooldown = 45,
	SightingCooldown = 8, -- per enemy per player
}

-- Enemies (§5b, §5h REC-AUTO). Cap = moving AI (sentries + watchers + repo drones; cameras are fixtures).
-- Counts per alarm tier for a full crew; CrewScale x0.5 solo / x0.75 duo applies to tower AI.
Config.Enemies = {
	Cap = 8,
	Counts = {
		{ sentries = 2, watchers = 0, repo = 2 }, -- Quiet
		{ sentries = 3, watchers = 1, repo = 3 }, -- Lockdown
		{ sentries = 3, watchers = 1, repo = 4 }, -- Purge (+ faster lasers)
	},
	CrewScale = { 0.5, 0.75, 1, 1 },
	Sentry = { Health = 150, Speed = 7, TurnRate = 160, Cone = 70, Range = 35, Hover = 2.8, Damage = 10, FireInterval = 0.8,
		AttackRange = 45, SpotTime = 0.6, LoseTime = 3, InvestigateTime = 4 },
	Watcher = { Health = 80, Speed = 10, TurnRate = 220, Cone = 90, Range = 40, Pitch = -35, Damage = 6, FireInterval = 0.5,
		AttackRange = 40, SpotTime = 0.5, LoseTime = 3, InvestigateTime = 3 },
	Camera = { Health = 40, Cone = 50, Range = 45, Period = 8, Pitch = -25, SpotTime = 0.8, Cooldown = 6, CallRadius = 60, HackRange = 16 },
}

-- Downed (§5c): bleed-out 25 s, revive 3 s hold (Config.Actions), 1 Override per player per run,
-- bleed-out -> recalled: respawn at the tower entrance after 30 s, carried loot dropped.
-- Run fails only if the whole crew is down at once (and nobody can Override).
Config.Downed = { MaxHP = 100, BleedOut = 25, ReviveHP = 50, Overrides = 1, Recall = 30, RegenDelay = 6, RegenRate = 8 }

-- Twists (§5c): one per run. Numbers ending in Mult multiply the run's params. Force = an id for playtests.
Config.Twists = {
	Enabled = { "blackout", "doublePatrol" }, -- 3C adds laserStorm, shortFuse, glitchSurge, loudFloor
	Force = nil,
	blackout = {
		name = "BLACKOUT",
		visionMult = 0.6, -- lights out: bots see less far; the crew sees less too
		lighting = { Brightness = 0.15, ClockTime = 0, Ambient = Color3.fromRGB(14, 14, 24), OutdoorAmbient = Color3.fromRGB(20, 20, 34), FogEnd = 420 },
	},
	doublePatrol = { name = "DOUBLE PATROL", sentryMult = 2 },
}

-- One-seat kart (§3b, §7), physics ported from roblox 1 Vehicles.luau. The driver's client steps the
-- physics (responsive on phones); ServerPhysics = true restores v0.3's server-owned model for an A/B
-- phone test. Size/proportions follow the razor blockout (~11 x 5 x 3.4 studs).
Config.Kart = {
	ServerPhysics = false,
	MaxSpeed = 60, Accel = 42, Reverse = 20, Brake = 95, Drag = 0.13,
	Steer = 32, SteerFalloff = 48, Grip = 12,
	Track = 4.4, Wheelbase = 7.2, MountY = 0.3, Rest = 1.85, Spring = 300, Damp = 22, RayLen = 2.4,
	FlipTime = 1.5,
	EmpTime = 1.2, EmpSpin = 7, EmpSpeedMult = 0.35, EmpAccelMult = 0.3, EmpGripMult = 0.25, -- EMP: tyres lose grip = spin-out
	InputRate = 15, InputTimeout = 0.5, -- server-physics mode only
	SpeedTolerance = 1.35, Strikes = 2, -- anti-cheat on driver-owned karts: rubber-band on repeat overspeed
	IdleAnchor = 2, -- an empty kart at rest anchors after this many seconds (cheap physics)
	Camera = { Back = 15, Up = 6.5, Ahead = 10, Lerp = 8, Fov = 75 },
}

-- Parking (§5d): park = leave the kart within Radius of your spot. Teammates' spots show within GlowRange.
Config.Parking = { Radius = 7, GlowRange = 60 }

-- Repo + pursuit drones (§3b, §5d). Repo: loops ~LoopTime s over stash zones; a kart seen continuously
-- fills its sabotage ring in SabotageTime[tier] s, draining at DrainMult speed out of sight.
-- Pursuit: chase karts on a dash and EMP them (spin + slow, no kills), from the AI budget left over.
Config.Drones = {
	Repo = { LoopTime = 22, Cone = 80, Range = 70, Pitch = -55, SabotageTime = { 4, 3, 2.5 }, DrainMult = 0.5, Health = 60, TurnRate = 180 },
	Pursuit = { PerTier = { 1, 2, 3 }, Speed = 52, Height = 12, EmpRange = 14, Cooldown = 6, Health = 60, TurnRate = 240 },
}

-- Escape (§5d): per-player gate timer from driving away (after the breach); run cap = safety net.
Config.Escape = { DashTime = 75, RunCap = 720, MinDashMult = 1.3, StepRate = 0.5 }

-- Repair minigame (§5d): 3 steps; needle period per revolution (owner self-repair is slower).
Config.Repair = { Steps = 3, Period = 2.9, SelfPeriod = 4.8, ZoneMin = 0.45, ZoneMax = 0.8, ZoneWidth = 0.14,
	Slack = 0.03, Latency = 0.6, MissPenalty = 0.5 }

-- Payout (§5d): heavy loot multiplier by outcome; small loot always 100%.
Config.Payout = { HeavyMult = { clean = 1.15, rough = 0.9, timeout = 0.5, caught = 0.5 } }

-- Laser gauntlet: touch = alarm bump + damage; hack = off for HackOff seconds, then re-arms.
Config.Lasers = {
	Radius = 0.9,
	Samples = { -2.2, 0, 1.8 }, -- feet / torso / head offsets from the root
	Damage = 20,
	Cooldown = 1.5, -- per player after a touch
	HackOff = 25,
	SpeedByTier = { 1, 1.35, 1.7 }, -- §5b: tiers add laser speed
}

Config.Settings = { -- defaults; Rules.cleanSettings enforces types and ranges
	Bools = { aimAssist = true, perfOverlay = false, mirrorFire = false, reducedMotion = false, largeHud = false, sfx = true },
	Numbers = { sensitivity = { 1, 0.2, 3 }, adsSensitivity = { 1, 0.2, 3 } }, -- default, min, max
}

Config.Perf = {
	ProbeSkip = 5, -- frame probe (ported): skip, then sample
	ProbeSample = 15,
	OverlayRate = 0.5, -- overlay refresh seconds
	TracerPool = 24,
	ImpactPool = 24,
	MarkerPool = 16,
	TracerTime = 0.06,
	TargetFps = { LowEnd = 30, Mid = 60 },
}

Config.Range = {
	LoanAllGuns = true, -- test range lets anyone try every gun without owning it (no profile write)
	DefaultLoan = { [2] = "buzz", [3] = "ranger" }, -- range only: fills wheel slots 2-3 so the wheel is testable at once
	RespawnTime = 3,
	DummyHealth = 150,
	SentryHealth = 250,
	StaticDistances = { 10, 25, 50, 100 },
	StrafeSpeed = 8,
	StrafeWidth = 14,
	SentryTurnRate = 90, -- degrees/second
	SentryRange = 90,
}

Config.Log = { Level = "info" } -- debug | info | warn

-- Lookup tables (built once).
Config.GunsById = {} :: { [string]: Gun }
for _, g in ipairs(Config.Guns) do
	Config.GunsById[g.id] = g
end
Config.AttachmentsById = {}
for _, a in ipairs(Config.Attachments) do
	Config.AttachmentsById[a.id] = a
end

return Config
