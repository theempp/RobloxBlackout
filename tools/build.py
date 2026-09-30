#!/usr/bin/env python3
"""Minimal Rojo-compatible builder: project.json -> .rbxlx (Rojo isn't installed; `rojo build` is a drop-in).

Supports: $className, $path (dir -> Folder, *.server.luau -> Script, *.client.luau -> LocalScript,
*.luau -> ModuleScript), $properties (bool/int/float/string). Usage: build.py [project.json] [out.rbxlx]
"""
import json, os, sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVICES = {'ReplicatedStorage', 'ServerScriptService', 'StarterPlayer', 'Workspace', 'Lighting',
            'StarterGui', 'SoundService', 'ServerStorage', 'StarterPlayerScripts', 'StarterCharacterScripts'}
_ref = [0]


def ref():
    _ref[0] += 1
    return f'RBX{_ref[0]}'


def prop(name, v):
    if isinstance(v, bool):
        return f'<bool name="{name}">{str(v).lower()}</bool>'
    if isinstance(v, int):
        return f'<int name="{name}">{v}</int>'
    if isinstance(v, float):
        return f'<float name="{name}">{v}</float>'
    return f'<string name="{name}">{escape(str(v))}</string>'


def item(cls, name, children=(), props=None, source=None):
    p = [prop('Name', name)] + [prop(k, v) for k, v in (props or {}).items()]
    if source is not None:
        p.append('<ProtectedString name="Source"><![CDATA[' + source.replace(']]>', ']]]]><![CDATA[>') + ']]></ProtectedString>')
    return f'<Item class="{cls}" referent="{ref()}"><Properties>{"".join(p)}</Properties>{"".join(children)}</Item>'


def from_path(path, name):
    full = os.path.join(ROOT, path)
    if os.path.isdir(full):
        kids = [from_path(os.path.join(path, f), None) for f in sorted(os.listdir(full))
                if not f.startswith('.') and (f.endswith('.luau') or os.path.isdir(os.path.join(full, f)))]
        return item('Folder', name or os.path.basename(path), kids)
    base = os.path.basename(path)
    for suffix, cls in (('.server.luau', 'Script'), ('.client.luau', 'LocalScript'), ('.luau', 'ModuleScript')):
        if base.endswith(suffix):
            with open(full, encoding='utf-8') as fh:
                return item(cls, name or base[:-len(suffix)], source=fh.read())
    raise ValueError(path)


def node(name, spec):
    if '$path' in spec:
        return from_path(spec['$path'], name)
    kids = [node(k, v) for k, v in spec.items() if not k.startswith('$')]
    cls = spec.get('$className') or (name if name in SERVICES else 'Folder')
    return item(cls, name, kids, spec.get('$properties'))


def build(project, out):
    with open(os.path.join(ROOT, project)) as fh:
        tree = json.load(fh)['tree']
    body = ''.join(node(k, v) for k, v in tree.items() if not k.startswith('$'))
    os.makedirs(os.path.dirname(os.path.join(ROOT, out)), exist_ok=True)
    with open(os.path.join(ROOT, out), 'w', encoding='utf-8') as fh:
        fh.write('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
                 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="4">' + body + '</roblox>')
    return os.path.join(ROOT, out)


if __name__ == '__main__':
    proj = sys.argv[1] if len(sys.argv) > 1 else 'default.project.json'
    out = sys.argv[2] if len(sys.argv) > 2 else 'build/place.rbxlx'
    print(build(proj, out))
