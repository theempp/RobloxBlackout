# Guns art plan (PLAN ONLY: nothing built, nothing generated, no credits spent)
Sources: DIRECTIVE §6 §17 §5f, BUILD_PLAN Build 1, Config.Guns/TriBudget, GunModel/ViewModel/Weapons/Carry, refs/guns/NOTES.md, RAZOR scripts.

## What the design already says
- 6 guns at launch, all owned-forever once unlocked. Wheel = 5 slots, 3 usable, 2 "Coming Soon" (no art needed).
- Roles/price (Config.Guns, all placeholders): Dart-9 Sidearm 0 · Buzzline SMG 1k · Ranger Rifle 3k · Scatterpop Shotgun 6k (8 pellets) · Needlepoint Marksman 10k · Rattler Heavy 15k (80-rd mag).
- Look LOCKED: foam-tactical, chunky foam-dart blasters, matte black + neon accents, no blood, no "Nerf"/Hasbro copies. Real feel: recoil, ADS, hit markers.
- Holster: gun holstered while carrying heavy loot, downed, or driving (Carry.holstered -> Weapons.setHolstered, fire() refuses). Draw 0.3 s after equip. Today the world gun is one weld to HumanoidRootPart at a hip placeholder; holstered state has no visual, no hand attach.
- Budgets (§6 REC-AUTO, verify on low-end phone): first-person gun <=5k tris, world gun <=1.5k, kart <=8k. **No draw-call/texture budget exists** (kart gate reports ~10 MeshParts, one atlas). I propose one below.
- Branding: one swappable engraving zone per class, gun = left receiver (Config.Branding.DecalId).
- Order (§17): guns -> darts+tracer -> attachments -> karts...; per item 1 concept sheet (front/side + logo spot), owner approves in batches of 3-4 BEFORE final art.
- Attachments: slots optic/barrel/mag/grip, sidegrades. Meshes are a later batch; this plan only reserves mount points.
- Code contract today: GunModel.build(gun) -> Model, PrimaryPart "Root" at grip origin, Attachment "Muzzle"; same model is used first-person (ViewModel, anchored, ADS hardcoded to top accent strip) and world. One tri check covers both.

## Proposed budgets (mine; change freely)
| | FP mesh | World mesh | Parts (FP) | Textures |
|---|---|---|---|---|
| per gun | <=4.0k base + <=1.0k attachments = 5k cap | <=1.5k, no attachments | <=5 MeshParts: Receiver, Mag, Mover (slide/pump/bolt, only where it exists), Accent (Neon, no SA), DecalPlate | 1 atlas/gun, shared by FP + world (same UVs) |
Targets (FP/world): Dart-9 2.5k/0.7k · Buzzline 3.5k/1.0k · Ranger 4.0k/1.3k · Scatterpop 3.8k/1.2k · Needlepoint 4.0k/1.5k · Rattler 4.0k/1.5k. World: <=3 MeshParts (Body+Mag merged, Accent, DecalPlate).
Atlas: ColorMap+NormalMap 1024, Metalness+Roughness 512 (~10 MB uncompressed/gun, ~60 MB for 6; all-512 = ~24 MB). Fallback all-512 same UVs. RAZOR note: sharpness needs ~150 px/stud on a phone ADS close-up; 1024 gives ~200, 512 ~100.

## Per gun (silhouette from refs; side view unless noted; no front/top refs exist, widths assumed chunky 0.3-0.45 stud)
| Gun | Refs | Silhouette | Split | Mover pivot | Notes |
|---|---|---|---|---|---|
| Dart-9 (Sidearm) | **none** | chunky toy slide pistol: boxy slide, big trigger guard, short foam muzzle | Receiver+grip, Mag (in grip), Slide, Accent, Plate | Slide: rear-rest, travels +Z | need a pistol ref or derive from 2.jpg language |
| Buzzline (SMG) | 2.jpg, 1.jpg | MP5-like: boxy handguard, angled grip, forward-curved mag, telescoping stock, carry rail, flared tube muzzle | Receiver (grip+stock+guard), Mag, Charging handle (optional), Accent, Plate | Mag: top of mag well | 2.jpg is the closest to the locked foam look |
| Ranger (Rifle) | 6.jpg, 4.jpg, 7.jpg | long tube muzzle, fat receiver, angular stock, curved fat mag; 7.jpg for clean flat panels | Receiver, Mag, Accent, Plate | Mag: top | 3 candidate refs: owner picks lead |
| Scatterpop (Shotgun) | 3.jpg (loose) | bulky bullpup, big round dial/drum on receiver, wide bore, short barrel | Receiver, Pump/foregrip (Mover), Dial (spin, optional), Accent, Plate | Pump: rest, travels Z | no shotgun ref; 3.jpg is a bulk/dial reference only |
| Needlepoint (Marksman) | 5.jpg | very long tube barrel, top rail/optic, hooked stock, thumbhole trigger group, tube glows accent | Receiver, Mag, Bolt (Mover), Barrel tube (Accent cyl), Plate | Bolt: rest, travels Z | barrel = cheap cylinder, spend tris on stock/trigger group |
| Rattler (Heavy) | 1.jpg, 7.jpg | chunky bullpup, ribbed mag, side ammo window (glowing), brass coil strip | Receiver, Mag, Accent (window+coil), Plate | Mag: top | window = Neon part, not geometry |

