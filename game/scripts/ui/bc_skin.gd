extends RefCounted
## Black Cabin UI skin, direction D2 "Back-bar" (Daniele 2026-11-19; spec docs/design/12-ui-notch.md §3).
## The interface is built from the bar itself: dark wood panels with a thin brass line and a red LED strip glowing
## under them, backlit cubbies for icons and options, velvet-red primary buttons with a gold rim, brass tags, and ONE
## neon-sign title per screen (Tilt Neon, SIL OFL 1.1, assets/fonts/OFL-TiltNeon.txt). Body text stays Lato.
## Flat StyleBoxFlat shapes + shadows only (Compatibility renderer, iPhone budget): no shaders, no textures.
##
## API (all static; `const BCSkin = preload("res://scripts/ui/bc_skin.gd")`). Sizes are in dp (1 dp = 1080/390 px).
##   Palette .......... WOOD_DEEP WOOD WOOD_HI BRASS BRASS_DIM LED LED_CORE VELVET VELVET_HI CREAM GOLD SMOKE ASH
##   dp(v) ............ dp -> px
##   panel_box(radius := 18, led := true, alpha := 0.96) -> StyleBoxFlat
##                      wood panel, brass line, LED glow under it (shadow pushed down). Use on PanelContainer "panel".
##   sheet_box() ...... bottom-sheet variant: top corners only, LED glow along the top edge
##   row_box(lit := false) -> StyleBoxFlat     an option row / list card inside a panel (darker wood, brass hairline)
##   cubby_box(color, lit := false) -> StyleBoxFlat   a backlit bottle cubby for an icon (lit = glows in `color`)
##   style_button(b, kind := "secondary")      restyles any Button. kind: primary (velvet red, gold rim, glow),
##                      secondary (wood + brass, gold text), ghost (no frame, smoke text), tag (brass outline, gold)
##   button(text, kind := "secondary") -> Button   a new styled button (min height 56/48 dp like before)
##   tile_button(text, icon) -> Button         a square HUD button with a small drawn icon over its label;
##                      icon: "door" | "ticket" | "" (text only)
##   neon(l, color := LED, strength := 1.0)   turns a Label into a neon sign: Tilt Neon, pale core, coloured tube
##                      outline and halo. Use it on ONE title per screen.
##   neon_title(text, size_dp, color := LED) -> Label   a new neon-sign Label (theme variation LabelNeon)
##   tag(text, color := GOLD) -> Label         brass tag label ("GAME", "NEW BEST")
##   chip(text, fill := VELVET) -> Label      a pill chip (LIVE · song 1 of 4)
##   led_strip(parent, at_top := false) -> Control   adds a glowing red LED line along the parent's bottom (or top)
##                      edge; returns it (mouse-transparent, follows the parent's size)
##   rule() -> Control  a thin brass rule between rows
## Fonts: theme variations in ui/bc_theme.tres: LabelNeon (Tilt Neon), LabelTitle (Tilt Neon), LabelScript (Kristi,
## kept for WASTED), body variations (Lato). Thai falls back to IBM Plex Sans Thai Looped in every variation.

const DP := 1080.0 / 390.0

const WOOD_DEEP := Color("120807")
const WOOD := Color("231210")
const WOOD_HI := Color("38201A")
const BRASS := Color("B58A4C")
const BRASS_DIM := Color("5E4428")
const LED := Color("FF2A1E")
const LED_CORE := Color("FFE2DA")
const VELVET := Color("9A0E18")
const VELVET_HI := Color("C8141C")
const CREAM := Color("F6EBDD")
const GOLD := Color("FFDD78")
const SMOKE := Color("C4ADA2")
const ASH := Color("A8907F")

const NEON_FONT := preload("res://assets/fonts/TiltNeon-Regular.ttf")


static func dp(v: float) -> float:
	return v * DP


static func _flat(bg: Color, radius: float, border := Color(0, 0, 0, 0), border_w := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(dp(radius)))
	if border_w > 0.0:
		s.border_color = border
		s.set_border_width_all(maxi(1, int(dp(border_w))))
	s.anti_aliasing = true
	return s


