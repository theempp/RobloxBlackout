-- Every tunable in the game lives here. ALL NUMBERS ARE PLACEHOLDERS until the owner's phone gun-feel test.
-- Units: studs, seconds, degrees. Product id 0 = hidden/disabled.
local Config = {}

Config.Build = "build3-phone-candidate"

-- Places + teleport (§11). Place ids = publish target [OPEN owner]; 0 = unpublished -> "local" mode:
-- nothing teleports (Studio: open build/heist.rbxlx to play the heist directly).
Config.Places = { Lobby = 102861732553937, Heist = 125919969708119 }
Config.Teleport = { Retries = 1, RetryDelay = 2, PadResetAfter = 20 }

-- Crews (ported from roblox 1): cap 4; haul bonus +8% per extra member, capped at +24% (§4).
Config.Crew = { MaxSize = 4, InviteTtl = 30, BonusPerMember = 0.08, BonusCap = 0.24 }

-- Difficulty is passed at teleport (§11) but the brief never defines levels: one placeholder level.
Config.Difficulty = { normal = { ai = 1, alarm = 1, payout = 1 } }

-- Build 3A: all garage positions are local to Origin (keeps the test range available in test builds).
Config.Garage = {
	Origin = Vector3.new(400, 0, 0), Spawn = Vector3.new(0, 0, 28), Door = Vector3.new(0, 10, -40),
	GunWall = Vector3.new(-110, 4, -10), Bench = Vector3.new(-86, 1.5, 4), Terminal = Vector3.new(-73, 2, 17),
	Friend = Vector3.new(-51, 0, 9), KartBay = Vector3.new(-35, 0, 16), KartGap = 9,
	TrackWidth = 20, InteractionRange = 12, ResetBelow = -15, CutsceneSeconds = 2.5,
	TrackNodes = {
		Vector3.new(-130, 0, 100), Vector3.new(-130, 0, -100), Vector3.new(0, 0, -100),
		Vector3.new(130, 18, -100), Vector3.new(130, 18, 70), Vector3.new(-35, 18, 70),
		Vector3.new(-35, 10, -65), Vector3.new(100, 10, -65), Vector3.new(100, 0, 100),
	},
	TutorialTargetSeconds = 90,
	-- Locker room (revision stage 1): open room east of the main hall. Locker = the station locker's front
	-- (prompt + range); LockerView = where the short entry camera ends, looking at it.
	Locker = Vector3.new(83.5, 0, 18), LockerView = Vector3.new(77, 5.2, 18), LockerIntroSeconds = 1.2,
	AckTimeout = 3, -- client waits this long for a station request's ack, then shows the saved setup again
}

