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
