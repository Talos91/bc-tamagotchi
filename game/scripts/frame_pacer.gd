extends Node
## Battery saver: frame pacing for phones (perf-iphone 2026-11-20; Daniele: "my whole phone overheat"). Autoload
## FramePacer. A phone browser draws every display refresh (60 a second, 120 on some), and the venue's frame is the
## expensive part; at 30 a second the phone does half the GPU work and stays cooler. The game keeps running every
## refresh (input, needs, the crowd's walk), only the drawing is skipped: RenderingServer.render_loop_enabled is
## switched off between the frames we draw, and the canvas keeps showing the last one (the engine's WebGL context
## preserves its drawing buffer).
##   - venue, start screen, menus: VENUE_FPS
##   - no touch for IDLE_S seconds: IDLE_FPS (a touch draws again at once)
##   - a minigame frame is open: no cap (timing games need every frame; the 3D venue is paused behind it, Q2)
## On by default for touch phones in the web build (the phone graphics parts are on: phone_graphics.gd), off on desktop,
## native and in tests. Debug > Performance > Battery saver switches it; `?saver=0` / `?saver=1` on the page URL too.

const PhoneGraphics = preload("res://scripts/phone_graphics.gd")

const VENUE_FPS := 30.0
const IDLE_FPS := 15.0
const IDLE_S := 20.0
const SLACK_S := 0.004   ## a refresh that comes slightly early still draws (60 Hz -> exactly every second one)

var saver := false
var _acc := 0.0
var _idle := 0.0
var _web := OS.has_feature("web")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100   # before the other nodes' _process, so the switch counts for this frame
	if _web:
		saver = not PhoneGraphics.parts().is_empty()
		var q = JavaScriptBridge.eval("(/[?&]saver=([01])/.exec(location.search) || [])[1] || ''", true)
		if q is String and q != "":
			saver = q == "1"


func set_saver(on: bool) -> void:
	saver = on
	if not on:
		RenderingServer.render_loop_enabled = true


## The frame rate drawn now (0 = every refresh).
func target_fps() -> float:
	if not saver or not _web:
		return 0.0
	var main := get_tree().current_scene
	if main != null and is_instance_valid(main.get("frame")):
		return 0.0
	return IDLE_FPS if _idle >= IDLE_S else VENUE_FPS


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventScreenDrag or e is InputEventMouseButton or e is InputEventKey:
		if _idle >= IDLE_S:
			_acc = 1.0   # draw the next frame at once
		_idle = 0.0


func _process(delta: float) -> void:
	_idle += delta
	var fps := target_fps()
	if fps <= 0.0:
		if not RenderingServer.render_loop_enabled:
			RenderingServer.render_loop_enabled = true
		_acc = 0.0
		return
	var r := pace(_acc, delta, fps)
	_acc = r.x
	RenderingServer.render_loop_enabled = r.y > 0.5


## One refresh: the time carried over and whether this refresh draws (y = 1).
static func pace(acc: float, delta: float, fps: float) -> Vector2:
	var period := 1.0 / fps
	acc += delta
	if acc >= period - SLACK_S:
		return Vector2(clampf(acc - period, 0.0, period), 1.0)
	return Vector2(acc, 0.0)


## One line for the perf report and the overlay.
func describe() -> String:
	if not saver:
		return "battery saver off"
	var fps := target_fps()
	return "battery saver on (%s)" % ("uncapped now" if fps <= 0.0 else "%d fps" % int(fps))
