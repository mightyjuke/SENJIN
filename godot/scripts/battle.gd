extends RefCounted
## Pure fixed-step simulation: no scene tree, rendering, platform or input dependencies.
## Derived from the MIT SENJIN browser implementation; see legal/NOTICE.txt.
const Moves = preload("res://scripts/move_data.gd")
const DT: float = 1.0 / 60.0
const ARENA_RADIUS: float = 43.0
const CELL_SIZE: float = 4.0
const MAX_ATTACKERS: int = 4
const OFFICER_NAMES: Array[String] = ["KUROGANE", "RAIDO", "BYAKUREN", "GENMA"]
enum EnemyState { APPROACH, WINDUP, RECOVER, STUN, DEAD }

signal impact(at: Vector3, heavy: bool, killed: bool)
signal action_started(id: String)
signal wave_started(number: int)
signal hero_damaged

var moves: Dictionary = Moves.build()
var hero_position: Vector3 = Vector3.ZERO
var hero_yaw: float = 0.0
var hero_hp: float = 400.0
var hero_surge: float = 0.0
var hero_state: String = "idle"
var hero_vertical: float = 0.0
var hero_speed: float = 0.0
var move_id: String = ""
var move_frame: int = 0
var surge_frame: int = 0
var state_frame: int = 0
var frame: int = 0
var wave: int = 1
var kos: int = 0
var combo: int = 0
var best_combo: int = 0
var alive: int = 0
var game_over: bool = false
var positions: PackedVector3Array = PackedVector3Array()
var velocities: PackedVector3Array = PackedVector3Array()
var health: PackedFloat32Array = PackedFloat32Array()
var facings: PackedFloat32Array = PackedFloat32Array()
var timers: PackedInt32Array = PackedInt32Array()
var states: PackedInt32Array = PackedInt32Array()
var officers: PackedByteArray = PackedByteArray()
var count: int = 0
var _seed: int = 2026
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _grid: Dictionary = {}
var _seen: Dictionary = {}
var _stopped_windows: Dictionary = {}
var _buffer: String = ""
var _buffer_ttl: int = 0
var _iframes: int = 0
var _hitstop: int = 0
var _last_hit: int = -1000
var _run_frames: int = 0
var _air_chain: int = 0
var _wave_wait: int = 0
var _dodge_direction: Vector3 = Vector3.FORWARD
var _surge_origin: Vector3 = Vector3.ZERO
var _surge_yaw: float = 0.0

func setup(enemy_count: int = 180, seed_value: int = 2026) -> void:
	count = clampi(enemy_count, 24, 1000)
	_seed = seed_value
	_rng.seed = _seed
	frame = 0
	wave = 1
	kos = 0
	combo = 0
	best_combo = 0
	hero_position = Vector3.ZERO
	hero_yaw = 0.0
	hero_hp = 400.0
	hero_surge = 0.0
	hero_vertical = 0.0
	hero_speed = 0.0
	hero_state = "idle"
	move_id = ""
	move_frame = 0
	surge_frame = 0
	state_frame = 0
	game_over = false
	_iframes = 0
	_hitstop = 0
	_last_hit = -1000
	_run_frames = 0
	_air_chain = 0
	_wave_wait = 0
	clear_commands()
	positions.resize(count)
	velocities.resize(count)
	health.resize(count)
	facings.resize(count)
	timers.resize(count)
	states.resize(count)
	officers.resize(count)
	_spawn_wave()

func clear_commands() -> void:
	_buffer = ""
	_buffer_ttl = 0

func forward() -> Vector3:
	return Vector3(-sin(hero_yaw), 0.0, -cos(hero_yaw))

func surge_ready() -> bool:
	return hero_surge >= Moves.SURGE_COST and hero_position.y <= 0.001 and hero_state != "surge" and not game_over

func query(center: Vector3, radius: float) -> Array[int]:
	var found: Array[int] = []
	var lo: Vector2i = _cell(center - Vector3(radius, 0, radius))
	var hi: Vector2i = _cell(center + Vector3(radius, 0, radius))
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var key: Vector2i = Vector2i(x, z)
			if _grid.has(key):
				for value in _grid[key]:
					found.append(int(value))
	return found

func rebuild_grid() -> void:
	_grid.clear()
	for i in range(count):
		if states[i] == EnemyState.DEAD:
			continue
		var key: Vector2i = _cell(positions[i])
		if not _grid.has(key):
			_grid[key] = []
		_grid[key].append(i)

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL_SIZE), floori(p.z / CELL_SIZE))

