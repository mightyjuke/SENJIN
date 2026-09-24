extends "res://scripts/arena_view.gd"
## Imported Blender assets replace native prototype geometry, without changing Battle.
const Assets = preload("res://scripts/art/asset_library.gd")
const Actor = preload("res://scripts/art/actor.gd")
const NEAR_LIMIT: int = 8
var hero_actor: Node3D
var _near_actors: Array[Node3D] = []
var _near_ids: Array[int] = []
var _officer_actors: Dictionary = {}
var _last_selection_frame: int = -100
var _hero_clip: String = "Idle"
var _hero_visual_start: int = 0
var _storm: MeshInstance3D
var _weapon_trail: MeshInstance3D
var _ribbon_mesh: ImmediateMesh
var _ribbon_base: Array[Vector3] = []
var _ribbon_tip: Array[Vector3] = []
var _last_trail_frame: int = -1
var _trail_active: bool = false
var _contact_shadows: MultiMesh

func setup(sim: RefCounted, shadows: bool = true) -> void:
	battle = sim
	_visual_rng.seed = 7301
	camera_pitch = 0.30
	_build_world(shadows)
	hero_actor = Actor.new()
	add_child(hero_actor)
	hero_actor.build("vanguard")
	rig = {"root":hero_actor}
	body = _instances(Assets.mesh("soldier_body"), battle.count)
	left_leg = _instances(Assets.mesh("soldier_leg_l"), battle.count)
	right_leg = _instances(Assets.mesh("soldier_leg_r"), battle.count)
	for i in range(NEAR_LIMIT):
		var actor: Node3D = Actor.new()
		add_child(actor)
		actor.build("soldier")
		actor.visible = false
		_near_actors.append(actor)
		_near_ids.append(-1)
	for i in range(battle.count):
		if battle.officers[i]:
			var actor: Node3D = Actor.new()
			add_child(actor)
			actor.build("officer")
			actor.scale = Vector3.ONE * 1.17
			_officer_actors[i] = actor
	camera = Camera3D.new()
	camera.fov = 50
	camera.near = 0.12
	camera.far = 210
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0,4.2,7.8)
	camera.look_at(Vector3(0,1,0))
	ring = _fx("shock_ring")
	trail = _fx("slash_arc")
	_storm = _fx("surge_ribbon")
	_ribbon_mesh = ImmediateMesh.new()
	_weapon_trail = MeshInstance3D.new()
	_weapon_trail.mesh = _ribbon_mesh
	var ribbon_mat := StandardMaterial3D.new()
	ribbon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ribbon_mat.vertex_color_use_as_albedo = true
	ribbon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ribbon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_weapon_trail.material_override = ribbon_mat
	_weapon_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_weapon_trail)
	_life.resize(96)
	_velocity.resize(96)
	for i in range(96):
		var spark: MeshInstance3D = _fx("spark")
		_effects.append(spark)
	battle.impact.connect(_impact)
	battle.action_started.connect(_action)
	battle.hero_damaged.connect(func(): _shake = 0.16)
	_build_contact_shadows()
	update_view(0.016)

