extends Node
## Anonymous performance telemetry (perf-telemetry 2026-11-19, owner item 41: "we need telemetry a friend tried to play
## and game was lagging like crazy"). Autoload PerfTelemetry. Samples every frame's time and, once a second, the
## renderer's counters; keeps them per screen / venue area. Nothing is sent anywhere and nothing personal is read (no
## name, save or avatar): the player opens Debug > Performance (or the page with ?perf=1), sees a small overlay and
## taps "Copy perf report" to paste the text in a chat. A server beacon waits for Daniele (hub card telemetry-beacon).
##
## Report: version, device hints (user agent, pixel ratio, screen, cores, memory class, WebGL renderer), canvas,
## phone graphics parts, quality level and its changes, load time (page open -> engine up -> title shown), first
## entry (page open -> first venue frame), fps p50 / p5 overall and per area, frame spikes (> 50 / > 100 ms, worst
## and where), draw calls / objects / primitives (mean, max), video memory, static memory.
## Auto quality (AUTO): in the venue, when the frame rate's median stays under LOW_FPS for WINDOW_S seconds the quality
## drops one level (perf_quality.gd); never up by itself.

const Quality = preload("res://scripts/perf_quality.gd")
const AUTO := true
const LOW_FPS := 24.0
const WINDOW_S := 6.0
const KEEP := 1800                      ## frame times kept per area (most recent)

var frames := {}                        ## area -> Array of frame ms (ring of KEEP)
var _recent: Array = []                 ## the last 120 frames, for the overlay
var _ring_pos := {}
var all_ms := PackedFloat32Array()      ## every area, most recent KEEP * 2
var spikes50 := 0
var spikes100 := 0
var worst := 0.0
var worst_where := ""
var counters := {"draws": [0.0, 0.0], "objects": [0.0, 0.0], "prims": [0.0, 0.0], "vram": [0.0, 0.0]}   ## sum, max
var _counter_n := 0
var t_engine_ms := -1.0                 ## page open -> engine up (web), else 0
var t_title_ms := -1.0                  ## page open -> title shown
var t_entry_ms := -1.0                  ## page open -> first venue frame
var quality_log: Array[String] = []
var where := "loading"

var _last_us := 0
var _sec := 0.0
var _window: PackedFloat32Array = PackedFloat32Array()
var _window_t := 0.0
var _manual := false
var _web := OS.has_feature("web")
var _overlay: CanvasLayer
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	t_engine_ms = _page_ms()
	if _web and str(JavaScriptBridge.eval("/[?&]perf=1/.test(location.search)", true)) == "true":
		show_overlay.call_deferred(true)


## Milliseconds since the page opened (web: performance.now()), or since the engine started.
func _page_ms() -> float:
	if _web:
		var v = JavaScriptBridge.eval("performance.now()", true)
		if v is float or v is int:
			return float(v)
	return float(Time.get_ticks_msec())


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_us == 0:
		_last_us = now
		return
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	where = _where()
	if where == "loading":
		return
	if t_title_ms < 0.0 and where.begins_with("start"):
		t_title_ms = _page_ms()
	if t_entry_ms < 0.0 and where.begins_with("venue:"):
		t_entry_ms = _page_ms()
	_add(where, ms)
	if ms > 50.0:
		spikes50 += 1
	if ms > 100.0:
		spikes100 += 1
	if ms > worst:
		worst = ms
		worst_where = where
	_sec += ms / 1000.0
	if _sec >= 1.0:
		_sec = 0.0
		_sample_counters()
		if is_instance_valid(_label) and _overlay.visible:
			_label.text = overlay_text()
	_auto_quality(ms)


func _add(area: String, ms: float) -> void:
	if not frames.has(area):
		frames[area] = []
		_ring_pos[area] = 0
	var a: Array = frames[area]
	if a.size() < KEEP:
		a.append(ms)
	else:
		a[_ring_pos[area]] = ms
		_ring_pos[area] = (_ring_pos[area] + 1) % KEEP
	_recent.append(ms)
	if _recent.size() > 120:
		_recent.pop_front()
	all_ms.append(ms)
	if all_ms.size() > KEEP * 2:
		all_ms = all_ms.slice(KEEP)