func _spawn_wave() -> void:
	alive = count
	for i in range(count):
		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(9.0, 38.0)
		positions[i] = Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
		velocities[i] = Vector3.ZERO
		officers[i] = 1 if i >= count - 4 else 0
		health[i] = (180.0 if officers[i] else 36.0) * (1.0 + 0.12 * (wave - 1))
		facings[i] = angle
		states[i] = EnemyState.APPROACH
		timers[i] = _rng.randi_range(30, 180)
	rebuild_grid()
	wave_started.emit(wave)

func step(movement: Vector2, actions: Array[String], camera_yaw: float = 0.0) -> void:
	if game_over:
		return
	frame += 1
	_iframes = maxi(0, _iframes - 1)
	_buffer_ttl = maxi(0, _buffer_ttl - 1)
	if _buffer_ttl == 0:
		_buffer = ""
	if frame - _last_hit > 150:
		combo = 0
	var direction: Vector3 = Vector3(movement.x, 0, movement.y).rotated(Vector3.UP, camera_yaw)
	direction = direction.limit_length(1.0)
	for action in actions:
		if action in ["attack", "charge", "dodge"]:
			_buffer = action
			_buffer_ttl = 18
		elif action == "jump" and hero_position.y <= 0.001 and hero_state in ["idle", "move"]:
			hero_vertical = 12.6
			hero_position.y = 0.01
			action_started.emit("jump")
		elif action == "surge" and surge_ready() and hero_state != "hurt":
			_start_surge()
	rebuild_grid()
	_tick_hero(direction)
	_tick_enemies()
	if hero_hp <= 0.0:
		game_over = true
		hero_state = "defeated"
		clear_commands()
	if alive == 0:
		_wave_wait += 1
		if _wave_wait >= 180:
			wave += 1
			_wave_wait = 0
			hero_hp = minf(400.0, hero_hp + 80.0)
			_spawn_wave()

func _tick_hero(direction: Vector3) -> void:
	if _hitstop > 0:
		_hitstop -= 1
		return
	state_frame += 1
	if hero_state == "surge":
		_tick_surge(direction)
		_clamp_hero()
		return
	if hero_state == "hurt":
		_gravity()
		if state_frame >= 20:
			hero_state = "idle"
		return
	if _buffer == "dodge" and hero_position.y <= 0.001 and hero_state != "dodge":
		var permitted: bool = hero_state != "attack" or move_frame >= int(moves[move_id].get("dodge", 99))
		if permitted:
			_dodge_direction = direction.normalized() if direction.length_squared() > 0.01 else forward()
			hero_state = "dodge"
			state_frame = 0
			_iframes = 16
			move_id = ""
			clear_commands()
			action_started.emit("dodge")
	if hero_state == "dodge":
		hero_position += _dodge_direction * (4.6 / 24.0)
		if state_frame >= 24:
			hero_state = "idle"
		_clamp_hero()
		return
	if hero_state == "attack":
		_tick_attack()
	else:
		_run_frames = _run_frames + 1 if direction.length_squared() > 0.2 else 0
		hero_speed = direction.length() * 8.5
		if hero_speed > 0.01:
			hero_yaw = lerp_angle(hero_yaw, atan2(-direction.x, -direction.z), 0.45)
			hero_position += direction * 8.5 * DT
			hero_state = "move"
		else:
			hero_state = "idle"
		if _buffer in ["attack", "charge"]:
			var next: String = "n1" if _buffer == "attack" else "c1"
			if hero_position.y > 0.001:
				next = "jatk" if _buffer == "attack" else "jc"
			elif _buffer == "attack" and _run_frames >= 14:
				next = "dash"
			_start_move(next)
	_gravity()
	_clamp_hero()

func _start_move(id: String) -> void:
	if id == "jatk":
		if _air_chain >= Moves.AIR_CHAIN_MAX:
			clear_commands()
			return
		_air_chain += 1
		if hero_vertical < 0.0:
			hero_vertical = 1.5
	hero_state = "attack"
	move_id = id
	move_frame = 0
	state_frame = 0
	_seen.clear()
	_stopped_windows.clear()
	clear_commands()
	action_started.emit(id)

