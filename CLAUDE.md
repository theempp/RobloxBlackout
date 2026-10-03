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
Guns: concepts approved Oct 2; next = untextured image-to-3D, handoff `gates/guns-image-to-3d.md`.
Oct 2: daily reward screen (D2) + HUD v2 (`refs/hud/`) built **unwired**, held for owner 'go': `gates/daily-reward-and-hud.md`. Order after that: locker/armory/queue pads -> guns + feel + Vortex -> Oceanside city last.

## Asset pipeline: Meshy -> Blender -> Roblox Studio (agreed Oct 2)
Order: **Meshy AI** (concept/mesh) -> **Blender** (clean, budget, rig, export) -> **Roblox Studio** (import, assemble) -> `tools/build.py` embeds.
Who does what:
- **Owner (Enzo)**: authorises and owns all Meshy runs (account + credit balance). **Claude has no Meshy key or API tool**; since Oct 2 the owner authorises Claude to drive Meshy in the owner's logged-in Chrome via Claude in Chrome (credit spend still needs explicit per-run approval) — it never assumes a job ran. Codex may drive Meshy only with the key the owner configured there; whoever ran a job records credits spent and new balance in the gate (as `gates/nightcrawler-concept-review.md` does). Downloaded results land in `assets/<thing>/source/`. Owner does the Studio import/upload and all phone tests.
- **Codex** (native on the Mac): headless Blender — `blender -b -P <script>.py -- <args>`; Blender's Python needs scipy + Pillow on sys.path. Owns repeatable build/export/verify scripts and Rojo/`tools/build.py` runs.
- **Claude** (cloud + mounted folder): reads/edits every repo file and runs repo Python, but its shell is a sandboxed VM with **no Blender and no Studio** — it cannot run `blender -b`. For interactive Blender it uses the Higgsfield bridge (`bl_*`); if that reports disconnected, open the Higgsfield panel in Blender and press Connect, else hand the Blender step to Codex. Owns design docs, gates, Luau systems, review of Codex output.
Rules:
- Meshy spend obeys the existing asset rule: owner-approved plan + current quotes on all candidate models, one draft at a time, untextured geometry inspected before any texture spend.
- Every imported mesh gets: a `source/` original kept byte-intact, a Blender source `.blend`, `export/` FBX+GLB with per-piece names and design-position pivots, a `manifest.json` (piece count + tri budget), and a `verify_*.py` re-import check. Phone tri budget decides; decimate in Blender, never in Studio.
- Axis convention on export to Roblox: Blender Z-up -> Roblox `(x, z, -y)` (see `tools/export_vortex.py`).
- Nothing is "done" until the owner has run it on iPhone; agents mark Studio/phone results as pending, never assumed.
Handoff between agents: whoever finishes a stage writes the next agent's exact command(s) into the relevant `gates/*.md`, with file paths, so neither re-derives the pipeline.
