#!/usr/bin/env python3
"""SENJIN Iron Oath: original helmeted PBR vanguard and engraved polearm.
SPDX-License-Identifier: MIT
Blender is the authoring dependency, not a runtime dependency. Existing combat data
and the proven 18-bone animation contract remain unchanged. All dimensions metres.
"""
from __future__ import annotations
import argparse, hashlib, importlib.util, json, math, sys
from pathlib import Path
import bpy, bmesh
from mathutils import Vector, Matrix

P=argparse.ArgumentParser(); P.add_argument('--root',type=Path,default=Path.cwd()); P.add_argument('--render',action='store_true'); P.add_argument('--bake',action='store_true'); P.add_argument('--sky-only',action='store_true')
ARGS=P.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
ROOT=ARGS.root.resolve(); OUT=ROOT/'godot/assets/realism'; SRC=ROOT/'art/realism/source'; PRE=ROOT/'art/realism/previews'
for folder in (OUT,SRC,PRE): folder.mkdir(parents=True,exist_ok=True)
# Import geometry-independent rig authoring. Do not regenerate the earlier asset kit.
old_argv=sys.argv[:]; sys.argv=['build_assets.py','--','--root',str(ROOT)]
spec=importlib.util.spec_from_file_location('ember_rig',ROOT/'art/tools/build_assets.py'); base=importlib.util.module_from_spec(spec); spec.loader.exec_module(base); sys.argv=old_argv
TAU=math.tau

def uv_tile(uv,tile):
    col=tile%2; row=tile//2
    return ((col+.016+uv[0]*.968)/2,(row+.016+uv[1]*.968)/2)

