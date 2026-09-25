extends SceneTree
## Real Godot review: --weapon, --capture=/path.png, or --turntable --write-movie.
const Actor = preload("res://scripts/art/actor.gd")
const Hero = preload("res://assets/realism/vanguard.glb")
const Weapon = preload("res://assets/realism/polearm.glb")
const Lighting = preload("res://scripts/realism/lighting.gd")
var world: Node3D
var model: Node3D
var camera: Camera3D
var turntable: bool = false
var frame_index: int = 0
var ready_to_render: bool = false
var weapon: bool = false
var target: Vector3
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,960)
	root.msaa_3d=Viewport.MSAA_4X
	turntable="--turntable" in OS.get_cmdline_user_args()
	weapon="--weapon" in OS.get_cmdline_user_args()
	world=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Lighting.environment();env.environment.fog_enabled=false;world.add_child(env)
	world.add_child(Lighting.sun(true))
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-28,125,0);fill.light_energy=.42;fill.light_color=Color("b7c9e0");world.add_child(fill)
	var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor.mesh=plane;floor.position.y=-.06;floor.material_override=Lighting.ground();floor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(floor)
	if weapon:
		model=Weapon.instantiate() as Node3D;world.add_child(model);target=Vector3(0,1.70,0)
	else:
		model=Actor.new();world.add_child(model);model.build("vanguard",Hero);model.sample("Idle",.3,true);target=Vector3(0,1.65,0)
	camera=Camera3D.new();world.add_child(camera);camera.current=true
	camera.fov=43
	camera.position=Vector3(.28,1.78,2.0) if weapon else Vector3(2.6,2.0,4.2)
	if weapon:camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.3
	camera.look_at(target)
	for i in range(12):await process_frame
	ready_to_render=true
	if turntable:return
	await RenderingServer.frame_post_draw
	var path:String="user://realism-godot.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):path=arg.trim_prefix("--capture=")
	var error:Error=root.get_texture().get_image().save_png(path)
	assert(error==OK,"Could not save Godot review capture")
	print("SENJIN_REALISM_VISUAL_PASS ",RenderingServer.get_current_rendering_method())
	quit()
func _process(_delta: float) -> bool:
	if turntable and ready_to_render:
		frame_index+=1
		var angle:float=TAU*float(frame_index)/144.0
		var distance:float=2.0 if weapon else 4.9
		camera.position=target+Vector3(sin(angle)*distance,.45,cos(angle)*distance)
		camera.look_at(target)
		if not weapon:model.sample("Idle",float(frame_index)/24.0,true)
		if frame_index>=144:print("SENJIN_REALISM_TURNTABLE_PASS");quit()
	return false
