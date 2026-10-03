"""Cockpit, flat colours, collision proxies and evaluated FBX/GLB export."""
import bpy,bmesh,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE/'.deps'))
import numpy as np
from PIL import Image
from scipy.spatial import cKDTree, ConvexHull
from scipy.interpolate import PchipInterpolator
from mathutils.bvhtree import BVHTree
bpy.ops.wm.open_mainfile(filepath=str(HERE/'wheel_stage.blend'))
source=HERE/'source/Meshy_AI_Shadow_Velocity_1003043122_generate.fbx'
expected=(HERE/'source/SHA256.txt').read_text().split()[0]
assert hashlib.sha256(source.read_bytes()).hexdigest()==expected
def r2b(p):return Vector((p[0],-p[2],p[1]))
def b2r(p):return (p.x,p.z,-p.y)
def activate(ob):
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
def seal_triangulated_wheel(ob):
    """Replace only residual pinched cut-seam patches with simple triangle fans."""
    bm=bmesh.new();bm.from_mesh(ob.data)
    badverts={v for e in bm.edges if not e.is_manifold for v in e.verts}
    if badverts:
        bmesh.ops.delete(bm,geom=list({f for v in badverts for f in v.link_faces}),context='FACES')
        remaining={e for e in bm.edges if e.is_boundary}
        while remaining:
            edge=next(iter(remaining));path=[edge.verts[0]];walk=[];current=path[0]
            while True:
                choices=[e for e in current.link_edges if e in remaining and e not in walk]
                assert choices,'open seam chain'
                e=choices[0];walk.append(e);current=e.other_vert(current)
                if current in path:
                    start=path.index(current);cycle=path[start:];cycle_edges=walk[start:]
                    remaining.difference_update(cycle_edges)
                    assert len(cycle)>=3,'degenerate seam loop'
                    center=bm.verts.new(sum((v.co for v in cycle),Vector())/len(cycle))
                    for i,v in enumerate(cycle):bm.faces.new((v,cycle[(i+1)%len(cycle)],center))
                    break
                path.append(current)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),(ob.name,'final wheel seam')
    bm.to_mesh(ob.data);bm.free()
def box(name,c,size,mat='StealthBlack',hidden=False):
    bpy.ops.mesh.primitive_cube_add(size=1,location=r2b(c));ob=bpy.context.object;ob.name=name
    ob.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    ob.data.materials.append(bpy.data.materials[mat])
    if hidden:ob.hide_render=True;ob.display_type='WIRE';ob['RobloxTransparency']=1
    return ob
body=bpy.data.objects['BodyShell']
def clip_surface(ob,cut):
    """Trim cosmetic shell faces against a convex local clearance volume.

    No volume remeshing or implicit reconstruction: preserve surviving source faces.
    Open wheel-well edges are intentional; separate boxes provide physics collision.
    """
    ob.data.update();bpy.context.view_layer.update()
    points=[cut.matrix_world@v.co for v in cut.data.vertices]
    equations=ConvexHull(np.array(points)).equations
    world=[ob.matrix_world@v.co for v in ob.data.vertices]
    a=BVHTree.FromPolygons(world,[p.vertices[:] for p in ob.data.polygons])
    b=BVHTree.FromPolygons(points,[p.vertices[:] for p in cut.data.polygons])
    remove={i for i,j in a.overlap(b)}
    centers=np.array([ob.matrix_world@p.center for p in ob.data.polygons])
    inside=np.all(centers@equations[:,:3].T+equations[:,3]<=.001,axis=1)
    remove.update(np.flatnonzero(inside).tolist())
    bm=bmesh.new();bm.from_mesh(ob.data);bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[bm.faces[i] for i in remove],context='FACES')
    bm.to_mesh(ob.data);bm.free();ob.data.update()
