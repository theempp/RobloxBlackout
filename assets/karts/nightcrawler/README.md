# Nightcrawler Blender review candidate

Immutable paid FBX -> local Blender derivative. No Meshy calls, generation,
textures, remeshing or credits. Source checksum is checked before and after.
Shared Config and runtime code are unchanged. Studio and phone acceptance are pending.

`blackout_nightcrawler.blend` contains the editable derivative, a hidden untouched
source-reference collection and hidden seated-avatar fit proxies. Only the 20
delivery meshes are exported. `manifest.json` measures 7,400 triangles, including
the hidden locator and collision proxies, against the 8,000 limit.

## Reproduce on this Mac

Tested: Blender 5.2.2 LTS / Python 3.13.13. Dependencies live in ignored `.deps/`.
Run from the repository root; the dependency install is needed only on a fresh setup.

```sh
uv pip install --python /Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 --target assets/karts/nightcrawler/.deps numpy==2.5.3 scipy==1.18.1 pillow==12.3.0
blender -b --python-exit-code 1 --python-expr "import sys; sys.path.insert(0,'assets/karts/nightcrawler/.deps'); import scipy; from PIL import Image; print('BLENDER_READY')"
blender -b --python-exit-code 1 -P assets/karts/nightcrawler/inspect_source.py
/Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 assets/karts/nightcrawler/measure_fit.py
blender -b --python-exit-code 1 -P assets/karts/nightcrawler/build_nightcrawler.py
blender -b --python-exit-code 1 -P assets/karts/nightcrawler/finish_nightcrawler.py
blender -b --python-exit-code 1 -P assets/karts/nightcrawler/verify_export.py
blender -b --python-exit-code 1 -P assets/karts/nightcrawler/check_clearance.py
blender -b --python-exit-code 1 -P assets/karts/nightcrawler/render_review.py
blender -b --python-exit-code 1 -P assets/karts/nightcrawler/render_review.py -- assets/karts/nightcrawler/blackout_nightcrawler.blend --open
python3 assets/karts/nightcrawler/review_manifest.py
```

The build uses a reduced working copy to avoid locking thousands of jagged cut
vertices into wheel seams, then budgets each piece separately. Source faces remain
where possible; only wheel seams, cockpit and motion-clearance regions are repaired.
Raw intake and wheel-stage `.blend` checkpoints are reproducible and ignored by git.

## Checks and limits

- `source_inspection.json`: raw FBX metadata, bounds and original topology.
- `fit_measurements.json`: approximate tyre-envelope centres, fitting transform and
  source symmetry by nearest mirrored vertex; these are measurements, not exact CAD hubs.
- `verification.json`: FBX and GLB independently re-imported; names, measured tris,
  wheel pivots, true radial radius, width, chassis frame, opaque untextured materials.
- `clearance_audit.json`: 24 static steering/travel poses against body, canopy, floor
  and tub; seated proxy/body surface intersections. This is not a physics test.
- `review_manifest.py`: stdlib-only cloud review of source/export hashes and actual
  GLB triangle counts, names and pivots, so Claude does not need Blender.
- `review/review-sheet.jpg`: final closed front/rear/side/top, inspected by Codex.
- `review/access-sheet.jpg`: opened canopy with a 4-stud-wide standard seated proxy.

The owner chose to raise the canopy for an upright avatar. The new hollow canopy
reaches 4.88 studs (the fitted source was about 2.57); maximum width is 4.5 studs to
clear arms. The seat-pan top stays at (0,1.54,0.05). Sampled actual inner-roof
clearance is 0.0912 studs over the standard proxy. The taller silhouette requires
owner visual acceptance; different avatar scales and accessories remain untested.

The body and tub deliberately have open cosmetic edges at wheel wells/cockpit.
They are not collision hulls. The four wheels are closed manifold meshes. Faceted
tyres have true radius 0.92 and width 0.96; their cardinal bounding-box diameters
can be slightly under 1.84 because vertices do not sit at every cardinal angle.

## Owner import and integration boundary

Import `export/blackout_nightcrawler.fbx` with individual names/pivots preserved;
do not rescale or decimate in Studio. GLB is the independently verified alternative.
Use flat SmoothPlastic, opaque black glass, no lights or emission. Hide `Chassis`,
`Collision` and `Ballast` (Transparency=1). All art is non-colliding/massless; use the
existing runtime collider and ballast dimensions, without duplicating physical boxes.
FBX custom properties are reference metadata, not guaranteed Roblox importer settings.

`Chassis` is the Vortex-style fixed-frame locator at (0,1.75,-0.05), not the rendered
body. `BodyShell` is the visible body. Wheel hubs and `Steer` match Config exactly.
`Canopy_L/R` have real longitudinal hinges at Roblox (±2.25,1.50,0.10); the review
opens them outward 68 degrees. These are **not** the Vortex door hinges: future
Nightcrawler-specific articulation wiring is pending. Do not rename/activate this
as the Vortex template or silently substitute its existing door motors.

Owner: inspect appearance, actual avatar/access, full steering and suspension,
ramps and frame time on iPhone 16 Pro. Claude: review the artifacts and propose
integration separately; no selection, purchases, product IDs or publishing changed.
