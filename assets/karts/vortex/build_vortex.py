"""Build the Blackout Vortex in Blender and export its offline Roblox model.

Run: blender -b -P assets/karts/vortex/build_vortex.py
One Blender unit is one Roblox stud. The saved scene is editable; the FBX/GLB
keep the same named pieces and pivots as the immediately playable RBXMX proxy.
"""
import bpy
import json
import math
from pathlib import Path
from xml.sax.saxutils import escape
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
OUT = HERE / "export"
OUT.mkdir(exist_ok=True)
ASSET = OUT / "VortexKartProxy.rbxmx"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "NONE"
parts = []

PALETTE = {
    "paint": ((.014, .017, .021), .11, .82, .15),
    "black": ((.022, .024, .027), .25, .65, .05),
    "carbon": ((.037, .042, .047), .32, .35, .02),
    "rubber": ((.012, .013, .014), .78, .0, .0),
    "glass": ((.018, .025, .034), .08, .35, .14),
    "white": ((.92, .96, 1.0), .22, .0, .0),
    "brake": ((.17, .18, .19), .42, .72, .0),
    "intake": ((.003,.003,.003), .85, .0, .0),
}

def material(key):
    c, rough, metal, transparency = PALETTE[key]
    m = bpy.data.materials.get(key)
    if m is None:
        m = bpy.data.materials.new(key)
        m.diffuse_color = (*c, 1 - transparency)
        m.use_nodes = True
        bs = m.node_tree.nodes.get("Principled BSDF")
        bs.inputs["Base Color"].default_value = (*c, 1)
        bs.inputs["Roughness"].default_value = rough
        bs.inputs["Metallic"].default_value = metal
        bs.inputs["Coat Weight"].default_value = .85 if key == "paint" else 0
        bs.inputs["Coat Roughness"].default_value = .07
        if key == "white":
            bs.inputs["Emission Color"].default_value = (*c, 1)
            bs.inputs["Emission Strength"].default_value = 1.8
        if transparency:
            bs.inputs["Alpha"].default_value = 1 - transparency
            m.surface_render_method = "DITHERED"
    return m

def r2b(v):
    return (v[0], -v[2], v[1])

def box(name, pos, size, mat="paint", rot=None, shape="Part", hidden=False):
    rot = rot or Matrix.Identity(3)
    spec = dict(name=name, pos=tuple(pos), size=tuple(size), mat=mat,
                rot=[list(row) for row in rot], shape=shape, hidden=hidden)
    parts.append(spec)
    round_part = name.startswith(("Wheel_", "Rim_", "BrakeDisc_", "Hub_"))
    verts = []
    sx, sy, sz = (n / 2 for n in size)
    if shape == "Ball":
        local_verts=[]
        for i in range(1,9):
            phi=-math.pi/2+i*math.pi/9
            for j in range(20):
                a=j*math.tau/20
                local_verts.append((sx*math.cos(phi)*math.cos(a),sy*math.sin(phi),sz*math.cos(phi)*math.sin(a)))
        local_verts += [(0,-sy,0),(0,sy,0)]
        faces=[]
        for i in range(7):
            for j in range(20):
                n=(j+1)%20
                faces.append((i*20+j,i*20+n,(i+1)*20+n,(i+1)*20+j))
        for j in range(20):
            n=(j+1)%20
            faces.append((160,j,n))
            faces.append((161,140+n,140+j))
    elif round_part:
        local_verts=[]
        for x in (-sx,sx):
            for j in range(20):
                a=j*math.tau/20
                local_verts.append((x,math.sin(a)*sy,math.cos(a)*sz))
        faces=[tuple(reversed(range(20))),tuple(range(20,40))]
        faces += [(j,(j+1)%20,(j+1)%20+20,j+20) for j in range(20)]
    elif shape == "WedgePart":
        local_verts=((-sx,-sy,-sz),(sx,-sy,-sz),(-sx,-sy,sz),(sx,-sy,sz),(-sx,sy,sz),(sx,sy,sz))
        faces=((0,1,3,2),(2,3,5,4),(0,4,5,1),(0,2,4),(1,5,3))
    else:
        local_verts=((-sx,-sy,-sz),(sx,-sy,-sz),(sx,sy,-sz),(-sx,sy,-sz),
                     (-sx,-sy,sz),(sx,-sy,sz),(sx,sy,sz),(-sx,sy,sz))
        faces=((0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0))
    for x,y,z in local_verts:
        rv = rot @ Vector((x,y,z))
        verts.append(r2b(rv))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(material(mat))
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    ob.location = r2b(pos)  # preserve per-piece pivots in FBX/GLB (wheels stay at their hubs)
    if hidden:
        ob.hide_render = True
        return spec
    bevel = ob.modifiers.new("Edge glints", "BEVEL")
    bevel.width = min(.045, min(size) * .12)
    bevel.segments = 2
    ob.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    ob["vortex_group"] = name.split("_")[0]
    return spec