class MeshBuilder:
    def __init__(self): self.v=[];self.f=[];self.uv=[];self.bones=[];self.smooth=[]
    def add(self,verts,faces,tile=0,bone='root',uv=None,smooth=True):
        start=len(self.v); self.v.extend(tuple(v) for v in verts); self.bones.extend([bone]*len(verts))
        if uv is None: uv=[((p[0]*2)%1,(p[2]*2)%1) for p in verts]
        self.uv.extend(uv_tile(p,tile) for p in uv)
        for f in faces:self.f.append(tuple(start+i for i in f));self.smooth.append(smooth)
    def tube(self,a,b,r,rt=None,tile=0,bone='root',n=16,rings=2,fold=0):
        a,b=Vector(a),Vector(b); rt=r if rt is None else rt; q=(b-a).to_track_quat('Z','Y').to_matrix()
        vs=[];uv=[]
        for j in range(rings+1):
            t=j/rings;radius=(r+(rt-r)*t)*(1+fold*math.sin(t*TAU*3))
            for i in range(n+1):
                ph=TAU*i/n;rr=radius*(1+fold*.4*math.sin(ph*6+t*12))
                vs.append(a.lerp(b,t)+q@Vector((rr*math.cos(ph),rr*math.sin(ph),0)));uv.append((i/n,t))
        fs=[]
        for j in range(rings):
            for i in range(n):k=j*(n+1)+i;fs.append((k,k+1,k+n+2,k+n+1))
        self.add(vs,fs,tile,bone,uv)
        self.add([vs[i] for i in range(n)],[tuple(reversed(range(n)))],tile,bone,[(.5+.48*math.cos(TAU*i/n),.5+.48*math.sin(TAU*i/n)) for i in range(n)],False)
        self.add(vs[-n-1:-1],[tuple(range(n))],tile,bone,[(.5+.48*math.cos(TAU*i/n),.5+.48*math.sin(TAU*i/n)) for i in range(n)],False)
    def ellipsoid(self,center,radius,tile=0,bone='root',n=24,rings=12,lo=-math.pi/2,hi=math.pi/2):
        vs=[];uv=[]
        for j in range(rings+1):
            a=lo+(hi-lo)*j/rings
            for i in range(n+1):
                ph=TAU*i/n
                vs.append(Vector(center)+Vector((radius[0]*math.cos(a)*math.cos(ph),radius[1]*math.cos(a)*math.sin(ph),radius[2]*math.sin(a))))
                uv.append((i/n,j/rings))
        fs=[]
        for j in range(rings):
            for i in range(n):k=j*(n+1)+i;fs.append((k,k+1,k+n+2,k+n+1))
        self.add(vs,fs,tile,bone,uv)
    def box(self,center,size,tile=0,bone='root',bevel=.002):
        bm=bmesh.new();bmesh.ops.create_cube(bm,size=1)
        for v in bm.verts:v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))
        if bevel:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=min(bevel,min(size)*.24),segments=3,affect='EDGES')
        bm.verts.ensure_lookup_table();bm.verts.index_update()
        # Separate each planar polygon so hard edges do not acquire pillow normals.
        for face in bm.faces:
            points=[v.co+Vector(center) for v in face.verts]; normal=face.normal; axis=max(range(3),key=lambda i:abs(normal[i]));axes=[i for i in range(3) if i!=axis]
            uvs=[(.5+v.co[axes[0]]/size[axes[0]],.5+v.co[axes[1]]/size[axes[1]]) for v in face.verts]
            self.add(points,[tuple(range(len(points)))],tile,bone,uvs,False)
        bm.free()
    def wire(self,points,r=.002,tile=1,bone='root',n=6):
        vs=[];uv=[];points=[Vector(p) for p in points]
        for j,p in enumerate(points):
            d=points[min(j+1,len(points)-1)]-points[max(0,j-1)];q=d.to_track_quat('Z','Y').to_matrix()
            for k in range(n+1):
                t=TAU*k/n;vs.append(p+q@Vector((r*math.cos(t),r*math.sin(t),0)));uv.append((k/n,j/max(1,len(points)-1)))
        fs=[]
        for j in range(len(points)-1):
            for k in range(n):i=j*(n+1)+k;fs.append((i,i+1,i+n+2,i+n+1))
        self.add(vs,fs,tile,bone,uv)
    def plate(self,rx,ry,z,h,a0,a1,tile=0,bone='spine',center=(0,0,0),nu=6,nv=3,bulge=.004):
        # Curved lamella: rolled corners, shallow crown and real back/thickness.
        vs=[];uv=[]
        for back in [0,1]:
            for j in range(nv+1):
                v=j/nv
                for i in range(nu+1):
                    u=i/nu;a=a0+(a1-a0)*u
                    chamfer=.002*(1-math.sin(math.pi*u))*(abs(v-.5)*2)**4
                    rr=bulge*math.sin(math.pi*u)*math.sin(math.pi*v)-back*.005-chamfer
                    vs.append((center[0]+(rx+rr)*math.sin(a),center[1]-(ry+rr)*math.cos(a),center[2]+z+h*v-.005*math.sin(math.pi*u)))
                    uv.append((u,v))
        stride=nu+1;layer=(nu+1)*(nv+1);fs=[]
        for j in range(nv):
            for i in range(nu):
                k=j*stride+i;fs.append((k,k+1,k+stride+1,k+stride));fs.append((k+layer+stride,k+layer+stride+1,k+layer+1,k+layer))
        for i in range(nu):
            fs.extend([(i+1,i,i+layer,i+layer+1),(nv*stride+i,nv*stride+i+1,nv*stride+i+1+layer,nv*stride+i+layer)])
        for j in range(nv):
            a=j*stride;b=(j+1)*stride;fs.extend([(a,b,b+layer,a+layer),(b+nu,a+nu,a+nu+layer,b+nu+layer)])
        self.add(vs,fs,tile,bone,uv)
    def make(self,name,material,arm=None):
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(self.v,[],self.f);mesh.update()
        uv=mesh.uv_layers.new(name='UVMap')
        for p,smooth in zip(mesh.polygons,self.smooth):
            p.use_smooth=smooth
            for li in p.loop_indices:uv.data[li].uv=self.uv[mesh.loops[li].vertex_index]
        # Explicit normal recalculation fixes orientation of back-facing shell patches.
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        for edge in bm.edges:
            if edge.is_manifold and edge.calc_face_angle(0.0)>math.radians(38): edge.smooth=False
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bm.to_mesh(mesh);bm.free()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(material)
        if arm:
            for bone in sorted(set(self.bones)):
                group=obj.vertex_groups.new(name=bone);group.add([i for i,b in enumerate(self.bones) if b==bone],1.0,'REPLACE')
            obj.parent=arm;mod=obj.modifiers.new('Skin','ARMATURE');mod.object=arm
        return obj

def texture(path,linear=False):
    image=bpy.data.images.load(str(path),check_existing=True)
    if linear:image.colorspace_settings.name='Non-Color'
    image.pack();return image

