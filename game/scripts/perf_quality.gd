extends RefCounted
## Quality levels (perf-telemetry 2026-11-19, owner item 41). 2 = the look as designed. Lower levels exist for phones
## that cannot hold the frame rate; PerfTelemetry steps down one level at a time when the measured frame rate stays
## low in the venue (AUTO), never up by itself. The overlay (Debug > Performance) can set any level by hand.
##   2 full: as designed.
##   1 lighter: 3D drawn at SCALE_3D and stretched (the "3D 0.75" phone part, DECISIONS 2026-11-10).
##   0 lowest: also no key-light shadow map.
## Every level keeps the layout, the lights and the crowd; pictures on hub card perf-telemetry-review.

const SCALE_3D := 0.75
const NAMES := ["lowest", "lighter", "full"]

static var level := 2


static func apply_level(main: Node, l: int) -> void:
	level = clampi(l, 0, 2)
	if main == null or not is_instance_valid(main):
		return
	var vp := main.get_viewport()
	if vp:
		var phone_scale: bool = preload("res://scripts/phone_graphics.gd").on("scale")
		vp.scaling_3d_scale = SCALE_3D if (level <= 1 or phone_scale) else 1.0
	var key := main.get_node_or_null("Venue/KeyLight") as DirectionalLight3D
	if key:
		key.shadow_enabled = level >= 1
