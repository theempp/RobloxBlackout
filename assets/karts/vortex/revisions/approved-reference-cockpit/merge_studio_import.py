"""Put Studio-uploaded body MeshParts into the playable Vortex template.

Run after importing export/vortex_shaped_body.fbx to Studio and saving the
temporary place as build/vortex-import-stage.rbxlx. The wheels, LEDs, frame,
and control names are retained from the offline proxy.
"""
from copy import deepcopy
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
PROXY = ROOT / "assets/karts/vortex/export/VortexKartProxy.rbxmx"
STAGE = ROOT / "build/vortex-import-stage.rbxlx"
OUT = ROOT / "assets/roblox/VortexKart.rbxmx"


def named(item):
    node = item.find("./Properties/string[@name='Name']")
    return node.text if node is not None else None


def put(props, tag, name, value):
    node = ET.SubElement(props, tag, {"name": name})
    node.text = str(value)
    return node


def vec(props, tag, name, xyz):
    node = ET.SubElement(props, tag, {"name": name})
    for axis, value in zip("XYZ", xyz):
        ET.SubElement(node, axis).text = format(float(value), ".9g")


def main():
    base = ET.parse(PROXY).getroot()
    model = base.find("Item")
    old = {named(p): p for p in model.findall("Item")}
    stage = ET.parse(STAGE).getroot()
    imports = next(p for p in stage.iter("Item") if p.attrib.get("class") == "Model" and named(p) == "vortex_shaped_body")
    seen = set()
    for imported in imports.findall("Item"):
        name = named(imported)
        assert imported.attrib.get("class") == "MeshPart" and name in old, name
        src = imported.find("Properties")
        mesh_id = src.find("Content[@name='MeshId']")
        assert mesh_id is not None and mesh_id.find("url") is not None and mesh_id.find("url").text.startswith("rbxassetid://"), name
        prior = old[name].find("Properties")
        p = ET.Element("Item", {"class": "MeshPart", "referent": "VX_MESH_" + name})
        props = ET.SubElement(p, "Properties")
        put(props, "string", "Name", name)
        pos = src.find("CoordinateFrame[@name='CFrame']")
        x,y,z = (float(pos.find(a).text) for a in "XYZ")
        # Studio's FBX import uses centimeters and the opposite X/Z heading.
        cf = ET.SubElement(props, "CoordinateFrame", {"name": "CFrame"})
        for a,v in zip("XYZ",(-x/100,y/100,-z/100)):
            ET.SubElement(cf,a).text = format(v,".9g")
        for i in range(3):
            for j in range(3):
                ET.SubElement(cf,f"R{i}{j}").text = str((-1 if i in (0,2) else 1) if i==j else 0)
        # MeshPart uses this hidden import dimension to scale the uploaded
        # centimeter geometry to Size. Without it the visual stays 100x larger
        # even though its reported Size and collision box are in studs.
        props.append(deepcopy(src.find("Vector3[@name='InitialSize']")))
        size = src.find("Vector3[@name='size']")
        dims = [float(size.find(a).text)/100 for a in "XYZ"]
        vec(props,"Vector3","size",dims)
        props.append(deepcopy(prior.find("Color3[@name='Color']")))
        for tag,key in (("float","Reflectance"),("float","Transparency")):
            props.append(deepcopy(prior.find(f"{tag}[@name='{key}']")))
        put(props,"bool","Anchored","true")
        put(props,"bool","CanCollide","false")
        put(props,"bool","CanQuery","false")
        put(props,"bool","CanTouch","false")
        props.append(deepcopy(mesh_id))
        model.remove(old[name])
        model.append(p)
        seen.add(name)
    manifest = json.loads((PROXY.parent/'manifest.json').read_text())
    expected = manifest.get('shaped_meshes', 18)
    assert len(seen) == expected, (len(seen), expected, sorted(seen))
    OUT.write_bytes(ET.tostring(base,encoding="utf-8",xml_declaration=True))
    print(f"VORTEX_STUDIO_MERGE {len(seen)} uploaded meshes, {len(model.findall('Item'))} named pieces -> {OUT}")


if __name__ == "__main__":
    main()
