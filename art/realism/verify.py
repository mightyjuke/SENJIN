#!/usr/bin/env python3
"""Fail closed on missing textures, tangent frames, skins, clips or asset hashes.
SPDX-License-Identifier: MIT. Structural validation is not artistic/device acceptance.
"""
import argparse, hashlib, json, struct
from pathlib import Path

REQUIRED={'Idle','Run','Dodge','Jump','Land','Hit','Death','Surge','dash','jatk','jc'}|{f'{p}{i}' for p in ['n','c'] for i in range(1,7)}
def verify(root: Path) -> dict:
    folder=root/'godot/assets/realism';manifest=json.loads((folder/'manifest.json').read_text())
    assert len(manifest['assets'])==2
    checks=0;total=0
    for item in manifest['assets']:
        path=folder/item['file'];raw=path.read_bytes();magic,version,length=struct.unpack_from('<III',raw)
        assert magic==0x46546c67 and version==2 and length==len(raw);checks+=1
        d=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
        assert item['sha256']==hashlib.sha256(raw).hexdigest();checks+=1
        assert len(raw)==item['bytes'] and len(raw)<32*1024*1024;total+=len(raw);checks+=1
        assert all('uri' not in b for b in d['buffers']);checks+=1
        assert all('bufferView' in image and image.get('mimeType')=='image/png' for image in d['images']);checks+=1
        for material in d['materials']:
            assert 'baseColorTexture' in material['pbrMetallicRoughness'];checks+=1
            assert 'metallicRoughnessTexture' in material['pbrMetallicRoughness'];checks+=1
            assert 'normalTexture' in material and 'occlusionTexture' in material;checks+=1
        for mesh in d['meshes']:
            for primitive in mesh['primitives']:
                attributes=primitive['attributes']
                assert {'POSITION','NORMAL','TANGENT','TEXCOORD_0'}<=set(attributes), (path,attributes);checks+=1
                assert d['accessors'][attributes['TANGENT']]['type']=='VEC4';checks+=1
        tris=sum(d['accessors'][p['indices']]['count']//3 for m in d['meshes'] for p in m['primitives'])
        assert tris==item['triangles'];checks+=1
        if path.stem=='vanguard':
            assert 15000<tris<90000;checks+=1
            assert len(d['meshes'])==2 and len(d['materials'])==2;checks+=1
            assert max(len(s['joints']) for s in d['skins'])==18;checks+=1
            assert {a['name'] for a in d['animations']}==REQUIRED;checks+=1
            assert {'TrailBase','TrailTip'}<={n.get('name','') for n in d['nodes']};checks+=1
            assert all({'JOINTS_0','WEIGHTS_0'}<=set(p['attributes']) for m in d['meshes'] for p in m['primitives']);checks+=1
        else:
            assert 8000<tris<26000 and not d.get('skins');checks+=1
    assert total<48*1024*1024;checks+=1
    assert (folder/'textures/battlefield_sky.exr').stat().st_size>10000;checks+=1
    assert (root/'art/realism/source/polearm_master.blend').is_file();checks+=1
    print('SENJIN_REALISM_CONTRACT_PASS',json.dumps({'checks':checks,'glb_bytes':total,'assets':manifest['assets']}))
    return manifest

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path.cwd());verify(p.parse_args().root.resolve())
