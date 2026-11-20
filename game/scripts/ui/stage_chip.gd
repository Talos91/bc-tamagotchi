extends PanelContainer
## The HUD's live chip under the zone title: who is on the real Black Cabin stage right now, from the weekly lineup
## and the Bangkok clock (tonight_events.gd stage_now). Daniele 2026-11-20: "since we have no live song, instead change
## the live song thing to what band is playing now ... based on the time". It replaces "LIVE · song n of 4"; the
## in-game house band (house_band.gd) still plays its songs for the Music meter, only the label changed.
##   On stage: velvet pill, the act's photo, "On stage: <name> · <genre>", "<set> · n min left" and a thin LED bar.
##   Otherwise: a dim wood pill, "Next: <act> at <time>" (or a later evening, or the next opening).

const UI = preload("res://scripts/minigames/mg_ui.gd")
const TE = preload("res://scripts/tonight_events.gd")
const BCSkin = preload("res://scripts/ui/bc_skin.gd")

const PHOTO := 30.0   ## dp
const MAX_LINE := 300.0  ## dp, widest the chip's text may get (the HUD column is ~360 dp in portrait)

var state := {}       ## TE.stage_now() as shown (tests read it)
var line: Label
var sub: Label
var photo: TextureRect
var _bar_bg: ColorRect
var _bar: ColorRect
var _box: StyleBoxFlat
var _photo_key := ""


func _init() -> void:
	name = "Live"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_box = StyleBoxFlat.new()
	_box.set_corner_radius_all(int(UI.dp(16)))
	_box.content_margin_left = UI.dp(6)
	_box.content_margin_right = UI.dp(12)
	_box.content_margin_top = UI.dp(3)
	_box.content_margin_bottom = UI.dp(3)
	_box.anti_aliasing = true
	add_theme_stylebox_override("panel", _box)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", int(UI.dp(7)))
	add_child(h)
	photo = TextureRect.new()
	photo.name = "Photo"
	photo.custom_minimum_size = Vector2(UI.dp(PHOTO), UI.dp(PHOTO))
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(photo)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	line = UI.label("", 13, UI.CREAM)
	line.name = "Line"
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(line)
	sub = UI.label("", 11, UI.GOLD)
	sub.name = "Sub"
	v.add_child(sub)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(BCSkin.WOOD_DEEP, 0.9)
	_bar_bg.custom_minimum_size = Vector2(0, maxf(2.0, UI.dp(2)))
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.name = "Progress"
	_bar.color = BCSkin.LED
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bg.add_child(_bar)


func refresh(unix := -1) -> void:
	state = TE.stage_now(unix)
	var on: bool = state["kind"] == "on"
	line.text = ("●  " if on else "") + TE.stage_line(state)
	# Trimmed labels have no width of their own: size the line to its text, capped so long names end in "…".
	var f: Font = line.get_theme_font("font")
	var fs: int = line.get_theme_font_size("font_size")
	var cap := UI.dp(MAX_LINE) - (UI.dp(PHOTO + 7) if on else 0.0)
	line.custom_minimum_size.x = minf(f.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0, cap) if f else 0.0
	sub.text = TE.stage_sub(state)
	sub.visible = sub.text != ""
	_bar_bg.visible = on and not bool(state["act"].get("till_late", false))
	if _bar_bg.visible:
		_bar.size = Vector2(_bar_bg.size.x * float(state["progress"]), _bar_bg.size.y)
	var key := str(state["act"].get("photo", "")) if on else ""
	if key != _photo_key:
		_photo_key = key
		photo.texture = TE.act_photo(state["act"]) if on else null
	photo.visible = photo.texture != null
	_box.bg_color = Color(BCSkin.VELVET, 0.9) if on else Color(BCSkin.WOOD_DEEP, 0.75)
	_box.content_margin_left = UI.dp(6) if photo.visible else UI.dp(12)
	line.add_theme_color_override("font_color", UI.CREAM if on else UI.SMOKE)
