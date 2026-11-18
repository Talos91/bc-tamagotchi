extends Control
## Shared minigame juice kit (docs/design/11-minigame-quality.md §2.1–2.2, job Q1). One overlay per game:
## `var fx = fx()` in any minigame_base subclass (or `MgFx.new()` + `target` for other screens). It draws on top
## of its parent and answers inputs with hit pops, a combo counter, flashes, a red failure edge, trauma screen shake
## (off with the "reduce motion" setting), hit-stop, squash & stretch, particle bursts and glows.
##
## Cosmetic only: nothing here touches a score, and games keep advancing through advance(dt). The overlay runs on
## its own clock, step(dt), which _process calls; tests call step() directly. Phone budget (§1.3): no shaders, no
## extra buffers, CPUParticles2D only, at most MAX_PARTICLES alive. Every value below is a starting value to tune.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const NODE_NAME := "MgFx"

# --- Hit pop: "+1", "+50", "CLEAN" rises 40 px and fades in 0.5 s, scale 1.3 -> 1.0
const POP_RISE := 40.0
const POP_SECONDS := 0.5
const POP_SCALE_FROM := 1.3
const POP_SCALE_SECONDS := 0.12  # the 1.3 -> 1.0 settle happens at the start of the rise
const POP_SIZE_PX := 56
const POP_OUTLINE_PX := 10
const POP_MAX := 12  # oldest pops drop first

# --- Combo counter: "CLEAN ×6"; grows on each step, shatters into sparks on a break
const COMBO_MIN := 2  # shown from the second step on
const COMBO_SIZE_PX := 48
const COMBO_BUMP := 0.35  # extra scale on a step, decaying over COMBO_BUMP_SECONDS
const COMBO_BUMP_SECONDS := 0.18
const COMBO_GROW_PER_STEP := 0.04  # the readout grows with the count, up to COMBO_GROW_MAX
const COMBO_GROW_MAX := 0.4

# --- Hit flash: object tints white 60 ms; failure tints the screen edge red 120 ms
const FLASH_SECONDS := 0.06
const EDGE_SECONDS := 0.12
const EDGE_WIDTH_DP := 22.0
const EDGE_BANDS := 6
const EDGE_ALPHA := 0.6

# --- Screen shake: trauma 0.3 on a bump, 0.6 on a lost life, decays in 0.25 s, max 10 px
const TRAUMA_BUMP := 0.3
const TRAUMA_LOSS := 0.6
const SHAKE_SECONDS := 0.25
const SHAKE_MAX_PX := 10.0
const REDUCE_MOTION_KEY := "reduce_motion"  # Needs.ext["ui"][REDUCE_MOTION_KEY]; absent = false = shake allowed

# --- Hit-stop: 50 ms freeze on a big hit
const HIT_STOP_SECONDS := 0.05

# --- Squash & stretch on taps
const SQUASH := Vector2(1.25, 0.8)
const SQUASH_SECONDS := 0.16

# --- Particles: sparks on success, embers on singe, confetti on perfect
const MAX_PARTICLES := 200
const BURSTS := {
	"spark": {"count": 14, "life": 0.45, "speed": [220.0, 420.0], "gravity": 300.0, "size": [6.0, 10.0], "spread": 180.0},
	"ember": {"count": 12, "life": 0.7, "speed": [60.0, 160.0], "gravity": -140.0, "size": [6.0, 12.0], "spread": 180.0},
	"confetti": {"count": 40, "life": 1.1, "speed": [300.0, 620.0], "gravity": 900.0, "size": [10.0, 16.0], "spread": 70.0},
}

# --- Glow: a soft circle, pre-blurred (no post-process on phones)
const GLOW_TEX_SIZE := 128
const FLARE_SECONDS := 0.3

static var _glow_tex: Texture2D
static var _glow_mat: CanvasItemMaterial

var target: Control  # what shakes; defaults to the parent
var reduce_motion := false  # read from Needs on _ready; tests and screens may set it
var auto_step := true  # _process drives step(); tests turn it off and call step()

var trauma := 0.0
var combo := 0
var combo_word := ""
var combo_pos := Vector2.ZERO

var _pops: Array = []  # {text, pos, color, t, size}
var _flares: Array = []  # {pos, radius, color, t}
var _flashes := {}  # id -> seconds left
var _squash := {}  # id -> seconds since the tap
var _bursts: Array = []  # {node, left, amount}
var _edge := 0.0
var _trauma_rate := 0.0
var _combo_bump := 0.0
var _rest := Vector2.ZERO
var _shaking := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = NODE_NAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 1138


