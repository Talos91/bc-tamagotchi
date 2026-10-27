extends Node3D
## Drops the player into the venue and wires the touch joystick.

func _ready() -> void:
	var player: Player = $Player
	player.joystick = $UI/Joystick
	if DisplayServer.get_name() == "headless":
		print("main ready: player at ", player.global_position)
