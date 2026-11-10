extends RefCounted
## Phone graphics (DECISIONS 2026-11-10, Daniele "Yes, allow it"; owner item 33: an iPhone lost its graphics entering
## the venue). On a touch web build the page shell (tools/build_web.py, SHELL_GUARD "Phone graphics") decides which
## parts are on and caps devicePixelRatio itself before the engine starts; it leaves the parts in window.bcPhone,
## {dpr, msaa, scale}, or null when off (desktop browsers, native, headless tests). This side applies the two parts
## the engine owns: MSAA off on the 3D views, 3D rendered at SCALE_3D and stretched. Measuring: ?phone=0 / ?phone=1 and
## ?pg=dpr,msaa,scale (any subset) on the page URL. Numbers and pictures: card perf-iphone-review.

const SCALE_3D := 0.75

static var _parts = null


## The parts the page turned on ({} when phone graphics is off).
static func parts() -> Dictionary:
	if _parts == null:
		_parts = {}
		if OS.has_feature("web"):
			var s = JavaScriptBridge.eval("window.bcPhone ? JSON.stringify(window.bcPhone) : ''", true)
			if s is String and s != "":
				var d = JSON.parse_string(s)
				if d is Dictionary:
					_parts = d
	return _parts


static func on(part: String) -> bool:
	return bool(parts().get(part, false))


## The game's own window: MSAA and 3D scale as the parts say (unchanged when off).
static func apply(vp: Viewport) -> void:
	if on("msaa"):
		vp.msaa_3d = Viewport.MSAA_DISABLED
	if on("scale"):
		vp.scaling_3d_scale = SCALE_3D


## MSAA for a 3D preview (character creator): off with the msaa part, else the usual 2x.
static func preview_msaa() -> Viewport.MSAA:
	return Viewport.MSAA_DISABLED if on("msaa") else Viewport.MSAA_2X
