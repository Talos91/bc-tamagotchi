extends RefCounted
## What tells a real person from an NPC in the venue (08-presence §6.4; Daniele 2026-11-19 "show with a small icon who
## is a live patron"): a small live icon over the head (a cyan dot in a dark ring, pulsing) and a thin ring on the floor under
## them, white and dim, warm gold for a tablemate. Anonymous patrons, regulars and staff have neither. Also the sender
## feedback of a verb (§5.1 "the sender sees the animation now"): a bubble that rises and fades over a figure.
## Plain unshaded meshes and one shared 64 px icon, no lights: ~2 draw calls per presence (perf item 41).

const UI = preload("res://scripts/minigames/mg_ui.gd")
const UIS = preload("res://scripts/ui/ui_strings.gd")

const BADGE_H := 1.3           ## metres over the figure's root, standing (FIG_SCALE figures are ~1.16 m)
const BADGE_H_SEATED := 1.06
const RING_COLOR := Color(1, 1, 1, 0.45)
const RING_MATE := Color(1.0, 0.82, 0.4, 0.8)
const LIVE := Color("18D0FA")   ## UI.CYAN


const ICON_PX := 64
const ICON_M := 0.3            ## icon diameter in metres (~30 px from the diorama camera at 1080 wide)
static var _icon: ImageTexture


## The live icon: a cyan dot in a dark ring with a thin cyan rim, drawn once and shared by every badge.
static func icon() -> ImageTexture:
	if _icon != null:
		return _icon
	var img := Image.create(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
	var c := Vector2(ICON_PX, ICON_PX) * 0.5
	for y in ICON_PX:
		for x in ICON_PX:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (ICON_PX * 0.5)
			var col := Color(0, 0, 0, 0)
			if d <= 0.46:
				col = LIVE.lightened(0.25 * (1.0 - d / 0.46))
			elif d <= 0.74:
				col = Color(UI.BG_DEEP, 0.92)
			elif d <= 0.86:
				col = LIVE
			elif d <= 0.98:
				col = Color(UI.BG_DEEP, 0.85)
			img.set_pixel(x, y, col)
	_icon = ImageTexture.create_from_image(img)
	return _icon


static func attach(fig: Node3D, tablemate := false) -> void:
	var badge := Sprite3D.new()
	badge.name = "LiveBadge"
	badge.texture = icon()
	badge.pixel_size = ICON_M / ICON_PX
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.shaded = false
	badge.double_sided = true
	badge.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	badge.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	badge.position = Vector3(0, BADGE_H, 0)
	badge.set_meta("tooltip", UIS.t("ui.presence.live"))
	fig.add_child(badge)
	var tw := badge.create_tween().set_loops()   # a slow pulse: it reads as "live", not as a prop
	tw.tween_property(badge, "scale", Vector3.ONE * 1.15, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(badge, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_SINE)
	var ring := MeshInstance3D.new()
	ring.name = "LiveRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.36
	tm.rings = 24
	tm.ring_segments = 4
	ring.mesh = tm
	ring.scale = Vector3(1, 0.15, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = RING_MATE if tablemate else RING_COLOR
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fig.add_child(ring)
	set_floor(fig, 0.0)


## Root height over the floor (seated figures are lowered onto the seat; walking ones stand on it): the ring stays on
## the floor and the badge over the head.
static func set_floor(fig: Node3D, root_above_floor: float, seated := false) -> void:
	var ring := fig.get_node_or_null("LiveRing") as Node3D
	if ring:
		ring.position = Vector3(0, -root_above_floor + 0.02, 0)
	var badge := fig.get_node_or_null("LiveBadge") as Node3D
	if badge:
		var top := standing_top(fig)
		if top <= 0.0:
			badge.position.y = BADGE_H_SEATED if seated else BADGE_H
		else:   # seated, the head sits SEAT_DROP lower than standing (thighs level on the seat)
			badge.position.y = top - (SEAT_DROP if seated else 0.0) + ICON_M * 1.1


const SEAT_DROP := 0.12


## The figure's standing height in its own space, from its meshes' rest-pose boxes (0 when it has none yet).
static func standing_top(fig: Node3D) -> float:
	var top := 0.0
	var inv := fig.global_transform.affine_inverse()
	for mi in fig.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "LiveRing" or not mi.is_visible_in_tree():
			continue
		var box: AABB = inv * (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		top = maxf(top, box.end.y)
	return top


static func has_badge(fig: Node) -> bool:
	return fig != null and fig.get_node_or_null("LiveBadge") != null


## A short line over a figure that rises 0.5 m and fades in 1.8 s (a verb sent, a reaction).
static func bubble(fig: Node3D, text: String, color := UI.GOLD) -> Label3D:
	if fig == null or not fig.is_inside_tree():
		return null
	var l := Label3D.new()
	l.name = "VerbBubble"
	l.text = text
	l.font_size = 46
	l.outline_size = 12
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_modulate = Color(UI.BG_DEEP, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.no_depth_test = true
	l.render_priority = 2
	l.position = Vector3(0, BADGE_H + 0.2, 0)
	fig.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", BADGE_H + 0.7, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(1.1)
	tw.chain().tween_callback(l.queue_free)
	return l
