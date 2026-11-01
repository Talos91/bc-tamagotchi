extends CanvasLayer
## Drunk screen effect (DECISIONS "Playtest of 33dc5b9"): from Rules.DRUNK_FROM alcoholic drinks the picture sways,
## doubles and blurs, growing to its strongest at Rules.DRUNK_FULL (Nightlife.drunk_level). A screen-space shader on
## its own CanvasLayer, between the vignette (Post, layer 0) and the HUD (UI, layer 1), so the HUD stays readable and
## the camera rig is untouched. main.gd adds it; it reads the session's drink count every frame and eases to it.

const Nightlife = preload("res://scripts/zones/nightlife.gd")

const EASE_PER_SECOND := 0.35   ## how fast the effect follows a new drink (a full 0 -> 1 in about 3 s)

const SHADER := """
shader_type canvas_item;
// Drunk: sway (slow roll, drift, breathing zoom), double vision (a ghost copy sliding sideways), blur (9 taps),
// warm tint and darker edges. amount 0..1.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
void fragment() {
	float a = amount;
	float t = TIME;
	vec2 c = SCREEN_UV - 0.5;
	float ang = sin(t * 0.8) * 0.035 * a;
	c = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * c;
	c *= 1.0 - 0.05 * a * (0.5 + 0.5 * sin(t * 0.55));
	vec2 uv = c + 0.5 + vec2(sin(t * 0.63), cos(t * 0.47)) * 0.012 * a;
	float r = 0.0065 * a;
	vec3 col = texture(screen_tex, uv).rgb;
	for (int i = 0; i < 8; i++) {
		float k = float(i) * 0.785398;
		col += texture(screen_tex, uv + vec2(cos(k), sin(k)) * r).rgb;
	}
	col /= 9.0;
	vec2 off = vec2(0.014 + 0.016 * sin(t * 0.9), 0.006 * cos(t * 1.3)) * a;
	vec3 ghost = texture(screen_tex, uv + off).rgb;
	col = mix(col, ghost, 0.42 * smoothstep(0.0, 0.35, a));
	col *= mix(vec3(1.0), vec3(1.07, 0.97, 0.9), a);
	float v = smoothstep(0.3, 0.9, length((SCREEN_UV - 0.5) * vec2(1.0, 0.8)));
	col *= 1.0 - v * 0.45 * a;
	COLOR = vec4(col, 1.0);
}
"""

var session: Node          ## VenueSession
var amount := 0.0          ## shown now
var override := -1.0       ## captures and tests: hold this level instead of the session's
var rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 0
	rect = ColorRect.new()
	rect.name = "Drunk"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	rect.material = _mat
	rect.visible = false
	add_child(rect)


func setup(s: Node) -> void:
	session = s


## The level the effect is heading for.
func target() -> float:
	if override >= 0.0:
		return override
	if session == null:
		return 0.0
	return Nightlife.drunk_level(session.tipsy.drinks)


## Jump straight to the target (captures).
func snap() -> void:
	amount = target()
	_apply()


func _process(delta: float) -> void:
	amount = move_toward(amount, target(), EASE_PER_SECOND * delta)
	_apply()


func _apply() -> void:
	_mat.set_shader_parameter("amount", amount)
	rect.visible = amount > 0.001
