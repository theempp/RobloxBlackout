# Blackout Vortex

## Cockpit revision — IMG_7147

**Owner-approved and locked.** The project-wide decision and pending integration
checks are in `refs/revisions/NOTES.md`. The exact approved source, exports,
reference and previews are preserved in `revisions/approved-reference-cockpit/`,
with file hashes in `APPROVAL.json`. Later changes must preserve this baseline.

The local Blender source and FBX/GLB now have a compact, double-curved
windshield, rounded side windows, painted roof and sculpted roof intake based
on `refs/kart/vortex/cockpit-reference.jpeg`. The glass foot moved 0.71 stud
rearward. The old central windshield bar and floating cockpit light strips
were replaced by continuous glass and slim seals. The windshield is a fixed
single pane; the side doors retain their named moving pieces. Black paint remains.
`refine_canopy.py` applies this revision after the original body shaping pass.
The prior source, exports and review renders are preserved under
`revisions/canopy-before-reference/`.

**This revision is local and has not been imported/uploaded into Roblox.**
The production model described below still contains the previous cockpit.
Review `export/cockpit-preview.png` and the front/side/rear renders first.
The revised source has 117 meshes, including 32 shaped meshes. The import
helper now reads the expected count from the export manifest and preserves
the shorter windshield dimensions without the former length clamp.

## Existing production integration

The single-seat Vortex is now the kart in both garage and heist builds. Its source is
`blackout_vortex.blend`; `export/blackout_vortex.fbx` and `.glb` keep individually
named wheels, doors, and cockpit pieces with pivots at their design positions.
`../../roblox/VortexKart.rbxmx` is the playable Studio-imported Roblox model.
`tools/build.py` embeds it in both places under `ReplicatedStorage.BlackoutCrewAssets`.

## Controls

While driving: **L** switches the exterior white LEDs on/off, **O** opens/closes
the butterfly doors while nearly stopped, and **V** switches chase/cockpit view.
The same actions have **LED**, **DOOR**, and **VIEW** touch buttons. Gamepad D-pad
up/down/right uses those three actions. The owner can also use the door prompt
while standing near the left door. Doors close automatically when the kart moves.

The wheel and its rim/brake details articulate with suspension, and 20 visible
control-arm links connect the moving knuckles to the chassis. The cockpit wheel
turns with the steering input. Door and LED states replicate as kart attributes;
visual animation runs locally on each client. Physics remains the shared
four-corner spring/tyre simulation in `src/shared/KartPhysics.luau`.

The wheel-face bars and raised fender strips were removed. The enclosed cockpit
now has two curved windshield meshes running from the central halo toward the
chassis, with dark side glass and rear fairings flowing into the engine cover; its butterfly
leaves open outward and upward. A front cowl, rear roof bridge, engine cover,
rear quarters and tail closure join the body from nose to diffuser. Hood vents,
engine louvres, rear blades and diffuser fins add the stealth aero detail.

## Source and import

Run `blender -b -P assets/karts/vortex/build_vortex.py` to regenerate the
editable source, FBX/GLB, the 32-piece Studio import FBX, and an offline proxy.
Run
`blender -b -P assets/karts/vortex/verify_export.py` to reimport the FBX and
check its named hubs and pivots. The production `VortexKart.rbxmx` contains the
18 meshes imported and uploaded through Studio. To replace their shape again,
import `export/vortex_shaped_body.fbx` through Studio's File > Import, save the
imported place as `build/vortex-import-stage.rbxlx`, run
`python3 assets/karts/vortex/merge_studio_import.py`, then
`python3 tools/build.py`. Generating the Blender source leaves the production
RBXMX untouched.

The built game has 125 named pieces, including the 18 shaped MeshParts. The
remaining named parts carry wheels, moving pivots, LEDs, frames, and aero details.
The visual `Chassis` locator remains invisible; collision and suspension are
provided by the shared kart physics model. The 18 mesh assets belong to the
Studio account used for this import and require that account's asset access when
opened elsewhere.

`export/preview.png`, `export/rear-preview.png`, and `export/side-preview.png`
are Blender review images. The shaped model was also visually checked in Studio.
