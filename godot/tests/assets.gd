extends SceneTree
## Asset contract and native visual-layer regression; no Blender installation required.
const Assets = preload("res://scripts/art/asset_library.gd")
const Actor = preload("res://scripts/art/actor.gd")
const Arena = preload("res://scripts/art/authored_arena.gd")
const Battle = preload("res://scripts/battle.gd")
const Moves = preload("res://scripts/move_data.gd")
var checks: int = 0
var failures: Array[String] = []
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/manifest.json"))
	expect(manifest.assets.size() == 21, "21 model exports")
	var total_bytes: int = 0
	for entry in manifest.assets:
		var id: String = entry.name
		var scene: Node = Assets.scene(id).instantiate()
		var meshes: Array[Node] = scene.find_children("*","MeshInstance3D",true,false)
		expect(meshes.size() == 1, id+": single draw surface mesh")
		var instance: MeshInstance3D = meshes[0] as MeshInstance3D
		var mesh: Mesh = instance.mesh
		expect(mesh.get_surface_count() == 1, id+": one material")
		var material: StandardMaterial3D = mesh.surface_get_material(0) as StandardMaterial3D
		expect(material != null and material.vertex_color_use_as_albedo and material.vertex_color_is_srgb, id+": linear glTF paint converted for both renderer families")
		var arrays: Array = mesh.surface_get_arrays(0)
		expect(arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size(), id+": vertex color coverage")
		var valid: bool = true
		for point in arrays[Mesh.ARRAY_VERTEX]: valid = valid and point.is_finite()
		expect(valid, id+": finite vertices")
		var bounds: AABB = mesh.get_aabb()
		expect(bounds.size.length() > 0.05 and bounds.size.length() < 30.0,id+": metre-scale bounds")
		expect(entry.triangles < (6000 if id in ["vanguard","officer"] else 4000), id+": triangle budget")
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		var raw: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/models/"+entry.file)
		hash.update(raw)
		expect(hash.finish().hex_encode() == entry.sha256, id+": committed export hash")
		total_bytes += raw.size()
		if not id in ["vanguard","soldier","officer"]:
			expect(Assets.mesh(id) != null,id+": transform-safe static batch")
		scene.free()
	expect(total_bytes < 8 * 1024 * 1024,"GLB pack under 8 MiB")
	var moves: Dictionary = Moves.build()
	for id in ["vanguard","soldier","officer"]:
		var actor: Node3D = Actor.new()
		root.add_child(actor)
		actor.build(id)
		expect(actor.skeleton.get_bone_count() == 18,id+": compact 18-bone rig")
		expect(actor._names.size() == 23,id+": 23 clips")
		for clip in actor._names:
			var animation: Animation = actor.player.get_animation(actor._names[clip])
			if moves.has(clip):
				expect(absf(animation.length-float(moves[clip].frames)/60.0)<0.025,id+":"+clip+": fixed 60Hz timing")
			var valid: bool = true
			for ratio in [0.0,0.25,0.5,0.75,1.0]:
				actor.sample(clip,animation.length*ratio,false)
				for bone in range(actor.skeleton.get_bone_count()):
					valid = valid and actor.skeleton.get_bone_pose(bone).is_finite()
				valid = valid and actor.trail_tip.global_position.is_finite()
			expect(valid,id+":"+clip+": finite pose and weapon sockets")
		actor.sample("n1",0.0)
		var initial: Vector3 = actor.trail_tip.global_position
		actor.sample("n1",0.16)
		expect(initial.distance_to(actor.trail_tip.global_position)>0.10,id+": weapon socket moves with clip")
		var socket: Vector3 = actor.trail_tip.global_position
		actor.sample("n1",0.16)
		expect(socket.is_equal_approx(actor.trail_tip.global_position),id+": hitstop freezes sampled pose")
		actor.sample("Idle",0.0)
		actor.sample("Idle",0.2)
		var head_bone: int = actor.skeleton.find_bone("head")
		var idle_right: Vector3 = actor.skeleton.get_bone_global_pose(head_bone).basis.x.normalized()
		actor.sample("Run",0.0)
		actor.sample("Run",0.2)
		var run_right: Vector3 = actor.skeleton.get_bone_global_pose(head_bone).basis.x.normalized()
		expect(idle_right.dot(run_right) > 0.95, id+": idle/run head roll remains continuous")
		actor.free()
	var sim = Battle.new()
	sim.setup(180)
	var view: Node3D = Arena.new()
	root.add_child(view)
	view.setup(sim,false)
	for frame in range(480):
		var actions: Array[String] = []
		if frame%14==0: actions.append("attack")
		if frame==120:
			sim.hero_surge=100.0
			actions.append("surge")
		sim.step(Vector2.ZERO,actions,0.0)
		var before: Vector3 = sim.hero_position
		var hp: float = sim.hero_hp
		view.update_view(1.0/60.0)
		if frame%60==0:
			expect(before==sim.hero_position and hp==sim.hero_hp,"render does not mutate battle")
			expect(view._near_ids.size()==8,"bounded nearby skeleton pool")
			var seen: Dictionary = {}
			var unique: bool = true
			for enemy in view._near_ids:
				if enemy>=0:
					unique=unique and not seen.has(enemy)
					seen[enemy]=true
			expect(unique,"nearby pool ownership unique")
			expect(view.body.visible_instance_count<=sim.count,"far crowd draw bound")
	view.free()
	Assets._meshes.clear()
	Assets._scenes.clear()
	print("SENJIN_ASSET_TEST_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"bytes":total_bytes}))
	if failures.is_empty(): print("SENJIN_ASSET_TESTS_PASS")
	quit(0 if failures.is_empty() else 1)