func _build_contact_shadows() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.2, 1.2)
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; void fragment() { ALBEDO=vec3(0.025,0.02,0.02); ALPHA=(1.0-smoothstep(0.08,0.50,length(UV-vec2(0.5))))*0.38*COLOR.a; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	plane.material = material
	_contact_shadows = _instances(plane, battle.count + 1)

func _update_contact_shadows() -> void:
	var slot: int = 0
	for i in range(battle.count + 1):
		if i < battle.count and battle.states[i] == Battle.EnemyState.DEAD:
			continue
		var point: Vector3 = battle.hero_position if i == battle.count else battle.positions[i]
		var fade: float = clampf(1.0 - point.y * 0.22, 0.0, 1.0)
		_contact_shadows.set_instance_transform(slot, Transform3D(Basis.IDENTITY, Vector3(point.x, 0.055, point.z)))
		_contact_shadows.set_instance_color(slot, Color(1,1,1,fade))
		slot += 1
	_contact_shadows.visible_instance_count = slot

func _fx(id: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = Assets.mesh(id)
	var mat: StandardMaterial3D = node.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color.a = 0.72
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node

func _build_world(shadows: bool) -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("384d6a")
	sky_mat.sky_horizon_color = Color("c5b59e")
	sky_mat.ground_horizon_color = Color("c5b59e")
	sky_mat.ground_bottom_color = Color("5c5856")
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a1b3cb")
	env.ambient_light_energy = 0.44
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("bbaa95")
	env.fog_density = 0.003
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-37,-32,0)
	sun.light_color = Color("ffdbb0")
	sun.light_energy = 1.15
	sun.shadow_enabled = shadows
	sun.directional_shadow_max_distance = 28
	add_child(sun)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(210,210)
	ground.mesh = ground_mesh
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color("777263")
	soil.roughness = 0.98
	ground.material_override = soil
	ground.position.y = -0.05
	add_child(ground)
	var pavers: MultiMesh = _instances(Assets.mesh("paver"),529)
	var k: int = 0
	for x in range(-11,12):
		for z in range(-11,12):
			pavers.set_instance_transform(k,Transform3D(Basis.IDENTITY,Vector3(x*4,0,z*4)))
			var tint: float = 0.86 + float((x*13+z*17+200)%9)*0.018
			pavers.set_instance_color(k,Color(tint,tint,tint))
			k += 1
	pavers.visible_instance_count = k
	Assets.place(self,"gate",Vector3(0,0,-48),0,1.45)
	for side in [-1,1]:
		for i in range(5):
			Assets.place(self,"wall",Vector3(side*(11+i*8),0,-48),0,1.0)
		Assets.place(self,"tower",Vector3(side*49,0,-48),0,1.35)
		for i in range(5):
			Assets.place(self,"wall",Vector3(side*49,0,-38+i*8),PI/2)
		for i in range(4):
			Assets.place(self,"tent",Vector3(side*(42+i%2*7),0,8+i*7),side*0.3)
		for i in range(6):
			Assets.place(self,"barricade",Vector3(side*43,0,-25+i*9),PI/2)
		for i in range(5):
			Assets.place(self,"banner",Vector3(side*36,0,-34+i*15),side*.25,1.3)
		Assets.place(self,"brazier",Vector3(side*9,0,-39),0,1.5)
		for i in range(4):
			Assets.place(self,"crate",Vector3(side*(39+i%2*1.25),0,18+i*.9),i*.25)
	for i in range(24):
		var a: float = TAU*float(i)/24
		Assets.place(self,"rock",Vector3(sin(a)*61,0,cos(a)*61),a,1.3+float(i%3)*.35)

func _choose_near() -> void:
	if battle.frame - _last_selection_frame < 12:
		return
	_last_selection_frame = battle.frame
	var candidates: Array[int] = []
	for i in range(battle.count):
		if not battle.officers[i] and battle.states[i] != Battle.EnemyState.DEAD:
			if battle.positions[i].distance_squared_to(battle.hero_position)<100:
				candidates.append(i)
	candidates.sort_custom(func(a:int,b:int):return battle.positions[a].distance_squared_to(battle.hero_position)<battle.positions[b].distance_squared_to(battle.hero_position))
	if candidates.size()>NEAR_LIMIT:
		candidates.resize(NEAR_LIMIT)
	for slot in range(NEAR_LIMIT):
		if not _near_ids[slot] in candidates:
			_near_ids[slot] = -1
	for i in candidates:
		if not i in _near_ids:
			var slot: int = _near_ids.find(-1)
			if slot >= 0:
				_near_ids[slot] = i

func _enemy_pose(actor: Node3D, i: int) -> void:
	actor.visible = battle.states[i] != Battle.EnemyState.DEAD
	if not actor.visible:
		return
	actor.position = battle.positions[i]
	actor.rotation = Vector3(0,battle.facings[i]+PI,0)
	var state: int = battle.states[i]
	if state == Battle.EnemyState.WINDUP:
		var window: int = 32 if battle.officers[i] else 44
		actor.sample("n1",clampf(float(window-battle.timers[i])/float(window)*7.0/60.0,0,7.0/60.0))
	elif state == Battle.EnemyState.RECOVER:
		var recovery: int = 75 if battle.officers[i] else 110
		actor.sample("n1",(7.0+float(recovery-battle.timers[i]))/60.0)
	elif state == Battle.EnemyState.STUN:
		actor.sample("Hit",float(24-battle.timers[i])/60.0)
	else:
		actor.sample("Run" if battle.velocities[i].length()>0.5 else "Idle",float(battle.frame+i*7)/60.0,true)

func _update_crowd() -> void:
	_choose_near()
	for slot in range(NEAR_LIMIT):
		var i: int = _near_ids[slot]
		_near_actors[slot].visible = i>=0
		if i>=0:
			_enemy_pose(_near_actors[slot],i)
	for i in _officer_actors:
		_enemy_pose(_officer_actors[i],i)
	var slot: int = 0
	for i in range(battle.count):
		if battle.states[i] == Battle.EnemyState.DEAD or battle.officers[i] or i in _near_ids:
			continue
		var pose := Transform3D(Basis(Vector3.UP,battle.facings[i]+PI),battle.positions[i])
		var tint := Color(1.04,.78,.69)
		if battle.states[i] == Battle.EnemyState.WINDUP:
			tint = Color(1.45,1.05,.68)
		elif battle.states[i] == Battle.EnemyState.STUN:
			tint = Color(1.25,1.20,1.1)
		body.set_instance_transform(slot,pose)
		body.set_instance_color(slot,tint)
		var stride: float = sin(float(battle.frame)*.22+float(i))*minf(.55,battle.velocities[i].length()*.17)
		left_leg.set_instance_transform(slot,pose*Transform3D(Basis(Vector3.RIGHT,stride),Vector3(.145,.98,0)))
		right_leg.set_instance_transform(slot,pose*Transform3D(Basis(Vector3.RIGHT,-stride),Vector3(-.145,.98,0)))
		left_leg.set_instance_color(slot,tint)
		right_leg.set_instance_color(slot,tint)
		slot += 1
	body.visible_instance_count = slot
	left_leg.visible_instance_count = slot
	right_leg.visible_instance_count = slot

func _update_hero() -> void:
	hero_actor.position = battle.hero_position
	hero_actor.rotation = Vector3(0,battle.hero_yaw+PI,0)
	var clip: String = "Idle"
	var at: float = float(battle.frame)/60.0
	var loop: bool = true
	match battle.hero_state:
		"move": clip = "Run"
		"attack": clip = battle.move_id; at = float(battle.move_frame)/60.0; loop = false
		"dodge": clip = "Dodge"; at = float(battle.state_frame)/60.0; loop = false
		"surge": clip = "Surge"; at = float(battle.surge_frame)/60.0; loop = false
		"hurt": clip = "Hit"; at = float(battle.state_frame)/60.0; loop = false
	if battle.hero_position.y>0.01 and clip in ["Idle","Run"]:
		clip = "Jump"
	if battle.game_over:
		clip = "Death"; loop = false
		if _hero_clip != clip:
			_hero_visual_start = battle.frame
		at = float(battle.frame-_hero_visual_start)/60.0
	_hero_clip = clip
	hero_actor.sample(clip,at,loop)
	trail.visible = false
	_trail_active = battle.hero_state == "surge" and battle.surge_frame>=132 and battle.surge_frame<176
	if battle.hero_state == "attack":
		var move: Dictionary = battle.moves[battle.move_id]
		for hit in move.hits:
			if battle.move_frame>=int(hit.first) and battle.move_frame<=int(hit.last):
				_trail_active = true
				trail.visible = true
				trail.position = battle.hero_position+Vector3(0,1.05,0)
				trail.rotation = Vector3(0,battle.hero_yaw+PI,0.20 if hit.shape=="arc" else 0)
				var radius: float = minf(float(hit.range),3.2)
				trail.scale = Vector3(radius,.65,radius)

func update_view(delta: float) -> void:
	_age += delta
	_update_crowd()
	_update_hero()
	_update_contact_shadows()
	var distance: float = 8.2 if battle.hero_state != "surge" else 8.8
	var offset := Vector3(0,sin(camera_pitch)*distance+1.1,cos(camera_pitch)*distance).rotated(Vector3.UP,camera_yaw)
	camera.position = camera.position.lerp(battle.hero_position + offset,1.0-exp(-10.0*delta))
	camera.position.y = maxf(1.8,camera.position.y)
	camera.look_at(battle.hero_position+Vector3(0,1.25,0))
	if _shake > 0.001:
		camera.position += Vector3(sin(_age*123.0),cos(_age*91.0),0)*_shake
		_shake = move_toward(_shake,0.0,delta*1.2)
	for i in range(_effects.size()):
		if _life[i] <= 0:
			continue
		_life[i] -= delta
		_effects[i].position += _velocity[i] * delta
		_velocity[i] += Vector3.DOWN * 9.0 * delta
		_effects[i].rotate_x(delta * 7.0)
		var mat: StandardMaterial3D = _effects[i].material_override as StandardMaterial3D
		mat.albedo_color.a = clampf(_life[i] * 3.5, 0.0, 0.72)
		if _life[i] <= 0:
			_effects[i].visible = false
	_update_surge()
	if battle.frame == _last_trail_frame:
		return
	_last_trail_frame = battle.frame
	if _trail_active:
		_ribbon_base.push_back(hero_actor.trail_base.global_position)
		_ribbon_tip.push_back(hero_actor.trail_tip.global_position)
		while _ribbon_base.size()>7:
			_ribbon_base.pop_front(); _ribbon_tip.pop_front()
	elif not _ribbon_base.is_empty():
		_ribbon_base.pop_front(); _ribbon_tip.pop_front()
	_ribbon_mesh.clear_surfaces()
	if _ribbon_base.size()<2:
		return
	_ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,_ribbon_base.size()):
		var alpha: float = float(i)/float(_ribbon_base.size())*.72
		for v in [_ribbon_base[i-1],_ribbon_tip[i-1],_ribbon_tip[i],_ribbon_base[i-1],_ribbon_tip[i],_ribbon_base[i]]:
			_ribbon_mesh.surface_set_color(Color(1.0,.63,.25,alpha))
			_ribbon_mesh.surface_add_vertex(v)
	_ribbon_mesh.surface_end()

func _update_surge() -> void:
	var active: bool = battle.hero_state == "surge"
	ring.visible = active
	_storm.visible = active and battle.surge_frame>=132
	if not active:
		return
	var t: int = battle.surge_frame
	ring.position = battle.hero_position+Vector3(0,.075,0)
	var radius: float = 1.8
	if t>=176:
		radius = 1+float(t-176)*.53
	elif t>=132:
		radius = 3.0
		ring.position += battle.forward()*(3+float(t-132)*.18)
		ring.position.y = .45
	ring.scale = Vector3(radius,1,radius)
	_storm.position = ring.position
	_storm.rotation.y = float(t)*.14
	_storm.scale = Vector3(minf(radius,5),2.1,minf(radius,5))

func _impact(point: Vector3, heavy: bool, killed: bool) -> void:
	super._impact(point,heavy,killed)
	var amount: int = 5 if heavy or killed else 2
	for k in range(amount):
		var slot: int = posmod(_effect_cursor-1-k,_effects.size())
		_effects[slot].scale = Vector3(.8,1.4,.8) if heavy else Vector3(.35,.7,.35)
