extends SceneTree
## Milliseconds per tap in the character creator (owner list 2026-11-20 item 1: "character creation is
## superunresponsve"). Opens the creator alone in a real window, and on each tab makes a run of choices through
## creator.choose() (what a tap calls); for each it times the call itself and the wall time until that frame has been
## drawn (RenderingServer.frame_post_draw), the delay a finger feels. Windowed (hidden desktop) for the real renderer:
##   godot --path . --resolution 540x960 --script res://tools/creator_taps.gd -- --out=C:/somewhere/taps.json
## Prints and writes {tab: {"call_ms": [...], "frame_ms": [...]}} plus medians.

const Creator = preload("res://scripts/ui/character_creator.gd")
const Avatar = preload("res://scripts/avatar.gd")

const RUNS := {   # tab index -> [key, values...] tapped in turn (keys and values both creator versions know)
	0: [["skin", ["Skin1", "Skin5", "Skin2", "Skin7"]], ["head", ["square", "soft", "heart", "round"]], ["face", ["bright", "soft", "easy"]]],
	1: [["hair", ["bob", "curly", "quiff", "crop"]], ["hair_colour", ["HairBrown", "HairRose", "HairGrey", "HairBlack"]]],
	2: [["top_colour", ["Mustard", "Rust", "Teal", "Cream"]]],
}

var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_run()


func _run() -> void:
	await process_frame
	var c: Control = Creator.new()
	root.add_child(c)
	c.open("edit", Avatar.default_record(), "Ty", "night_owl")
	for i in 30:
		await process_frame
	var res := {}
	for t: int in RUNS:
		c._go_tab(t)
		for i in 20:   # the tab's own build (hair cards render) is not a tap
			await process_frame
		var calls: Array = []
		var frames: Array = []
		for run in RUNS[t]:
			for v in run[1]:
				var t0 := Time.get_ticks_usec()
				c.choose(run[0], v)
				var t1 := Time.get_ticks_usec()
				await RenderingServer.frame_post_draw
				var t2 := Time.get_ticks_usec()
				calls.append((t1 - t0) / 1000.0)
				frames.append((t2 - t0) / 1000.0)
				for i in 3:
					await process_frame
		res[["body", "hair", "outfit"][t]] = {"call_ms": calls, "frame_ms": frames, "call_median": _median(calls), "frame_median": _median(frames)}
	var text := JSON.stringify(res, " ")
	print(text)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
	quit(0)


func _median(a: Array) -> float:
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2] if not s.is_empty() else 0.0
