# RAZOR kart: Roblox import (Studio)
Files: `razor_kart.fbx` (10 visual parts + Collision), `razor_axes_test.fbx`, `textures/`, `razor_preview.glb` (preview only).
Exported Y-up, nose = -Z, kart right = +X, 1 unit = 1 stud. **Unverified in Studio; step 1 proves it.**

## 1. Axes test (do first)
Import `razor_axes_test.fbx` (3D Importer, defaults). Expected part Size = **(5, 4, 7)**.
- Cube 2 studs at origin. Longest bar (5 studs out of cube) points **-Z** (forward). Side bar (3) points **+X** (right). Up bar (2) points **+Y**.
- Wrong size (e.g. 500x) → scale issue: tell me. Bars wrong way → tell me the axis; don't fix by rotating.

## 2. Import kart
3D Importer → `razor_kart.fbx`. Keep "Import as Model" on. Expect 11 MeshParts: Chassis, Steer, Wheel_FL/FR/RL/RR, DecalPlates, HeadlightStrips, TailStrips, Underglow, Collision.
- Check Chassis Size ≈ X 5.16 (width), Y 3.14 (height), Z 11.2 (length).
- Pivot: Chassis pivot should sit at ground, kart centre. Wheel pivots at hub centre (spin about X). Steer pivot at steering hub. If any pivot is wrong: set `PivotOffset` to fix, or re-import with "Use model pivot" toggled; report which.

## 3. Textures
Chassis, Steer, Wheel×4 each: add `SurfaceAppearance`; same 4 maps on all six:
ColorMap `razor_color.png`, NormalMap `razor_normal.png` (OpenGL), MetalnessMap `razor_metalness.png`, RoughnessMap `razor_roughness.png`. Upload as Images first.
DecalPlates: SurfaceAppearance ColorMap `razor_decals_color.png` (blank plates). Orientation test: `razor_decals_orient.png` (labelled; hood/rear/#7 tops should read upright).
Skins = swap **ColorMap only** (`razor_color_noao.png` = albedo without AO, multiply your own AO from `razor_ao.png`).
Logo orientation: hood top = toward nose; rear/endplate top = up.

## 4. Physics / cost flags
- Collision: `Transparency=1`, `CanCollide=true`, `CollisionFidelity=Hull`(or Box), `Massless=false`. It is the ONLY colliding part.
- All other 10 parts: `CanCollide=false`, `CanQuery=false`, `CanTouch=false`, `Massless=true`, `CastShadow` off on small strips.
- HeadlightStrips: Material Neon, Color white. TailStrips: Neon, red. Underglow: Neon, tint by squad colour. No SurfaceAppearance on these three.
- Weld all to Chassis (PrimaryPart). Wheels/steer via your constraints.

## 5. Perf check (low-end phone)
Studio → Stats (Shift+F2) / MicroProfiler: 4634 visual tris, ~10 draw calls per kart. Test 8 karts on-screen on a low-end phone; report FPS. If slow: drop maps to 512 (same UVs).
