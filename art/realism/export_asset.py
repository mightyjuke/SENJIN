#!/usr/bin/env python3
"""Export hand-edited PBR sources without regenerating or discarding UV textures.
Use --asset polearm --sync-hero to also update its embedded copy in vanguard.blend.
SPDX-License-Identifier: MIT
"""
import argparse, importlib.util, json, sys
from pathlib import Path
import bpy

p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path.cwd());p.add_argument('--asset',choices=['vanguard','polearm'],required=True);p.add_argument('--sync-hero',action='store_true')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []);root=a.root.resolve()
old=sys.argv[:];sys.argv=['build_realism.py','--','--root',str(root)]
spec=importlib.util.spec_from_file_location('pbr_authoring',root/'art/realism/build_realism.py');author=importlib.util.module_from_spec(spec);spec.loader.exec_module(author);sys.argv=old
manifest_path=root/'godot/assets/realism/manifest.json';manifest=json.loads(manifest_path.read_text())

def export_open(name):
    objects=[o for o in bpy.context.scene.objects if o.type in {'MESH','ARMATURE'} or o.name in {'TrailBase','TrailTip'}]
    assert objects and not any('HIGH' in o.name for o in objects),'Export the game source, not the high-poly master'
    for o in objects:
        if o.type=='MESH':assert o.data.uv_layers.active is not None,'PBR UVs are required'
    entry=author.export(name,objects,name=='vanguard')
    index=next(i for i,item in enumerate(manifest['assets']) if item['file']==name+'.glb')
    manifest['assets'][index]=entry
    return entry

source=root/'art/realism/source'/f'{a.asset}.blend';assert source.is_file()
bpy.ops.wm.open_mainfile(filepath=str(source));entries=[export_open(a.asset)]
if a.asset=='polearm' and a.sync_hero:
    hero_source=root/'art/realism/source/vanguard.blend'
    bpy.ops.wm.open_mainfile(filepath=str(hero_source))
    with bpy.data.libraries.load(str(source),link=False) as (src,dst):
        names=[name for name in src.objects if name=='Polearm_LOD0']
        assert len(names)==1,'Preserve the Polearm_LOD0 object name in the weapon source'
        dst.objects=names
    imported=dst.objects[0];hero_weapon=bpy.data.objects.get('Polearm_PBR')
    assert imported is not None and hero_weapon is not None
    hero_weapon.data=imported.data
    hero_weapon.vertex_groups.clear();group=hero_weapon.vertex_groups.new(name='weapon');group.add(list(range(len(hero_weapon.data.vertices))),1.0,'REPLACE')
    bpy.data.objects.remove(imported,do_unlink=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(hero_source),compress=True)
    entries.append(export_open('vanguard'))
manifest['last_export']='hand-edited packed source; rebake maps after UV/topology changes'
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
print('SENJIN_PBR_EXPORT_PASS',json.dumps(entries))
