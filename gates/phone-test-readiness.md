# Blackout Crew — iPhone 16 Pro test handoff
Oct 1, 2026. Candidate published under the owner's explicit approval to create a new private two-place test experience. No commits, pushes, paid generation or external messages performed. Existing gun/stage-1 changes preserved. This is a private playtest candidate; the ~100-tester alpha gate remains open.

## Current local evidence
- Full Studio regression: **1,444/1,444**, exit 0: lobby **866/866**, heist **549/549**, two-client **29/29**. `build/regression-build3-final.log`. No project or engine error reported in this run. Multiplayer rendering was throttled; CLI FPS is not phone evidence.
- New Build3 checks **68/68**, Economy **30/30**, City **23/23**. Coverage includes save rollback/retry/idempotency, migration and all 40 free claims, paid-policy fail-closed, receipt entitlements without credit power, consented squad queueing, bounded audio, shop open/close, top kart spread and elevated gate bounds.
- Vortex full-run checks **23/23**, source **6,616 triangles**, measured rendering **6,252**, all **117 names** retained. Original source evaluated **54,024**. Approved reference hashes verified; the source snapshot is unchanged. Final focused Vortex **25/25**, including actual curved trim groups turning off/on, exit 0: `build/regression-vortex-final.log`.
- Shared physics route simulation **3/3**: 55.6 simulated seconds, minimum height 1.43 studs. Human driving, pursuit and EMP effects remain unmeasured.
- GunFeel **29/29** with gun and kart fixed-size mesh caches loaded together. Four detailed first-person weapons rendered within 5,000 triangles; world LOD within 1,500. Allocation failure in the earlier full run was fixed and independently rerun **156/156** before this clean full run.
- Earlier full regression was **1,426/1,429**: two gun mesh-allocation failures plus one stale starter-kart expectation. Those failures are retained in `build/regression-build3-first.log`; the final run supersedes that evidence.
- Final shipping smoke passed: lobby **21/21** client modules, heist **21/21**, both servers ready, no failed modules. Garage/queue and running heist/kart/enemies present. Logs: `build/smoke-build3-{lobby,heist}-summary.log`. Build label: `build3-phone-candidate`.
- Final artifact hashes: `phone-candidate-manifest.json`, including both shipping files and the derivative. All 17 original approval hashes reverified. Python compilation and `git diff --check` passed.

## What is playable
- Approved curved Vortex derivative in both places; wheels, steering, doors, cockpit and matte light controls retained. Starter/top tiers share art; earned top tier has fixed +8% speed/+4% acceleration, with no paid power.
- Oceanside city blockout, bay/bridge/uphill escape and safe garage, fall recovery, minimap route, seeded day/night and bounded practical lights. One lighting controller applies Blackout overrides.
- Credit gun/attachment purchases, 40-tier free/premium claim framework, five free seasonal spins, earned-token cosmetic spins with live odds/no duplicates/pity, server-authoritative repair skip and rollback-safe saves.
- All six twist parameters, three guard routes and three same-footprint vault variants. Bullion pressure plates and prototype fall-drop behavior. These are modular variants, not three finished architectural wings.
- Session squad invites/accept/decline/leave with range, cooldown and invite mute/block. Bounded placeholder world/UI sounds and local aggregate run/session counters.

## Explicit gaps before alpha acceptance
- Paid products, paid random items and purchase prompts are disabled; all production product IDs are zero/absent. Policy checks fail closed. Bundle/crate cards and the 12 cosmetic masks are test placeholders; full approved cosmetic sets, final art, wheel animation and Player Emulator validation remain unfinished.
- City and wing art remain primitives. Yacht berth is reserved. No final custom audio or owner visual/feel/balance acceptance. Social mute/block affects invites in this session, not Roblox platform communication settings; no platform friends browser.
- Telemetry aggregates per-place sessions only; cross-place first-session retention and 100-tester evidence are absent.
- EditableMesh device allocation/availability, phone FPS/thermal stability, touch layout, four-player pursuit, full run duration, live DataStore saves, receipt retries and reconnects still need published testing. Primitive fallback exists but is a visual degradation.
- Both published place IDs are configured. Real lobby→heist→lobby teleport and phone rendering still need the owner device test. No phone success is claimed.

## Published private test — owner approved
- Owner account: Actuallytherealzo. Experience/universe: **10768927445**, **Blackout Crew Phone Test**, Access and Audience Reach verified Private in Creator Hub.
- Start/lobby place: **102861732553937**, published **version 3** (8:41 PM EDT). Heist: **125919969708119**, **Blackout Crew Phone Test — Heist**, published **version 3** (8:39 PM EDT). Published-only version history verified for both.
- Both Config IDs set, shipping files rebuilt. Linked shipping smoke: lobby **21/21**, heist **21/21**, servers ready, no failed client modules. Logs: `build/smoke-linked-{lobby,heist}-summary.log`.
- Heist capacity **4**, direct access restricted to secure server teleports within this universe. Lobby capacity remains Roblox's default 50. Same-universe teleports do not require enabling third-party teleports.
- Owner completed ID verification personally; **Allow Mesh / Image APIs** enabled, saved and verified after reopening settings. Team Create and optional AI data sharing disabled at creation. HTTP requests, Studio API access, third-party sales/teleports/assets remain off.
- Play on the owner account: https://www.roblox.com/games/102861732553937/Blackout-Crew-Phone-Test . The owner page exposes Play. Desktop browser launch was attempted, but no Roblox desktop client opened; no live session, teleport or device performance is claimed.
- Creator Hub: https://create.roblox.com/dashboard/creations/experiences/10768927445/overview . Friends access is a separate limited-Playtesters setup, not included in this owner-private publication.
- Updated artifact hashes: `phone-candidate-manifest.json`. Original 17 approval hashes still match.

## iPhone 16 Pro owner checklist
1. Sign into Roblox on the owner account and launch the private start place in landscape. Complete or skip onboarding; check safe insets, menu scrolling, ADS/swap, aiming and weapon visibility.
2. Garage: drive ramps/crossover, brake/reverse, exit/re-enter; open/close doors, lights and cockpit view. Swap all guns while several karts are visible. Record missing curved meshes, crashes or severe frame drops.
3. Shop: buy with earned Credits, equip at armory, claim an unlocked free tier, try free/earned spins and check odds. Confirm paid actions remain unavailable; verify reconnect retains purchases/claims through the live save path.
4. Queue READY and check real teleport, heist, loot, sabotage/repair, EMP pursuit, bridge/uphill gate, payout and return. Report route time and whether the 75-second escape feels fair. Repeat solo, then 2–4 players.
5. Check day/night and Blackout, water/fall recovery, squad acceptance and declined/blocked invitations. Play at least 15 minutes; record device warmth, FPS if available, rough run duration and touch frustrations. A desktop pass does not establish a 60 FPS phone result.
