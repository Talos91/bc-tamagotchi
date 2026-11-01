# From the kit session: Compatibility glow needs HDR 2D

Measured 2026-10-27 with Godot 4.6.1, Compatibility renderer: with WorldEnvironment glow on, a viewport
without `use_hdr_2d` renders the background #1C0D0C as #92403A (whole frame lifted to pink). Glow
intensity, bloom, threshold and blend mode made no difference; `use_hdr_2d = true` fixed it (#1E0A08).
`game/scenes/main.tscn` has glow on and `project.godot` does not set `rendering/viewport/hdr_2d`,
so the game is likely washed out too. Owner of project.godot: set `rendering/viewport/hdr_2d=true`.
Repro: `game/assets/kit/capture_showcase.gd` (comment out the use_hdr_2d line).
