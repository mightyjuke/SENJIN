extends Node3D
const Battle=preload("res://scripts/battle.gd")
const Arena=preload("res://scripts/arena_view.gd")
const Controls=preload("res://scripts/input_router.gd")
const Hud=preload("res://scripts/hud.gd")
const Profile=preload("res://scripts/profile.gd")
const Sound=preload("res://scripts/audio.gd")
var battle=Battle.new()
var profile=Profile.new()
var controls:Node
var hud:Control
var arena:Node3D
var sound:Node
var _smoke:bool=false
var _capture:String=""
var _smoke_finishing:bool=false

func _ready() -> void:
	get_tree().auto_accept_quit=false
	_smoke="--smoke" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture=argument.trim_prefix("--capture=")
	profile.load_profile()
	controls=Controls.new()
	add_child(controls)
	sound=Sound.new()
	add_child(sound)
	sound.enabled=profile.sound
	var layer:=CanvasLayer.new()
	layer.layer=10
	add_child(layer)
	hud=Hud.new()
	layer.add_child(hud)
	hud.quality.select(profile.quality)
	hud.audio_toggle.set_pressed_no_signal(profile.sound)
	hud.resume_requested.connect(func():_pause(false))
	hud.restart_requested.connect(_restart)
	hud.quality_changed.connect(func(index:int):profile.quality=index;_save())
	hud.sound_changed.connect(func(enabled:bool):profile.sound=enabled;sound.enabled=enabled;sound.stop_all();_save())
	controls.pause_requested.connect(func():_pause(not get_tree().paused))
	_create_battle()
	_pause(not _smoke)

func _create_battle() -> void:
	battle=Battle.new()
	battle.setup(profile.enemy_count())
	arena=Arena.new()
	add_child(arena)
	arena.setup(battle,profile.quality>=2)
	sound.bind(battle)
	hud.bind(battle,controls)
	hud.best_kos=profile.best_kos

func _restart() -> void:
	_save()
	sound.stop_all()
	controls.clear()
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
	_create_battle()
	_pause(false)

func _pause(value:bool) -> void:
	if not is_instance_valid(controls):
		return
	if battle.game_over and not value:
		return
	controls.active=not value
	controls.clear()
	battle.clear_commands()
	get_tree().paused=value
	hud.set_paused(value)
	if value:
		sound.stop_all()
		_save()

func _save() -> void:
	if _smoke:
		return
	profile.record(battle)
	var result:Error=profile.save_profile()
	if result!=OK:
		push_warning("SENJIN settings could not be saved: %s" % error_string(result))
	if is_instance_valid(hud):
		hud.best_kos=profile.best_kos

func _physics_process(_delta:float) -> void:
	if not is_instance_valid(controls) or _smoke_finishing:
		return
	var command:Dictionary=controls.poll()
	arena.camera_yaw-=float(command.look.x)
	arena.camera_pitch=clampf(arena.camera_pitch+float(command.look.y),0.18,0.86)
	var actions:Array[String]=[]
	actions.assign(command.actions)
	var movement:Vector2=command.move
	if _smoke:
		movement=Vector2(0,-0.5) if battle.frame<100 else Vector2.ZERO
		if battle.frame%14==0:
			actions.append("attack")
		if battle.frame==120:
			battle.hero_surge=100.0
			actions.append("surge")
		if battle.frame==370:
			actions.append("jump")
		if battle.frame==380:
			actions.append("charge")
		battle.hero_hp=400.0
	battle.step(movement,actions,arena.camera_yaw)
	if battle.game_over:
		_pause(true)
	if _smoke and battle.frame>=480:
		_smoke_finishing=true
		_finish_smoke.call_deferred()

func _process(delta:float) -> void:
	if is_instance_valid(arena):
		arena.update_view(minf(delta,0.1))

func _finish_smoke() -> void:
	if not _capture.is_empty() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image:Image=get_viewport().get_texture().get_image()
		var result:Error=image.save_png(_capture)
		if result!=OK:
			push_error("Capture failed: "+error_string(result))
			get_tree().quit(1)
			return
	print("SENJIN_SMOKE_PASS ",JSON.stringify({"frames":battle.frame,"enemies":battle.count,"kos":battle.kos,"wave":battle.wave,"renderer":RenderingServer.get_current_rendering_method()}))
	get_tree().quit(0)

func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not _smoke:
			_pause(true)
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		_pause(true)
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()
