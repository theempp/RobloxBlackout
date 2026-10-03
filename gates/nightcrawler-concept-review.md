# Nightcrawler concept review — Oct 2, 2026

Priority: limited-edition paid Nightcrawler through battlepass or bundle; Phantom deferred.

## Current boundary
- Owner approved the closed-cockpit design pair and requested a new chat to start the Blender process. Design review gate cleared. Separate paid 3D cost approval remains required.
- Owner requested closed cockpit on Oct 2: low teardrop canopy with sloping windshield, curved roof, narrow blacked-out windows and tapered rear spine, guided by IMG_7228/7229 (copies in concepts/references). Add continuous red taillight full width along spoiler upper rear edge; keep diffuser lights and no side/arch strips. This supersedes the open-cockpit design. Owner approved another 12 Nano Banana 2 credits with "go"; both jobs completed, balance 1090 → 1078. No remaining spending approval.
- Current review pair: `concepts/nightcrawler-closed-front.webp` and `concepts/nightcrawler-closed-rear.webp`. Rear generated from new closed front + prior rear geometry reference. Both visually inspected: enclosed canopy, blacked-out glass, spoiler light strip and no side/arch strips. Concept perspectives still differ in canopy contour and wing-end depth; use rear for endplate geometry and rear-facing lights, reconcile in Blender. Await owner design approval before any 3D job.
- Owner approved 12 Meshy credits for two Nano Banana 2 images; both jobs completed (6 each), balance 1102 → 1090. No remaining approval; no 3D generated.
- Front: `concepts/nightcrawler-front-no-side-strip.webp`, task `01a0ff73-d283-7168-a834-b7568bce757d`, 1200 × 896.
- Rear: `concepts/nightcrawler-rear-matching.webp`, generated from corrected front, saved full-size.
- Originals preserved. Await owner review before paid multi-view mesh.
- Side/arch light strip removed. Rear defines deep wing endplates, exposed rear mechanics, spoiler/diffuser red lamps. Front places short red lamps on forward-visible wing ends and depicts shallower endplates; these need reconciliation to the rear geometry when modeling. Do not treat the pair as exact CAD views.

## Reuse findings
- `src/shared/KartModel.luau`: invisible collider assembly, one seat, wheel motors; expected Chassis, Steer, Wheel_FL/FR/RL/RR with Config hub tolerance.
- `src/shared/KartPhysics.luau`, client KartVisuals/KartClient/CameraRig: existing driving foundation.
- Garage and heist spawners currently use a single Config template and `owned.vortex` tier flag. Add explicit vehicle selection/ownership validation for Nightcrawler; a new mesh alone does not supply this.
- Rules currently whitelist base/vortex only. Economy premium rewards are cosmetics; receipts support premium/currency/cosmetics, no kart bundle grant yet. Pass and bundle product IDs remain zero. Preserve disabled purchases until owner supplies product configuration and approves activation.
- Connected Studio `shot-lobby.rbxlx` was in Play; read-only inspection confirmed ReplicatedStorage.BlackoutCrewAssets.VortexKartApproved. Two other ui-preview instances also connected. No Studio edits made.
- Higgsfield Blender bridge disconnected. Desktop IMG_7223.jpg and related originals not found on Desktop/Downloads; current front and approved textual wing description used.

## Next
Review two concepts, then obtain separate current quote approval for ONE untextured multi-view Meshy draft (FBX for Blender/Roblox). Inspect full geometry before texture spending, make localized Blender corrections, adapt existing chassis, and test. No live publishing authorized.
