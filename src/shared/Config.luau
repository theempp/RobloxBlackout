-- Every tunable in the game lives here. ALL NUMBERS ARE PLACEHOLDERS until the owner's phone gun-feel test.
-- Units: studs, seconds, degrees. Product id 0 = hidden/disabled.
local Config = {}

Config.Build = "build1"

-- Profiles / persistence (ported from roblox 1 Profiles.luau)
Config.Profile = {
	StoreName = "BlackoutCrew_Profile_v1",
	Persistence = true, -- live DataStore outside Studio; Studio is always session-only
	SchemaVersion = 1,
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
	EyeHeight = 0.4, -- camera offset above the Head centre
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

Config.Movement = { WalkSpeed = 16 }

Config.Fire = {
	OriginTolerance = 6, -- max studs between claimed shot origin and server-side head
	Bunch = 2, -- shots of rate allowance banked for network jitter (token bucket capacity)
	DrawTime = 0.3, -- after equip before firing is allowed
	MaxSeqJump = 1000,
	MaxRange = 500, -- absolute cap regardless of gun
	FxRadius = 250, -- other players within this get tracer FX
	SpreadSeedPrime = 100003,
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
}

-- Tri budgets (§6 REC-AUTO, verify on low-end phone) and per-primitive estimates used to check them.
Config.TriBudget = { FirstPersonGun = 5000, WorldGun = 1500, Kart = 8000 }
Config.TriEstimate = { Block = 12, Wedge = 8, Cylinder = 96, Ball = 480 }

Config.Colors = {
	Body = Color3.fromRGB(28, 28, 32), -- matte black
	Foam = Color3.fromRGB(255, 120, 40), -- dart tips
	Hit = Color3.fromRGB(255, 255, 255),
	Head = Color3.fromRGB(255, 214, 64),
	Kill = Color3.fromRGB(255, 70, 70),
	Text = Color3.fromRGB(255, 255, 255),
	Panel = Color3.fromRGB(14, 16, 24),
	Accent = Color3.fromRGB(64, 220, 255),
	Muted = Color3.fromRGB(150, 158, 180),
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
	Buttons = {
		fire = { x = 0.885, y = 0.72, size = 86, label = "FIRE" },
		ads = { x = 0.765, y = 0.585, size = 60, label = "ADS" },
		reload = { x = 0.765, y = 0.87, size = 50, label = "R" },
		jump = { x = 0.935, y = 0.43, size = 56, label = "JUMP" },
		weapon = { x = 0.65, y = 0.86, size = 58, label = "GUN" },
		fireLeft = { x = 0.07, y = 0.42, size = 64, label = "FIRE", optional = true }, -- mirrored, off by default
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
