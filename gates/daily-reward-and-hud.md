# Gate: daily reward screen + HUD v2 (staged, NOT wired) — Oct 2
Owner asked for both built and held until "go". Nothing is required from Main.client, Rules, Profiles, Remotes or HeistHud; no gameplay behaviour changed. No asset generation or upload.

## Delivered (local, unwired)
- `src/shared/DailyReward.luau` — pure rules: soft streak (lifetime claims, never reset; cycle pos = claims % 7), UTC-day claim, wrap after Day 7, clock-rollback refusal, credits cap, token / cosmetic / keepsake grants, timer text. Config: `Config.DailyReward` (7 rewards = owner list; Day 7 = `static_7` Static Face mask; no Glitch Coins).
- `src/client/DailyRewardUI.luau` — D2 look: night skyline + moon, one static ViewportFrame diorama (7 rooftop stops climbing right to the gold-trimmed vault tower, kart, 2 drones with beams, blocky props), projected DAY/CLAIMED/TODAY/LOCKED labels, reward card + CLAIM, streak / tomorrow / next-reward timer, close X. Gold glow on TODAY only (pulse), faint gold vault trim, white LED windows. Reduced motion freezes pulse/drones/claim burst. Uses `Menus` (one menu at a time, Back closes).
- `src/client/HudV2.luau` + `Config.HudRef` + `refs/hud/` — reference HUD (see `refs/hud/NOTES.md`).
- Specs: `DailyReward.spec` 40/40, `HudRef.spec` 11/11 (6 phone sizes incl. iPhone 16 Pro: on-screen, no overlaps, >=44px targets), Config 171/171. (Hud.spec shows 3 failures in a spec-only run; identical on a clean HEAD checkout, passed in the Oct 1 full regression. Full regression NOT re-run.)

## Seen vs not seen
- Daily screen: rendered in Studio Play (1st build) — layout/labels/day states worked. Then fixed: route ran right-to-left, backdrop gradient was black, TODAY glow misplaced on first open. The fixes were NOT re-viewed (Studio blocked on a system "Save changes?" sheet I may not click).
- HudV2: never viewed. Only compiled/ran headless; layout checked numerically.

## To implement on "go" (small)
Daily: add `daily = DailyReward.clean(raw.daily)` to `Rules.clean`/`defaultProfile`; remotes `DailyClaim`/`DailyEvent` (rate-limited); server `DailyService` like `EconomyService.transact` (busy lock, snapshot, `D.claim(d, os.time())`, save, revert on failed save, push profile; lobby only); add `DailyRewardUI` to lobby `ROLE_MODULES`, `UI.onClaim` -> remote, `UI.claimed` on reply, open from a garage button / on join when claimable; extend a spec for the remote path.
HUD: feed `HudV2` from `HeistHud` (squad/objective/map clip) and `Hud` (ammo/health), bind `v.buttons.*` / `v.stick` in `Controls`/`HeistControls`, retire the old panels, phone-test `TopInset`.

## Owner decisions / gaps
- Day->reward mapping is my placeholder: Credits 150, Spray Tag, Kart Decal Sheet, Ping Icon Token, Cosmetic Crate (= 1 earned spin token), Credits 300, Static Face Mask. Spray/decal/ping have no systems yet, so they are stored as "keepsakes" on the daily record only.
- Art not made (needs an approved plan + cost quotes): HUD icons (backpack, menu, map, swap, aim, sprint, bullet, weapon silhouettes), flame/padlock/gift glyphs, chamfered minimap frame, real prop/title art. Everything here is primitives + text.
- Streak shown = lifetime claims (grows past 7). Day boundary = UTC midnight. Both easy to change.
- `DIRECTIVE_GRAY.md` still has the old glow rule (white LED + gold now allowed); not edited.
