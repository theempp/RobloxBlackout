# Revision stage 2 — guns (owner review checkpoint)
Historical checkpoint; Oct 1 continuation supersedes its pending-authorisation statements. Current evidence: `phone-test-readiness.md`.
Status: local implementation complete; owner visual/feel/balance and phone acceptance pending. Build remains 3. Stages 3–4 and 3B–3D are not authorised. No uploads, publishing, pushing, paid generation or commits.

## Delivered
- Continued Claude's existing changes rather than replacing the weapon pipeline. Four locked v2 sheets traced into reproducible beveled Blender art and generated `src/shared/GunArt` data. All four sheet SHA-256 hashes match LOCKED.md.
- First-person art uses offline EditableMesh → MeshPart, one vertex-coloured mesh per Receiver/Mover/Mag group, freed on destruction; async equip ignores stale completed builds. Device failures use world primitives. Armory inspection uses detailed art when available. World LOD preserves Buzzline handle opening and Needlepoint scope tube/bell. Scatterpop/Rattler, all gun IDs/prices/ownership remain intact.
- Per-gun cadence, predictable recoil/recovery, aligned sights, eased ADS/FOV, draw/bob/sway/kick, moving slide/bolt and magazine reload. All tuning in Config. Full-viewport Needlepoint reticle hides the obstructing viewmodel; swap, menu, death and holster reset ADS.
- Server returns a unique defeat ID on the lethal hit. Client displays one ELIMINATED per remembered ID; pellets/multi-hit aggregate server-side. Damage/tag positions avoid the reticle. Pooled local/teammate shot sounds and bolt/reload/dry sounds respect SFX settings.
- Replaced temporary ZzTech staging spec with GunFeel behavior/render tests; added long-command helper, released probe's spare EditableMesh, expanded Fire tests and printed measured budgets through test.py.

## Balance proposal — not owner-locked
Needlepoint: **50 RPM / 1.2 s cycle, 95 body / 190 head damage before falloff, 5-round magazine, 2.8 s reload**. One shot per trigger press. Server allows small paid-back jitter slack, cannot bank idle bursts. This makes body shots nonlethal against a 100-health enemy and rewards a deliberate headshot. Folded bipod rest pose follows the approved side view.

## Verification (Oct 1, Codex continuation)
- Initial focused lobby Config/Fire/GunFeel/Guns: **417/417**; expanded tests followed.
- Full `python3 tools/test.py --only lobby,heist,multi`: **1240/1240 assertions**, lobby **765/765**, heist **446/446**, two-client **29/29**. Harness exit 1: known Roblox CoreScripts ChatScript SetCore registration error in multiplayer; no project assertion failed. Separate multiplayer rerun **29/29**, exit 0, no BC_ERR. Logs in ignored `build/test-{lobby,heist,multi}.log`; multiplayer log now contains rerun.
- GunFeel **29/29**: real mesh rendering, budgets, full-view scope/model hiding, zoom, menu/swap/death resets, rapid ADS toggles, Ranger sight alignment, duplicate elimination suppression/reticle clearance, respawn. Fire **64/64** includes deterministic bolt half/full-cycle and idle-burst rejection, server defeat IDs, repeated damage and new ID after target respawn. Existing client firing probe passed this run; no failing firing rerun hidden.
- Both shipping places rebuilt; `git diff --check` clean. Shipping smoke passed: lobby **17/17** client modules, heist **19/19**, no failed modules, both servers ready; heist running with kart/enemies present. Logs: `build/smoke-stage2-{lobby,heist}.log`.

### Measured rendered triangles
Stats.SceneTriangleCount delta, model visible versus removed, repeated three times. Counts include runtime carriers/root and vary slightly with surrounding scene; report maximum across focused/full runs. Caps FP ≤5000, world ≤1500.

| Gun | First person | World | Path |
|---|---:|---:|---|
| Dart-9 | 1746 | 204 | mesh / primitive LOD |
| Buzzline | 2578 | 432 | mesh / primitive LOD |
| Ranger | 2246 | 336 | mesh / primitive LOD |
| Needlepoint | 2136 | 648 | mesh / primitive LOD |
| Scatterpop | 168 | 168 | existing primitives |
| Rattler | 276 | 276 | existing primitives |

## Visuals and limits
- Review `assets/guns/v2/overlay-sheet.png`: locked sheet, 50% overlay, side, three-quarter, first-person renders. Blender source and generation scripts saved beside it. Existing Claude chat reports in-engine winding/colour review; Codex verified actual mesh render path/counts and inspected the saved overlay. New live screenshot attempt failed: computer-use Studio selection timed out; no new in-engine screenshot claimed.
- Audio is **built-in placeholder content**, with gun-specific volume/pitch. No final custom punchy recordings uploaded or listening/phone quality acceptance claimed.
- Offline EditableMesh works in local Studio tests; shipping-device/API availability and memory limits remain unverified. Unsupported devices retain functional primitive fallback. Fine grip textures and full PBR materials from concept art are simplified to matte vertex colours.
- No named-phone FPS, frame-time, latency, real touch/gamepad, live persistence or real teleport results. Background/multiplayer Studio render throttling makes its FPS invalid for phone acceptance.

## Owner playtest
1. `python3 tools/build.py`; open `build/lobby.rbxlx` in Studio, Play. Use the armory to inspect four revised guns. Test range loans exist only in test build (`build/test.rbxlx`); in a shipping local Studio server command bar use `local S=require(game.ServerScriptService.BlackoutCrew.ServerState) for _,p in ipairs(game.Players:GetPlayers()) do S.Weapons.loan(p,"needle") end` for a session-only Needlepoint test. Substitute dart9/buzz/ranger as needed.
2. Sustain automatic fire, tap semi-auto, empty/reload and swap quickly. Review recoil countering/recovery, slide/bolt/mag animation, sound levels and reduced-motion setting.
3. Needlepoint: scope in/out rapidly; swap, open menu and respawn while scoped. Confirm full scene, clean sight, restored FOV and reachable controls. Verify deliberate single-shot cycle.
4. Range/heist: body/head hits, multiple shotgun pellets and repeated target defeats; one server-confirmed ELIMINATED per defeat, damage text off centre. Try with 2–4 players.
5. Named low/mid-range phones: record FPS/frame time, stutter, aim responsiveness, mesh versus fallback, scope/touch safe areas, repeated swaps/armory opens and heat during sustained firing (targets ≥30/60 FPS). Review both lobby and heist.
6. Approve or revise gun art/feel, placeholder sound direction and Needlepoint cadence/damage together. Stage 3 (approved Vortex) needs a separate go.
