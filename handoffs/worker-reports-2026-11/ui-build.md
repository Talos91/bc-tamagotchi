# 🖼️ ui-build report, 2026-11-19 (load 2026-11-19-ui-black-cabin-f12ab0)

## Evidence
- Branch wk/ui-build, rebased on origin/main 54b1e94 (up to date), not pushed. Tip: see the final message (report commit).
- Commits: U1 1d89019 · U2 3bcfd6d · U3 · U4 b6ec41c · U5 17f72bb · U6 48e9863 · BCSkin rename 76ee4d6 · fixes 51adaf2 ·
  captures/role note 03ab5fd · uids c45e972.
- Suites, headless, empty APPDATA, worktree: all 27 in PROJECT.md Tests PASS + new test_ui_skin PASS (28). test_nightlife
  first failed on the WASTED variation check (now LabelScript, still Kristi); updated, re-run PASS.
- Captures (hidden desktop via hd.ps1, foreground probe godot-owned=0 on every run), 540×960 and 960×540:
  docs/art/screens/ui-build/{before,after}/{hud,menu,tonight,result,start}-{portrait,landscape}.png,
  sheet-portrait.png, sheet-landscape.png. Before = 54b1e94 in a detached worktree.
- Hub card `ui-build-review` (8 pictures + files).

## What changed
I2 neon-tube glyphs; meters as lit cubbies; bc_skin.gd kit (wood/brass panels, LED strip, velvet/brass buttons, tags,
chips, neon labels; Tilt Neon OFL subset 50 KB); HUD, sheets, Tonight, action card, result card, start prompt,
Welcome Back, farewell, offer card in the skin. All string keys kept.

## Not verified / not done
- No real phone; no web build. Captures are half-size windows, not 1080×1920 windows.
- Character creator selection colours and walk-out bars keep the old palette; no full-meter label sheet (none exists).
- presence-client's branch not landed at report time: no rebase over it was needed; its start_screen hunks are apart
  from mine (expect a clean merge).

## Profile note
- The brief's hd.ps1 path (ooze-wt/map-shots-tools) has no hd.ps1; a copy is at C:/Users/itisf/bc-wt/q7-tmp/hd.ps1.
