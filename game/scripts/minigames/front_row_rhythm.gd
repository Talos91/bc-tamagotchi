extends "res://scripts/minigames/minigame_base.gd"
## Front Row Rhythm (GDD section 9 #3, Stage, Music +12-18). Two clap lanes scroll down to a hit line; tap the left or
## right half of the screen on the beat (two fingers when two claps arrive together).
##
## Endless set (docs/design/15-minigame-ramp.md; Daniele 2026-11-20: "the clap game should have double taps and 2 taps
## at the same time and after a few lost taps a loss (3 taps missed)"): no song end. The chart is fully generated,
## seeded per night (config "seed", default Rivals.night(), so everyone plays the same set tonight), in chunks of
## 8 bars (32 beats) kept one chunk ahead of the clock; judged notes far behind are dropped. Tempo 96 BPM, +4 BPM
## every 8 bars up to 152 BPM (bar 113, about 3m45s in); the clock maps beats to seconds through the accumulated tempo
## segments (beat_time / time_to_beat). Stages by bar: 1-8 quarter notes one lane at a time; from 9 "both" chords
## (two lanes at once); from 17 double taps (one lane, half a beat apart); from 25 eighth-note runs swapping lanes;
## after that all of them mixed, denser each step up to the cap. Notes fall faster (lead 1.7 s -> 1.2 s at the cap).
## Hit windows unchanged (+-0.07 perfect, +-0.14 good; relaxed x1.5). A note that passes the line unhit is a missed
## clap = a strike; the 3rd ends the round (lose()). Points: perfect 2, good 1 (uncapped record; 100 = a full old
## song). Level = 1 + tempo steps (15 at 152 BPM).
##
## Beat map format (JSON, one file per song in scenes/minigames/front_row_rhythm/beatmaps/), kept for the tests and the
## old songs (the endless set does not read them; config "song" is ignored now):
##   {"version":1,"id":"song_1","title_key":"...","bpm":104,"offset":0.0,"beats_per_bar":4,
##    "length_beats":96,"lanes":2,"notes":[[beat, lane], ...]}
## `beat` counts from the first downbeat after the 4-beat count-in; `lane` is 0 (left) or 1 (right).

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")

## Look B sprites (game/assets/minigames/README.md), the section 2.3 beats through mg_fx (clap squash, white flash and
## combo on a perfect, the puck dims on a miss, NO shake) and section 4.1 competition through mg_rivals (job Q9).
## Relaxed timing is as built (windows x1.5) at every tempo. Payouts unchanged (the need gain reads the first 100).
const ART_DIR := "res://assets/minigames/front_row_rhythm/"
const ART_NEEDED := ["clap", "puck", "target", "band_jo", "band_pete", "backdrop"]
const HIT_FADE := 0.35  # a judged puck blooms and fades over this long
const MISS_FADE := 0.55
const CLAP_SECONDS := 0.2

const SONG_DIR := "res://scenes/minigames/front_row_rhythm/beatmaps/"
const SONGS := ["song_1", "song_2", "song_3", "song_4"]
const COUNT_IN_BEATS := 4
const PERFECT_WINDOW := 0.07
const GOOD_WINDOW := 0.14
const GOOD_WEIGHT := 0.6
const HIT_LINE := 0.72  # fraction of the play height

