# Directive Gray — Full Project Brief
*Status: v1 design complete. Build only per BUILD_PLAN.md, one build at a time, stop at each gate. NOTHING gets generated (Higgsfield etc.) until owner says "go" on an approved plan, after cost quotes on every candidate model, ranked.*

Legend: **[LOCKED]** = owner decided. **[REC]** = Claude recommendation, not yet confirmed. **[OPEN]** = undecided. **[REC-AUTO]** = Claude default, applies unless owner vetoes.

**Read map (load only the current build's sections; `grep -n '^## '` then read by range):** B1: §4 §5f §6 §15 §16 · B2: §3 §3b §5 §5b-5e §5h §7 §11 §17 · B3A: §9 §10 §11 · B3B: §5g §5i §12 · B3C: §5c §8 §17. §2/§18 = pitch/summary.

## 1. Basics
- Roblox game, phone-first. Audience ~9-17. Owner: Enzo, building solo with Claude.
- Goal: fastest path to launch (ASAP). No hours/week given. Most of the game already exists in the old Directive Gray project.
- Branding: logo/emblem, military insignia, "DG" monogram.
- Name: **Blackout Crew [LOCKED, pending trademark check]**. Check USPTO classes 9/28/41 + attorney; no Roblox game of that name found (thin search). Also check "Directive Gray".
- Owner wants every missing detail gathered first so the build happens in one go.

## 2. Pitch [LOCKED]
Redesign from Jailbreak-style cops-and-robbers into **co-op heists against the Directive**, a fictional megacorp's AI security. Crews up to 4. No Police role, no PvP.
- Fantasy: heist nerves with friends, tension + cooperation, light humor.
- Soft fails: lose run loot, not progression.
- Tone: neon-cool heist comedy + noir-lite; deadpan Directive.
- Look: colorful "glitch" identity vs the gray Directive.

## 3. Core Loop [LOCKED]
Garage lobby → queue as squad → teleport → drive to tower (highway cutscene) → infiltrate vault, grab heavy loot → escape by kart through a fixed 8-10 block neon Brickell-style city (fictional brands) → rewards saved → back to lobby.

## 3b. Heist Kart Mechanic [LOCKED, details OPEN]
- Each player has their own one-seat kart. Game guides step-by-step: where to park. Kart stays at its spot the whole heist.
- Karts must be hidden. If Directive repo drones find one, they **sabotage** it (disabled: flat tires/lock-down). No towing, no impound.
- **Repair [LOCKED]:** any teammate repairs it via a short (~5-10s) cooperative minigame. Optional pay-to-skip in earned soft currency only (never Robux) (kept; see §5d, §5g).
- **Repo drones [LOCKED]:** short patrol loops covering a few stash zones, vision cones, sabotage after N seconds of continuous sighting (short loops avoid guard stacking/chain fails). N, loop count, repair time: see §5d [LOCKED].
- After the vault: exit building, sneak through a couple of buildings to the kart, escape. Loot always counts.
- [REC] Marked stash spots with varied hiding quality (closer to exit = more visible). Tune to be tense, not punishing.

## 4. Keep / Change / Cut
- **Build approach [LOCKED]: selective salvage.** Old project audited (folder `roblox 1`, v0.3 cops-and-robbers, 179/179 Studio checks, ~60fps Mac only, no phone/20-player/live-save tests; private place 85367345143911, v0.3 publish unconfirmed). Keep infrastructure; rebuild gameplay fresh.
- **Salvage:** full audit in SALVAGE.md (port/defer/skip + gotchas). Caveats: `package.py` depends on the old city file (replace); mobile HUD code lives inside the 1,320-line client (extract, don't port). Summary of what was verified: `Profiles.luau` (DataStore + session lock), `Rules.clean` (save validation), receipt idempotency, shop tabs/cosmetics framework, XP/season track, crews (4, haul bonus), mobile HUD scaling/safe insets/accessibility, weapon-wheel input logic (list-based now), `Vehicles.luau` raycast-suspension physics (+36 driving tests) as kart base, Studio CLI test harness (pattern only; `package.py` is NOT reusable: it depends on the old city file).
- **Rebuild fresh:** guns (currently blocky parts, hitscan stats only; no attachments in config; ADS/recoil/hit markers not evident, unverified), police/arrest/PvP, open city, masks, vault/tower, kart bodies, lobby.
- **Known debt:** `Main.client.luau` (1,320-line monolith, hit Luau 200-register limit) is NOT ported; extract helpers only (SALVAGE.md).
- **Cut:** Police role, PvP.

## 5. Heist Gameplay [LOCKED]
- **Vault:** physical infiltration: lasers/traps gauntlet, carrying heavy loot. No sprint/kart until back at the parked kart. Forgiving touch controls.
- **Tower:** one new stylized tower; randomized vault, guard routes, and a twist per run.
- **Enemies:** Directive bots, drones, cameras only (no human deaths, no human cops). Kart-finding threat = Directive repo drones. Players get downed and are revivable before bleeding out. Gunfire escalates the alarm.
- **Performance:** mobile frame rate is top priority everywhere; use streaming.
- **Scaling:** solo/duo allowed with difficulty scaling.

## 5b. Heist Tuning — Batch 2A [LOCKED Sept 29]
- **Run length:** ~9 min arrive→lobby (~5 inside, ~3 escape, ~1 buffer). Target 2 runs/session (19+ min band; Roblox 2025 benchmark: median D1 11.5% at 19-24 min avg session vs 7.9% at 7-12).
- **Alarm:** 3-tier meter (Quiet → Lockdown → Purge). Gunfire = big bump, camera sighting = small, downed teammate = medium, slow time creep. Tiers add enemies + laser speed. Tier drops only via hack objective.
- **Enemies (owner chose smaller than REC):** 3 types: Sentry bot (patrol), Camera (sweeping, hackable), Watcher drone (Tier 2+). Cap ~8 active AI; scale x0.5 solo / x0.75 duo. Enforcer cut (post-launch candidate). Tier 3 = more sentries/drones + faster lasers. Cap is a guess until low-end phone test.
- **Heavy loot:** 1 per player, ~40% slower, gun holstered, drop/hand-off allowed, solo-able (no forced 2-person lift). Banks when loaded on your kart; kart holds 1 heavy item.
- Loot conflict (§2 vs §3b) resolved in §5d payout table.

## 5c. Heist Variety — Batch 2B [LOCKED Sept 29]
- **Structure:** Modular Remix: one tower, 3 vault wings, 6 twists, 3-4 preset guard-route sets; one of each per run.
- **Downed:** bleed-out 25s; teammate revive 3s hold; 1 self-revive ("Override") per player per run (covers solo/duo). Bleed-out ends → "recalled": respawn at tower entrance after 30s, drops carried loot. Run fails only if whole crew down at once. Numbers = design judgment, tune in 1B playtest.
- **Twists (6, mostly param flips):** Blackout (lights out), Double Patrol, Laser Storm, Short Fuse (alarm 2x faster), Glitch Surge (doors reroute), Loud Floor (gunfire alarm 2x).
- **Vault wings (3):** Data Vault (hackable lasers), Bullion Vault (heaviest loot, pressure plates), Prototype Lab (fragile loot; falling/downed drops it). Only chosen wing streams in.

## 5d. Escape — Batch 2C [LOCKED Sept 29]
- **Flow:** sneak through 2-3 buildings to kart (repo drones hunt), then timed kart dash (~75s) to exit gate; pursuing drones EMP karts (spin/slow, no kills). Tower AI streams out on exit, freeing the ~8-AI budget.
- **Payout (resolves §2 vs §3b):** loot never hits zero; small loot/cash always 100%. Heavy loot: Clean = 100% + bonus, Rough (sabotaged, repaired) = 90%, Timed-out/caught = 50%. Banked per player at the gate.
- **Repair:** 3-step timing wheel; ~6s one teammate, ~3s with two, ~10s solo self-repair. Skip = soft currency only, ~10% of avg run payout (exact coins in economy batch). Never Robux.
- **Drone sabotage:** 4s continuous sighting at Quiet / 3s Lockdown / 2.5s Purge; visible fill ring on kart, drains at half speed when drone looks away. 2 drones on route +1 per alarm tier (max 4); ~20-25s loops.
- **Glowed-up parking spots [owner]:** count = squad size (solo 1, duo 2, trio 3, squad 4), differs per round; each spot glows in its player's tag color. **[REC-AUTO]** pool = 15 spots (3 zones x 5: per zone 1 obvious near exit, 2 medium, 2 well hidden); each round draws squad-size spots from >=2 zones; no player gets an obvious spot twice in a row. Own spot = bright beacon visible through walls; teammates' = faint outline within ~60 studs + on minimap. Client-side UI only; drones ignore glows.

## 5e. HUD & Colors — Batch 3 [LOCKED Sept 29]
- **Style [owner]:** minimalist, plain; only the most useful info. Buttons in corners/borders; nothing mid-screen except small, centered-top items. Minimap at a decent phone scale, top-left BELOW Roblox's own menu/chat icons (respect notch/safe insets; salvage old HUD scaling code).
- **Minimap [owner override of REC]:** squad in their colors, own parking spot, exit gate, objective pins. Enemies pinged LIVE by proximity: marker appears on map or screen as you get close. **[REC-AUTO]** markers fade in 45->30 studs (full at <=30), proximity only (no line-of-sight test; cheap). Purge jams radar: radius 20 + flicker. Hacked camera drops off map.
- **Squad cards:** name + color badge, health bar (becomes bleed-out ring when downed), heavy-loot icon, kart-status dot (hidden/spotted/sabotaged). Solo = own card only; shrink to name + badge when calm.
- **Colors [owner override of REC]:** 4 fixed neon colors by squad slot, COLOR ONLY (no shapes). Same color on tag, minimap dot, parking glow. Risk: ~8% of males colorblind; mitigation = CVD-distinguishable palette + always show name text. **[REC-AUTO]** palette (Okabe-Ito base): slot1 sky blue #56B4E9, slot2 orange #E69F00, slot3 green #009E73, slot4 pink-purple #CC79A7; no red (alarm) or yellow (roll-up door). Brighten via emissive; verify in a CVD simulator.
- **Parking glow:** own spot bright, teammates' spots faint outline in their color.

## 5f. Touch Controls — Batch 4 [LOCKED Sept 29]
- **Aim/fire:** classic two-thumb: left stick move; drag right half to aim; big Fire bottom-right; ADS toggle above-left of Fire; optional mirrored Fire on left edge (3-finger). All buttons movable/resizable in settings (salvage old accessibility code). Override Roblox default jump-button spot.
- **Recoil/assist:** learnable per-blaster recoil pattern countered by dragging down + LIGHT aim assist (slow-down over targets, no snap; settings toggle). Tune in 1A gun-feel test.
- **Wheel:** tap weapon icon = swap to last-used; hold = radial (2 left, 2 right, 1 top), slide + release to equip; Coming Soon slots show teaser.
- **Actions [owner: "1 and 3 mix"]:** contextual action button that appears only when something is in reach (revive/repair/hack/pick up/drop/hand-off), HOLD to perform (proximity-hold flavor). Plus Jump + Sneak toggle. Multi-target priority [REC]: revive > repair > hack > pick up. [CONFIRM] interpretation.
- Note: "roblox 1" wheel input code not reviewed (folder not connected); check at build.

## 5g. Economy — Batch 5 [LOCKED Sept 29; all numbers are alpha placeholders]
- **Currencies:** Credits (earned from loot) buy guns, attachments, repair skip. Glitch Coins (Robux) buy cosmetics, bundles, pass. Premium never buys power or repair skip. Credits never sold for Robux.
- **Values:** avg clean run ~1,000 Credits; repair skip ~100; 6 guns = 1 free starter + 5 priced at 1,000/3,000/6,000/10,000/15,000 [REC-AUTO fix]; attachments 300-2,000. Guns alone = 35,000 = ~35 runs; [REC-AUTO] most attachments come via progression/pass so total stays ~40 runs (~5h); 1st priced gun in ~1 run.
- **Season pass:** 6 weeks, 40 tiers, free + premium tracks (both get sidegrade attachments; premium adds cosmetics). 599 Robux (~$7.50; unverified vs comparable games — check 3-5 top games before ship). No XP boosts, no tier-skip sales at launch. ~$1.59 net/sale (70% share x $0.0038/Robux DevEx, verified Sept 30; earlier ~$1.00 was an arithmetic error; before taxes; DevEx min 30k Robux, 13+, W-9/8).
- **Bundles [owner: all in]:** cosmetic bundles (blaster skin + kart skin + mask + emote) at 199 / 499 / 999 Robux, rotating weekly. Cosmetic-only crate + spin wheel both in v1: wheel in 3B after the crate, paid side behind a kill switch (§5i). Compliance: full numerical odds for crates AND indirect items (keys, spin tickets, Glitch Coins); PolicyService fail-closed; restricted users get an alternative (§5i).

## 5h. Stealth Numbers [REC-AUTO, tune in playtest]
- Walk 16, sneak 8 studs/s (sneak = toggle). Noise radius: sneak 6, walk 15, gunfire 60 studs (gunfire also = alarm bump, §5b).
- Sentry: 70° cone, 35 studs, plus noise radius. Camera: 90° sweep, 45 studs, hackable.
- All unverified placeholders; tune in Build 1/2 playtests.

## 5i. Spin Wheel [LOCKED Sept 30; all numbers = Config placeholders]
- **Free wheel:** 5 spins/account/season; grand prize guaranteed by spin 5 = top-tier kart at level 1 (Credits-upgradable; all karts within <=15% stat spread, so sidegrades) + saved heli entitlement (redeemable when heli ships; "Coming Soon").
- **Paid wheel:** season-themed, 12 segments, no duplicates, cosmetics only. 199 Robux/spin; 5-pack 799 Robux (~20% off; fits the 800-Robux bundle; owner-chosen, REC leans against: review after spin data). Tier odds Common 60 / Rare 25 / Epic 11 / Legendary 4 (%). Hard pity: Epic+ by spin 6 (counter shown in odds UI). Legendary = animated Season 1 set. Never awards Credits or Glitch Coins; never power.
- **Pop-up:** max once/day, only when new content. Lobby-only, dismissible, no countdowns. Suppressed in tutorial, queue, invites. (Supersedes "welcome every join".)
- **Compliance [researched Sept 30]:** server-side PolicyService (`ArePaidRandomItemsRestricted`; regulated: AU, BE, NL, UK, BR), fail closed. Restricted users: earnable spin tokens (no permission pop-up). Odds for every outcome incl. pity shown before purchase, sum 100%, labeled "Details" button (icon alone insufficient); every result gives a benefit. Robux-bought currency/tickets count as paid random. Test with Studio Player Emulator. Free spins need no odds display.
- **Build:** 3B after crate; paid side behind kill switch (Config flag). After v1: kart upgrades, Robux parts shop (sidegrades/cosmetics only).
- **Season 1 = "Neon Static" [REC-AUTO, veto ok]:** CRT/VHS-glitch neon; fits the locked glitch-vs-gray identity; palette swaps + emissive only, so cheap on mobile perf. 12 segments (per-item odds, %): Common x6 @10 (dart tracer, plate frame, spray tag, blaster charm, ping-icon pack, kart decal); Rare x3 @8.33/8.33/8.34 (mask "Static Face", wheel glow, emote "Buffering"); Epic x2 @5.5 (blaster skin, kart skin); Legendary x1 @4 (animated full set: blaster+kart+mask+emote).
- **Dupes/odds:** no duplicates; owned items drop out and odds renormalize to 100 (Roblox requires dynamic odds update); UI shows live odds + pity counter; fully owned = wheel hidden. Ships with the theme's item list only; final art via review (§17).
- **Unit economics:** paid spin 199R = ~$0.53 net; 5-pack 799R = ~$2.13 net (70% x $0.0038; ~$0.0054 on eligible US 18+ age-verified buys).
- **Kart roster v1 [REC-AUTO]:** 2 karts: Base (free, all) + Top-tier (free-wheel prize, <=15% better stats). Guaranteed by spin 5, so effectively universal: a retention hook, not exclusivity. Credits upgrades ship post-v1, so v1 top-tier = fixed stats.
- **Kids/Select [researched Sept 30]:** Kids 5-8 = Minimal/Mild labels only; Select 9-15 = up to Moderate; 16+ Moderate; 18+ Restricted. [REC-AUTO] target Mild (foam darts, no blood, robots downed not killed) so both Kids and Select can play; answer the questionnaire honestly (incl. paid random items). [REC-AUTO] hide paid wheel for Kids (5-8) accounts; no API found to detect it, so verify at build.
- **Open (owner-only):** 5-pack keep/drop after spin data; final questionnaire result.

## 6. Guns [LOCKED unless noted]
- Fictional names only; frame rate prioritized in production.
- **Look [LOCKED Sept 29, supersedes GTA-stylized-realism]: "foam-tactical"** — chunky foam-dart blasters, matte black, NO neon/emissive strips [owner override Sept 30: no bright neon lights on guns/cars/etc.], punchy (not squeaky) sound, tailored/tweaked per owner. Robotic enemies, no blood. Generic foam-blaster design only: NO "Nerf" name or copied Hasbro models (trademark). Still run Roblox maturity questionnaire on Phase 1A prototype to confirm label (Minimal/Mild = Kids 5-8 + Select 9-15; Moderate = Select 9-15 + 16+; Restricted = 18+ verified; source: create.roblox.com content-maturity).
- **Branding on props [LOCKED]:** game name + owner logos (DG monogram, insignia) engraved on every item (guns, darts, attachments, karts, etc.). Risk: name is pending trademark check — engrave via swappable decal/texture layer so a rename is cheap.
- **Asset pipeline:** Blender allowed → import to Roblox Studio. **[REC-AUTO]** tri budgets (guess; verify on low-end phone): first-person gun <=5k, world gun <=1.5k, kart <=8k. Placeholder primitives first; final art only after gameplay proven. Nothing generated until plan approved + cost quotes.
- **Ownership:** players own every gun they unlock (no cap).
- **Weapon wheel: 5 slots.** Equip 3 at launch; the other 2 are faded-in "Coming Soon" slots, unlocked by a later update. Launch cut ~6 guns = owned pool, 3 equipped.
  - [REC] Layout 2 left, 2 right, 1 top (no bottom slot, thumb covers it on phones). Faded slots tappable with a teaser ("Unlocks Season 1 Week 3").
- Attachments via progression + season pass; sidegrades on both free and premium tracks.
- **Feel [LOCKED Sept 29]:** foam-blaster look but REAL gun feel: real recoil, hit markers, damage markers, ADS.
- Feel refs (3 Roblox FPS videos: snow/industrial realistic shooter, stylized pink-skin duel game, Phantom-Forces-style): wants their attachments, movement, ADS scoping, hit markers, recoil.
- Mobile touch controls: see §5f [LOCKED].

## 7. Vehicles [LOCKED]
- Go-karts only at launch: matte black, numbered, chunky/stylized.
- One drone-helicopter concept: cosmetic skins only, "Coming Soon" in lobby. Phone-call helicopter drop = later feature.
- Kart tiers (Sept 30): one top-tier kart = free-wheel grand prize (§5i); Credits upgrades, <=15% spread. Heli: wheel grants a saved entitlement, redeemable when heli ships; skins stay cosmetic-only.
- Wants a couple of go-kart concept options generated once more references are sent (only after plan confirm + cost quotes).

## 8. Audio [LOCKED]
Sound effects on everything: karts, tire screech, helicopters, drones, robots.

## 9. Garage Hub (Lobby) [LOCKED, designed Sept 29-30]
**Overall:** one open building, asymmetric, no clean shape: a massive main hall with very tall ceilings, a wide racetrack area, a separate armory, plus small open hallways and rooms. **No doors anywhere except the yellow roll-up garage door.** Tall ceilings in every room. [REC] Break long sightlines with bends/walls (no occlusion in open layouts; helps frame rate).
**Look everywhere:** black-on-dark-wood with beautiful LED lighting throughout.
- [REC] Achieve LED look with emissive strips/neon parts; few real dynamic lights (armory only) for mobile perf.
- [REC] Ceiling heights: main hall ~3x a normal room, armory ~2x.

**Size [REC-AUTO]:** footprint ~300x250 studs; main hall ~120x80, ~45 tall; armory ~50x40, ~25 tall; track lap ~25-30s. StreamingEnabled in lobby from day one.
**Kart customization at launch [REC-AUTO]:** cosmetic skins + number plates only, no performance parts; underglow = squad color. Only stat difference = wheel's top-tier kart (§5i).

**Main hall:** yellow roll-up door (cars drift out in a cutscene), Fortnite-style queue pads, drone showcase in one corner. Spawn faces the roll-up door with queue pads in frame; the tutorial (below) handles first-time direction.

**Kart track (the wow factor):** multi-level, runs around the ENTIRE garage. Clear elevation: big ramps down, big ramps up, small ramps up, small ramps down, and ramps overlapping/crossing the track itself. Not a simple loop.
- Launch rules [LOCKED]: free driving, no timer, no rewards. Best-lap board post-launch.
- [REC] Build in modular pieces, wide banked ramps; test kart physics + touch driving on a low-end phone early (biggest technical risk).

**Armory:** own dedicated open room, high-end and exclusive-looking, black-on-dark-wood, LED lighting. Where players buy guns, attachments, etc., and use the weapon wheel setup.
- Layout [LOCKED]: wide doorway off the main hall; backlit gun wall; attachment bench in the center; wheel setup on a pedestal terminal (buy → attach → equip in one spot).

## 10. Tutorial / Onboarding [LOCKED]
First visit, **skippable**, target under 90 seconds. Wide **white** glowing path with visible arrows (color flexible if a better one is found).
1. Grab a gun in the armory and walk out.
2. Meet the friend **scripted NPC** (every player gets it, even solo) outside the armory.
3. Short back-and-forth conversation with the NPC.
4. Conversation leads to both joining each other's squad (teaches the squad system).
5. Walk to their go-karts, parked a bit off in the distance.
6. Take the kart to the queue pad, squad ready.
(Optional kart lap dropped from the flow; the track itself is free driving anytime.)

## 11. Servers & Social [LOCKED]
- Public Lobby place (kept below max capacity so friend-joins work) + private 4-player Heist place via teleport (crew size + difficulty passed).
- Retry failed teleports once; save rewards at heist end; late joiners skipped.
- Social: 2K-park style walk-up invites; squad max 4 queues together; friends-tab joins; decline, mute, block, invite cooldown.

## 12. Monetization [LOCKED unless noted]
- Free + premium season pass. Bundles/packages/deals are the main revenue.
- **Currencies [LOCKED]:** soft currency (earned from loot: guns, attachments, cosmetics, optional repair skip) + Robux-bought premium currency. Premium = cosmetics/bundles/pass only, no power, no repair skip. Gate random items via PolicyService; verify compliance for under-13s. Prices/conversion: see §5g.
- Season 1 = 6 weeks. Launch ASAP.
- Crates + spin wheel: see §5g, §5i; wheel ships in 3B (§13). Paid-random/odds policy researched Sept 30 (§5i); Kids/Select researched (§5i) (audience 9-17).

## 13. Build Order
- **Phase 1A:** gun-feel slice first.
- **Phase 1B:** loop slice (lobby/garage, tower, kart escape).
- [REC] Staged launch: closed alpha (50-200 testers, Discord) → open beta → public. Key alpha metric: first sessions lasting 15+ min. Roblox discovery weighs D1/D7 retention and session length; don't open-launch a thin game.
- **[REC-AUTO] Scope:** hours/wk assumed 25-30 (owner to confirm; no dates until confirmed). Alpha: 100 testers via Discord (friends first, then 2-3 Roblox groups) -> open beta -> public. Launch content: 1 tower, 3 wings, 6 twists, 3 guard sets, 6 guns, 1 crate, spin wheel (3B, paid side kill-switched), season pass. Cut from launch: drone skins, helicopter drop.
- **Build plan:** see BUILD_PLAN.md (3 builds, gate after each).
- [REC] Start a Discord now (top launches start 2-4 months early).

## 14. Risks
- Mobile frame rate (realistic guns + LED garage + streaming city). Mitigate: emissive strips, streaming, early low-end phone tests.
- Multi-level kart track physics on touch.
- Solo build scope; content amount vs ASAP launch.
- Paid random rewards + young audience (policy/compliance).
- Weak early retention signals hurting discovery.

## 15. Open Items
- **Owner-only:** trademark check "Blackout Crew"/"Directive Gray" (USPTO 9/28/41 + attorney); Roblox maturity questionnaire on Build 1 gun prototype; confirm weekly hours; compare pass price vs 3-5 top games; verify retention benchmark (§5b); maturity questionnaire result (Kids/Select + paid-random rules researched, §5i); veto Season 1 "Neon Static" wheel list.
- **Owner review:** veto any [REC-AUTO]; item-by-item visual review (§17) during Build 2.
- **Check at build:** toolchain (Studio CLI, Rojo); low-end phone perf (owner supplies device results). Old wheel/HUD code already audited: SALVAGE.md.
- **Owner-only:** publish target for dev builds (rec: reuse old private place 85367345143911).

## 16. Working Rules (owner preferences)
- Compact, token-efficient responses and files; keep substance.
- Honesty over agreeableness.
- Every design question includes Claude's recommendation backed by current data; 3-4 questions per batch plus 2-3 concept options first.
- Never generate agents/skills without a full question round first; after generating, re-crawl every project file for contradictions.
- Answering questions or uploading files is NOT a green light to build: confirm explicitly first.

## 17. Visual Review Plan [REC-AUTO]
- Order: guns (6) -> darts + tracer -> attachments (sight/muzzle/grip/mag) -> karts (body, wheels, number plate, underglow) -> masks -> enemies (sentry, camera, watcher, repo drone) -> loot/props.
- Per item: 1 concept sheet (front/side + logo spot); owner approves/vetoes in batches of 3-4. Runs during Build 2, before Build 3 final art. No generation until plan + cost quotes on every candidate model.
- Engraving: one swappable decal zone per class: gun left receiver; kart hood + rear; dart base; attachment side plate. Rename = swap texture.

## 18. One-Page Summary [REC-AUTO draft]
- **Pitch:** phone-first Roblox co-op heists (crews of 4) vs the Directive AI megacorp; ages 9-17; no PvP.
- **Loop:** garage -> queue -> tower infiltration (~5m) -> hidden-kart escape (~3m) -> payout -> garage.
- **Keep/Change/Cut:** keep infra (saves, shop, UI, crews, tests, kart physics); rebuild gameplay; cut police/PvP.
- **Build:** 3 builds (BUILD_PLAN.md) -> closed alpha (100) -> beta -> public; Season 1 = 6 weeks.
- **Money:** 599R pass + rotating bundles + crate + spin wheel (199R/spin); nothing paid buys power.
- **Risks:** §14.
