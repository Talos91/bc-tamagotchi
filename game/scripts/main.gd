extends Node3D
## Drops the player into the venue and wires the touch joystick.

func _ready() -> void:
	var player: Player = $Player
	player.joystick = $UI/Joystick
	# Needs debug HUD (NEEDS button / F1). Debug builds only; exported releases drop it.
	if not OS.is_debug_build():
		$UI/NeedsDebug.queue_free()
	if DisplayServer.get_name() == "headless":
		print("main ready: player at ", player.global_position)
