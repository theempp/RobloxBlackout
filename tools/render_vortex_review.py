"""Render a repeatable review image from the editable Vortex source."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

HERE=Path(__file__).resolve().parents[1]/"assets/karts/vortex"
bpy.ops.wm.open_mainfile(filepath=str(HERE/"phone-optimized.blend"))
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.samples=12
scene.render.resolution_x=1280
scene.render.resolution_y=800
scene.render.resolution_percentage=100
if scene.world is None:
    scene.world=bpy.data.worlds.new("Review world")
scene.world.color=(.18,.18,.20)

def aim(ob, target):
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()

bpy.ops.object.camera_add(location=(8.8,10.2,6.1))
camera=bpy.context.object
aim(camera,(0,0,1.4))
camera.data.type='ORTHO'
camera.data.ortho_scale=15.5
scene.camera=camera

for pos,power,size in [((3,3,9),3500,7),((-6,4,6),2400,6),((3,-8,7),3000,5)]:
    bpy.ops.object.light_add(type='AREA',location=pos)
    ob=bpy.context.object
    ob.data.energy=power
    ob.data.shape='DISK'
    ob.data.size=size
    aim(ob,(0,0,1))

bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.02))
floor=bpy.context.object
floor.name="Review floor"
mat=bpy.data.materials.new("Dark review floor")
mat.diffuse_color=(.065,.068,.075,1)
floor.data.materials.append(mat)
scene.render.filepath=str(HERE/"phone-review"/"preview.png")
bpy.ops.render.render(write_still=True)
camera.location=(-8.8,-10.2,6.1)
aim(camera,(0,0,1.4))
scene.render.filepath=str(HERE/"phone-review"/"rear-preview.png")
bpy.ops.render.render(write_still=True)
camera.location=(9,0,3.4)
aim(camera,(0,0,1.45))
scene.render.filepath=str(HERE/"phone-review"/"side-preview.png")
bpy.ops.render.render(write_still=True)
camera.location=(8.5,10.5,5.0)
aim(camera,(0,-.10,2.10))
camera.data.ortho_scale=6.3
scene.render.filepath=str(HERE/"phone-review"/"cockpit-preview.png")
bpy.ops.render.render(write_still=True)
