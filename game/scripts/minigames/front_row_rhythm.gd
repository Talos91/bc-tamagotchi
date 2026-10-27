extends "res://scripts/minigames/minigame_base.gd"
## Front Row Rhythm (GDD section 9 #3, Stage, Music +8-12 per song). Two clap lanes scroll down to a hit
## line; tap the left or right half of the screen on the beat. Misses only lose the bonus.
##
## Beat map format (JSON, one file per song in scenes/minigames/front_row_rhythm/beatmaps/):
##   {"version":1,"id":"song_1","title_key":"...","bpm":104,"offset":0.0,"beats_per_bar":4,
##    "length_beats":96,"lanes":2,"notes":[[beat, lane], ...]}
## `beat` counts from the first downbeat after the 4-beat count-in; `lane` is 0 (left) or 1 (right).
## config: {"song": 0..3} picks the song (default: by day, so the 4-song loop rotates).

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const SONG_DIR := "res://scenes/minigames/front_row_rhythm/beatmaps/"
const SONGS := ["song_1", "song_2", "song_3", "song_4"]
const COUNT_IN_BEATS := 4
const PERFECT_WINDOW := 0.07
const GOOD_WINDOW := 0.14
const GOOD_WEIGHT := 0.6
const LEAD_SECONDS := 1.7  # time a note is visible before it reaches the line
const HIT_LINE := 0.72  # fraction of the play height

var song: Dictionary = {}
var notes: Array = []  # {time, lane, beat, state: 0 pending / 1 perfect / 2 good / 3 missed}
var clock := 0.0  # song time in seconds; starts negative (count-in)
var perfect := 0
var good := 0
var missed := 0
var combo := 0
var best_combo := 0
var _flash := [0.0, 0.0]
var _last_beat := -99
var _tick: AudioStreamPlayer
var _feedback := ""
var _feedback_t := 0.0


func _init() -> void:
	game_id = "front_row_rhythm"
	action_id = "front_row_rhythm"
	need_id = "music"
	title_key = "mg.front_row_rhythm.title"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_tick = AudioStreamPlayer.new()
	_tick.stream = _make_tick()
	_tick.volume_db = -14.0
	add_child(_tick)


# --- Beat map --------------------------------------------------------------------------------------

