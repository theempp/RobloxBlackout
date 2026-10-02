# Blackout Crew — deep project audit

October 1, 2026 · Audit only · Original game code, assets, project mappings and existing documents unchanged.

## Outcome

The project has a coherent client/server/shared structure. Cleanup should first reconcile stale guidance, remove unused assets from shipping inputs, and stabilize validation. There is no evidence supporting wholesale deletion of source modules. The fresh full regression is **not green**: **1,435/1,446**. A separate controlled diagnostic passed **100/100** and explains eight of the eleven failures as test assumptions about randomly selected content.

No files were deleted, moved, committed, published, or uploaded. No plugins or skills were installed. This report and its supporting audit files are the only intentional repository additions.

## Scope and evidence

- Inventoried **454 files** outside `.git` before audit outputs: 191 assets, 97 Luau source files, 40 test files, 57 build files, 31 references, plus documents/configuration/tools. Source contains **13,840 lines**: 29 client, 30 server and 38 shared files, including generated art.
- Read project guidance and relevant design sections, current/historical gates and handoffs; reviewed bootstraps, module dependencies, project trees, asset generation/build tooling, purchase/persistence interfaces, role-specific karts, content variation and failing test paths. The module index is lexical; it is not a full Luau type analysis.
- No repository or ancestor `AGENTS.md` was found. The user-provided instructions apply; `CLAUDE.md` contains existing project-specific workflow guidance.
- Existing worktree: **48 tracked modified files and 61 untracked files** before audit additions. These are substantial current implementation/assets, not disposable clutter. The latest commit predates much of the phone candidate.
- **22 byte-identical duplicate groups**, with about **7.43 MB** of redundant bytes. No duplicate Luau source files. A 12-nonempty-line comparison of nongenerated source found no shared literal blocks across different files; semantic overlap still exists.
- All **17/17 Vortex approval hashes**, **4/4 locked gun-sheet hashes**, and **12/12 phone-candidate manifest file hashes** match. Approval-manifest paths were resolved relative to their snapshot; candidate-manifest paths relative to the project root.
- All project `$path` targets exist; all four project files build to valid XML in temporary output. Both RBXMX assets parse and have unique referents. The derivative has **117 unique named pieces / 6,616 source triangles**.
- **62/62 local Markdown links** resolved before adding this report. All **28 Python files** parsed successfully. `git diff --check` passed. Roblox Studio and Blender are available; Rojo, Luau analyzer, Selene and StyLua were not found on PATH. No dependency/version manifest is present.

Supporting files: [inventory and duplicate hashes](project-audit/inventory.json), [source module index](project-audit/code-map.json), [reviewable cleanup manifest](project-audit/cleanup-manifest.json), [test evidence](project-audit/validation.txt).

## Findings, ordered by cleanup priority

### 1. High — baseline tests depend on random content

The fresh unmodified-copy regression passed lobby **866/866** and two-client **29/29**, but heist passed **540/551**. Exit status was 1. Preserve this result alongside the earlier passing evidence; do not replace either with a blanket claim that the project is verified.

| Failed area | Checks | Finding |
| --- | ---: | --- |
| Alarm / downed / enemies | 7 | Wiring tests expect base bumps, while `Heist.start` randomly selects twists. `shortFuse` multiplies all bumps by two; `loudFloor` multiplies gunfire. Observed values were exactly doubled. |
| Laser layout | 1 | `Lasers.spec` tests the Data Vault beam against `Gauntlet.touching`, which uses pressure plates when the active wing is Bullion. The test does not pin the wing. |
| Heist minimap | 1 | Live minimap measured 102 px against a 110 px minimum. Its 120-unit design size becomes 102 at the allowed 0.85 HUD scale. |
| Kart touch controls | 1 | Live audit reported overlapping controls and exit/gas offscreen at the Studio viewport. The actual layout requirement fails for that viewport; device coverage needs explicit viewport fixtures. |
| Vortex render measurement | 1 | Triangle delta was zero even though mesh availability, 117-piece presence and trim-toggle checks passed. The suite reported rendering throttled, so this measurement cannot establish missing geometry or a valid render budget. |

