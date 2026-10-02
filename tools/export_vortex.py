"""Extract approved evaluated geometry; never modifies its snapshot. Run with Blender."""
import bpy, hashlib, json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=R/'assets/karts/vortex/revisions/approved-reference-cockpit'
a=json.loads((S/'APPROVAL.json').read_text())
for f,h in a['files'].items():
    assert hashlib.sha256((S/f).read_bytes()).hexdigest()==h, f
bpy.ops.wm.open_mainfile(filepath=str(S/'blackout_vortex.blend'))
# Apply source modifiers only in this temporary scene, then budget each named piece.
for ob in list(bpy.context.scene.objects):
    if ob.type!='MESH': continue
    bpy.context.view_layer.objects.active=ob
    for mod in list(ob.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.data.calc_loop_triangles()
    n=len(ob.data.loop_triangles)
    if n>16:
        mod=ob.modifiers.new('PhoneBudget','DECIMATE'); mod.ratio=.125
        bpy.ops.object.modifier_apply(modifier=mod.name)
deps=bpy.context.evaluated_depsgraph_get()
out=[]
for ob in sorted(bpy.context.scene.objects,key=lambda x:x.name):
    if ob.type!='MESH': continue
    ev=ob.evaluated_get(deps); me=ev.to_mesh(); me.calc_loop_triangles()
    verts=[]
    for v in me.vertices:
        p=ob.matrix_world@v.co
        verts.append([round(p.x,6),round(p.z,6),round(-p.y,6)])
    mat=ob.data.materials[0] if ob.data.materials else None
    col=list(mat.diffuse_color) if mat else [.02,.02,.02,1]
    out.append(dict(name=ob.name,vertices=verts,triangles=[list(t.vertices) for t in me.loop_triangles],color=col))
    ev.to_mesh_clear()
p=R/'assets/karts/vortex/approved-geometry.json'
p.write_text(json.dumps(out,separators=(',',':')))
total=sum(len(x['triangles']) for x in out)
assert len(out)==117 and total<=8000, (len(out),total)
lines=['-- Generated approved Vortex phone derivative. Snapshot untouched.', 'return { tris = '+str(total)+', pieces = {']
for x in out:
    vs=x['vertices']; lo=[min(v[i] for v in vs) for i in range(3)]; hi=[max(v[i] for v in vs) for i in range(3)]; c=[(a+b)/2 for a,b in zip(lo,hi)]
    def vec(v): return 'Vector3.new('+','.join(str(round(a,6)) for a in v)+')'
    lines.append('{ name = '+json.dumps(x['name'])+', center = '+vec(c)+', color = Color3.new('+','.join(str(round(v,4)) for v in x['color'][:3])+'), vertices = {'+','.join(vec([v[i]-c[i] for i in range(3)]) for v in vs)+'}, faces = {'+','.join('{'+','.join(str(i+1) for i in t)+'}' for t in x['triangles'])+'} },')
lines.append('} }')
(R/'src/shared/VortexArt.luau').write_text('\n'.join(lines))
bpy.ops.wm.save_as_mainfile(filepath=str(R/'assets/karts/vortex/phone-optimized.blend'))
print('BC_GEOMETRY',len(out),total)