## Parses beat-map JSON text. Returns {ok, error, bpm, title_key, length_seconds, notes: [{time, lane, beat}]}.
static func parse_beatmap(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {"ok": false, "error": "invalid json"}
	var d: Dictionary = json.data
	for k in ["bpm", "lanes", "notes", "length_beats"]:
		if not d.has(k):
			return {"ok": false, "error": "missing " + k}
	var bpm := float(d["bpm"])
	var lanes := int(d["lanes"])
	if bpm <= 0.0 or lanes < 1 or not (d["notes"] is Array):
		return {"ok": false, "error": "bad bpm, lanes or notes"}
	var offset := float(d.get("offset", 0.0))
	var beat_len := 60.0 / bpm
	var out: Array = []
	for n in d["notes"]:
		if not (n is Array) or n.size() < 2:
			return {"ok": false, "error": "bad note entry"}
		var beat := float(n[0])
		var lane := int(n[1])
		if beat < 0.0 or beat > float(d["length_beats"]) or lane < 0 or lane >= lanes:
			return {"ok": false, "error": "note out of range"}
		out.append({"time": offset + beat * beat_len, "lane": lane, "beat": beat, "state": 0})
	out.sort_custom(func(a, b): return a["time"] < b["time"])
	return {"ok": true, "error": "", "id": str(d.get("id", "")), "title_key": str(d.get("title_key", "")),
		"bpm": bpm, "lanes": lanes, "offset": offset, "length_seconds": offset + float(d["length_beats"]) * beat_len,
		"notes": out}


static func load_song(song_id: String) -> Dictionary:
	var f := FileAccess.open(SONG_DIR + song_id + ".json", FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "missing file"}
	return parse_beatmap(f.get_as_text())


## Judgement for a tap `dt` seconds from a note's time: 1 perfect, 2 good, 0 no hit.
static func judge(dt: float, window_scale := 1.0) -> int:
	var a := absf(dt)
	if a <= PERFECT_WINDOW * window_scale:
		return 1
	if a <= GOOD_WINDOW * window_scale:
		return 2
	return 0


static func score_from(perfect_hits: int, good_hits: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return clampf((perfect_hits + GOOD_WEIGHT * good_hits) / float(total), 0.0, 1.0)


func current_score() -> float:
	var judged := 0
	for n in notes:
		if n["state"] != 0:
			judged += 1
	return score_from(perfect, good, notes.size()) if judged > 0 else 0.0


# --- Play ------------------------------------------------------------------------------------------

func _on_start() -> void:
	var idx: int = int(config.get("song", (Time.get_date_dict_from_system()["day"]) % SONGS.size()))
	song = load_song(SONGS[idx % SONGS.size()])
	notes = song.get("notes", []).duplicate(true) if song.get("ok", false) else []
	clock = -COUNT_IN_BEATS * 60.0 / float(song.get("bpm", 100.0))
	perfect = 0
	good = 0
	missed = 0
	combo = 0
	best_combo = 0
	_last_beat = -99
	_flash = [0.0, 0.0]
	set_status(S.t("mg.front_row_rhythm.status", {"combo": 0}))
	queue_redraw()


func _window_scale() -> float:
	return 1.5 if relaxed else 1.0


func tap(lane: int) -> void:
	if not running or paused:
		return
	_flash[lane] = 1.0
	var best_i := -1
	var best_dt := 99.0
	for i in notes.size():
		var n = notes[i]
		if n["state"] != 0 or n["lane"] != lane:
			continue
		var dt: float = clock - n["time"]
		if dt < -GOOD_WINDOW * _window_scale():
			break
		if absf(dt) < absf(best_dt):
			best_dt = dt
			best_i = i
	if best_i < 0:
		return
	var j := judge(best_dt, _window_scale())
	if j == 0:
		return
	notes[best_i]["state"] = j
	if j == 1:
		perfect += 1
	else:
		good += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	_feedback = S.t("mg.front_row_rhythm.hit_perfect" if j == 1 else "mg.front_row_rhythm.hit_good")
	_feedback_t = 0.5
	set_status(S.t("mg.front_row_rhythm.status", {"combo": combo}))


func advance(dt: float) -> void:
	clock += dt
	_flash[0] = maxf(0.0, _flash[0] - dt * 5.0)
	_flash[1] = maxf(0.0, _flash[1] - dt * 5.0)
	_feedback_t = maxf(0.0, _feedback_t - dt)
	var beat_len := 60.0 / float(song.get("bpm", 100.0))
	var beat_i := int(floor(clock / beat_len))
	if beat_i != _last_beat and is_inside_tree() and _tick != null and clock > -COUNT_IN_BEATS * beat_len - 0.01:
		_last_beat = beat_i
		_tick.play()
	var win := GOOD_WINDOW * _window_scale()
	for n in notes:
		if n["state"] == 0 and clock - n["time"] > win:
			n["state"] = 3
			missed += 1
			combo = 0
			set_status(S.t("mg.front_row_rhythm.status", {"combo": 0}))
	if clock > float(song.get("length_seconds", 0.0)) + 1.0 or notes.is_empty():
		finish(score_from(perfect, good, notes.size()))
	queue_redraw()


func _result_extra() -> Dictionary:
	return {"perfect": perfect, "good": good, "missed": missed, "best_combo": best_combo, "song": song.get("id", "")}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tap(0 if event.position.x < size.x * 0.5 else 1)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_A, KEY_LEFT]:
			tap(0)
		elif event.keycode in [KEY_D, KEY_RIGHT]:
			tap(1)


# --- Drawing ---------------------------------------------------------------------------------------

func _make_tick() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.04)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := int(sin(i * TAU * 1200.0 / rate) * 12000.0 * (1.0 - float(i) / n))
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func _draw() -> void:
	if size.x <= 0.0:
		return
	# Stage behind the lanes, dimmed to 40%.
	draw_rect(Rect2(Vector2.ZERO, size), Color(UI.BG_DEEP))
	draw_rect(Rect2(0, 0, size.x, size.y * 0.5), Color(UI.RED, 0.28))
	var line_y := size.y * HIT_LINE
	var lane_w := size.x * 0.5
	for l in 2:
		var x0 := l * lane_w
		draw_rect(Rect2(x0 + 24, 0, lane_w - 48, size.y), Color(UI.BG_BASE, 0.7))
		draw_rect(Rect2(x0 + 24, line_y - 6, lane_w - 48, 12), Color(UI.GOLD, 0.35 + 0.65 * _flash[l]))
		draw_circle(Vector2(x0 + lane_w * 0.5, line_y), 74.0, Color(UI.GOLD, 0.10 + 0.4 * _flash[l]))
		draw_arc(Vector2(x0 + lane_w * 0.5, line_y), 74.0, 0, TAU, 40, UI.GOLD, 4.0, true)
	var px_per_sec := line_y / LEAD_SECONDS
	for n in notes:
		if n["state"] != 0:
			continue
		var y: float = line_y - (n["time"] - clock) * px_per_sec
		if y < -80.0 or y > size.y + 80.0:
			continue
		var cx: float = n["lane"] * lane_w + lane_w * 0.5
		draw_circle(Vector2(cx, y), 58.0, UI.CREAM)
		draw_circle(Vector2(cx, y), 40.0, UI.BG_RAISED)
	if clock < 0.0:
		var beats_left := int(ceil(-clock / (60.0 / float(song.get("bpm", 100.0)))))
		UI.draw_text(self, str(beats_left), Vector2(size.x * 0.5, size.y * 0.4), 220, UI.CREAM)
	elif _feedback_t > 0.0:
		UI.draw_text(self, _feedback, Vector2(size.x * 0.5, line_y - 140), 64, UI.GOLD)
	UI.draw_text(self, S.t("mg.front_row_rhythm.hint"), Vector2(size.x * 0.5, size.y - 90), 40, UI.SMOKE)
