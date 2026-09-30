# Gate — Build 2 (Heist Loop, blockout)
Status: built, awaiting owner test + "go". The Build 1 gate went "go" without phone results, so phone fps, gun feel and the maturity questionnaire are all still owed.

## Tests: `python3 tools/test.py` = **870/870**
This runs 3 Studio sessions:
- **Lobby, 486:** Build 1 plus crews 21 and lobby/queue/teleport 36.
- **Heist, 355:** alarm, carry/loot, downed, enemies/perception, escape/payout, HUD layout, kart, lasers, map, session, twists, perf, and a full flow (dash → gate → payout → replay → crew wipe).
- **2-client, 29:** revive, hand-off, recall, the second client driving its own kart, both HUDs, and both players banking with the duo bonus.

Every new end-to-end check was negative-controlled once. Both shipping places boot clean (lobby 10/10 client modules, heist 16/16).

## Perf (Studio CLI only; phone numbers unknown)
- Heist server loop: 0.18 ms mean, 0.34 ms max per 10 Hz tick. Client: 60 fps, p95 18 ms. Idle remote sends: 0/s.
- About 240 primitive parts, StreamingEnabled, neon only (no dynamic lights), shadows off in the heist.
- Moving AI is capped at 8. Bots move by physics replication. Cameras and lasers are computed from server time on each client, so they send no traffic.

## Decisions (veto any)
1. **Kart physics runs on the driver's phone** (instant response). `Config.Kart.ServerPhysics = true` switches back to v0.3's server-owned model for an A/B test. The server checks speed (rubber-bands offenders), enforces a minimum dash time, and owns sabotage and EMP.
2. **Difficulty** is passed at teleport but never defined in the brief. There is one placeholder level, "normal", and no picker.
3. **"Caught"** = the crew wiped: heavy loot 50%, small loot 100%.
4. **Gate timer** is per player, 75 s, starting when you drive off your spot after the vault breach.
5. **AI cap (8)** counts sentries, watchers, repo drones and pursuit drones; cameras don't count. Solo/duo scaling applies to tower AI. Repo drone count follows the alarm tier.
6. **§5f [CONFIRM]:** one HOLD button. Priority: Override > revive > repair > load > hack > grab > give > drive > drop.
7. **Bots don't pathfind:** they patrol loops, stop and turn toward noise, and hold and fire when alerted.
8. **Minimap is north-up.** A rotating map needs a CanvasGroup, which is heavy on phones.
9. **Mirrored FIRE** default moved to (0.34, 0.40) so it doesn't cover the minimap.
10. **Heist guns** use the range loan (all 6 guns) until the armory in 3A.
11. **Lock hand-off:** each profile's session lock is released before the teleport and taken back if the teleport fails. Save schema is now v2 (`heist.runs`, `heist.lastObvious`); v1 saves migrate.

## Gaps
- **Untested:** live teleport, the lock hand-off, and live saves. All need published places, and the place ids are [OPEN] (`Config.Places` = 0).
- **Not built (out of Build 2 scope):** highway cutscene (§3), repair skip (3B), the other 4 twists/2 wings/guard sets and walk-up invites (3C), audio (§8).
- **Blockout limits:** kart wheels don't spin; sabotage shows only as a bar; recalled players stand frozen for 30 s.
- **~9 min run length is unmeasured.**

## Owner steps
1. Run `python3 tools/build.py`. This writes `build/lobby.rbxlx` and `build/heist.rbxlx`.
2. **Studio full run (heist.rbxlx → Play, or Test → Device iPhone XR):**
   - DRIVE to your glowing P and park.
   - In the vault: HACK the corridor panel (or jump the knee beams), GRAB the crate, LOAD it at your kart, drive to the green gate.
   - Try the terminal hack and getting downed (OVERRIDE). The run replays by itself after the results panel.
3. **Publish (target [OPEN]; rec: the old universe of place 85367345143911):** lobby = start place, heist = a second place in the same universe. Put both ids in `Config.Places`, rebuild, and publish both. Turn on friend-slot reservation for lobby servers (§11).
4. **Friends test, 1–4 players:** join the lobby, stand on one pad, READY → heist → escape → payout.
   - Time a full run (target ~9 min).
   - Rejoin and check the "Saved total" on the next results panel.
5. **Phone perf:** a 4-player heist on a low-end and a mid-range phone, with the perf overlay and benchmark. Targets: ≥30 fps low-end, 60 mid-range.
6. **Kart touch driving:** left stick steers and throttles, plus GAS/BRAKE/EXIT. Compare `Kart.ServerPhysics` false vs true, and report feel and lag.
7. **§17 visual review batch** (concept sheets only after plan + cost quotes; no generation yet), in order:
   1. guns
   2. darts + tracer
   3. attachments
   4. karts
   5. masks
   6. enemies
   7. loot/props
8. **Reply with:** phones + fps, kart and gun feel, run time, questionnaire result, vetoes, difficulty levels if you want them, then "go".