In a separate **temporary copy only**, set `Config.Twists.Force="doublePatrol"` and pinned the run wing to `data`; the four affected suites passed **100/100**. This confirms sensitivity to content fixtures, not a clean full-suite result. All three original suites reported throttled rendering; their FPS numbers are invalid.

Recommended cleanup: keep meaningful assertions, add deterministic base fixtures, test twist/wing variation separately, record viewport dimensions in UI evidence, and treat throttled render statistics as unavailable. Do not change gameplay values simply to satisfy tests that assume another variant. The two layout findings remain unresolved; phone performance and live save/teleport behavior remain unverified.

### 2. High — historical handoffs still read as current instructions

`CLAUDE.md`, `BUILD_PLAN.md` and `gates/phone-test-readiness.md` describe the current local continuation. In contrast:

- `refs/revisions/CLAUDE_CODE_HANDOFF.md` opens by authorizing only stage 1 and says Build 3B–3D remain pending; its production-template paragraph names the old kart.
- `HANDOFF_PROMPT.md` is marked historical but directs its reader to `gates/build-3.md`, whose body is itself historical.
- `MASTER_PROMPT_QUEUE.md` contains completed coordination work, an old stage-1 starting instruction and an automation identifier whose current state was not inspected.
- `refs/revisions/REVIEW.md`, `NOTES.md` and the Vortex README contain accurate historical observations that are stale if read as current implementation status.

These files need clear historical labeling and a single current index. Preserve owner decisions and approval evidence. Do not delete substantive design rules merely because older execution instructions are superseded. The directive already has explicit precedence for matte materials and the practical-streetlight exception; its older neon wording is subordinate historical guidance, not evidence that runtime neon remains enabled.

Recommended: a root README with project map, current status and commands; one project `AGENTS.md` carrying shared workflow rules, with a concise CLAUDE bridge; archive completed prompts after updating inbound links. Keep design decisions, current implementation status and historical evidence clearly identified.

### 3. Medium — an unselected kart asset is still shipped in both places

`Config.KartModel.Template` selects `VortexKartApproved`. The older `assets/roblox/VortexKart.rbxmx` is not selected by the current runtime, but all four project mappings include the entire `assets/roblox` directory. Temporary build inspection confirmed both kart templates in every output.

The old model adds **126 XML items / 18 MeshParts**, including older uploaded mesh references, to each place. The selected approved carrier has **118 items** (model plus 117 parts), and curved runtime art comes from `VortexArt` / `VortexMeshes`.

Recommended: archive the older model outside the shipping directory, update `merge_studio_import.py` and the old integration instructions, then rebuild and smoke-test both places. Keep the selected carrier: although it is byte-identical to an approval proxy, its current runtime role makes it necessary. The asset README mentions a missing `RazorKart.rbxmx` and needs correction.

### 4. Medium — duplicate files have different preservation roles

Most duplicate bytes are the approved Vortex snapshot and matching working source/exports. The exporter explicitly verifies and reads the frozen snapshot. Deleting or rewriting it would break the approval chain.

- Keep the complete `approved-reference-cockpit` directory and its manifest.
- Keep the active runtime carrier, generated art, phone derivative and review renders.
- Matching working Vortex sources/exports can be consolidated later, but only after their tool paths, documentation and regeneration workflow are updated.
- The identical cockpit reference under `refs` is a valid convenience reference; removing it saves only 36 KB and requires link changes.
- `assets/guns/color/gun_points.json` and `detail/gun_points.json` match, but their surrounding Blender files/renders differ. The folders are distinct revisions, not duplicates.
- Several build summary logs match; current and historical gate references determine retention. Identical log contents alone do not justify deleting evidence.

### 5. Medium — scattered constants contradict the single-Config rule

`Economy` and `ShopClient` repeat the 40-tier limit, five free spins and pity boundary; `Social` and `SocialClient` repeat the 18-stud invite distance, and the server hardcodes a five-second cooldown. `HeistHud` hardcodes minimap size. `Config.Economy.Season` exists, but wheel season state is copied during profile cleaning and never reconciled with it; changing the configured season will not automatically renew free spins.

