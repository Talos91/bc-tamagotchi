extends RefCounted
## The one place that builds the version string shown in the game ("v0.2.0 · 33dc5b9", plus " · dirty" when the build
## was stamped from a tree with uncommitted changes). The number is `application/config/version` in project.godot (the
## source of truth); the stamp is `res://build_info.json`, written by `python tools/version.py` and gitignored. Without
## the stamp (a plain checkout, an export that did not include it) the string is the version only. docs/tech/versioning.md.

const UI = preload("res://scripts/minigames/mg_ui.gd")

const STAMP_PATH := "res://build_info.json"
const SEP := " · "


## `MAJOR.MINOR.PATCH` from project.godot.
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## The build stamp ({"sha", "dirty", "date"}), or {} when there is none or it cannot be read.
static func build() -> Dictionary:
	if not FileAccess.file_exists(STAMP_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAMP_PATH))
	return parsed if parsed is Dictionary else {}


## "v0.2.0 · 33dc5b9", "v0.2.0 · 33dc5b9 · dirty", or "v0.2.0" without a stamp.
static func text() -> String:
	return compose(version(), build())


static func compose(ver: String, b: Dictionary) -> String:
	var s := "v" + ver
	var sha := str(b.get("sha", ""))
	if sha != "":
		s += SEP + sha
		if b.get("dirty", false):
			s += SEP + "dirty"
	return s


## The small dim label for a bottom corner (bottom right, clear of the zone prompt and the walk hints), named
## "VersionLabel". Lato from the project theme.
static func label() -> Label:
	var l := UI.label(text(), 9.0, Color(UI.ASH, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	l.name = "VersionLabel"
	l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_right = -UI.dp(8)
	l.offset_bottom = -UI.dp(6)
	return l
