extends RefCounted
const VERSION: int = 1
var path: String = "user://senjin.cfg"
var quality: int = 1
var sound: bool = true
var best_kos: int = 0
var best_combo: int = 0
var best_wave: int = 1

func load_profile() -> void:
	var cfg:=ConfigFile.new()
	if cfg.load(path)!=OK:
		return
	if int(cfg.get_value("meta","version",0))!=VERSION:
		return
	var value: Variant=cfg.get_value("settings","quality",1)
	if value is int:
		quality=clampi(value,0,2)
	value=cfg.get_value("settings","sound",true)
	if value is bool:
		sound=value
	for key in ["best_kos","best_combo","best_wave"]:
		value=cfg.get_value("records",key,0)
		if value is int:
			set(key,clampi(value,0,100000000))
	best_wave=maxi(1,best_wave)

func record(battle: RefCounted) -> void:
	best_kos=maxi(best_kos,battle.kos)
	best_combo=maxi(best_combo,battle.best_combo)
	best_wave=maxi(best_wave,battle.wave)

func save_profile() -> Error:
	var cfg:=ConfigFile.new()
	cfg.set_value("meta","version",VERSION)
	cfg.set_value("settings","quality",quality)
	cfg.set_value("settings","sound",sound)
	cfg.set_value("records","best_kos",best_kos)
	cfg.set_value("records","best_combo",best_combo)
	cfg.set_value("records","best_wave",best_wave)
	var temp_path:String=path+".tmp"
	var result:Error=cfg.save(temp_path)
	if result!=OK:
		return result
	# Write complete temporary file before replacing the previous save.
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path),ProjectSettings.globalize_path(path))

func enemy_count() -> int:
	return [96,180,300][clampi(quality,0,2)]
