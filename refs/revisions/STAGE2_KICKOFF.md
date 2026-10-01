Work in `/Users/zozo/Desktop/Blackout Crew`. Owner go (Oct 1): start **revision stage 2: four approved gun assets and shooting feel**, now.

Stage 1 (locker room, armory, queue pads) is delivered: `gates/revision-stage-1.md`. Its [REC-AUTO] proposals stand unless I veto them, and my phone playtest is still pending.

**Read first:**
- `CLAUDE.md`.
- `refs/revisions/CLAUDE_CODE_HANDOFF.md`: the "Four approved gun assets and shooting" section and "Validation, reporting and stop".
- `refs/revisions/NOTES.md`: the gun lock and the Oct 1 decisions.
- `refs/revisions/REVIEW.md`.
- `gates/revision-stage-1.md`.
- `assets/guns/concepts-2026-09-30/LOCKED.md`, the four `*-v2.png` sheets, and `assets/guns/{PLAN,BLOCKOUT,DETAIL,COLOR}.md`.
- From `DIRECTIVE_GRAY.md`, only §5f, §6, §15–17 (read by range).

**Inspect before editing** and extend what exists; do not build a parallel weapon pipeline: `GunModel`, `ViewModel`, `GunClient`, `CameraRig`, `Recoil`, `Weapons`, `Targets`, `Fx`, `Hud`, `GunStats`, `StatSheet`, and the existing gun build scripts. Preserve all existing uncommitted work.

**Scope:**
- Replace the art for `dart9`, `buzz`, `ranger` and `needle`. Keep Scatterpop and Rattler, and keep every gun's ID, price and ownership rules.
- Give each of the four distinct cadence, predictable recoil and recovery, smooth ADS, aligned sights, viewmodel motion and sound. All tuning goes in Config.
- **Needlepoint** becomes a single-shot bolt-action with a smooth bolt cycle and a full-viewport scope:
  - Hide whatever blocks the sight.
  - Reset the scope on swap, death and menu entry, with no stuck zoom.
  - Propose its cadence and damage together for my balance review before locking them.
- Show one server-confirmed **ELIMINATED** tag per defeat. Deduplicate pellets and multi-hits, never predict kills client-side, and keep tags off the reticle.
- **Budgets:** ≤ 5k first-person and ≤ 1.5k world triangles, measured.
- **Needs my approval first:** Roblox uploads, publishing, pushing, and any paid generation (plan plus cost quotes). Use offline import paths first.

**Process:**
1. Give a concise stage 2 plan, then implement without re-asking for this authorisation.
2. Batch genuine blockers into one round of questions.
3. Add behavioural tests: scope reset, elimination dedup, cadence and server rate limits, and budgets.
4. Run focused specs, the full `tools/test.py --only lobby,heist,multi` regression, and shipping smoke on both places.
5. Capture screenshots if you can.
6. Write `gates/revision-stage-2.md` with exact results, measured budgets, limits and phone playtest steps.
7. Stop for my review.