func _tick_attack() -> void:
	var m: Dictionary = moves[move_id]
	move_frame += 1
	if m.has("hang") and move_frame == int(m.hang[0]) and hero_vertical > 0.0:
		move_frame -= 1
	if m.has("land") and move_frame >= int(m.land) and hero_position.y > 0.001:
		move_frame = int(m.land) - 1
	if m.has("leap") and move_frame == int(m.leap[0]):
		hero_vertical = float(m.leap[1])
		hero_position.y = maxf(hero_position.y, 0.01)
	if m.has("plunge") and move_frame == int(m.plunge[0]):
		hero_vertical = float(m.plunge[1])
	if m.has("hang") and move_frame >= int(m.hang[0]) and move_frame < int(m.hang[1]):
		hero_vertical = 0.0
	for lunge in m.get("lunge", []):
		if move_frame >= int(lunge[0]) and move_frame < int(lunge[1]):
			hero_position += forward() * float(lunge[2]) / maxf(1.0, float(lunge[1]) - float(lunge[0]))
	var windows: Array = m.hits
	for w in range(windows.size()):
		var h: Dictionary = windows[w]
		if move_frame >= int(h.first) and move_frame <= int(h.last):
			var hits: int = strike(h, w, hero_position, hero_yaw)
			if hits > 0 and not _stopped_windows.has(w):
				_hitstop = int(h.hitstop)
				_stopped_windows[w] = true
	if _buffer in ["attack", "charge"]:
		var threshold: int = int(m.get("branch", m.cancel)) if _buffer == "charge" else int(m.cancel)
		if move_frame >= threshold:
			var next: String = str(m.get("charge", "c1")) if _buffer == "charge" else str(m.get("next", "n1"))
			if hero_position.y > 0.001 and not bool(m.get("air", false)):
				next = "jc" if _buffer == "charge" else "jatk"
			_start_move(next)
			return
	if move_frame >= int(m.frames):
		hero_state = "idle"
		move_id = ""

func _gravity() -> void:
	var hang: bool = false
	if hero_state == "attack" and moves[move_id].has("hang"):
		var span: Array = moves[move_id].hang
		hang = move_frame >= int(span[0]) and move_frame < int(span[1])
	if not hang:
		hero_vertical -= 28.0 * DT
	hero_position.y += hero_vertical * DT
	if hero_position.y <= 0.0:
		hero_position.y = 0.0
		hero_vertical = 0.0
		_air_chain = 0
		if move_id == "jatk":
			hero_state = "idle"
			move_id = ""

func _clamp_hero() -> void:
	var flat: Vector2 = Vector2(hero_position.x, hero_position.z).limit_length(ARENA_RADIUS)
	hero_position.x = flat.x
	hero_position.z = flat.y

func _start_surge() -> void:
	hero_surge = maxf(0.0, hero_surge - Moves.SURGE_COST)
	hero_state = "surge"
	surge_frame = 0
	move_id = ""
	_iframes = Moves.SURGE_END + 12
	_seen.clear()
	clear_commands()
	action_started.emit("surge")

func _tick_surge(direction: Vector3) -> void:
	surge_frame += 1
	if surge_frame >= 100 and surge_frame < Moves.SURGE_CONTACT:
		if direction.length_squared() > 0.01:
			hero_yaw = lerp_angle(hero_yaw, atan2(-direction.x, -direction.z), 0.06)
		hero_position += forward() * 10.0 * DT
	if surge_frame == Moves.SURGE_CONTACT:
		_sur ge_placeholder()
	if surge_frame > Moves.SURGE_CONTACT and surge_frame < Moves.SURGE_FINISHER:
		hero_position += forward() * (2.4 / 44.0)
		if surge_frame % 6 == 0:
			var offset: float = float(surge_frame - Moves.SURGE_CONTACT) / 44.0
			var center: Vector3 = _surge_origin + Vector3(-sin(_surge_yaw), 0, -cos(_surge_yaw)) * (3.0 + offset * 9.0)
			strike(Moves.hit(0,0,"circle",3.0,12,360,5,5,1,true,2,0,6), 100 + surge_frame, center, _surge_yaw)
	if surge_frame == Moves.SURGE_FINISHER:
		strike(Moves.hit(0,0,"circle",12.0,60,360,12,9,0,true,2,0,8), 999, hero_position, hero_yaw)
		action_started.emit("surge_burst")
	if surge_frame >= Moves.SURGE_END:
		hero_state = "idle"
		surge_frame = 0

func _surge_contact() -> void:
	_sur ge_noop()

