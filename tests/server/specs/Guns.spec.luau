-- Gun data, attachments (sidegrades), recoil patterns, primitive models, tri budgets.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.BlackoutCrew.Config)
local GunStats = require(RS.BlackoutCrew.GunStats)
local GunModel = require(RS.BlackoutCrew.GunModel)
local Recoil = require(RS.BlackoutCrew.Recoil)

return function(T)
	for _, g in ipairs(C.Guns) do
		local s = GunStats.resolve(g.id)
		T.check(g.id .. " resolves", s ~= nil and math.abs(s.interval - 60 / g.rpm) < 1e-9)
		local tris = GunModel.estimateTris(g)
		T.check(g.id .. " world tri budget", tris <= C.TriBudget.WorldGun, tris)
		T.check(g.id .. " first-person tri budget", tris <= C.TriBudget.FirstPersonGun, tris)
		local m = GunModel.build(g)
		local parts, collide, engr = 0, 0, 0
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
				if d.CanCollide or d.CanQuery or not d.Massless then
					collide += 1
				end
			elseif d.Name == "Engraving" then
				engr += 1
			end
		end
		T.eq(g.id .. " model parts", parts, #g.shape + 1)
		T.eq(g.id .. " parts non-colliding/massless", collide, 0)
		T.eq(g.id .. " one engraving layer", engr, 1)
		T.check(g.id .. " muzzle attachment", m.PrimaryPart and m.PrimaryPart:FindFirstChild("Muzzle") ~= nil)
		m:Destroy()
	end

	local r = GunStats.resolve("ranger", { mag = "ext_mag", barrel = "compensator", grip = "vert_grip" })
	T.eq("ext_mag rounds mag", r.mag, math.floor(28 * 1.4 + 0.5))
	T.near("ext_mag slows reload", r.reload, 2.1 * 1.2)
	T.near("compensator * vert_grip recoil", r.recoil.up, 0.5 * 0.85 * 0.88)
	T.near("compensator widens hip spread", r.hipSpread, 2.2 * 1.15)
	T.eq("Config recoil not mutated", C.GunsById.ranger.recoil.up, 0.5)
	local p = GunStats.resolve("dart9", { grip = "vert_grip", mag = "scope2x" })
	T.check("disallowed slot / wrong-slot attachment ignored", next(p.attachments) == nil and p.recoil.up == 0.9)
	T.eq("unknown gun resolves nil", GunStats.resolve("nope"), nil)

	for _, a in ipairs(C.Attachments) do
		local buff, cost, unknown = 0, 0, 0
		for stat, m in pairs(a.mods) do
			if GunStats.LOWER_BETTER[stat] then
				if m < 1 then buff += 1 else cost += 1 end
			elseif GunStats.HIGHER_BETTER[stat] then
				if m > 1 then buff += 1 else cost += 1 end
			else
				unknown += 1
			end
		end
		T.check(a.id .. " is a sidegrade (buff + cost)", buff >= 1 and cost >= 1 and unknown == 0, buff .. "/" .. cost .. "/" .. unknown)
		T.check(a.id .. " slot valid", table.find(C.AttachmentSlots, a.slot) ~= nil)
	end

	-- Recoil: deterministic, learnable, per-blaster
	local s = GunStats.resolve("ranger")
	local u1, x1 = Recoil.kick(s, 3)
	local u2, x2 = Recoil.kick(s, 3)
	T.check("kick deterministic", u1 == u2 and x1 == x2)
	T.eq("side pattern loops", select(2, Recoil.kick(s, 1)), select(2, Recoil.kick(s, 1 + #s.recoil.side)))
	T.check("vertical grows then plateaus", Recoil.kick(s, 5) > Recoil.kick(s, 1) and Recoil.kick(s, 11) == Recoil.kick(s, 20))
	local sigs = {}
	for _, g in ipairs(C.Guns) do
		local sig = g.recoil.up .. "|" .. table.concat(g.recoil.side, ",")
		T.check(g.id .. " unique pattern", not sigs[sig])
		sigs[sig] = true
	end
	local function spray(n, counter)
		local st = Recoil.new()
		local t, total = 0, 0
		for _ = 1, n do
			local up = Recoil.onShot(st, s, t)
			total += up
			if counter then
				Recoil.onLook(st, -up * counter)
			end
			t += s.interval
		end
		local back = 0
		for _ = 1, 200 do
			t += 1 / 60
			back += Recoil.step(st, s, 1 / 60, t)
		end
		return total, back, st
	end
	local a1 = spray(10)
	local a2 = spray(10)
	T.eq("same spray, same climb", a1, a2)
	local total, back = spray(10)
	T.near("recovery returns recover * climb", -back, total * s.recoil.recover, 1e-6)
	local _, backFull = spray(10, 1)
	T.near("fully countered spray recovers nothing", backFull, 0, 1e-9)
	local totalHalf, backHalf = spray(10, 0.5)
	T.near("half-countered recovers half", -backHalf, totalHalf * 0.5 * s.recoil.recover, 1e-6)
	local st = Recoil.new()
	Recoil.onShot(st, s, 0)
	T.eq("no recovery while still firing", Recoil.step(st, s, 1 / 60, s.interval * 0.5), 0)
	Recoil.onShot(st, s, 5)
	T.eq("pattern resets after pause", st.index, 1)
end
