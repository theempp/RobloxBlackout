# Gun concept brief — Meshy image-to-3D (Oct 2)
Owner decisions (Oct 2, this chat): refs = baseline, tweaked *slightly* toward an airsoft/foam-blaster look; winners **replace** `dart9` (pistol), `ranger` (AR), `needle` (sniper) and give `scatter` (shotgun) its first real art. Buzzline/Rattler untouched. IDs, prices, ownership unchanged. Route: Meshy concept image -> image-to-3D **preview, untextured** -> owner review -> Blender. Driven via Claude in Chrome on owner's account.
Refs: `refs/ref1-pistol.jpg` `ref2-ar.jpg` `ref3-sniper.jpg` `ref4-shotgun.jpg` (contain real brands — never upload them to Meshy as-is; prompts only).

## Shared visual language (read from refs)
- Flat cel look: bold dark outline, 2–3 flat value steps per material, no grain, no gradients beyond one soft highlight band.
- Forms: boxy receivers with chamfered corners; detail = a few cut lines (slide serrations as 4–6 grooves, M-LOK as a row of slots, grip texture as a flat panel). No screws, knurling, text.
- Silhouette tells per class: pistol = slide + optic hump + muzzle can; AR = stock/mag/handguard triangle + tall scope; sniper = long barrel + skeleton stock + big scope; shotgun = tube under barrel + pump + pistol grip.
- Airsoft/blaster tweak (light touch, keeps Mild rating): ~10–15% chunkier grip, trigger guard, mag and optic; slightly thicker barrels; flat **orange muzzle tip** on every gun (the airsoft tell); softer rounded edges; no bullets/brass/visible cartridges.
- Palettes: pistol FDE tan + black · AR matte black + dark grey, one orange accent · sniper black/dark grey, desaturated · shotgun black + brushed-silver receiver. No neon/emissive.
- Markings: invented only — a small Blackout Crew glyph (abstract chevron) on the left receiver = `Config.Branding` engrave zone. No real brands, wordmarks, model numbers.

## Constraint block (appended to every prompt)
`Low-poly stylized game asset, clean simple topology, single closed mesh, 1.5k-3k triangles after cleanup, flat baked colour only, no PBR micro-detail, no normal-map clutter. Strict side profile, barrel pointing right (+X), centred, no stand, no hands, no scene, plain white background. Slightly exaggerated grip and optic for third-person mobile readability. No text, logos, brand names or numbers.`
Style prefix (every prompt): `Flat cel-shaded vector illustration of a stylized airsoft-style toy blaster, bold dark outlines, large flat colour blocks,`

## Per-weapon prompts (2 per class, differ in configuration)
| ID | Slot | Prompt body (between style prefix and constraint block) |
|---|---|---|
| P1 | dart9 | `semi-automatic pistol, FDE tan slide and frame, black grip panels, suppressed: long fat black cylindrical suppressor with blocky relief, boxy red-dot optic on the slide, tactical flashlight under the dust cover, orange muzzle ring` |
| P2 | dart9 | `semi-automatic pistol, FDE tan frame with black slide, compensated: short chunky square compensator with two top ports, open-frame red-dot, extended magazine with flat baseplate, no light, orange muzzle tip` |
| A1 | ranger | `AR-style carbine, matte black and dark grey, 14-inch slotted handguard, tall 1-6x scope with offset mini red dot, chunky angled stock, waffle-window magazine, vertical foregrip, one orange accent stripe on the ejection side, orange flash-hider tip` |
| A2 | ranger | `short-barrel AR-style carbine, matte black and dark grey, 10-inch slotted handguard, compact square red-dot, collapsed chunky stock, straight magazine, angled foregrip, one orange accent on charging handle, orange muzzle tip` |
| S1 | needle | `bolt-action sniper rifle, black and desaturated dark grey, folding skeleton chassis stock with cheek riser, long fluted heavy barrel with chunky muzzle brake, big long scope on high rings, folded bipod under the forend, orange muzzle tip` |
| S2 | needle | `bolt-action sniper rifle, black and desaturated dark grey, solid thumbhole chassis stock, shorter barrel with fat cylindrical suppressor, medium scope, top rail only, no bipod, orange suppressor end cap` |
| G1 | scatter | `pump-action shotgun, black barrel and furniture, brushed silver two-tone receiver, ribbed black pump, magazine tube under barrel, bare pistol grip with no stock, short barrel, top rail, orange muzzle tip` |
| G2 | scatter | `pump-action shotgun, black barrel and furniture, brushed silver two-tone receiver, ribbed black pump, extended magazine tube with clamp, fixed chunky stock, longer barrel with ghost-ring sights, side shell-carrier block, orange muzzle tip` |

Negative (where Meshy accepts one): `photorealistic, grain, scratches, text, logo, brand, letters, numbers, bullets, hands, background, stand, gradient`.

## Flow per class (one class at a time)
1. Meshy text-to-image: 2 concept images (P1+P2 …) -> owner picks/approves.
2. Image-to-3D **preview, no texture** for approved images -> owner reviews geometry.
3. Texture/refine only after a second approval. Downloads -> `assets/guns/<class>/source/`, byte-intact; `NOTES.md` logs prompt, model, mode, credits, balance.

## Meshy quote (read on screen Oct 2, owner account, nothing spent) — balance **1,078**
Image (per image; multi-view toggle doesn't change price): Nano Banana Pro 9 · Nano Banana 2 **6** · Nano Banana (original) 3 · GPT Image 2 9.
Image-to-3D, High Detail: Meshy 7.1 Standard 20 / +texture 30 · Ultra 2K 25 / 35 · Meshy 6 20 / 30 · Meshy 6 Lite 10 (no texture option).
Image-to-3D, Smart Topology: **Meshy T2 5** untextured / 15 textured, poly-count field 100–4000+ at the same price (T1 = legacy). Meshy's own tip there: 2D/hand-drawn input should first go through image generation "to give it a 3D look".
Proposed: NB2 concept (1 per gun) + T2 untextured at a ~1.5k poly target = 11/gun, **22/class, 88 for all 8**. Cap requested: **120** (88 plus one 6-credit re-roll per gun = 48 worst case → capped). No texture spend (flat colours get painted in Blender).
Prompt change: concept images are rendered as "clean 3D toy-blaster render, flat colours, soft toon shading" instead of flat vector art, per Meshy's tip; the cel look comes back in Blender/Roblox.
