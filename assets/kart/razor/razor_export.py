# razor_export.py -- Phase 6: Roblox export prep. exec'd in razor_build namespace at end of run (PHASE>=6).
import json, glob, shutil
PK = os.path.join(OUT, "pkg"); os.makedirs(PK + "/textures", exist_ok=True)
Rz = Matrix.Rotation(math.pi, 4, "Z")      # Blender (x,y,z) -> (-x,-y,z); default FBX/glTF export (x,z,-y) then yields Roblox (-x, z, y): nose -Z, up +Y, kart right +X
# ---- collision hull (Blender frame, symmetric in X)
pts = []
for x, y, z in ((2.3, -4.3, .15), (2.3, 4.5, .15), (1.2, -5.4, .15), (1.2, 5.5, .15), (2.45, -4.0, 1.2), (2.45, 4.2, 1.2), (1.3, -5.5, 1.2), (1.3, 5.5, 1.2), (1.2, -3.4, 2.1), (1.2, 4.0, 2.1)):
    pts += [(x, y, z), (-x, y, z)]
hb = bmesh.new(); [hb.verts.new(p) for p in pts]; bmesh.ops.convex_hull(hb, input=hb.verts[:]); bmesh.ops.triangulate(hb, faces=hb.faces[:])
hm = bpy.data.meshes.new("Collision"); hb.to_mesh(hm); hb.free(); col_ob = bpy.data.objects.new("Collision", hm); col.objects.link(col_ob)
COLL_TRIS = len(hm.polygons)
# ---- rename wheels by Roblox side/end (after rotation: Roblox X = -Blender X, forward = -Blender Y)
for o in GRP["Wheels"]:
    wx = -o.location.x; fr = "F" if o.location.y < 0 else "R"; o.name = f"Wheel_{fr}{'R' if wx > 0 else 'L'}"
parts = GRP["Chassis"] + GRP["Steer"] + GRP["Wheels"] + GRP["DecalPlates"] + GRP["HeadlightStrips"] + GRP["TailStrips"] + GRP["Underglow"]
for o in parts + [col_ob]:
    if o.data.users > 1 or o in GRP["Wheels"] or o in GRP["Steer"]: o.matrix_world = Rz @ o.matrix_world
    else: o.data.transform(Rz); o.data.update()
GRP["Steer"][0].name = "Steer"; GRP["DecalPlates"][0].name = "DecalPlates"
bpy.context.view_layer.update()
unit = sc.unit_settings; unit.system = "NONE"; unit.scale_length = 1.0
def sel(obs):
    bpy.ops.object.select_all(action="DESELECT") if bpy.context.object else None
    for o in bpy.data.objects: o.select_set(False)
    for o in obs: o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
FBX_KW = dict(use_selection=True, object_types={"MESH"}, apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS", global_scale=1.0, axis_forward="-Z", axis_up="Y",
              use_mesh_modifiers=False, mesh_smooth_type="OFF", add_leaf_bones=False, bake_space_transform=False, path_mode="AUTO", use_custom_props=False)
allp = parts + [col_ob]
for o in bpy.data.objects:
    if o not in allp: o.hide_viewport = True
sel(allp); bpy.ops.export_scene.fbx(filepath=PK + "/razor_kart.fbx", **FBX_KW)
# ---- axes test (built directly in export-rotated Blender frame b'=(x,-z_rb,y_rb)); Roblox sizes: X5 Y4 Z7
def box(bm, lo, hi):
    t = bmesh.new(); bmesh.ops.create_cube(t, size=1); bmesh.ops.scale(t, vec=(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]), verts=t.verts)
    bmesh.ops.translate(t, verts=t.verts, vec=tuple((a + b) / 2 for a, b in zip(lo, hi))); me = bpy.data.meshes.new("t"); t.to_mesh(me); t.free(); bm.from_mesh(me); bpy.data.meshes.remove(me)
ab = bmesh.new(); R2B = lambda x, y, z: (x, -z, y)     # Roblox coords -> Blender export frame
def rbox(lo, hi):
    a, b = R2B(*lo), R2B(*hi); box(ab, tuple(min(p, q) for p, q in zip(a, b)), tuple(max(p, q) for p, q in zip(a, b)))