# Raise only the thin arch roofs before cutting a conservative full-travel wheel
# envelope. This keeps the main aero silhouette and frees tyre/steering motion.
for p in body.data.vertices:
    x,y,z=b2r(p.co)
    for wheel in ['Wheel_FL','Wheel_FR','Wheel_RL','Wheel_RR']:
        hub=b2r(bpy.data.objects[wheel].location)
        if abs(x-hub[0])<.7 and abs(z-hub[2])<1.12 and 1.40<y<2.30:
            p.co.z+=.44*max(0,1-abs(z-hub[2])/1.2);break
clearance_cutters=[]
for wheel in ['Wheel_FL','Wheel_FR','Wheel_RL','Wheel_RR']:
    hub=bpy.data.objects[wheel].location;points=[]
    angles=[-32,-16,0,16,32] if wheel.startswith('Wheel_F') else [0]
    from mathutils import Matrix
    for angle in angles:
        rotation=Matrix.Rotation(math.radians(angle),3,'Z')
        for travel in [-.8,.35]:
            for width in [-.525,.525]:
                for k in range(24):
                    a=k*math.tau/24
                    points.append(hub+rotation@Vector((width,.975*math.cos(a),.975*math.sin(a)))+Vector((0,0,travel)))
    me=bpy.data.meshes.new('WheelClearance');me.from_pydata(points,[],[])
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    cut=bpy.data.objects.new('Clearance_'+wheel,me);bpy.context.scene.collection.objects.link(cut)
    clearance_cutters.append(cut)
    clip_surface(body,cut)
# Hollow the solid draft around the fixed seat; floor is 1.12 studs high.
cutter=box('CockpitCut',(0,3.12,-.15),(4.12,4.0,4.6))
clip_surface(body,cutter);bpy.data.objects.remove(cutter,do_unlink=True)
# Remove the remaining original roof outside the primary cut, above the side pods.
bm=bmesh.new();bm.from_mesh(body.data)
remove=[]
for f in bm.faces:
    c=f.calc_center_median();x,y,z=b2r(c)
    if abs(x)<1.35 and -2.85<z<2.35 and y>1.72:remove.append(f)
bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(body.data);bm.free()
# Longitudinal teardrop sections: z, half width, roof height, sill height.
# Broad shoulders fit a standard 4-stud arm envelope; roof clears a 4.54-stud head.
sections=[(-3.35,.18,1.73,1.50),(-2.50,.90,2.80,1.50),(-1.50,1.75,3.90,1.50),
    (-.70,2.25,4.85,1.50),(.10,2.25,4.88,1.50),(.80,2.25,4.80,1.50),
    (1.40,1.65,3.90,1.50),(2.20,.85,2.55,1.50),(2.85,.18,1.72,1.50)]
section_array=np.array(sections)
zs=sorted(set(np.linspace(-3.35,2.85,10).tolist()+[-.7,-.45,.1,.55,.8]))
sections=[(z,*PchipInterpolator(section_array[:,0],section_array[:,1:],axis=0)(z)) for z in zs]
def canopy_height(x,z):
    width=np.interp(z,[s[0] for s in sections],[s[1] for s in sections])
    top=np.interp(z,[s[0] for s in sections],[s[2] for s in sections])
    return 1.50+(top-1.50)*max(0,1-(abs(x)/width)**4)**.4
for side,sign in [('L',-1),('R',1)]:
    pts=[];polys=[];N=8
    for z,width,top,base in sections:
        for j in range(N+1):
            theta=(j/N)*math.pi/2
            pts.append(r2b((sign*width*math.cos(theta)**.5,base+(top-base)*math.sin(theta)**.8,z)))
    for i in range(len(sections)-1):
        for j in range(N):
            a=i*(N+1)+j;f=(a,a+1,a+N+2,a+N+1)
            polys.append(f if sign==1 else tuple(reversed(f)))
    me=bpy.data.meshes.new('Canopy_'+side);me.from_pydata(pts,[],polys);me.update()
    ob=bpy.data.objects.new('Canopy_'+side,me);bpy.context.scene.collection.objects.link(ob)
    me.materials.append(bpy.data.materials['OpaqueBlackGlass']);me.materials.append(bpy.data.materials['StealthBlack'])
    for p in me.polygons:
        p.material_index=1 if p.index%N>=N-1 else 0;p.use_smooth=True
    activate(ob);mod=ob.modifiers.new('Opaque canopy shell','SOLIDIFY');mod.thickness=.035;mod.offset=-1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # A real opening hinge: lift this leaf outward 68 degrees for access.
    hinge=r2b((sign*2.25,1.50,.10))
    for p in ob.data.vertices:p.co-=hinge
    ob.location=hinge;ob['access_hinge_axis_blender']='Y';ob['open_degrees']=sign*68
    ob['RobloxCanCollide']=False
    for cut in clearance_cutters:
        clip_surface(ob,cut)
