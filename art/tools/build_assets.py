#!/usr/bin/env python3
"""SENJIN Ember kit. Original geometry and animation authored for this project.
SPDX-License-Identifier: MIT
Run: blender -b --python art/tools/build_assets.py -- --root . [--render]
Blender Z-up/-Y forward; exported glTF Y-up/+Z forward, metres, no root motion.
"""
import argparse, json, math, sys, hashlib, random
from pathlib import Path
import bpy, bmesh
from mathutils import Vector, Matrix, Quaternion

P = argparse.ArgumentParser()
P.add_argument('--root', type=Path, default=Path.cwd())
P.add_argument('--render', action='store_true')
ARGS=P.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
ROOT=ARGS.root.resolve(); OUT=ROOT/'godot/assets/models'; SRC=ROOT/'art/blender'; PRE=ROOT/'art/previews'
for p in (OUT,SRC,PRE): p.mkdir(parents=True,exist_ok=True)
R=random.Random(61783)
TAU=math.tau
PALETTE={'iron':'29343f','iron2':'425362','edge':'75909b','dark':'141e29','red':'a33138','red2':'dd6653','gold':'bd924b','gold2':'f2ce83','cloth':'d5c4a0','wood':'45352e','wood2':'79604a','skin':'cda085','black':'18222a','stone':'686e72','stone2':'90918b','roof':'334452','green':'536a61'}
def rgb(c):
    c=PALETTE.get(c,c)
    return tuple(int(c[i:i+2],16)/255 for i in (0,2,4))
def linear(c): return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in rgb(c))

def material(name,emission=False):
    m=bpy.data.materials.new(name); m.use_nodes=True
    nodes=m.node_tree.nodes; bs=nodes.get('Principled BSDF'); vc=nodes.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value=.64
    if emission:
        m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Emission Color']); bs.inputs['Emission Strength'].default_value=1.8
    return m
MAT=None
class Geo:
    def __init__(self): self.v=[]; self.f=[]; self.cols=[]; self.groups=[]
    def add(self,vs,fs,c='iron',bone='root',shade=1.0):
        off=len(self.v); self.v.extend(tuple(v) for v in vs); self.groups.extend([bone]*len(vs)); col=linear(c)
        for face in fs:
            self.f.append(tuple(off+i for i in face)); self.cols.append(tuple(min(1,x*shade) for x in col)+(1,))
    def box(self,center,size,c='iron',bone='root',rot=None,bevel=.0):
        # Small chamfers catch light without smooth-normal or normal-map dependencies.
        bm=bmesh.new(); bmesh.ops.create_cube(bm,size=1)
        for v in bm.verts: v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))
        if bevel>0:
            bmesh.ops.bevel(bm,geom=list(bm.edges),offset=min(bevel,min(size)*.24),segments=1,affect='EDGES')
        bm.verts.ensure_lookup_table(); bm.verts.index_update()
        q=Matrix.Identity(3) if rot is None else rot
        self.add([q@v.co+Vector(center) for v in bm.verts],[[v.index for v in f.verts] for f in bm.faces],c,bone)
        bm.free()
    def tube(self,a,b,r1,r2=None,c='iron',bone='root',n=8):
        a,b=Vector(a),Vector(b); r2=r1 if r2 is None else r2
        q=(b-a).to_track_quat('Z','Y').to_matrix(); vs=[]
        for p,r in ((a,r1),(b,r2)):
            for i in range(n): vs.append(p+q@Vector((r*math.cos(TAU*i/n),r*math.sin(TAU*i/n),0)))
        fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]
        fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        self.add(vs,fs,c,bone)
    def ellipsoid(self,center,size,c='iron',bone='root',n=10,rings=5):
        vs=[Vector(center)+Vector((0,0,-size[2]))]
        for j in range(1,rings):
            a=-math.pi/2+math.pi*j/rings
            for i in range(n):
                t=TAU*i/n; vs.append(Vector(center)+Vector((size[0]*math.cos(a)*math.cos(t),size[1]*math.cos(a)*math.sin(t),size[2]*math.sin(a))))
        vs.append(Vector(center)+Vector((0,0,size[2]))); fs=[]
        for i in range(n): fs.append((0,1+(i+1)%n,1+i))
        for j in range(rings-2):
            o=1+j*n
            for i in range(n): fs.append((o+i,o+(i+1)%n,o+(i+1)%n+n,o+i+n))
        top=len(vs)-1; o=1+(rings-2)*n
        for i in range(n): fs.append((o+i,o+(i+1)%n,top))
        self.add(vs,fs,c,bone)
    def panel(self,points,depth,c='iron',bone='root'):
        # Extruded outline in X/Z, useful for blades, sode and roof ends.
        vs=[(x,y+d,z) for d in (-depth/2,depth/2) for x,y,z in points]; n=len(points)
        fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        self.add(vs,fs,c,bone)
    def obj(self,name,arm=None):
        unique=[]; cols=[]; seen=set()
        for face,col in zip(self.f,self.cols):
            key=tuple(sorted(face))
            if key not in seen:
                seen.add(key); unique.append(face); cols.append(col)
        self.f,self.cols=unique,cols
        mesh=bpy.data.meshes.new(name); mesh.from_pydata(self.v,[],self.f); mesh.update()
        bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(mesh); bm.free()
        colors=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
        for p,col in zip(mesh.polygons,self.cols):
            for i in p.loop_indices: colors.data[i].color=col
        o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o); mesh.materials.append(MAT)
        if arm:
            for name in set(self.groups):
                g=o.vertex_groups.new(name=name); g.add([i for i,b in enumerate(self.groups) if b==name],1.0,'REPLACE')
            mod=o.modifiers.new('Deform','ARMATURE'); mod.object=arm; o.parent=arm
        return o