## Public hit resolution is also used by regression tests; caller supplies one window ID per attack.
func strike(h: Dictionary, window: int, origin: Vector3, yaw: float) -> int:
	var reach: float = float(h.range) + 0.4
	var hits: int = 0
	var direction: Vector3 = Vector3(-sin(yaw), 0, -cos(yaw))
	for i in query(origin, reach + float(h.get("width", 0))):
		if states[i] == EnemyState.DEAD:
			continue
		var delta: Vector3 = positions[i] - origin
		if absf(delta.y) > float(h.height):
			continue
		delta.y = 0.0
		var distance: float = delta.length()
		if h.shape == "line":
			var along: float = delta.dot(direction)
			var side: float = absf(delta.dot(direction.cross(Vector3.UP)))
			if along < -0.4 or along > reach or side > float(h.width) * 0.5 + 0.4:
				continue
		else:
			if distance > reach:
				continue
			if h.shape == "arc" and distance > 0.01:
				var aim: Vector3 = direction.rotated(Vector3.UP, deg_to_rad(float(h.direction)))
				if delta.normalized().dot(aim) < cos(deg_to_rad(float(h.angle)) * 0.5):
					continue
		var key: Vector2i = Vector2i(window, i)
		if _seen.has(key):
			if int(h.every) <= 0 or frame - int(_seen[key]) < int(h.every):
				continue
		_seen[key] = frame
		health[i] -= float(h.damage)
		var push: Vector3 = delta.normalized() if distance > 0.01 else direction
		velocities[i] = push * float(h.force) * (0.55 if officers[i] else 1.0)
		velocities[i].y = float(h.lift) * (0.65 if officers[i] else 1.0)
		states[i] = EnemyState.STUN
		timers[i] = 24 if bool(h.heavy) else 12
		var killed: bool = health[i] <= 0.0
		if killed:
			states[i] = EnemyState.DEAD
			alive -= 1
			kos += 1
		combo += 1
		best_combo = maxi(best_combo, combo)
		_last_hit = frame
		if hero_state != "surge":
			hero_surge = minf(100.0, hero_surge + (2.0 if killed else 0.65))
		impact.emit(positions[i] + Vector3.UP, bool(h.heavy), killed)
		hits += 1
	return hits

func damage_hero(amount: float, officer: bool = false) -> void:
	if _iframes > 0 or game_over or hero_hp <= 0.0:
		return
	hero_hp = maxf(0.0, hero_hp - amount)
	hero_surge = minf(100.0, hero_surge + amount * 0.15)
	_iframes = 22
	var armor: bool = hero_state == "attack" and (not officer or bool(moves[move_id].get("armor", false)))
	if not armor:
		hero_state = "hurt"
		state_frame = 0
		move_id = ""
	hero_damaged.emit()

func _tick_enemies() -> void:
	var attackers: int = 0
	for state in states:
		if state == EnemyState.WINDUP:
			attackers += 1
	for i in range(count):
		if states[i] == EnemyState.DEAD:
			continue
		timers[i] = maxi(0, timers[i] - 1)
		var p: Vector3 = positions[i]
		var v: Vector3 = velocities[i]
		if states[i] == EnemyState.STUN or p.y > 0.01:
			p += v * DT
			v.y -= 24.0 * DT
			v.x *= 0.94
			v.z *= 0.94
			if p.y <= 0.0:
				p.y = 0.0
				v.y = 0.0
				if timers[i] == 0:
					states[i] = EnemyState.RECOVER
					timers[i] = 30
			positions[i] = p
			velocities[i] = v
			continue
		var delta: Vector3 = hero_position - p
		delta.y = 0
		var distance: float = delta.length()
		if states[i] == EnemyState.WINDUP:
			if timers[i] == 0:
				if distance < 2.1 and hero_position.y < 1.4:
					damage_hero(18.0 if officers[i] else 7.0, officers[i] != 0)
				states[i] = EnemyState.RECOVER
				timers[i] = 75 if officers[i] else 110
			continue
		if states[i] == EnemyState.RECOVER and timers[i] == 0:
			states[i] = EnemyState.APPROACH
		if distance > 0.001:
			facings[i] = atan2(-delta.x, -delta.z)
		if states[i] == EnemyState.APPROACH and distance < 1.8 and timers[i] == 0 and attackers < MAX_ATTACKERS:
			states[i] = EnemyState.WINDUP
			timers[i] = 32 if officers[i] else 44
			attackers += 1
			continue
		# Spread steering work over three ticks. Movement remains at 60 Hz.
		if (frame + i) % 3 == 0:
			v = delta.normalized() * (3.4 if officers[i] else 2.5) if distance > 1.4 else Vector3.ZERO
			for j in query(p, 1.3):
				if j == i or states[j] == EnemyState.DEAD:
					continue
				var separation: Vector3 = p - positions[j]
				separation.y = 0.0
				var d2: float = separation.length_squared()
				if d2 > 0.0001 and d2 < 1.2:
					v += separation / d2 * 0.5
			v = v.limit_length(4.0)
			velocities[i] = v
		p += v * DT
		var flat: Vector2 = Vector2(p.x, p.z).limit_length(ARENA_RADIUS + 1.0)
		positions[i] = Vector3(flat.x, maxf(0.0, p.y), flat.y)
