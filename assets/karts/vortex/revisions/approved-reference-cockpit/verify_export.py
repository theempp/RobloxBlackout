"""Check the exported FBX can be reimported with named articulation pivots."""
import bpy
from pathlib import Path
from mathutils import Vector

root=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(root/"export"/"blackout_vortex.fbx"),axis_forward="-Z",axis_up="Y")
meshes={o.name.split(".")[0]:o for o in bpy.data.objects if o.type=="MESH"}
required=("Chassis","Wheel_FL","Wheel_FR","Wheel_RL","Wheel_RR","Steer","Door_L_Shell","Door_R_Shell")
missing=[n for n in required if n not in meshes]
assert not missing, "missing FBX pieces: "+str(missing)
def rb(o):
    b=o.matrix_world.translation
    return Vector((b.x,b.z,-b.y))
hubs={"Wheel_FL":(-1.925,.92,-3.4),"Wheel_FR":(1.925,.92,-3.4),
      "Wheel_RL":(-1.925,.92,3.6),"Wheel_RR":(1.925,.92,3.6)}
for n,v in hubs.items():
    assert (rb(meshes[n])-Vector(v)).length<.02,(n,tuple(rb(meshes[n])))
assert (rb(meshes["Steer"])-Vector((0,1.85,-.95))).length<.02
assert (rb(meshes["Chassis"])-Vector((0,1.75,-.05))).length<.02
print("VORTEX_FBX_OK",len(meshes),"pieces, pivots aligned")
