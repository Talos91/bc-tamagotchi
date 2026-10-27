# Engine decision: Godot 4.6 vs web-native client

Date: 2026-10-27. Author: tech session 1C. Status: recommendation for the orchestrator to confirm.

## Recommendation

**Godot 4.6, with the Web export as the link-sharing path.** The usual case for a web client is "instant browser access and a shareable venue URL". Ooze Syndicate already shows Godot delivering that, so the main argument for leaving Godot is weaker than it looks.

## What Ooze Syndicate actually has (checked in the sibling repo)

- `Game/2.0` is Godot **4.6.1**, `config/features = 4.6, GL Compatibility`, with `rendering_method` and `rendering_method.mobile` both set to `gl_compatibility`. The binary lives in `Tools/Godot/`.
- It ships a **Web export** (`build/web`, live at oozesyndicate.com). The pack is 52 MB and the wasm 36 MB, so the first load is heavy. Ooze lives with that and hides updates behind `web/update.js`.
- Networking is **not** Godot's high-level ENet multiplayer. It is `scripts/net.gd` on top of `scripts/relay_bridge.gd`: every player holds one **WebSocket** to `server/relay.py` (Python `websockets`, behind Caddy/TLS at `wss://…/ooze`). The server forwards strings between a room's players. Rooms are hosted by a **headless Godot** process the relay spawns (`godot --headless --main-pack index.pck -- --dedicated`). It began on PeerJS/WebRTC and was moved off it because strict networks blocked it.
- Hosting is one Vultr Singapore box (1 vCPU, 1 GB, about 250–350 MB per match host). Accounts and progression sit in `scripts/account.gd` and `supabase/`.
- Layout: `scripts/`, `assets/`, `maps/`, `shaders/`, `server/`, `tests/` (headless test scripts), `web/` (JS shims), `docs/NEXT-SESSION.md`; every number lives in one `rules.gd`.

So Daniele already owns a working Godot-to-browser pipeline, a deployable relay, a room-host pattern, an account layer and a test harness.

## Comparison

| Axis | Godot 4.6 | Web (Three.js / Babylon / PlayCanvas) |
|---|---|---|
| **Voxel look + emissive/bloom** | Compatibility renderer supports glow/bloom, emissive materials, OmniLight/SpotLight, and `WorldEnvironment`. Heavy glow is costlier on mobile GL but workable at this scene size. Greybox uses cheap lights. | Best-in-class. `UnrealBloomPass` / Babylon's glow layer is easy and tunable, and instanced voxel meshes are well-trodden. Slight edge on look-dev speed. |
| **20–50 avatars in one room** | Avatars are the same capsule-plus-kit mesh; use `MultiMeshInstance3D` for crowd, full rigs only near the camera. Presence is small (position, facing, emote at ~5–10 Hz). Ooze's relay pattern already carries it. | Equivalent. Instanced meshes plus a WebSocket relay or a managed service (Colyseus, PartyKit, Supabase realtime). No clear win. |
| **Mobile portrait** | Native Android/iOS export, touch input, and a portrait viewport via stretch settings. App-store build gives push notifications for the weekly-needs hook. Web export on a phone is possible but heavy (wasm, memory limits, iOS Safari quirks). | Browser-native, light first load (a few MB), pointer events and PWA install. Strongest on cold-start for casual visitors. |
| **Iteration with AI-generated assets** | Existing Blender MCP kit pipeline emits glTF straight into the project; `.tscn` is text and diffable, so worker sessions can edit scenes. Needs the editor/CLI for import. | glTF loads at runtime with no import step, which is very fast to iterate. But no editor-built scenes, so level layout lives in code or a custom format. |
| **Distribution** | Stores (Play/App Store review, fees, updates) plus Web build link. Link path = Ooze's current model. | Link only, with no review and no fees; stores later via a wrapper if wanted. The simplest. |
| **Reuse of what Daniele has** | Everything above: server, relay, accounts, tests, Blender kit, project habits, sessions already know the codebase. | Only the Blender assets and the Python relay idea. New toolchain (bundler, TS, hosting), new test setup, new bugs. |

## The honest case for web

A venue link someone can tap and be inside in five seconds is the best possible acquisition loop for a real bar, where a QR code on a table could drop a customer into the game. Three.js starts at a few MB; Ooze's Godot web build starts at roughly 90 MB, which is the single largest practical gap. Bloom and per-voxel look-dev are also easier and faster to tweak in a browser. If this game were web-only and casual-first, web would win.

It does not win outright because: (1) the gap can be narrowed on the Godot side (strip unused modules with a custom export template, compress and lazy-load packs, keep the venue small and voxel-textured); (2) the weekly-needs hook wants push notifications and an installed icon, which favour a native build; (3) the reuse advantage is large and certain while the web advantage is a size-of-first-load argument that we can measure early; (4) the orchestration plan has parallel AI sessions that already know Godot and this repo layout.

## Decision

Build in Godot 4.6.1 using the **Compatibility** renderer (matches Ooze, runs on web and low-end phones, and avoids the Mobile renderer's lack of web support). Treat the Web export as a first-class target from the first playable, not an afterthought, and design the venue so a trimmed "visitor" build is possible later.

Network plan for wave 3: reuse the Ooze relay approach (WebSocket relay, headless Godot as an authoritative room host for the one persistent venue), but note the difference. Ooze has short matches of 2–6 players; here there is one long-lived room with 20–50 presences, so the server tracks positions and needs state, not a simulation.

## Three risks of this choice

1. **Web first-load size and mobile browser memory.** If the Godot web build is around 90 MB like Ooze's, a QR-code visitor leaves before it loads, and iOS Safari may crash on heavy scenes. *Mitigation:* set a size budget now (target under 25 MB compressed pack), build a custom export template without 2D physics/unused modules, and measure the empty skeleton's Web export in the first wave-2 session. If it misses badly, reopen this decision before the venue kit is built.
2. **Bloom/emissive look on the Compatibility renderer.** The art direction (red neon, amber shelves, candlelight) relies on glow. Compatibility supports glow but has fewer features than Forward+ and is slower on weak phones, and many dynamic lights are expensive. *Mitigation:* bake or fake most lighting with emissive materials plus a few real lights, test on one mid-range Android phone early, and keep a quality switch.
3. **Persistent 20–50 player room is a different server shape than Ooze's matches.** Ooze's relay hosts small, short rooms on a 1 GB box with about 300 MB per match host; a headless Godot hosting a 50-avatar all-day venue plus per-player persistence has not been proven. *Mitigation:* prototype presence with simulated bots on the relay before building features on it, keep the server dumb (positions, emotes, chat, needs stored in Supabase), and shard venue instances if one room caps out.

## What the next tech session should do

The skeleton in `game/` runs: Godot 4.6.1 (Ooze Syndicate's copy) loads it headless and a scripted player walks up the stairs into the lounge. It has not been looked at in a real window yet.

1. Open `game/` in the editor, check the look (glow, lights, scale against the photos) and tune `tools/build_venue.gd`.
2. Web-export the skeleton and record pack size and load time as the baseline for risk 1.
3. Test portrait layout and the touch joystick on a real phone.
