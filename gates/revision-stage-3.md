# Revision stage 3 — phone-budget Vortex
Local review candidate, Oct 1. Owner authorised optimisation to the phone budget. Approved reference files remain untouched; visual and iPhone 16 Pro acceptance are pending.

- Export verifies the 17 approved-reference hashes, preserves all 117 named pieces and applies source modifiers before decimation. Original evaluated geometry: 54,024 triangles. Derivative: 6,616 source triangles against an 8,000 cap.
- Reproducible tool: `tools/export_vortex.py`; editable derivative: `assets/karts/vortex/phone-optimized.blend`; runtime data: `src/shared/VortexArt.luau`. Dedicated `VortexKartApproved.rbxmx` supplies replicated carriers, motors and pivots.
- Client fixed-size cached meshes share geometry across karts. Groups follow wheels, steering and butterfly doors; separate matte trim groups follow the lights switch. Device allocation failures fall back to carriers and emit a warning. No mesh uploads.
- Curved cockpit, silhouette, rig and in-engine appearance inspected in local Studio. Saved four-view derivative renders: `assets/karts/vortex/phone-review`. Blender review materials differ from runtime matte materials; these renders are shape review evidence.
- Validation and latest counts: `phone-test-readiness.md`. Earlier focused render delta: 6,380 triangles. Source count is the conservative budget figure. The initial 117 separate dynamic meshes exhausted the device budget; grouped fixed-size allocation and fixed-size gun meshes resolved the local regression.

Owner review: inspect canopy curvature, wheels, open/close doors, steering, cockpit view and matte light toggles. Test multiple karts alongside gun swaps on the iPhone; local Studio allocation does not establish phone support or FPS.
