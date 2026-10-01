# Gun detail pass (Phase 3-4) — awaiting owner approval before UV/texture
Build: `blender -b -P gun_build.py -- detail detail` then `python3 gun_sheet.py detail` -> `detail/detail-sheet.png`.
Frame as RAZOR: Blender muzzle -Y/up +Z; export Rz(180) -> Roblox (-x, z, y). Gun LEFT = Blender +X (blockout had the plate on the right; fixed).
Muzzle tip (foam front face, bore axis) = Config.Guns muzzle exactly (read from Config.luau). Lengths shift vs blockout: Dart-9 -0.11, Ranger -0.13, Needlepoint -0.17.
Parts: Receiver, Mag, Mover (Dart-9 slide, Buzzline/Ranger charging handle, Needlepoint bolt), Plate. Mag/Mover origin = joint (pivots in gun_points.json).
Tris FP: Dart-9 1252 · Buzzline 1708 · Ranger 1582 · Needlepoint 1676 (targets 2.5-4k; cap 5k). 0 non-manifold edges.
Points: `detail/gun_points.json` (Roblox frame, studs from grip origin): Muzzle Sight Grip Support MagWell Eject MountOptic MountBarrel MountGrip Engrave HolsterHip|HolsterBack.
Materials slots = future atlas zones: black, charcoal, foam, steel, plate. No neon/emissive.
Not done: UV/atlas, export, world LOD, Guns.spec, IMPORT.md.
