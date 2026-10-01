# Revision stage 1 — locker room, personal armory, queue pads (review checkpoint)
Status: delivered locally. Owner moved on to stage 2 (guns) on Oct 1; phone playtest still pending, [REC-AUTO] proposals stand unless vetoed. Build stays 3; 3A still awaits owner acceptance; 3B–3D not authorised. Nothing uploaded, published, pushed or generated.

## Delivered
- **Locker room** (open room east of the main hall, 7 lockers; centre one = "YOUR LOCKER"). Prompt → ~1.2 s camera push-in while the locker door swings open; skip with SKIP, a tap or any key; Back/B closes; reduced motion = instant. Screen: centred live preview (your own avatar clone on a yellow-rimmed stage, drag / < > / right stick to turn), Outfit · Disguise · Mask grids, APPLY / CANCEL, honest save line (Studio: "SESSION ONLY").
- **Cosmetics** (`Config.Cosmetics`, placeholder matte primitives; outfits recolour body + hide avatar clothing). Profile schema 3 → 4 adds validated `cosmetics.equipped`; old saves keep everything. Server checks range, ids, slots, ownership (all-or-nothing). `Appearance` re-applies on spawn, avatar load and heist arrival. Disguises are cosmetic only (no stealth hooks).
- **Personal armory** (terminal or bench open one panel). LOADOUT: owned + locked blasters, slots 1–3 (swap / remove, last blaster kept), 4–5 Coming Soon. BENCH: owned-attachment chips, gun preview, stat widget SAVED / NEW / CHANGE from `GunStats.resolve` via new `StatSheet` (rounded mag, capped range/falloff, nested recoil; zoom marked as tradeoff). Preview/cancel never touch saved gear; APPLY = one acked, rate-limited request; rejection or no ack → saved setup shown again. Wheel hub now shows resolved stats.
- **Queue pads**: two raised adjacent platforms flanking the departure lane at the roll-up door, ramps, 4 matte status circles (empty / taken / ready), backboards (heist, mode, n/4, countdown, names + READY) and overhead labels. Pad HUD reads your READY state back from the server; Enter / R1 / button. Squad rules, countdown, leave/disconnect and teleport retry unchanged (`Lobby.drop` extracted for disconnects). Departure cutscene now drives down the lane.
- **Input**: `Menus` makes menus exclusive; while open: no firing/context actions, prompts off, touch fire/gear/tutorial hidden, crosshair hidden; close / skip / death / respawn restore camera, controls and prompts. Touch targets ≥ 44 px inside safe insets; gamepad gets first-button focus.

## Proposed for owner veto ([REC-AUTO])
Starter catalog: free Crew Coveralls, Night Shift, Courier, Bandana, Foam Visor; locked (shop 3B, no prices): Track Suit, Gala Black, Maintenance, Night Guard, Robo Faceplate, Domino. Pad spot (door lane) and locker-room spot (east of hall). Outfits hide avatar clothing ("Own look" is default).

## Verification (this session)
- Focused lobby run **276/276**. Negative control: 4 planted bugs (preview leak, locker close, circle colours, ownership check) each failed their targeted checks (**131/142**), then reverted.
- Full regression **1114/1114** (run twice; second run after the crosshair/header tweaks): lobby 639, heist 446 (incl. new Cosmetics 5/5), two-client 29/29. The second two-client run also logged the known Roblox CoreScripts chat-registration error (`ChatScript` SetCore, engine code, seen at the 3A gate), so the harness marks that run unclean. Firing probe passed both runs (previously flaky). Crosshair-hide check added afterwards; affected specs (Armory, Locker, Client, Hud) rerun **123/123**.
- Shipping smoke: lobby client **16/16**, heist **18/18** modules, servers ready. Studio CLI FPS is throttled → not phone evidence.
- Screenshots (Studio Play, background capture): `gates/revision-stage-1/` queue-overview, queue-on-pad (pad loop paused for the photo, so its countdown reads 0 s), locker-preview (taken before the crosshair-hide fix), armory-bench, armory-loadout. Refs: `refs/revisions/locker-room-reference.jpeg`, `heist-queue-reference.jpeg`.
- Budgets: locker room 22 blocks (~0.3k tris), pads 20 parts (~0.9k tris), cosmetics ≤ 6 massless pieces / player (≤ ~0.2k tris). One ViewportFrame each, only while the locker / armory is open. Boards: 2 local SurfaceGuis, text at 4 Hz, no per-tick remotes.

## Limits / not verified
Phones, real gamepad and real touch (owner). Live DataStore persistence and real lobby → heist teleport (places = 0; covered only by memory-store hand-off + heist apply specs). The ProximityPrompt click itself (tests fire the same server event). Nobody owns attachments until 3B, so the bench shows only locked chips in shipping. Primitive cosmetics can clip with avatar hats / dynamic heads; layered clothing stays visible. During capture the Roblox in-game menu opened once from outside input (not game code).

## Owner playtest
1. `python3 tools/build.py`; open `build/lobby.rbxlx`, Play (Studio profiles reset each session).
2. Locker (east of hall): prompt → watch / skip intro; try Outfit / Disguise / Mask, turn the preview, CANCEL, APPLY. Respawn (Esc → Respawn): look stays. Toggle Reduced motion (P) and re-enter.
3. Armory terminal/bench: move blasters between slots 1–3, remove, try slot 4–5 teaser. Bench: to test previews, switch the Studio command bar to **Server** and run `local S=require(game.ServerScriptService.BlackoutCrew.ServerState) for p,d in pairs(S.profiles.loaded) do for _,a in ipairs(require(game.ReplicatedStorage.BlackoutCrew.Config).Attachments) do d.attachments.owned[a.id]=true end S.pushProfile(p) end` (session only), then preview, CANCEL, APPLY and check SAVED / NEW / CHANGE.
4. Pads: step on, READY (button / Enter / R1), step off (countdown cancels), 2–4 players with friends; watch boards and circles.
5. Phone (low + mid): touch sizes, menus over controls, back/close, death while a menu is open, FPS (≥ 30 low, 60 mid). Gamepad: A select, B back, R1 ready.
6. Reply with fixes or vetoes, or say go for the gun stage.
