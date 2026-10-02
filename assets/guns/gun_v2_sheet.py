"""Overlay check for gun_v2.py: per gun, [locked sheet | render blended 50% over it | render alone], plus 3/4 + first-person views.
Run from assets/guns after the Blender build:  python3 gun_v2_sheet.py  ->  v2/overlay-sheet.png"""
import json, os
from PIL import Image, ImageDraw
H = os.path.dirname(os.path.abspath(__file__)); V = os.path.join(H, "v2"); info = json.load(open(os.path.join(V, "info.json")))
SHEET = dict(dart9="dart9-v2.png", buzz="buzzline-v2.png", ranger="ranger-v2.png", needle="needlepoint-v2.png")
rows = []
for g in ("dart9", "buzz", "ranger", "needle"):
    if g not in info: continue
    sh = Image.open(os.path.join(H, "concepts-2026-09-30", SHEET[g])).convert("RGBA")
    rd = Image.open(os.path.join(V, f"{g}-side.png")).convert("RGBA").resize(sh.size)
    bg = Image.new("RGBA", sh.size, (128, 128, 132, 255)); alone = Image.alpha_composite(bg, rd)
    a = rd.split()[3].point(lambda v: v // 2); half = rd.copy(); half.putalpha(a); blend = Image.alpha_composite(sh, half)
    q = [Image.open(os.path.join(V, f"{g}-{n}.png")).convert("RGBA") for n in ("q-left", "fp")]
    w, h = 672, 376
    row = Image.new("RGB", (w * 5, h + 22), (24, 24, 26)); d = ImageDraw.Draw(row)
    for i, im in enumerate([sh, blend, alone] + [Image.alpha_composite(Image.new("RGBA", x.size, (128, 128, 132, 255)), x) for x in q]):
        row.paste(im.convert("RGB").resize((w, h)), (i * w, 22))
    v = info[g]; d.text((6, 5), f"{g}  first-person tris {v['fp_tris']}  world primitives {v['world_prims']}  muzzle {v['muzzle']}   [sheet | overlay 50% | render | 3/4 | first-person]", fill=(235, 235, 235))
    rows.append(row)
out = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)))
y = 0
for r in rows: out.paste(r, (0, y)); y += r.height
out.save(os.path.join(V, "overlay-sheet.png")); print("sheet", out.size)
