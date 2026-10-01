> Historical Build 1 prompt. For current work follow CLAUDE.md and gates/build-3.md.

You are building **Blackout Crew** (Roblox, phone-first co-op heist). Do **BUILD 1 only**, then stop at its gate.
Project: `~/Desktop/Blackout Crew`. `~/Desktop/roblox 1` = read-only reference (old v0.3 game).

**Read first, nothing else:** `CLAUDE.md` -> `BUILD_PLAN.md` (Build 1) -> `SALVAGE.md` -> only the DIRECTIVE_GRAY.md sections BUILD_PLAN lists for Build 1 (§4 §5f §6 §15 §16; `grep -n '^## '`, read by range, never the whole brief).

**Before coding (report in ≤10 lines):**
1. Toolchain: locate Roblox Studio, prove the CLI works (`--task RunScript --localPlaceFile <abs> --runScriptFile <abs> --outputFile <log> --quitAfterExecution`), check Rojo/aftman. Choose the pipeline (Rojo preferred). Old `package.py` is not reusable.
2. Spot-check each SALVAGE "Port" file before copying it.
3. List real owner-only/[OPEN] blockers. Ask ONE batched question round only if a blocker exists; otherwise proceed. Then post a ≤15-line plan (layout, order, tests) and continue without waiting.

**Build (BUILD_PLAN Build 1, in order):** repo layout + `git init` if absent -> port Rules.clean (new schema), Profiles (`BlackoutCrew_Profile_v1`), receipt pattern, HUD scale/safe-inset helpers, test harness + frame probe -> Config module (all tunables, placeholders), logging, perf overlay toggle -> guns -> touch controls -> test range.
Guns: server-authoritative hitscan (client sends aim only; server validates rate, ammo, range, line of sight; rate-limit remotes), per-blaster deterministic recoil pattern countered by drag-down, ADS, hit + damage markers, light aim assist (slow-down only, settings toggle), attachment data model (sidegrades), 6 placeholder foam-tactical primitive blasters (1 free + 5 priced 1k/3k/6k/10k/15k Credits), 5-slot wheel (3 usable + 2 "Coming Soon"). Touch per §5f: two-thumb, movable/resizable buttons, tap = swap last, hold = radial (2L/2R/1T), keyboard/gamepad fallback. Engraving via one swappable decal layer.
Perf: tri budgets (§6), no per-frame allocation, pooled effects, StreamingEnabled, low remote traffic. Targets: ≥30fps low-end phone, 60 mid (owner supplies device numbers; you cannot test phones).
Tests: one Studio-CLI suite per system (profiles/clean, receipts, fire validation, recoil, wheel, config), plus client-compile probe (server pass ≠ client OK). Report pass/total only.

**Hard rules:** No lobby, heist, karts, economy UI, spin wheel, generated assets, Higgsfield, publishing, or new agents/skills. Never edit `roblox 1`. Don't guess [OPEN] items. Disagree with the design when warranted; be terse and honest.

**Credit discipline:** batch independent tool calls; read ranges not files; don't re-read edited files; test output = summaries; commit per system; compact at milestones; think deeply only on architecture and gun feel, keep mechanical porting lean.

**Gate:** write `gates/build-1.md` (≤1 page: tests, perf, gaps, decisions made, owner phone-test steps incl. Studio Test -> Device fallback and the maturity questionnaire), update nothing else, tell the owner, stop. Do not start Build 2.
