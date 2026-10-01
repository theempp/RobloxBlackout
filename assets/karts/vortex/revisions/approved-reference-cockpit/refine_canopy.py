"""Reference-led prototype canopy. Coordinates: X/right, Y/up, Z/rear.

The windshield is one uninterrupted curved pane. Side glass,
pillars and roof share boundary curves, avoiding the old overlapping wedges.
"""
import math
from mathutils import Vector


def refine(bpy, material, r2b):
    def remove(name):
        ob = bpy.data.objects.get(name)
        if ob:
            bpy.data.objects.remove(ob, do_unlink=True)

    def bez(a, b, c, d, t):
        return (Vector(a)*(1-t)**3 + Vector(b)*3*t*(1-t)**2
                + Vector(c)*3*t*t*(1-t) + Vector(d)*t**3)

    def surface(name, fn, mat, nu=24, nv=18, thickness=.025, flip=False):
        remove(name)
        verts = [Vector(fn(i/nu, j/nv)) for j in range(nv+1) for i in range(nu+1)]
        centre = sum(verts, Vector()) / len(verts)
        faces = []
        for j in range(nv):
            for i in range(nu):
                k = j*(nu+1)+i
                f = (k, k+1, k+nu+2, k+nu+1)
                faces.append(tuple(reversed(f)) if flip else f)
        data = bpy.data.meshes.new(name)
        data.from_pydata([r2b(v-centre) for v in verts], [], faces)
        data.materials.append(material(mat))
        data.update()
        # Analytic boundary normals keep the two windshield leaves visually
        # continuous at their shared centreline, including in the exports.
        normals = []
        eps = .0001
        for j in range(nv+1):
            for i in range(nu+1):
                u,v = i/nu,j/nv
                du = Vector(fn(u+eps,v))-Vector(fn(u-eps,v))
                dv = Vector(fn(u,v+eps))-Vector(fn(u,v-eps))
                normal = du.cross(dv).normalized()
                normals.append(r2b(-normal if flip else normal))
        data.normals_split_custom_set_from_vertices(normals)
        ob = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = r2b(centre)
        ob['vortex_group'] = name.split('_')[0]
        ob['vortex_shaped'] = True
        for f in data.polygons:
            f.use_smooth = True
        if thickness:
            solid = ob.modifiers.new('Laminated surface thickness', 'SOLIDIFY')
            solid.thickness = thickness
            solid.offset = -1
        return ob

    def tube(name, points, radius, mat='paint', sides=8):
        remove(name)
        verts, faces = [], []
        for i, p in enumerate(points):
            p = Vector(p)
            tangent = Vector(points[min(i+1,len(points)-1)]) - Vector(points[max(0,i-1)])
            tangent.normalize()
            across = tangent.cross(Vector((0,1,0)))
            if across.length < .01:
                across = tangent.cross(Vector((1,0,0)))
            across.normalize()
            normal = tangent.cross(across).normalized()
            for k in range(sides):
                a = math.tau*k/sides
                verts.append(p+radius*(math.cos(a)*across+math.sin(a)*normal))
        for i in range(len(points)-1):
            for k in range(sides):
                a = i*sides+k
                b = i*sides+(k+1)%sides
                faces.append((a,b,b+sides,a+sides))
        faces += [tuple(reversed(range(sides))), tuple((len(points)-1)*sides+k for k in range(sides))]
        centre = sum(verts, Vector()) / len(verts)
        data = bpy.data.meshes.new(name)
        data.from_pydata([r2b(v-centre) for v in verts], [], faces)
        data.materials.append(material(mat))
        data.update()
        ob = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = r2b(centre)
        ob['vortex_shaped'] = True
        for f in data.polygons:
            f.use_smooth = True
        return ob

    # Keep paint opaque; the previous alpha setting made overlapping panels
    # appear crumpled. Dark coated glazing uses physical surface reflections.
    for key in ('paint','black','carbon','glass'):
        mat = material(key)
        mat.diffuse_color = (*mat.diffuse_color[:3], 1)
        bs = mat.node_tree.nodes.get('Principled BSDF')
        bs.inputs['Alpha'].default_value = 1
        if key == 'glass':
            bs.inputs['Base Color'].default_value = (.006,.009,.011,1)
            bs.inputs['Roughness'].default_value = .19
            bs.inputs['Metallic'].default_value = 0
            bs.inputs['Specular IOR Level'].default_value = .32
            bs.inputs['Coat Weight'].default_value = .18
            bs.inputs['Coat Roughness'].default_value = .09
            bs.inputs['IOR'].default_value = 1.48
        if key == 'paint':
            bs.inputs['Metallic'].default_value = .35
            bs.inputs['Roughness'].default_value = .23
            bs.inputs['Coat Weight'].default_value = .45
            bs.inputs['Coat Roughness'].default_value = .13

    # A compact, double-curved windshield: foot moved 0.71 stud rearward,
    # rounded brow and corners, and one uninterrupted reflective front face.
    def wind(u, v):
        lower = Vector((1.20*u, 1.75+.045*(1-u*u), -1.57+.23*u*u))
        upper = Vector((.91*u, 2.97-.15*u*u, .08+.18*u*u))
        p = lower.lerp(upper, v)
        p.x += .09*u*math.sin(math.pi*v)
        p.y += .065*math.sin(math.pi*v)
        p.z -= .13*(1-u*u)*math.sin(math.pi*v)
        return p

    # Cubic roof rails produce the rounded side-window outline in IMG_7147.
    a, b = wind(1,0), wind(1,1)
    c, d = Vector((.97,2.76,1.23)), Vector((1.28,1.80,1.66))
    def upper(t):
        return bez(b,(.97,2.94,.55),(.94,2.91,1.06),c,t)
    def lower(t):
        return bez(a,(1.39,1.71,-.55),(1.43,1.70,.96),d,t)
    def rear(v):
        return bez(d,(1.39,2.13,1.92),(1.04,2.72,1.64),c,v)
    def side(t,v):
        edge = lower(t)*(1-v)+upper(t)*v + wind(1,v)*(1-t)+rear(v)*t
        corners = a*(1-t)*(1-v)+b*(1-t)*v+d*t*(1-v)+c*t*v
        p = edge-corners
        p.x += .075*math.sin(math.pi*t)*math.sin(math.pi*v)
        return p
    def mirror(p,s):
        return (s*p[0],p[1],p[2])

    for name in ('HaloFront','HaloCrown','HaloRear_L','HaloRear_R', 'RearRoofBridge'):
        remove(name)
    for name in ('Door_L_Glass','Door_R_Glass'):
        remove(name)
    surface('Windshield',lambda u,v: wind(-1+2*u,v),'glass',48,24,flip=True)
    def cowl(u,v):
        x = -1+2*u
        front = Vector((1.12*x,1.44-.10*x*x,-2.35+.08*x*x))
        back = wind(x,0)-Vector((0,.028,0))
        p = front.lerp(back,v)
        p.y += .025*math.sin(math.pi*v)
        return p
    surface('FrontCowl',cowl,'paint',32,12,.065,flip=True)
    for label,s in (('L',-1),('R',1)):
        prefix = 'Door_'+label+'_'
        # Painted side surface under a slightly inset-size glazed opening.
        surface(prefix+'OuterFrame',lambda u,v: mirror(side(u,v),s),'paint',28,24,flip=s>0)
        def sideglass(u,v):
            p = side(.035+.92*u,.075+.86*v)
            p.x += .016
            return mirror(p,s)
        surface(prefix+'SideGlass',sideglass,'glass',28,24,.016,flip=s>0)
        tube(prefix+'FrontFrame',[wind(s*i/24,0) for i in range(25)],.031,'black')
        tube(prefix+'RearFrame',[mirror(wind(1,i/32),s) for i in range(33)],.038,'paint')
        tube(prefix+'SideLowerFrame',[mirror(lower(i/32),s) for i in range(33)],.036,'paint')
        tube('Shoulder_'+label,[mirror(lower(i/32),s) for i in range(33)],.055,'paint')
        # Replace the old floating white cockpit bars with slim black seals.
        tube(prefix+'Rim',[mirror(side(i/32,.065),s) for i in range(33)],.016,'black')
        # Roof starts on the windshield brow and meets the side-window rail.
        def roof(u,t):
            rail = upper(t)
            centre = bez((0,2.97,.08),(0,3.13,.47),(0,3.12,1.01),(0,3.01,1.23),t)
            p = centre.lerp(rail,u*u)
            p.x = rail.x*u
            return mirror(p,s)
        surface(prefix+'RoofGlass',roof,'paint',20,24,.04,flip=s>0)
        # Rounded C-pillar sweeps down into the existing rear shoulder.
        def pillar(u,v):
            front = rear(v)
            back = Vector((1.35-.35*v,1.66+1.03*v,2.02-.20*v))
            p = front.lerp(back,u)
            p.x += .035*math.sin(math.pi*u)
            return mirror(p,s)
        surface('CanopyButtress_'+label,pillar,'paint',14,20,.05,flip=s>0)
        def doorskin(t,v):
            top = lower(t)
            bottom = Vector((1.48+.12*math.sin(math.pi*t),.88,top.z))
            return mirror(bottom.lerp(top,v),s)
        surface(prefix+'Shell',doorskin,'paint',28,12,.065,flip=s>0)

    # Rear roof cap, with the same rounded crown as the front roof.
    def rearroof(u,v):
        x = -1+2*u
        front = Vector((.97*x,3.01-.25*x*x,1.23))
        back = Vector((1.00*x,2.73-.04*x*x,1.82))
        p = front.lerp(back,v)
        p.y += .055*math.sin(math.pi*v)
        return p
    surface('RearRoofBridge',rearroof,'paint',32,16,.05,flip=True)

    # Sculpted roof intake: a rounded mouth and a tapered fairing, echoing
    # the reference's roof profile while retaining the Vortex black finish.
    def intake(u,t):
        angle = math.tau*u
        def signedpow(x,p):
            return math.copysign(abs(x)**p,x)
        width = .37*(1-.72*t*t)
        height = .23*(1-.40*t)
        cy = 3.20-.23*t*t
        return (width*signedpow(math.cos(angle),.65),cy+height*signedpow(math.sin(angle),.65),.48+1.24*t)
    surface('AirScoop',intake,'paint',40,20,.035)
    ring = [intake(i/48,0) for i in range(49)]
    tube('ScoopLip',ring,.032,'paint',10)
    remove('ScoopMouth')
    cap = bpy.data.meshes.new('ScoopMouth')
    cap.from_pydata([r2b((p[0]*.98,(p[1]-3.20)*.98+3.20,.475)) for p in ring[:-1]],
                   [], [tuple(range(len(ring)-1))])
    cap.materials.append(material('intake'))
    cap.update()
    mouth = bpy.data.objects.new('ScoopMouth',cap)
    bpy.context.scene.collection.objects.link(mouth)
    mouth['vortex_shaped'] = True
    cap_thickness = mouth.modifiers.new('Intake backing thickness','SOLIDIFY')
    cap_thickness.thickness = .018

    # The revised lower glass edge sits behind the old dash location.
    # Tuck the dashboard under the new cowl, keeping its named moving controls.
    bpy.data.objects['Dash'].location = r2b((0,1.60,-1.09))
    bpy.data.objects['DashScreen'].location = r2b((0,1.74,-1.12))
    # Flatten the wheel's upper arc below the shorter windshield. Its centre
    # and steering pivot stay fixed; no rim can poke through the glazing.
    for ob in bpy.context.scene.objects:
        if ob.name.startswith('Steer_'):
            ob.location.z = 1.85+(ob.location.z-1.85)*.65
            for vertex in ob.data.vertices:
                vertex.co.z *= .65

    # Comfortable, uncluttered material preview when opened interactively.
    for ob in bpy.context.scene.objects:
        ob.select_set(False)
        if ob.name == 'Chassis':
            ob.hide_set(True)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == 'VIEW_3D':
                space = area.spaces.active
                space.shading.type = 'MATERIAL'
                space.overlay.show_overlays = False
                space.region_3d.view_distance = 16
                space.region_3d.view_location = (0,0,1.5)
                direction = Vector((8,10,6))
                space.region_3d.view_rotation = direction.to_track_quat('Z','Y')
