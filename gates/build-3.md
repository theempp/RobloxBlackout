# Gate — Build 3A: garage, kart and onboarding
Historical checkpoint; Oct 1 continuation supersedes its pending-authorisation statements. Current evidence: `phone-test-readiness.md`.
Status: ready for owner playtest of the 3A blockout. Build 3B–3D remain pending. Current build stays 3.
Revision stage 1 (locker room, personal armory, queue pads) is built on top of 3A: see `revision-stage-1.md` (awaiting owner review).

## Delivered
- Resumed Claude's uncommitted RAZOR integration: XML/PBR template support, proportioned fallback, animated wheels/steering, shared driver/server suspension, landing damping and corrected ownership transitions.
- Matte dark-wood garage blockout: tall main hall, open armory, yellow roll-up departure, queue pads, Coming Soon drone and a connected crossing track at 0/10/18 studs. Free driving has no timer/reward.
- Owned-gun loadout and attachment bench with server ownership/range validation. Purchases belong to 3B. Shipping places no longer loan paid guns; test range remains in test builds.
- Skippable onboarding: free gun → scripted guide conversation → practice squad → personal kart → real queue READY. The NPC uses invite/accept rules but never occupies a live teleport slot. Completion migrates into profile schema 3.
- Owner-approved warm paper panels, dark outlines and bright flat buttons across menus; compact heist chips. Full shop cards/3D preview remain 3B.

## Verification
- Latest full run: **948/951**. Three existing client firing-probe checks failed intermittently; an unchanged Client + Garage rerun passed **51/51**. Earlier complete lobby run passed **523/523** (before adding two passing menu checks). Treat the CLI firing probe as flaky, not a clean 951-check single run.
- Heist **397/397**, including suspension **29/29**; two-client **29/29**. One earlier Studio attempt connected only one client; standalone rerun passed.
- Both shipping places boot: lobby **13/13**, heist **17/17** client modules; no shipping range/paid-gun loans. XML/PBR importer checks **7/7**; Python compile and diff checks pass.
- Simulated landing: 3.80 kart-g, settles 0.60 s; no pogo/bottoming. Background Studio throttled rendering, so phone FPS remains unknown.

## Remaining / owner checks
- The Blackout Vortex now replaces the RAZOR placeholder in both places. Its 121-piece offline RBXMX is playable; the editable Blender source and FBX/GLB are under `assets/karts/vortex`. The optional uploaded-mesh appearance, phone FPS and player feel remain unverified.
- `Config.Places` is still 0. Publishing, real teleport, live persistence and reconnect remain unverified; no publishing or pushing was performed.
- Garage/guide/drone are primitives; departure is a short local single-kart cutscene. Tutorial <90 s and track lap ~25–30 s are targets, not measured user results. SFX/content/economy/pass/wheel/social/alpha telemetry remain 3B–3D.
- Earlier phone tests, friends test and maturity questionnaire are still outstanding. No asset generation or paid services used. Existing concurrent gun-asset work was preserved.

## Play this gate
1. `python3 tools/build.py`; open `build/lobby.rbxlx` in Studio and Play. New Studio sessions use temporary profiles, so onboarding repeats.
2. Follow the white arrows: equip Dart-9 at the wall, talk to the guide twice, DRIVE your kart, reach a HEIST pad and READY (Enter on keyboard). Skip via button or Backspace; P opens settings.
3. Drive the marked track entry, ramps and crossover. Check steering, reversing, bumps, falling/reset, exit and re-entry. Try server physics via `Config.Kart.ServerPhysics` for comparison.
4. At LOADOUT, move Dart-9 between slots 1–3. The bench explains the empty owned-attachment inventory; paid items remain unavailable at this gate. Check the departure and reduced-motion option.
5. Open `build/heist.rbxlx` for a full run while unpublished. Test 1–4 players and low/mid-range phones: touch targets, kart feel, guide/track usability, tutorial time, FPS (≥30 low, 60 mid).
6. Report problems and phone results, provide optional Vortex mesh/publish IDs when ready, then say go for 3B.

## Vortex vehicle update
- Added a single-seat metallic-black Vortex with white LEDs, upward-opening doors, 20 moving control-arm links and a cockpit steering wheel. Driver controls: L / O / V or the LED / DOOR / VIEW touch buttons; gamepad D-pad up / down / right.
- Blender FBX reimport verified all 125 named pieces and wheel pivots. Both shipping places booted cleanly. The latest swept-canopy revision passed focused Studio checks: heist Kart/Vortex **70/70** and lobby Garage **41/41**. The earlier full suite reached **975/975** before this visual revision; the first two-client process also logged a Roblox CoreScripts chat registration error, then its isolated rerun passed **29/29** without it. Studio CLI rendering was throttled, so its FPS numbers are invalid for phone targets.
