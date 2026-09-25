extends "res://scripts/art/authored_arena.gd"
## Hero/weapon/lighting vertical slice. Enemy counts, attacks, physics and hitboxes
## are inherited unchanged. Only the one hero uses the higher-detail PBR assets.
const HeroScene = preload("res://assets/realism/vanguard.glb")
const Lighting = preload("res://scripts/realism/lighting.gd")

func setup(sim: RefCounted, shadows: bool = true) -> void:
	super.setup(sim,shadows)
	remove_child(hero_actor)
	hero_actor.free()
	hero_actor = Actor.new()
	add_child(hero_actor)
	hero_actor.build("vanguard",HeroScene)
	rig = {"root":hero_actor}
	# Review closer material/weapon detail while retaining free right-thumb orbit.
	camera.fov = 45
	get_viewport().msaa_3d = Viewport.MSAA_2X if shadows else Viewport.MSAA_DISABLED

func _build_world(shadows: bool) -> void:
	super._build_world(shadows)
	for child in get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			remove_child(child)
			child.free()
	var world := WorldEnvironment.new()
	world.name = "IronOathLighting"
	world.environment = Lighting.environment()
	add_child(world)
	add_child(Lighting.sun(shadows))
	var ground_material: StandardMaterial3D = Lighting.ground()
	for child in get_children():
		if child is MeshInstance3D and child.mesh is PlaneMesh:
			child.material_override = ground_material
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif child is MultiMeshInstance3D and child.multimesh.mesh == Assets.mesh("paver"):
			child.material_override = ground_material
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func blocks_camera(center: Vector3, camera_position: Vector3, target: Vector3) -> bool:
	# Presentation only: hide enemies in a narrow camera-to-hero capsule. The
	# simulation and off-axis attackers remain untouched. Parent updates restore
	# all instance transforms on the following frame, so no unit is despawned.
	var ray: Vector3 = target - camera_position
	var length_squared: float = ray.length_squared()
	if length_squared < 0.01:
		return false
	var along: float = (center - camera_position).dot(ray) / length_squared
	if along <= 0.0 or along >= 0.94:
		return false
	return center.distance_squared_to(camera_position + ray * along) < 0.85 * 0.85

func update_view(delta: float) -> void:
	super.update_view(delta)
	var target: Vector3 = battle.hero_position + Vector3(0,1.25,0)
	for slot in range(NEAR_LIMIT):
		var index: int = _near_ids[slot]
		if index >= 0 and blocks_camera(battle.positions[index] + Vector3(0,1.1,0),camera.position,target):
			_near_actors[slot].visible = false
	for index in _officer_actors:
		if blocks_camera(battle.positions[index] + Vector3(0,1.2,0),camera.position,target):
			_officer_actors[index].visible = false
	var slot: int = 0
	for index in range(battle.count):
		if battle.states[index] == Battle.EnemyState.DEAD or battle.officers[index] or index in _near_ids:
			continue
		if blocks_camera(battle.positions[index] + Vector3(0,1.1,0),camera.position,target):
			var invisible := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),battle.positions[index])
			body.set_instance_transform(slot,invisible)
			left_leg.set_instance_transform(slot,invisible)
			right_leg.set_instance_transform(slot,invisible)
		slot += 1
