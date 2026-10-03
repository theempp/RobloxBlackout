# Heist HUD v2 — owner reference (Oct 2)
Image: `hud-reference.webp` (1672x941). Owner: "the exact in-game HUD" for heists. Concept art, grey placeholder background.
Structure (ref px -> design units x0.36; all numbers in `Config.HudRef`):
- Top-left: minimap (octagonal chamfered frame, "N" tab, dashed route, white arrow, pin) ; under it the objective checklist (diamond + title, 3 steps: active white dot, rest grey).
- Top, right of map: 4 circular squad portraits (avatar headshots), white health bar across each bottom.
- Top-right: health bar + number; under it weapon silhouette + big magazine count | reserve.
- Bottom-left: round move stick (grey thumb). Bottom-right: fire (largest), aim/crosshair, swap-weapon, sprint. Bottom-centre: three bare icons (backpack, phone, map).
- Style: matte near-black panels, dark outer edge + thin grey rim, light-grey ink, one white/grey accent. No colour, no glow.
Built: `src/client/HudV2.luau` (presentation + setters, unwired), layout spec `tests/server/specs/HudRef.spec.luau`.
Deviations (owner to confirm): slot-colour dot + name under each portrait (directive 5e, set `HudRef.ShowNames=false` for reference-exact); settings gear dropped (menu icon opens settings); minimap pushed down by `TopInset` to clear Roblox's own menu icons (phone-test); minimap frame rounded, not chamfered; icons are text until art is uploaded (`HudRef.Icons`).

# Lobby HUD (owner reference, Oct 2) — `lobby-hud-reference.jpg` (640x359)
Same matte near-black plate style as the heist HUD. Layout:
- Top-left: player card (avatar circle, "LVL 24", white XP bar, "420 / 650 XP"). Under it a left column of round icon buttons with caption: SHOP, VIP, INVENTORY.
- Top-right: Credits pill ("$ 124,750" + cash icon) and Glitch Coins pill ("1,350" + coin icon, with a "+" button). Under them: FRIENDS, SETTINGS round buttons.
- Bottom-left: DAILY REWARD plate (gift icon, live countdown 23:59:17) -> opens the daily reward screen.
- Bottom-centre: 4 squad slots: your avatar + 3 "+" circles (invite a squadmate; max 4).
- Bottom-right: CURRENT CONTRACT plate (document icon, diamond + objective line, e.g. "Get to parking garage").
Rules that still apply: paid actions (VIP, Glitch Coin "+") stay disabled/unavailable in the private test (see readiness gate); LVL/XP must come from real profile data (`Economy.tier` / `progress.xp`, not decorative numbers); no neon/glow; 44px touch targets.
