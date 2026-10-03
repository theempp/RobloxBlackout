"""Orthographic geometry inspection; optional input blend path after --."""
import bpy, sys, math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE/'.deps'))
from PIL import Image, ImageDraw
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
bpy.ops.wm.open_mainfile(filepath=str(Path(args[0]) if args else HERE/'blackout_nightcrawler.blend'))
if '--open' in args:
    for name in ['Canopy_L','Canopy_R']:
        ob=bpy.data.objects[name];ob.rotation_euler.y=math.radians(ob['open_degrees'])
    for ob in bpy.context.scene.objects:
        if ob.name.startswith('FIT_PROXY_'):
            ob.hide_render=False;ob.color=(.8,.35,.07,1)
bpy.context.view_layer.update()
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'; scene.display.shading.studio_light='paint.sl'
scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.display.shading.background_type='WORLD'
if scene.world is None: scene.world=bpy.data.worlds.new('ReviewWorld')
scene.world.color=(.16,.16,.16)
scene.render.resolution_x=1000; scene.render.resolution_y=700; scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.view_settings.exposure=1.2
meshes=[o for o in scene.objects if o.type=='MESH' and not o.hide_render]
corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(p[i] for p in corners) for i in range(3)])
hi=Vector([max(p[i] for p in corners) for i in range(3)])
center=(lo+hi)/2; span=max(hi-lo)
data=bpy.data.cameras.new('ReviewCamera'); cam=bpy.data.objects.new('ReviewCamera',data)
scene.collection.objects.link(cam); scene.camera=cam; data.type='ORTHO'; data.ortho_scale=span*1.18
out=HERE/'review';out.mkdir(exist_ok=True)
views={'front':(0,1,0),'rear':(0,-1,0),'side':(1,0,0),'top':(0,0,1)}
if args and '--raw' in args: views={'raw_plus_x':(1,0,0),'raw_minus_x':(-1,0,0),'raw_side':(0,-1,0),'raw_top':(0,0,1)}
sheet=Image.new('RGB',(2000,1480),(34,34,34)); draw=ImageDraw.Draw(sheet)
for i,(name,direction) in enumerate(views.items()):
    cam.location=center+Vector(direction)*span*3
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    inv=cam.rotation_euler.to_matrix().transposed()
    projected=[inv@(p-center) for p in corners]
    width=max(p.x for p in projected)-min(p.x for p in projected)
    height=max(p.y for p in projected)-min(p.y for p in projected)
    data.ortho_scale=max(width,height*1000/700)*1.12
    filename=('open-' if '--open' in args else '')+name+'.png'
    scene.render.filepath=str(out/filename);bpy.ops.render.render(write_still=True)
    sheet.paste(Image.open(out/filename).convert('RGB'),((i%2)*1000,(i//2)*740+40))
    draw.text(((i%2)*1000+25,(i//2)*740+10),name,fill='white',font_size=24)
sheet.save(out/('raw-sheet.jpg' if '--raw' in args else 'access-sheet.jpg' if '--open' in args else 'review-sheet.jpg'))
