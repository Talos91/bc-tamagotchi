extends RefCounted
## HTTP transport to Supabase (auth, PostgREST RPC, Edge Functions) for the Presence autoload. Every call answers a
## Dictionary and never throws: network failures are {ok:false, reason:"offline"}. Uses HTTPRequest, which the web
## export maps to the browser's fetch (no threads, no WebSockets). The mock transport (presence_mock.gd) has the
## same four methods.

var url := ""
var anon_key := ""
var host: Node


func _init(p_host: Node, p_url: String, p_key: String) -> void:
	host = p_host
	url = p_url.trim_suffix("/")
	anon_key = p_key


func signup() -> Dictionary:
	var r := await _post("/auth/v1/signup", {"data": {}}, "", 8.0)
	return _session(r)


func refresh(refresh_token: String) -> Dictionary:
	var r := await _post("/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token}, "", 8.0)
	return _session(r)


func rpc(fn: String, args: Dictionary, token: String, timeout: float) -> Dictionary:
	var r := await _post("/rest/v1/rpc/" + fn, args, token, timeout)
	if not r["ok"]:
		return r
	var d = r["data"]
	if d is Dictionary:
		return d
	return {"ok": true, "value": d}


func edge(fn: String, body: Dictionary, token: String, timeout: float) -> Dictionary:
	var r := await _post("/functions/v1/" + fn, body, token, timeout)
	if not r["ok"]:
		return r
	return r["data"] if r["data"] is Dictionary else {"ok": false, "reason": "server", "detail": "bad answer"}


func _session(r: Dictionary) -> Dictionary:
	if not r["ok"]:
		return r
	var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
	if not d.has("access_token"):
		return {"ok": false, "reason": "server", "detail": "no session"}
	return {"ok": true, "user_id": str(d.get("user", {}).get("id", "")), "access_token": str(d["access_token"]),
		"refresh_token": str(d.get("refresh_token", "")),
		"expires_at": Time.get_unix_time_from_system() + float(d.get("expires_in", 3600))}


func _post(path: String, body: Dictionary, token: String, timeout: float) -> Dictionary:
	if url == "" or host == null or not host.is_inside_tree():
		return {"ok": false, "reason": "off"}
	var http := HTTPRequest.new()
	# No engine timeout (hotfix 2, 2026-11-20): HTTPRequest's timer counts frame delta, and the QR check-in is sent in
	# the first frame after the web start-up block (7.8 s on the live build in a browser), so its 4 s timer fired
	# before the request ever reached fetch: "No signal" on every phone. The wait below counts at most 0.25 s a frame.
	http.timeout = 0.0
	# No gzip from Godot's side (hotfix 2026-11-20, check-in "No signal" on every new phone): Supabase auth answers
	# gzipped; on the web the browser has already unzipped the body, and HTTPRequest unzipping it again failed
	# (stream_peer_gzip), which read as offline. The browser still negotiates compression on its own.
	http.accept_gzip = false
	host.add_child(http)
	var headers := PackedStringArray(["apikey: " + anon_key, "Content-Type: application/json"])
	headers.append("Authorization: Bearer " + (token if token != "" else anon_key))
	var err := http.request(url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"ok": false, "reason": "offline", "detail": "request %d" % err}
	var res: Array = []
	http.request_completed.connect(func(a, b, c, d): res.assign([a, b, c, d]), CONNECT_ONE_SHOT)
	var tree := host.get_tree()
	var waited := 0.0
	var last := Time.get_ticks_msec()
	while res.is_empty():
		await tree.process_frame
		if not res.is_empty():
			break
		if not is_instance_valid(http) or not is_instance_valid(host) or not host.is_inside_tree():
			if is_instance_valid(http):
				http.queue_free()
			return {"ok": false, "reason": "offline", "detail": "closed"}
		var now := Time.get_ticks_msec()
		waited += minf((now - last) / 1000.0, 0.25)
		last = now
		if waited >= timeout:
			http.cancel_request()
			http.queue_free()
			return {"ok": false, "reason": "offline", "detail": "timeout"}
	http.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS or code == 0:
		return {"ok": false, "reason": "offline", "detail": "result %d" % result}
	var data = JSON.parse_string(text) if text != "" else null
	if code == 401 or code == 403:
		return {"ok": false, "reason": "auth", "code": code, "detail": text.left(200)}
	if code == 429:
		return {"ok": false, "reason": "rate_limited", "code": code}
	if code >= 400:
		return {"ok": false, "reason": "server", "code": code, "detail": text.left(300)}
	return {"ok": true, "code": code, "data": data}