def pbr(family,normal_file=None):
    mat=bpy.data.materials.new('IronOath_'+family);mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links;bs=n.get('Principled BSDF')
    root=OUT/'textures'
    for kind,socket in [('albedo','Base Color')]:
        tex=n.new('ShaderNodeTexImage');tex.image=texture(root/f'{family}_{kind}.png');tex.label='sRGB base colour';l.new(tex.outputs['Color'],bs.inputs[socket])
    orm=n.new('ShaderNodeTexImage');orm.image=texture(root/f'{family}_orm.png',True);orm.label='R=AO G=roughness B=metal'
    separate=n.new('ShaderNodeSeparateColor');l.new(orm.outputs['Color'],separate.inputs['Color']);l.new(separate.outputs['Green'],bs.inputs['Roughness']);l.new(separate.outputs['Blue'],bs.inputs['Metallic'])
    nt=n.new('ShaderNodeTexImage');nt.image=texture(root/(normal_file or f'{family}_normal.png'),True)
    normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.65 if family=='hero' else 1.0;l.new(nt.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],bs.inputs['Normal'])
    group=bpy.data.node_groups.get('glTF Material Output')
    if group is None:
        group=bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree');group.interface.new_socket(name='Occlusion',in_out='INPUT',socket_type='NodeSocketFloat')
    ao=n.new('ShaderNodeGroup');ao.node_tree=group;l.new(separate.outputs['Red'],ao.inputs['Occlusion'])
    return mat

def ring(g,center,rx,ry,r=.002,tile=1,bone='spine',n=32):
    g.wire([(center[0]+rx*math.sin(TAU*i/n),center[1]-ry*math.cos(TAU*i/n),center[2]) for i in range(n+1)],r,tile,bone)

def rivet(g,point,direction=(0,-1,0),bone='spine',r=.0035,tile=1):
    p=Vector(point);d=Vector(direction).normalized();g.tube(p-d*.001,p+d*.0025,r,r*.7,tile,bone,n=8)

def cloth_panel(g,center,width,height,bone='hips',back=False):
    nu,nv=16,18;vs=[];uv=[]
    for j in range(nv+1):
        v=j/nv
        for i in range(nu+1):
            u=i/nu;x=center[0]+(u-.5)*width*(1+.15*v)
            folds=.017*math.sin(u*math.pi*8+v*.7)*(v+.3)+.008*math.sin(u*24-v*8)
            y=center[1]+(-1 if not back else 1)*(.02*v+folds)
            z=center[2]-height*v-.012*math.cos(u*15)*v*v
            vs.append((x,y,z));uv.append((u,v))
    fs=[]
    for j in range(nv):
        for i in range(nu):k=j*(nu+1)+i;fs.append((k,k+1,k+nu+2,k+nu+1))
    g.add(vs,fs,2,bone,uv)
    # Fine double stitching and bound hem, rather than disconnected rectangular trim.
    for i in (0,nu):g.wire([vs[j*(nu+1)+i] for j in range(nv+1)],.0025,3,bone)
    g.wire(vs[-nu-1:],.0022,1,bone)

