local C = require(game.ReplicatedStorage.BlackoutCrew.Config)
return function(T)
 local ok, counts = T.cmdLong(90, "gunTris")
 T.check("render measurement completed", ok and counts ~= nil)
 if ok then
  for _, g in ipairs(C.Guns) do
   local r = counts[g.id]
   print("BC_TRI", g.id, r.fp, r.world, r.kind)
   T.check(g.id .. " measured FP budget", r.fp > 0 and r.fp <= C.TriBudget.FirstPersonGun, r.fp)
   T.check(g.id .. " measured world budget", r.world > 0 and r.world <= C.TriBudget.WorldGun, r.world)
   if g.art then T.eq(g.id .. " real meshes render", r.kind, "mesh") end
  end
 end
 local function state() local ok, r = T.cmd("gunState"); assert(ok, "gunState failed"); return r end
 local ok, r = T.cmdLong(30, "gunEquip", "needle")
 T.check("Needlepoint equipped", ok and r.gun == "needle" and r.built)
 T.cmd("gunAds", true, 0.5)
 r = state()
 T.check("scope full view enabled", r.scoped and r.scopeGui and r.hidden > 0 and r.shown == 0)
 T.check("scope zoom applied", r.fov < C.Camera.Fov)
 local ok, menu = T.cmd("openMenu")
 T.check("menu resets scope immediately", ok and menu.alpha == 0 and not menu.scoped)
 T.cmd("adsSpam", 12, 0.02)
 T.cmd("gunAds", false, 0.5)
 r = state()
 T.check("rapid toggles restore view", not r.ads and not r.scoped and not r.scopeGui and r.shown > 0)
 T.cmd("gunAds", true, 0.5)
 T.cmdLong(30, "gunEquip", "dart9")
 r = state()
 T.check("swap resets scope", not r.ads and not r.scoped and r.alpha == 0)
 local ok, delta = T.cmd("elimReplay", 1000000000)
 T.eq("duplicate confirmations show one tag", delta, 1)
 local ok, delta = T.cmd("elimReplay", 1000000000)
 T.eq("later repeated confirmation suppressed", delta, 0)
 r = state()
 T.check("tag avoids centre reticle", r.elimRect.x > 10 and r.elimRect.y > 10)
 T.cmdLong(30, "gunEquip", "ranger")
 T.cmd("gunAds", true, 0.5)
 r = state()
 T.check("Ranger sights centred and aligned", r.sight and r.front and math.abs(r.sight.x) < 3 and math.abs(r.sight.y) < 3 and math.abs(r.front.x) < 3 and math.abs(r.front.y) < 3)
 T.cmdLong(30, "gunEquip", "needle")
 T.cmd("gunAds", true, 0.5)
 T.player.Character.Humanoid.Health = 0
 task.wait(0.2)
 r = state()
 T.check("death resets scope", not r.ads and not r.scoped and r.alpha == 0)
 local old = T.player.Character
 local untilAt = os.clock() + 15
 repeat task.wait(0.1) until (T.player.Character ~= old and T.player.Character and T.player.Character:FindFirstChild("Head")) or os.clock() > untilAt
 T.check("respawn completed", T.player.Character ~= old)
 T.cmdLong(30, "gunEquip", "dart9")
end
