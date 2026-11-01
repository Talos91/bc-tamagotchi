# Room polish, parity iterations 11-17 (commit ad8bf98, main)

Two-ups: docs/art/screens/parity/17-R05-twoup.png, 17-R06-twoup.png (11..16 alongside). Stats in docs/art/parity-measurements.md.

What moved the picture most (in order):
1. Shadowed warm DirectionalLight "KeyLight" (build_venue.gd _environment): cast shadow under every chair/stool/table/figure.
   Ceiling layer 2 is outside its cull mask; walls, cornices and upper walls have cast_shadow off.
2. Floor: 0.2 m running-bond tiles, per-tile spread 0.07, roughness 0.34 (0.18 threw white lamp glints).
3. Stage: StageCarpet / StageCarpetBand swatches (darker), one SpotLight per truss PAR, no flood, no front omni.
4. Upper walls 4-6 m (brick, joists, soffits, high exit signs) fill the voids above the cutaway; they carry cut_normal.

Pipeline: scratchpad iter.sh N = import, build_venue, export_layout, capture R05/R06, compose.
layout.json check: all 471 kit instances and 98 spawns of 146d334 identical; 106 dressing instances added.

Characters session: most remaining L>0.8 pixels are blond/white hair under the key light and lamps.
Not staged by me: docs/art/review-overview.png (rewritten by bc_review.py), tools/blender/bc_chars.py (sibling).
