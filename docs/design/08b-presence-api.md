# 08b — Presence API contract (client ↔ `Presence` autoload ↔ Supabase)

Status: **v1, 2026-11-19** (🌐 presence-backend). Built against `08-presence.md` (baseline P1–P11, DECISIONS
2026-11-09). This page is the contract between the backend worker (`game/scripts/presence/`, `supabase/`) and the
presence-client worker (venue avatars, live badge, verb sheet). Change it only by a new dated row in §9.

## 1. The autoload

- Autoload name **`Presence`**, script `res://scripts/presence/presence.gd` (registered in `project.godot` by the
  backend branch). Helpers live beside it (`presence_api.gd` HTTP, `presence_config.gd` URL/key, `presence_mock.gd`).
- **`Presence.ON`** (const, `PRESENCE_ON`): `true` in this branch's web build only when `presence_config.gd` has a URL;
  when false every call answers at once with `{ok:false, reason:"off"}` and no request is made. Single-player never
  waits on it (08 §8).
- **Mock mode for tests and the offline client:** `Presence.use_mock(true)` (or `Presence.mock` set before the first
  call) swaps the network for an in-memory server (`presence_mock.gd`) that implements every rule below (one per
  night, tablemates within 45 min, verb limits, hide). `Presence.mock_fake_presences(n)` adds `n` generated
  players to tonight (the debug "Fake presences"). The presence-client worker builds against the mock.
- Every call is **async**: `await Presence.x(...)` returns a `Dictionary`. Every answer has `ok: bool`; when `ok`
  is false it has `reason: String` (§6). Nothing throws; a network error is `reason:"offline"`; a call never takes
  longer than `TIMEOUT_S` = 4 s (`tonight`, `checkin`) or 8 s (others).

## 2. Constants (in `presence.gd`, not in `rules.gd`, so the two branches do not collide)

| Const | Value | Meaning |
|---|---|---|
| `ON` | see §1 | master switch (`PRESENCE_ON`) |
| `POLL_S` | 120 | `tonight` re-fetch while the venue is on screen (late check-ins walk in) |
| `TIMEOUT_S` | 4 | venue entry / check-in timeout |
| `CAP` | 40 | most avatars staged (`PRESENCE_CAP`); the client sorts and cuts |
| `TABLEMATE_WINDOW_MIN` | 45 | server-side, informative |
| `VERBS` | `["wave","cheers","drink","phrase"]` | wave 1 verbs |
| `PHRASES` | 24 ids `p01`…`p24` | the preset lines (strings in `strings.csv` keys `PRES_PHRASE_01`…, client side) |

## 3. Calls

### 3.1 `checkin(code: String) -> Dictionary`

The table QR's code (`?t=<code>` in the page address, read by `Presence.pending_code()`; §5). Signs in anonymously
the first time (account id saved to `Needs.profile.player_id`). Sends the current avatar snapshot + display name +
presence mode with it.

**Precondition (P1):** `Presence.mode()` must not be `""`. If the player never chose, the call answers
`{ok:false, reason:"need_mode"}` and writes nothing; the client shows the consent card, then calls
`Presence.set_mode(m)` and `checkin` again.

Answer when `ok`:
```
{ ok: true, night: "2026-11-19", night_key: 20411, table_id: "Table3", label: "Table 3",
  first_of_night: true,      # false = a re-scan the same night (same or other table)
  moved: false,              # true = this scan moved tonight's presence to another table
  tablemates: [ <presence>, ... ] }   # players at the same table within 45 min, new matches included
```
On `ok` with `first_of_night`, `Presence` itself calls `Needs.check_in()` (clock reset / revival) and emits
`checked_in(answer)`; the client shows the "you are in" moment and N1 toasts from `tablemates`. Reasons:
`need_mode`, `bad_code`, `closed` (outside Tue–Sun 19:00–02:00 Bangkok), `rate_limited` (5 tries / 10 min),
`banned`, `offline`, `off`.

### 3.2 `tonight(force := false) -> Dictionary`

Tonight's visible presences, cached; re-fetched when older than `POLL_S` or `force`. `Presence.start_polling()` /
`stop_polling()` (venue on screen) emit `tonight_changed(list)` when the list changes; new ids arrive in
`added`, gone ones (hidden, banned, after 02:00) in `removed`.
```
{ ok: true, night: "2026-11-19", me_checked_in: true, my_table: "Table3",
  presences: [ <presence>, ... ], last_night: [ {player_id, display_name, avatar}, ... ] }
```
`<presence>`:
```
{ player_id: "uuid", display_name: "Mai", avatar: { ...07 §4 record... },
  table_id: "Table3" | "",   # "" unless the viewer checked in tonight (P3)
  zone: "Tables" | "Lounge" | "Buffer" | "Bar",   # layout.json zone of the real table; always present (P3 seat zone)
  at: 1763560000.0,          # unix seconds of the (last) scan
  tablemate: false, friend: false, regular: false, first_time: true,
  me: false }                # the viewer's own row (skip it when staging)
```
Order from the server: tablemates, then players you interacted with tonight, then newest first. The viewer's own
row is included with `me:true`. Hidden/blocked players and players in mode `nobody` never appear; mode `here`
players appear only to viewers checked in tonight. After 02:00 `presences` is empty and `last_night` lists last
night's visible names until 19:00 (P2). Offline: `{ok:false, reason:"offline", presences: <cached or []>}`.

### 3.3 `send_verb(to: String, kind: String, payload := {}) -> Dictionary`