Config.Lobby = {
	-- Raised, adjacent pads flanking the departure lane in front of the roll-up door (revision stage 1).
	-- label/mode are board text only: every pad keeps the same squad rules (MaxSquad, default difficulty).
	Pads = { { id = "A", x = 387, z = -24, label = "TOWER HEIST", mode = "NORMAL" }, { id = "B", x = 413, z = -24, label = "TOWER HEIST", mode = "NORMAL" } },
	PadSize = Vector3.new(20, 0.6, 14), -- platform; wedge ramps on the front and outer side
	PadMargin = 1, -- occupancy box = platform footprint + this
	PadHeight = 8, -- occupancy reaches this far above the platform
	-- Flat matte status colours (no neon): standing circles show empty / taken / ready.
	Colors = { Platform = Color3.fromRGB(46, 44, 48), Empty = Color3.fromRGB(205, 203, 196), Taken = Color3.fromRGB(255, 190, 97),
		Ready = Color3.fromRGB(146, 221, 128), Board = Color3.fromRGB(45, 34, 28) },
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
	SchemaVersion = 6, -- 6: replace retired guns; Rules.clean drops stale IDs and supplies the new free P1
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
Config.Karts = { { id = "base" }, { id = "vortex" } }

-- Cosmetics (locker room, revision stage 1). Placeholder matte primitives (no assets, no neon) welded to the
-- character. Disguises are COSMETIC ONLY: nothing reads them for stealth. free = starter item everyone
-- owns; the rest stay locked until the 3B shop (no prices here: the economy is deferred).
-- Outfits recolour torso/arms/legs and hide avatar clothing. Piece size/pos are fractions of the body
-- part's size (pos = centre offset, -Z = facing; rot = degrees), so pieces follow avatar scale.
Config.CosmeticSlots = { "outfit", "disguise", "mask" }
local function piece(at, kind, size, pos, color, rot)
	return { at = at, kind = kind, size = size, pos = pos, color = color, rot = rot }
end
local V3, RGB = Vector3.new, Color3.fromRGB
local function cap(color)
	return piece("Head", "Cylinder", V3(0.4, 1.08, 1.08), V3(0, 0.46, 0.02), color, V3(0, 0, 90))
end
local function vest(color)
	return piece("Torso", "Block", V3(1.04, 0.86, 1.12), V3(0, -0.02, 0), color)
end
Config.Cosmetics = {
	{ id = "fit_crew", slot = "outfit", name = "Crew Coveralls", free = true, about = "Charcoal coveralls and gloves.",
		colors = { torso = RGB(40, 41, 46), arms = RGB(40, 41, 46), legs = RGB(30, 31, 35) } },
	{ id = "fit_night", slot = "outfit", name = "Night Shift", free = true, about = "Navy work jacket, black trousers.",
		colors = { torso = RGB(36, 46, 70), arms = RGB(36, 46, 70), legs = RGB(24, 25, 29) } },
	{ id = "fit_track", slot = "outfit", name = "Track Suit", about = "Teal track suit.",
		colors = { torso = RGB(31, 94, 101), arms = RGB(31, 94, 101), legs = RGB(28, 28, 32) } },
	{ id = "fit_gala", slot = "outfit", name = "Gala Black", about = "All-black formal fit.",
		colors = { torso = RGB(20, 20, 22), arms = RGB(20, 20, 22), legs = RGB(20, 20, 22) } },
	{ id = "dis_courier", slot = "disguise", name = "Courier", free = true, about = "Flat cap and delivery satchel.", parts = {
		cap(RGB(92, 64, 44)), piece("Head", "Block", V3(0.92, 0.06, 0.5), V3(0, 0.3, -0.62), RGB(80, 55, 38)),
		piece("Torso", "Block", V3(0.16, 1.2, 1.1), V3(0, 0, 0), RGB(70, 52, 38), V3(0, 0, 35)),
		piece("Torso", "Block", V3(0.32, 0.36, 0.62), V3(0.62, -0.62, 0), RGB(70, 52, 38)) } },
	{ id = "dis_maint", slot = "disguise", name = "Maintenance", about = "Hard hat and work vest.", parts = {
		piece("Head", "Cylinder", V3(0.36, 1.1, 1.1), V3(0, 0.5, 0), RGB(226, 224, 216), V3(0, 0, 90)),
		piece("Head", "Block", V3(1.22, 0.05, 1.22), V3(0, 0.33, 0), RGB(226, 224, 216)),
		vest(RGB(214, 120, 52)), piece("Torso", "Block", V3(1.06, 0.1, 1.14), V3(0, -0.16, 0), RGB(120, 120, 124)) } },
	{ id = "dis_guard", slot = "disguise", name = "Night Guard", about = "Peaked cap and guard vest.", parts = {
		cap(RGB(30, 36, 56)), piece("Head", "Block", V3(0.92, 0.06, 0.5), V3(0, 0.3, -0.62), RGB(20, 22, 30)),
		vest(RGB(34, 40, 60)), piece("Torso", "Block", V3(0.18, 0.2, 0.05), V3(0.26, 0.2, -0.58), RGB(150, 150, 155)) } },
	{ id = "dis_valet", slot = "disguise", name = "Valet", about = "Waistcoat and bow tie.", parts = {
		vest(RGB(110, 34, 40)), piece("Torso", "Block", V3(0.3, 0.1, 0.06), V3(0, 0.44, -0.58), RGB(18, 18, 20)) } },
	{ id = "mask_bandana", slot = "mask", name = "Bandana", free = true, about = "Dark face wrap.", parts = {
		piece("Head", "Block", V3(1.05, 0.44, 1.05), V3(0, -0.24, 0), RGB(52, 54, 60)),
		piece("Head", "Block", V3(0.24, 0.18, 0.16), V3(0, -0.08, 0.58), RGB(52, 54, 60)) } },
	{ id = "mask_visor", slot = "mask", name = "Foam Visor", free = true, about = "Padded band with a smoked lens.", parts = {
		piece("Head", "Block", V3(1.04, 0.15, 1.04), V3(0, 0.12, 0), RGB(36, 36, 40)),
		piece("Head", "Block", V3(0.8, 0.26, 0.1), V3(0, 0.12, -0.53), RGB(64, 72, 82)) } },
	{ id = "mask_robot", slot = "mask", name = "Robo Faceplate", about = "Riveted faceplate.", parts = {
		piece("Head", "Block", V3(0.9, 0.86, 0.12), V3(0, -0.02, -0.55), RGB(178, 180, 186)),
		piece("Head", "Block", V3(0.62, 0.08, 0.06), V3(0, 0.14, -0.62), RGB(30, 30, 34)) } },
	{ id = "mask_domino", slot = "mask", name = "Domino", about = "Classic eye mask.", parts = {
		piece("Head", "Block", V3(0.86, 0.2, 0.08), V3(0, 0.14, -0.54), RGB(22, 22, 24)) } },
}

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
	BoltSlack = 0.05, -- bunch-1 (bolt) guns: seconds of network jitter forgiven per shot (sustained rate still capped)
	FxRadius = 250, -- other players within this get tracer FX
}

