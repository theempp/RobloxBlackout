# Nightcrawler — Meshy draft done, Blender stage (Oct 3, 2026)

## Meshy result (verified)
- ONE untextured draft generated Oct 3 via Claude in Chrome: Meshy 7.1 Flagship, High Detail, multi-view (Main = `concepts/nightcrawler-closed-front.webp`, Back = `concepts/nightcrawler-closed-rear.webp`), **Standard**, Texture/Split/Pose/Image Enhancement off, Private. Quote 20 credits (owner-approved). Balance 1,052 -> **1,032** (the 1,078 in earlier gates was stale; the gun work spent the difference).
- Meshy auto-name: "Shadow Velocity". Mesh: **1,364,170 faces / 681,719 verts** (≈170x the 8,000-tri budget). Unrequested spend: none. Texture/remesh/retry: none, each needs new owner approval.
- Source (byte-intact, never edit): `assets/karts/nightcrawler/source/Meshy_AI_Shadow_Velocity_1003043122_generate.fbx` (38.8 MB, sha256 in `source/SHA256.txt`). Original also still in ~/Downloads. FBX axis/scale/origin: Meshy defaults (Resize off, origin Bottom) — measure in Blender, don't assume.
- Inspection shots: `assets/karts/nightcrawler/inspection/` (front-quarter, front 3/4, rear 3/4, underside).

## Inspection verdict (Meshy viewer, grey solid; Claude)
- Good: low teardrop canopy, slammed body, open front suspension arms, thin splitter, big rear wing with deep endplates, diffuser fins, chopped aero. Reads as the approved concept.
- Underside is flat/closed (good for a collider hull).
- Concerns for Blender: wheels look fused/near-fused to body arches (separate 4 locally); suspension arms/wing struts are fine detail that decimation will eat; canopy is a solid shell (no cockpit/seat) so avatar fit + access needs a cut; no lamps/glass materials (untextured) — colours come from Blender materials (flat black body, red rear lamp strip on spoiler upper edge, red diffuser lamps, white headlights, opaque black glass), NOT a paid Meshy texture.
- Not yet verified: exact dimensions vs Config hubs (track 3.85, wheelbase 7.0 studs, wheel radius 0.92, width 0.96), left/right symmetry, mesh manifold/holes.

## Contract for Blender (from repo, unchanged)
- `Config.TriBudget.Kart = 8000` whole kart. Required parts: Chassis, Steer, Wheel_FL/FR/RL/RR; `Config.KartModel.HubTolerance = 0.15`; hubs FL(-1.925,.92,-3.4) FR(1.925,.92,-3.4) RL(-1.925,.92,3.6) RR(1.925,.92,3.6). Roblox frame +X right, +Y up, nose -Z. Export maps Blender (x,y,z)->Roblox (x,z,-y); mirror `tools/export_vortex.py` (decimate per piece, evaluated geometry, scaling). **Do not edit shared Config** to fit the mesh — scale/position the mesh to the hubs instead. Wheel radius/width in Config.Kart.Geo.
- Deliverables in `assets/karts/nightcrawler/`: `blackout_nightcrawler.blend`, `export/` FBX + GLB (per-piece names, hub-centred wheel pivots), `manifest.json` (piece count + measured tris), `verify_export.py` re-import check, build script(s) under the same folder. Studio import/upload and phone tests = owner; mark pending.
- No Config/rules/economy/selection edits yet; purchases stay disabled, product IDs 0.

## Codex command pattern
`blender -b -P assets/karts/nightcrawler/<script>.py -- <args>` (needs scipy + Pillow on Blender's Python path). Higgsfield `bl_*` live bridge is optional.

## Pending
- [ ] Blender: clean, scale to hubs, separate wheels, canopy cut/seat fit, budget <=8,000 tris, materials, collisions, export, verify
- [ ] Owner: Studio import/upload; phone test
- [ ] Integration: Nightcrawler selection + ownership validation (inspect Garage/heist spawners, Rules whitelist, Economy first); purchases off
