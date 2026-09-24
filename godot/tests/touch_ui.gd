extends SceneTree
## GUI integration regression: enabling menu touch support must not duplicate attacks.
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
	var controls = Controls.new()
	root.add_child(controls)
	controls.active = true
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
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
	await process_frame
	await process_frame
	var center: Vector2 = ui.resume_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.device = -1
	motion.position = center
	root.push_input(motion,true)
	click.device = -1
	click.position = center
	click.global_position = center
	root.push_input(click,true)
	var release := InputEventMouseButton.new()
	release.device = -1
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = center
	release.global_position = center
	release.pressed = false
	root.push_input(release,true)
	await process_frame
	check(received.resume, "native menu accepts touch-emulated press and release")
	check(controls.poll().actions.is_empty(), "menu tap does not leak into gameplay queue")
	ui.queue_free()
	controls.queue_free()
	await process_frame
	print("SENJIN_TOUCH_UI_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty():
		print("SENJIN_TOUCH_UI_PASS")
	quit(0 if failures.is_empty() else 1)