Config.Recoil = {
	ResetAfter = 0.35, -- idle seconds before the pattern index resets
	MaxKickDeg = 3, -- sanity cap for any single kick
	VisualReturn = 14, -- viewmodel kick spring return speed
}

-- First-person feel defaults (per-gun overrides in Config.Guns[i].fp). Distances in studs, angles in degrees.
Config.ViewModel = {
	Hip = Vector3.new(0.72, -0.72, -1.45), -- legacy guns without fp.hip
	Eye = 0.6, -- legacy guns: eye relief behind the sight in ADS
	Kick = { back = 0.06, rise = 2, roll = 1, spring = 300, damp = 26 },
	Draw = { drop = 0.45, tilt = 35 }, -- equip: rises from below over Config.Fire.DrawTime
	Reload = { tilt = 22, roll = 18, dip = 0.12, magDrop = 0.35 },
	Bob = { amp = 0.035, rate = 1.6, adsMult = 0.15 }, -- walk bob (reduced motion = off)
	Sway = { look = 2, ads = 0.2 },
	ScopeShowAt = 0.85, -- ADS progress at which a scope gun swaps to the full-view reticle
}

-- Full-viewport scope (Needlepoint): reticle across the whole play view, light edge shading only (no black ring).
Config.Scope = {
	LineColor = Color3.fromRGB(12, 12, 14), LineThickness = 2, CenterGap = 18, ThickFrom = 0.22, -- thick outer posts from 22% of half-width
	EdgeShade = 0.55, -- transparency of the corner shading (1 = none)
	Dot = 4,
}

-- Hit feedback. ELIMINATED appears once per server-confirmed defeat, below-right of the reticle (never over it).
Config.HitFx = {
	ElimText = "ELIMINATED", ElimTime = 1.1, ElimColor = Color3.fromRGB(255, 70, 70),
	ElimOffset = Vector2.new(46, 52), -- design px from screen centre to the tag's top-left corner
	DamageOffset = Vector2.new(0.9, 0.9), -- BillboardGui SizeOffset: numbers float up-right of the hit, off the reticle
	SeenCap = 64, -- remembered defeat ids (dedupe)
}

-- Gun sound. PLACEHOLDERS: the only offline sounds are Roblox's built-in client content (rbxasset://sounds). Real
-- per-gun audio needs owner-approved uploads; set ids here and nothing else changes. volume 0-1, speed = PlaybackSpeed.
Config.Sfx = {
	Placeholder = true,
	PoolPerGun = 4, -- overlapping shots (auto fire) without allocating
	OtherShots = 6, -- 3D pool for teammates' shots
	OtherMaxDistance = 140,
	Shot = {
		P1 = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.55, speed = 1.7 },
		A2 = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.45, speed = 2.3 },
		A1 = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.22, speed = 2.6 },
		S1 = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.35, speed = 1.5 },
		default = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.5, speed = 1.9 },
	},
	Bolt = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.4, speed = 1.6 },
	Reload = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.35, speed = 1.2 },
	Dry = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.5, speed = 0.8 },
}

-- Per-player remote rate limits: { per second, burst }.
Config.RateLimits = {
	SocialAction = { 2, 4 },
	EconomyAction = { 2, 4 },
	GarageAction = { 5, 10 },
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
	KartAction = { 4, 6 }, -- driver controls for doors and white LEDs
	Repair = { 6, 10 },
	RepairSkip = { 1, 2 },
}

-- Tri budgets (§6 REC-AUTO, verify on low-end phone) and per-primitive estimates used to check them.
Config.TriBudget = { FirstPersonGun = 5000, WorldGun = 1500, Kart = 8000 }
Config.TriEstimate = { Block = 12, Wedge = 8, Cylinder = 96, Ball = 480 }

