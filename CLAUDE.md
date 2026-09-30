# Blackout Crew (Roblox co-op heist, phone-first; owner Enzo)
Files: DIRECTIVE_GRAY.md (design truth) · BUILD_PLAN.md · SALVAGE.md (audit of ~/Desktop/roblox 1) · gates/ (gate reports) · refs/ (owner reference images + NOTES) · HANDOFF_PROMPT.md
**Current build: 1** (update only after owner says "go" at a gate). Build ONLY it, then stop at its gate.
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
