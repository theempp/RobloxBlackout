# Gate: kart-razor (Phases 2-6)
**Tris:** 4634 visual (cap 8k) + 36 collision hull. Chassis 2790 (body 2262, wing 152, splitter 100, diffuser 96, canards 48, hoop 60, seat 72), wheels 398x4, steer 140, decals 40, head 40, tail 20, glow 12.
**Draw calls:** 10 visual MeshParts (Chassis, Steer, Wheel x4, DecalPlates, HeadlightStrips, TailStrips, Underglow) + 1 invisible Collision. 6 textured parts share ONE 1024 atlas (4 maps) + decals 512x256 (ColorMap only).
**Verts (export):** Chassis 2443, wheel 392, steer 180.
**Checks:** top silhouette IoU 0.99; FBX round-trip bbox = 11.2L x 5.16W x 3.14H (chassis), nose -Z, scale 1 stud; GLB axes OK. Studio import NOT yet verified.
**Deviations:** crown z 2.10 vs ref 1.97; wing top 3.29 vs ref ~3.09; headlights 40 tris vs 24 budget; 11 parts incl. collision; atlas density 56.8 px/stud (80% packed).
**Mobile notes:** 4 PBR maps 1024 ~ 16MB uncompressed, shared by all karts; fall back to 512 if needed. AO baked into ColorMap; skins swap ColorMap only (`razor_color_noao.png` + `razor_ao.png`).
**Files (assets/kart/razor/):** razor_kart.fbx, razor_axes_test.fbx, razor_preview.glb, IMPORT.md, textures/*.png, razor_build.py/razor_tex.py/razor_export.py (rebuild: from that folder, `blender -b -P razor_build.py -- 6 OUT`; Blender's Python needs scipy + Pillow on sys.path; set RAZOR_REF if refs/ is not at ../../../refs/kart/razor; rebuild verified 2026-09-30: same tris/verts, 9 textures byte-identical), review/*.png
## Your Studio test steps (see IMPORT.md)
1. Import razor_axes_test.fbx: Size must be (5,4,7); long bar -Z.
2. Import razor_kart.fbx: 11 parts, Chassis Size 5.16/3.14/11.2; check pivots (chassis ground/centre, wheels hub).
3. Add SurfaceAppearance (4 maps) to Chassis, Steer, 4 wheels; decals ColorMap to DecalPlates (try orient png).
4. Collision part only: Transparency 1, CanCollide on, Hull; others CanCollide/CanQuery/CanTouch off, Massless.
5. Neon: head white, tail red, underglow squad tint.
6. Stats on a low-end phone, 8 karts: report FPS.
Report any axis/pivot mismatch; do not fix by rotating.
