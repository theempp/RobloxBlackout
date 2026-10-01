# Revision review — October 1, 2026

Reviewed the locked notes, city concept, gun approvals, Vortex snapshot, project instructions, build/gate records and relevant source paths. Documentation review only; no game tests were rerun.

## Coverage and gaps

| Area | Existing foundation | Required revision / acceptance |
| --- | --- | --- |
| Locker room | Garage onboarding; cosmetics ownership; empty Config cosmetic catalog | Entry/skip, centered preview, owned outfit/mask choices, saved equipped IDs, migration, respawn and heist transfer. Cosmetic disguises unless separately approved. |
| Personal armory | Owned loadout and attachment bench with server ownership/range validation | Personal inventory UI, three usable slots, inspect/preview/apply/cancel, accurate before/after stats, rejected-save recovery. No paid-gun grants in shipping builds. |
| Queue | Existing server queue, crew readiness and teleport flow | Raised adjacent pads, labels, names/count/ready feedback, join/leave/disconnect/countdown/failure recovery. Retain four-player maximum. |
| City | Ten-block heist map; fixed nighttime baseline | Ocean/harbor, tower grid, circular and hexagonal landmarks, bridge/tree-covered uphill escape, day/night; preserve heist navigation, parking, timer/payout and pursuit. |
| Guns | Six configured guns, shared attachment resolver, generic recoil/ADS, confirmed hit/damage feedback | Four approved art replacements; aligned optics, distinct feel, full-view Needlepoint scope, once-per-defeat ELIMINATED. Preserve remaining roster. |
| Vortex | Older cockpit in production; shared suspension/doors/cameras | Import approved curved model, preserve pivots/door clearance, usable tinted cockpit, collision and device budgets. Offline proxy is not final art. |

## Contradictions requiring explicit handling

1. BUILD_PLAN bans dynamic lights; city notes request actual light pools. Owner approved a narrow exception on Oct 1: a small number of practical city streetlights, verified for phone performance. Existing KartVisuals also switches parts to Neon, despite the global no-neon override; Claude must reconcile it.
2. Four approved gun sheets do not replace the six-gun roster. Keep Scatterpop and Rattler and their entitlements. Needlepoint art describes a bolt-action sniper; current `needle` is a marksman at 220 rpm. Ask before changing its class, cadence, damage or pricing.
3. Gate and Vortex README contain historical 121/125-piece statements and 18 imported meshes. Approved snapshot describes 117 pieces / 32 shaped meshes / 18 door pieces. Counts refer to different revisions; use the approved manifest for the new import and inspect production separately.
4. Existing gate remains 3A awaiting owner testing. Visual locks do not unlock 3B economy, 3C content or 3D alpha. Agree a revision stage with the owner before coding across these boundaries.
5. HANDOFF_PROMPT.md is historical Build 1. MASTER_PROMPT_QUEUE previously targeted a new Codex chat. Use the new Claude handoff for this work.

## Missing implementation safeguards added to the handoff

- Cosmetic equip persistence and old-profile migration without deleting owned items, receipts, settings or tutorial state.
- Preview isolation, menu input suppression, safe-inset touch controls and reduced-motion cleanup.
- Stat comparisons from final resolved values, with units and correct improvement direction; zoom is a tradeoff, not universally better.
- Queue lifecycle/error feedback; deduplicated server-confirmed eliminations; scope reset on death, swap and menu entry.
- Escape-route timing, streaming at kart speed, AI pathing/visibility and Blackout/day-night precedence.
- Measured triangle/render budgets, client boot checks and multiplayer regressions; phone acceptance and live persistence remain owner checks.

## Verified inputs / remaining choices

All 17 approved Vortex snapshot hashes and all four locked gun-sheet hashes match. Six city reference images are present. This verifies file integrity, not visual suitability or Roblox performance.

Resolved Oct 1: limited performance-tested practical streetlights; reserved yacht berth only at launch, no exterior. Owner subsequently locked bolt-action Needlepoint and stage order: locker/armory/queue, guns, Vortex, city. Stage 1 local implementation is authorized; stop for owner review after each stage. Exact gun balance remains a proposal for the gun stage. Final city name, map dimensions, cycle duration/start selection and cosmetic catalog should be proposed in Claude's first plan; Port Meridian remains a placeholder. No new art, stealth mechanic or paid generation is approved here.
