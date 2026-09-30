# Gate — Build 1 (Foundation + Gun Feel)
Status: built, awaiting owner phone test + "go". Git repo initialised; 6 commits. Build 2 not started.

## Tests — `python3 tools/test.py` (one Studio Play session): **419/419**
Config 153 · Profiles/clean 62 · Receipts 15 · Fire validation 55 · Guns (stats, sidegrades, recoil, models, tris) 80 · Wheel 24 · HUD/layout 17 · Client (compile probe + end-to-end fire) 13.
Negative controls fail when they should (failing spec, syntax-error spec, server rejecting all shots). Shipping place smoke (`tools/smoke.luau`): server ready, client 9/9 modules, gun equipped. Profile lock logic runs against an in-memory store only: **no live-persistence evidence**.

## Perf
Mac Studio CLI: 60 fps / p95 17 ms when not throttled. This is not a phone number (the harness flags throttled runs as invalid). Blasters are ≈260 estimated tris each (budget 1.5k world / 5k first-person); estimates come from primitive counts, not measurement. StreamingEnabled is on (asserted by a test). Effects are pooled, emissive only, no dynamic lights. Each shot sends 1 remote event of ~40 B; other players' tracers use an unreliable event; every client remote is rate-limited per player. **Phone fps is unknown until you measure it.**

## Decisions made (veto any)
1. **First-person camera.** The brief doesn't say; §6's first-person gun budget and all 3 feel refs point to FPS.
2. Rojo isn't installed, so the layout is Rojo-compatible and `tools/build.py` builds it. `brew install rojo` is a drop-in replacement.
3. The client sends aim only. The server applies deterministic seeded spread and the client predicts the identical tracer. The client's ADS flag is trusted for spread only.
4. Hit markers: grey (predicted) instantly, then white/yellow/red on server confirm. Damage numbers come only from the server.
5. Recoil recovery returns only the climb you didn't counter, so it never overshoots. Aim assist is slow-down only, touch and gamepad only.
6. Wheel: the 3 usable slots are top-left, top and top-right; lower-left and lower-right are Coming Soon.
7. Range: any of the 6 guns can be loaned at the rack behind spawn (no profile write). Slots 2-3 are pre-loaned with Buzzline/Ranger. Teammates don't block shots.
8. Placeholder names: Dart-9 (free), Buzzline 1k, Ranger 3k, Scatterpop 6k, Needlepoint 10k, Rattler 15k.

## Gaps
- The viewmodel has no arms. The third-person gun is a fixed hip pose with no aim animation.
- No gun audio yet: §8 is later and there are no approved assets.
- Attachments have a data model, server/client resolution and tests, but no UI to own or equip them (3B).
- Live DataStore saves are untested. That needs a published private place, and the publish target is still [OPEN].
- Untested by me: phone fps, touch feel, and multi-touch (move + aim + fire together).
- The sentry dummy tracks you but doesn't shoot. The contextual action button and Sneak toggle are Build 2.

## Owner phone test
1. Run `python3 tools/build.py`, then open `build/place.rbxlx` in Studio.
2. **Real phone:** publish to a private place (rec: reuse 85367345143911) and join on a low-end phone and a mid-range phone. **Fallback without publishing:** Studio → Test → Device → iPhone XR 896×414 → Play. This emulates touch only and gives no perf numbers.
3. Controls: left thumb moves; drag the right half to aim (dragging from FIRE also aims). Also try ADS, R (reload), JUMP, and GUN: tap swaps to the last gun; hold, slide and release to pick; slots 4-5 should say Coming Soon. Walk up to the rack and tap a prompt to try each gun.
4. Gun feel: spray Ranger/Rattler at the 25-50 stud dummies while dragging down to counter the recoil. Is the recoil too strong or too weak, per gun? How do hit markers, damage numbers and ADS zoom feel?
5. ⚙ Settings: toggle aim assist on/off while tracking the strafers. Press EDIT to move/resize buttons (−/+), then OK.
6. Perf: ⚙ → Performance overlay ON, then ⚙ → RUN benchmark (hold still 20 s). Note meanFPS and p95 for each phone. Targets: ≥30 on low-end, 60 on mid-range.
7. Fill in the Roblox **maturity questionnaire** (Creator Hub → experience → Questionnaire) for this prototype. Target: Mild.
8. Decide: keep or adjust the foam-tactical look.

**Reply with:** phone models + meanFPS/p95 each, feel notes per gun, questionnaire result, any vetoes, then "go".