def beam(name, a, b, width, mat="carbon"):
    a, b = Vector(a), Vector(b)
    delta = b-a
    direction = delta.normalized()
    right = direction.cross(Vector((0,1,0)))
    if right.length < .001: right = Vector((1,0,0))
    right.normalize()
    up = right.cross(direction).normalized()
    rot = Matrix(((right.x, up.x, direction.x),
                  (right.y, up.y, direction.y),
                  (right.z, up.z, direction.z)))
    return box(name, (a+b)/2, (width, width, delta.length), mat, rot)

def slope(name, x, y, z, sx, sy, sz, deg, mat="paint"):
    rot = Matrix.Rotation(math.radians(deg), 3, 'X')
    return box(name, (x,y,z), (sx,sy,sz), mat, rot)

# The Chassis locator encodes the fixed kart frame used by KartModel.templateFrame.
# It stays invisible in game; all visible pieces are separate and non-colliding.
box("Chassis", (0,1.75,-.05), (5.16,3.14,11.2), hidden=True)
box("Floor", (0,.34,0), (2.55,.17,10.3), "carbon")
box("Belly", (0,.46,.2), (3.08,.17,8.8), "black")

# Long low nose, broad splitters and sculpted front aero. The nose is deliberately
# below the windscreen so the driving view can see over it.
box("NoseCore",(0,1.03,-3.77),(2.15,.94,3.55),"paint",shape="Ball")
box("NoseSpine", (0,1.20,-3.5), (.28,.08,3.55), "black")
box("NoseBridge", (0,1.04,-1.76), (2.38,.66,1.23), "paint")
box("FrontCowl", (0,1.52,-1.55), (2.16,.30,.80), "paint")
for side,s in (("L",-1),("R",1)):
    box("HoodVent_"+side,(s*.67,1.40,-2.31),(.30,.045,.85),"carbon")
for side, s in (("L",-1),("R",1)):
    box("Splitter_"+side, (s*1.48,.27,-4.91), (1.65,.095,1.53), "carbon")
    slope("FrontBlade_"+side, s*1.63,.37,-5.07,1.55,.10,1.42,-6,"paint")
    box("DivePlane_"+side, (s*2.08,.40,-4.42), (.63,.08,1.47), "black")
    beam("NoseRail_"+side, (s*.56,1.12,-2.52), (s*.38,.91,-5.45), .075, "white")
    beam("Headlight_"+side, (s*.44,.88,-5.47), (s*1.86,.46,-5.35), .105, "white")
    box("Canard_"+side, (s*2.16,.78,-3.62), (.25,.11,.95), "carbon")

