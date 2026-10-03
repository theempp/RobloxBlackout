"""Re-import every gun export (GLB + FBX) and check it against its manifest. Run: blender -b -P tools/verify_guns.py
Also renders assets/guns/export-check.png (side views, one random colour per piece)."""
import bpy, json, random
from pathlib import Path
from mathutils import Vector
R = Path(__file__).resolve().parents[1]
fails, shots = [], []
PAL = {'Body': (.55, .55, .55, 1), 'Slide': (.2, .4, 1, 1), 'Mag': (1, .2, .2, 1), 'Optic': (.2, .9, .3, 1), 'Muzzle': (1, .9, .1, 1),
       'Barrel': (1, .5, 0, 1), 'Stock': (.7, .2, 1, 1), 'Pump': (0, .9, .9, 1), 'Foregrip': (1, .4, .8, 1), 'Light': (.5, .3, .1, 1), 'Bipod': (.5, .3, .1, 1)}
for cls in ('pistol', 'ar', 'sniper', 'shotgun'):
    man = json.loads((R / f'assets/guns/{cls}/export/manifest.json').read_text())
    for gid, m in man.items():
        for ext in ('glb', 'fbx'):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            f = str(R / f'assets/guns/{cls}/export/{gid}.{ext}')
            (bpy.ops.import_scene.gltf if ext == 'glb' else bpy.ops.import_scene.fbx)(filepath=f)
            ms = [o for o in bpy.data.objects if o.type == 'MESH']
            names = sorted(o.name.split('.')[0] for o in ms)
            want = sorted(p['object'] for p in m['pieces'])
            t = 0; pts = []
            for o in ms:
                o.data.calc_loop_triangles(); t += len(o.data.loop_triangles)
                pts += [o.matrix_world @ v.co for v in o.data.vertices]
                for mat in o.data.materials:  # no orange: every colour must be near-black
                    c = mat.diffuse_color
                    if max(c[:3]) > .1: fails.append(f'{gid}.{ext} {o.name} colour {tuple(round(a,2) for a in c[:3])}')
            if names != want: fails.append(f'{gid}.{ext} pieces {names} != {want}')
            if t != m['tris'] or t > m['tri_budget']: fails.append(f'{gid}.{ext} tris {t} (manifest {m["tris"]})')
            L = max(p.y for p in pts) - min(p.y for p in pts)
            if abs(L - m['length_studs']) > .02: fails.append(f'{gid}.{ext} length {L:.3f} along Y')
            front = [o for o in ms if o.name.split('_')[1].split('.')[0] in ('Muzzle', 'Barrel')]
            if front and max(p.y for p in pts) - max((o.matrix_world @ v.co).y for o in front for v in o.data.vertices) > .02:
                fails.append(f'{gid}.{ext} muzzle not at +Y')
            if ext == 'glb':
                sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
                sc.display.shading.color_type = 'OBJECT'
                for o in ms: o.color = PAL.get(o.name.split('_')[1].split('.')[0], (1, 1, 1, 1))
                sc.render.resolution_x, sc.render.resolution_y = 900, 300
                cam = bpy.data.objects.new('c', bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera = cam
                cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(m['length_studs'], 3 * (max(p.z for p in pts) - min(p.z for p in pts))) * 1.1
                cy = (max(p.y for p in pts) + min(p.y for p in pts)) / 2; cz = (max(p.z for p in pts) + min(p.z for p in pts)) / 2
                cam.location = (5, cy, cz); cam.rotation_euler = (1.5708, 0, 1.5708)  # from +X: muzzle (+Y) on the right
                sc.render.filepath = str(R / f'build/gunshot-{gid}.png'); bpy.ops.render.render(write_still=True)
                shots.append(sc.render.filepath)
            print(f'CHECK {gid}.{ext} pieces={len(ms)} tris={t} len={L:.2f}')
img = [bpy.data.images.load(p) for p in shots]
W, H = 900, 300; out = bpy.data.images.new('sheet', W * 2, H * 4)
px = [0.0] * (W * 2 * H * 4 * 4)
for i, im in enumerate(img):
    src = list(im.pixels); cx, cy = (i % 2) * W, (3 - i // 2) * H
    for y in range(H):
        a = ((cy + y) * W * 2 + cx) * 4; px[a:a + W * 4] = src[y * W * 4:(y + 1) * W * 4]
out.pixels = px; out.filepath_raw = str(R / 'assets/guns/export-check.png'); out.file_format = 'PNG'; out.save()
print('VERIFY', 'FAIL' if fails else 'PASS', len(shots), 'guns'); [print('  ' + f) for f in fails]