def hero_geometry():
    g=MeshBuilder();sp=base.bone_spec()
    g.ellipsoid((0,.016,1.026),(.206,.144,.15),3,'hips')
    g.ellipsoid((0,.018,1.286),(.244,.159,.205),3,'spine',32,14)
    g.ellipsoid((0,0,1.145),(.18,.13,.14),2,'hips')
    # Anatomical chest shell, curved rather than a stack of flat boxes.
    g.plate(.250,.169,1.205,.274,-1.45,1.45,0,'spine',nu=20,nv=10,bulge=.018)
    g.plate(.235,.154,1.205,.274,1.52,4.76,0,'spine',nu=20,nv=10,bulge=.010)
    for z,rx,ry in [(1.219,.25,.173),(1.472,.251,.173)]:ring(g,(0,0,z),rx,ry,.0035)
    # A subtle central forged ridge and parallel inlaid filaments.
    for sx in [-1,1]:
        g.wire([(sx*(.014+.024*math.sin(i/24*math.pi)),-.188-.004*math.sin(i/24*math.pi),1.245+i*.0086) for i in range(25)],.0018,1,'spine')
        for z in [1.253,1.447]:rivet(g,(sx*.184,-.125,z),bone='spine')
    # Articulated abdominal lames, individual curved plates and real fasteners.
    for row in range(4):
        z=1.06+row*.045;rx=.197+row*.011;ry=.14+row*.007
        for col in range(12):
            a0=-math.pi+(col+.07)*TAU/12;a1=-math.pi+(col+.93)*TAU/12
            g.plate(rx,ry,z,.052,a0,a1,0,'hips' if row<2 else 'spine',nu=3,nv=2)
            for a in [a0+.045,a1-.045]:
                rivet(g,((rx+.002)*math.sin(a),-(ry+.002)*math.cos(a),z+.037),(math.sin(a),-math.cos(a),0),'hips' if row<2 else 'spine',.0027)
    # Bound silk collar, waist wraps and articulated four-way skirt.
    g.tube((0,0,1.46),(0,0,1.545),.101,.09,2,'head',n=28,rings=10,fold=.055)
    for k in range(5):ring(g,(0,0,1.474+k*.013),.102,.102,.004,2,'head')
    for k in range(3):g.plate(.220,.157,.997+k*.021,.030,-math.pi,math.pi,2,'hips',nu=32,nv=2)
    g.box((.005,-.177,1.035),(.072,.026,.05),1,'hips',.005)
    g.box((.005,-.193,1.035),(.048,.008,.029),3,'hips',.003)
    for x in [-.146,.146]:cloth_panel(g,(x,-.207,.97),.202,.41,'thigh.R' if x<0 else 'thigh.L')
    cloth_panel(g,(0,.149,.985),.39,.41,'hips',True)
    for side in [-1,1]:
        for row in range(4):
            for col in range(3):
                a=side*(1.03+col*.39)
                g.plate(.232+row*.012,.162+row*.010,.908-row*.047,.057,a-.15,a+.15,0,'hips',nu=3,nv=2)
    # Short, pleated shoulder mantle; no hair-card or cloth-simulation requirement.
    cloth_panel(g,(0,.176,1.463),.375,.43,'scarf',True)
    for s in ['L','R']:
        sign=1 if s=='L' else -1
        for part,r,tile in [('arm',.078,2),('forearm',.062,3),('thigh',.104,3),('shin',.066,3)]:
            a,b,_=sp[part+'.'+s];g.tube(a,b,r,r*.80,tile,part+'.'+s,n=20,rings=12,fold=.04 if tile==2 else .018)
        g.ellipsoid((sign*.290,.008,1.428),(.127,.151,.083),0,'arm.'+s,24,10)
        ring(g,(sign*.29,0,1.432),.126,.15,.0034,1,'arm.'+s)
        for row in range(3):
            # Curved sode on a separate rigid shoulder bone with overlapping lower edge.
            g.plate(.114+row*.012,.151,1.334-row*.041,.05,-1.18,1.18,0,'arm.'+s,(sign*.326,.016,0),nu=8,nv=2)
        a,b,_=sp['forearm.'+s];a=Vector(a);b=Vector(b)
        g.tube(a.lerp(b,.10),a.lerp(b,.82),.073,.063,0,'forearm.'+s,n=24,rings=5)
        for t in [.14,.78]:
            p=a.lerp(b,t);g.tube(p,p+(b-a).normalized()*.009,.076-t*.012,tile=1,bone='forearm.'+s,n=20)
        a,b,_=sp['shin.'+s];a=Vector(a);b=Vector(b)
        g.tube(a.lerp(b,.08),a.lerp(b,.90),.087,.061,0,'shin.'+s,n=24,rings=8)
        for i in [-1,0,1]:
            g.wire([(sign*.155+i*.017,-.090+.026*j/8,.48-j*.039) for j in range(9)],.0024,1,'shin.'+s)
        g.ellipsoid((sign*.155,-.052,.53),(.082,.062,.077),0,'shin.'+s,20,8)
        rivet(g,(sign*.155,-.116,.543),bone='shin.'+s,r=.0037)
        g.ellipsoid((sign*.16,-.075,.077),(.083,.167,.075),3,'foot.'+s,24,10)
        g.ellipsoid((sign*.16,-.172,.088),(.076,.086,.055),0,'foot.'+s,24,8)
        ring(g,(sign*.16,-.075,.036),.081,.159,.003,3,'foot.'+s)
        # Palm and four curled glove fingers, visible in close-ups and bound to the hand.
        wrist=Vector(sp['hand.'+s][0]);g.ellipsoid(wrist+Vector((0,-.008,-.047)),(.045,.035,.060),3,'hand.'+s,16,8)
        for f in range(4):
            x=wrist.x+(f-1.5)*.019
            g.wire([(x,wrist.y-.025,wrist.z-.045),(x,wrist.y-.042,wrist.z-.068),(x,wrist.y-.039,wrist.z-.093),(x,wrist.y-.012,wrist.z-.096)],.009,3,'hand.'+s,n=8)
            g.ellipsoid((x,wrist.y+.019,wrist.z-.049),(.010,.009,.015),0,'hand.'+s,8,4)
        g.wire([wrist+Vector((sign*.034,0,-.012)),wrist+Vector((sign*.060,-.02,-.04)),wrist+Vector((sign*.042,-.044,-.056))],.012,3,'hand.'+s,n=8)
    # Helmet: smooth hemispherical shell, raised crown ribs, visor and forged face guard.
    g.ellipsoid((0,.012,1.684),(.102,.108,.141),3,'head',32,16)
    g.ellipsoid((0,.017,1.728),(.146,.145,.125),0,'head',36,16,lo=-.06,hi=math.pi/2)
    ring(g,(0,.017,1.732),.149,.148,.004,1,'head',48)
    for a in [-1.7,-.82,0,.82,1.7,math.pi]:
        points=[]
        for i in range(19):
            t=.05+i/18*1.43;points.append((.148*math.sin(t)*math.sin(a),.017-.147*math.sin(t)*math.cos(a),1.728+.126*math.cos(t)))
        g.wire(points,.0028,1,'head')
    for j in range(4):
        g.plate(.139+j*.006,.139+j*.011,1.705-j*.034,.041,.78,TAU-.78,0,'head',nu=24,nv=2)
    # Visor has an open eye slot rather than a painted-on cartoon face.
    g.plate(.115,.125,1.546,.112,-1.0,1.0,0,'head',nu=18,nv=6,bulge=.013)
    for a in [-1,1]:
        g.wire([(a*(.084-.003*i),-.113-.003*i,1.561+i*.011) for i in range(8)],.0022,1,'head')
    g.wire([(-.107,-.118,1.692),(-.055,-.146,1.700),(0,-.153,1.694),(.055,-.146,1.700),(.107,-.118,1.692)],.008,0,'head',n=10)
    # Nose ridge, three recessed ventilation cuts and tiny bronze fixings.
    g.box((0,-.136,1.636),(.025,.027,.065),0,'head',.006)
    for x in [-.047,0,.047]:g.box((x,-.134,1.583),(.018,.012,.0045),3,'head',.001)
    for x in [-.083,.083]:rivet(g,(x,-.111,1.640),bone='head',r=.0038)
    # Low, original crest; no copied historical-fantasy character emblem.
    g.wire([(-.026,-.075,1.815),(-.020,-.074,1.859),(0,-.056,1.888),(.020,-.074,1.859),(.026,-.075,1.815)],.007,1,'head',n=8)
    return g