-- Owner-approved UI direction (Sept 30): warm paper, dark outlines, bright flat pills.
Config.UI = {
	Paper = Color3.fromRGB(255, 248, 232), Ink = Color3.fromRGB(35, 31, 39),
	Muted = Color3.fromRGB(93, 83, 100), Blue = Color3.fromRGB(112, 207, 242),
	Green = Color3.fromRGB(146, 221, 128), Orange = Color3.fromRGB(255, 190, 97),
	Pink = Color3.fromRGB(243, 154, 181), Outline = 3,
}

Config.Colors = {
	Body = Color3.fromRGB(28, 28, 32), -- matte black
	Foam = Color3.fromRGB(255, 120, 40), -- dart tips
	Hit = Color3.fromRGB(255, 255, 255),
	Predict = Color3.fromRGB(200, 200, 200),
	Head = Color3.fromRGB(255, 214, 64),
	Kill = Color3.fromRGB(255, 70, 70),
	Puff = Color3.fromRGB(236, 230, 220), -- muzzle air puff (foam blaster; matte, not a glow)
	Text = Color3.fromRGB(255, 255, 255),
	Panel = Color3.fromRGB(14, 16, 24),
	Accent = Color3.fromRGB(64, 220, 255),
	Muted = Color3.fromRGB(150, 158, 180),
	-- Squad slots (§5e REC-AUTO, Okabe-Ito, CVD-distinguishable; no red = alarm, no yellow = roll-up door).
	-- Same colour on tag, minimap dot, parking glow, kart number plate (flat colour; no neon, owner Sept 30). Always shown with the name.
	Slots = { Color3.fromHex("56B4E9"), Color3.fromHex("E69F00"), Color3.fromHex("009E73"), Color3.fromHex("CC79A7") },
}

-- Eight independent Blender guns. IDs match exports; balance remains provisional for the phone gate.
-- Geometry/points are generated. Runtime uses uploaded meshes; false selects procedural piece boxes.
Config.GunMeshes = { UseUploaded = true, NearBlackMax = 0.1, MinPartSize = 0.001 }
export type Gun = {
	id: string, name: string, class: string, price: number, auto: boolean,
	damage: number, headMult: number, rpm: number, mag: number, reload: number,
	range: number, falloffStart: number, minDamageMult: number, pellets: number,
	hipSpread: number, adsSpread: number, pelletSpread: number,
	adsFov: number, adsTime: number, adsSpeedMult: number,
	recoil: { up: number, grow: number, side: { number }, recover: number, recoverTime: number, visual: number },
	slots: { string }, accent: Color3, shape: { any }?, muzzle: Vector3,
	art: boolean?, fp: any?, bolt: boolean?, bunch: number?,
}