# Close the new cockpit sills down to the floor: no floating canopy or open
# side gaps left by removing the original solid cockpit volume.
points=[];polys=[]
for z,width,top,base in sections:
    points.extend([r2b((-width,base,z)),r2b((width,base,z)),
                   r2b((-width*.90,.98,z)),r2b((width*.90,.98,z))])
for i in range(len(sections)-1):
    a=4*i;b=a+4
    polys.extend([(a,b,b+2,a+2),(a+1,a+3,b+3,b+1),(a+2,b+2,b+3,a+3)])
polys.extend([(0,2,3,1),(len(points)-4,len(points)-3,len(points)-1,len(points)-2)])
me=bpy.data.meshes.new('CockpitTub');me.from_pydata(points,[],polys);me.update()
tub=bpy.data.objects.new('CockpitTub',me);bpy.context.scene.collection.objects.link(tub)
me.materials.append(bpy.data.materials['FlatForgedCarbon'])
for p in me.polygons:p.use_smooth=True
for cut in clearance_cutters:clip_surface(tub,cut)
for cut in clearance_cutters:bpy.data.objects.remove(cut,do_unlink=True)
box('CockpitFloor',(0,1.10,-.15),(3.85,.08,4.5),'FlatForgedCarbon')
box('SeatPan',(0,1.46,.05),(1.2,.16,1.2),'TyreBlack')
box('SeatBack',(0,2.05,.78),(1.30,1.05,.16),'TyreBlack')
# Fixed runtime articulation hub and tilt, following Vortex convention.
bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=4,location=r2b((0,1.85,-.95)),major_radius=.31,minor_radius=.045)
steer=bpy.context.object;steer.name='Steer';steer.rotation_euler=(math.radians(60),0,0)
steer.data.materials.append(bpy.data.materials['TyreBlack'])
activate(steer);bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
# Explicit hidden fixed-frame locator and simple runtime-matching collider/ballast.
box('Chassis',(0,1.75,-.05),(5.16,3.14,11.2),hidden=True)
collision=box('Collision',(0,1.25,0),(4.9,1.1,8.4),hidden=True);collision['RobloxCanCollide']=True
ballast=box('Ballast',(0,.55,0),(3,.4,6),hidden=True);ballast['RobloxCanCollide']=False
# Lamps are opaque, non-emissive colour. The rear lamp is exactly one full-width bar.
for side,sign in [('L',-1),('R',1)]:
    box('Headlight_'+side,(sign*1.54,.67,-5.42),(.72,.12,.08),'WhiteHeadlamp')
    box('DiffuserLamp_'+side,(sign*1.16,.67,5.48),(.64,.10,.08),'RedTailLamp')
box('TailLamp',(0,2.19,5.57),(4.45,.095,.065),'RedTailLamp')
# Flat carbon treatment on splitter, underside and rear wing, without textures.
body.data.materials.append(bpy.data.materials['FlatForgedCarbon'])
for p in body.data.polygons:
    c=body.matrix_world@p.center;x,y,z=b2r(c)
    if y<.55 or (z>4.75 and y>1.3):p.material_index=1
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name!='SOURCE_UNMODIFIED']
activate(body);body.data.validate();body.data.calc_loop_triangles()
if len(body.data.loop_triangles)>4250:
    mod=body.modifiers.new('Body final phone budget','DECIMATE');mod.ratio=4240/len(body.data.loop_triangles)
    bpy.ops.object.modifier_apply(modifier=mod.name)