# One-seat monocoque, deep intake pods and a canopy split by one central halo.
box("CockpitTub", (0,.85,.10), (2.45,1.03,3.0), "paint")
box("SeatBack", (0,1.54,.78), (1.05,1.38,.22), "black", Matrix.Rotation(math.radians(-12),3,'X'))
box("HeadRest", (0,2.25,1.12), (.62,.60,.26), "carbon")
for side,s in (("L",-1),("R",1)):
    box("SidePod_"+side, (s*1.76,.76,.47), (1.0,.73,3.52), "paint")
    box("Intake_"+side, (s*2.27,.96,-.42), (.065,.54,1.32), "black")
    beam("IntakeRim_"+side, (s*2.31,1.21,-1.06), (s*2.31,1.21,.23), .045,"white")
    box("Sill_"+side, (s*1.61,.32,.51), (.86,.12,4.08), "carbon")
    box("Shoulder_"+side, (s*1.17,1.62,.18), (.56,.22,2.72), "paint")
    # Swept front windshields meet at the halo; the side panes continue to the engine fairing.
    box("Door_"+side+"_Shell", (s*1.31,1.69,-.03), (.57,.27,3.36), "paint")
    glass_tilt = Matrix.Rotation(math.radians(-20), 3, 'X') @ Matrix.Rotation(math.radians(-s*20), 3, 'Z')
    box("Door_"+side+"_Glass", (s*.80,2.10,-1.07), (1.70,.075,2.45), "glass",glass_tilt)
    box("Door_"+side+"_SideGlass", (s*1.43,1.98,.70), (.075,.78,1.96), "glass")
    roof_tilt = Matrix.Rotation(math.radians(-s*18), 3, 'Z')
    box("Door_"+side+"_RoofGlass", (s*.76,2.61,.88), (1.57,.075,1.72), "glass",roof_tilt)
    beam("Door_"+side+"_OuterFrame", (s*1.61,1.48,-2.21), (s*1.61,2.20,.12), .075, "paint")
    beam("Door_"+side+"_FrontFrame", (s*.04,2.14,-2.21), (s*1.61,1.48,-2.21), .07, "black")
    beam("Door_"+side+"_RearFrame", (s*.04,2.89,.12), (s*1.61,2.20,.12), .075, "paint")
    beam("Door_"+side+"_SideLowerFrame",(s*1.44,1.55,.16),(s*1.44,1.55,1.68),.07,"paint")
    beam("Door_"+side+"_Rim", (s*1.57,1.82,-1.68), (s*1.57,1.82,1.62), .055, "white")
    box("Door_"+side+"_Handle", (s*1.63,1.75,.72), (.06,.05,.28), "carbon")
    slope("CanopyButtress_"+side,s*1.22,2.10,1.61,.42,.55,.95,-17,"paint")

# The central post and crown form a proper halo between the two glass halves.
beam("HaloFront", (0,1.64,-2.26), (0,2.86,.10), .17, "paint")
beam("HaloCrown", (0,2.86,.10), (0,2.88,1.32), .18, "black")
for side,s in (("L",-1),("R",1)):
    beam("HaloRear_"+side,(0,2.88,1.32),(s*.93,1.78,1.75),.14,"paint")
box("RearBulkhead", (0,1.81,1.57), (2.33,.70,.36), "paint")
box("RearRoofBridge", (0,2.18,1.85), (2.43,.26,1.03), "paint")
box("AirScoop", (0,3.01,1.54), (.79,.40,.87), "paint")
box("ScoopMouth", (0,3.06,1.07), (.65,.27,.04), "black")
box("EngineDeck", (0,1.59,3.14), (2.57,.58,3.17), "paint")
box("EngineCover", (0,2.00,3.16), (2.19,.26,2.80), "paint")
box("RearClosure", (0,1.21,4.99), (4.32,.76,.88), "paint")
for side,s in (("L",-1),("R",1)):
    box("RearQuarter_"+side,(s*1.70,1.19,2.34),(.97,.65,1.42),"paint")
    box("RearHaunch_"+side, (s*1.87,1.18,3.57), (.89,.61,2.65), "paint")
    slope("RearVent_"+side,s*1.16,1.91,2.49,.68,.075,1.28,14,"carbon")
    box("EngineLouvre_"+side,(s*.76,2.17,3.31),(.34,.045,1.43),"carbon")
    beam("RearBlade_"+side,(s*2.13,.54,3.98),(s*2.17,1.36,4.80),.13,"carbon")
    beam("WingStrut_"+side,(s*1.32,1.70,4.12),(s*1.64,3.26,4.72),.19,"black")
    box("WingEndplate_"+side,(s*2.57,3.22,4.95),(.10,.92,1.36),"paint")
    beam("TailLED_"+side,(s*.42,1.48,5.29),(s*2.24,1.48,5.29),.10,"white")
