extends Node3D
## Root of chars_showcase.tscn: every preset plays its idle (staggered so the room does not breathe in sync).

@export var animation := "idle"

func _ready() -> void:
	var i := 0
	for child in get_children():
		var player := BCChars.setup_animations(child)
		if player == null or not player.has_animation(animation):
			continue
		player.play(animation)
		player.seek(fmod(i * 0.37, player.current_animation_length), true)
		i += 1