func _sample_counters() -> void:
	_counter_n += 1
	var vals := {"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"vram": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0}
	for k in vals:
		counters[k][0] += vals[k]
		counters[k][1] = maxf(counters[k][1], vals[k])


## Where the player is: the same names as the page's context-loss banner (main.gd _mark_scene).
func _where() -> String:
	var main := get_tree().current_scene
	if main == null or not main.has_method("_mark_scene"):
		return "loading" if main == null else "other"
	if is_instance_valid(main.get("start_screen")):
		return "start"
	for k in ["creator", "frame", "menu_list"]:
		if is_instance_valid(main.get(k)):
			return {"creator": "creator", "frame": "minigame", "menu_list": "menu"}[k]
	var p = main.get("player")
	if p and p.get("rig"):
		return "venue:" + str(p.rig.zone)
	return "other"


func _auto_quality(ms: float) -> void:
	if not AUTO or _manual or Quality.level == 0 or not where.begins_with("venue:"):
		_window.clear()
		_window_t = 0.0
		return
	_window.append(ms)
	_window_t += ms / 1000.0
	if _window_t < WINDOW_S:
		return
	var med := _pct(_window, 0.5)
	_window.clear()
	_window_t = 0.0
	if med > 1000.0 / LOW_FPS:
		var from := Quality.level
		Quality.apply_level(get_tree().current_scene, from - 1)
		quality_log.append("auto %s->%s at %ds in %s (median %.0f ms)" % [Quality.NAMES[from], Quality.NAMES[Quality.level], int(_page_ms() / 1000.0), where, med])


func set_quality(l: int) -> void:
	_manual = true
	var from := Quality.level
	Quality.apply_level(get_tree().current_scene, l)
	quality_log.append("by hand %s->%s at %ds" % [Quality.NAMES[from], Quality.NAMES[Quality.level], int(_page_ms() / 1000.0)])


static func _pct(a, p: float) -> float:
	if a.is_empty():
		return 0.0
	var s: Array = Array(a).duplicate()
	s.sort()
	return s[clampi(int(p * (s.size() - 1)), 0, s.size() - 1)]


## "fps p50 / p5" of a frame-time list: the median frame and the slowest 5 %.
static func fps_text(a) -> String:
	if a.is_empty():
		return "-"
	return "%.0f / %.0f fps (%d frames)" % [1000.0 / maxf(_pct(a, 0.5), 0.1), 1000.0 / maxf(_pct(a, 0.95), 0.1), a.size()]


func device_text() -> String:
	var lines: Array[String] = []
	lines.append("renderer: %s | %s | %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), RenderingServer.get_current_rendering_method()])
	lines.append("os: %s, window %s, 3D scale %.2f" % [OS.get_name(), str(get_viewport().get_visible_rect().size) if get_viewport() else "?", get_viewport().scaling_3d_scale if get_viewport() else 1.0])
	if _web:
		var js = JavaScriptBridge.eval("""(function(){var c=document.querySelector('canvas'),g=null,r='';
try{g=c&&(c.getContext('webgl2'));var e=g&&g.getExtension('WEBGL_debug_renderer_info');r=e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):''}catch(x){}
var p=window.bcPhone;return JSON.stringify({ua:navigator.userAgent,dpr:window.devicePixelRatio,real:p&&p.real||'',
screen:screen.width+'x'+screen.height,canvas:c?c.width+'x'+c.height:'',cores:navigator.hardwareConcurrency||0,
mem:navigator.deviceMemory||0,gl:r,phone:p?Object.keys(p).filter(function(k){return p[k]===true}).join(','):'off'})})()""", true)
		var d = JSON.parse_string(str(js)) if js != null else null
		if d is Dictionary:
			lines.append("ua: " + str(d.ua))
			lines.append("gpu: %s | pixel ratio %s (real %s) | screen %s | canvas %s | cores %s | memory class %s GB | phone graphics %s" % [
				d.gl, str(d.dpr), str(d.real), d.screen, d.canvas, str(d.cores), str(d.mem), d.phone])
	return "\n".join(lines)


func report() -> String:
	var lines: Array[String] = ["Black Cabin perf report " + preload("res://scripts/version_info.gd").text()]
	lines.append(device_text())
	lines.append("quality: %s%s%s" % [Quality.NAMES[Quality.level], " (set by hand)" if _manual else "", ("; " + "; ".join(quality_log)) if not quality_log.is_empty() else ""])
	lines.append("load: engine up %s, title %s, first venue frame %s (ms after the page opened)" % [_ms(t_engine_ms), _ms(t_title_ms), _ms(t_entry_ms)])
	lines.append("fps p50 / p5, all: " + fps_text(all_ms))
	var keys := frames.keys()
	keys.sort()
	for k in keys:
		lines.append("  %s: %s" % [k, fps_text(frames[k])])
	lines.append("spikes: %d frames > 50 ms, %d > 100 ms, worst %.0f ms in %s" % [spikes50, spikes100, worst, worst_where])
	var n := maxf(_counter_n, 1)
	lines.append("draws mean %.0f max %.0f | objects mean %.0f max %.0f | primitives mean %.0fk max %.0fk | video %.0f MB (max %.0f) | static mem %.0f MB" % [
		counters.draws[0] / n, counters.draws[1], counters.objects[0] / n, counters.objects[1], counters.prims[0] / n / 1000.0,
		counters.prims[1] / 1000.0, counters.vram[0] / n, counters.vram[1], Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	return "\n".join(lines)


static func _ms(v: float) -> String:
	return "-" if v < 0.0 else "%.0f" % v


func overlay_text() -> String:
	return "%s | %s\n%d draws | quality %s | spikes %d" % [where, fps_text(_recent), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), Quality.NAMES[Quality.level], spikes50]


## Copies the report (web: the page's clipboard, inside the tap). Returns the text.
func copy_report() -> String:
	var r := report()
	DisplayServer.clipboard_set(r)
	return r


## The small overlay at the top: live fps, draws, quality, and its buttons (copy, quality, hide).
func show_overlay(v: bool) -> void:
	if v and not is_instance_valid(_overlay):
		_overlay = CanvasLayer.new()
		_overlay.layer = 120
		_overlay.name = "PerfOverlay"
		add_child(_overlay)
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.anchor_left = 0.0
		panel.anchor_right = 1.0
		panel.offset_left = 8
		panel.offset_right = -8
		panel.offset_top = 8
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.6)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", sb)
		_overlay.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		_label = Label.new()
		_label.add_theme_font_size_override("font_size", 22)
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(_label)
		var row := HBoxContainer.new()
		box.add_child(row)
		for b in [["Copy perf report", _on_copy], ["Quality", _on_quality], ["Hide", func(): show_overlay(false)]]:
			var btn := Button.new()
			btn.text = b[0]
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", 22)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.pressed.connect(b[1])
			row.add_child(btn)
		_label.text = overlay_text()
	if is_instance_valid(_overlay):
		_overlay.visible = v


func overlay_shown() -> bool:
	return is_instance_valid(_overlay) and _overlay.visible


func _on_copy() -> void:
	copy_report()
	_label.text = "Copied. Paste it in the chat.\n" + overlay_text()


func _on_quality() -> void:
	set_quality(Quality.level - 1 if Quality.level > 0 else 2)
	_label.text = overlay_text()