static func panel_box(radius := 18.0, led := true, alpha := 0.96) -> StyleBoxFlat:
	var s := _flat(Color(WOOD, alpha), radius, Color(BRASS, 0.55), 1.0)
	s.set_content_margin_all(dp(16))
	if led:
		s.shadow_color = Color(LED, 0.34)
		s.shadow_size = int(dp(7))
		s.shadow_offset = Vector2(0, dp(3))
	return s


static func sheet_box() -> StyleBoxFlat:
	var s := panel_box(22.0, true, 0.97)
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	s.border_width_bottom = 0
	s.shadow_offset = Vector2(0, -dp(3))
	return s


static func row_box(lit := false) -> StyleBoxFlat:
	var s := _flat(Color(WOOD_DEEP, 0.92), 12.0, Color(BRASS, 0.5) if lit else Color(BRASS_DIM, 0.55), 1.0)
	s.set_content_margin_all(dp(10))
	if lit:
		s.shadow_color = Color(LED, 0.30)
		s.shadow_size = int(dp(5))
		s.shadow_offset = Vector2(0, dp(2))
	return s


static func cubby_box(color: Color, lit := false) -> StyleBoxFlat:
	var s := _flat(Color(color.darkened(0.55), 0.95) if lit else Color("0B0505"), 9.0, Color(color, 0.85) if lit else Color(BRASS_DIM, 0.7), 1.2)
	if lit:
		s.shadow_color = Color(color, 0.40)
		s.shadow_size = int(dp(6))
	return s


static func style_button(b: Button, kind := "secondary") -> void:
	var fill := WOOD
	var fill_hi := WOOD_HI
	var fg := GOLD
	var edge := Color(BRASS, 0.75)
	var glow := Color(0, 0, 0, 0)
	var radius := 12.0
	match kind:
		"primary":
			fill = VELVET
			fill_hi = VELVET_HI
			fg = CREAM
			edge = Color(GOLD, 0.85)
			glow = Color(LED, 0.38)
		"ghost":
			fill = Color(0, 0, 0, 0)
			fill_hi = Color(WOOD_HI, 0.8)
			fg = SMOKE
			edge = Color(0, 0, 0, 0)
		"tag":
			fill = Color(WOOD_DEEP, 0.7)
			fill_hi = WOOD_HI
			edge = GOLD
			radius = 8.0
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := _flat(fill_hi if st == "pressed" else fill, radius, edge, 1.4 if kind != "ghost" else 0.0)
		sb.content_margin_left = dp(10)
		sb.content_margin_right = dp(10)
		if glow.a > 0.0 and st != "disabled":
			sb.shadow_color = glow
			sb.shadow_size = int(dp(6))
		if st == "disabled":
			sb.bg_color = Color(fill, 0.55)
			sb.border_color = Color(edge, 0.35)
		if st == "focus":
			sb.draw_center = false
			sb.border_color = Color(0, 0, 0, 0)
			sb.shadow_size = 0
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", ASH)


static func button(text: String, kind := "secondary") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, dp(56.0 if kind == "primary" else 48.0))
	b.add_theme_font_size_override("font_size", int(dp(17.0 if kind == "primary" else 15.0)))
	style_button(b, kind)
	return b


## Square HUD button: icon on top, label under it (Leave = a door, Tonight = a ticket).
static func tile_button(text: String, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(dp(56), dp(52))
	b.add_theme_font_size_override("font_size", int(dp(12)))
	b.clip_text = false
	style_button(b, "secondary")
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st)
		sb.set_corner_radius_all(int(dp(12)))
		sb.content_margin_left = dp(4)
		sb.content_margin_right = dp(4)
		if icon != "":
			sb.content_margin_top = dp(22)
			sb.content_margin_bottom = dp(4)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, CREAM)
	if icon != "":
		var ic := _TileIcon.new()
		ic.kind = icon
		ic.set_anchors_preset(Control.PRESET_CENTER_TOP)
		ic.offset_left = -dp(10)
		ic.offset_right = dp(10)
		ic.offset_top = dp(6)
		ic.offset_bottom = dp(24)
		b.add_child(ic)
	return b


