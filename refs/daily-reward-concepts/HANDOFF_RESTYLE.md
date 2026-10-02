# Handoff: restyle the Blackout Crew daily-reward concepts

Owner (Enzo) rejected round 1 (`A1 A2 B1 B2 C1 C2 .png` in this folder): "super plain and basic". His three original references (`../daily-reward-originals/1.webp` Vault Spin, `2.webp` Loot Express, `3.webp` Rooftop Streak) are far ahead. Goal: redo all three concepts at THAT quality, tailored to Blackout Crew. Do not defend round 1.

## Why round 1 failed (my mistake)
- Prompt said "matte flat colors, no glossy shine, no glow, no bloom". That erased the quality the refs have.
- Result: flat 2D sticker UI, plain panels, little depth, no hero 3D props, garbled small text.

## What the references do (analysis, copy this)
- **Hybrid 3D + 2D.** Hero props are rendered 3D, chunky Roblox-blocky, with bevels, specular highlights, soft contact shadows (cash stacks, golden key, crates, gems, claw, safe, bat-wing drone). UI chrome is layered 2D on top.
- **Real set dressing / scene depth.** Each is a diorama: blurred depth-of-field background (vault/city street; construction-site conveyor world; night rooftops with moon), blurred foreground props, bokeh. UI sits IN a world.
- **Framing hardware.** Vault Spin: riveted steel frame, bolts, heavy ring, brushed-metal bevels, red accent plates. Loot Express: yellow/teal machine frame, conveyor belt, claw. Rooftop Streak: no frame, the rooftops themselves ARE the layout (isometric path of arrows).
- **Title lockup is an illustration.** Extruded/beveled 3D lettering with stroke + gradient + a mascot prop (train, city skyline silhouettes, spray-torn edges). Two-tone word split (white/red, yellow/teal, white/orange).
- **One strong palette per concept** (steel+crimson+gold / yellow+teal+navy / navy night+orange+purple gem), with one accent for the hero state.
- **Hero state hierarchy.** Today = biggest, lit/raised, callout (speech bubble, side panel, claim card). Claimed = green check badges. Locked = dim + padlock pill. Lots of small pill labels with dark fill, small bold caps.
- **Always present:** title, 7 days, today card, giant CTA, streak, reset timer, close X, "tomorrow/next" teaser. Full-bleed 16:9, no empty margins.

## Blackout Crew constraints (from DIRECTIVE_GRAY.md, owner-locked)
- Co-op heist vs the Directive (gray megacorp AI); our identity = colorful "glitch" vs gray. Deadpan humor, kid-friendly (9-17), no blood, no real guns shown, robots "downed".
- Squad colors: sky blue #56B4E9, orange #E69F00, green #009E73, pink-purple #CC79A7. Avoid red/yellow as STATE colors.
- UI precedence (Sept 30): warm off-white rounded panels, dark outlines, bold headings, flat colorful pills, sticker-like cards. Owner now wants the refs' richer look; blend, don't drop it.
- Currencies: Credits (earned), Glitch Coins (premium). Rewards used so far: Credits, Spray Tag, Kart Decal, Ping Icons, Static Face Mask (Season 1 "Neon Static"), spin ticket. Premium never buys power.
- Fictional brands only (no real place names; round 1 used "Brickell"/"Biscayne Bay" in B1, remove).
- **DECIDED (owner, Oct 2): soft glow allowed on the TODAY item only; still no neon.** Keep 3D specular highlights and rim light. No neon-colored or emissive glow elsewhere. Do not re-ask this one. Remaining questions (timer, reward types) still open.
- **(Superseded for glow, see above) original note:** DIRECTIVE_GRAY.md says "no neon/emissive" on guns, karts, garage, city (owner override Sept 30). His refs rely on warm glow/bloom on the TODAY item and glossy highlights. Proposal to confirm: no neon-colored/emissive glow; DO allow 3D specular highlights, rim light, soft warm spotlight on the today prop. Also earlier open Qs (defaults used: rewards = Credits/cosmetics only, soft streak that pauses, Day 7 = Static Face Mask; §5i says no countdowns on wheel pop-up, so confirm a reset timer is OK here).

## The three concepts to restyle (keep the ideas, upgrade the craft)
- **A. Dead Drop**: garage locker room. 3D metal lockers (dented, stickers, key tags, a crown-emblem duffel), 7 lockers on a row or arc, today's locker door swung open with the reward lit inside, 3D props (Credits cash stacks, spray can, kart decal sheet, Static Face mask). Riveted gray-steel + sky blue / orange accents. Mascot: masked crew member.
- **B. Getaway Route**: night city heist route. Isometric diorama of fictional city blocks, a 3D Vortex-style go-kart driving a dotted route between 7 stash-spot stops (squad-colored), repo drones with vision cones blocking locked days, day 7 = the Directive tower vault. Closest to Rooftop Streak structure.
- **C. Directive Payroll**: the Directive's cold gray corporate portal being "glitched" by colorful sticker/pixel-tear overlays; 3D sealed folders/envelopes/vault drawers per day, deadpan exec mascot, compliance meter, "Collect Compensation" CTA. Gray + glitch palette.

## How to generate
- Higgsfield CLI via the `higgsfield-generate` skill. Model: **GPT Image 2.5** (`gpt_image_2_5`), 16:9, 2k, ~0.5 credits/image (account ~193 credits left). Rules from CLAUDE.md: quote cost first (`higgsfield generate cost ...`), get owner go, no spend beyond approved plan.
- **Pass the owner's 3 references as `--image` style references** (and try a ref-guided variant per concept). Quote cost with the image flag included. Compare against the text-only prompt on one concept first.
- Write prompts that ASK for: "premium mobile-game UI key art, 3D-rendered chunky Roblox-style props with bevels and specular highlights, layered 2D UI frame, depth of field, rich cinematic lighting, extruded 3D title lettering". Do NOT say "flat" or "no gloss".
- Keep on-image text minimal and exact (title, DAY n, CLAIMED/LOCKED/TODAY, 2 reward names, CLAIM/button). Long small text garbles. Fix logic errors from round 1 (wrong claimed day, streak count mismatch).
- 2 variants per concept, save to `refs/daily-reward-concepts/v2/`, then SHOW the owner the images side by side with the refs and wait for feedback.
- Rules: terse, honest, no subagents, don't build UI in Roblox yet (concept art only), read ranges of DIRECTIVE_GRAY.md not the whole file.

## Owner decision (Oct 2)
Picked Getaway Route (B1) restyled blacked-out: **v2/D2.png** (black + gold trim). Look: near-black, stealth/modern/minimalist, thin white LED edge light, gold glow on TODAY (and faint on Day 7 vault). No event-ends pill, no red X. Concept art only; not built in Roblox.
