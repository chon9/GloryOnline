# Convert a VRM 0.x file into a slim glTF binary for Godot's built-in importer (game copy of lookdev/tools/vrm2glb.py):
# drops thumbnail/normal/matcap/outline-width textures, downsizes the rest, keeps VRM JSON (humanoid, springs) as a sidecar.
# Usage: python -I vrm2glb.py <in.vrm> <out.glb> [body_px=512] [face_px=1024]
#   body_px: clothes/body/shoes textures; face_px: face, eyes, brows and hair (they carry the anime read in close-ups).
import sys, json, struct, io, re
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
maxsz = int(sys.argv[3]) if len(sys.argv) > 3 else 512
facesz = int(sys.argv[4]) if len(sys.argv) > 4 else 1024
FACE = re.compile(r'(Face|Eye|Hair)')
b = open(src, 'rb').read()
off = 12; js = None; bn = None
while off < len(b):
    l, t = struct.unpack('<II', b[off:off+8]); c = b[off+8:off+8+l]
    if t == 0x4E4F534A: js = json.loads(c)
    else: bn = c
    off += 8 + l
DROP = re.compile(r'(Thumbnail|_nml|Matcap|_out$|_spe$|Shader_None)')
tiny = io.BytesIO(); Image.new('RGBA', (4, 4), (128, 128, 255, 255)).save(tiny, 'PNG'); tiny = tiny.getvalue()
newimg = {}
for i, img in enumerate(js['images']):
    bv = js['bufferViews'][img['bufferView']]
    data = bn[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
    name = img.get('name', '')
    if DROP.search(name):
        newimg[img['bufferView']] = tiny; continue
    im = Image.open(io.BytesIO(data))
    w, h = im.size
    s = min(1.0, (facesz if FACE.search(name) else maxsz) / max(w, h))
    if s < 1.0:
        im = im.resize((max(4, int(w*s)), max(4, int(h*s))), Image.LANCZOS)
    o = io.BytesIO(); im.save(o, 'PNG', optimize=True); newimg[img['bufferView']] = o.getvalue()
    img['mimeType'] = 'image/png'
for m in js['materials']:
    for k in ['normalTexture', 'occlusionTexture', 'emissiveTexture']:
        m.pop(k, None)
    m.pop('extensions', None)  # KHR_materials_unlit -> we replace materials at runtime anyway
js['extensionsUsed'] = [e for e in js.get('extensionsUsed', []) if e not in ('KHR_materials_unlit',)]

# merge primitives that share vertex attributes and material (VRoid hair = 100+ surfaces -> 1 draw call)
extra = {}
def acc_bytes(ai):
    a = js['accessors'][ai]; bv = js['bufferViews'][a['bufferView']]
    st = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    size = {5125: 4, 5123: 2, 5121: 1}[a['componentType']] * a['count']
    return bn[st:st + size], a['componentType']
for mesh in js['meshes']:
    groups = {}
    for p in mesh['primitives']:
        key = (json.dumps(p['attributes'], sort_keys=True), p.get('material'), p.get('mode', 4), json.dumps(p.get('targets'), sort_keys=True))
        groups.setdefault(key, []).append(p)
    newp = []
    for key, ps in groups.items():
        if len(ps) == 1:
            newp.append(ps[0]); continue
        data = bytearray(); cnt = 0
        for p in ps:
            d, ct = acc_bytes(p['indices'])
            if ct == 5123: d = b''.join(struct.pack('<I', v) for v in struct.unpack('<%dH' % (len(d) // 2), d))
            elif ct == 5121: d = b''.join(struct.pack('<I', v) for v in d)
            data += d; cnt += len(d) // 4
        js['bufferViews'].append({'buffer': 0, 'byteLength': len(data), 'target': 34963})
        extra[len(js['bufferViews']) - 1] = bytes(data)
        js['accessors'].append({'bufferView': len(js['bufferViews']) - 1, 'componentType': 5125, 'count': cnt, 'type': 'SCALAR'})
        q = dict(ps[0]); q['indices'] = len(js['accessors']) - 1
        newp.append(q)
    mesh['primitives'] = newp
newimg.update(extra)
side = js['extensions'].get('VRM', {})
humanoid = {h['bone']: js['nodes'][h['node']]['name'] for h in side.get('humanoid', {}).get('humanBones', [])}
springs = []
for g in side.get('secondaryAnimation', {}).get('boneGroups', []):
    springs.append({'stiffness': g.get('stiffiness'), 'gravity': g.get('gravityPower'), 'drag': g.get('dragForce'),
                    'radius': g.get('hitRadius'), 'bones': [js['nodes'][n]['name'] for n in g.get('bones', [])]})
# expressions (VRM blendShapeMaster): name -> [[mesh name, morph index, weight 0..1]]; Godot keeps the morph order
expressions = {}
for g in side.get('blendShapeMaster', {}).get('blendShapeGroups', []):
    binds = [[js['meshes'][bb['mesh']].get('name', ''), bb['index'], bb.get('weight', 100) / 100.0] for bb in g.get('binds', [])]
    if binds:
        expressions[(g.get('presetName') if g.get('presetName') not in (None, 'unknown') else g.get('name', '')).lower()] = binds
meta = side.get('meta', {})
js['extensions'].pop('VRM', None)
if not js['extensions']: js.pop('extensions')

# VRM 0.x faces -Z; glTF/Godot humanoid convention is +Z. Wrap the scene in a node rotated 180 deg about Y
# (the importer's rest fixer "apply_node_transforms" bakes it into the skeleton rest).
sc = js['scenes'][js.get('scene', 0)]
js['nodes'].append({'name': 'VRM0_FacingFix', 'rotation': [0, 1, 0, 0], 'children': sc['nodes']})
sc['nodes'] = [len(js['nodes']) - 1]
# rebuild binary buffer
out = bytearray()
for i, bv in enumerate(js['bufferViews']):
    data = newimg.get(i)
    if data is None:
        data = bn[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
    while len(out) % 4: out.append(0)
    bv['byteOffset'] = len(out); bv['byteLength'] = len(data); out += data
while len(out) % 4: out.append(0)
js['buffers'] = [{'byteLength': len(out)}]
jb = json.dumps(js, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
while len(jb) % 4: jb += b' '
glb = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(out)) + struct.pack('<II', len(jb), 0x4E4F534A) + jb + struct.pack('<II', len(out), 0x004E4942) + out
open(dst, 'wb').write(glb)
json.dump({'source': __import__('os').path.basename(src), 'meta': {k: meta.get(k) for k in ['title', 'author', 'licenseName', 'otherLicenseUrl', 'allowedUserName']},
           'humanoid': humanoid, 'springs': springs, 'expressions': expressions}, open(dst[:-4] + '.vrm.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(dst, len(glb) // 1024, 'KB', 'springs', len(springs))
