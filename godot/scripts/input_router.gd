extends Node
## Same command stream for touch, keyboard and standard controllers.
## Touches have independent owners; releasing one finger cannot release another's action.
signal pause_requested
var active: bool = false
var show_touch: bool = false
var safe_rect: Rect2 = Rect2(0,0,1280,720)
var movement: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO
var stick_center: Vector2 = Vector2(140,560)
var stick_point: Vector2 = Vector2(140,560)
var buttons: Dictionary = {}
var _move_finger: int = -1
var _look_finger: int = -1
var _look_point: Vector2 = Vector2.ZERO
var _action_fingers: Dictionary = {}
var _held: Dictionary = {}
var _pending: Array[String] = []
var _repeat_frame: int = 0
const STICK_RADIUS: float = 76.0
const ACTION_RADIUS: float = 44.0
const KEYS: Dictionary = {KEY_J:"attack",KEY_K:"charge",KEY_SPACE:"jump",KEY_L:"dodge",KEY_SHIFT:"dodge",KEY_I:"surge"}
const PAD: Dictionary = {JOY_BUTTON_X:"attack",JOY_BUTTON_Y:"charge",JOY_BUTTON_A:"jump",JOY_BUTTON_B:"surge",JOY_BUTTON_RIGHT_SHOULDER:"dodge"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	show_touch = OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()
	Input.joy_connection_changed.connect(_controller_changed)
	set_layout(safe_rect)

func set_layout(rect: Rect2) -> void:
	if rect != safe_rect:
		clear()
	safe_rect = rect
	var end: Vector2 = rect.end
	stick_center = Vector2(rect.position.x + 132, end.y - 126)
	stick_point = stick_center
	buttons = {
		"attack":Vector2(end.x - 92,end.y - 130),
		"charge":Vector2(end.x - 192,end.y - 194),
		"dodge":Vector2(end.x - 196,end.y - 86),
		"jump":Vector2(end.x - 302,end.y - 100),
		"surge":Vector2(end.x - 90,end.y - 252),
		"pause":Vector2(end.x - 36,rect.position.y + 34)}

func clear() -> void:
	_move_finger = -1
	_look_finger = -1
	_action_fingers.clear()
	_held.clear()
	_pending.clear()
	movement = Vector2.ZERO
	look_delta = Vector2.ZERO
	stick_point = stick_center
	_repeat_frame = 0

func _controller_changed(_device: int, _connected: bool) -> void:
	clear()

func handle_touch(index: int, point: Vector2, pressed: bool) -> void:
	if not pressed:
		_action_fingers.erase(index)
		if index == _move_finger:
			_move_finger = -1
			movement = Vector2.ZERO
			stick_point = stick_center
		if index == _look_finger:
			_look_finger = -1
		return
	if not active or not safe_rect.has_point(point):
		return
	show_touch = true
	for action in buttons:
		var radius: float = 30.0 if action == "pause" else ACTION_RADIUS + 5.0
		if point.distance_to(buttons[action]) <= radius:
			if action == "pause":
				pause_requested.emit()
			else:
				_action_fingers[index] = action
				_pending.append(str(action))
			return
	if point.x < safe_rect.position.x + safe_rect.size.x * 0.43 and point.y > safe_rect.position.y + safe_rect.size.y * 0.38 and _move_finger == -1:
		_move_finger = index
		stick_center = point
		stick_point = point
	elif _look_finger == -1:
		_look_finger = index
		_look_point = point

func handle_drag(index: int, point: Vector2) -> void:
	if not active:
		return
	if index == _move_finger:
		var delta: Vector2 = (point - stick_center).limit_length(STICK_RADIUS)
		stick_point = stick_center + delta
		movement = delta / STICK_RADIUS
		if movement.length() < 0.12:
			movement = Vector2.ZERO
	elif index == _look_finger:
		look_delta += (point - _look_point) * 0.005
		_look_point = point

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		handle_touch(event.index,event.position,event.pressed and not event.canceled)
	elif event is InputEventScreenDrag:
		handle_drag(event.index,event.position)
	elif event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_ESCAPE and event.pressed:
			pause_requested.emit()
		elif active and KEYS.has(event.physical_keycode):
			_button("key_" + str(event.physical_keycode),str(KEYS[event.physical_keycode]),event.pressed)
	elif event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_START and event.pressed:
			pause_requested.emit()
		elif active and PAD.has(event.button_index):
			_button("pad_" + str(event.device) + "_" + str(event.button_index),str(PAD[event.button_index]),event.pressed)
	elif active and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_button("mouse_left","attack",event.pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_button("mouse_right","charge",event.pressed)
	elif active and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		look_delta += event.relative * 0.005

func _button(source: String, action: String, pressed: bool) -> void:
	if pressed:
		if not _held.has(source):
			_pending.append(action)
		_held[source] = action
	else:
		_held.erase(source)

func poll() -> Dictionary:
	var actions: Array[String] = []
	if not active:
		clear()
		return {"move":Vector2.ZERO,"look":Vector2.ZERO,"actions":actions}
	var keyboard := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var pad_move := Vector2.ZERO
	var pad_look := Vector2.ZERO
	var devices: Array[int] = Input.get_connected_joypads()
	if not devices.is_empty():
		var device: int = devices[0]
		pad_move = Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y))
		pad_look = Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y))
		if pad_move.length() < 0.18:
			pad_move = Vector2.ZERO
		if pad_look.length() < 0.18:
			pad_look = Vector2.ZERO
	var orbit: float = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	var look: Vector2 = look_delta + pad_look * 0.045 + Vector2(orbit * 0.035,0)
	look_delta = Vector2.ZERO
	actions.assign(_pending)
	_pending.clear()
	_repeat_frame += 1
	if _repeat_frame % 12 == 0 and ("attack" in _held.values() or "attack" in _action_fingers.values()) and not "attack" in actions:
		actions.append("attack")
	var result: Vector2 = movement if _move_finger >= 0 else (keyboard + pad_move).limit_length(1.0)
	return {"move":result,"look":look,"actions":actions}
