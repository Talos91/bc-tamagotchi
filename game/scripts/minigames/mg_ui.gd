extends RefCounted
## Flat-shape UI helpers in the style guide palette (docs/ui/style-guide.md sections 2 and 5). No theme resource yet.

const BG_BASE := Color("1C0D0C")
const BG_DEEP := Color("160A0C")
const BG_RAISED := Color("2E1614")
const BG_PLUM := Color("2A0E12")
const LINE := Color("4A2A24")
const CREAM := Color("F6EBDD")
const SMOKE := Color("C4ADA2")
const ASH := Color("A8907F")
const RED := Color("8C0610")
const RED_HI := Color("D0161C")
const NEON := Color("FF2A14")
const AMBER := Color("FF8A30")
const GOLD := Color("FFDD78")
const CYAN := Color("18D0FA")

## 1 dp at the 1080 px base width (design frame is 390 dp wide).
const DP := 1080.0 / 390.0

const NEED_COLORS := {"music": RED_HI, "friends": GOLD, "drinks": AMBER, "nightlife": CYAN}


static func dp(v: float) -> float:
	return v * DP


static func box(bg: Color, radius := 14.0, border := Color(0, 0, 0, 0), border_w := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(dp(radius)))
	if border_w > 0.0:
		s.border_color = border
		s.set_border_width_all(maxi(1, int(border_w)))
	s.anti_aliasing = true
	return s


static func label(text: String, size_dp := 15.0, color := CREAM, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(dp(size_dp)))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Makes a label wrap inside its container (Thai breaks by dictionary, so no clip_text anywhere).
static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## kind: "primary" (Velvet Red), "secondary" (raised, gold label) or "ghost".
static func button(text: String, kind := "secondary") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, dp(56.0 if kind == "primary" else 48.0))
	b.add_theme_font_size_override("font_size", int(dp(17.0 if kind == "primary" else 15.0)))
	var fill := BG_RAISED
	var fill_hi := BG_PLUM
	var fg := GOLD
	var edge := LINE
	match kind:
		"primary":
			fill = RED
			fill_hi = RED_HI
			fg = CREAM
			edge = RED_HI
		"ghost":
			fill = Color(0, 0, 0, 0)
			fill_hi = BG_PLUM
			fg = SMOKE
			edge = Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", box(fill, 14, edge, 2.0))
	b.add_theme_stylebox_override("hover", box(fill, 14, edge, 2.0))
	b.add_theme_stylebox_override("pressed", box(fill_hi, 14, edge, 2.0))
	b.add_theme_stylebox_override("disabled", box(fill, 14, edge, 2.0))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", ASH)
	return b


static func need_color(need: String) -> Color:
	return NEED_COLORS.get(need, CREAM)


## Draws text with its baseline at `pos`; centered on pos.x unless align says otherwise.
static func draw_text(ci: CanvasItem, text: String, pos: Vector2, size_px: int, color: Color, centered := true) -> void:
	var font := ThemeDB.fallback_font
	var p := pos
	if centered:
		p.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	ci.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