## The endless ramp (docs/design/15-minigame-ramp.md, Daniele 2026-11-20).
const BASE_BPM := 96.0          ## why: a calm opening, slower than every old song (104-120)
const RAMP_BPM_STEP := 4.0      ## why: +4 BPM per 8 bars is felt but never a jump
const BPM_CAP := 152.0          ## why: eighths at 152 = 5 taps a second over two thumbs, humanly playable
const CHUNK_BEATS := 32         ## why: one tempo step = 8 bars of 4 beats = one generated chunk
const LEAD_START := 1.7         ## why: seconds a note is visible before the line at 96 BPM (the old songs' lead)
const LEAD_CAP := 1.2           ## why: notes fall faster with the tempo, still 3 beats of preview at 152 BPM
const LEVEL_CAP := 15           ## why: 1 + 14 tempo steps (96 -> 152 BPM)
const STAGE_CHORDS := 1         ## why: chunk index (bar 9) where "both" chords start
const STAGE_DOUBLES := 2        ## why: bar 17, double taps (same lane, half a beat apart)
const STAGE_RUNS := 3           ## why: bar 25, eighth-note runs swapping lanes; after it everything mixes
const DROP_AFTER := 2.0         ## why: judged notes this many seconds behind the clock are dropped (fades are over)
const POINTS_PERFECT := 2       ## why: 50 perfect claps = 100 = a full old song
const POINTS_GOOD := 1
const CELL_SINGLE := 0
const CELL_CHORD := 1
const CELL_DOUBLE := 2
const CELL_RUN := 3

var night_seed := 0             # the chart's seed (tonight's set)
var notes: Array = []  # {time, lane, beat, state: 0 pending / 1 perfect / 2 good / 3 missed}; sorted by time
var next_chunk := 0             # the next 8-bar chunk to generate
var tempo_step := 0             # tempo steps taken (0 = 96 BPM)
var bpm := BASE_BPM             # the tempo now
var lives_left := STRIKES
var clock := 0.0  # set time in seconds; starts negative (count-in)
var perfect := 0
var good := 0
var missed := 0
var combo := 0
var best_combo := 0
var _lane_frame := [-1, -1]     # the process frame of each lane's last input tap (drops mouse/touch twins)
var _flash := [0.0, 0.0]
var _last_beat := -99
var _tick: AudioStreamPlayer
var _feedback := ""
var _feedback_t := 0.0
var rival: Dictionary = {}  # tonight's regular to beat {regular, name, points}
var rival_passed := false
var rivals_store: Object = null  # tests: where mg_rivals keeps tonight's record (default Needs, else memory)
var _record: Dictionary = {}
var _art: Dictionary = {}  # sprite name -> {tex, glow, fw, fh, frames, anchor}
var _glow_layer: Control
var _clap_t := [9.0, 9.0]  # seconds since each lane's tap
var _beat_t := 9.0  # seconds since the last beat (the band's frame 1)


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