def weapon_geometry(high_detail=False):
    g=MeshBuilder();b='weapon'
    g.tube((0,0,-.71),(0,0,1.40),.023,.020,3,b,n=28,rings=12)
    # Ferrules with turned grooves, not simple colored bands.
    for z in [-.69,.53,1.04,1.23,1.32]:
        g.tube((0,0,z),(0,0,z+.063),.033,.031,1,b,n=28,rings=3)
        for d in [0,.014,.047,.059]:ring(g,(0,0,z+d),.034,.034,.0018,0,b,28)
    g.tube((0,0,-.815),(0,0,-.69),.002,.031,0,b,n=24,rings=4)
    # Continuous leather wrapping with visible edge seam, plus fine brass binding wire.
    turns=19;points=[]
    for i in range(turns*20+1):
        a=TAU*i/20;z=-.40+i/(turns*20)*.81;points.append((.027*math.cos(a),.027*math.sin(a),z))
    g.wire(points,.0068,2,b,n=6)
    g.wire([(p[0]*1.02,p[1]*1.02,p[2]+.008) for p in points],.00115,1,b,n=4)
    # Sculpted socket/quillons. Deliberately abstract rather than creature-shaped.
    g.tube((0,0,1.27),(0,0,1.47),.042,.048,1,b,n=32,rings=6)
    for side in [-1,1]:
        points=[(side*(.028+.142*t),0,1.36-.08*math.sin(t*math.pi)+.032*t) for t in [i/18 for i in range(19)]]
        g.wire(points,.010,1,b,n=10)
        for i in range(5):
            a=TAU*i/5;rivet(g,(.043*math.sin(a),.043*math.cos(a),1.34),(.1*math.sin(a),.1*math.cos(a),0),b,.004,0)
    # Eight-point blade cross-section: spine, shoulder bevel, cutting edge, reversed back.
    vs=[];uv=[];rows=38
    for j in range(rows+1):
        t=j/rows;z=1.40+t*.82
        width=max(.002,(.070+.088*math.sin(math.pi*t))*(1-t**5))
        center=.006+.064*math.sin(math.pi*t*.82);thick=.013*(1-.65*t)
        section=[(-width,0),(-width*.88,-thick*.53),(0,-thick),(width*.72,-thick*.5),(width,0),(width*.72,thick*.5),(0,thick),(-width*.88,thick*.53)]
        for k,(x,y) in enumerate(section):
            vs.append((center+x,y,z));uv.append(((x/width+1)*.5 if k<=4 else 1-(x/width+1)*.5,t))
    faces=[]
    for j in range(rows):
        for k in range(8):faces.append((j*8+k,j*8+(k+1)%8,(j+1)*8+(k+1)%8,(j+1)*8+k))
    g.add(vs,faces,0,b,uv,True)
    # Inlaid borders follow the blade's actual taper. Etched fine detail lives in the maps.
    for side in [-1,1]:
        points=[]
        for i in range(31):
            t=.04+.83*i/30;width=(.070+.088*math.sin(math.pi*t))*(1-t**5);center=.006+.064*math.sin(math.pi*t*.82)
            points.append((center+side*width*.53,-.012*(1-.65*t),1.4+t*.82))
        g.wire(points,.0014,1,b,n=4)
    # Original fine brass scroll inlay follows both blade faces, with four paired
    # lance-leaf flourishes. This silhouette detail survives texture mip reduction.
    def blade_point(t,x_fraction,face):
        width=(.070+.088*math.sin(math.pi*t))*(1-t**5)
        center=.006+.064*math.sin(math.pi*t*.82);thick=.013*(1-.65*t)
        return (center+width*x_fraction,face*(thick*(1-abs(x_fraction)*.63)+.0007),1.40+t*.82)
    for face in [-1,1]:
        g.wire([blade_point(.12+.65*i/48,.075*math.sin(i/48*TAU*1.5),face) for i in range(49)],.0009,1,b,n=4)
        for j in range(4):
            t0=.15+j*.14
            for side in [-1,1]:
                g.wire([blade_point(t0+.095*i/20,side*.32*math.sin(math.pi*i/20),face) for i in range(21)],.0008,1,b,n=4)
    # Socket chasing: fine crossed helices between its machined end bands.
    for side in [-1,1]:
        g.wire([(.048*math.cos(side*TAU*i/60),.048*math.sin(side*TAU*i/60),1.34+.115*i/60) for i in range(61)],.0011,0,b,n=4)
    # Lacquered binding and hanging cord, with individual fiber silhouette only near guard.
    ring(g,(0,0,1.25),.043,.043,.0055,2,b)
    for k in range(14):
        a=TAU*k/14
        g.wire([(.032*math.cos(a),.032*math.sin(a),1.25),(.06+.017*math.cos(a),.015+.021*math.sin(a),1.14),(.075+.024*math.cos(a),.02+.025*math.sin(a),1.04)],.0024,2,b,n=4)
    return g