`Config.Products` still declares the old `{id, credits}` shape while the active grant path expects `{kind, amount/items}` entitlements. `EconomyService` collects a policy boolean, while the pure `paidAllowed` helper accepts a policy table; that helper is only exercised in tests and paid purchase paths remain disabled. The tests do not demonstrate a completed paid-purchase integration.

Recommended: centralize actual tunables, reconcile current receipt types/comments with the grant interface, and record season rollover and paid integration as unfinished functionality. Keep all paid switches off during cleanup. These are refactoring/implementation tasks, not reasons to delete economy or persistence code.

### 6. Low — folder naming and old asset revisions obscure navigation

RAZOR lives in `assets/kart/razor`, while Vortex lives in `assets/karts/vortex`. Guns contain blockout/detail/color/v2 production stages plus approved concept history. The older asset folders listed in the manifest total roughly **42.5 MB** and contain distinct images/models.

Recommended: consolidate the kart directory naming and index asset stages as approved references, working sources, runtime exports and historical revisions. Start with indexes and labels; path moves must update script parent assumptions and references. Retain approved gun concepts and owner review evidence. Do not flatten asset history into one folder.

### 7. Low — reproducibility and local configuration are undocumented

There is no root README, pinned Python/Blender/Studio toolchain record, or Luau analysis configuration. The project currently uses its own XML builder and Studio harness. Document the commands that actually work before adding tools.

`.claude/settings.local.json` is local permission configuration and is not tracked. The current `.gitignore` does not explicitly exclude it or Blender `.blend1` backups. Review its retention/ignore policy without committing local permissions. `.git` is about 119 MB and is recovery history; do not prune it as part of this cleanup.

## Code overlap: retain now, refactor selectively

| Area | Assessment |
| --- | --- |
| `GarageKarts` / heist `Karts` | Shared model and physics are already centralized. Driver mass, entry/exit and stale-input handling overlap semantically. Extract small shared helpers only after tests are stable; preserve heist sabotage, repair, payout and anti-cheat differences. |
| `Controls` / `HeistControls` | General weapon/movement controls versus contextual heist actions; complementary. |
| `Hud` / `HeistHud` | UI primitives/scaling versus run-specific panels; complementary. |
| Client/server gun state and art data | Prediction/presentation versus authoritative validation; generated data is intentional, not duplicate code to remove. |
| Lobby/heist client probes | Different commands and role coverage; keep separate. |
| Four project JSON files | Lobby/heist and shipping/test variants; all four serve current build/test commands. |
| Legacy gun primitives | Scatterpop/Rattler remain in the six-gun roster. Four approved gun art sheets did not remove their entitlements. |

No source file is approved for removal by this audit. Small refactoring opportunities should not become a replacement monolith, particularly given the prior Luau register-limit failure.

## Reviewable cleanup sequence

1. Preserve a recoverable snapshot of the existing tracked modifications and all 61 untracked files before destructive work. Git HEAD alone is insufficient.
2. Add the project index/current-status entry point; label/archive completed handoffs and reconcile stale asset documentation.
3. Review the explicit deletion manifest. Cache files, four Blender automatic backups and old liveness/progress logs total **1,211,755 bytes (~1.21 MB)**. The Blender backups differ from their current files; confirm they are not needed for recovery before deleting them.
4. Archive the old unselected runtime kart and organize historical asset folders with coordinated tooling/link updates. Preserve manifest-bound candidate artifacts and final evidence.
5. Stabilize test fixtures and viewport/render evidence; perform small Config/type/helper refactors with behavior tests. Rebuild both shipping places and run applicable regression/smoke checks.
6. Reverify approved hashes and links, document the resulting tree, then begin the separate plugin/skill selection discussion. No plugin installation is part of this audit.

This report proposes cleanup; it does not authorize new gameplay scope, publishing, paid generation, global skill changes, or deletion of protected files.