## Accuracy 0..1 of a set of judged claps (a good counts GOOD_WEIGHT). Sent as extra.accuracy.
static func score_from(perfect_hits: int, good_hits: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return clampf((perfect_hits + GOOD_WEIGHT * good_hits) / float(total), 0.0, 1.0)


## Uncapped record points: perfect 2, good 1.
static func points_of(perfect_hits: int, good_hits: int) -> int:
	return perfect_hits * POINTS_PERFECT + good_hits * POINTS_GOOD


func record_points() -> int:
	return points_of(perfect, good)


func current_score() -> float:
	return score_of(float(record_points()))


# --- Endless ramp ----------------------------------------------------------------------------------

## Tempo steps from 96 to the cap (14).
static func step_count() -> int:
	return int((BPM_CAP - BASE_BPM) / RAMP_BPM_STEP)


## BPM of tempo step `step` (step k = bars 8k+1 .. 8k+8).
static func bpm_at(step: int) -> float:
	return minf(BASE_BPM + RAMP_BPM_STEP * float(maxi(0, step)), BPM_CAP)


## Seconds a note falls before it reaches the line at tempo step `step` (1.7 -> 1.2 by the cap).
static func lead_at(step: int) -> float:
	return lerpf(LEAD_START, LEAD_CAP, clampf(float(step) / float(step_count()), 0.0, 1.0))


## The ramp level at tempo step `step`.
static func level_at(step: int) -> int:
	return mini(1 + maxi(0, step), LEVEL_CAP)


## Seconds one 8-bar step lasts.
static func step_seconds(step: int) -> float:
	return float(CHUNK_BEATS) * 60.0 / bpm_at(step)


## Set time (seconds) of a beat through the accumulated tempo segments. Negative beats are the count-in at 96 BPM.
static func beat_time(beat: float) -> float:
	if beat < 0.0:
		return beat * 60.0 / BASE_BPM
	var t := 0.0
	var k := 0
	while beat >= float(CHUNK_BEATS * (k + 1)):
		t += step_seconds(k)
		k += 1
	return t + (beat - float(CHUNK_BEATS * k)) * 60.0 / bpm_at(k)


## The beat (fractional) at set time `t`: the inverse of beat_time.
static func time_to_beat(t: float) -> float:
	if t < 0.0:
		return t * BASE_BPM / 60.0
	var acc := 0.0
	var k := 0
	while acc + step_seconds(k) <= t:
		acc += step_seconds(k)
		k += 1
	return float(CHUNK_BEATS * k) + (t - acc) * bpm_at(k) / 60.0


## The tempo step playing at set time `t` (0 during the count-in).
static func step_at_time(t: float) -> int:
	return maxi(0, int(floor(time_to_beat(t) / float(CHUNK_BEATS))))


## The chance of each cell [single, chord, double, run] on a beat of chunk `step` (the stages by bar). After the runs
## stage the singles give way to two-note cells until the cap (density rises from 1.6 to 1.85 claps a beat).
static func cell_weights(step: int) -> PackedFloat32Array:
	if step < STAGE_CHORDS:
		return PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	if step < STAGE_DOUBLES:
		return PackedFloat32Array([0.75, 0.25, 0.0, 0.0])
	if step < STAGE_RUNS:
		return PackedFloat32Array([0.55, 0.2, 0.25, 0.0])
	var d := clampf(float(step - STAGE_RUNS) / float(step_count() - STAGE_RUNS), 0.0, 1.0)
	return PackedFloat32Array([0.4 - 0.25 * d, 0.15 + 0.07 * d, 0.2 + 0.08 * d, 0.25 + 0.1 * d])


static func _pick_cell(rng: RandomNumberGenerator, w: PackedFloat32Array) -> int:
	var total := 0.0
	for x in w:
		total += x
	var r := rng.randf() * total
	for i in w.size():
		if r < w[i]:
			return i
		r -= w[i]
	return CELL_SINGLE


static func _note(beat: float, lane: int) -> Dictionary:
	return {"time": beat_time(beat), "lane": lane, "beat": beat, "state": 0}


## The notes of 8-bar chunk `step` for chart seed `seed_value`, sorted by time (deterministic). Same-lane notes are
## never closer than half a beat.
static func chunk_notes(step: int, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("frr:%d:%d" % [seed_value, step])
	var w := cell_weights(step)
	var out: Array[Dictionary] = []
	var lane := rng.randi_range(0, 1)
	var b := 0
	while b < CHUNK_BEATS:
		var beat := float(step * CHUNK_BEATS + b)
		var cell := _pick_cell(rng, w)
		if cell == CELL_RUN and b + 1 >= CHUNK_BEATS:
			cell = CELL_SINGLE
		if cell == CELL_CHORD:
			out.append(_note(beat, 0))
			out.append(_note(beat, 1))
		elif cell == CELL_DOUBLE:
			lane = rng.randi_range(0, 1)
			out.append(_note(beat, lane))
			out.append(_note(beat + 0.5, lane))
		elif cell == CELL_RUN:
			lane = 1 - lane
			for i in 4:
				out.append(_note(beat + 0.5 * float(i), lane if i % 2 == 0 else 1 - lane))
			lane = 1 - lane  # the run ended on the other lane
			b += 1
		else:
			if rng.randf() < 0.6:
				lane = 1 - lane
			out.append(_note(beat, lane))
		b += 1
	return out


# --- Play ------------------------------------------------------------------------------------------

func _on_start() -> void:
	night_seed = int(config.get("seed", Rivals.night()))
	notes = []
	next_chunk = 0
	tempo_step = 0
	bpm = BASE_BPM
	lives_left = STRIKES
	clock = -float(COUNT_IN_BEATS) * 60.0 / BASE_BPM
	perfect = 0
	good = 0
	missed = 0
	combo = 0
	best_combo = 0
	_last_beat = -99
	_flash = [0.0, 0.0]
	_clap_t = [9.0, 9.0]
	_beat_t = 9.0
	_lane_frame = [-1, -1]
	_ensure_chunks()
	var t := Rivals.tonight(game_id, rivals_store)
	rival = t["rival"]
	rival_passed = false
	_record = {}
	_load_art()
	_ensure_glow_layer()
	_update_status()
	queue_redraw()


func _update_status() -> void:
	set_status(S.t("mg.ramp.status", {"level": ramp_level, "points": record_points(), "lives": lives_left}))


## Keeps the chart one 8-bar chunk ahead of the clock.
func _ensure_chunks() -> void:
	while next_chunk <= step_at_time(clock) + 1:
		notes.append_array(chunk_notes(next_chunk, night_seed))
		next_chunk += 1


## The tempo steps up every 8 bars: a faster tick, faster notes, a LEVEL pop.
func _ramp_to(s: int) -> void:
	if s <= tempo_step:
		return
	tempo_step = s
	bpm = bpm_at(s)
	level_up(level_at(s))
	_update_status()


func _window_scale() -> float:
	return 1.5 if relaxed else 1.0


## A clap in `lane`: judges the nearest unjudged note of that lane (so a chord takes two taps, one per lane, and a
## double tap's second note waits for the second tap).
func tap(lane: int) -> void:
	if not running or paused or lane < 0 or lane > 1:
		return
	_flash[lane] = 1.0
	_clap_t[lane] = 0.0
	fx().squash("clap%d" % lane)
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
	notes[best_i]["t_hit"] = clock
	if j == 1:
		perfect += 1
	else:
		good += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	_feedback = S.t("mg.front_row_rhythm.hit_perfect" if j == 1 else "mg.front_row_rhythm.hit_good")
	_feedback_t = 0.5
	_update_status()
	_hit_beat(lane, j)


## Section 2.3: perfect = white flash on the puck, a flare and the combo; good = a smaller pop. No shake, no hit-stop
## (either would break the rhythm).
func _hit_beat(lane: int, j: int) -> void:
	var f := fx()
	var p := _lane_pos(lane)
	f.flash("lane%d" % lane)
	if j == 1:
		f.pop(S.t("mg.front_row_rhythm.hit_perfect"), p + Vector2(0, -150.0 * _sc()), UI.GOLD, 60)
		f.flare(p, 150.0 * _sc(), Color(1, 1, 1, 0.9))
		f.burst("spark", p, 10)
	else:
		f.pop(S.t("mg.front_row_rhythm.hit_good"), p + Vector2(0, -150.0 * _sc()), UI.CREAM, 44)
		f.flare(p, 100.0 * _sc(), UI.GOLD)
	f.combo_step("", Vector2(size.x * 0.5, size.y * HIT_LINE - 330.0 * _sc()))
	if not rival_passed and not rival.is_empty() and live_points() > int(rival.get("points", 0)):
		rival_passed = true
		f.pop(S.t("mg.rivals.passed", {"regular": str(rival.get("name", ""))}), Vector2(size.x * 0.5, size.y * 0.34), UI.NEON, 44)


func advance(dt: float) -> void:
	clock += dt
	_flash[0] = maxf(0.0, _flash[0] - dt * 5.0)
	_flash[1] = maxf(0.0, _flash[1] - dt * 5.0)
	_feedback_t = maxf(0.0, _feedback_t - dt)
	_clap_t[0] += dt
	_clap_t[1] += dt
	_beat_t += dt
	# The metronome follows the tempo: one tick per beat of the accumulated tempo map (the count-in at 96 BPM).
	var beat_i := int(floor(time_to_beat(clock)))
	if beat_i != _last_beat:
		_last_beat = beat_i
		_beat_t = 0.0
		if is_inside_tree() and _tick != null:
			_tick.play()
	_ramp_to(step_at_time(clock))
	_ensure_chunks()
	var win := GOOD_WINDOW * _window_scale()
	for n in notes:
		if done or float(n["time"]) > clock:
			break
		if n["state"] == 0 and clock - float(n["time"]) > win:
			_miss(n)
	# Judged notes long behind the line leave the chart (it is sorted by time, so they are at the front).
	while not notes.is_empty() and int(notes[0]["state"]) != 0 and clock - float(notes[0]["time"]) > DROP_AFTER:
		notes.pop_front()
	if _glow_layer != null:
		_glow_layer.queue_redraw()
	queue_redraw()


## A clap passed the line unhit: a strike. The third ends the round.
func _miss(n: Dictionary) -> void:
	n["state"] = 3
	n["t_hit"] = clock
	missed += 1
	combo = 0
	lives_left = maxi(0, STRIKES - missed)
	var f := fx()
	f.combo_break()  # the puck dims in _draw; no shake
	f.pop(S.t("mg.front_row_rhythm.missed"), _lane_pos(int(n["lane"])) + Vector2(0, -150.0 * _sc()), UI.SMOKE, 44)
	if lives_left > 0:
		var word := S.t("mg.ramp.last") if lives_left == 1 else S.t("mg.ramp.strike", {"lives": lives_left})
		f.pop(word, Vector2(size.x * 0.5, size.y * 0.42 + (missed - 1) * 70.0 * _sc()), UI.NEON, 52)   # a chord passed by = two strikes in one frame: stacked, not on top of each other
	haptic("fail")
	_update_status()
	if lives_left <= 0:
		lose()


func live_points() -> int:
	return record_points()


func _result_extra() -> Dictionary:
	if _record.is_empty():
		_record = Rivals.record(game_id, record_points(), {}, rivals_store)
	return {"level": ramp_level, "speed": roundi(bpm), "misses": missed, "lives_left": lives_left,
		"points": record_points(), "perfect": perfect, "good": good, "missed": missed, "best_combo": best_combo,
		"accuracy": score_from(perfect, good, perfect + good + missed), "seed": night_seed,
		"rival": rival, "board": _record["board_line"]}


## Every finger is its own clap (two thumbs = a chord): ScreenTouch carries each finger; the mouse (desktop) also
## arrives as ScreenTouch (project.godot emulate_touch_from_mouse) and the first finger also as an emulated mouse
## click, so a second tap on the same lane in the same frame is a twin and is dropped.
func _gui_input(event: InputEvent) -> void:
	var pos: Variant = null
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pos = event.position
	if pos == null:
		return
	var lane := 0 if (pos as Vector2).x < size.x * 0.5 else 1
	var frame := Engine.get_process_frames()
	if _lane_frame[lane] == frame:
		return
	_lane_frame[lane] = frame
	tap(lane)


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


func _fx_ok() -> bool:
	return _fx != null and is_instance_valid(_fx)


## Fit scale of the sprites to the play area (they are drawn for a 780 px wide play area; never above 1.5x).
func _sc() -> float:
	return clampf(minf(size.x / 780.0, size.y / 1100.0), 0.4, 1.5)


## Where a lane's target pad sits (local px).
func _lane_pos(lane: int) -> Vector2:
	return Vector2(lane * size.x * 0.5 + size.x * 0.25, size.y * HIT_LINE)


# --- Art -------------------------------------------------------------------------------------------

func _load_art() -> void:
	if not _art.is_empty():
		return
	var meta: Variant = null
	var f := FileAccess.open(ART_DIR + "sprites.json", FileAccess.READ)
	if f != null:
		meta = JSON.parse_string(f.get_as_text())
	if not meta is Dictionary:
		return
	var sprites: Dictionary = meta.get("sprites", {})
	for name in sprites:
		var m: Dictionary = sprites[name]
		var path: String = ART_DIR + str(m.get("file", ""))
		if not ResourceLoader.exists(path):
			continue
		var a: Array = m.get("anchor_px", [0, 0])
		var e := {"tex": load(path), "glow": null, "fw": float(m["frame_w"]), "fh": float(m["frame_h"]),
			"frames": int(m.get("frames", 1)), "anchor": Vector2(float(a[0]), float(a[1]))}
		if m.has("glow_file") and ResourceLoader.exists(ART_DIR + str(m["glow_file"])):
			e["glow"] = load(ART_DIR + str(m["glow_file"]))
		_art[name] = e


## Sprites the game draws with (the tests check them; the flat drawing is only a fallback when art is missing).
func has_art() -> bool:
	for n in ART_NEEDED:
		if not _art.has(n):
			return false
	return true


func _blit(ci: CanvasItem, name: String, frame: int, pos: Vector2, sc: Vector2, col := Color.WHITE, glow := false) -> void:
	var a: Dictionary = _art.get(name, {})
	if a.is_empty():
		return
	var tex: Texture2D = a["glow"] if glow else a["tex"]
	if tex == null:
		return
	var div := 2.0 if glow else 1.0
	var fw: float = a["fw"]
	var fh: float = a["fh"]
	var fr := clampi(frame, 0, int(a["frames"]) - 1)
	var src := Rect2(fr * fw / div, 0.0, fw / div, fh / div)
	var anchor: Vector2 = a["anchor"]
	ci.draw_texture_rect_region(tex, Rect2(pos - anchor * sc, Vector2(fw, fh) * sc), src, col)


func _ensure_glow_layer() -> void:
	if _glow_layer != null and is_instance_valid(_glow_layer):
		return
	_glow_layer = Control.new()
	_glow_layer.name = "Glow"
	_glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_layer.material = Fx.glow_material()
	_glow_layer.size = size
	_glow_layer.draw.connect(_draw_glows)
	add_child(_glow_layer)
	if _fx_ok():
		move_child(_glow_layer, _fx.get_index())  # glows under the juice overlay


func _px_per_sec() -> float:
	return size.y * HIT_LINE / lead_at(tempo_step)


## Additive halos: target rings that lit with a tap, the pucks coming in.
func _draw_glows() -> void:
	if not has_art() or size.x <= 0.0:
		return
	_glow_layer.size = size
	var sc := Vector2.ONE * _sc()
	for l in 2:
		var a: float = clampf(_flash[l], 0.0, 1.0)
		if a > 0.0:
			_blit(_glow_layer, "target", 0, _lane_pos(l), sc, Color(1, 1, 1, a), true)
	var line_y := size.y * HIT_LINE
	for n in notes:
		if n["state"] != 0:
			continue
		var y: float = line_y - (n["time"] - clock) * _px_per_sec()
		if y < -80.0 or y > size.y + 80.0:
			continue
		_blit(_glow_layer, "puck", 0, Vector2(_lane_pos(n["lane"]).x, y), sc, Color(1, 1, 1, 0.55), true)


# --- Drawing ---------------------------------------------------------------------------------------

func _draw() -> void:
	if size.x <= 0.0:
		return
	if has_art():
		_draw_art()
	else:
		_draw_flat()
	if clock < 0.0:
		var beats_left := int(ceil(-clock * BASE_BPM / 60.0))
		UI.draw_text(self, str(beats_left), Vector2(size.x * 0.5, size.y * 0.4), 220, UI.CREAM)
	UI.draw_text(self, S.t("mg.front_row_rhythm.hint"), Vector2(size.x * 0.5, size.y - 90), 40, UI.SMOKE)
	if not rival.is_empty():
		var col := UI.GOLD if rival_passed else UI.CREAM
		_text_right(S.t("mg.rivals.to_beat"), Vector2(size.x - 24.0, 120.0), 24, UI.SMOKE)
		_text_right("%s %d" % [str(rival.get("name", "")), int(rival.get("points", 0))], Vector2(size.x - 24.0, 158.0), 34, col)
		_text_right(S.t("mg.rivals.you_now", {"score": live_points()}), Vector2(size.x - 24.0, 194.0), 28, UI.GOLD if rival_passed else UI.SMOKE)


func _text_right(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	UI.draw_text(self, text, Vector2(pos.x - w * 0.5, pos.y), size_px, color)


func _draw_art() -> void:
	var b: Dictionary = _art["backdrop"]
	var tex_size := Vector2(b["fw"], b["fh"])
	var k := maxf(size.x / tex_size.x, size.y / tex_size.y)
	var shown := tex_size * k
	draw_texture_rect(b["tex"], Rect2((size - shown) * 0.5, shown), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.18))
	var sc := _sc()
	var scv := Vector2.ONE * sc
	var line_y := size.y * HIT_LINE
	var lane_w := size.x * 0.5
	for l in 2:
		draw_rect(Rect2(l * lane_w + 24, 0, lane_w - 48, size.y), Color(UI.BG_DEEP, 0.38))
	# The band on the stage strip between the lanes, frame 1 on the beat.
	var on_beat := 1 if _beat_t < 0.16 else 0
	var feet_y := size.y * 0.30
	_blit(self, "band_jo", on_beat, Vector2(size.x * 0.5 - 76.0 * sc, feet_y), scv)
	_blit(self, "band_pete", on_beat, Vector2(size.x * 0.5 + 84.0 * sc, feet_y), scv)
	for l in 2:
		_blit(self, "target", 0 if _flash[l] > 0.05 else 1, _lane_pos(l), scv)
	var pps := _px_per_sec()
	for n in notes:
		var lane_x: float = _lane_pos(n["lane"]).x
		var y: float = line_y - (n["time"] - clock) * pps
		if n["state"] == 0:
			if y < -120.0 or y > size.y + 120.0:
				continue
			_blit(self, "puck", 0, Vector2(lane_x, y), scv)
			continue
		var age: float = clock - float(n.get("t_hit", clock))
		if n["state"] == 3:  # missed: the puck dims and falls on past the line
			if age < MISS_FADE:
				_blit(self, "puck", 2, Vector2(lane_x, y), scv, Color(1, 1, 1, 1.0 - age / MISS_FADE))
		elif age < HIT_FADE:  # hit: a bright puck blooms on the pad (white on a perfect)
			var k2 := age / HIT_FADE
			var tint := Color(1, 1, 1, 1.0 - k2)
			if n["state"] == 1 and _fx_ok():
				tint = _fx.flash_color("lane%d" % n["lane"], tint)
				tint.a = 1.0 - k2
			_blit(self, "puck", 1, _lane_pos(n["lane"]), scv * (1.0 + 0.4 * k2), tint)
	# The clapping hands below each pad: 0 open, 1 closing, 2 clap, squashed by the juice kit.
	for l in 2:
		var t: float = _clap_t[l]
		var fr := 0
		if t < CLAP_SECONDS * 0.34:
			fr = 1
		elif t < CLAP_SECONDS:
			fr = 2
		var sq := _fx.squash_scale("clap%d" % l) if _fx_ok() else Vector2.ONE
		_blit(self, "clap", fr, _lane_pos(l) + Vector2(0, 190.0 * sc), scv * sq)


func _draw_flat() -> void:
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
	var px_per_sec := _px_per_sec()
	for n in notes:
		if n["state"] != 0:
			continue
		var y: float = line_y - (n["time"] - clock) * px_per_sec
		if y < -80.0 or y > size.y + 80.0:
			continue
		var cx: float = n["lane"] * lane_w + lane_w * 0.5
		draw_circle(Vector2(cx, y), 58.0, UI.CREAM)
		draw_circle(Vector2(cx, y), 40.0, UI.BG_RAISED)
