extends Node
## Small procedurally generated PCM bank. No recordings or third-party music.
const RATE: int = 22050
var enabled: bool = true
var _bank: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _cursor: int = 0
var _last_impact_frame: int = -1

func _ready() -> void:
	_bank["swing"]=_sound(0.13,220.0,0.55,13)
	_bank["hit"]=_sound(0.15,95.0,0.75,22)
	_bank["heavy"]=_sound(0.28,60.0,0.5,34)
	_bank["jump"]=_sound(0.12,420.0,0.12,41)
	_bank["surge"]=_sound(0.7,165.0,0.2,57)
	for i in range(12):
		var player:=AudioStreamPlayer.new()
		player.volume_db=-16.0
		add_child(player)
		_voices.append(player)

func bind(battle:RefCounted) -> void:
	battle.action_started.connect(_action)
	battle.impact.connect(_impact)
	battle.hero_damaged.connect(func():play("heavy"))

func _sound(seconds:float,frequency:float,noise_mix:float,seed_value:int) -> AudioStreamWAV:
	var random:=RandomNumberGenerator.new()
	random.seed=seed_value
	var samples:int=int(seconds*RATE)
	var bytes:=PackedByteArray()
	bytes.resize(samples*2)
	for i in range(samples):
		var t:float=float(i)/RATE
		var envelope:float=pow(1.0-float(i)/samples,2.0)*minf(1.0,t*400.0)
		var tone:float=sin(TAU*frequency*t*(1.0-0.25*t/seconds))
		tone=tone*(1.0-noise_mix)+random.randf_range(-1,1)*noise_mix
		bytes.encode_s16(i*2,int(clampf(tone*envelope,-1,1)*24575.0))
	var sound:=AudioStreamWAV.new()
	sound.format=AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate=RATE
	sound.stereo=false
	sound.data=bytes
	return sound

func play(id:String) -> void:
	if not enabled or _voices.is_empty() or not _bank.has(id):
		return
	var voice:AudioStreamPlayer=_voices[_cursor%_voices.size()]
	_cursor+=1
	voice.stream=_bank[id]
	voice.play()

func stop_all() -> void:
	for voice in _voices:
		voice.stop()
		voice.stream=null

func _exit_tree() -> void:
	stop_all()
	_bank.clear()

func _action(id:String) -> void:
	if id in ["surge","surge_contact"]:
		play("surge")
	elif id=="surge_burst":
		play("heavy")
	elif id in ["jump","dodge"]:
		play("jump")
	else:
		play("swing")

func _impact(_at:Vector3,heavy:bool,_killed:bool) -> void:
	var tick:int=Engine.get_physics_frames()
	if tick==_last_impact_frame:
		return
	_last_impact_frame=tick
	play("heavy" if heavy else "hit")
