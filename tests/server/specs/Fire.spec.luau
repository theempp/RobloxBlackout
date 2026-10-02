-- Server fire validation with the real Play-mode player. Targets are placed straight ABOVE the player's
-- head (the sky is always clear), because a server cannot move a client-owned character.
-- A fake clock makes rate/reload/draw checks deterministic.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)
local GunStats = require(RS.BlackoutCrew.GunStats)
local Spread = require(RS.BlackoutCrew.Spread)
local RateLimit = require(RS.BlackoutCrew.RateLimit)
local server = game.ServerScriptService.BlackoutCrew
local Weapons = require(server.Weapons)
local Targets = require(server.Targets)
local Remotes = require(server.Remotes)

return function(T)
	local player = T.player
	local head = player.Character.Head
	local made = {}
	local now = 100
	Weapons.clock = function()
		return now
	end
	local function dummy(height, opts)
		opts = opts or {}
		local cf = CFrame.new(head.Position + Vector3.new(0, height, 0))
		if opts.flip then
			cf *= CFrame.Angles(math.pi, 0, 0)
		end
		local m = Targets.makeDummy(cf, { health = opts.health or 1000, name = "TestDummy" })
		table.insert(made, m)
		return m
	end
	local seq = 0
	local function shoot(target, extra)
		extra = extra or {}
		seq += extra.seqStep or 1
		local origin = extra.origin or head.Position
		local aim = target and (target.PrimaryPart.Position - origin).Unit or Vector3.yAxis
		return Weapons.fire(player, extra.seq or seq, origin, extra.dir or aim, extra.ads ~= false)
	end

	local ok, err = pcall(function()
		Weapons.states[player] = nil
		T.check("equip slot 1", Weapons.equip(player, 1))
		local st = Weapons.states[player]
		T.eq("slot 1 = free gun", st.gunId, "dart9")
		T.eq("range default loan fills slot 2", Weapons.gunInSlot(player, 2), C.Range.DefaultLoan[2])
		st.loan = {} -- below: profile-only loadout
		T.eq("coming-soon slot rejected", select(2, Weapons.equip(player, 4)), "comingSoon")
		T.eq("invalid slot rejected", select(2, Weapons.equip(player, 9)), "invalid")
		T.eq("empty slot rejected", select(2, Weapons.equip(player, 2)), "empty")
		T.eq("non-integer slot rejected", select(2, Weapons.equip(player, 1.5)), "badArgs")
		T.eq("still on slot 1", st.slot, 1)

		local d1 = dummy(20)
		T.eq("fire while drawing rejected", select(2, shoot(d1)), "drawing")
		now += 0.5
		local s = st.stats
		local okShot, reason, hits = shoot(d1)
		T.check("valid shot accepted", okShot, reason)
		T.eq("valid shot hits", hits and #hits, 1)
		local dist = hits and hits[1] and (hits[1].p - head.Position).Magnitude or 0
		local expected = math.floor(GunStats.damageAt(s, dist, false) + 0.5)
		T.eq("damage applied = stats", hits and hits[1] and hits[1].d, expected)
		T.eq("dummy health reduced", d1:GetAttribute("Health"), 1000 - expected)
		T.eq("ammo decremented", st.ammo.dart9, s.mag - 1)
		T.eq("instant second shot rate-limited", select(2, shoot(d1)), "rate")
		now += s.interval
		T.check("shot after interval accepted", shoot(d1))
		now += s.interval
		T.eq("replayed seq rejected", select(2, shoot(d1, { seq = seq - 1, seqStep = 0 })), "seq")
		T.eq("seq jump rejected", select(2, shoot(d1, { seqStep = 5000 })), "seq")
		seq -= 5000
		T.eq("origin far from head rejected", select(2, shoot(d1, { origin = head.Position + Vector3.new(0, 0, 20) })), "origin")
		T.eq("NaN direction rejected", select(2, shoot(nil, { dir = Vector3.new(0 / 0, 1, 0) })), "badArgs")
		T.eq("zero direction rejected", select(2, shoot(nil, { dir = Vector3.zero })), "badArgs")
		T.eq("non-integer seq rejected", select(2, Weapons.fire(player, 1.5, head.Position, Vector3.yAxis, true)), "badArgs")
		T.eq("wrong arg type rejected", select(2, Weapons.fire(player, seq + 1, "x", Vector3.yAxis, true)), "badArgs")

		st.ammo.dart9 = 0
		now += 1
		T.eq("empty mag rejected", select(2, shoot(d1)), "empty")
		T.check("reload accepted", Weapons.reload(player))
		T.eq("fire during reload rejected", select(2, shoot(d1)), "reloading")
		T.eq("double reload rejected", select(2, Weapons.reload(player)), "reloading")
		now += s.reload
		T.check("fire after reload accepted", shoot(d1))
		T.eq("mag refilled", st.ammo.dart9, s.mag - 1)
		st.ammo.dart9 = s.mag
		T.eq("reload when full rejected", select(2, Weapons.reload(player)), "full")
		d1:Destroy() -- targets share the column above the head: clear each before the next

		now += 1
		local far = dummy(s.range + 30)
		local okFar, _, farHits = shoot(far)
		T.check("out-of-range shot accepted but misses", okFar and #farHits == 0)

		now += 1
		local d2 = dummy(20)
		local wall = Instance.new("Part")
		wall.Anchored, wall.Size, wall.Transparency = true, Vector3.new(4, 0.5, 4), 1
		wall.CFrame = CFrame.new(head.Position + Vector3.new(0, 8, 0))
		wall.Parent = workspace
		table.insert(made, wall)
		local spoof = head.Position + Vector3.new(5, 0, 0)
		local okLos, _, losHits = shoot(d2, { origin = spoof })
		T.check("wall between head and target: no damage", okLos and #losHits == 0 and d2:GetAttribute("Health") == 1000)
		now += 1
		local okWall, _, wallHits = shoot(d2)
		T.check("wall blocks direct shot", okWall and #wallHits == 0)
		wall:Destroy()
		d2:Destroy()
		far:Destroy()

		now += 1
		local flipped = dummy(20, { flip = true })
		local okHead, _, headHits = shoot(nil, { dir = (flipped.Head.Position - head.Position).Unit })
		T.check("headshot flagged", okHead and headHits[1] and headHits[1].h == true)
		local hd = headHits[1] and headHits[1].d or 0
		T.eq("headshot damage uses headMult", hd, math.floor(GunStats.damageAt(s, (headHits[1].p - head.Position).Magnitude, true) + 0.5))
		flipped:Destroy()

		now += 1
		local weak = dummy(40, { health = 10 })
		local _, _, killHits = shoot(weak)
		T.check("server defeat id attached", killHits[1] and type(killHits[1].e) == "number")
		T.check("kill reported", killHits[1] and killHits[1].k == true and weak:GetAttribute("Down") == true)
		now += 1
		local _, _, downHits = shoot(weak)
		T.eq("downed target takes no damage", #downHits, 0)
		weak:Destroy()

		T.near("no falloff before falloffStart", GunStats.damageAt(s, s.falloffStart, false), s.damage)
		T.near("min damage at max range", GunStats.damageAt(s, s.range, false), s.damage * s.minDamageMult)
		T.check("falloff monotonic", GunStats.damageAt(s, 100, false) <= GunStats.damageAt(s, 70, false))

		Weapons.setAds(player, true)
		T.near("ADS slows walk", player.Character.Humanoid.WalkSpeed, C.Movement.WalkSpeed * s.adsSpeedMult)
		Weapons.setAds(player, false)
		T.near("ADS off restores walk", player.Character.Humanoid.WalkSpeed, C.Movement.WalkSpeed)

		T.check("range loan equips", Weapons.loan(player, "scatter"))
		T.eq("loaned gun active", st.gunId, "scatter")
		T.check("bad loan rejected", not Weapons.loan(player, "nope"))
		now += 1
		local d3 = dummy(12)
		local _, _, pellets = shoot(d3)
		local one = GunStats.damageAt(st.stats, 10, false)
		T.check("pellets aggregate into one hit > 1 pellet", pellets[1] and #pellets == 1 and pellets[1].d > one, pellets[1] and pellets[1].d)
		d3:Destroy()
        T.check("bolt loan equips", Weapons.loan(player, "needle"))
        now += 2
        T.check("bolt first shot accepted", shoot(nil))
        now += st.stats.interval * 0.5
        T.eq("bolt half cycle rejected", select(2, shoot(nil)), "rate")
        now += st.stats.interval * 0.5 + 0.001
        T.check("bolt full cycle accepted", shoot(nil))
        now += 10
        T.check("bolt idle shot accepted", shoot(nil))
        now += st.stats.interval * 0.5
        T.eq("bolt idle cannot bank burst", select(2, shoot(nil)), "rate")
        local dead = dummy(25, { health = 1 })
        local _, killed, id = Targets.damage(dead, 10)
        local dealt, twice, repeated = Targets.damage(dead, 10)
        T.check("multi-hit defeat emitted once", killed and type(id) == "number" and dealt == 0 and not twice and repeated == nil)
        Targets.setDown(dead, false)
        local _, again, newId = Targets.damage(dead, 10000)
        T.check("respawn has new defeat id", again and newId ~= id)
        st.loan = {}

		local a = Spread.direction(Vector3.yAxis, 3, Spread.seed(player.UserId, 7, 1))
		T.check("spread deterministic", a == Spread.direction(Vector3.yAxis, 3, Spread.seed(player.UserId, 7, 1)))
		T.check("spread varies by seq", a ~= Spread.direction(Vector3.yAxis, 3, Spread.seed(player.UserId, 8, 1)))
		local worst = 0
		for i = 1, 300 do
			local d = Spread.direction(Vector3.new(1, 2, 3), 4, Spread.seed(-1, i, 1))
			worst = math.max(worst, math.deg(math.acos(math.clamp(d:Dot(Vector3.new(1, 2, 3).Unit), -1, 1))))
		end
		T.check("spread within cone", worst <= 4.0001 and worst > 2, worst)
		T.check("zero cone exact", Spread.direction(Vector3.new(0, 0, -2), 0, 1) == Vector3.new(0, 0, -1))

		local b = RateLimit.new(10, 3)
		local passed = 0
		for _ = 1, 10 do
			if b:take("k", 0) then
				passed += 1
			end
		end
		T.eq("bucket burst", passed, 3)
		T.check("bucket refills", b:take("k", 0.1) and not b:take("k", 0.1))
		T.check("remote flood dropped (client probe sent 60)", (Remotes.dropped.Fire or 0) >= 25, Remotes.dropped.Fire)
		T.eq("no remote handler errors", Remotes.errors.Fire or 0, 0)
	end)
	T.check("fire spec ran to completion", ok, err)
	for _, m in ipairs(made) do
		m:Destroy()
	end
	Weapons.clock = os.clock
	Weapons.states[player] = nil
	Weapons.equip(player, 1)
end