def export(name,objects,animated=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    options=dict(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,
        export_animations=animated,export_skins=animated,export_extras=True,export_texcoords=True,export_normals=True,export_tangents=True,
        export_materials='EXPORT',export_cameras=False,export_lights=False)
    if animated:options.update(export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_optimize_animation_size=True)
    bpy.ops.export_scene.gltf(**options)
    (OUT/(name+'.glb.import')).write_text('[remap]\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[deps]\nsource_file="res://assets/realism/'+name+'.glb"\n\n[params]\nmeshes/generate_lods=false\nskins/use_named_skins=true\nanimation/import=true\nanimation/fps=60\nanimation/import_rest_as_RESET=false\nimport_script/path="res://scripts/realism/import_pbr.gd"\n')
    raw=(OUT/(name+'.glb')).read_bytes();size=int.from_bytes(raw[12:16],'little');data=json.loads(raw[20:20+size])
    return {'file':name+'.glb','bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'triangles':sum(data['accessors'][p['indices']]['count']//3 for m in data['meshes'] for p in m['primitives']),'meshes':len(data['meshes']),'materials':len(data.get('materials',[])),'images':len(data.get('images',[])),'bones':max([len(s['joints']) for s in data.get('skins',[])],default=0),'animations':[a['name'] for a in data.get('animations',[])]}

def save_source(name):
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')),compress=True)

def bake_weapon(low):
    # Keep tile UVs on the displaced master; the game mesh receives a UNIQUE unwrap.
    # Baking into the repeated source atlas would corrupt normals at overlapping UVs.
    master=low.copy();master.data=low.data.copy();bpy.context.collection.objects.link(master);master.name='Polearm_HIGH_EngravedMaster'
    source=low.data.materials[0].copy();master.data.materials.clear();master.data.materials.append(source)
    nodes=source.node_tree.nodes;links=source.node_tree.links;bs=nodes.get('Principled BSDF');output=nodes.get('Material Output')
    for link in list(bs.inputs['Normal'].links):links.remove(link)
    subdiv=master.modifiers.new('High resolution engraving surface','SUBSURF');subdiv.subdivision_type='SIMPLE';subdiv.levels=3
    displacement=master.modifiers.new('Chisel cut and hammered microstructure','DISPLACE')
    ht=bpy.data.textures.new('Original weapon height','IMAGE');ht.image=texture(OUT/'textures/weapon_height.png',True)
    displacement.texture=ht;displacement.texture_coords='UV';displacement.uv_layer='UVMap';displacement.strength=.00055;displacement.mid_level=.5
    bpy.ops.object.select_all(action='DESELECT');low.select_set(True);bpy.context.view_layer.objects.active=low
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.012,area_weight=.5)
    bpy.ops.object.mode_set(mode='OBJECT')
    destination=bpy.data.materials.new('BakeDestination');destination.use_nodes=True;low.data.materials.clear();low.data.materials.append(destination)
    target=destination.node_tree.nodes.new('ShaderNodeTexImage');destination.node_tree.nodes.active=target
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.seed=1947
    scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.004;scene.render.bake.max_ray_distance=.010;scene.render.bake.margin=12
    bpy.ops.object.select_all(action='DESELECT');low.select_set(True);master.select_set(True);bpy.context.view_layer.objects.active=low
    for kind in ['normal','albedo','orm']:
        image=bpy.data.images.new('Weapon_Runtime_'+kind,width=2048,height=2048,alpha=False)
        image.colorspace_settings.name='sRGB' if kind=='albedo' else 'Non-Color'
        target.image=image
        if kind=='normal':
            bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT')
        else:
            emission=nodes.get('BakeEmission') or nodes.new('ShaderNodeEmission');emission.name='BakeEmission'
            source_image=next(node for node in nodes if node.type=='TEX_IMAGE' and node.image and node.image.filepath.endswith('weapon_'+kind+'.png'))
            links.new(source_image.outputs['Color'],emission.inputs['Color']);links.new(emission.outputs['Emission'],output.inputs['Surface'])
            bpy.ops.object.bake(type='EMIT')
        image.filepath_raw=str(OUT/'textures'/('weapon_runtime_'+kind+'.png'));image.file_format='PNG';image.save();image.pack()
    links.new(bs.outputs['BSDF'],output.inputs['Surface'])
    low.data.materials[0]=pbr('weapon_runtime')
    master.hide_render=True;master.hide_set(True)
    save_source('polearm_master')
    bpy.data.objects.remove(master,do_unlink=True)
    return 'weapon_runtime'

def light_stage(objects,weapon=False):
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True;scene.cycles.seed=1947
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
    scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.13,.18,.25,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.36
    target=Vector((0,0,1.2 if not weapon else 1.67))
    for name,pos,power,size,color in [('Key',(-2.6,-3.6,4.8),600,3,(1,.86,.73)),('SkyFill',(2.8,-1.8,3.4),380,3,(.63,.77,1)),('StripRim',(0,2.6,3.6),800,2,(1,.69,.43))]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
        ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(target-ob.location).to_track_quat('-Z','Y').to_euler()
    camera=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'));scene.collection.objects.link(camera);scene.camera=camera
    camera.location=(.66,-2.9,1.91) if weapon else (3.15,-5.6,2.68)
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=72 if weapon else 67
    scene.render.resolution_x=1400 if weapon else 1200;scene.render.resolution_y=1500;scene.render.resolution_percentage=100
    if weapon:camera.data.type='ORTHO';camera.data.ortho_scale=1.29
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025));floor=bpy.context.object
    mat=bpy.data.materials.new('ReviewGround');mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.022,.028,.036,1);mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.68;floor.data.materials.append(mat)
    return scene,camera

