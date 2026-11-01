extends RefCounted
## Portrait / landscape (DECISIONS 2026-11-02: portrait first, landscape through a toggle at the top right of the
## HUD). Same mechanism as main.gd's F7 debug key: the window swaps width and height, and the canvas_items / expand
## stretch re-lays the UI; on a phone the screen orientation follows. Headless (tests) has no window, so the root
## viewport is resized instead. The choice lives in the save: Needs.ext["ui"]["orientation"].

const PORTRAIT := "portrait"
const LANDSCAPE := "landscape"
const EXT_KEY := "ui"


static func _root() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


## What the screen shows now (also after F7, which does not touch the save).
static func current() -> String:
	var r := _root()
	if r == null:
		return PORTRAIT
	var s := r.get_visible_rect().size
	return LANDSCAPE if s.x > s.y else PORTRAIT


static func saved(needs: Node) -> String:
	if needs == null:
		return ""
	return str(needs.ext.get(EXT_KEY, {}).get("orientation", ""))


static func apply(o: String) -> void:
	var land := o == LANDSCAPE
	if DisplayServer.get_name() == "headless":
		var r := _root()
		if r != null and current() != o:
			r.size = Vector2i(r.size.y, r.size.x) if r.size.x != r.size.y else Vector2i(1920, 1080) if land else Vector2i(1080, 1920)
		return
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE if land else DisplayServer.SCREEN_SENSOR_PORTRAIT)
		return
	var s := DisplayServer.window_get_size()
	if (s.x > s.y) != land:
		DisplayServer.window_set_size(Vector2i(s.y, s.x))


## Flips the orientation and remembers it in the save.
static func toggle(needs: Node) -> String:
	var o := PORTRAIT if current() == LANDSCAPE else LANDSCAPE
	apply(o)
	if needs != null:
		var ui: Dictionary = needs.ext.get(EXT_KEY, {})
		ui["orientation"] = o
		needs.ext[EXT_KEY] = ui
		if needs.autosave:
			needs.save_game()
	return o


## At boot: the saved choice, unless the command line sized the window (--resolution, screenshot mode) or there is
## no window. No saved choice means portrait, the project's window size.
static func restore(needs: Node) -> void:
	var o := saved(needs)
	if o == "" or DisplayServer.get_name() == "headless":
		return
	if "--resolution" in OS.get_cmdline_args():
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture"):
			return
	apply(o)
