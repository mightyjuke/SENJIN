extends Node3D
const Factory = preload("res://scripts/mesh_factory.gd")
const Battle = preload("res://scripts/battle.gd")
var battle: RefCounted
var camera: Camera3D
var camera_yaw: float = 0.0
var camera_pitch: float = 0.42
var rig: Dictionary = {}
var body: MultiMesh
var left_leg: MultiMesh
var right_leg: MultiMesh
var ring: MeshInstance3D
var trail: MeshInstance3D
var _effects: Array[MeshInstance3D] = []
var _life: PackedFloat32Array = PackedFloat32Array()
var _velocity: PackedVector3Array = PackedVector3Array()
var _effect_cursor: int = 0
var _visual_rng := RandomNumberGenerator.new()
var _shake: float = 0.0
var _age: float = 0.0

func setup(sim: RefCounted, shadows: bool = true) -> void:
	battle = sim
	_visual_rng.seed = 7301
	_build_world(shadows)
	rig = Factory.hero(self)
	body = _instances(Factory.soldier(),battle.count)
	left_leg = _instances(Factory.leg(),battle.count)
	right_leg = _instances(Factory.leg(),battle.count)
	camera = Camera3D.new()
	camera.fov = 52.0
	camera.near = 0.15
	camera.far = 240.0
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0,6.4,10.5)
	camera.look_at(Vector3(0,1,0))
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	ring = MeshInstance3D.new()
	ring.mesh = torus
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color("ffc581")
	ring.material_override = gold
	ring.visible = false
	add_child(ring)
	trail = MeshInstance3D.new()
	trail.mesh = torus
	var crimson := StandardMaterial3D.new()
	crimson.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crimson.albedo_color = Color("dd634e")
	trail.material_override = crimson
	trail.visible = false
	add_child(trail)
	var spark_mesh: ArrayMesh = Factory.boxes([[Vector3.ZERO,Vector3.ONE,Color("ffc78d")]])
	_life.resize(96)
	_velocity.resize(96)
	for i in range(96):
		var fx := MeshInstance3D.new()
		fx.mesh = spark_mesh
		fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx.visible = false
		add_child(fx)
		_effects.append(fx)
	battle.impact.connect(_impact)
	battle.action_started.connect(_action)
	battle.hero_damaged.connect(func(): _shake = 0.22)
	update_view(0.016)

func _instances(mesh: Mesh, capacity: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return mm

func _build_world(shadows: bool) -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a88470")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a1adc1")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-30,0)
	sun.light_color = Color("ffdda5")
	sun.light_energy = 1.4
	sun.shadow_enabled = shadows
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var parts: Array = [[Vector3(0,-0.3,0),Vector3(190,0.6,190),Color("71665e")]]
	# Ground pavers and camp props use one vertex-colored mesh.
	for x in range(-10,11):
		for z in range(-10,11):
			var shade: float = _visual_rng.randf_range(0.78,1.05)
			parts.append([Vector3(x*4.0,-0.015,z*4.0),Vector3(3.84,0.055,3.84),Color(0.46,0.42,0.37)*shade])
	# Fortress with a real open gate silhouette; arena collision is the circular simulation boundary.
	for side in [-1,1]:
		parts.append([Vector3(side*31,4.6,-53),Vector3(45,9.2,4),Color("49454c")])
		parts.append([Vector3(side*8,7.4,-53),Vector3(4,14.8,7),Color("48414a")])
		parts.append([Vector3(side*8,15.2,-53),Vector3(9,1.2,10),Color("372932")])
	parts.append([Vector3(0,11.2,-53),Vector3(14,2.2,5),Color("62525a")])
	for x in range(-52,53,4):
		parts.append([Vector3(x,9.8,-53),Vector3(2.5,1.2,4.8),Color("615660")])
	for i in range(64):
		var a: float = float(i)*TAU/64.0
		var point := Vector3(sin(a)*47.0,1.6,cos(a)*47.0)
		if point.z < -35 and absf(point.x)<12:
			continue
		parts.append([point,Vector3(0.7,3.2,0.7),Color("534032")])
	for i in range(26):
		var a: float = _visual_rng.randf_range(0,TAU)
		var p := Vector3(sin(a)*55.0,0,cos(a)*55.0)
		parts.append([p+Vector3(0,3.8,0),Vector3(0.14,7.6,0.14),Color("342833")])
		parts.append([p+Vector3(1.0,6.0,0),Vector3(2.0,2.4,0.10),Color("893a33") if i%2 else Color("a0865f")])
	Factory.mesh_node(self,parts,"Battlefield")

func update_view(delta: float) -> void:
	_age += delta
	_update_crowd()
	_update_hero()
	var distance: float = 10.5
	if battle.hero_state == "surge" and battle.surge_frame < 90:
		distance = 7.2
	var offset := Vector3(0,sin(camera_pitch)*distance+2.0,cos(camera_pitch)*distance).rotated(Vector3.UP,camera_yaw)
	var desired: Vector3 = battle.hero_position + offset
	camera.position = camera.position.lerp(desired,1.0-exp(-10.0*delta))
	camera.position.y = maxf(2.4,camera.position.y)
	camera.look_at(battle.hero_position+Vector3(0,1.35,0))
	if _shake>0.001:
		camera.position += Vector3(sin(_age*123.0),cos(_age*91.0),0)*_shake
		_shake = move_toward(_shake,0.0,delta*1.2)
	for i in range(_effects.size()):
		if _life[i]<=0:
			continue
		_life[i]-=delta
		_effects[i].position += _velocity[i]*delta
		_velocity[i] += Vector3.DOWN*9.0*delta
		_effects[i].rotate_x(delta*7.0)
		if _life[i]<=0:
			_effects[i].visible=false
	_update_surge()