box("Diffuser",(0,.38,5.22),(3.42,.21,.90),"carbon")
for x in (-1.14,-.38,.38,1.14):
    box("DiffuserFin_%s"%str(x).replace('-','m').replace('.','p'),(x,.27,5.36),(.075,.32,.74),"carbon")
box("RearWing",(0,3.38,4.95),(5.25,.15,1.33),"paint")
box("WingFlap",(0,3.55,5.40),(5.0,.08,.30),"black")
beam("WingLED",(-2.43,3.39,4.28),(2.43,3.39,4.28),.055,"white")

# Wheels have independent named pivots at the shared physics hubs.
HUBS = ((-1.925,.92,-3.4),(1.925,.92,-3.4),(-1.925,.92,3.6),(1.925,.92,3.6))
for name,hub in zip(("FL","FR","RL","RR"), HUBS):
    x,y,z = hub
    box("Wheel_"+name,hub,(.96,1.84,1.84),"rubber")
    box("Rim_"+name,(x+(-.49 if x<0 else .49),y,z),(.055,1.22,1.22),"black")
    box("BrakeDisc_"+name,(x+(-.526 if x<0 else .526),y,z),(.035,.60,.60),"brake")
    box("Hub_"+name,(x+(-.61 if x<0 else .61),y,z),(.06,.25,.25),"black")

# Cockpit steering wheel is a set of slim movable pieces, visible from the eye point.
STEER=(0,1.85,-.95)
box("Steer",STEER,(.18,.18,.18),"black")
def steer_point(a,r):
    tilt=math.radians(30)
    return (math.cos(a)*r,1.85+math.sin(a)*r*math.cos(tilt),-.95-math.sin(a)*r*math.sin(tilt))
for j in range(12):
    a=j*math.tau/12
    beam("Steer_Rim_%d"%j,steer_point(a,.39),steer_point(a+math.tau/12,.39),.085,"carbon")
for j,a in enumerate((0,2.15,4.15)):
    beam("Steer_Spoke_%d"%j,STEER,steer_point(a,.35),.075,"black")
box("Dash",(0,1.82,-1.31),(1.64,.24,.49),"carbon")
box("DashScreen",(0,1.94,-1.34),(.63,.06,.30),"white")

def number(x):
    return format(float(x), ".7g")

def vec3(tag, name, v):
    return '<%s name="%s"><X>%s</X><Y>%s</Y><Z>%s</Z></%s>' % (tag,name,*map(number,v),tag)

def cf(p):
    r=p["rot"]
    vals=''.join('<R%d%d>%s</R%d%d>'%(i,j,number(r[i][j]),i,j) for i in range(3) for j in range(3))
    return '<CoordinateFrame name="CFrame"><X>%s</X><Y>%s</Y><Z>%s</Z>%s</CoordinateFrame>'%(*map(number,p["pos"]),vals)

def xml_part(p, index):
    c, rough, metal, transparency = PALETTE[p["mat"]]
    # SmoothPlastic + modest reflectance gives a glossy PPF read without texture IDs.
    props = '<string name="Name">%s</string>'%escape(p["name"])
    props += cf(p) + vec3("Vector3","size",p["size"])
    props += '<Color3 name="Color"><R>%s</R><G>%s</G><B>%s</B></Color3>'%tuple(map(number,c))
    props += '<float name="Reflectance">%s</float>'%number(.13 if p["mat"]=="paint" else .04 if p["mat"]=="glass" else 0)
    props += '<float name="Transparency">%s</float>'%number(1 if p["hidden"] else transparency)
    props += '<bool name="Anchored">true</bool><bool name="CanCollide">false</bool>'
    cls="Part" if p["shape"]=="Ball" else p["shape"]
    return '<Item class="%s" referent="VX%d"><Properties>%s</Properties></Item>'%(cls,index,props)

