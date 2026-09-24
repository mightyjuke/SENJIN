extends Control
signal resume_requested
signal restart_requested
signal quality_changed(index: int)
signal sound_changed(enabled: bool)
var battle: RefCounted
var router: Node
var best_kos: int = 0
var menu: PanelContainer
var heading: Label
var description: Label
var resume_button: Button
var quality: OptionButton
var audio_toggle: CheckButton
var _credits: AcceptDialog
var _safe: Rect2 = Rect2(0,0,1280,720)
var _hud_panel: StyleBoxFlat

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	theme=Theme.new()
	theme.default_font_size=20
	_build_menu()
	resized.connect(_layout)
	_layout()

func bind(sim: RefCounted, input_node: Node) -> void:
	battle=sim
	router=input_node
	_layout()

func _build_menu() -> void:
	menu=PanelContainer.new()
	menu.size=Vector2(670,590)
	add_child(menu)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.085,0.075,0.105,0.97)
	style.border_color=Color("ab6352")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left=28
	style.content_margin_right=28
	style.content_margin_top=22
	style.content_margin_bottom=22
	menu.add_theme_stylebox_override("panel",style)
	# A scroll boundary prevents wrapped labels from forcing a viewport-sized
	# menu to thousands of pixels tall during the initial zero-width layout.
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	menu.add_child(scroll)
	var column:=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)
	heading=Label.new()
	heading.text="SENJIN"
	heading.add_theme_font_size_override("font_size",42)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	description=Label.new()
	description.text="One vanguard. A battlefield to break.\nLeft thumb: move. Right side: look + combat.\nHold ATTACK to chain; tap CHARGE during a combo."
	description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	resume_button=_button(column,"ENTER BATTLE",func():resume_requested.emit())
	_button(column,"NEW BATTLE",func():restart_requested.emit())
	quality=OptionButton.new()
	quality.add_item("LOW  /  96 enemies")
	quality.add_item("BALANCED  /  180 enemies")
	quality.add_item("HIGH  /  300 enemies")
	quality.selected=1
	quality.custom_minimum_size.y=44
	quality.item_selected.connect(func(index:int):quality_changed.emit(index))
	column.add_child(quality)
	var note:=Label.new()
	note.text="Quality applies to the next battle. Device performance is not yet certified."
	note.add_theme_font_size_override("font_size",14)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	audio_toggle=CheckButton.new()
	audio_toggle.text="Sound"
	audio_toggle.button_pressed=true
	audio_toggle.toggled.connect(func(enabled:bool):sound_changed.emit(enabled))
	column.add_child(audio_toggle)
	_button(column,"OPEN SOURCE LICENSES",_show_licenses)
	var keys:=Label.new()
	keys.text="Desktop: WASD + J/K + Space + L + I  |  Q/E camera  |  Esc pause\nController: left stick / right stick + X/Y/A/RB/B"
	keys.add_theme_font_size_override("font_size",14)
	keys.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(keys)
	_credits=AcceptDialog.new()
	_credits.title="SENJIN — licenses and third-party notices"
	_credits.exclusive=true
	add_child(_credits)
	var text:=RichTextLabel.new()
	text.name="LicenseText"
	text.bbcode_enabled=false
	text.custom_minimum_size=Vector2(580,350)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits.add_child(text)

func _button(parent:Node,label:String,callback:Callable) -> Button:
	var button:=Button.new()
	button.text=label
	button.custom_minimum_size.y=44
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _show_licenses() -> void:
	var parts: Array[String]=[FileAccess.get_file_as_string("res://legal/NOTICE.txt"),Engine.get_license_text()]
	# Includes the engine's font and other bundled dependencies, not just its MIT notice.
	for item in Engine.get_copyright_info():
		parts.append(str(item))
	var licenses: Dictionary=Engine.get_license_info()
	for name in licenses:
		parts.append(str(name)+"\n"+str(licenses[name]))
	_credits.get_node("LicenseText").text="\n\n".join(parts)
	_credits.popup_centered(Vector2i(640,440))

func _layout() -> void:
	var viewport_size: Vector2=get_viewport_rect().size
	_safe=Rect2(Vector2(18,12),viewport_size-Vector2(36,24))
	if OS.has_feature("mobile"):
		var display: Rect2i=DisplayServer.get_display_safe_area()
		if display.size.x>0 and display.size.y>0:
			var inverse: Transform2D=get_viewport().get_screen_transform().affine_inverse()
			var local_start: Vector2=inverse*Vector2(display.position)
			var local_end: Vector2=inverse*Vector2(display.end)
			var native_safe:=Rect2(local_start,local_end-local_start).intersection(Rect2(Vector2.ZERO,viewport_size))
			if native_safe.size.x>0 and native_safe.size.y>0:
				_safe=native_safe.grow(-12)
	if is_instance_valid(router):
		router.set_layout(_safe)
	if is_instance_valid(menu):
		menu.size=Vector2(minf(670,_safe.size.x),minf(590,_safe.size.y))
		menu.position=_safe.get_center()-menu.size*0.5
	queue_redraw()

