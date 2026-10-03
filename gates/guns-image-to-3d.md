# Guns: Meshy image-to-3D (untextured) — handoff, Oct 2
State: concepts for all 4 classes **owner-approved**; originals byte-intact in `assets/guns/<class>/source/*-gptimage2.png` (pistol P1P2, ar A1A2, sniper S1S2, shotgun G1G2). Meshy balance **1,042**.
Owner override: **no orange anywhere** (tips, AR strip/charging handle) — paint black in Blender; untextured 3D ignores it.
Inputs for 3D: each sheet holds 2 variants, so they were split into single-gun square crops (white bg, local PIL, no credits): `assets/guns/{pistol,ar,sniper,shotgun}/{P1,P2,A1,A2,S1,S2,G1,G2}-crop.png`.

## Next step (new chat)
1. **Ask owner first (batched, once):** "all 4 guns" = 4 runs (one variant per class — which: P1/P2, A1/A2, S1/S2, G1/G2?) or all 8 variants? Quote: Meshy **T2 Smart Topology, untextured, 5 credits each** -> 20 (4) or 40 (8). Get explicit "go N".
2. Via Claude in Chrome (owner's logged-in Meshy, Model > Image to 3D): upload the crop, Smart Topology, **Meshy T2**, texture **off**, poly target ~1500 (100–4000+ same price). Verify price on screen = 5 before each Generate; one at a time.
3. Review geometry in Meshy viewer (screencap -> `assets/guns/<class>/3d-<ID>-screencap.png`). Owner approves before any download/texture spend.
4. Download GLB/FBX of approved -> `assets/guns/<class>/source/` byte-intact; log model, mode, poly target, credits, balance in `<class>/NOTES.md`.
5. Then Blender (Codex or `bl_*`): clean, budget, rename pieces, black-out orange parts, export per CLAUDE.md asset rules.
Meshy UI gotchas: page flips to Viewer after Generate — switch back to Toolkit before editing; prompts cap at 800 chars.

## Done Oct 2–3 (steps 1–3)
Owner chose **all 8**. All 8 generated: T2 Smart Topology, untextured, poly 1500, 5 cr each = 40. Balance 1,042 -> **1,052** (an unexplained +50 grant appeared after run 1; per-run log in `assets/guns/pistol/NOTES.md`).
Review caps: `assets/guns/3d-all8-grid-screencap.jpg` (all 8), `pistol/3d-P1`, `sniper/3d-S1`, `shotgun/3d-G1`, `shotgun/3d-G2` `-screencap.jpg`. Meshy grid order newest-first: G2 G1 S2 S1 / A2 A1 P2 P1.
**Next:** owner picks keepers in Meshy (rotate in viewer) -> step 4 download GLB+FBX to `<class>/source/`. No texture spend.
Gotchas added: narrow Chrome window forces Meshy mobile layout (Toolkit/Viewer/Assets slide panels); a job finishing clears the uploaded image — re-check the thumbnail before Generate; page reload resets to High Detail 25 cr.

## Step 4 done Oct 3
Owner: keep all 8. GLB+FBX in `assets/guns/<class>/source/<ID>-meshy-t2.{glb,fbx}` (byte-identical to ~/Downloads Meshy_AI_* originals; tri counts match Meshy viewer). Each GLB is ONE mesh — piece split (slide/mag/optic/etc.) must happen in Blender.
Balance after: **1,032** — a 20-credit race-car generation appeared in the account at ~00:27 Oct 3 that this session did not start (other session/owner?). Owner to confirm.
**Next (step 5, Codex or `bl_*`):** per gun: import GLB, split into named pieces, black-out orange parts, budget check, export FBX+GLB to `<class>/export/`, `manifest.json`, `verify_*.py` — per CLAUDE.md asset rules.

## Step 5 done Oct 3 (Blender, local headless — `/opt/homebrew/bin/blender` exists, no bridge needed)
Owner answers: bisect-cut mags+slides; muzzle **Blender +Y** (Roblox -Z via (x,z,-y)); decimate to **≤1500** (Config.TriBudget.WorldGun); lengths pistol 1.43 / AR 2.97 / sniper 3.10 / shotgun 2.6 studs (1 Blender unit = 1 stud).
Script: `tools/guns_blender.py` (piece boxes per gun in `PIECES`, lengths in `CLASS`; sources read-only, sha-checked unchanged). Check: `tools/verify_guns.py` re-imports every GLB+FBX: piece names, tris = manifest ≤1500, length on Y, muzzle at +Y, every material near-black -> **PASS 8/8**. Split sheet: `assets/guns/export-check.png` (debug colours only; shipped mats are Gunmetal .05 / Black .015 — no orange anywhere).
Out: `<class>/<ID>.blend`, `<class>/export/<ID>.{fbx,glb}`, `<class>/export/manifest.json` (per piece: tris, pivot Blender+Roblox, material). Objects `<ID>_<Piece>` under empty `<ID>`; origin at grip; pivots = piece bbox centre, Mag = its top.
| Gun | tris | pieces |
|-|-|-|
| P1 | 1476 | Body Slide Optic Muzzle Mag Light |
| P2 | 1478 | Body Slide Optic Muzzle Mag |
| A1 | 1484 | Body Optic Muzzle Stock Mag Foregrip |
| A2 | 1482 | Body Optic Muzzle Stock Mag Foregrip |
| S1 | 1478 | Body Barrel Optic Muzzle Stock Mag Bipod |
| S2 | 1484 | Body Optic Muzzle Stock Mag |
| G1 | 1483 | Body Barrel Pump Stock |
| G2 | 1483 | Body Barrel Pump Stock |
Known limits: AR charging handle + sniper bolt stay in Body (no clean shell; black-out is via materials anyway); G1 grip top stays Body; bisect caps are flat fills. `gun_points.json` / v2 blends use muzzle **-Y** — flip Z sign if reused with these.
Rebuild/verify: `blender -b -P tools/guns_blender.py` (subset: `-- P1 S2`), then `blender -b -P tools/verify_guns.py`.
**Next (owner):** Studio 3D Importer -> `assets/guns/pistol/export/P1.fbx` first; confirm it lands ~1.43 studs long, muzzle along -Z, 6 MeshParts named `P1_*` (if ~100× off, set importer units to studs/scale and tell me). Then the other 7. Phone test: equip in Phone Test place on iPhone 16 Pro, check silhouette/darkness readability and FPS. Commit when owner says.

## Step 6 — uploaded gun roster, Oct 3
Owner chose eight new guns, retiring the old roster, and uploaded meshes. P1/P2, A1/A2, S1/S2, G1/G2 are independent IDs; names/stats/prices are provisional Config entries. Old saved gun IDs are dropped; credits/other data remain, with P1 supplied as starter.
- Uploaded all 43 pieces through Studio's 3D Importer as Actuallytherealzo. `assets/guns/uploaded-assets.json` locks IDs to export/geometry hashes. No Meshy/Higgsfield runs or credits spent.
- Rebuild: `blender -b -P tools/export_guns.py`, then `python3 tools/import_guns.py`, then `python3 tools/build.py`. Existing uploads are reused. For changed exports only: import `build/guns-import.glb` (Front/Top, Upload to Roblox, Insert Using Scene Position), save `build/guns-upload.rbxlx`, run `python3 tools/import_guns.py --from-place build/guns-upload.rbxlx`.
- Generated `GunAssets.luau` drives world + first-person meshes, muzzle/attachment points, Slide/Pump movers and top-of-Mag pivots. Importer's baked X/Z reversal is corrected; no old `gun_points.json` coordinates. `Config.GunMeshes.UseUploaded=false` selects procedural boxes of the new guns; failed asset loads also report fallback. No runtime EditableMesh for guns. Sniper bolts remain in Body; shotgun exports have no detachable Mag.
- Verification: `VERIFY PASS 8 guns`; 20 source files hash-identical to `8b1ce26`; deterministic generation; 43 unique uploaded IDs. `python3 tools/test.py`: **1,922/1,922**, exit 0 (lobby 1,342; heist 551; two-client 29), versus baseline 1,436/1,446. GunFeel 55/55; Guns 574/574; measured world/FP 1,476–1,484 tris per gun. Logs: `build/guns-final-summary.log`. Earlier overlapping Studio runs were invalid; final run was serial.
- Shipping builds: `build/lobby.rbxlx`, `build/heist.rbxlx`. Private places have **not** been republished by this step. Owner: publish these to the existing private Phone Test lobby/heist IDs in Config before phone testing.
Phone gate (iPhone 16 Pro, owner account): open [Blackout Crew Phone Test](https://www.roblox.com/games/102861732553937/Blackout-Crew-Phone-Test); equip P1/P2/A1/A2/S1/S2/G1/G2 at the range wall. Check dark silhouettes against light/dark level areas, -Z muzzle/tracers and ADS. Fire/reload every gun; confirm slides/pumps return and magazines drop/reseat. Swap all eight with Vortex karts visible; record FPS, stutters and warmth over 15 minutes. Desktop FPS is not phone evidence. Stop here until owner's **go**.