def clear():
    global MAT
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for ac in list(bpy.data.actions): bpy.data.actions.remove(ac)
    for mat in list(bpy.data.materials):
        if mat.users==0: bpy.data.materials.remove(mat)
    bpy.context.scene.camera=None
    MAT=material('SENJIN_Painted')
    bpy.context.scene.render.fps=60

def bone_spec():
    d={'root':((0,0,0),(0,0,.25),None), 'hips':((0,0,.98),(0,0,1.16),'root'),
       'spine':((0,0,1.16),(0,0,1.48),'hips'), 'head':((0,0,1.48),(0,0,1.79),'spine'),
       'weapon':((0,0,0),(0,0,.2),'root'), 'scarf':((0,.08,1.5),(.0,.27,1.31),'spine')}
    for s,x in [('L',1),('R',-1)]:
        d['arm.'+s]=((x*.29,0,1.43),(x*.43,-.025,1.16),'spine')
        d['forearm.'+s]=((x*.43,-.025,1.16),(x*.39,-.16,.91),'arm.'+s)
        d['hand.'+s]=((x*.39,-.16,.91),(x*.39,-.20,.80),'forearm.'+s)
        d['thigh.'+s]=((x*.145,0,.98),(x*.155,-.015,.54),'hips')
        d['shin.'+s]=((x*.155,-.015,.54),(x*.16,0,.105),'thigh.'+s)
        d['foot.'+s]=((x*.16,0,.105),(x*.16,-.22,.07),'shin.'+s)
    return d

def rig():
    ar=bpy.data.armatures.new('VanguardRig'); o=bpy.data.objects.new('VanguardRig',ar); bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o; o.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
    for n,(a,b,p) in bone_spec().items():
        bone=ar.edit_bones.new(n); bone.head=a; bone.tail=b
        if p: bone.parent=ar.edit_bones[p]
    bpy.ops.object.mode_set(mode='OBJECT'); o.show_in_front=True; return o

def polearm(g,mode='hero'):
    b='weapon'; g.tube((0,0,-.66),(0,0,1.38),.025,c='wood',bone=b)
    for i in range(16): g.tube((0,0,-.37+i*.048),(0,0,-.347+i*.048),.031,c='red' if i%3 else 'cloth',bone=b)
    for z in (-.68,.6,1.02,1.30): g.tube((0,0,z),(0,0,z+.052),.043,c='gold',bone=b)
    g.tube((0,0,-.77),(0,0,-.64),.006,.04,'edge',b)
    # Offset hooked blade with a contrasting cutting edge; no creature/franchise motifs.
    g.panel([(-.055,0,1.28),(.08,0,1.28),(.17,0,1.47),(.21,0,1.77),(.15,0,2.06),(.055,0,2.22),(.08,0,1.86),(-.045,0,1.52)],.032,'edge',b)
    g.panel([(.055,-.019,1.4),(.10,-.019,1.48),(.135,-.019,1.75),(.08,-.019,1.98),(.07,-.019,1.79),(.012,-.019,1.54)],.009,'cloth',b)
    g.box((0,0,1.28),(.20,.12,.055),'gold',b,bevel=.01)
    g.panel([(-.03,0,1.27),(-.09,0,1.05),(-.07,0,.88),(-.01,0,.99),(.025,0,1.27)],.023,'red2',b)

