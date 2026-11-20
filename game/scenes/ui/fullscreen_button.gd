extends Button
## HUD full-screen button (top right, beside the orientation toggle; Daniele 2026-11-20: "add a full screen button in
## the interface to force full screen (vertical)"). Web only. Where the browser has the Fullscreen API (Android Chrome,
## desktop) a tap puts the page full screen and locks it to portrait where the browser allows. iPhone Safari has no
## Fullscreen API for pages: there the tap emits `hint` with "Add to Home Screen for full screen" (the home-screen app
## opens standalone, the manifest says portrait). Hidden off the web, when already full screen and when the game runs
## as the installed app (display-mode standalone).

signal hint(text: String)

const UI = preload("res://scripts/minigames/mg_ui.gd")
const U = preload("res://scripts/ui/ui_strings.gd")

const SIZE_DP := 44.0

## Browser state as JSON: standalone (installed app), fs (full screen now), api (Fullscreen API present), ios.
const JS_STATE := """JSON.stringify((function () {
	var d = document, el = d.documentElement, ua = navigator.userAgent || '';
	return {
		standalone: !!((window.matchMedia && matchMedia('(display-mode: standalone)').matches) || navigator.standalone),
		fs: !!(d.fullscreenElement || d.webkitFullscreenElement),
		api: !!(el.requestFullscreen || el.webkitRequestFullscreen) && !/iPhone|iPod/.test(ua),
		ios: /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1)
	};
})())"""
## Full screen, then portrait lock (both may be refused; the page then stays as it was).
const JS_GO := """(function () {
	var el = document.documentElement, rq = el.requestFullscreen || el.webkitRequestFullscreen;
	var lock = function () { try { if (screen.orientation && screen.orientation.lock) { screen.orientation.lock('portrait').catch(function () {}); } } catch (e) {} };
	try { var p = rq.call(el, { navigationUI: 'hide' }); if (p && p.then) { p.then(lock).catch(function () {}); } else { lock(); } } catch (e) {}
})()"""

var _state := {}
## Captures only (tests/capture_fullscreen.gd): show the button off the web, as a phone browser would.
static var force_show := false


func _ready() -> void:
	name = "FullscreenButton"
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(UI.dp(SIZE_DP), UI.dp(SIZE_DP))
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for st in ["normal", "hover", "pressed"]:
		add_theme_stylebox_override(st, UI.box(UI.BG_PLUM if st == "pressed" else Color(UI.BG_BASE, 0.85), SIZE_DP * 0.5, UI.LINE, 2.0))
	tooltip_text = U.t("ui.fullscreen.button")
	accessibility_name = tooltip_text
	pressed.connect(_on_pressed)
	get_viewport().size_changed.connect(refresh)
	refresh()


static func browser_state() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var s = JavaScriptBridge.eval(JS_STATE, true)
	var d = JSON.parse_string(s) if s is String else null
	return d if d is Dictionary else {}


## Shown on the web while the page is neither full screen nor the installed app.
func refresh() -> void:
	_state = browser_state()
	if force_show:
		visible = true
		return
	visible = not _state.is_empty() and not _state.get("standalone", false) and not _state.get("fs", false)


func _on_pressed() -> void:
	refresh()
	if _state.is_empty():
		return
	if _state.get("api", false):
		JavaScriptBridge.eval(JS_GO, true)
	else:
		hint.emit(U.t("ui.fullscreen.ios_hint"))


func _draw() -> void:
	# four corner brackets, the usual full-screen sign
	var c := size * 0.5
	var h := UI.dp(9)
	var l := UI.dp(5)
	var w := UI.dp(2)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var p := c + Vector2(sx * h, sy * h)
			draw_line(p, p - Vector2(sx * l, 0), UI.CREAM, w, true)
			draw_line(p, p - Vector2(0, sy * l), UI.CREAM, w, true)
	draw_circle(c, UI.dp(1.5), UI.GOLD)
