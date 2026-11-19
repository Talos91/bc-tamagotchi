# Worker report: 🖼️ ui-notch (owner item 39), design only

Load id 2026-11-18-ui-black-cabin-59f561 · Opus 5.5 · session local_e0977981 (shared checkout, docs only).

## Evidence
- Spec: `docs/design/12-ui-notch.md`.
- Mock-ups (PIL drawings over real in-game captures, labelled "mock-up, not a game capture"):
  `docs/art/screens/ui-notch/icons-options.png`, `directions-overview.png`, and for d1-neon / d2-backbar / d3-poster:
  `-portrait-hud.png` (1080×1920), `-portrait-result.png` (1080×1920), `-landscape.png` (1920×1080).
  Generators: `docs/art/screens/ui-notch/tools/`.
- Hub cards (Questions tab, kind design): `ui-notch-icons` (order 380, 1 picture, rec I1),
  `ui-notch-direction` (order 381, 10 pictures, rec D2). Asset ids in the cards.
- Suites: none (no code changed). Godot: not run.

## Recommendation
- Icons **I1 Bold chips**: ♫ notes, two people, cocktail glass, **disco ball** for Nightlife (replaces the moon that
  read as sleep); Music to neon pink so it shows on the red room; bigger meter tiles.
- Interface **D2 Back-bar**: dark wood + brass line + red LED strip under panels, needs as a shelf of lit cubbies that
  fill like glasses, one neon sign (Tilt Neon, OFL) per screen; Lato body.
- Build order U1 icons → U2 skin kit → U3 HUD / U4 sheets / U5 result+frame (after Q1) / U6 start & rest.

## Not verified
- No in-engine render; glow cost and phone legibility checked first in U1/U2 (hidden desktop, then Daniele's phone).
- Start screen, character creator, Welcome Back not mocked (U6).
- Profile note: the ui profile is build-oriented ("branch off main, shoot before/after"); a design-only variant
  (options + cards, no branch) would fit jobs like this one.