`kind` in `VERBS`. `payload`: `drink` → `{drink_id:"...", band:4|6|9}` (coins spent client-side first, P10);
`phrase` → `{phrase:"p07", emoji:"🍸"}`; others `{}`. The sender plays the animation at once; the receiver gets an
inbox event and, if they opted in, a phone notification (§4). Answer `{ok:true, event_id, pushed: bool}`.
Reasons: `limit` (wave/cheers/drink 1 per pair per night, phrase 3, 40 per sender per night), `hidden` (the
receiver hid you; told as `limit` would leak, so the server answers `ok:true, pushed:false` and drops it — the
client never sees `hidden`), `not_tonight` (receiver not checked in tonight), `self`, `bad_kind`, `offline`
(queued locally, sent on reconnect the same night; `queued:true`).

### 3.4 `inbox() -> Dictionary` and `mark_read(ids: Array) -> Dictionary`

Unread events for the start-screen inbox (N2):
```
{ ok: true, events: [ { id: 12, from: <presence-lite {player_id, display_name, avatar}>, kind: "wave",
  payload: {}, night: "2026-11-19", at: 1763560000.0 }, ... ] }
```
The client applies the receiver effect (Friends +2, a free drink "from Mai") once, then calls `mark_read([ids])`.
Signal `inbox_changed(count)` after each poll while polling runs.

### 3.5 Settings and safety

| Call | Answer / effect |
|---|---|
| `mode() -> String` | `""` (never chosen), `"everyone"`, `"here"`, `"nobody"` (local, from save) |
| `set_mode(m)` | saves locally; server copy updated at the next call; `"nobody"` also hides tonight at once |
| `hide(player_id)` | that player disappears from your `tonight` and their verbs to you are dropped (08 §7.4) |
| `report(player_id, reason)` | `reason` in `["name","harassment","other"]`; also hides |
| `delete_me()` | every server row of the player goes; local game stays; `player_id` cleared |
| `push_supported() -> String` | `"yes"`, `"needs_install"` (iPhone not installed to home screen), `"no"` |
| `push_enable() -> Dictionary` | asks the browser permission, subscribes, stores the subscription: `{ok, reason}` (`denied`, `unsupported`, `needs_install`) |
| `push_disable()` | unsubscribes and deletes the server row |
| `push_enabled() -> bool` | local flag |

### 3.7 Perf telemetry (card telemetry-beacon: "auto", not anonymous)

`perf_report(version: String, device: Dictionary, numbers: Dictionary) -> Dictionary`: one report per visit, sent
automatically at the end of the visit (client hook later, from `PerfTelemetry`'s report). Signs in anonymously if
needed; the row carries the player id (Daniele 2026-11-19: "no need to be anonymous"). `device`: user agent, GPU,
pixel ratio, screen/canvas, cores, memory class, phone parts. `numbers`: fps p50/p5 overall and per screen/area,
spikes, draws/objects/primitives, video MB, load times, quality changes. Answer `{ok, id}`; reasons `limit` (30 a
day per player), `offline`, `off`. Server: table `perf_reports`, RPC `bc_perf_report`, kept 90 days.

### 3.6 Signals

`checked_in(answer)`, `tonight_changed(list, added, removed)`, `inbox_changed(count)`, `status_changed(s)` with
`s` in `"off"`, `"offline"`, `"online"` (for the small offline dot on the door board).

## 4. Phone notifications (Web Push)

- When a verb is sent, the server sends a push to the receiver if they enabled push and the push cap allows
  (default cap, pending owner card `presence-push-caps`: **1 push per sender per night, at most 3 a night,
  19:00–02:00 Bangkok only**; never from a hidden player). Text: "Mai waved at you at Black Cabin" (per kind);
  tapping it opens the game; the event is in the inbox either way.
- The opt-in card is the client's (UI), shown after the first tablemate or the first received verb; it calls
  `push_supported()` and on iPhone without home-screen install shows: "On iPhone, notifications work only once the
  game is on your home screen (Share → Add to Home Screen, iOS 16.4+)." Android Chrome: works in the browser.
- Without push everything still lands in the inbox.

## 5. The QR / page address

Check-in URL per table: `https://blackcabin.app/?t=<code>` (`code` = 10 random characters, not the table
number; P9). `Presence.pending_code()` returns the code from the address (web only; once, then the address is
cleaned with `history.replaceState`). The start flow: creator/name done → consent card if `mode()==""` →
`checkin(code)`. Codes and the printable sheet: `docs/venue/qr/`.

## 6. Reasons (all calls)

`off`, `offline`, `need_mode`, `bad_code`, `closed`, `rate_limited`, `banned`, `limit`, `not_tonight`, `self`,
`bad_kind`, `denied`, `unsupported`, `needs_install`, `server` (anything else; message in `detail`).

## 7. Backend shape (for reference; the client never calls these directly)

Supabase project `bc-tamagotchi-presence` (Singapore). Anonymous auth. RPCs (`/rest/v1/rpc/…`, user JWT):
`bc_check_in`, `bc_tonight`, `bc_inbox`, `bc_mark_read`, `bc_set_profile`, `bc_hide`, `bc_report`, `bc_delete_me`,
`bc_save_push`, `bc_delete_push`. Edge Function `verb` (user JWT) records the verb through `bc_send_verb` and sends
the push. Schema and RLS: `supabase/migrations/`. Public URL and anon key: `game/scripts/presence/presence_config.gd`
(public by design; RLS on every table). Service-role and VAPID private keys only inside Supabase.

## 8. Offline rules (08 §8, unchanged)

Venue entry never waits more than 4 s; a check-in is never queued; verbs are queued and flushed the same night.

## 9. Changes

| Date | Change |
|---|---|
| 2026-11-19 | v1.1: check-in host is `blackcabin.app` (Daniele's domain); perf telemetry §3.7 (`bc_perf_report`). |
| 2026-11-19 | v1. URL is `/?t=<code>` (orchestrator brief) instead of 08 §3.1's `/c/<code>`: no Vercel rewrite needed. |