## Pivots and attachment points
- Mesh origin = grip origin (matches GunModel Root). Export frame as RAZOR: Y-up, muzzle = -Z, right = +X, 1 unit = 1 stud. Mag/Mover meshes keep their own origin at the joint so Luau can tween them.
- Points (Vector3 from Root, generated to `gun_points.json`, pasted into Config.Guns[i].points; FBX cannot carry Attachments): Muzzle (exists; must match), Sight (ADS eye line, replaces ViewModel hardcode), Grip (right hand), Support (left hand), MagWell, Eject, MountOptic, MountBarrel, MountGrip, Engrave (left-receiver plate), HolsterHip / HolsterBack (per class).
- Every Mover rests closed at origin offset 0 (no baked animation).

## Roblox import flags (draft IMPORT.md, same as RAZOR)
- Step 1: reuse `assets/kart/razor/razor_axes_test.fbx`; expect Size (5,4,7). **Kart Studio result is still pending: do not finalise gun export flags before it.**
- 3D Importer defaults, Import as Model. Per gun MeshParts named Receiver/Mag/Mover/Accent/Plate. No Collision part (guns never collide).
- All parts: CanCollide/CanQuery/CanTouch false, Massless true, CastShadow false, weld to Root. Accent: Material Neon, colour from Config accent, no SurfaceAppearance.
- SurfaceAppearance on Receiver/Mag/Mover: ColorMap, NormalMap (OpenGL), MetalnessMap, RoughnessMap. Skins = swap ColorMap only (`*_color_noao.png` + `*_ao.png`). Plate: ColorMap only, swap = rename.
- GunModel stays the contract: add mesh template lookup (`Config.Guns[i].mesh` ids); if empty, fall back to today's primitives, so tests and placeholders keep working. Uploads/asset ids are manual (owner).

## Pipeline (reuse RAZOR structure, don't copy geometry)
`assets/guns/`: `gun_lib.py` (generic: argv after `--`, PT/SS, tris counter, materials, stats, render views, shelf packer, raster/bake, FBX_KW, reimport verify) · `gun_<id>.py` (measured profile polylines, part list, points) · `gun_tex.py` (UV islands, class table albedo/metal/rough, panel-groove height fields -> normal, AO) · `gun_export.py` (Rz flip, FBX, GLB preview, bbox verify, export_info.json, gun_points.json).
Phases: 0 refs -> side masks · 1 blockout sheet, all 6 (silhouette only; OWNER APPROVAL, batches of 3-4) · 2 receiver/parts · 3 detail (bevels, grooves) · 4 points · 5 UV + atlas · 6 export + verify · FP -> world LOD (separate simplified build from same UVs, <=1.5k).
Verify per gun: tris vs table, reimport bbox vs expected length, Muzzle == Config within 0.05, Sight line sane, UV in range. Test: Guns.spec reads export_info.json + gun_points.json vs Config and budgets. Needs Blender + scipy + Pillow (venv from RAZOR verify).
Out of scope: darts/tracer, attachment meshes, third-person hold animation, audio, Studio uploads.

## Routes and cost quotes (Higgsfield `get_cost` preflights: no job submitted, no credits spent; unit = credits)
**Account balance: 2.91 credits.** No 3D route below is affordable without a top-up.
| Route | Model | Quote |
|---|---|---|
| A. Blender procedural (RAZOR) | local | 0 |
| B. Concept sheet image | gpt_image_2_5 low/1k 16:9 | 0.25 each |
| B. | gpt_image_2_5 medium/2k 16:9 | 1 each |
| C. Image->3D | tripo_h3_1_image_to_3d (3k faces, PBR) | 9 |
| C. | hunyuan3d_v3_image_to_3d (LowPoly, min 40k faces, PBR) | 22 |
| C. | meshy_v7_image_to_3d (3k, PBR) | 38 |
| C. Text->3D | tripo_3d (3k faces) | 5 |
| C. | hunyuan3d_v3_1_text_to_3d (pro, PBR) | 16 |
| C. | meshy_v6_text_to_3d (full, PBR, 3k) | 25 |
Not quoted: sam_3_3d (same class as C), multiview models (we only have single side views), rigging/remesh/retexture/body (n/a), other image models (only gpt_image_2_5 proposed).
C caveats: one welded mesh (no separate mag/mover), arbitrary pivot/scale/axes, lighting baked into textures, no clean decal island, tri cap ruins hard-surface detail (Hunyuan minimum 40k). Needs uploading owner refs (incl. Riot/Boundary designs) to a third party.
Recommendation: A for all meshes; B optional and only low/1k (2.91 credits ~ 11 images) if owner wants §17 concept sheets; skip C.
