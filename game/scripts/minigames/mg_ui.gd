extends RefCounted
## Flat-shape UI helpers in the style guide palette (docs/ui/style-guide.md sections 2 and 5). No theme resource yet.

const BCSkin = preload("res://scripts/ui/bc_skin.gd")

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

const NEED_COLORS := {"music": Color("FF4081"), "friends": GOLD, "drinks": AMBER, "nightlife": CYAN}


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


## Titles (zone names, sheet and card headings, Welcome Back) use Tilt Neon, the D2 neon-sign face (LabelTitle in
## bc_theme.tres; Kristi stays only as LabelScript for WASTED). Neither has Thai glyphs: Thai falls back to IBM Plex
## Sans Thai Looped. Tilt Neon has a normal x-height, so no size boost (Kristi needed 1.4).
const SCRIPT_SCALE := 1.0


static func title(text: String, size_dp: float, color := GOLD) -> Label:
	var l := label(title_case(text), size_dp, color)
	l.theme_type_variation = &"LabelTitle"
	title_size(l, size_dp)
	return l


static func title_size(l: Label, size_dp: float) -> void:
	var thai := TranslationServer.get_locale().begins_with("th")
	l.add_theme_font_size_override("font_size", int(dp(size_dp * (1.0 if thai else SCRIPT_SCALE))))


## Script capitals read badly: "THE LOUNGE" becomes "The Lounge". Mixed case and Thai pass through.
static func title_case(s: String) -> String:
	return s.capitalize() if s == s.to_upper() and s != s.to_lower() else s


## Makes a label wrap inside its container (Thai breaks by dictionary, so no clip_text anywhere).
static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## kind: "primary" (velvet red, gold rim), "secondary" (wood + brass, gold label), "ghost" or "tag": the D2 Back-bar
## skin (scripts/ui/bc_skin.gd, Daniele 2026-11-19).
static func button(text: String, kind := "secondary") -> Button:
	return BCSkin.button(text, kind)


static func need_color(need: String) -> Color:
	return NEED_COLORS.get(need, CREAM)


## Draws text with its baseline at `pos`; centered on pos.x unless align says otherwise.
static func draw_text(ci: CanvasItem, text: String, pos: Vector2, size_px: int, color: Color, centered := true) -> void:
	var theme := ThemeDB.get_project_theme()
	var font: Font = theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font
	var p := pos
	if centered:
		p.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	ci.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
