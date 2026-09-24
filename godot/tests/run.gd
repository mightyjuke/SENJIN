extends SceneTree
const Battle=preload("res://scripts/battle.gd")
const Moves=preload("res://scripts/move_data.gd")
const Controls=preload("res://scripts/input_router.gd")
const Profile=preload("res://scripts/profile.gd")
const Factory=preload("res://scripts/mesh_factory.gd")
var checks:int=0
var failures:Array[String]=[]

func _initialize() -> void:
	_run.call_deferred()

func check(condition:bool,label:String) -> void:
	checks+=1
	if not condition:
		failures.append(label)
		printerr("FAIL: "+label)

func fresh() -> RefCounted:
	var b=Battle.new()
	b.setup(24,77)
	for i in range(b.count):
		b.positions[i]=Vector3(200+i*3,0,200)
		b.health[i]=120
		b.timers[i]=10000
	b.rebuild_grid()
	return b

func advance(b:RefCounted,steps:int) -> void:
	var empty:Array[String]=[]
	for _i in range(steps):
		b.step(Vector2.ZERO,empty)

func _run() -> void:
	var data:Dictionary=Moves.build()
	check(data.size()==15,"all fifteen browser move types represented")
	for key in data:
		var m:Dictionary=data[key]
		check(int(m.cancel)<=int(m.frames),str(key)+": valid cancel window")
		for h in m.hits:
			check(int(h.first)<=int(h.last) and int(h.last)<int(m.frames),str(key)+": active frames within duration")
	var a=Battle.new()
	var b=Battle.new()
	a.setup(300,12)
	b.setup(300,12)
	check(a.positions==b.positions,"seeded wave spawn reproducible")
	var empty:Array[String]=[]
	for i in range(120):
		a.step(Vector2(0.2,-0.3),empty)
		b.step(Vector2(0.2,-0.3),empty)
	check(a.positions==b.positions and a.hero_position==b.hero_position,"fixed-step simulation reproducible")
	check(a.officers.count(1)==4,"four officers per wave")
	b=fresh()
	b.positions[0]=Vector3(0,0,-2)
	b.positions[1]=Vector3(0,0,2)
	b.rebuild_grid()
	var arc:Dictionary=Moves.hit(0,4,"arc",3,10,90)
	check(b.strike(arc,0,Vector3.ZERO,0)==1,"arc selects forward enemy only")
	check(b.health[0]==110 and b.health[1]==120,"arc excludes target behind hero")
	check(b.strike(arc,0,Vector3.ZERO,0)==0,"same window cannot double-hit")
	check(b.strike(arc,1,Vector3.ZERO,0)==1,"new window can hit same enemy")
	var line:Dictionary=Moves.hit(0,4,"line",4,10,180,3,0,0,false,1)
	b.positions[0]=Vector3(2,0,-2)
	b.positions[1]=Vector3(0,0,-3)
	b.rebuild_grid()
	check(b.strike(line,2,Vector3.ZERO,0)==1,"line respects lateral width")
	b=fresh()
	b.positions[0]=Vector3(0,0,-1)
	b.rebuild_grid()
	var repeated:Dictionary=Moves.hit(0,30,"circle",3,2,360,0,0,10)
	check(b.strike(repeated,0,Vector3.ZERO,0)==1,"multi-hit initial tick")
	b.frame+=9
	check(b.strike(repeated,0,Vector3.ZERO,0)==0,"multi-hit cannot fire before interval")
	b.frame+=1
	check(b.strike(repeated,0,Vector3.ZERO,0)==1,"multi-hit fires on interval")
	b=fresh()
	b.positions[0]=Vector3(0,0,-1)
	b.health[0]=1
	b.rebuild_grid()
	check(b.strike(arc,0,Vector3.ZERO,0)==1 and b.kos==1 and b.alive==23,"KO counters update exactly once")
	check(b.strike(arc,1,Vector3.ZERO,0)==0 and b.kos==1,"dead enemies cannot be re-killed")
	b=fresh()
	var attack:Array[String]=["attack"]
	var charge:Array[String]=["charge"]
	b._start_move("n1")
	b.move_frame=22
	b.step(Vector2.ZERO,attack)
	check(b.move_id=="n2","normal input branches to next combo move")
	b._start_move("n1")
	b.move_frame=10
	b.step(Vector2.ZERO,charge)
	check(b.move_id=="c2","charge input branches after normal hit")
	for id in data:
		b=fresh()
		if id in ["jatk","jc"]:
			b.hero_position.y=2.0
		b._start_move(str(id))
		advance(b,260)
		check(b.hero_state!="attack",str(id)+": completes without an infinite animation/landing hold")
	b=fresh()
	var dodge:Array[String]=["dodge"]
	b.step(Vector2.RIGHT,dodge)
	b.damage_hero(100)
	check(b.hero_hp==400,"dodge invulnerability")
	advance(b,40)
	b.damage_hero(100)
	check(b.hero_hp==300,"invulnerability ends")
	b=fresh()
	var jump:Array[String]=["jump"]
	b.step(Vector2.ZERO,jump)
	check(b.hero_position.y>0,"jump leaves ground")
	advance(b,120)
	check(is_zero_approx(b.hero_position.y),"jump lands on arena floor")
	b=fresh()
	b.hero_hp=100000
	for i in range(700):
		b.step(Vector2.RIGHT,empty)
	check(Vector2(b.hero_position.x,b.hero_position.z).length()<=43.001,"arena boundary constrains player")
	b=fresh()
	var surge:Array[String]=["surge"]
	b.hero_surge=24.0
	b.step(Vector2.ZERO,surge)
	check(b.hero_state!="surge","Surge rejects insufficient meter")
	b.hero_surge=25.0
	b.step(Vector2.ZERO,surge)
	check(b.hero_state=="surge" and b.hero_surge==0.0,"one Surge consumes one of four segments")
	b.damage_hero(100)
	check(b.hero_hp==400,"Surge invulnerability")
	advance(b,220)
	check(b.hero_state=="idle","Surge returns control")
	b=fresh()
	b.alive=0
	for i in range(b.count):
		b.states[i]=Battle.EnemyState.DEAD
	advance(b,181)
	check(b.wave==2 and b.alive==b.count,"reinforcement wave after intermission")
	b=fresh()
	b.damage_hero(1000)
	advance(b,1)
	check(b.game_over,"zero health triggers defeat")
	var tick:int=b.frame
	advance(b,10)
	check(b.frame==tick,"defeated simulation stops")

	var controls=Controls.new()
	root.add_child(controls)
	controls.active=true
	controls.set_layout(Rect2(40,20,1200,670))
	controls.handle_touch(0,Vector2(140,540),true)
	controls.handle_drag(0,Vector2(190,540))
	controls.handle_touch(1,controls.buttons.attack,true)
	controls.handle_touch(2,Vector2(700,300),true)
	controls.handle_drag(2,Vector2(730,310))
	var command:Dictionary=controls.poll()
	check(command.move.x>0.5 and "attack" in command.actions and command.look.x>0,"move + attack + look simultaneously")
	controls.handle_touch(1,Vector2.ZERO,false)
	check(controls.poll().move.x>0.5,"releasing attack preserves movement finger")
	controls.handle_touch(0,Vector2.ZERO,false)
	check(controls.poll().move==Vector2.ZERO,"releasing movement clears joystick")
	controls.handle_touch(3,controls.buttons.attack,true)
	controls.clear()
	check(controls.poll().actions.is_empty(),"pause/focus loss clears held and pending input")
	for key in controls.buttons:
		check(controls.safe_rect.has_point(controls.buttons[key]),str(key)+": button lies inside safe area")
	controls.queue_free()

	var profile=Profile.new()
	profile.path="user://senjin-regression.cfg"
	profile.quality=2
	profile.best_kos=314
	profile.sound=false
	check(profile.save_profile()==OK,"profile save succeeds")
	var loaded=Profile.new()
	loaded.path=profile.path
	loaded.load_profile()
	check(loaded.quality==2 and loaded.best_kos==314 and not loaded.sound,"profile round trip")
	var malformed:=ConfigFile.new()
	malformed.set_value("meta","version",1)
	malformed.set_value("settings","quality",100)
	malformed.set_value("records","best_kos","not a number")
	malformed.save(profile.path)
	loaded=Profile.new()
	loaded.path=profile.path
	loaded.load_profile()
	check(loaded.quality==2 and loaded.best_kos==0,"profile clamps invalid values")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile.path))
	check(Factory.soldier().get_surface_count()==1,"soldier uses one batched mesh surface")
	check(Factory.leg().get_surface_count()==1,"leg mesh builds")
	var presets:=ConfigFile.new()
	check(presets.load("res://export_presets.cfg")==OK,"export configuration parses")
	check(presets.get_value("preset.0","platform","")=="Android","Android debug preset")
	check(presets.get_value("preset.1.options","gradle_build/export_format",-1)==1,"Android store preset uses AAB")
	check(presets.get_value("preset.2","platform","")=="iOS","iOS preset")
	check(FileAccess.file_exists("res://legal/NOTICE.txt"),"attribution bundled in native project")
	await process_frame
	print("SENJIN_TEST_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty():
		print("SENJIN_TESTS_PASS")
	quit(0 if failures.is_empty() else 1)
