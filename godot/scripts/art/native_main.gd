extends "res://scripts/main.gd"
## Renderer seam: input, lifecycle, save data and combat remain in the shared native client.
const ArtArena = preload("res://scripts/art/authored_arena.gd")
func _create_battle() -> void:
	battle = Battle.new()
	battle.setup(profile.enemy_count())
	arena = ArtArena.new()
	add_child(arena)
	arena.setup(battle, profile.quality >= 2)
	sound.bind(battle)
	hud.bind(battle, controls)
	hud.best_kos = profile.best_kos
