# Blackout Crew — Claude Code revision handoff

Copy the prompt below into Claude Code in `/Users/zozo/Desktop/Blackout Crew`. Owner authorized local stage 1 implementation on Oct 1. Locked order: locker/armory/queue → guns → approved Vortex → city. Stop for owner review after each stage; subsequent stages require the next go-ahead.

---

You are the implementation agent for Blackout Crew, a phone-first Roblox co-op heist game. Codex reviewed and consolidated the locked revision plan on October 1, 2026. Start local stage 1 now: locker room, personal armory and queue presentation. Preserve approved art and game rules. Later stages are guns, approved Vortex, then city, each with an owner review checkpoint.

## Read and establish the starting point

1. Read the nearest AGENTS.md if present, `CLAUDE.md`, `BUILD_PLAN.md`, `gates/build-3.md`, and `SALVAGE.md`. Read only relevant DIRECTIVE_GRAY sections: §3/3b, §5b–5f/5h, §6–11, §15–17, plus its top-level visual override. Economy sections only if 3B is separately authorized.
2. Read `refs/revisions/NOTES.md`, `OCEANSIDE_CITY_CONCEPT.md`, and `REVIEW.md`. Inspect the referenced images and approved kart manifest. Older instructions naming Codex describe the previous executor; Claude Code now performs implementation. Historical Build 1 HANDOFF_PROMPT is not this assignment.
3. Inspect the working tree before editing: it contains substantial existing uncommitted work. Preserve it; do not reset, delete, overwrite or commit unrelated changes. Keep `~/Desktop/roblox 1` read-only. Do not use agents/skills without the project-required owner authorization.
4. Current build is 3, with 3A awaiting owner playtest; 3B–3D are pending. Stage 1 local revisions are authorized; ask one batched round only for real blockers. Do not treat the art locks or this file as permission to cross a gate. Propose small reviewable stages, then implement only the authorized stage and stop at its review gate.

## Exact approved inputs (relative to project root)

- Locker room: `refs/revisions/locker-room-reference.jpeg`.
- Queue: `refs/revisions/heist-queue-reference.jpeg`.
- City: `refs/revisions/OCEANSIDE_CITY_CONCEPT.md`; `refs/revisions/city/IMG_7153.jpeg` through `IMG_7158.jpeg` (six images).
- Gun lock/hashes: `assets/guns/concepts-2026-09-30/LOCKED.md`; exact sheets `dart9-v2.png`, `buzzline-v2.png`, `ranger-v2.png`, `needlepoint-v2.png` in that directory. Older sheets are historical. Concept art is not a finished mesh or exact engineering drawing.
- Kart: `assets/karts/vortex/revisions/approved-reference-cockpit/APPROVAL.json`; verify its file hashes before use. Source `blackout_vortex.blend`; exports `export/blackout_vortex.fbx`, `export/blackout_vortex.glb`, `export/vortex_shaped_body.fbx`, `export/manifest.json`. Review `export/cockpit-preview.png`, `preview.png`, `side-preview.png`, `rear-preview.png`, and snapshot `cockpit-reference.jpeg`. Owner reference also at `refs/kart/vortex/cockpit-reference.jpeg`.

All revision reference paths above resolve under `/Users/zozo/Desktop/Blackout Crew/`. Do not substitute later working-file drift for the approved snapshot.

## Implementation requirements and acceptance

**Locker / personal armory / queue**
- Build the short locker entry with skip/reduced-motion support, centered live character preview and owned outfit/disguise/mask choices. Adapt reference colors to the established dark-wood garage and warm-paper UI. Disguises are cosmetic; propose the initial catalog rather than inventing monetization or stealth effects.
- Server validates owned/compatible cosmetic equips; migrate equipped cosmetic fields safely, preserve existing profile data, apply on respawn and arrival in the heist. Show save failures honestly. Studio profiles are temporary; true persistence requires later owner-approved private-place testing.
- Extend `GarageClient`, server `Garage`, `Rules`, `Profiles`, `Config`, `GunStats`, `Weapons` and existing wheel flow. Do not create a second inventory/loadout service. Personal inventory must not expose or alter another player's items. Preserve three usable slots and two Coming Soon slots; purchases remain 3B.
- Gun/attachment inspection shows current versus proposed final values and signed deltas with units. Use `GunStats.resolve` for both sides, including rounded magazine size, capped range/falloff and nested recoil. Clearly label tradeoffs; more zoom is not universally better. Preview/cancel must not mutate equipment. Apply/remove/swap receives server acknowledgement and rejection recovery; whitelist IDs, compatibility, ownership and interaction range, and rate-limit requests.
- Queue presentation uses adjacent raised standing pads, clear labels, player names, occupancy and ready feedback. Use flat contrasting materials to respect no-neon. Reuse `Lobby`, `Queue`, `Crews`, `Teleport`: four players maximum, existing difficulty/party rules, countdown cancellation, leave/disconnect/party change, failed teleport recovery. Tutorial NPC never consumes a live slot.
- Menus suppress firing/context actions and restore input/camera on close/skip/death. Touch targets >=44 physical pixels, safe insets, two-thumb access, keyboard/gamepad fallback.

