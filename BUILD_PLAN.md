# Blackout Crew — Build Plan (v1 = alpha-ready)
Truth: DIRECTIVE_GRAY.md (numbers = placeholders -> one Config module). Old-code audit: SALVAGE.md. 3 builds, sequential. Each ends at a **gate**: stop, write `gates/build-N.md` (≤1 page: test counts, perf, gaps, owner tasks), owner phone-tests, owner says "go".

Current Oct 1 continuation: stages 3–4 and Build 3B–3D local test preparation authorised. See `gates/phone-test-readiness.md` for current evidence and explicit gaps; alpha acceptance remains pending.

## Global rules
- Placeholders/primitives only; no generated assets, no Higgsfield, until owner approves plan + cost quotes.
- Mobile first: StreamingEnabled, matte surfaces, no neon/emissive (owner override Sept 30); dynamic lights remain prohibited except a small, performance-tested number of practical city streetlights (owner approval Oct 1), tri budgets (§6). AI cap ~8.
- `~/Desktop/roblox 1` = read-only reference; SALVAGE.md is the audit; spot-check a file before porting.
- Studio CLI test per system. Claude Code can't test on phones; owner supplies device results.
- Name/logo via swappable decal layer. Never guess [OPEN]/owner-only items; ask once, batched.
- Read only the DIRECTIVE_GRAY sections listed per build (its Read map).

## Build 1 — Foundation + Gun Feel (Phase 1A)  | Reads: §4 §5f §6 §15 §16
1. **Toolchain first:** Studio + CLI probe, Rojo availability; pick pipeline (old `package.py` not reusable). Repo layout (`src/{shared,server,client}`, `tests/`, `tools/`), git if absent.
2. Port per SALVAGE: `Rules.clean` (new schema), `Profiles` (new store name), receipt pattern, HUD scale/safe-inset helpers, test harness + frame probe. Defer shop framework (3B) and crews (Build 2).
3. Config module (all tunables), logging, perf overlay (toggle).
4. Guns: server-validated hitscan, per-blaster recoil pattern, ADS, hit/damage markers, light aim assist (toggle), attachment data model (sidegrades), 6 guns (1 free + 5 priced 1k/3k/6k/10k/15k Credits) as placeholder foam-tactical primitives, 5-slot wheel (3 usable, 2 Coming Soon).
5. Touch controls §5f (two-thumb, movable/resizable buttons, tap-swap + hold-radial wheel) + keyboard/gamepad fallback.
6. Test range: dummies, sentry dummy, damage numbers.
**Gate:** tests pass; owner phone test of gun feel + fps (floor >=30 low-end, 60 mid); owner runs maturity questionnaire (target Mild); keep/adjust foam-tactical.
Not in scope: lobby, heist, karts, economy UI, wheel, assets.

## Build 2 — Heist Loop (Phase 1B, blockout art)  | Reads: §3 §3b §5 §5b-5e §5h §7 §11 §17
1. Servers: minimal lobby (queue pad, squad, teleport w/ crew size + difficulty, retry once, skip late joiners), 4-player Heist place, save at end. Port crews.
2. Tower blockout: entrance, 1 wing (Data Vault, hackable lasers), guard set A, small + heavy loot, carry rules.
3. Enemies/alarm: sentry, camera, watcher drone; 3-tier alarm; cap + solo/duo scaling; noise/vision (§5h); downed/revive/Override/recall; fail rule.
4. Twist engine (param flips) + 2 twists (Blackout, Double Patrol).
5. Escape: 15-spot pool + guided parking + glows, one-seat Kart module from `Vehicles.luau` (SALVAGE), repo drones, sabotage, repair minigame, 8-10 block city blockout, EMP pursuit, ~75s gate timer, payout tiers, Credits saved. Test kart on phone early.
6. HUD §5e: minimap + pings, squad cards, context hold button, 4 colors, kart-status dot.
7. Owner visual review (§17) in parallel.
**Gate:** full run lobby->heist->escape->payout with 1-4 players (multi-client test + owner's friends); ~9 min run; 4-player phone perf; kart touch driving OK; tuning notes.

## Build 3 — Garage, Economy, Content, Alpha prep  (splittable at the gate into 3A+3B)
- **3A Garage** | §9 §10 §11: main hall, armory (gun wall, bench, wheel terminal), roll-up cutscene, queue pads, drone showcase (Coming Soon), multi-level modular kart track, skippable tutorial (NPC, white path), matte dark-wood look (Sept 30 override), streaming.
- **3B Economy** | §5g §5i §12: Credits/Glitch Coins, shop framework (port), attachments, 40-tier pass (free + premium), rotating bundles 199/499/999, crate w/ odds display + PolicyService gating, repair skip, idempotent receipts. Spin wheel per §5i: free 5-spin wheel + paid 12-segment wheel (199R, 5-pack 799R), pity + live odds UI, PolicyService fail-closed + earnable tokens, pop-up rules, kill switch; test via Player Emulator.
- **3C Content + polish** | §5c §8 §17: wings 2-3, remaining 4 twists, guard sets 2-3, baseline cosmetics, SFX on everything, settings (button layout), social (walk-up invites, mute/block/cooldown).
- **3D Alpha prep:** perf pass, telemetry (session length, 15+ min first sessions, run completion), known-issues list.
**Gate = v1:** alpha-ready for ~100 testers.

## After v1 (not in scope)
Kart upgrades, Robux parts shop (sidegrades/cosmetics only), drone skins, helicopter drop, best-lap board, Enforcer enemy, open beta, Season 1.

## Owner tasks
Trademark check; maturity questionnaire (Build 1 gate); phone tests each gate; friends test (Build 2 gate); veto [REC-AUTO]; visual review batches; start Discord now; confirm weekly hours; pick publish target.