func _enter_tree() -> void:
	if target == null and get_parent() is Control:
		target = get_parent()
	reduce_motion = reduce_motion or reduce_motion_on(_needs())


func _process(delta: float) -> void:
	if auto_step:
		step(delta)


func _needs() -> Node:
	var tree := get_tree() if is_inside_tree() else null
	return tree.root.get_node_or_null("Needs") if tree != null else null


# --- Settings ------------------------------------------------------------------------------------------------------

## The "reduce motion" switch lives with the other UI settings in the save (Needs.ext["ui"]); default off.
static func reduce_motion_on(needs: Node) -> bool:
	if needs == null:
		return false
	var ui: Variant = needs.ext.get("ui")
	return ui is Dictionary and bool(ui.get(REDUCE_MOTION_KEY, false))


static func set_reduce_motion(needs: Node, on: bool) -> void:
	if needs == null:
		return
	var ui: Variant = needs.ext.get("ui")
	if not ui is Dictionary:
		ui = {}
	ui[REDUCE_MOTION_KEY] = on
	needs.ext["ui"] = ui


# --- Hit pop -------------------------------------------------------------------------------------------------------

## Text that rises and fades at `pos` (local px). Returns the number of pops alive.
func pop(text: String, pos: Vector2, color := UI.GOLD, size_px := POP_SIZE_PX) -> int:
	_pops.append({"text": text, "pos": pos, "color": color, "t": 0.0, "size": size_px})
	while _pops.size() > POP_MAX:
		_pops.pop_front()
	queue_redraw()
	return _pops.size()


static func pop_offset(t: float) -> float:
	var k := clampf(t / POP_SECONDS, 0.0, 1.0)
	return -POP_RISE * (1.0 - pow(1.0 - k, 3.0))


static func pop_scale(t: float) -> float:
	return lerpf(POP_SCALE_FROM, 1.0, clampf(t / POP_SCALE_SECONDS, 0.0, 1.0))


static func pop_alpha(t: float) -> float:
	var k := clampf(t / POP_SECONDS, 0.0, 1.0)
	return 1.0 - k * k


func pops_alive() -> int:
	return _pops.size()


# --- Combo ---------------------------------------------------------------------------------------------------------

## One more clean step. `word` defaults to CLEAN; `pos` is where the readout sits (keeps the last one).
func combo_step(word := "", pos := Vector2(-1, -1)) -> int:
	combo += 1
	combo_word = word if word != "" else S.t("mg.fx.clean")
	if pos.x >= 0.0:
		combo_pos = pos
	elif combo_pos == Vector2.ZERO:
		combo_pos = Vector2(size.x * 0.5, size.y * 0.3)
	_combo_bump = COMBO_BUMP_SECONDS
	queue_redraw()
	return combo


## The run broke: a shown combo shatters into sparks. Returns the count that was lost.
func combo_break() -> int:
	var lost := combo
	if combo >= COMBO_MIN:
		burst("spark", combo_pos, 10 + mini(combo, 10))
	combo = 0
	_combo_bump = 0.0
	queue_redraw()
	return lost


func combo_text() -> String:
	return S.t("mg.fx.combo", {"word": combo_word, "count": combo}) if combo >= COMBO_MIN else ""


func combo_scale() -> float:
	var grow := minf(COMBO_GROW_MAX, COMBO_GROW_PER_STEP * float(maxi(0, combo - COMBO_MIN)))
	return 1.0 + grow + COMBO_BUMP * (_combo_bump / COMBO_BUMP_SECONDS)


# --- Flashes -------------------------------------------------------------------------------------------------------

## Marks object `id` as hit: flash_amount(id) runs 1 -> 0 over FLASH_SECONDS; the game lerps its colour to white by it.
func flash(id: Variant) -> void:
	_flashes[id] = FLASH_SECONDS


func flash_amount(id: Variant) -> float:
	return clampf(float(_flashes.get(id, 0.0)) / FLASH_SECONDS, 0.0, 1.0)


## Helper for draw code: `col` tinted toward white by the object's flash.
func flash_color(id: Variant, col: Color) -> Color:
	return col.lerp(Color.WHITE, flash_amount(id))


