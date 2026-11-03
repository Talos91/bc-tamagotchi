# Role note: cast tonight (2026-11-03)
- Night number = `Cast.night()` in `game/scripts/cast.gd`: days since 1970 in Bangkok, turning at 06:00 (`night_at(unix)`). Global calendar night; not per save, not a visit count (`needs.nights_out` is never read).
- Prae (`mali`): in on even nights (`prae_in`), spot = `PRAE_ZONES[(n/2)%3]`. Ty (`tt`): every night at `table:LongTable`.
- Tue 2026-11-03 = night 20760 (even): Prae in at WestTable0, Ty in. Wed 11-04 = 20761: Prae out.
- No guest-night override added (not needed). If Prae must be in on an odd night, add a constant date list checked before the parity rule in `prae_in`.
- Test: `test_cast_tonight` in `game/tests/test_nightlife.gd`. Capture: `game/tests/capture_cast_tonight.gd` -> `docs/art/screens/cast-tonight/`.
