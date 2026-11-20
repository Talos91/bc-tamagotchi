extends SceneTree
## QR remake (2026-11-20), headless: every printed table code (docs/venue/qr/codes.json) checks in to a real seat of
## the venue the game ships (seat markers with metas table / zone, the ones venue_patrons.gd seats a check-in at);
## Buffer + Main room only (no Lounge, no Smoking), every Buffer / Main room / raised table and every bar stool has
## its code, new tokens for all (none of the 2026-11-19 codes), and codes.json, the client table lists
## (presence_mock, fake_presence), the Supabase seed, the map and the print sheet all list the same set.
##   godot --headless --path . --script res://tests/test_qr_codes.gd

const Mock = preload("res://scripts/presence/presence_mock.gd")
const Fake = preload("res://scripts/presence_ui/fake_presence.gd")
const CODE_ZONES := ["Buffer", "Tables", "Raised", "Bar"]
## The 2026-11-19 print (Daniele 2026-11-20: "New tokens for all"): none may come back.
const RETIRED := ["3hY9WEUfxi", "nZMhXxH2HR", "DD3NAQxY7i", "Kq58SDyTWS", "oNSMUTq2LJ", "uzVtBmrAS8", "UNjb5Aijur",
	"vtuFy8UJyd", "xG2ugpdcGq", "G7UJar4C4k", "sdse5B7YfD", "SxnGgVtEag", "RZFX6FMYDo", "x6KMa8KHwZ", "2BYgfrBWj9",
	"9YL5HnBgJM", "2JPaNA87GM", "5s3zrycvAb", "MLRH3w4qJh", "Uqmj4YnQVc"]

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", what)


func _init() -> void:
	await process_frame
	var qr := ProjectSettings.globalize_path("res://").path_join("../docs/venue/qr/")
	var codes: Variant = JSON.parse_string(FileAccess.get_file_as_string(qr + "codes.json"))
	check(codes is Array and codes.size() > 0, "codes.json is a list of codes")
	if not codes is Array:
		quit(1)
		return

	# The shipped venue's sit seats: table -> {zone, n}, and the bar stools.
	var venue: Node = (load("res://scenes/venue/venue.tscn") as PackedScene).instantiate()
	var seat_tables := {}
	var bar_stools := 0
	for m in venue.find_children("*", "Marker3D", true, false):
		if str(m.get_meta("pose", "")) != "sit" or str(m.get_meta("table", "")) == "":
			continue
		var t := str(m.get_meta("table"))
		var z := str(m.get_meta("zone", ""))
		if not seat_tables.has(t):
			seat_tables[t] = {"zone": z, "n": 0}
		seat_tables[t]["n"] += 1
		check(seat_tables[t]["zone"] == z, "%s: every seat in one zone" % t)
		if t == "Bar":
			bar_stools += 1
	venue.free()

	var re := RegEx.create_from_string("^[A-Za-z0-9]{10}$")
	var seen_codes := {}
	var seen_keys := {}
	var tables := {}           # table_id -> zone, from codes.json
	var bar_codes := 0
	for e in codes:
		var code := str(e.get("code", ""))
		var t := str(e.get("table_id", ""))
		var z := str(e.get("zone", ""))
		check(re.search(code) != null, "%s: code %s is 10 letters/digits (08b §5)" % [e.get("key"), code])
		check(not seen_codes.has(code), "code %s printed once" % code)
		check(not seen_keys.has(e.get("key")), "key %s once" % e.get("key"))
		check(not RETIRED.has(code), "%s: a new token, not a 2026-11-19 one" % e.get("key"))
		seen_codes[code] = true
		seen_keys[e.get("key")] = true
		check(CODE_ZONES.has(z), "%s: zone %s is Buffer / Main room (no Lounge, no Smoking)" % [e.get("key"), z])
		check(seat_tables.has(t) and seat_tables[t]["n"] > 0, "%s: table %s has seats in the venue" % [e.get("key"), t])
		check(seat_tables.has(t) and seat_tables[t]["zone"] == z, "%s: zone %s matches the seats' zone" % [e.get("key"), z])
		check(str(e.get("label", "")) != "", "%s: has a printed label" % e.get("key"))
		if tables.has(t):
			check(tables[t] == z, "%s: one zone per table" % t)
		tables[t] = z
		if t == "Bar":
			bar_codes += 1
	# Coverage: every Buffer / Main room / raised table has a code; one code per bar stool.
	for t in seat_tables:
		if ["Buffer", "Tables", "Raised"].has(seat_tables[t]["zone"]):
			check(tables.has(t), "venue table %s (%s) has a code" % [t, seat_tables[t]["zone"]])
	check(bar_stools > 0 and bar_codes == bar_stools, "one code per bar stool (%d codes, %d stools)" % [bar_codes, bar_stools])

	# Client table lists.
	check(Mock.TABLES.size() == tables.size(), "presence_mock lists the %d QR tables (%d)" % [tables.size(), Mock.TABLES.size()])
	for t in tables:
		check(Mock.TABLES.get(t, "") == tables[t], "presence_mock: %s in zone %s" % [t, tables[t]])
	for t in Fake.TABLES:
		check(tables.get(t, "") == Fake.TABLES[t], "fake_presence: %s is a QR table in zone %s" % [t, Fake.TABLES[t]])
	var mock := Mock.new()
	check(mock.codes.size() == Mock.TABLES.size(), "presence_mock: one distinct test code per table (%d)" % mock.codes.size())

	# Seed SQL, map, sheet.
	var sql := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../supabase/seed/venue_tables.sql"))
	var svg := FileAccess.get_file_as_string(qr + "table-map.svg")
	for e in codes:
		check(sql.contains("('%s', '%s', " % [e["code"], e["table_id"]]), "seed SQL inserts %s -> %s" % [e["code"], e["table_id"]])
		check(svg.contains("%d=%s" % [e["n"], e["key"]]), "map shows #%d %s" % [e["n"], e["key"]])
	check(sql.count("', true)") == codes.size(), "seed SQL has exactly the %d codes" % codes.size())
	check(sql.contains("set active = false where code not in"), "seed SQL retires every other code")
	for old in RETIRED:
		check(not sql.contains(old), "seed SQL does not keep old code %s" % old)
	# PIL writes the page tree first: "/Type /Pages" then "/Count N", within the first 300 bytes.
	var head := FileAccess.get_file_as_bytes(qr + "qr-sheet.pdf").slice(0, 300).get_string_from_ascii()
	var m := RegEx.create_from_string("/Type /Pages\\s*/Count (\\d+)").search(head)
	var pages := int(m.get_string(1)) if m else 0
	check(pages == ceili(codes.size() / 20.0) + 1, "qr-sheet.pdf: %d card pages + the map (%d pages)" % [ceili(codes.size() / 20.0), pages])

	print("test_qr_codes: %d codes, %d tables, %d bar stools; %d checks, %d failed" % [codes.size(), tables.size(), bar_stools, checks, fails])
	quit(0 if fails == 0 else 1)