func _update_crowd() -> void:
	var slot: int = 0
	for i in range(battle.count):
		if battle.states[i] == Battle.EnemyState.DEAD:
			continue
		var size: float = 1.3 if battle.officers[i] else 1.0
		var pose := Transform3D(Basis(Vector3.UP,battle.facings[i]).scaled(Vector3.ONE*size),battle.positions[i])
		var tint := Color(1,1,1)
		if battle.officers[i]:
			tint = Color(1.45,1.2,0.9)
		if battle.states[i] == Battle.EnemyState.WINDUP:
			tint = Color(2.0,1.25,0.7)
		elif battle.states[i] == Battle.EnemyState.STUN:
			tint = Color(1.7,1.5,1.25)
		body.set_instance_transform(slot,pose)
		body.set_instance_color(slot,tint)
		var stride: float = sin(float(battle.frame)*0.22+float(i)) * minf(0.65,battle.velocities[i].length()*0.2)
		left_leg.set_instance_transform(slot,pose * Transform3D(Basis(Vector3.RIGHT,stride),Vector3(-0.18,0.84,0)))
		right_leg.set_instance_transform(slot,pose * Transform3D(Basis(Vector3.RIGHT,-stride),Vector3(0.18,0.84,0)))
		slot += 1
	body.visible_instance_count = slot
	left_leg.visible_instance_count = slot
	right_leg.visible_instance_count = slot

func _update_hero() -> void:
	rig.root.position = battle.hero_position
	rig.root.rotation = Vector3(0,battle.hero_yaw,0)
	var stride: float = sin(float(battle.frame)*0.29)*minf(battle.hero_speed*0.07,0.6) if battle.hero_state=="move" else 0.0
	rig.left_leg.rotation.x = stride
	rig.right_leg.rotation.x = -stride
	rig.left_arm.rotation = Vector3(-0.2-stride*0.5,0,0.06)
	rig.right_arm.rotation = Vector3(-0.4+stride*0.5,0,-0.06)
	rig.torso.rotation = Vector3.ZERO
	rig.weapon.rotation = Vector3(-0.12,0.0,-0.12)
	trail.visible = false
	if battle.hero_state=="attack":
		var m: Dictionary = battle.moves[battle.move_id]
		var t: float = float(battle.move_frame)/float(m.frames)
		var sweep: float = sin(t*TAU)*1.5
		if battle.move_id in ["c3","c4","c6","dash"]:
			sweep = t*TAU*2.0
		rig.torso.rotation.y = sweep*0.3
		rig.weapon.rotation.y = sweep
		rig.weapon.rotation.z = sin(t*PI)*0.4
		rig.right_arm.rotation.x = -1.0
		for h in m.hits:
			if battle.move_frame>=int(h.first) and battle.move_frame<=int(h.last):
				trail.visible=true
				trail.position=battle.hero_position+Vector3(0,1.1,0)
				trail.scale=Vector3(float(h.range),0.55,float(h.range))
	elif battle.hero_state=="dodge":
		rig.torso.rotation.x=-float(battle.state_frame)/24.0*TAU
	elif battle.hero_state=="surge":
		rig.weapon.rotation.y=sin(float(battle.surge_frame)*0.15)*1.4
		rig.right_arm.rotation.x=-1.0
	elif battle.game_over:
		rig.root.rotation.z=1.35

func _update_surge() -> void:
	ring.visible=battle.hero_state=="surge"
	if not ring.visible:
		return
	var t: int = battle.surge_frame
	ring.position=battle.hero_position+Vector3(0,0.2,0)
	var radius: float = 1.8+sin(float(t)*0.15)*0.2
	if t>=176:
		radius=1.0+float(t-176)*0.55
	elif t>=132:
		radius=3.0
		ring.position+=battle.forward()*(3.0+float(t-132)*0.18)
		ring.position.y=1.2+sin(float(t)*0.24)*0.4
	ring.scale=Vector3(radius,0.65,radius)

func _impact(point: Vector3, heavy: bool, killed: bool) -> void:
	var amount: int = 5 if heavy or killed else 2
	for _i in range(amount):
		var slot: int = _effect_cursor%_effects.size()
		_effect_cursor+=1
		_life[slot]=0.36 if not killed else 0.7
		_effects[slot].position=point
		_effects[slot].scale=Vector3.ONE*(0.19 if killed else 0.075)
		_effects[slot].visible=true
		_velocity[slot]=Vector3(_visual_rng.randf_range(-4,4),_visual_rng.randf_range(2,6),_visual_rng.randf_range(-4,4))
	if heavy:
		_shake=maxf(_shake,0.12)

func _action(id: String) -> void:
	if id=="surge_burst":
		_shake=0.32
		_impact(battle.hero_position+Vector3.UP,true,true)