def make_sky():
    base.clear();scene=bpy.context.scene;scene.world.use_nodes=True;n=scene.world.node_tree.nodes;l=scene.world.node_tree.links
    tex=n.new('ShaderNodeTexSky');tex.sky_type='MULTIPLE_SCATTERING';tex.sun_elevation=math.radians(27);tex.sun_rotation=math.radians(145);tex.altitude=.12;tex.air_density=1;tex.aerosol_density=1.6;tex.ozone_density=1
    tex.sun_disc=False
    hue=n.new('ShaderNodeHueSaturation');hue.inputs['Saturation'].default_value=.3;l.new(tex.outputs['Color'],hue.inputs['Color'])
    coord=n.new('ShaderNodeTexCoord');cloud=n.new('ShaderNodeTexNoise');cloud.inputs['Scale'].default_value=3.1;cloud.inputs['Detail'].default_value=4;l.new(coord.outputs['Normal'],cloud.inputs['Vector'])
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.34;ramp.color_ramp.elements[1].position=.64;l.new(cloud.outputs['Fac'],ramp.inputs[0])
    mix=n.new('ShaderNodeMixRGB');mix.inputs[2].default_value=(3.6,3.7,3.9,1);l.new(ramp.outputs['Color'],mix.inputs[0]);l.new(hue.outputs['Color'],mix.inputs[1])
    l.new(mix.outputs['Color'],n['Background'].inputs['Color']);n['Background'].inputs['Strength'].default_value=.18
    # Lower-hemisphere diffuse ground bounce prevents black metal reflections.
    bpy.ops.mesh.primitive_plane_add(size=20000,location=(0,0,-2));floor=bpy.context.object
    m=bpy.data.materials.new('GroundBounce');m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.21,.19,.16,1);bs.inputs['Roughness'].default_value=.95;floor.data.materials.append(m)
    cam=bpy.data.objects.new('SkyBake',bpy.data.cameras.new('SkyBake'));scene.collection.objects.link(cam);cam.data.type='PANO';cam.data.panorama_type='EQUIRECTANGULAR';scene.camera=cam
    scene.render.engine='CYCLES';scene.cycles.samples=8;scene.render.resolution_x=1024;scene.render.resolution_y=512;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='OPEN_EXR';scene.render.image_settings.color_depth='16';scene.render.filepath=str(OUT/'textures/battlefield_sky.exr');bpy.ops.render.render(write_still=True)


