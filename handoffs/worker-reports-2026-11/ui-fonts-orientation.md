# 🖼️ UI worker: fonts + orientation toggle — done, commit 9c6e39e (not pushed)
Full note in the repo: handoffs/ui-fonts-orientation-2026-11-02.md. For other workers:
- needs_hud.gd top bar: outer row separation 0, rings in their own row (fits 390 dp); zone name row now holds the
  orientation toggle (HUD.orientation_toggle). New theme variation LabelTitle (Kristi) via UI.title() in mg_ui.gd.
- main.gd F7 left untouched (it had venue-notes' uncommitted edit): suggested one-liner `KEY_F7: Orientation.toggle(needs)`
  so F7 also saves (scripts/ui/orientation.gd).