rbox((-1, -1, -1), (1, 1, 1)); rbox((1, -.25, -.25), (4, .25, .25)); rbox((-.25, 1, -.25), (.25, 3, .25)); rbox((-.25, -.25, -6), (.25, .25, -1))
am = bpy.data.meshes.new("AxesTest"); ab.to_mesh(am); ab.free(); ax_ob = bpy.data.objects.new("AxesTest", am); col.objects.link(ax_ob)
for o in bpy.data.objects: o.hide_viewport = o is not ax_ob
sel([ax_ob]); bpy.ops.export_scene.fbx(filepath=PK + "/razor_axes_test.fbx", **FBX_KW)
for o in bpy.data.objects: o.hide_viewport = o not in allp
# ---- GLB preview (textured, no collision)
col_ob.hide_viewport = True; col_ob.hide_render = True
sel(parts); bpy.ops.export_scene.gltf(filepath=PK + "/razor_preview.glb", export_format="GLB", use_selection=True, export_yup=True, export_apply=False)
# ---- verify: GLB POSITION bounds (raw file coords) + FBX reimport bbox
def glb_bounds(p):
    b = open(p, "rb").read(); L = int.from_bytes(b[12:16], "little"); js = json.loads(b[20:20 + L]); out = {}
    for n in js["nodes"]:
        if "mesh" in n:
            acc = js["accessors"][js["meshes"][n["mesh"]]["primitives"][0]["attributes"]["POSITION"]]; out[n["name"]] = (acc["min"], acc["max"], n.get("translation"))
    return out
GB = glb_bounds(PK + "/razor_preview.glb"); ch = GB["Chassis"]
print("GLB Chassis raw min/max", [round(v, 2) for v in ch[0]], [round(v, 2) for v in ch[1]])
before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=PK + "/razor_kart.fbx", axis_forward="-Z", axis_up="Y", global_scale=1.0)
new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]; RB = {}
for o in new:
    vs = [o.matrix_world @ Vector(c) for c in o.bound_box]; RB[o.name.split(".")[0]] = ([round(min(v[i] for v in vs), 2) for i in range(3)], [round(max(v[i] for v in vs), 2) for i in range(3)], len(o.data.polygons))
print("FBX reimport", {k: v for k, v in RB.items() if k in ("Chassis", "Collision", "Steer", "Wheel_FR")})
exp_ch = [-2.58, -5.65, .18]; ok_scale = abs(RB["Chassis"][0][0] - exp_ch[0]) < .02 and abs(RB["Chassis"][1][1] - 5.55) < .02 and abs(RB["Chassis"][0][1] + 5.65) < .02
gx = ch[0][2] < -5.5 and ch[1][2] > 5.6      # glTF z spans -5.55(nose)..5.65(tail)? (nose=-Z)
print("scale/axes roundtrip ok:", ok_scale, " GLB nose at -Z:", abs(ch[0][2] + 5.55) < .02)
# ---- package
for f in glob.glob(OUT + "/razor_*.png"): shutil.copy(f, PK + "/textures/")
for f in ("razor_build.py", "razor_tex.py", "razor_export.py"): shutil.copy(f, PK)
vis = len(GRP["Chassis"]) + len(GRP["Steer"]) + len(GRP["Wheels"]) + len(GRP["DecalPlates"]) + len(GRP["HeadlightStrips"]) + len(GRP["TailStrips"]) + len(GRP["Underglow"])
tot = sum(tris(o) for o in parts if o not in GRP["Wheels"]) + tris(GRP["Wheels"][0]) * 4
EX = dict(visual_parts=vis, collision_tris=COLL_TRIS, tris_visual=tot, tris_with_collision=tot + COLL_TRIS, scale_ok=bool(ok_scale), verts={o.name: len(o.data.vertices) for o in parts if o not in GRP["Wheels"][1:]})
json.dump(EX, open(PK + "/export_info.json", "w")); print("EXPORT", EX)
