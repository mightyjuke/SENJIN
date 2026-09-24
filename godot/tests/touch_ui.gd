extends SceneTree
## GUI integration regression: menu touch support must not duplicate attacks.
const Controls = preload("res://scripts/input_router.gd")
const Hud = preload("res://scripts/hud.gd")
const Battle = preload("res://scripts/battle.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures.append(name)
		printerr("FAIL: " + name)

func _run() -> void:
	root.size = Vector2i(1280,720)
	Input.use_accumulated_input = false
	var controls = Controls.new()
	root.add_child(controls)
	controls.active = true
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	click.device = -1
	controls._input(click)
	check(controls.poll().actions.is_empty(), "emulated touch mouse cannot trigger gameplay attack")
	click.device = 0
	controls._input(click)
	check("attack" in controls.poll().actions, "real mouse retains attack control")
	controls.clear()
	check(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "native menu touch-to-mouse enabled")
	controls.active = false
	var sim = Battle.new()
	sim.setup(24)
	var ui = Hud.new()
	root.add_child(ui)
	ui.bind(sim,controls)
	ui.set_paused(true)
	var received: Dictionary = {"resume":false}
	ui.resume_requested.connect(func(): received.resume = true)
	for _i in range(5):
		await process_frame
	var center: Vector2 = ui.resume_button.get_global_rect().get_center()
	print("TOUCH_UI_GEOMETRY ", JSON.stringify({"viewport":str(root.get_visible_rect()),"menu":str(ui.menu.get_global_rect()),"button":str(ui.resume_button.get_global_rect()),"point":str(center)}))
	check(root.get_visible_rect().has_point(center), "resume button is on screen")
	var motion := InputEventMouseMotion.new()
	motion.device = -1
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	await process_frame
	click.device = -1
	click.position = center
	click.global_position = center
	Input.parse_input_event(click)
	await process_frame
	check(ui.resume_button.button_pressed, "menu button receives touch-emulated pointer down")
	var release := InputEventMouseButton.new()
	release.device = -1
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = center
	release.global_position = center
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	check(received.resume, "native menu accepts touch-emulated press and release")
	check(controls.poll().actions.is_empty(), "menu tap does not leak into gameplay queue")
	var workspace: String = OS.get_environment("GITHUB_WORKSPACE")
	if not workspace.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(workspace + "/artifacts/touch-menu.png")
	ui.queue_free()
	controls.queue_free()
	await process_frame
	print("SENJIN_TOUCH_UI_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty():
		print("SENJIN_TOUCH_UI_PASS")
	quit(0 if failures.is_empty() else 1)
