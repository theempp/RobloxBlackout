# Pending Blackout Crew master implementation prompt

**Current handoff:** [Claude Code revision prompt](refs/revisions/CLAUDE_CODE_HANDOFF.md), prepared October 1, 2026; [review findings](refs/revisions/REVIEW.md). Claude Code is the intended implementation agent. This preparation does not authorize game-code changes or advance the 3A gate.

**Status:** the owner has locked the game revision list, gun visual direction, and revised Blackout Vortex model/cockpit. The approved kart handoff is now recorded in `refs/revisions/NOTES.md`, with a preserved source/export snapshot. The inputs are ready for the combined master implementation prompt; this turn only locks and saves them. No game code should be changed from this note alone.

A quiet hourly follow-up in this Codex chat checks these dependencies and should only notify the owner when completion, failure, or a required decision becomes actionable. Automation ID: `blackout-crew-master-prompt-readiness`.

## Locked input already ready

- Four owner-approved gun concepts: [locked gun set](assets/guns/concepts-2026-09-30/LOCKED.md). Use the four `v2` images listed there. The owner approved their visual look on Sept 30, 2026. [The revision note](refs/revisions/NOTES.md) also locks in high-quality in-game gun assets, responsive realistic shooting feel, a full-viewport Needlepoint scope, hit/damage/ELIMINATED feedback, and phone-smooth performance.
- The owner-locked [complete revision list](refs/revisions/NOTES.md) covers locker-room entry and customization, personal armory and live gun-stat comparisons, heist queue presentation, and the [oceanside city concept](refs/revisions/OCEANSIDE_CITY_CONCEPT.md). The city concept is locked; its yacht heist belongs to version 2, the first major update.

## Inputs still required

None for the approved visual/revision handoff. The owner explicitly approved the reference-led Vortex cockpit shown in this chat. Use [the approved snapshot](assets/karts/vortex/revisions/approved-reference-cockpit/) and its `APPROVAL.json` file hashes, with the complete kart entry in [the revision notes](refs/revisions/NOTES.md). Earlier candidate files and later workstream edits must not supersede this approval. Roblox import, integration and phone acceptance remain implementation work, not prerequisites for recording this visual approval.

## When the kart handoff is complete

Prepare **one copy-pasteable master prompt for Claude Code** that merges the locked guns, finished kart, and complete owner-approved revision list. State exact project paths to every approved reference. Tell the implementation chat to read the nearest `AGENTS.md`, `CLAUDE.md`, current `BUILD_PLAN.md`, `gates/build-3.md`, and only relevant directive sections; inspect the current code first and reconcile rather than duplicate built systems. Preserve the project's Build 3 gate sequence, server validation/persistence, mobile readability and performance, gun/vehicle budgets, and owner phone-test requirements. Include concrete acceptance checks and tests for the requested systems. Flag unresolved visual or gameplay choices instead of guessing. Do not make the actual code changes until the owner starts that implementation chat or explicitly asks for them here.

This queue is a coordination note, **not** the final master prompt. The approved kart snapshot is now the final visual input for that prompt. Draft from the locked outputs and distinguish completed local model checks from the still-pending Roblox import and device tests.

The earlier readiness coordination text above is historical context. The combined prompt is now prepared; implementation authorization and unresolved owner choices are tracked in the Claude Code handoff. Automation state was not inspected or changed during this review.

Oct 1 final owner approval: bolt-action Needlepoint; staged order locker/armory/queue → guns → Vortex → city. Claude may start local stage 1 now and must stop at its owner review checkpoint.