def character(detail=True,officer=False):
    g=Geo(); spec=bone_spec()
    g.ellipsoid((0,0,1.015),(.245,.165,.175),'dark','hips')
    g.ellipsoid((0,0,1.295),(.30,.18,.255),'iron','spine')
    g.ellipsoid((0,0,1.13),(.20,.145,.15),'red','hips')
    for j in range(6 if detail else 3):
        z=1.17+j*(.048 if detail else .09); w=.218+j*.008
        for side in [-1,1]:
            g.box((0,side*.163,z),(w*2,.045,.043 if detail else .075),'iron2','spine',bevel=.008)
            g.box((0,side*.19,z+.016),(w*2,.013,.011),'gold' if j in (0,5) else 'edge','spine')
            if detail:
                for x in [-.15,-.075,.075,.15]:
                    g.tube((x,side*.192,z-.011),(x,side*.194,z+.014),.008,c='red2',bone='spine',n=5)
    g.box((.03,-.205,1.315),(.047,.022,.325),'red','spine',Matrix.Rotation(-.52,3,'Y'),.01)
    g.box((.015,-.225,1.30),(.088,.028,.065),'gold','spine',bevel=.008)
    g.tube((0,0,1.47),(0,0,1.53),.112,c='red',bone='head',n=10)
    g.ellipsoid((0,0,1.655),(.119,.109,.165),'skin','head',12 if detail else 8,6 if detail else 4)
    # Faceted crown, low swept brim, neck plates and abstract sun emblem.
    g.ellipsoid((0,.009,1.745),(.158,.148,.108),'iron','head',12 if detail else 8,4)
    g.tube((0,.012,1.737),(0,.012,1.771),.19,.154,'iron2','head',12)
    g.box((0,-.145,1.75),(.23,.07,.03),'gold','head',bevel=.009)
    for j in range(3):
        g.box((0,.128+j*.014,1.70-j*.05),(.286+j*.015,.04,.043),'iron2','head',bevel=.009)
    g.panel([(-.032,-.13,1.74),(-.045,-.085,1.83),(0,-.07,1.9),(.045,-.085,1.83),(.032,-.13,1.74)],.024,'gold','head')
    for x in [-1,1]:
        g.box((x*.051,-.108,1.676),(.056,.018,.026),'black','head',bevel=.003)
        g.box((x*.051,-.12,1.677),(.022,.009,.007),'cloth','head')
    g.box((0,-.099,1.612),(.182,.082,.077),'iron2','head',bevel=.014)
    for x in [-.054,0,.054]:g.box((x,-.144,1.615),(.012,.009,.032),'dark','head')
    for j in range(3 if detail else 2):
        for side in [-1,1]:
            g.box((side*.17,-.173,.935-j*.073),(.28,.050,.059),'iron2','hips',Matrix.Rotation(side*.08,3,'Y'),.010)
            g.box((side*.17,-.201,.951-j*.073),(.27,.013,.011),'gold','hips')
            g.box((side*(.268+j*.012),.02,.935-j*.073),(.060,.30,.059),'iron2','hips',bevel=.010)
    g.panel([(-.104,-.194,.99),(.09,-.194,.99),(.105,-.23,.56),(-.055,-.24,.48),(-.12,-.215,.66)],.017,'cloth','hips')
    g.panel([(-.044,-.25,.80),(-.004,-.25,.80),(.036,-.248,.57),(.001,-.25,.55)],.005,'red','hips')
    g.panel([(-.10,.10,1.51),(.12,.10,1.50),(.20,.27,1.30),(.22,.33,1.0),(.07,.39,.89),(-.07,.32,1.19)],.025,'red','scarf')
    for s in ['L','R']:
        x=1 if s=='L' else -1
        for part,r,c in [('arm',.092,'dark'),('forearm',.078,'iron2'),('thigh',.111,'dark'),('shin',.086,'iron2')]:
            a,b,_=spec[part+'.'+s]; g.tube(a,b,r,r*.82,c,part+'.'+s,n=8)
        for j in range(3 if detail else 2):
            g.box((x*(.335+j*.019),0,1.455-j*.068),(.23 if s=='R' else .19,.275,.055),'iron2','arm.'+s,Matrix.Rotation(x*.11,3,'Y'),.013)
            g.box((x*(.34+j*.019),-.145,1.445-j*.068),(.195,.014,.012),'gold','arm.'+s)
        if detail:
            for j in range(3):
                a=Vector(spec['forearm.'+s][0]); b=Vector(spec['forearm.'+s][1]); p=a.lerp(b,.22+j*.24)
                d=(b-a).normalized()*.018; g.tube(p-d,p+d,.085,c='gold' if j==0 else 'red',bone='forearm.'+s,n=8)
        a,b,_=spec['hand.'+s]; g.ellipsoid(Vector(a).lerp(Vector(b),.48),(.055,.051,.078),'wood','hand.'+s,8,4)
        g.box((x*.16,-.084,.085),(.182,.34,.16),'dark','foot.'+s,bevel=.025)
        g.box((x*.16,-.218,.105),(.17,.065,.12),'iron2','foot.'+s,bevel=.012)
        g.box((x*.156,-.083,.47),(.117,.052,.09),'gold','shin.'+s,bevel=.015)
    if officer:
        g.tube((-.26,.19,.95),(-.26,.19,2.12),.021,c='wood',bone='spine')
        g.box((-.065,.19,1.91),(.38,.032,.40),'red','spine',bevel=.007)
        g.panel([(-.20,.164,1.96),(-.065,.164,2.02),(.07,.164,1.96),(-.065,.164,1.86)],.01,'gold','spine')
    polearm(g)
    return g