## Failure: the screen edge goes red for EDGE_SECONDS.
func fail_edge() -> void:
	_edge = EDGE_SECONDS
	queue_redraw()


func edge_amount() -> float:
	return clampf(_edge / EDGE_SECONDS, 0.0, 1.0)


# --- Shake ---------------------------------------------------------------------------------------------------------

## Adds trauma (0.3 bump, 0.6 lost life); the shake lasts SHAKE_SECONDS. Returns false when reduce motion is on.
func shake(amount := TRAUMA_BUMP) -> bool:
	if reduce_motion or amount <= 0.0:
		return false
	trauma = minf(1.0, trauma + amount)
	_trauma_rate = trauma / SHAKE_SECONDS
	return true


## Offset this frame: up to SHAKE_MAX_PX, scaled by trauma² (small bumps stay small).
func shake_offset() -> Vector2:
	if trauma <= 0.0:
		return Vector2.ZERO
	var m := SHAKE_MAX_PX * trauma * trauma
	return Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * m


# --- Hit-stop ------------------------------------------------------------------------------------------------------

## Freezes the host game for `seconds` (minigame_base.hit_stop); the overlay keeps animating. Returns true if applied.
func hit_stop(seconds := HIT_STOP_SECONDS) -> bool:
	var host := get_parent()
	if host != null and host.has_method("hit_stop"):
		host.hit_stop(seconds)
		return true
	return false


# --- Squash & stretch ----------------------------------------------------------------------------------------------

func squash(id: Variant) -> void:
	_squash[id] = 0.0


## Scale to draw object `id` with: SQUASH on the tap, springing back to 1 with one small overshoot.
func squash_scale(id: Variant) -> Vector2:
	if not _squash.has(id):
		return Vector2.ONE
	return squash_at(float(_squash[id]))


static func squash_at(t: float) -> Vector2:
	var k := clampf(t / SQUASH_SECONDS, 0.0, 1.0)
	var amp := (1.0 - k) * (1.0 - k)
	return Vector2.ONE + (SQUASH - Vector2.ONE) * amp * cos(k * PI * 1.5)


# --- Particles -----------------------------------------------------------------------------------------------------

## A one-shot burst ("spark", "ember", "confetti") at `pos`. Clamped to the MAX_PARTICLES budget; returns how many
## particles were emitted (0 when the budget is spent).
func burst(kind: String, pos: Vector2, count := -1) -> int:
	var def: Dictionary = BURSTS.get(kind, BURSTS["spark"])
	var n := int(def["count"]) if count < 0 else count
	n = mini(n, MAX_PARTICLES - particles_alive())
	if n <= 0:
		return 0
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = n
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = float(def["life"])
	p.direction = Vector2.UP
	p.spread = float(def["spread"])
	p.initial_velocity_min = def["speed"][0]
	p.initial_velocity_max = def["speed"][1]
	p.gravity = Vector2(0, float(def["gravity"]))
	p.damping_min = 40.0
	p.damping_max = 120.0
	p.angular_velocity_min = -360.0 if kind == "confetti" else 0.0
	p.angular_velocity_max = 360.0 if kind == "confetti" else 0.0
	p.scale_amount_min = def["size"][0]  # no texture: each particle is a square of this many px (voxel look)
	p.scale_amount_max = def["size"][1]
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.color_initial_ramp = _palette(kind)
	p.emitting = true
	add_child(p)
	_bursts.append({"node": p, "left": p.lifetime + 0.1, "amount": n})
	return n


static func _palette(kind: String) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var cols: Array
	match kind:
		"ember":
			cols = [UI.NEON, UI.AMBER, UI.RED_HI]
		"confetti":
			cols = [UI.NEON, UI.GOLD, UI.CYAN, UI.CREAM, UI.AMBER]
		_:
			cols = [UI.GOLD, UI.CREAM, UI.AMBER]
	var offs := PackedFloat32Array()
	var pc := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / float(cols.size()))
		pc.append(cols[i])
	g.offsets = offs
	g.colors = pc
	return g


func particles_alive() -> int:
	var n := 0
	for b in _bursts:
		n += int(b["amount"])
	return n


# --- Glow ----------------------------------------------------------------------------------------------------------

## The shared soft glow: a white radial falloff, tinted by the draw call's modulate.
static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = GLOW_TEX_SIZE
		t.height = GLOW_TEX_SIZE
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		_glow_tex = t
	return _glow_tex