def save():
    # The offline proxy and import metadata follow the refined scene. Curved
    # meshes are approximated by boxes only in this offline proxy.
    current = {ob.name: ob for ob in scene.objects if ob.type == 'MESH'}
    parts[:] = [p for p in parts if p['name'] in current]
    known = {p['name']: p for p in parts}
    bpy.context.view_layer.update()
    for name, ob in current.items():
        if ob.get('vortex_shaped'):
            p = known.get(name)
            if p is None:
                p = {'name':name,'hidden':False}
                parts.append(p)
            p.update(pos=(ob.location.x,ob.location.z,-ob.location.y),
                     size=(ob.dimensions.x,ob.dimensions.z,ob.dimensions.y),
                     rot=[list(row) for row in Matrix.Identity(3)],shape='Part',
                     mat=ob.data.materials[0].name)
        elif name in ('Dash','DashScreen') or name.startswith('Steer_'):
            known[name]['pos'] = (ob.location.x,ob.location.z,-ob.location.y)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "blackout_vortex.blend"))
    # The locator is hidden in the saved viewport but must remain in exports.
    for ob in scene.objects:
        ob.hide_set(False)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=str(OUT / "blackout_vortex.fbx"), use_selection=True,
                             axis_forward="-Z",axis_up="Y",add_leaf_bones=False,
                             bake_space_transform=False,apply_unit_scale=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / "blackout_vortex.glb"),export_format="GLB")
    bpy.ops.object.select_all(action="DESELECT")
    for ob in scene.objects:
        ob.select_set(bool(ob.get("vortex_shaped")))
    bpy.ops.export_scene.fbx(filepath=str(OUT / "vortex_shaped_body.fbx"), use_selection=True,
                             axis_forward="-Z", axis_up="Y", add_leaf_bones=False,
                             bake_space_transform=False, apply_unit_scale=True)
    model = '<Item class="Model" referent="VXMODEL"><Properties><string name="Name">VortexKart</string></Properties>'
    model += ''.join(xml_part(p,i) for i,p in enumerate(parts,1)) + '</Item>'
    ASSET.write_text('<roblox version="4">'+model+'</roblox>')
    manifest = {"parts":len(parts), "wheels":list(HUBS), "door_parts":len([p for p in parts if p["name"].startswith("Door_")]),
                "led_parts":len([p for p in parts if p["mat"]=="white"]),
                "chassis":(0,1.75,-.05), "steering_hub":STEER}
    manifest['source_meshes'] = sum(o.type == 'MESH' for o in scene.objects)
    manifest['shaped_meshes'] = sum(bool(o.get('vortex_shaped')) for o in scene.objects)
    manifest['revision'] = 'Curved prototype canopy from IMG_7147; local source/export review'
    manifest['production_import_pending'] = True
    (OUT / "manifest.json").write_text(json.dumps(manifest,indent=2))
    print("VORTEX_EXPORT",manifest)

import importlib.util
shape_spec = importlib.util.spec_from_file_location("shape_vortex", HERE / "shape_vortex.py")
shape_module = importlib.util.module_from_spec(shape_spec)
shape_spec.loader.exec_module(shape_module)
shape_module.refine(bpy, material, r2b)
canopy_spec = importlib.util.spec_from_file_location("refine_canopy", HERE / "refine_canopy.py")
canopy_module = importlib.util.module_from_spec(canopy_spec)
canopy_spec.loader.exec_module(canopy_module)
canopy_module.refine(bpy, material, r2b)
for key in ('paint','black','carbon','glass'):
    c,rough,metal,_ = PALETTE[key]
    PALETTE[key] = (c,rough,metal,0)
save()