def low_soldier():
    g=Geo(); spec=bone_spec()
    g.ellipsoid((0,0,1.26),(.27,.16,.29),'iron','spine',8,3)
    g.box((0,-.16,1.29),(.38,.055,.32),'red','spine')
    for z in [1.16,1.30,1.43]:g.box((0,-.198,z),(.40,.017,.022),'gold','spine')
    g.ellipsoid((0,0,1.63),(.11,.10,.14),'skin','head',8,3)
    g.tube((0,0,1.72),(0,0,1.84),.20,.045,'iron2','head',8)
    g.box((0,-.108,1.65),(.17,.018,.025),'dark','head')
    g.box((0,-.15,.94),(.40,.08,.18),'red','hips')
    for s in ['L','R']:
        x=1 if s=='L' else -1
        for part,r,c in [('arm',.077,'dark'),('forearm',.070,'iron2'),('thigh',.10,'dark'),('shin',.077,'iron2')]:
            a,b,_=spec[part+'.'+s];g.tube(a,b,r,r*.85,c,part+'.'+s,n=5)
        g.box((x*.32,0,1.43),(.19,.21,.08),'iron2','arm.'+s)
        g.box((x*.16,-.08,.08),(.15,.29,.14),'dark','foot.'+s)
    g.tube((0,0,-.7),(0,0,1.2),.022,c='wood',bone='weapon',n=5)
    g.panel([(-.035,0,1.2),(.07,0,1.2),(.10,0,1.45),(0,0,1.65),(-.035,0,1.40)],.022,'edge','weapon')
    return g

def sockets(arm):
    out=[]
    for name,y in [('TrailBase',.90),('TrailTip',2.0)]:
        ob=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(ob)
        ob.parent=arm;ob.parent_type='BONE';ob.parent_bone='weapon';ob.location=(0,y,0)
        out.append(ob)
    return out

def orient(a,b):
    a,b=Vector(a),Vector(b); return Matrix.Translation(a) @ (b-a).to_track_quat('Y','Z').to_matrix().to_4x4()
def ik(a,b,l1,l2,pole):
    a,b=Vector(a),Vector(b); ab=b-a; dist=min(max(ab.length,.05),l1+l2-.0001); d=ab.normalized()
    v=Vector(pole)-a; v=(v-d*v.dot(d)).normalized(); along=(l1*l1-l2*l2+dist*dist)/(2*dist)
    return a+d*along+v*math.sqrt(max(0,l1*l1-along*along))

def pose(arm,f,grip=(0,-.46,1.14),yaw=.1,pitch=.65,twist=0,crouch=0,stride=0,lean=0,fall=0):
    spec=bone_spec(); mats={}; bodyrot=Matrix.Rotation(twist,4,'Z') @ Matrix.Rotation(lean,4,'X')
    origin=Vector((0,0,-crouch))
    def torso_point(p): return origin+bodyrot@Vector(p)
    mats['root']=Matrix.Identity(4)
    for n in ['hips','spine','head']:
        a,b,_=spec[n]; mats[n]=orient(torso_point(a),torso_point(b))
    direction=Vector((math.sin(yaw)*math.cos(pitch),-math.cos(yaw)*math.cos(pitch),math.sin(pitch)))
    gp=Vector(grip)+origin
    weaponrot=direction.to_track_quat('Z','Y').to_matrix().to_4x4()
    mats['weapon']=Matrix.Translation(gp) @ weaponrot @ arm.data.bones['weapon'].matrix_local
    for s in ['R','L']:
        sign=-1 if s=='R' else 1
        a=torso_point(spec['arm.'+s][0]); target=gp+direction*(-.20 if s=='R' else .20)
        la=(Vector(spec['arm.'+s][1])-Vector(spec['arm.'+s][0])).length
        lb=(Vector(spec['forearm.'+s][1])-Vector(spec['forearm.'+s][0])).length
        elbow=ik(a,target,la,lb,(sign*.85,0,1.05-crouch))
        mats['arm.'+s]=orient(a,elbow); mats['forearm.'+s]=orient(elbow,target)
        mats['hand.'+s]=orient(target,target+direction*.10)
        hip=torso_point(spec['thigh.'+s][0]); phase=stride*sign
        foot=Vector((sign*.19,-.05+phase*.38,.105+max(0,phase)*.16))
        if fall: foot.z+=.22
        l1=(Vector(spec['thigh.'+s][1])-Vector(spec['thigh.'+s][0])).length
        l2=(Vector(spec['shin.'+s][1])-Vector(spec['shin.'+s][0])).length
        knee=ik(hip,foot,l1,l2,(sign*.17,-1,.48))
        mats['thigh.'+s]=orient(hip,knee); mats['shin.'+s]=orient(knee,foot)
        mats['foot.'+s]=orient(foot,foot+Vector((0,-.22,-.035)))
    a,b,_=spec['scarf']; mats['scarf']=orient(torso_point(a),torso_point(b)+Vector((math.sin(f*.1)*.04,.025,0)))
    if fall:
        pivot=Vector((0,0,.9)); roll=Matrix.Translation(pivot) @ Matrix.Rotation(fall,4,'X') @ Matrix.Translation(-pivot)
        for n in mats:
            if n!='root': mats[n]=roll @ mats[n]
    for n in spec:
        pb=arm.pose.bones[n]; pb.rotation_mode='QUATERNION'; pb.matrix=mats[n]
        bpy.context.view_layer.update()
        for attr in ('location','rotation_quaternion','scale'): pb.keyframe_insert(attr,frame=f,group=n)

DURS={'Idle':120,'Run':36,'Dodge':24,'Jump':48,'Land':18,'Hit':24,'Death':60,
      'n1':35,'n2':35,'n3':30,'n4':38,'n5':50,'n6':48,'c1':56,'c2':112,'c3':114,'c4':76,'c5':80,'c6':130,'dash':88,'jatk':22,'jc':56,'Surge':200}