## Additive blend for a node that draws glows (set it as that node's material); without it glows blend normally.
static func glow_material() -> CanvasItemMaterial:
	if _glow_mat == null:
		_glow_mat = CanvasItemMaterial.new()
		_glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _glow_mat


static func draw_glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	ci.draw_texture_rect(glow_texture(), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


## A glow that flares at `pos` and fades over FLARE_SECONDS (a gate passed, a perfect pour).
func flare(pos: Vector2, radius: float, color := UI.GOLD) -> void:
	_flares.append({"pos": pos, "radius": radius, "color": color, "t": 0.0})
	queue_redraw()


# --- Clock and drawing ---------------------------------------------------------------------------------------------

func step(dt: float) -> void:
	for p in _pops:
		p["t"] += dt
	_pops = _pops.filter(func(p): return p["t"] < POP_SECONDS)
	for f in _flares:
		f["t"] += dt
	_flares = _flares.filter(func(f): return f["t"] < FLARE_SECONDS)
	for id in _flashes.keys():
		_flashes[id] -= dt
		if _flashes[id] <= 0.0:
			_flashes.erase(id)
	for id in _squash.keys():
		_squash[id] += dt
		if _squash[id] >= SQUASH_SECONDS:
			_squash.erase(id)
	_edge = maxf(0.0, _edge - dt)
	_combo_bump = maxf(0.0, _combo_bump - dt)
	for b in _bursts:
		b["left"] -= dt
		if b["left"] <= 0.0 and is_instance_valid(b["node"]):
			b["node"].queue_free()
	_bursts = _bursts.filter(func(b): return b["left"] > 0.0)
	_step_shake(dt)
	queue_redraw()


func _step_shake(dt: float) -> void:
	if target == null and get_parent() is Control:
		target = get_parent()
	if target == null or not is_instance_valid(target):
		trauma = maxf(0.0, trauma - _trauma_rate * dt)
		return
	if trauma > 0.0:
		if not _shaking:
			_rest = target.position
			_shaking = true
		trauma = maxf(0.0, trauma - _trauma_rate * dt)
		target.position = _rest + shake_offset()
	if trauma <= 0.0 and _shaking:
		target.position = _rest
		_shaking = false


## True while anything is still animating (pops, flashes, shake, particles...).
func busy() -> bool:
	return not (_pops.is_empty() and _flares.is_empty() and _flashes.is_empty() and _squash.is_empty() \
		and _bursts.is_empty() and _edge <= 0.0 and trauma <= 0.0)


func _draw() -> void:
	for f in _flares:
		var k := float(f["t"]) / FLARE_SECONDS
		var c: Color = f["color"]
		draw_glow(self, f["pos"], float(f["radius"]) * (1.0 + 0.4 * k), Color(c, c.a * (1.0 - k)))
	for p in _pops:
		var t := float(p["t"])
		var s := pop_scale(t)
		var c: Color = p["color"]
		draw_set_transform(p["pos"] + Vector2(0, pop_offset(t)), 0.0, Vector2(s, s))
		_outlined(p["text"], Vector2.ZERO, int(p["size"]), Color(c, pop_alpha(t)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var ct := combo_text()
	if ct != "":
		var s := combo_scale()
		draw_set_transform(combo_pos, 0.0, Vector2(s, s))
		_outlined(ct, Vector2.ZERO, COMBO_SIZE_PX, UI.GOLD)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _edge > 0.0:
		var a := EDGE_ALPHA * edge_amount()
		var band := UI.dp(EDGE_WIDTH_DP) / float(EDGE_BANDS)
		for i in EDGE_BANDS:
			var c := Color(UI.RED_HI, a * (1.0 - float(i) / float(EDGE_BANDS)))
			var o := band * i
			draw_rect(Rect2(o, o, size.x - 2.0 * o, band), c)
			draw_rect(Rect2(o, size.y - o - band, size.x - 2.0 * o, band), c)
			draw_rect(Rect2(o, o + band, band, size.y - 2.0 * o - 2.0 * band), c)
			draw_rect(Rect2(size.x - o - band, o + band, band, size.y - 2.0 * o - 2.0 * band), c)


## Centered text with a dark outline so pops read over any background.
func _outlined(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	var theme := ThemeDB.get_project_theme()
	var font: Font = theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font
	var p := pos - Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5, 0.0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, POP_OUTLINE_PX, Color(UI.BG_DEEP, color.a))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