for ob in meshes:
    activate(ob)
    ob.data.validate(verbose=True,clean_customdata=True);ob.data.update()
    mod=ob.modifiers.new('Evaluated export triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
    if ob.name.startswith('Wheel_'):seal_triangulated_wheel(ob)
    ob.data.calc_loop_triangles()
total=sum(len(o.data.loop_triangles) for o in meshes)
assert total<=8000,total
# Conservative seated standard-avatar proxy: feet/legs, torso, head, and relaxed arms.
proxy=[('Legs',(0,1.92,-.65),(2.0,.70,1.6)),('Torso',(0,2.54,.05),(2,2,1)),
       ('Head',(0,4.04,.05),(2,1,1)),('Arm_L',(-1.5,2.54,.05),(1,2,1)),('Arm_R',(1.5,2.54,.05),(1,2,1))]
clearances=[]
for name,c,s in proxy:
    points=[(c[0]+dx*s[0]/2,c[1]+s[1]/2,c[2]+dz*s[2]/2) for dx in [-1,1] for dz in [-1,1]]
    clearances.extend(canopy_height(x,z)-y-.035 for x,y,z in points)
    p=box('FIT_PROXY_'+name,c,s,hidden=True);p['not_exported']=True
assert min(clearances)>.05,min(clearances)
# Test the actual faceted inner canopy, not only its analytic design curve.
trees=[]
for name in ['Canopy_L','Canopy_R']:
    o=bpy.data.objects[name]
    trees.append(BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[p.vertices[:] for p in o.data.polygons]))
mesh_clearances=[]
for name,c,s in proxy:
    for x in np.linspace(c[0]-s[0]/2,c[0]+s[0]/2,7):
        for z in np.linspace(c[2]-s[2]/2,c[2]+s[2]/2,7):
            start=r2b((x,c[1]+s[1]/2,z))
            hits=[tree.ray_cast(start,Vector((0,0,1)),10)[3] for tree in trees]
            hits=[h for h in hits if h is not None]
            assert hits,('proxy outside canopy',name,x,z)
            mesh_clearances.append(min(hits))
assert min(mesh_clearances)>.05,min(mesh_clearances)
manifest={'asset':'Nightcrawler','status':'Blender derivative; Studio and phone pending',
    'source_sha256':expected,'axis_mapping':'Blender (x,y,z) -> Roblox (x,z,-y)',
    'piece_count':len(meshes),'measured_triangles':total,'triangle_budget':8000,
    'hub_tolerance':.15,'canopy_proxy_min_clearance':min(mesh_clearances),
    'avatar_proxy':'Standard 4-stud arm span, 4.54-stud seated head top; actual owner avatar pending',
    'seat_rb':[0,1.54,.05],'access':'Two canopy leaves, outward 68-degree hinges; runtime wiring pending',
    'materials':'Flat opaque colour; no textures, metallic or emission',
    'collision':'Hidden Collision box and non-colliding Ballast match Config; runtime creates these itself',
    'pieces':[dict(name=o.name,triangles=len(o.data.loop_triangles),pivot_rb=b2r(o.location),
        hidden=o.hide_render,bbox_rb=[b2r(o.matrix_world@Vector(c)) for c in o.bound_box]) for o in meshes]}
out=HERE/'export';out.mkdir(exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'blackout_nightcrawler.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for ob in meshes:ob.hide_set(False);ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(out/'blackout_nightcrawler.fbx'),use_selection=True,axis_forward='-Z',axis_up='Y',
    add_leaf_bones=False,bake_space_transform=False,apply_unit_scale=True,use_custom_props=True)
bpy.ops.export_scene.gltf(filepath=str(out/'blackout_nightcrawler.glb'),export_format='GLB',use_selection=True,export_extras=True)
assert hashlib.sha256(source.read_bytes()).hexdigest()==expected
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('NIGHTCRAWLER_EXPORT',len(meshes),total,'mesh clearance',min(mesh_clearances),flush=True)
