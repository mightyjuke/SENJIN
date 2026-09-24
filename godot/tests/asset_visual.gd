extends SceneTree
const Actor = preload("res://scripts/art/actor.gd")
const Assets = preload("res://scripts/art/asset_library.gd")
var world: Node3D
var characters: Array[Node3D] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	world = Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("182331")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a5bfd1")
	env.ambient_light_energy = 0.45
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-25,0)
	sun.light_color = Color("ffe0ba")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30,145,0)
	fill.light_color = Color("81b5e0")
	fill.light_energy = 0.75
	world.add_child(fill)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor.mesh = plane
	floor.position.y = -0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("273343")
	floor.material_override = mat
	world.add_child(floor)
	for i in range(3):
		var actor: Node3D = Actor.new()
		world.add_child(actor)
		actor.build(["vanguard","soldier","officer"][i])
		actor.position.x = (i-1)*2.0
		actor.rotation.y = -0.30
		actor.sample("Idle",0.0,true)
		characters.append(actor)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(4.0,3.2,8.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.4
	camera.look_at(Vector3(0,1.2,0))
	camera.current = true
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	var output: String = "user://characters-godot.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): output = argument.trim_prefix("--capture=")
	var result: Error = root.get_texture().get_image().save_png(output)
	assert(result == OK, "Cannot write asset preview")
	print("SENJIN_ASSET_VISUAL_PASS")
	quit()
