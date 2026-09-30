# SALVAGE — audit of ~/Desktop/roblox 1 (Directive Gray v0.3, cops-and-robbers) [audited Sept 30]
Read-only reference. Never copy `outputs/` (411MB of logs/rbxlx/png). No CLAUDE.md there; its rules live in README.md, docs/WORKFLOW_NOTES.md, docs/QA_REPORT.md (all digested below). Spot-check a file before porting.

## Port in Build 1
| Old file | Action |
|---|---|
| `src/shared/Rules.luau` (64L) `finite`, `clean`, `find`, `defaultProfile` | Port pattern. New schema: `schemaVersion, credits, glitchCoins, guns owned, attachments, karts, cosmetics, wheel{freeSpins,pity,season}, settings, receipts(cap 500)`. Validate everything from raw; whitelist ids against Config; server-only fields never client-writable. Test per field. Drop police/arrest. Keep `payout` crew bonus (8%/extra member, cap 24%) for Build 2. |
| `src/server/Profiles.luau` (62L) | Port ~as-is: `UpdateAsync` + session lock (180s expiry, 55s autosave, 3 retries, `BindToClose` 25s, kick on failed load/save, Studio = session-only). Store name -> `BlackoutCrew_Profile_v1`. Live persistence never verified: test on private published place only. |
| `GameService.luau` L275-287 `ProcessReceipt` | Port pattern: idempotent per `PurchaseId`, save before grant, roll back on failed save. Reuse for crate/wheel/pass in 3B. |
| `Config.luau` (83L) | Pattern only: one Config for all tunables; `id=0` product = hidden (use for wheel kill switch). |
| `tools/make_test_runner.py`, `tools/run-qa.luau`, `collect_qa.py` | Port harness pattern: tests concatenated into ModuleScript sources; run `Studio --task RunScript --localPlaceFile <abs .rbxlx> --runScriptFile <abs .luau> --outputFile <log> --quitAfterExecution`; results as `XX_JSON {..}` log lines; frame probe (skip 5s, sample 15s, mean fps + p95). Rename markers `BC_`. 2-client tests: `StudioTestService:ExecuteMultiplayerTestAsync(2,..)` (see `tests/Multiplayer.luau`). |
| `Main.client.luau` (1320L) | DO NOT port whole. Extract only: (a) helpers L20-47 (`make/corner/stroke/pad/tween` w/ reduced-motion); (b) rescale L1096-1113: `S=clamp(min(vp.X*.55,vp.Y)/340,.85,1.6)*(large 1.15)`, design units 800x340, `ScreenInsets=CoreUISafeInsets`; (c) action-button placement around jump button L246-290; (d) wheel drag-select math L768-830, rewrite for 5 fixed slots (2L/2R/1T). Rest is police/robber UI: discard. New client = small ModuleScripts, scoped init (Luau 200-register limit). |
| `Equipment.luau` `SHAPES` | Concept only: guns as welded parts (grip/receiver/barrel/mag/stock), muzzle along -Z. Rebuild as foam-tactical primitives within tri budgets (§6). |

## Defer
- Shop framework -> 3B. Crews -> Build 2. Both unused/untestable in Build 1.
- `Vehicles.luau` (220L) -> Build 2. Keep: 4-ray raycast suspension (spring 300, damp 22, rest 2.72), impulse lateral grip, speed-sensitive steer (32deg, /(1+(v/48)^2)), grade assist, occupant-validated input w/ 0.5s timeout. Refactor: coupled to `Config.Cars`, player attrs (Jail/Role/Crew), police visuals, Vesper art in ServerStorage, 4 seats. Target one-seat Kart module. Risk: server-owned physics (`SetNetworkOwner(nil)`) can feel laggy on phones: test early in Build 2. Old 36 driving tests are city-specific: rewrite.

## Do not port
`tools/package.py` (injects into `Graybox_V4_Two_Supercars.rbxlx`, the old city; generates `build-world.luau`): replace with Rojo (`rojo build`) if available, else minimal XML injector with no city. `World, Landmarks, Masks, GameService` (rest), city/ramp/highway tests, `work/`, `outputs/`.

## Gotchas (paid for in v0.3)
- Luau 200-local-register limit killed the monolith client. Use scoped builder functions; shared services in one table. A server-only pass does not prove the LocalScript compiled: add a client-ready signal + UI probe.
- Touch targets >=44px physical after scaling: round UP; entrance animations can shrink them; test visible size.
- Hold buttons must follow the touch's own End/Cancel (`MouseButton1Up` never fires if the thumb slides off).
- Roblox default UI: player list off, chat docked bottom-left, jump-button spot overridden; respect safe insets. Opening a menu suppresses contextual actions and firing.
- Avoid rare Unicode glyphs in HUD (use emoji/images). Use only known-good asset ids (a missing sound id broke slide sfx).
- Always `--quitAfterExecution`; stuck Studio procs halved fps once. Kill stragglers before fps runs.
- Studio = session-only profiles by design; never enable Studio API access to test saves.
- Old ~60fps figures = Mac Studio only. Phone, 20-player, latency, live save, reconnect: never tested.
- Phone preview without publishing: Studio Test -> Device (iPhone XR 896x414).

## Old project facts
Private place 85367345143911, universe 10768548489 (phones+tablets on, Team Create off). Blackout Crew publish target = [OPEN owner]; [REC] reuse this private place for dev, new store name isolates data.
