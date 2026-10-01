"""Compose detail/detail-sheet.png (rows = guns; cols = left side, 3/4 front-left, 3/4 rear-right, top). Run: python3 gun_sheet.py [DIR]"""
import json, sys, os
from PIL import Image, ImageDraw
D = sys.argv[1] if len(sys.argv) > 1 else "detail"; info = json.load(open(os.path.join(D, "detail_info.json")))
NAMES = dict(dart9="Dart-9 (sidearm)", buzz="Buzzline (SMG)", ranger="Ranger (rifle)", needle="Needlepoint (marksman)")
W, H, V = 550, 320, ("left", "q-left", "q-right", "top")
sh = Image.new("RGB", (W * 4, (H + 26) * len(info)), (30, 30, 32)); dr = ImageDraw.Draw(sh)
for r, (g, v) in enumerate(info.items()):
    y = r * (H + 26)
    dr.text((8, y + 7), f"{NAMES.get(g, g)}   tris {v['tris_total']}  {v['tris']}   L {v['bbox']['L']}  H {v['bbox']['H']}  W {v['bbox']['W']}   muzzle tip y {v['bbox']['tip_y']}", fill=(235, 235, 235))
    for c, n in enumerate(V): sh.paste(Image.open(os.path.join(D, f"{g}-{n}.png")).convert("RGB").resize((W, H)), (c * W, y + 26))
sh.save(os.path.join(D, "detail-sheet.png")); print("sheet", sh.size)
