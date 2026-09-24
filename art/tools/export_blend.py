#!/usr/bin/env python3
"""Export a manually edited source without running the procedural kit builder.
blender -b --python art/tools/export_blend.py -- --root . --asset vanguard
Then: python3 art/tools/verify_exports.py --refresh-manifest
SPDX-License-Identifier: MIT
"""
import argparse
from pathlib import Path
import sys
import bpy
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--root',type=Path,default=Path.cwd())
p.add_argument('--asset',required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert a.asset.isidentifier(), 'Use an asset basename, not a path'
root=a.root.resolve()
source=root/'art/blender'/(a.asset+'.blend')
out=root/'godot/assets/models'/(a.asset+'.glb')
assert source.is_file(), source
bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.ops.object.select_all(action='DESELECT')
objects=[o for o in bpy.context.scene.objects if o.type in {'MESH','ARMATURE','EMPTY'}]
assert objects, 'No model objects in source'
for ob in objects: ob.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
animated=any(ob.type=='ARMATURE' for ob in objects)
options=dict(filepath=str(out),export_format='GLB',use_selection=True,export_yup=True,
    export_apply=False,export_animations=animated,export_skins=animated,export_extras=True,
    export_texcoords=False,export_normals=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
if animated:
    options.update(export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_optimize_animation_size=True)
bpy.ops.export_scene.gltf(**options)
print('SENJIN_MANUAL_EXPORT_PASS',out)