**Four approved gun assets and shooting**
- Replace art for existing IDs `dart9`, `buzzline`, `ranger`, `needle`. Preserve all six existing guns, including Scatterpop (`scatter`) and Rattler, their ownership, pricing and unlock rules. No approval exists for replacement art for the remaining two.
- Preserve matte charcoal/warm-grey family, orange foam muzzles, swappable engraving plates and robot/foam non-graphic tone. Inspect `GunModel`, `ViewModel`, `GunClient`, `CameraRig`, `Recoil`, `Weapons`, `Targets`, `Fx` and `Hud` before modifying. No parallel weapon pipeline.
- Give each approved gun distinct responsive cadence, predictable recoil/recovery, aligned sights, ADS transitions, motion and sound. Tune in Config. Owner locked Needlepoint as a deliberate single-shot bolt-action sniper with a smooth bolt cycle and full-view scope. Propose cadence/damage together for owner balance review in the gun stage; preserve its ID, ownership and price. Folded bipod can be proposed as the rest pose.
- Needlepoint ADS shows the zoomed scene and centered reticle across the full active play view, without a small circular image surrounded by black. Hide obstructing viewmodel pieces; preserve controls and safe areas. Reset scope on swap/death/menu entry; rapid toggles must not leave stuck zoom or camera state.
- Keep server-authoritative rate/ammo/range/line-of-sight checks, predicted/confirmed hit feedback and damage tags. Add one clear ELIMINATED per server-confirmed enemy defeat, deduplicated across pellets, multi-hit and repeated events; no client-predicted kills. Tags must not obscure the reticle.
- Budgets: <=5k first-person gun triangles, <=1.5k world gun triangles; measure rather than infer from source appearance. No paid generation without approved plan and model cost quotes.

**Approved Vortex import**
- Production `assets/roblox/VortexKart.rbxmx` still has the older cockpit. Approved local model: 117 named pieces, 32 shaped meshes, 18 door pieces. Verify manifest and actual import; old 121/125 counts are historical. The offline box proxy is not acceptable final curved art.
- Preserve continuous double-curved front glass, its shortened position, rounded side windows/pillars/roof, intake, slim seals, shaped doors/cowl, black finish and fixed front windshield. Keep named wheel/steering/chassis pivots and butterfly-door pieces.
- Inspect importer/build embedding, `KartModel`, `KartVisuals`, `KartPhysics`, `KartClient`, `GarageKarts`, heist `Karts`. Preserve shared suspension, steering and replication. Verify scale/orientation, clearance/auto-close, wheel articulation, collision, driver-only controls, cockpit/chase views, reset and multiplayer.
- Tinted glass must allow readable driving from inside. Reconcile existing Neon/LED behavior with no-neon/no-emissive styling. Preserve exterior silhouette while meeting <=8k kart triangle target; flag a measured conflict before materially simplifying approved geometry. Roblox uploads/account permissions require owner approval; do not silently upload.

**Oceanside city and time of day**
- Evolve the existing heist map into the locked fictional oceanside grid: parallel long/wide boulevards, cross streets/alleys, layered towers/landscaping, circular and hexagonal landmarks, beachfront/harbor, bridge across the bay, winding uphill tree-canopy route to safety. Port Meridian is a placeholder name.
- Concentrate believable detail near players; reusable facade kits, streaming, distance simplification, restrained ambience. Suggest alive-feeling traffic/boats without adding a new full simulation or obstructing the kart route.
- Preserve tower-heist objective flow, 15-spot parking pool, loot/carry, drones/pursuit, escape timer/payout and lobby return. Measure route time with realistic kart speed and multiplayer; do not silently lengthen timers or remove consequences to fit new geography. Ensure streaming at driving speed never removes needed road collision; validate water/fall recovery and AI paths/line of sight.
- Server controls time of day consistently within each heist instance, including city/bridge/safe side. Propose cycle length/start selection in Config. Avoid competing Lighting writers; reconcile Blackout twist and restored lighting. Test daylight, sunset/night and cycle boundaries while preserving stealth rules unless separately approved.
- Owner approved Oct 1: use a small, performance-tested number of practical city streetlights casting road light pools. This narrowly supersedes the older dynamic-light ban for streetlights; cap/cull active lights and verify nighttime driving performance. No neon/emissive styling remains locked.
- Owner chose Oct 1: reserve a giant-yacht harbor berth and sightline only at launch; do not build the yacht exterior. The playable yacht heist is version 2, first major update. Do not implement yacht interiors/objectives/security/rewards now.

## Validation, reporting and stop

Use existing harness: `python3 tools/build.py`; focused suites via `python3 tools/test.py --only lobby,heist --spec <existing relevant specs>` (choose valid names); final applicable regressions via `python3 tools/test.py --only lobby,heist,multi`. Add meaningful behavioral tests for new systems: ownership rejection, preview isolation/stat accuracy, cosmetic migration, queue lifecycle, elimination deduplication, lighting/twist precedence and escape integration. Include client-ready/UI checks; server passes alone do not prove the client boots. Build and smoke-check both shipping places.

Report exact pass/total and failures; historical gate numbers are not current results. Existing firing probes have been flaky: report failed runs and reruns separately. Document blocked imports, save/teleport checks and device tests without claiming completion.

Owner phone acceptance: sustained firing, rapid ADS/scope and swaps; touch access and menu/camera restoration; cosmetic/loadout transfer; 1–4 player queue/heist/escape; kart doors/cockpit/terrain; streaming bridge route at speed; daytime/nighttime. Targets >=30 fps low-end, 60 mid-range; record frame time and stutter/input response on named devices. Throttled/background Studio FPS is invalid evidence.

At the authorized stage gate, record delivered changes, current test summaries, screenshots/reference comparisons, known gaps, measured budgets and owner playtest steps. Keep current build 3 until the owner advances it. Do not start 3B–3D, publish, upload, spend, push, or message other chats without the applicable owner authorization. Stop for owner review.
