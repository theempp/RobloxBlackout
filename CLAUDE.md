# Blackout Crew (Roblox co-op heist, phone-first; owner Enzo)
Files: DIRECTIVE_GRAY.md (design truth) · BUILD_PLAN.md · SALVAGE.md (audit of ~/Desktop/roblox 1) · gates/ (gate reports) · refs/ (owner reference images + NOTES) · HANDOFF_PROMPT.md
**Current build: 3** (update only after owner says "go" at a gate). Build ONLY it, then stop at its gate.
Owner authorised the Oct 1 local continuation through revision stages 3–4 and Build 3B–3D. Current readiness: `gates/phone-test-readiness.md`; historical 3A gate: `gates/build-3.md`. Phone and visual acceptance remain pending.
Revision stages (`refs/revisions/CLAUDE_CODE_HANDOFF.md`): stage 1 (locker/armory/queue) delivered — `gates/revision-stage-1.md` (owner phone playtest pending). **Stage 2 (guns) delivered locally Oct 1**; review gate: `gates/revision-stage-2.md` (phone, visual/feel and Needlepoint balance acceptance pending); kickoff: `refs/revisions/STAGE2_KICKOFF.md`. Stages 3–4 are implemented locally for review; the owner authorised a separate phone-budget Vortex derivative and will test on iPhone 16 Pro. Owner approved and published a new private two-place Blackout Crew Phone Test (universe 10768927445); IDs and mesh API access configured. See readiness handoff for the owner link.
Read order: this file -> BUILD_PLAN.md (current build) -> SALVAGE.md -> ONLY the DIRECTIVE_GRAY.md sections in its Read map (`grep -n '^## '`, read by range). Never load the whole brief.
Rules:
- Terse, honest; disagree when warranted.
- [REC-AUTO] applies unless owner vetoed; [OPEN]/owner-only -> ask once, batched, don't guess.
- No asset generation or Higgsfield spend without owner-approved plan + cost quotes on all candidate models.
- All tunables in one Config module; numbers are placeholders.
- `~/Desktop/roblox 1` is read-only; don't copy `outputs/`.
- Mobile perf first; a test per system; owner runs phone tests.
- No agents/skills without asking owner questions first; after creating, re-crawl all files for contradictions.
- Don't build beyond the ask; confirm before any large new deliverable.
Token discipline: batch independent tool calls; read ranges, not whole files; don't re-read files you just edited; tests print summaries only; keep .md files terse; compact context at milestones; no subagents unless independent and parallel.
Gate: write gates/build-N.md, list owner phone-test steps, stop.
Oct 2: HUD v2 (heist + lobby) + daily reward **wired** (owner go): gate `gates/hud-and-daily.md` (phone test + batched questions pending). Order after that: locker/armory/queue pads -> guns + feel + Vortex -> Oceanside city last.
