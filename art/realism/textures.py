#!/usr/bin/env python3
"""Original deterministic PBR surfaces for SENJIN. No downloaded texture assets.
SPDX-License-Identifier: MIT
PNG albedo is sRGB; ORM (R=AO,G=roughness,B=metallic), normals and height are linear.
The height field is also used to displace the Blender weapon master before baking.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw


def noise(n: int, cells: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    a = (rng.random((cells, cells)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(a).resize((n, n), Image.Resampling.BICUBIC), dtype=np.float32) / 255.0


def tile(kind: str, n: int, seed: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) / n
    fine = noise(n, max(8, n // 2), seed)
    broad = noise(n, 12, seed + 1)
    mid = noise(n, 80, seed + 2)
    edge = np.minimum.reduce([x, y, 1-x, 1-y])
    wear = np.exp(-edge * 105) * (.25 + .75 * broad)
    scratch_image = Image.new('L', (n,n), 0)
    pen = ImageDraw.Draw(scratch_image)
    rng = np.random.default_rng(seed + 3)
    for _ in range(44):
        cx, cy = rng.uniform(.06, .94, 2) * n
        length = float(rng.uniform(.008,.07)) * n
        pen.line((cx,cy,cx+length*.18,cy+length), fill=int(rng.integers(70,190)), width=1)
    scratches = np.asarray(scratch_image,dtype=np.float32)/255
    if kind in ('steel', 'blade', 'brass'):
        color = np.array({'steel': [83, 91, 100], 'blade': [168, 177, 182], 'brass': [163, 128, 73]}[kind], np.float32)
        base = np.broadcast_to(color, (n, n, 3)).copy()
        base *= (.84 + .18*broad + .065*mid)[...,None]
        base += (wear*14 + scratches*3)[...,None]
        rough = {'steel':.33,'blade':.20,'brass':.33}[kind] + .14*(broad-.5) + .035*(fine-.5) - .07*wear + .05*scratches
        height = .5 + .024*(mid-.5) + .004*(fine-.5) - .045*scratches
        metallic = np.full_like(x, .96)
        # Original flowing guilloche: nested waves with a narrow chisel-cut border.
        if kind in ('blade','brass'):
            wave = .48 + .25*np.sin(y*5*np.pi) * np.sin(np.pi*y)
            distance = np.abs(x-wave)
            ornament = np.exp(-((distance-.04)*n/1.9)**2) + .7*np.exp(-((distance-.065)*n/1.4)**2)
            ornament *= (y>.055) & (y<.945)
            for sign in [-1,1]:
                stem = .50 + sign*.27*np.sin(y*9*np.pi)**2
                ornament += .6*np.exp(-((x-stem)*n/1.8)**2)*((y>.12)&(y<.9))
            border = np.exp(-((x-.10)*n/1.7)**2)+np.exp(-((x-.90)*n/1.7)**2)
            etch = np.minimum(1, ornament + border)
            height -= etch*.24
            base -= etch[...,None]*np.array([19,20,22])
            rough += etch*.14
        if kind == 'steel':
            # Subtle hammered steel grain. Specular breakup is primarily roughness.
            height += .007*np.sin(x*660)*np.sin(y*620)
        ao = .96 - .06*scratches
    elif kind == 'cloth':
        weave = np.sin(x*2*np.pi*94)*np.sin(y*2*np.pi*94)
        twill = np.sin((x+y)*2*np.pi*63)
        base = np.broadcast_to(np.array([75,28,29],np.float32),(n,n,3)).copy()
        base *= (.82 + .21*broad + .045*weave + .02*twill)[...,None]
        rough = .76 + .07*mid + .025*weave
        height = .5 + .055*weave + .026*twill
        metallic = np.zeros_like(x); ao = .96 + .025*weave
    elif kind == 'leather':
        pores = np.maximum(0,(fine-.60))
        creases = np.exp(-(np.sin((x*2+y*.6+mid*.1)*36)*16)**2)
        base = np.broadcast_to(np.array([49,31,24],np.float32),(n,n,3)).copy()
        base *= (.74 + .38*broad + .05*mid)[...,None]
        base += (wear*9)[...,None]
        rough = .55 + .12*mid + .07*creases
        height = .5 + .085*(fine-.5) - .075*creases - .1*pores
        metallic = np.zeros_like(x); ao = .96 - .1*creases
    elif kind == 'wood':
        grain = np.sin(x*170 + mid*1.3 + np.sin(y*4)*1.8)
        base = np.broadcast_to(np.array([47,35,27],np.float32),(n,n,3)).copy()
        base *= (.82 + .15*broad + .14*grain)[...,None]
        rough = .42 + .13*mid
        height = .5 + .045*grain + .009*fine
        metallic=np.zeros_like(x); ao=np.full_like(x,.98)
    elif kind == 'ground':
        grit = fine*.6+mid*.4
        fissures = np.exp(-(np.sin((x*3+y+mid*.09)*18)*22)**2)*np.exp(-(np.sin((y*3-x+mid*.06)*13)*9)**2)
        base = np.broadcast_to(np.array([112,108,95],np.float32),(n,n,3)).copy()
        base *= (.68 + .35*broad + .08*mid)[...,None]
        base -= fissures[...,None]*18
        rough=.88+.09*grit
        height=.50+.14*mid+.045*fine-.12*fissures
        metallic=np.zeros_like(x);ao=.94-.14*fissures
    else:
        raise ValueError(kind)
    orm=np.dstack([ao,np.clip(rough,.06,.98),metallic])
    return np.clip(base/255,0,1),np.clip(orm,0,1),np.clip(height,0,1)


def normal(height: np.ndarray, strength: float) -> np.ndarray:
    # Arrays run bottom-to-top in UV space; reverse only when writing PNG.
    dy,dx=np.gradient(height)
    v=np.dstack([-dx*strength,-dy*strength,np.ones_like(dx)])
    v/=np.linalg.norm(v,axis=-1,keepdims=True)
    return v*.5+.5


def save(path: Path, data: np.ndarray) -> None:
    Image.fromarray(np.flipud(np.rint(np.clip(data,0,1)*255).astype(np.uint8))).save(path,compress_level=6)


def make(root: Path) -> None:
    out=root/'godot/assets/realism/textures';out.mkdir(parents=True,exist_ok=True)
    for family,kinds in [('hero',['steel','brass','cloth','leather']),('weapon',['blade','brass','leather','wood'])]:
        n=1024
        albedo=np.zeros((n*2,n*2,3),np.float32);orm=albedo.copy(); normals=albedo.copy(); heights=np.zeros((n*2,n*2),np.float32)
        for i,kind in enumerate(kinds):
            a,o,h=tile(kind,n,202609+i*271+(1000 if family=='weapon' else 0))
            r,c=divmod(i,2);s=np.s_[r*n:(r+1)*n,c*n:(c+1)*n]
            albedo[s]=a;orm[s]=o;heights[s]=h;normals[s]=normal(h,5.0 if kind in ('cloth','leather') else 3.5)
        save(out/f'{family}_albedo.png',albedo);save(out/f'{family}_orm.png',orm)
        save(out/f'{family}_normal.png',normals);save(out/f'{family}_height.png',heights)
    a,o,h=tile('ground',1024,21723)
    save(out/'ground_albedo.png',a);save(out/'ground_orm.png',o);save(out/'ground_normal.png',normal(h,5.0))
    entries=[{'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(out.glob('*.png')) if p.name in {f'{f}_{k}.png' for f in ['hero','weapon'] for k in ['albedo','orm','normal','height']}|{f'ground_{k}.png' for k in ['albedo','orm','normal']}]
    (out/'manifest.json').write_text(json.dumps({'schema':1,'license':'MIT','origin':'original procedural fields; not downloaded','maps':entries},indent=2)+'\n')
    print('SENJIN_REALISM_TEXTURES_PASS',len(entries))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=Path.cwd())
    make(parser.parse_args().root.resolve())
