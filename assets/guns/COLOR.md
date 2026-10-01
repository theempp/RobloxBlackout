# Dark lacquer gun review pass (awaiting owner approval)

Render: `blender --factory-startup -b -P gun_build.py -- color color` then `python3 gun_sheet.py color` from `assets/guns/`.
Review: `color/detail-sheet.png` and individual `color/<id>-*.png`. The original `detail/` pass remains reproducible with `-- detail detail`.

Four deeper palettes: Dart-9 midnight cobalt/brass, Buzzline oxblood/warm gold, Ranger petrol/sage metal, Needlepoint aubergine/champagne. Painted panels use a low-roughness clearcoat with restrained molded grain; metal trim and the Needlepoint barrel have tighter highlights. A dark studio setup shows the finish in the review renders. Each keeps the orange foam muzzle and neutral swappable engraving plate. No emissive material or paid generation.

Four mesh objects each; first-person tris: 1392 / 1848 / 1722 / 1960. All retain their previous attachment points and pivots, and report zero non-manifold edges. The original detail JSON files regenerate byte for byte with a non-color build. These Blender materials are for visual review; UVs, export atlases, world LOD, and Roblox import remain pending.
