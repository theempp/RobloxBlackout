# kart-razor verify (2026-09-30)
Checked with system Python (PIL/numpy) and headless Blender FBX re-import. Pip installs only into a scratchpad venv, with owner approval.

| # | Check | Result |
|---|---|---|
| 1 | Inventory: all FBX/GLB/IMPORT/9 textures/3 scripts/review/ present, none zero-byte | PASS (extras: razor_blockout.*, blockout-sheet.png, blockout_stats.txt, review/ has 3 pngs) |
| 2 | Atlas maps (color, color_noao, normal, metalness, roughness, ao, uv_layout) 1024x1024 | PASS |
| 2 | Decal maps 512x256 | PASS |
| 2 | Normal mostly (128,128,255) | PASS (98.3% within ±4, mean 128,128,254.8) |
| 2 | Metalness/roughness single-channel | PASS (mode L; ao also L) |
| 3 | 11 meshes, names as specified | PASS |
| 3 | Visual tris 4634, Collision 36 | PASS |
| 3 | Chassis bbox 5.16 W x 3.14 H x 11.2 L, 1 unit = 1 stud | PASS |
| 3 | Nose -Z, up +Y, right +X (headlights/front wheels at nose end, FL/RL at -X, verified via importer axes) | PASS |
| 3 | UVs in 0..1, no NaN (all UV meshes) | PASS |
| 3 | Axes test bbox X5 Y4 Z7; long bar -Z, side bar +X, up bar +Y | PASS (48 tris) |
| 4 | IMPORT.md vs gate vs measured numbers | PASS (tri breakdown sums to 4634; 10 visual + Collision consistent) |
| 4 | Gate/script run instruction `python3 razor_build.py 6 OUT` | FIXED: script needs Blender (bpy); now `blender -b -P razor_build.py -- 6 OUT` (argv parsing patched to read after `--`). Gate line updated. |
| 5 | Rebuild reproduces tri counts | PASS: venv (Blender's Python 3.13 + scipy 1.18.1, Pillow 12.3.0, numpy 2.3.4; in scratchpad, not in repo). Phase 6 rebuild: 4634 visual / 36 collision tris, verts 2443/392/180 match gate, bbox + axes roundtrip OK, 9 textures byte-identical to shipped, re-imported FBX geometry matches (FBX bytes differ only by metadata). |
| 5 | Script fixes needed to run standalone | FIXED in razor_build.py: argv read after `--`; REF was hardcoded `/mnt/user-data/uploads/...` -> `RAZOR_REF` env or `../../../refs/kart/razor` from cwd; `mask_top.png` (QA silhouette mask, absent from repo) now optional, only the top-silhouette IoU (0.99 in gate) is skipped without it. |

Not verified (Studio-only, owner): mesh pivot on import, axes-test size in Studio, SurfaceAppearance look, phone FPS.