def main():
    for name in ['hero_albedo.png','weapon_height.png']:
        assert (OUT/'textures'/name).exists(),'Run textures.py before Blender authoring'
    base.clear();weapon_mat=pbr('weapon');weapon=weapon_geometry().make('Polearm_LOD0',weapon_mat)
    baked=bool(ARGS.bake)
    if baked:bake_weapon(weapon)
    # Reuse the exact low mesh, baked material and unique UVs inside the hero export.
    game_weapon_mesh=weapon.data.copy();game_weapon_mesh.use_fake_user=True
    save_source('polearm');entries=[export('polearm',[weapon])]
    if ARGS.render:
        scene,_=light_stage([weapon],True);scene.render.filepath=str(PRE/'polearm-blender.png');bpy.ops.render.render(write_still=True)
    base.clear();arm=base.rig();body=hero_geometry().make('Vanguard_PBR',pbr('hero'),arm)
    weapon=bpy.data.objects.new('Polearm_PBR',game_weapon_mesh.copy());bpy.context.collection.objects.link(weapon)
    group=weapon.vertex_groups.new(name='weapon');group.add(list(range(len(weapon.data.vertices))),1.0,'REPLACE')
    weapon.parent=arm;modifier=weapon.modifiers.new('Skin','ARMATURE');modifier.object=arm
    base.animate(arm);sockets=base.sockets(arm);save_source('vanguard');entries.append(export('vanguard',[arm,body,weapon]+sockets,True))
    if ARGS.render:
        scene,_=light_stage([body,weapon]);scene.frame_set(0);scene.render.filepath=str(PRE/'vanguard-blender.png');bpy.ops.render.render(write_still=True)
    make_sky()
    manifest={'schema':1,'license':'MIT','source':'Original scripted Blender geometry and procedural texture fields','authoring':bpy.app.version_string,'units':'metres','up':'+Y','forward':'+Z','normal_bake':'selected-to-active, subdivided displaced source' if baked else 'analytical surface normal fields','assets':entries}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('SENJIN_REALISM_BUILD_PASS',json.dumps(entries),flush=True)

if __name__=='__main__':
    if ARGS.sky_only:make_sky()
    else:main()