func set_paused(value: bool) -> void:
	menu.visible=value
	if value and battle!=null:
		heading.text="SENJIN" if not battle.game_over else "VANGUARD FALLEN"
		resume_button.text="ENTER BATTLE" if battle.frame==0 else "RESUME"
		resume_button.disabled=battle.game_over
		description.text="Wave %d  /  K.O. %d  /  Best %d\nHold ATTACK for combos; CHARGE branches into finishers.\nEvery full Surge segment unleashes a formation breaker." % [battle.wave,battle.kos,best_kos]
		_layout()

func _process(_delta:float) -> void:
	queue_redraw()

func _text(at:Vector2,text:String,size_px:int=20,color:Color=Color("f1dfc8")) -> void:
	draw_string(get_theme_default_font(),at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func _draw() -> void:
	if battle==null or router==null:
		return
	var start: Vector2=_safe.position
	var end: Vector2=_safe.end
	draw_style_box(_panel(),Rect2(start,Vector2(310,115)))
	_text(start+Vector2(14,29),"SENJIN  /  VANGUARD",22)
	var hp:=Rect2(start+Vector2(14,42),Vector2(280,13))
	draw_rect(hp,Color("35262a"))
	draw_rect(Rect2(hp.position,Vector2(hp.size.x*battle.hero_hp/400.0,hp.size.y)),Color("ce6652"))
	for i in range(4):
		var rect:=Rect2(start+Vector2(14+i*54,67),Vector2(48,10))
		draw_rect(rect,Color("443435"))
		draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(battle.hero_surge/25.0-i,0,1),10)),Color("dfb36e"))
	_text(start+Vector2(14,102),"SURGE READY" if battle.surge_ready() else "BUILD SURGE THROUGH COMBAT",14)
	_text(Vector2(_safe.get_center().x-100,start.y+30),"WAVE %d    K.O. %d" % [battle.wave,battle.kos],23)
	if battle.combo>1:
		_text(Vector2(_safe.get_center().x-70,start.y+61),"%d HIT CHAIN" % battle.combo,21,Color("dfad70"))
	var map_rect:=Rect2(Vector2(end.x-170,start.y+74),Vector2(150,150))
	draw_style_box(_panel(),map_rect)
	for i in range(battle.count):
		if battle.states[i]==4:
			continue
		var p: Vector3=battle.positions[i]
		var point: Vector2=map_rect.get_center()+Vector2(p.x,p.z)*1.5
		draw_circle(point,3.0 if battle.officers[i] else 1.3,Color("edbf76") if battle.officers[i] else Color("b64a43"))
	draw_circle(map_rect.get_center()+Vector2(battle.hero_position.x,battle.hero_position.z)*1.5,3.5,Color("f6efe3"))
	if battle.hero_state=="surge":
		_text(Vector2(_safe.get_center().x-112,start.y+104),"FORMATION BREAK",25,Color("ffd29a"))
	if router.show_touch and not menu.visible:
		draw_circle(router.stick_center,router.STICK_RADIUS,Color(0.08,0.07,0.10,0.40))
		draw_arc(router.stick_center,router.STICK_RADIUS,0,TAU,48,Color(0.9,0.76,0.65,0.5),2,true)
		draw_circle(router.stick_point,29,Color(0.87,0.73,0.60,0.60))
		for action in router.buttons:
			var p: Vector2=router.buttons[action]
			var r:float=26.0 if action=="pause" else router.ACTION_RADIUS
			draw_circle(p,r,Color(0.12,0.08,0.11,0.68))
			draw_arc(p,r,0,TAU,40,Color("bb8770"),2,true)
			var label:String="II" if action=="pause" else str(action).to_upper()
			var font_size:int=15 if action!="surge" else 16
			var width:float=get_theme_default_font().get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			_text(p+Vector2(-width*0.5,5),label,font_size)
	elif not menu.visible:
		_text(Vector2(start.x,end.y-15),"WASD move  /  J attack  K charge  Space jump  L dodge  I Surge  /  Esc pause",17)

func _panel() -> StyleBoxFlat:
	if _hud_panel==null:
		_hud_panel=StyleBoxFlat.new()
		_hud_panel.bg_color=Color(0.07,0.06,0.10,0.75)
		_hud_panel.set_corner_radius_all(8)
	return _hud_panel