local GunAssets = require(script.Parent.GunAssets)
Config.Guns = {
	{
		id = "P1", name = "P1", class = "Sidearm", price = 0, auto = false,
		damage = 24, headMult = 1.6, rpm = 420, mag = 12, reload = 1.4,
		range = 160, falloffStart = 60, minDamageMult = 0.6, pellets = 1,
		hipSpread = 1.0, adsSpread = 0, pelletSpread = 0,
		adsFov = 58, adsTime = 0.12, adsSpeedMult = 0.85,
		recoil = { up = 0.9, grow = 0, side = { 0.10, -0.10 }, recover = 0.7, recoverTime = 0.2, visual = 1.0 },
		slots = { "optic", "barrel", "mag" }, accent = Color3.fromRGB(64, 220, 255),
		muzzle = GunAssets.P1.muzzle, art = true,
		fp = { hip = Vector3.new(0.6, -0.6, -1.35), eye = 0.95, kick = { back = 0.09, rise = 4.5, roll = 2, spring = 260, damp = 22 },
			mover = { kind = "slide", travel = 0.13, time = 0.09 }, bob = 1.0 },
	},
	{
		id = "P2", name = "P2", class = "Sidearm", price = 2000, auto = false,
		damage = 30, headMult = 1.6, rpm = 330, mag = 10, reload = 1.4,
		range = 160, falloffStart = 60, minDamageMult = 0.6, pellets = 1,
		hipSpread = 1.0, adsSpread = 0, pelletSpread = 0,
		adsFov = 58, adsTime = 0.12, adsSpeedMult = 0.85,
		recoil = { up = 1.1, grow = 0, side = { 0.10, -0.10 }, recover = 0.7, recoverTime = 0.2, visual = 1.0 },
		slots = { "optic", "barrel", "mag" }, accent = Color3.fromRGB(64, 220, 255),
		muzzle = GunAssets.P2.muzzle, art = true,
		fp = { hip = Vector3.new(0.6, -0.6, -1.35), eye = 0.95, kick = { back = 0.09, rise = 4.5, roll = 2, spring = 260, damp = 22 },
			mover = { kind = "slide", travel = 0.13, time = 0.09 }, bob = 1.0 },
	},
	{
		id = "A1", name = "A1", class = "Rifle", price = 3000, auto = true,
		damage = 20, headMult = 1.6, rpm = 600, mag = 28, reload = 2.1,
		range = 250, falloffStart = 90, minDamageMult = 0.65, pellets = 1,
		hipSpread = 2.2, adsSpread = 0, pelletSpread = 0,
		adsFov = 50, adsTime = 0.18, adsSpeedMult = 0.75,
		recoil = { up = 0.5, grow = 0.05, side = { 0, 0.08, 0.15, 0.2, 0.1, -0.1, -0.2, -0.25, -0.1, 0.1 }, recover = 0.5, recoverTime = 0.35, visual = 0.8 },
		slots = { "optic", "barrel", "mag", "grip" }, accent = Color3.fromRGB(255, 80, 200),
		muzzle = GunAssets.A1.muzzle, art = true,
		fp = { hip = Vector3.new(0.6, -0.72, -1.0), eye = 0.5, kick = { back = 0.05, rise = 1.8, roll = 1.0, spring = 360, damp = 28 }, bob = 1.0 },
	},
	{
		id = "A2", name = "A2", class = "Rifle", price = 1000, auto = true,
		damage = 14, headMult = 1.5, rpm = 780, mag = 30, reload = 1.8,
		range = 120, falloffStart = 40, minDamageMult = 0.55, pellets = 1,
		hipSpread = 2.0, adsSpread = 0.2, pelletSpread = 0,
		adsFov = 62, adsTime = 0.14, adsSpeedMult = 0.8,
		recoil = { up = 0.35, grow = 0.04, side = { 0.05, 0.12, 0.18, 0.10, -0.08, -0.2, -0.22, -0.05, 0.14, 0.2 }, recover = 0.5, recoverTime = 0.3, visual = 0.6 },
		slots = { "optic", "barrel", "mag", "grip" }, accent = Color3.fromRGB(120, 255, 90),
		muzzle = GunAssets.A2.muzzle, art = true,
		fp = { hip = Vector3.new(0.62, -0.68, -1.05), eye = 0.45, kick = { back = 0.035, rise = 1.2, roll = 0.8, spring = 420, damp = 30 }, bob = 0.9 },
	},
	{
		id = "S1", name = "S1", class = "Sniper", price = 10000, auto = false, bolt = true, bunch = 1,
		damage = 95, headMult = 2.0, rpm = 50, mag = 5, reload = 2.8,
		range = 500, falloffStart = 300, minDamageMult = 0.85, pellets = 1,
		hipSpread = 4.0, adsSpread = 0, pelletSpread = 0,
		adsFov = 20, adsTime = 0.28, adsSpeedMult = 0.6,
		recoil = { up = 2.6, grow = 0, side = { 0.25, -0.2, 0.3 }, recover = 0.9, recoverTime = 0.45, visual = 2.2 },
		slots = { "optic", "barrel", "mag", "grip" }, accent = Color3.fromRGB(160, 110, 255),
		muzzle = GunAssets.S1.muzzle, art = true,
		fp = { hip = Vector3.new(0.58, -0.7, -0.95), eye = 0.35, scope = true, kick = { back = 0.14, rise = 6, roll = 2.5, spring = 160, damp = 16 },
			mover = { kind = "bolt", lift = 60, travel = 0.24, delay = 0.12, time = 0.8 }, bob = 1.1 },
	},
	{
		id = "S2", name = "S2", class = "Sniper", price = 12000, auto = false, bolt = true, bunch = 1,
		damage = 80, headMult = 2.0, rpm = 65, mag = 7, reload = 2.8,
		range = 500, falloffStart = 300, minDamageMult = 0.85, pellets = 1,
		hipSpread = 4.0, adsSpread = 0, pelletSpread = 0,
		adsFov = 20, adsTime = 0.28, adsSpeedMult = 0.6,
		recoil = { up = 2.1, grow = 0, side = { 0.25, -0.2, 0.3 }, recover = 0.9, recoverTime = 0.45, visual = 2.2 },
		slots = { "optic", "barrel", "mag", "grip" }, accent = Color3.fromRGB(160, 110, 255),
		muzzle = GunAssets.S2.muzzle, art = true,
		fp = { hip = Vector3.new(0.58, -0.7, -0.95), eye = 0.35, scope = true, kick = { back = 0.14, rise = 6, roll = 2.5, spring = 160, damp = 16 },
			mover = { kind = "bolt", lift = 60, travel = 0.24, delay = 0.12, time = 0.8 }, bob = 1.1 },
	},
	{
		id = "G1", name = "G1", class = "Shotgun", price = 6000, auto = false,
		damage = 9, headMult = 1.3, rpm = 75, mag = 6, reload = 2.6,
		range = 70, falloffStart = 20, minDamageMult = 0.4, pellets = 8,
		hipSpread = 1.5, adsSpread = 0, pelletSpread = 4.5,
		adsFov = 60, adsTime = 0.16, adsSpeedMult = 0.8,
		recoil = { up = 2.2, grow = 0, side = { 0.3, -0.3 }, recover = 0.8, recoverTime = 0.35, visual = 2.0 },
		slots = { "optic", "barrel", "grip" }, accent = Color3.fromRGB(255, 200, 40),
		muzzle = GunAssets.G1.muzzle, art = true,
		fp = { hip = Vector3.new(0.6, -0.7, -1.1), eye = 0.6, kick = { back = 0.1, rise = 5, roll = 2, spring = 220, damp = 22 },
			mover = { kind = "pump", travel = 0.24, delay = 0.12, time = 0.22 }, bob = 1.1 },
	},
	{
		id = "G2", name = "G2", class = "Shotgun", price = 15000, auto = false,
		damage = 8, headMult = 1.3, rpm = 65, mag = 6, reload = 2.6,
		range = 70, falloffStart = 20, minDamageMult = 0.4, pellets = 10,
		hipSpread = 1.5, adsSpread = 0, pelletSpread = 4.5,
		adsFov = 60, adsTime = 0.16, adsSpeedMult = 0.8,
		recoil = { up = 2.5, grow = 0, side = { 0.3, -0.3 }, recover = 0.8, recoverTime = 0.35, visual = 2.0 },
		slots = { "optic", "barrel", "grip" }, accent = Color3.fromRGB(255, 200, 40),
		muzzle = GunAssets.G2.muzzle, art = true,
		fp = { hip = Vector3.new(0.6, -0.7, -1.1), eye = 0.6, kick = { back = 0.1, rise = 5, roll = 2, spring = 220, damp = 22 },
			mover = { kind = "pump", travel = 0.24, delay = 0.12, time = 0.22 }, bob = 1.1 },
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
		gas = { x = 0.885, y = 0.72, size = 86, label = "GAS", driving = true },
		brake = { x = 0.75, y = 0.8, size = 62, label = "BRAKE", driving = true },
		exit = { x = 0.935, y = 0.25, size = 50, label = "EXIT", driving = true },
		lights = { x = 0.79, y = 0.36, size = 49, label = "LED", driving = true },
		doors = { x = 0.65, y = 0.36, size = 49, label = "DOOR", driving = true },
		view = { x = 0.52, y = 0.36, size = 49, label = "VIEW", driving = true },
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
	LobbyReady = Enum.KeyCode.Return, TutorialSkip = Enum.KeyCode.Backspace,
	MenuBack = Enum.KeyCode.Backspace, PadMenuBack = Enum.KeyCode.ButtonB, PadReady = Enum.KeyCode.ButtonR1,
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
	Enabled = { "blackout", "doublePatrol", "laserStorm", "shortFuse", "glitchSurge", "loudFloor" }, -- 3C adds laserStorm, shortFuse, glitchSurge, loudFloor
	Force = nil,
	blackout = {
		name = "BLACKOUT",
		visionMult = 0.6, -- lights out: bots see less far; the crew sees less too
		lighting = { Brightness = 0.15, ClockTime = 0, Ambient = Color3.fromRGB(14, 14, 24), OutdoorAmbient = Color3.fromRGB(20, 20, 34), FogEnd = 420 },
	},
	doublePatrol = { name = "DOUBLE PATROL", sentryMult = 2 },
 laserStorm = { name = "LASER STORM", laserMult = 1.6 },
 shortFuse = { name = "SHORT FUSE", alarmMult = 2 },
 glitchSurge = { name = "GLITCH SURGE", reroute = true },
 loudFloor = { name = "LOUD FLOOR", bumpMult = { gunfire = 2 } },
}

-- One-seat kart (§3b, §7): owner's RAZOR model on an invisible physics box. KartPhysics = fixed-step
-- rigid body (same code on the driver's client and in ServerPhysics mode): sphere-cast wheels, spring +
-- bump/rebound damping + bump stop, anti-roll bars, tyre slip curve. Kart frame: origin = ground under the
-- kart centre at the RAZOR design ride height, +X right, +Y up, nose -Z. All numbers = placeholders.
Config.Kart = {
	ServerPhysics = false,
 TopTierSpeedMult = 1.08, TopTierAccelMult = 1.04,
	MaxSpeed = 60, Accel = 42, Reverse = 20, Brake = 95, -- studs/s, studs/s^2
	Drag = 0.13, Roll = 1.5, AirDrag = 0.05, -- coast: Drag x speed + Roll (studs/s^2)
	TopTaper = 0.15, -- drive force fades to 0 over the top 15% of MaxSpeed
	DriveRear = 0.6, -- share of drive on the rear axle (rest front): stable on phones
	GradeAssist = 1, -- 1 = slopes neither slow you nor roll you back (arcade)
	Steer = 32, SteerFalloff = 48, SteerRate = 8, -- deg; speed-sensitive (Steer / (1 + (v/SteerFalloff)^2)); 1/s
	Gravity = 110, -- kart-only gravity (Roblox 196.2 is cancelled on the kart): readable jumps, softer landings
	Step = 1 / 120, MaxSubsteps = 12, -- fixed-step sub-stepping: 30 fps and 60 fps run identical substeps
	Inertia = Vector3.new(20, 11.4, 3), -- per unit mass: pitch (X), yaw (Y), roll (Z)
	-- RAZOR geometry, measured from assets/kart/razor (razor_build.py CFG + razor_export.py), kart frame.
	Geo = {
		WheelRadius = 0.92, WheelWidth = 0.96,
		Hubs = { Vector3.new(-1.925, 0.92, -3.4), Vector3.new(1.925, 0.92, -3.4), Vector3.new(-1.925, 0.92, 3.6), Vector3.new(1.925, 0.92, 3.6) }, -- FL FR RL RR: track 3.85, wheelbase 7.0
		Chassis = { Center = Vector3.new(0, 1.75, -0.05), Size = Vector3.new(5.16, 3.14, 11.2) }, -- mesh bbox
		Collider = { Center = Vector3.new(0, 1.25, 0), Size = Vector3.new(4.9, 1.1, 8.4) }, -- shortened hull with bottom at 0.7: clears ramp approach beneath the visual overhang
		Ballast = { Center = Vector3.new(0, 0.55, 0), Size = Vector3.new(3, 0.4, 6), Density = 10 }, -- lowers the CoM
		ColliderDensity = 0.3,
		Seat = Vector3.new(0, 1.54, 0.05), -- seat pan top
		SteerHub = Vector3.new(0, 1.85, -0.95), SteerTilt = 30, SteerRatio = 4, -- steering wheel turns 4x the road wheels
		HoodPlate = { Center = Vector3.new(0, 1.48, -3.4), Size = Vector3.new(1.88, 0.05, 1.57), Pitch = -6.6 }, -- §17 decal zones (hood follows ZCEN 1.40..1.58)
		RearPlate = { Center = Vector3.new(0, 1.1, 5.0), Size = Vector3.new(1.56, 0.46, 0.05) },
		Tris = 6616, -- optimized approved source geometry; rendered derivative measured separately
	},
	Susp = {
		Freq = 2.3, -- ride frequency (Hz): spring rate = (2 pi f)^2 per unit corner mass, preloaded to sit at static
		Droop = 0.8, Bump = 0.35, -- travel below / above static (studs); long droop catches landings before the hard stop
		StaticDrop = 0.2, -- body rides this far above the RAZOR design height: its 0.06 arch / 0.18 floor clearance leave no travel
		BumpZeta = 0.6, ReboundZeta = 0.95, -- damping ratios (1 = critical)
		Knee = 3, Digress = 0.3, -- above Knee studs/s the damper slope x Digress (blow-off: sharp hits stay soft)
		StopZone = 0.12, StopG = 2, -- progressive bump stop over the last 0.12 of bump travel, +6 g at full bump
		StopBias = 0.2, StopBiasMax = 3, -- hard stop: closing speed -> 0 (no bounce) + gentle push-out
		ARBFront = 0.5, ARBRear = 0.3, -- anti-roll bars, fraction of spring rate
		MaxLoadG = 4.8, -- cap force at deep bump; the hard stop removes residual closing speed without spring energy
		TyreLag = 0.03, -- s: tyre/sidewall filter on the road-profile rate the damper sees
		CastRadius = 0.75, CastMargin = 1, -- sphere-cast wheel (bridges holes, rolls up edges)
		VisualDroopRate = 6, -- studs/s a wheel drops when it leaves the ground (visual only)
	},
	Tyre = { Mu = 1.2, PeakSlip = 8, Slide = 0.75, LowSpeed = 3, RollCenter = 0.35 }, -- slip curve: peak at 8 deg, 75% when sliding
	Air = { Level = 80, Damp = 14, After = 0.02, LandingTime = 0.5, LandingDamp = 2 }, -- arcade levelling and landing damping
	Rest = { Speed = 0.08, Spin = 0.03 }, -- below these with 4 wheels down and no throttle: hold still (no creep/jitter)
	FlipTime = 1.5,
	EmpTime = 1.2, EmpSpin = 7, EmpSpeedMult = 0.35, EmpAccelMult = 0.3, EmpGripMult = 0.25, -- EMP: tyres lose grip = spin-out
	InputRate = 15, InputTimeout = 0.5, -- server-physics mode only
	SpeedTolerance = 1.35, Strikes = 2, -- anti-cheat on driver-owned karts: rubber-band on repeat overspeed
	IdleAnchor = 2, -- an empty kart at rest anchors after this many seconds (cheap physics)
	LootMount = CFrame.new(0, 1.85, 3.1), -- heavy loot on the rear deck (root space)
	Camera = { Back = 15, Up = 6.5, Ahead = 10, Lerp = 8, Fov = 75 },
	CockpitEye = Vector3.new(0, 2.32, 0.35), CockpitLook = Vector3.new(0, 2.04, -12),
	DoorMaxSpeed = 2, DoorAngle = 68,
}

-- Offline Vortex RBXMX ships with both places. The editable Blender/FBX source is in assets/karts/vortex.
Config.KartModel = { Template = "VortexKartApproved", HubTolerance = 0.15 }

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
Config.WorldAudio = { Roll = "rbxasset://sounds/action_footsteps_plastic.mp3", Drone = "rbxasset://sounds/action_swim.mp3", Cue = "rbxasset://sounds/volume_slider.ogg", RollVolume = .12, DroneVolume = .08, CueVolume = .18, CuePool = 4, Range = 90, UpdateSeconds = .1 }

Config.City = { CycleSeconds = 1200, StartHours = { 9, 17, 21 }, UpdateSeconds = 1, MaxLights = 6, LightRange = 140, RecoverBelow = -5 }

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
	DefaultLoan = { [2] = "A2", [3] = "A1" }, -- range only: fills wheel slots 2-3 so the wheel is testable at once
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

-- Private-test economy: all production product IDs remain zero, no Robux prompts.
Config.Economy = { Season = 1, XpPerTier = 250, RunXp = 250, FailXp = 50, TierCredits = 100,
 AttachmentPrice = 600, RepairSkip = 100, PaidRandomEnabled = false, PassProduct = 0,
 SpinProduct = 0, SpinPackProduct = 0, CrateProduct = 0, BundleProducts = { 0, 0, 0 },
 SpinItems = {}, SeasonName = "Static Signal" }
local names = { "Slate", "Sand", "Harbor", "Courier", "Circuit", "Carbon", "Static Face", "Signal", "Buffering", "Midnight", "Ivory", "Full Static" }
local weights = {10,10,10,10,10,10,8.33,8.33,8.34,5.5,5.5,4}
for i,name in ipairs(names) do
 local id="static_"..i
 local col=RGB(45+i*8,55+i*6,65+i*5)
 table.insert(Config.Cosmetics,{id=id,slot="mask",name=name,parts={piece("Head","Block",V3(.85,.35,.1),V3(0,0,-.55),col)}})
 table.insert(Config.Economy.SpinItems,{id=id,weight=weights[i],rank=i<=6 and 1 or (i<=9 and 2 or (i<=11 and 3 or 4))})
end

-- Lookup tables (built once).
Config.GunsById = {} :: { [string]: Gun }
for _, g in ipairs(Config.Guns) do
	Config.GunsById[g.id] = g
end
Config.AttachmentsById = {}
for _, a in ipairs(Config.Attachments) do
	Config.AttachmentsById[a.id] = a
end
Config.CosmeticsById = {}
for _, c in ipairs(Config.Cosmetics) do
	Config.CosmeticsById[c.id] = c
end

return Config