CONTACT={'n1':7,'n2':9,'n3':10,'n4':14,'n5':12,'n6':15,'c1':25,'c2':16,'c3':13,'c4':24,'c5':24,'c6':10,'dash':5,'jatk':5,'jc':36}
def interp(keys,t):
    for i in range(len(keys)-1):
        if t<=keys[i+1][0]:
            a,b=keys[i],keys[i+1]; u=max(0,(t-a[0])/(b[0]-a[0])); u=u*u*(3-2*u)
            return [x+(y-x)*u for x,y in zip(a[1:],b[1:])]
    return keys[-1][1:]

def animate(arm):
    arm.animation_data_create()
    for name,duration in DURS.items():
        ac=bpy.data.actions.new(name); ac.use_fake_user=True; arm.animation_data.action=ac
        for f in range(duration+1):
            t=f/duration; gp=(0,-.37,1.12); yaw=.60; pitch=.82; twist=0; crouch=.035; stride=0; lean=0; fall=0
            if name=='Idle':
                crouch=.035+.006*math.sin(t*TAU); gp=(0,-.38,1.12+.013*math.sin(t*TAU))
            elif name=='Run':
                stride=math.sin(t*TAU); crouch=.04+abs(stride)*.035; lean=.055; pitch=.70; gp=(-.045,-.38,1.15+.02*math.cos(t*TAU*2))
            elif name=='Dodge':
                crouch=.31*math.sin(t*math.pi); lean=.17; fall=-TAU*t; pitch=.25
            elif name=='Jump':
                crouch=.10; stride=.55; pitch=.85; lean=-.06
            elif name=='Land': crouch=.19*(1-t); gp=(0,-.45,1.10); pitch=.45
            elif name=='Hit': lean=-.18*math.sin(t*math.pi); yaw=.95; crouch=.11*math.sin(t*math.pi)
            elif name=='Death': fall=-1.43*min(1,t*1.8); crouch=.78*min(1,t*1.8); pitch=.22
            elif name=='Surge':
                yaw,pitch,twist,crouch=interp([(0,.5,.7,0,.04),(27,-.7,1.25,-.4,.19),(88,-.4,.8,-.18,.12),(100,0,.3,0,.16),(130,0,.05,.20,.10),(140,1.9,.18,.7,.09),(169,-2,.8,-.6,.15),(176,0,-.58,.3,.3),(187,0,-.58,.25,.18),(200,.6,.82,0,.035)],f)
            else:
                hit=CONTACT[name]; spin=name in ['c4','c6','dash']; lift=name in ['c1','c2','c5']
                slash=name in ['n3','n4','jatk']; alternate=name in ['n2','n4','c2']
                s=-1 if alternate else 1
                yaw,pitch,twist,crouch=interp([(0,.6,.82,0,.04),(max(1,hit-4),s*-1.45,(-.35 if lift else 1.2),s*-.55,.12),(hit,s*-.18,(.05 if slash else -.12 if lift else .4),s*.08,.10),(min(hit+5,duration-2),s*1.45,(1.0 if lift else -.15),s*.62,.075),(max(hit+6,duration-9),s*1.2,.15,s*.48,.06),(duration,.6,.82,0,.035)],f)
                if spin and hit<=f<=duration-14:
                    u=(f-hit)/max(1,duration-14-hit); yaw=-1.2+u*TAU*(3 if name=='dash' else 2); pitch=.18; twist=yaw*.28
                if name in ['c3','n5'] and hit<f<min(duration-12,hit+32):
                    gp=(0,-.32-.17*(.5+.5*math.sin((f-hit)*.8)),1.16); yaw=.05; pitch=.06
                if name=='jc':
                    yaw,pitch,twist,crouch=interp([(0,.25,1.1,0,.12),(31,.1,1.3,0,.08),(36,0,-1.15,.12,.33),(43,0,-1.15,.12,.30),(56,.6,.82,0,.035)],f)
                stride=.18*math.sin(t*math.pi)
            pose(arm,f,gp,yaw,pitch,twist,crouch,stride,lean,fall)
        track=arm.animation_data.nla_tracks.new(); track.name=name
        strip=track.strips.new(name,0,ac); strip.action_frame_start=0; strip.action_frame_end=duration
        track.mute=True
    arm.animation_data.action=bpy.data.actions.get('Idle'); bpy.context.scene.frame_set(0)

