# Gate: HUD v2 (heist + lobby) + daily reward — Oct 2
Kickoff: `refs/hud/IMPLEMENT_KICKOFF.md`. Supersedes the staged gate `gates/daily-reward-and-hud.md`. Committed on owner request.
**Where the work is:** worktree `.claude/worktrees/relaxed-proskuriakova-74975c` (branch `claude/unruffled-euler-3fcae9`), including copies of the earlier staged files. The main checkout is exactly as it was before this session.

## Done
- **Daily reward wired.** `daily` profile field via `Rules.defaultProfile`/`Rules.clean` (schema 6; older saves gain a clean record). Remotes `DailyClaim` (rate limit 1/s, burst 3) and `DailyEvent`. New `src/server/DailyService.luau` (lobby only): busy lock, snapshot, `D.claim` on the server clock, save, restore on failed save, push profile. `daily` added to the profile push. `DailyRewardUI` is a lobby module, opened from the lobby HUD plate; CLAIM sends only the request. No auto-open on join (it would cover the HUD and fight the tutorial). Say if you want it.
- **Heist HUD.** `HeistHud` builds `HudV2` and feeds it: map clip, portraits, objective checklist from `BC_Step`, health from `BC_HP`. `Hud` forwards ammo, gun and reload. `Controls` places its own touch buttons at the HudRef slots (`Config.Touch` `ref`), so saved layouts and edit mode still work, and HudV2 restyles them matte. Retired: old minimap box, squad cards, heist ammo panel, settings gear. Kept: alarm meter, downed/recall line, dash timer, pings, name tags, results.
- **Lobby HUD.** New `src/client/LobbyHud.luau` + `Config.LobbyHud`, same plate style. Real data: credits, glitch coins, LVL/XP, crew, daily timer, queue pad. SHOP opens the shop. INVENTORY opens the armory loadout at the bench; elsewhere it shows a toast. SETTINGS opens settings. FRIENDS and squad "+" open the invite panel. VIP and Glitch "+" are greyed. Old floating SHOP / SQUAD / gear launchers removed. Hud's ammo panel moves to top-centre in the lobby.
- **LVL mapping:** LVL = season tier = `Economy.tier` = floor(xp / 250), 0..40. The bar shows XP inside the tier ("x / 250 XP"), "MAX" at 40.
- **Crew replication:** `Social` publishes `BC_CrewLeader`/`BC_CrewIndex` at 2 Hz so the lobby squad row can show your crew.
- Specs: new `DailyService` (16), `LobbyHud`. Updated `HudRef`, `HudHeist`, `Hud`. Details: `refs/hud/NOTES.md`.

## Tests (`python3 tools/test.py`, full lobby + heist + multi)
**1546/1554** (lobby 969/975, heist 548/550, multi 29/29). Clean HEAD baseline: 1436/1446. Remaining 8 failures are live probes in the portrait CLI window (Armory ×2, Locker, Kart, Hud ×3, HeistClient ×1), all pre-existing in baseline. Follow-up after the last edit: LobbyHud 28/28, DailyService 16/16, HudRef 24/24.
The Studio CLI play window on this Mac comes up **296x506 portrait**. Every live touch-overlap / off-screen probe runs in that window, while phones play landscape (no orientation override; Roblox defaults to landscape). The real phone layouts are checked by pure specs on six device sizes (iPhone SE … iPad, incl. iPhone 16 Pro): `HudRef.spec` (heist) and `LobbyHud.spec` (lobby, normal HUD size). Both pass.

## Seen vs not seen
- Seen (Studio Play, landscape): lobby HUD renders as in the reference.
- Not seen: daily reward screen and heist HUD screenshots (command-bar open failed; not retried). Phone test covers both.
- Also: lobby ammo panel keeps the old paper style; on desktop keyboard mode the mouse is locked, so lobby buttons need touch/gamepad.

## Owner phone steps (iPhone 16 Pro, private Phone Test)
1. Lobby, landscape: card top-left (LVL/XP match the Shop tier), pills top-right, SETTINGS/FRIENDS row, daily plate bottom-left, squad row, contract bottom-right. Nothing should sit under Roblox's top-left icons (`TopInset`) or the notch.
2. Tap each lobby button: SHOP, VIP (toast), INVENTORY (toast away from the bench, loadout at the bench), SETTINGS, FRIENDS, squad "+".
3. DAILY REWARD: open, CLAIM, then check the toast, the CLAIMED stop and the countdown on the plate. Leave and rejoin: still claimed, timer still running (reconnect persistence). Claim again: refused.
4. Move with the left thumb near the daily plate: does the plate block Roblox's thumbstick?
5. Heist: minimap + objective top-left below Roblox's icons, portraits, health/ammo top-right, cluster bottom-right (FIRE, ADS, GUN, JUMP, R, SNEAK), dock bottom-centre (MENU opens settings). Check the move stick: does a second stick (Roblox's) appear when you touch?
6. Settings > EDIT layout in the heist: drag and resize a button, then rejoin and check it persists.
7. Rotate to portrait: expect it to stay landscape. Report if it rotates.

## Owner questions (batched)
1. Reference **sprint** button: there is no sprint mechanic, so that slot is JUMP now. Add sprint (gameplay change), or keep JUMP?
2. Heist dock **BAG** and **MAP** are greyed "coming soon". Should BAG open the weapon wheel and MAP a full map, or drop them?
3. **INVENTORY**: open the armory from anywhere in the lobby (server range checks would change), or keep "go to the bench"?
4. **VIP**: what does it mean once paid items are on (pass, perks)? It stays greyed until then.
5. **Art**: icons (shop, VIP, bag, gear, friends, gift, doc, coin, cash, weapon silhouettes, HUD buttons) are text placeholders. Make an icon set? Needs an approved plan + cost quotes.
6. Daily reward: auto-open on join when claimable?

## Known gaps
- Large HUD setting: on phones the lobby bottom row can touch the fraction-placed GUN/R/FIRE buttons (spec checks normal size only).
- Move stick is a visual mirror; Roblox still moves you and draws its own stick (step 4/5).
- Old `gates/daily-reward-and-hud.md` items are done except art.
