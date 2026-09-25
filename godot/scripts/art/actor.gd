extends Node3D
## Sample baked Blender clips from simulation time. Animations never apply damage or root motion.
const Assets = preload("res://scripts/art/asset_library.gd")
var player: AnimationPlayer
var skeleton: Skeleton3D
var trail_base: Node3D
var trail_tip: Node3D
var _names: Dictionary = {}
var _current: String = ""
var _from: Array[Transform3D] = []
var _blend_elapsed: float = 1.0
var _blend_duration: float = 0.06
var _last_sample_time: float = 0.0

func build(asset_id: String) -> void:
	var model: Node3D = Assets.scene(asset_id).instantiate() as Node3D
	add_child(model)
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	assert(players.size() == 1 and skeletons.size() == 1, "Rig/animation contract failed: " + asset_id)
	player = players[0] as AnimationPlayer
	skeleton = skeletons[0] as Skeleton3D
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key in player.get_animation_list():
		var short_name: String = str(key).get_slice("/", str(key).get_slice_count("/") - 1)
		_names[short_name] = key
	trail_base = model.find_child("TrailBase", true, false) as Node3D
	trail_tip = model.find_child("TrailTip", true, false) as Node3D
	assert(trail_base != null and trail_tip != null, "Weapon trail sockets missing")
	if asset_id != "vanguard":
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_node: MeshInstance3D = child as MeshInstance3D
			var mat: StandardMaterial3D = mesh_node.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			mat.albedo_color = Color(1.15,0.68,0.57) if asset_id == "soldier" else Color(1.18,0.91,0.69)
			mesh_node.material_override = mat
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sample("Idle", 0.0)

func sample(clip: String, time: float, loop: bool = false) -> void:
	assert(_names.has(clip), "Missing required animation: " + clip)
	var key: String = str(_names[clip])
	if _current != key:
		_from.clear()
		if not _current.is_empty():
			for bone in range(skeleton.get_bone_count()):
				_from.append(skeleton.get_bone_pose(bone))
		_blend_duration = 0.10 if clip in ["Idle", "Run", "Jump"] else 0.05
		_blend_elapsed = _blend_duration if _current.is_empty() else 0.0
		_last_sample_time = time
		player.play(key)
		_current = key
	else:
		# Simulation-time delta freezes transitions during hitstop and pauses.
		_blend_elapsed += minf(absf(time - _last_sample_time), 0.1)
		_last_sample_time = time
	var length: float = player.get_animation(key).length
	var seek_time: float = fposmod(time, length) if loop and length > 0 else clampf(time, 0, length)
	player.seek(seek_time, true)
	if _blend_elapsed < _blend_duration and _from.size() == skeleton.get_bone_count():
		var weight: float = smoothstep(0.0, _blend_duration, _blend_elapsed)
		for bone in range(skeleton.get_bone_count()):
			skeleton.set_bone_pose(bone, _from[bone].interpolate_with(skeleton.get_bone_pose(bone), weight))
	skeleton.force_update_all_bone_transforms()
	# BoneAttachment notifications normally arrive after _process. Resolve the socket parent
	# now so the sampled blade and its trail use the same frame, including during hitstop.
	var binding: BoneAttachment3D = trail_tip.get_parent() as BoneAttachment3D
	if binding != null:
		binding.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(binding.get_bone_idx())
