extends SceneTree
## Exercise the imported PBR rig and actual runtime override, not only raw glTF.
const Actor = preload("res://scripts/art/actor.gd")
const Hero = preload("res://assets/realism/vanguard.glb")
const Weapon = preload("res://assets/realism/polearm.glb")
const Arena = preload("res://scripts/realism/realism_arena.gd")
const Battle = preload("res://scripts/battle.gd")
const Moves = preload("res://scripts/move_data.gd")
var checks: int = 0
var errors: Array[String] = []
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors.append(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for packed in [Hero,Weapon]:
		var scene: Node = packed.instantiate()
		for node in scene.find_children("*","MeshInstance3D",true,false):
			var mesh: Mesh = node.mesh
			for surface in range(mesh.get_surface_count()):
				var mat: StandardMaterial3D = mesh.surface_get_material(surface)
				expect(mat.albedo_texture != null,"textured base color")
				expect(mat.normal_enabled and mat.normal_texture != null,"normal map enabled")
				expect(mat.metallic_texture != null and mat.roughness_texture != null,"separate metal/roughness values")
				expect(not mat.vertex_color_use_as_albedo,"no legacy paint override")
				expect(mat.roughness_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_GREEN,"ORM roughness green")
				expect(mat.metallic_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_BLUE,"ORM metallic blue")
				var arrays: Array = mesh.surface_get_arrays(surface)
				expect(arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"UV coverage")
				expect(arrays[Mesh.ARRAY_TANGENT].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"tangent frame coverage")
		scene.free()
	var actor: Node3D = Actor.new()
	root.add_child(actor)
	actor.build("vanguard",Hero)
	expect(actor.skeleton.get_bone_count()==18,"existing rig contract")
	expect(actor._names.size()==23,"all inherited clips retained")
	var moves: Dictionary = Moves.build()
	for clip in actor._names:
		var animation: Animation = actor.player.get_animation(actor._names[clip])
		if moves.has(clip): expect(absf(animation.length-float(moves[clip].frames)/60.0)<0.025,clip+" gameplay timing")
		for ratio in [0.0,.25,.5,.75,1.0]:
			actor.sample(clip,animation.length*ratio)
			var finite: bool = actor.trail_tip.global_position.is_finite()
			for bone in range(actor.skeleton.get_bone_count()): finite=finite and actor.skeleton.get_bone_pose(bone).is_finite()
			expect(finite,clip+" finite pose")
	actor.sample("Idle",0.0);actor.sample("Idle",.2)
	var bone_id: int = actor.skeleton.find_bone("head")
	var idle_right: Vector3 = actor.skeleton.get_bone_global_pose(bone_id).basis.x.normalized()
	actor.sample("Run",0.0);actor.sample("Run",.2)
	expect(idle_right.dot(actor.skeleton.get_bone_global_pose(bone_id).basis.x.normalized())>.95,"no head roll regression")
	actor.sample("n1",0.0);actor.sample("n1",.16)
	var socket: Vector3 = actor.trail_tip.global_position
	actor.sample("n1",.16)
	expect(socket.is_equal_approx(actor.trail_tip.global_position),"hitstop freezes trail")
	actor.free()
	expect(Arena.blocks_camera(Vector3(0,1.25,4),Vector3(0,1.25,8),Vector3(0,1.25,0)),"camera blocker is hidden")
	expect(not Arena.blocks_camera(Vector3(2,1.25,4),Vector3(0,1.25,8),Vector3(0,1.25,0)),"off-axis soldier remains visible")
	expect(not Arena.blocks_camera(Vector3(0,1.25,-2),Vector3(0,1.25,8),Vector3(0,1.25,0)),"enemy beyond hero remains visible")
	expect(not Arena.blocks_camera(Vector3(0,1.25,9),Vector3(0,1.25,8),Vector3(0,1.25,0)),"enemy behind camera is not hidden")
	var sim = Battle.new();sim.setup(96)
	var arena: Node3D = Arena.new();root.add_child(arena);arena.setup(sim,false)
	expect(arena.hero_actor.player != null,"default runtime has imported PBR hero")
	expect(arena.get_node("IronOathLighting").environment.ambient_light_source==Environment.AMBIENT_SOURCE_SKY,"sky-based material lighting")
	expect(not arena.get_node("IronOathLighting").environment.sdfgi_enabled,"no Forward+ GI requirement")
	for child in arena.get_children():
		if child is MeshInstance3D and child.mesh is PlaneMesh:
			expect(child.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"flat ground does not self-shadow")
	for frame in range(240):
		var actions: Array[String]=[]
		if frame%14==0: actions.append("attack")
		if frame==120: sim.hero_surge=100.0;actions.append("surge")
		sim.step(Vector2.ZERO,actions,0.0)
		var position: Vector3=sim.hero_position
		var hp: float=sim.hero_hp
		arena.update_view(1.0/60.0)
		if frame%30==0: expect(position==sim.hero_position and hp==sim.hero_hp,"visuals do not mutate simulation")
	arena.free()
	print("SENJIN_REALISM_TEST_RESULT ",JSON.stringify({"checks":checks,"errors":errors}))
	if errors.is_empty():print("SENJIN_REALISM_TESTS_PASS")
	quit(0 if errors.is_empty() else 1)
