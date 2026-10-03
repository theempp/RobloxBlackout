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

## Codex Blender result — Oct 3, 2026 (supersedes Blender pending above)

**Local Blender review candidate delivered: 20 pieces / 7,400 measured triangles.**
Pulled first; starting HEAD `8d9410f93d832f3d2ee1b9a3f84b6448999fb269`, clean tree.
No Meshy/service calls, generation, texture, remesh or credits. Config, Studio,
publishing, rules, economy and product IDs untouched.

### Measured intake and fit

- Blender 5.2.2 LTS runs headlessly; Python 3.13.13 with local SciPy 1.18.1 and
  Pillow 12.3.0 verified before import. Reproduction: `assets/karts/nightcrawler/README.md`.
- Source SHA256 before/after: `c8fa2193a762b6ef7dd3cf3f8c3160be5ffa2ddf36c0292830cfd0decd0cdc7d`.
- Raw import: 681,719 vertices / 1,364,170 triangles; **0 boundary / 0 non-manifold
  edges**. Object scale (1,1,1), scene unit scale 1. FBX metadata: Up +Y, Front +Z,
  Coord +X, UnitScaleFactor 1. Actual imported geometry: longitudinal X, nose -X,
  lateral Y, up Z. Do not infer a kart orientation from metadata alone.
- Raw bounds min (-0.951484,-0.422325,-0.214257), max
  (0.951197,0.422943,0.213540); size (1.902681,0.845268,0.427797).
- Approximate bilateral symmetry, nearest mirrored vertex: mean 0.001413,
  p95 0.004140, max 0.042265 raw units. It is not exactly symmetric.
- Fit from imported raw coordinates to Roblox:
  `(5.720359*rawY-0.003631, 5.980169*rawZ+1.293938, 6.279084*rawX-0.239483)`.
  Approximate natural tyre-envelope centres miss the fixed hubs after this fit by:
  FL **0.02477**, FR **0.03693**, RL **0.02380**, RR **0.03528** studs, all <0.15.
  Full measured centres/radii/widths: `fit_measurements.json`.
- Four locally separated wheels have exact contract pivots, radial radius 0.92
  and width 0.96. Local seam patches are closed manifold surfaces. Faceted cardinal
  diameters are slightly under 1.84; radial radius is tested directly.

### Delivered and verified

- `assets/karts/nightcrawler/blackout_nightcrawler.blend`: editable derivative,
  hidden original reference and hidden seated fit proxy. Repeatable scripts alongside it.
- `export/blackout_nightcrawler.fbx` and `.glb`; `manifest.json`; `verify_export.py`.
  Both re-import at **20 pieces / 7,400 tris**, required names intact. Maximum hub
  pivot error: FBX **0.000000246** studs; GLB **0**. Chassis frame and Steer checked.
- Owner explicitly chose **raise the canopy for a seated avatar** in this chat.
  Hollow opaque canopy, cockpit tub, seat top (0,1.54,0.05), two outward-opening
  68-degree leaves. Roof 4.88 studs versus ~2.57 in the fitted source; 4.5-stud
  maximum width clears a standard 4-stud arm span. Actual sampled inner-roof
  clearance over the 4.54-stud seated-head proxy: **0.09122** studs.
- Collision/ballast boxes and hidden `Chassis` locator match Vortex/Config.
  Body/tub are cosmetic open shells: 548/30 boundary edges respectively, no extra
  non-manifold edges; separate boxes provide collision. All four wheels are closed.
  GLB topology audit epsilon-welds duplicated normal-seam positions in a temporary
  BMesh only; export contents stay unchanged.
- `check_clearance.py`: **24 wheel poses** (front -32/0/+32 degrees; travel
  -0.8/0/+0.35) pass against body, canopy, floor and tub. Five seated-proxy parts
  have zero body-surface intersections. Local wheel-well relief and raised arch
  roofs provide clearance. This is geometric evidence, not a physics playtest.
- Flat opaque colours; no texture/image nodes, no emission. White headlights,
  exactly one continuous full-width red `TailLamp` on the upper rear wing edge,
  red diffuser lamps, dark flat carbon. No side/arch lamps.
- Closed `review/review-sheet.jpg` and open `review/access-sheet.jpg` rendered and
  inspected by Codex. Splitter, wing/endplates and remaining suspension geometry
  remain visible. The substantially taller canopy and decimated surface quality
  need owner visual acceptance; concept-level appearance is not signed off.

### Exact next commands and pending gate

Claude, from the mounted repository root (no Blender needed):

```sh
git pull --ff-only
python3 assets/karts/nightcrawler/review_manifest.py
cat assets/karts/nightcrawler/README.md
```

Review `review/review-sheet.jpg`, `review/access-sheet.jpg`, `manifest.json`,
`verification.json` and `clearance_audit.json`. Do not regenerate the Meshy draft.
Nightcrawler selection/ownership and canopy hinge wiring are separate pending work.
The canopy hinges differ from Vortex; do not wire them to its existing door pivots.

Owner, on the Mac:

```sh
cd "/Users/zozo/Desktop/Blackout Crew"
git pull --ff-only
blender -b --python-exit-code 1 -P assets/karts/nightcrawler/verify_export.py
blender -b --python-exit-code 1 -P assets/karts/nightcrawler/check_clearance.py
open assets/karts/nightcrawler/review/review-sheet.jpg
open assets/karts/nightcrawler/blackout_nightcrawler.blend
```

Then, owner-only: visually accept/revise the raised canopy; import the FBX with
names/pivots preserved and no Studio decimation. Set hidden locator/collision
metadata explicitly as described in README (importer support is not assumed).
Check actual avatar/access, steering/suspension/ramps, and iPhone 16 Pro frame time.
**Studio import/upload, actual-avatar fit, hinge integration, visual acceptance,
publishing and phone results remain pending.** No game integration was activated.