static func neon(l: Label, color := LED, strength := 1.0) -> Label:
	l.theme_type_variation = &"LabelNeon"
	l.add_theme_color_override("font_color", color.lerp(LED_CORE, 0.78))
	l.add_theme_color_override("font_outline_color", Color(color, 0.92 * strength))
	l.add_theme_constant_override("outline_size", maxi(2, int(dp(2.2))))
	l.add_theme_color_override("font_shadow_color", Color(color, 0.30 * strength))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", maxi(4, int(dp(7))))
	return l


static func neon_title(text: String, size_dp: float, color := LED) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", int(dp(size_dp)))
	return neon(l, color)


static func tag(text: String, color := GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.theme_type_variation = &"LabelDisplayS"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(dp(13)))
	l.add_theme_color_override("font_color", color)
	var sb := _flat(Color(Color("3A2610"), 0.92), 6.0, color, 1.2)
	sb.content_margin_left = dp(8)
	sb.content_margin_right = dp(8)
	sb.content_margin_top = dp(2)
	sb.content_margin_bottom = dp(2)
	l.add_theme_stylebox_override("normal", sb)
	return l


static func chip(text: String, fill := VELVET) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", int(dp(13)))
	l.add_theme_color_override("font_color", CREAM)
	var sb := _flat(Color(fill, 0.9), 20.0)
	sb.content_margin_left = dp(10)
	sb.content_margin_right = dp(12)
	sb.content_margin_top = dp(2)
	sb.content_margin_bottom = dp(2)
	l.add_theme_stylebox_override("normal", sb)
	return l


static func led_strip(parent: Control, at_top := false) -> Control:
	var s := _LedStrip.new()
	s.name = "LedStrip"
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.set_anchors_preset(Control.PRESET_TOP_WIDE if at_top else Control.PRESET_BOTTOM_WIDE)
	s.offset_left = dp(14)
	s.offset_right = -dp(14)
	s.offset_top = -dp(3) if at_top else -dp(1)
	s.offset_bottom = dp(1) if at_top else dp(3)
	s.at_top = at_top
	parent.add_child(s)
	return s


static func rule() -> Control:
	var c := ColorRect.new()
	c.color = Color(BRASS, 0.35)
	c.custom_minimum_size = Vector2(0, maxf(1.0, dp(0.8)))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The LED line: a bright core with a soft red bloom drawn as wider translucent lines.
class _LedStrip extends Control:
	var at_top := false

	func _draw() -> void:
		var y := size.y * 0.5
		var a := Vector2(0, y)
		var b := Vector2(size.x, y)
		draw_line(a, b, Color(LED, 0.10), DP * 9.0, true)
		draw_line(a, b, Color(LED, 0.22), DP * 4.5, true)
		draw_line(a, b, Color(LED, 0.95), DP * 1.3, true)
		draw_line(a, b, Color(LED_CORE, 0.6), maxf(1.0, DP * 0.4), true)


## Small icon for tile buttons, gold, drawn with primitives.
class _TileIcon extends Control:
	var kind := "door"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u := minf(size.x, size.y) / 20.0
		var o := (size - Vector2(20, 20) * u) * 0.5
		var c := GOLD
		match kind:
			"door":
				draw_rect(Rect2(o + Vector2(5, 1) * u, Vector2(10, 18) * u), c)
				draw_circle(o + Vector2(12.4, 10.5) * u, 1.2 * u, WOOD_DEEP)
				draw_colored_polygon(PackedVector2Array([o + Vector2(15, 7) * u, o + Vector2(19, 10) * u, o + Vector2(15, 13) * u]), Color(c, 0.75))
			"ticket":
				var r := Rect2(o + Vector2(1, 5) * u, Vector2(18, 10) * u)
				draw_rect(r, c)
				draw_circle(o + Vector2(1, 10) * u, 2.2 * u, WOOD)
				draw_circle(o + Vector2(19, 10) * u, 2.2 * u, WOOD)
				for i in 3:
					draw_rect(Rect2(o + Vector2(6.5 + i * 3.0, 7.5) * u, Vector2(1.2, 5) * u), WOOD_DEEP)
