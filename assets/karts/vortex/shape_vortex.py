"""Sculpt the Vortex's continuous body and enclosed canopy after proxy generation.

Coordinates below are in the game's X/right, Y/up, Z/rear frame. Each mesh has
its own editable vertices and origin; the named door and wheel pivots survive FBX.
"""
import math
from mathutils import Vector


def refine(bpy, material, r2b):
    scene = bpy.context.scene

    def remove(*names):
        for name in names:
            ob = bpy.data.objects.get(name)
            if ob:
                bpy.data.objects.remove(ob, do_unlink=True)

    def mesh(name, vertices, faces, mat, pivot=(0, 0, 0), smooth=True):
        remove(name)
        data = bpy.data.meshes.new(name)
        data.from_pydata([r2b((x-pivot[0], y-pivot[1], z-pivot[2])) for x, y, z in vertices], [], faces)
        data.update()
        data.materials.append(material(mat))
        ob = bpy.data.objects.new(name, data)
        scene.collection.objects.link(ob)
        ob.location = r2b(pivot)
        for poly in data.polygons:
            poly.use_smooth = smooth
        ob["vortex_group"] = name.split("_")[0]
        ob["vortex_shaped"] = True
        return ob

    def loft(name, stations, mat="paint", count=20):
        # Station: z, half-width, lower Y, upper Y, crown. Rounded cross section
        # varies along the car; end rings close the watertight shell.
        verts = []
        for z, width, bottom, top, crown in stations:
            cy = (bottom + top) / 2
            ry = (top - bottom) / 2
            for i in range(count):
                a = math.tau * i / count
                x = width * math.cos(a)
                y = cy + ry * math.sin(a) + crown * max(0, math.sin(a)) * (1 - abs(math.cos(a)))
                verts.append((x, y, z))
        faces = [tuple(reversed(range(count)))]
        for k in range(len(stations)-1):
            for i in range(count):
                j = (i+1) % count
                faces.append((k*count+i, k*count+j, (k+1)*count+j, (k+1)*count+i))
        faces.append(tuple((len(stations)-1)*count+i for i in range(count)))
        ob = mesh(name, verts, faces, mat, pivot=(0, 0, (stations[0][0]+stations[-1][0])/2))
        bevel = ob.modifiers.new("Soft panel edges", "BEVEL")
        bevel.width, bevel.segments = .035, 2
        ob.modifiers.new("Weighted panel normals", "WEIGHTED_NORMAL")
        return ob

    def panel(name, rows, mat="glass", thickness=.018):
        # Rows run front to rear, with several points across each pane.
        width = len(rows[0])
        verts = [p for row in rows for p in row]
        faces = []
        for j in range(len(rows)-1):
            for i in range(width-1):
                faces.append((j*width+i, j*width+i+1, (j+1)*width+i+1, (j+1)*width+i))
        cx = sum(p[0] for p in verts)/len(verts)
        cy = sum(p[1] for p in verts)/len(verts)
        cz = sum(p[2] for p in verts)/len(verts)
        ob = mesh(name, verts, faces, mat, pivot=(cx,cy,cz))
        solid = ob.modifiers.new("Pane thickness", "SOLIDIFY")
        solid.thickness = thickness
        bevel = ob.modifiers.new("Soft glass edge", "BEVEL")
        bevel.width, bevel.segments = .012, 2
        return ob

    # Long pointed nose with a rising cowl. The cockpit remains open inside
    # its dark glazing; there is no solid roof in the driver's sightline.
    loft("NoseCore", [
        (-5.48,.13,.54,.64,0),(-5.22,.47,.48,.84,.01),
        (-4.75,.82,.49,1.04,.02),(-4.13,1.00,.52,1.20,.04),
        (-3.45,1.08,.55,1.29,.06),(-2.80,1.12,.58,1.36,.06),
        (-2.18,1.18,.60,1.48,.04),(-1.65,1.23,.64,1.62,.02)])
    remove("NoseBridge", "FrontCowl")
    loft("FrontCowl", [(-2.22,1.16,.88,1.40,.03),(-1.86,1.27,.92,1.57,.05),
                       (-1.48,1.29,.92,1.65,.04),(-1.18,1.25,.89,1.66,.02)])
    remove("CockpitTub")
    loft("CockpitTub", [(-1.85,1.24,.36,1.25,.0),(-1.43,1.38,.38,1.34,.02),
                        (-.60,1.52,.36,1.40,.02),(.45,1.55,.36,1.46,.03),
                        (1.40,1.44,.39,1.52,.02),(1.84,1.31,.46,1.59,.02)])
    remove("EngineDeck", "EngineCover", "RearClosure", "RearRoofBridge")
    loft("EngineCover", [(1.45,1.10,.86,2.36,.06),(1.75,1.25,.72,2.30,.06),
                         (2.25,1.38,.63,2.20,.06),(3.05,1.48,.58,2.09,.05),
                         (3.85,1.54,.52,1.96,.04),(4.70,1.67,.51,1.75,.02),
                         (5.22,1.83,.54,1.52,.01)])
    loft("RearRoofBridge", [(1.28,1.13,1.54,2.52,.02),(1.63,1.29,1.47,2.45,.04),
                            (1.96,1.36,1.35,2.32,.04),(2.18,1.34,1.28,2.25,.02)])
    loft("RearClosure", [(4.65,1.71,.62,1.52,.02),(5.02,1.96,.61,1.43,.02),
                         (5.38,2.13,.54,1.27,.01)])

    for side, s in (("L",-1),("R",1)):
        # Broad, swept windshield halves converge on the central halo. The
        # outer edge reaches the shoulder/chassis near the front axle line.
        remove("Door_"+side+"_Glass", "Door_"+side+"_SideGlass",
               "Door_"+side+"_RoofGlass", "Door_"+side+"_Shell")
        wind = []
        for z, inner_y, outer_x, outer_y in [
            (-2.28,1.69,1.48,1.52),(-1.91,1.98,1.53,1.59),
            (-1.39,2.28,1.57,1.69),(-.81,2.60,1.60,1.83),
            (-.21,2.79,1.59,1.99),(.12,2.84,1.55,2.09)]:
            wind.append([(s*x, inner_y+(outer_y-inner_y)*t, z)
                         for t,x in ((0,.09),(.25,.45),(.53,.91),(1,outer_x))])
        panel("Door_"+side+"_Glass", wind)
        # Deep black side glazing, following the silhouette in the photograph.
        side_rows = []
        for z, bottom, top, x in [(-.28,1.72,2.02,1.56),(.12,1.58,2.13,1.57),
                                   (.70,1.55,2.32,1.51),(1.24,1.57,2.41,1.37),
                                   (1.72,1.64,2.32,1.19)]:
            side_rows.append([(s*x, bottom+(top-bottom)*t, z) for t in (0,.35,.7,1)])
        panel("Door_"+side+"_SideGlass", side_rows)
        roof_rows = []
        for z, h, outer_x, outer_y in [(-.16,2.79,1.59,2.03),(.35,2.87,1.52,2.25),
                                       (.91,2.84,1.40,2.38),(1.43,2.67,1.23,2.40),
                                       (1.70,2.46,1.12,2.28)]:
            roof_rows.append([(s*x, h+(outer_y-h)*t, z)
                              for t,x in ((0,.10),(.32,.45),(.68,.85),(1,outer_x))])
        panel("Door_"+side+"_RoofGlass", roof_rows)
        # Curved painted door lower skin, separate so the existing Motor6D
        # continues to lift each butterfly leaf as one side.
        shell_rows = []
        for z, x, top in [(-2.20,1.38,1.54),(-1.53,1.55,1.62),(-.65,1.65,1.76),
                          (.35,1.63,1.66),(1.19,1.47,1.62),(1.73,1.24,1.70)]:
            shell_rows.append([(s*(x-.42*t), .86+(top-.86)*t, z) for t in (0,.36,.72,1)])
        panel("Door_"+side+"_Shell", shell_rows, "paint", .07)
        remove("CanopyButtress_"+side, "RearQuarter_"+side, "RearHaunch_"+side)
        haunch_rows=[]
        for z, outer, crown in [(1.31,1.34,2.44),(1.72,1.65,2.35),
                                 (2.25,1.96,2.09),(3.08,2.17,1.78),
                                 (3.91,2.24,1.56),(4.77,2.19,1.35),(5.13,2.06,1.23)]:
            haunch_rows.append([(s*x,y,z) for x,y in
                                ((.88,1.43),(1.11,crown),(outer-.20,crown-.13),(outer,1.18))])
        panel("RearHaunch_"+side,haunch_rows,"paint",.09)
        # A small upturned shoulder makes the roof and engine cover read as
        # one flowing body surface from the three-quarter view.
        shoulder=[]
        for z,x,y in [(1.31,1.17,2.39),(1.68,1.27,2.36),(2.16,1.40,2.18),
                      (2.73,1.56,2.01),(3.38,1.64,1.81)]:
            shoulder.append([(s*(x+.24*t),y-.25*t,z) for t in (0,.5,1)])
        panel("CanopyButtress_"+side,shoulder,"paint",.065)

    # The halo is deliberately kept as three named structural pieces and all
    # four wheel meshes remain untouched so game articulation still aligns.