MANIFEST=[]
def export(name,objects,animated=False):
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    blend=SRC/(name+'.blend'); bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    path=OUT/(name+'.glb')
    kwargs=dict(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,
                export_animations=animated,export_skins=animated,export_extras=True,export_texcoords=False,
                export_normals=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    if animated:kwargs.update(export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_optimize_animation_size=True)
    bpy.ops.export_scene.gltf(**kwargs)
    policy=Path(str(path)+'.import')
    if not policy.exists():
        policy.write_text('[remap]\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[deps]\nsource_file="res://assets/models/'+name+'.glb"\n\n[params]\nmeshes/generate_lods=true\nskins/use_named_skins=true\nanimation/import=true\nanimation/fps=60\nanimation/import_rest_as_RESET=false\nimport_script/path="res://scripts/art/import_scene.gd"\n')
    raw=path.read_bytes(); jlen=int.from_bytes(raw[12:16],'little'); gltf=json.loads(raw[20:20+jlen])
    tris=sum((gltf['accessors'][p['indices']]['count']//3) for m in gltf.get('meshes',[]) for p in m['primitives'])
    entry={'name':name,'file':f'{name}.glb','bytes':len(raw),'triangles':tris,'meshes':len(gltf.get('meshes',[])),
           'materials':len(gltf.get('materials',[])),'bones':max([len(s['joints']) for s in gltf.get('skins',[])],default=0),
           'animations':[a['name'] for a in gltf.get('animations',[])],'sha256':hashlib.sha256(raw).hexdigest()}
    MANIFEST.append(entry); print('SENJIN_ASSET',json.dumps(entry),flush=True)
    return entry

def roof(g,width,depth,z,height=1.6):
    for side in [-1,1]:
        for row in range(5):
            v0=row/5; v1=(row+1)/5; ya=side*depth*.5*v0; yb=side*depth*.5*v1
            za=z+height*(1-v0)**1.4+.24*v0**6; zb=z+height*(1-v1)**1.4+.24*v1**6
            for tile in range(max(4,int(width/.44))):
                n=max(4,int(width/.44)); x0=-width*.5+width*tile/n; x1=-width*.5+width*(tile+1)/n
                g.add([(x0,ya,za),(x1,ya,za),(x1,yb,zb),(x0,yb,zb)],[(0,1,2,3),(3,2,1,0)],'roof' if tile%3 else 'iron2')
            g.tube((-width*.5,yb,zb),(width*.5,yb,zb),.055,c='edge',n=6)
    g.tube((-width*.52,0,z+height),(width*.52,0,z+height),.11,c='roof')
    for side in [-1,1]:g.box((side*width*.46,0,z+.1),(.17,depth*.91,.17),'red',bevel=.035)

def env_asset(name):
    g=Geo()
    if name=='wall':
        g.box((0,0,1.50),(8,1.20,3),'stone',bevel=.10)
        for row in range(5):
            for i in range(6):
                x=-3.9+i*1.34+(row%2)*.28
                if x<3.6:g.box((x, -.621, .30+row*.57),(1.24,.10,.5),'stone2' if (row+i)%5==0 else 'stone',bevel=.035)
        for x in [-3.6,3.6]:g.box((x,0,4.0),(.28,1.30,2.2),'wood',bevel=.04)
        g.box((0,0,3.92),(7.1,.32,1.88),'cloth',bevel=.04); g.box((0,-.23,3.4),(7.3,.13,.12),'wood2')
        roof(g,8.5,2.2,4.85,.70)
    elif name=='gate':
        for x in [-4.1,4.1]:
            g.box((x,0,3.1),(.8,1.3,6.2),'wood',bevel=.08)
            g.box((x,0,.4),(1.2,1.7,.8),'stone',bevel=.07)
            for z in [1.2,4.9]:g.box((x,0,z),(.86,1.36,.13),'gold',bevel=.014)
        g.box((0,0,5.7),(9.4,1.4,.7),'red',bevel=.06)
        g.box((0,0,6.55),(7.8,1.5,1.0),'wood2',bevel=.04)
        for x in range(-3,4):g.box((x, -.81,6.5),(.16,.15,.85),'gold')
        roof(g,11,4.1,7.1,1.7)
        for side in [-1,1]:
            g.box((side*3.1,.36,2.3),(1.45,.18,4.0),'wood2',bevel=.045)
            for z in [1.0,3.5]:g.box((side*3.1,.22,z),(1.53,.12,.15),'iron')
        g.box((0,-.86,6.02),(1.6,.18,.72),'iron',bevel=.06)
        g.panel([(-.28,-.98,6), (0,-.98,6.23),(.28,-.98,6),(0,-.98,5.8)],.025,'gold')
    elif name=='tower':
        g.box((0,0,.5),(4.6,4.6,1),'stone',bevel=.12)
        for x in [-1.65,1.65]:
            for y in [-1.65,1.65]:g.box((x,y,3.35),(.34,.34,5.6),'wood',bevel=.04)
        for side in [-1,1]:g.tube((-1.65,side*1.65,.85),(1.65,side*1.65,4.7),.10,c='wood2')
        g.box((0,0,4.9),(4.1,4.1,.24),'wood2',bevel=.035)
        for side in [-1,1]:
            for i in range(7):
                g.box((side*1.93,-1.75+i*.58,5.43),(.09,.09,.9),'wood')
                g.box((-1.75+i*.58,side*1.93,5.43),(.09,.09,.9),'wood')
            g.box((side*1.93,0,5.9),(.15,4,.16),'red',bevel=.02); g.box((0,side*1.93,5.9),(4,.15,.16),'red',bevel=.02)
        roof(g,5.4,5.4,7,1.4)
    elif name=='barricade':
        for x in [-1.4,0,1.4]:
            g.tube((x,-.6,0),(x,.5,1.8),.09,c='wood2');g.tube((x,.6,0),(x,-.5,1.8),.09,c='wood2')
            g.box((x,0,1.05),(.24,.24,.23),'iron',bevel=.035)
        g.tube((-1.8,0,1),(1.8,0,1),.12,c='wood')
    elif name=='banner':
        g.tube((0,0,0),(0,0,3.8),.045,c='wood');g.tube((-.1,0,3.52),(1.27,0,3.52),.035,c='gold')
        for j in range(12):
            z=3.48-j*.17
            for i in range(5):
                x=.08+i*.22; y=.07*math.sin(i*.6+j*.3)
                g.add([(x,y,z),(x+.22,y+.012,z),(x+.22,y+.012,z-.17),(x,y,z-.17)],[(0,1,2,3),(3,2,1,0)],'red2' if i in (0,4) else 'red')
        g.panel([(.3,-.035,2.75),(.6,-.035,3.07),(.9,-.035,2.75),(.6,-.035,2.47)],.012,'gold')
    elif name=='tent':
        g.add([(-2,-1.8,0),(2,-1.8,0),(0,-1.8,2.6),(-2,1.8,0),(2,1.8,0),(0,1.8,2.6)],[(0,1,2),(3,5,4),(0,2,5,3),(1,4,5,2)],'cloth')
        for y in [-1.85,1.85]:
            g.tube((0,y,0),(0,y,2.65),.06,c='wood');g.tube((-2,y,.03),(0,y,2.65),.032,c='gold');g.tube((2,y,.03),(0,y,2.65),.032,c='gold')
        g.panel([(-.8,-1.82,0),(.8,-1.82,0),(0,-1.82,1.8)],.02,'dark')
        for x in [-2.0,2.0]:g.tube((x,-1.8,.12),(x*1.4,-2.6,.02),.019,c='wood2')
    elif name=='brazier':
        for x,y in [(-.3,-.3),(.3,-.3),(0,.33)]:g.tube((x*1.3,y*1.3,0),(x,y,1.1),.045,c='iron')
        g.tube((0,0,.93),(0,0,1.15),.23,.46,'iron2',n=10)
        for i in range(9):
            a=i*TAU/9; g.tube((.39*math.cos(a),.39*math.sin(a),1.13),(.33*math.cos(a),.33*math.sin(a),1.39),.025,c='gold',n=5)
        for i in range(5):
            a=i*TAU/5; g.tube((math.cos(a)*.15,math.sin(a)*.15,1.14),(math.cos(a+.3)*.08,math.sin(a+.3)*.08,1.65+(i%2)*.22),.12,.009,'red2',n=5)
        g.ellipsoid((0,0,1.30),(.22,.22,.20),'gold2',n=8,rings=3)
    elif name=='crate':
        g.box((0,0,.48),(.98,.98,.96),'wood',bevel=.045)
        for i in range(5):
            for y in [-.51,.51]:g.box((-.39+i*.195,y,.48),(.18,.05,.87),'wood2',bevel=.007)
        for z in [.13,.81]:g.box((0,0,z),(1.07,1.07,.09),'iron',bevel=.015)
    elif name=='rock':
        g.ellipsoid((0,0,.45),(1.18,.80,.65),'stone',n=7,rings=3)
        g.ellipsoid((.77,.2,.25),(.6,.6,.36),'stone2',n=7,rings=3)
    elif name=='paver':
        for x in range(4):
            for y in range(4):
                cx=-1.5+x;cy=-1.5+y
                col='stone2' if (x*3+y)%7==0 else 'stone'
                g.box((cx,cy,-.035),(.973,.971,.09),col)
                g.cols[-6:]=[tuple(v*(.88+.035*((x*3+y*7)%5)) if k<3 else v for k,v in enumerate(c)) for c in g.cols[-6:]]
    elif name=='slash_arc':
        for i in range(32):
            a=-.2+3.65*i/32;b=-.2+3.65*(i+1)/32
            w=.02+.27*math.sin(math.pi*(i+.5)/32)
            g.add([(math.cos(a)*(1-w),math.sin(a)*(1-w),0),(math.cos(a),math.sin(a),.035),(math.cos(b),math.sin(b),.035),(math.cos(b)*(1-w),math.sin(b)*(1-w),0)],[(0,1,2,3),(3,2,1,0)],'gold2' if i>22 else 'red2')
    elif name=='shock_ring':
        for i in range(48):
            a=TAU*i/48;b=TAU*(i+.8)/48
            g.add([(.91*math.cos(a),.91*math.sin(a),0),(math.cos(a),math.sin(a),0),(math.cos(b),math.sin(b),.07),(.91*math.cos(b),.91*math.sin(b),.02)],[(0,1,2,3),(3,2,1,0)],'gold2')
    elif name=='spark':
        g.add([(0,0,-.5),(-.07,0,0),(0,-.07,0),(.07,0,0),(0,.07,0),(0,0,.5)],[(0,2,1),(0,3,2),(0,4,3),(0,1,4),(5,1,2),(5,2,3),(5,3,4),(5,4,1)],'gold2')
    elif name=='surge_ribbon':
        for i in range(48):
            a=i*TAU*1.3/48;b=(i+1)*TAU*1.3/48;r=.4+i/48*.65;h=i/48*.75
            g.add([(r*math.cos(a),r*math.sin(a),h),((r-.15)*math.cos(a),(r-.15)*math.sin(a),h+.15),((r-.15)*math.cos(b),(r-.15)*math.sin(b),h+.17),(r*math.cos(b),r*math.sin(b),h+.03)],[(0,1,2,3),(3,2,1,0)],'red2' if i%8<5 else 'gold2')
    return g

def render_preview(name,objects,animated=False):
    if not ARGS.render:return
    sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=32; sc.cycles.use_denoising=True
    sc.render.resolution_x=1000;sc.render.resolution_y=1000;sc.render.resolution_percentage=100
    sc.world.use_nodes=True; sc.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.16,.20,.27,1); sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
    if animated:
        for ob in objects:
            if ob.type=='ARMATURE':ob.animation_data.action=bpy.data.actions.get('Idle')
        sc.frame_set(0)
    bpy.context.view_layer.update()
    bounds=[o.matrix_world@Vector(v) for o in objects if o.type=='MESH' for v in o.bound_box]
    if animated: bounds=[Vector((-1,-1,0)),Vector((1,1,2.7))]
    lo=Vector(tuple(min(p[i] for p in bounds) for i in range(3))); hi=Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
    target=(lo+hi)*.5; extent=max(hi-lo)
    cam_data=bpy.data.cameras.new('PreviewCamera');cam=bpy.data.objects.new('PreviewCamera',cam_data);sc.collection.objects.link(cam)
    cam.location=target+Vector((extent*.9,-extent*1.65,extent*.65));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam_data.type='ORTHO';cam_data.ortho_scale=extent*1.14;sc.camera=cam
    for nm,offset,energy,size,col in [('Key',(-3,-4,6),1100,5,(1,.80,.65)),('Fill',(4,-2,3),750,4,(.64,.79,1)),('Rim',(1,4,5),1300,3,(1,.50,.3))]:
        ld=bpy.data.lights.new(nm,'AREA');ld.energy=energy;ld.shape='DISK';ld.size=size;ld.color=col
        ob=bpy.data.objects.new(nm,ld);sc.collection.objects.link(ob);ob.location=target+Vector(offset)*max(1,extent*.5);ob.rotation_euler=(target-ob.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.mesh.primitive_plane_add(size=extent*200,location=(0,0,-.04));floor=bpy.context.object;fm=bpy.data.materials.new('PreviewGround');fm.use_nodes=True;fm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.028,.041,.059,1);fm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8;floor.data.materials.append(fm)
    sc.view_settings.view_transform='AgX';sc.render.filepath=str(PRE/(name+'.png'));bpy.ops.render.render(write_still=True)

def main():
    clear(); ar=rig(); g=character(True); body=g.obj('Vanguard',ar); animate(ar);export('vanguard',[ar,body]+sockets(ar),True);render_preview('vanguard',[ar,body],True)
    clear();ar=rig();g=character(True,True);body=g.obj('Officer',ar);animate(ar);export('officer',[ar,body]+sockets(ar),True)
    clear();ar=rig();g=character(False);body=g.obj('Soldier',ar);animate(ar);export('soldier',[ar,body]+sockets(ar),True)
    for nm,groups in [('soldier_body',[n for n in bone_spec() if not any(n.startswith(p) for p in ('thigh','shin','foot'))]),('soldier_leg_l',['thigh.L','shin.L','foot.L']),('soldier_leg_r',['thigh.R','shin.R','foot.R'])]:
        clear(); src=low_soldier(); g=Geo()
        for face,col in zip(src.f,src.cols):
            if src.groups[face[0]] in groups:
                vs=[Vector(src.v[i]) for i in face]
                if 'leg' in nm:
                    origin=Vector((.145 if nm.endswith('_l') else -.145,0,.98));vs=[v-origin for v in vs]
                elif src.groups[face[0]]=='weapon':
                    vs=[v+Vector((-.39,-.16,.91)) for v in vs]
                g.add(vs,[tuple(range(len(vs)))],'iron');g.cols[-1]=col
        ob=g.obj(nm);export(nm,[ob])
    clear();g=Geo();polearm(g);o=g.obj('Polearm');export('polearm',[o])
    for name in ['wall','gate','tower','barricade','banner','tent','brazier','crate','rock','paver','slash_arc','shock_ring','spark','surge_ribbon']:
        clear()
        if name in ['slash_arc','shock_ring','spark','surge_ribbon']:globals()['MAT']=material('SENJIN_EmberFX',True)
        ob=env_asset(name).obj(name); export(name,[ob])
        if name in ['gate','tower','banner','tent']:render_preview(name,[ob])
    (OUT/'manifest.json').write_text(json.dumps({'schema':1,'authoring':'Blender '+bpy.app.version_string,'license':'MIT','forward':'+Z','up':'+Y','units':'metres','assets':MANIFEST},indent=2)+'\n')
    print('SENJIN_ASSETS_PASS',len(MANIFEST),flush=True)
if __name__=='__main__':main()
