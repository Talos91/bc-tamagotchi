# Game bible

One page that points at everything known about Black Cabin Tamagotchi, with the live numbers from `game/scripts/rules.gd`. Paths are relative to the repo root. Where DECISIONS and another doc disagree, `docs/design/DECISIONS.md` wins. Maintained by Housekeeping; refresh after each wave (`python docs/design/build_hub_tabs.py`).

## What it is
A voxel-art Tamagotchi-style game commissioned by the real Black Cabin bar (466 Soi Thong Lo 16, Bangkok; open Tue–Sun 19:00–02:00). The character lives a needs loop (four meters, real-time decay) in a voxel replica of the venue, with minigames, coins and, later, a bridge to the real venue. Mobile only, portrait first. Engine: Godot 4.6.1, Compatibility renderer.

## Design
| Doc | What it holds |
|---|---|
| `docs/design/DECISIONS.md` | Binding decision log, newest rows at the bottom, plus the "Still open" list |
| `docs/design/00-brief.md` | The original brief (2026-09-22) |
| `docs/design/01-high-concept.md` | Pitch, pillars, the stakes in one page |
| `docs/design/02-gdd.md` | Game design document: needs, Vibe, visits, memories, minigames, notifications |
| `docs/design/03-cast.md` | Cast bible: owners, staff, regulars (Prae, Nam, Ty and the rest), asks to Black Cabin |
| `docs/design/04-coins.md` | Coin economy v2, signed off (long form) |
| `docs/design/04-coins-summary.md` | The coin economy on one page |
| `docs/design/06-stakes.md` | Stakes v3: fatal timer, ghost window, deletion, annoyances, the Flat, build spec |
| `docs/design/stakes-rules.md` | The player-facing stakes rules (hub tab "Stakes rules") |
| `docs/design/BACKLOG.md` | Living list of ideas and requests; mirrored on the hub Backlog tab |
| `docs/MANUAL.md` | The game manual (also a live Claude Doc), sections 1–16 |

## Venue and real-world facts
| Doc | What it holds |
|---|---|
| `docs/venue/menu/` | The real menu: 11 page photos, `menu.json`, `menu.md` (121 drinks, 34 dishes); used with the bar's authorization |
| `docs/venue/menu/errata-for-black-cabin.md` | Spellings that cannot be verified, to send to the bar |
| `docs/venue/events/` | Monthly event posters and JSON transcriptions (feeds the calendar need) |
| `docs/art/direction/` | Floor map, route and photos 01–25 of the real venue, the renders that set the look |
| `docs/reference/venue-photos/` | Reduced venue photos for reference (originals in `venue-photos-original/`) |

## Art
| Doc | What it holds |
|---|---|
| `docs/art/art-bible.md` | Art bible v2: voxel scale, palette, characters |
| `docs/art/palette-look-d.md` | Look D (the accepted venue look) values and the follow-ups |
| `docs/art/plan-v4.md` | Venue v4 plan from the real floor map |
| `docs/art/parity-measurements.md` | Measurements of renders 05 and 06 against the build |
| `docs/art/screens/` | Review captures per job, portrait 1080×1920 and landscape 1920×1080 |
| `blender/` | Review `.blend` files (kit, characters) |

## UI
| Doc | What it holds |
|---|---|
| `docs/ui/style-guide.md` | UI style guide: Lato for text, Kristi for titles, Thai fallback |
| `docs/ui/wireframes.md` | Portrait wireframes and components |
| `docs/ui/strings-guidelines.md` | String table rules; English and Thai ship together (`game/i18n/`) |

## Tech and process
| Doc | What it holds |
|---|---|
| `docs/tech/01-engine-decision.md` | Why Godot over a web-native client |
| `docs/tech/02-playtest-guide.md` | How to play the first loop |
| `docs/tech/03-web-build.md` | Web export, Vercel deploy, phone pass |
| `docs/tech/versioning.md` | Version number, build stamp, changelog |
| `docs/CHANGELOG.md` | Every commit by version (`python tools/changelog.py`) |
| `PROJECT.md`, `STATE.md`, `LOG.md` | Rules, state now, history |
| `ORCHESTRATION.md`, `handoffs/` | How the project is run; role notes and worker reports |
| `game/tests/` | The fifteen headless suites |

## Live numbers (`game/scripts/rules.gd`)
<!-- RULES-TABLE -->
| Section | Constant | Value | Note |
|---|---|---|---|
| Meters | `METER_MAX` | `100.0` | §2.1 "float 0-100" |
| Meters | `METER_MIN` | `0.0` |  |
| Meters | `START_VALUE` | `75.0` | GDD §2.1 (start value line) |
| Meters | `SOFT_FLOOR_BELOW` | `30.0` |  |
| Meters | `SOFT_FLOOR_FACTOR` | `0.3` |  |
| Meters | `PERSONALITY_DECAY_MULT` | `0.9` |  |
| Meters | `OUT_OF_TOWN_MAX_DAYS` | `14.0` |  |
| Meters | `OUT_OF_TOWN_COOLDOWN_DAYS` | `30.0` |  |
| Vibe | `GLOWING_MEMORY_BONUS` | `0.25` | §2.2 +25% memory drop chance (consumed by the memories system) |
| Visits and diminishing returns | `DIMINISH_TIER_1_END` | `40.0` |  |
| Visits and diminishing returns | `DIMINISH_TIER_2_END` | `80.0` |  |
| Visits and diminishing returns | `DIMINISH_TIER_1_FACTOR` | `1.0` |  |
| Visits and diminishing returns | `DIMINISH_TIER_2_FACTOR` | `0.5` |  |
| Visits and diminishing returns | `DIMINISH_TIER_3_FACTOR` | `0.25` |  |
| Visits and diminishing returns | `VISIT_IDLE_SECONDS` | `600.0` |  |
| Visits and diminishing returns | `DAY_UTC_OFFSET_HOURS` | `7.0` |  |
| Full and empty | `OVERFLOW_TO_TAB_RATIO` | `1.0` |  |
| Welcome Back | `WELCOME_BACK_VIBE_BELOW` | `25.0` | first visit after Vibe has been below 25... |
| Welcome Back | `WELCOME_BACK_AWAY_DAYS` | `7.0` | ...or after 7+ days away |
| Welcome Back | `WELCOME_BACK_GAIN_MULT` | `2.0` |  |
| Welcome Back | `WELCOME_BACK_MINUTES` | `15.0` | for 15 minutes |
| Notifications | `NOTIFY_LOWEST_METER_CROSSES` | `40.0` |  |
| Notifications | `NOTIFY_MAX_PER_WEEK` | `2` |  |
| Notifications | `NOTIFY_QUIET_AFTER_HOUR` | `22` |  |
| Debug clock | `DEBUG_CLOCK_MULTIPLIER` | `60.0` |  |
| Persistence | `AUTOSAVE_SECONDS` | `30.0` |  |
| Persistence | `VISIT_LOG_MAX` | `200` |  |
| Stakes | `FATAL_DAYS` | `21.0` | days without a counting visit (Out of Town excluded): the character dies |
| Stakes | `GHOST_WINDOW_DAYS` | `14.0` | a ghost can be revived by a check-in this long, then it is deleted (day 35) |
| Stakes | `GHOST_REMINDER_DAYS` | `[28.0, 33.0]` | days since the last visit: a ghost's reminders |
| Stakes | `REVIVE_COOLDOWN_DAYS` | `90.0` | one revival per this many days |
| Stakes | `REVIVE_METER_FLOOR` | `40.0` | a revived character's meters are lifted to at least this |
| Stakes | `REAL_VISIT_REQUIRED` | `false` |  |
| Stakes | `STAKE_NOTIFY_OUTSIDE_BUDGET` | `["last_call", "dead", "ghost_33"]` |  |
| Stakes | `STAKE_NOTIFY_FALLBACK_HOUR` | `19` |  |
| Stakes | `NIGHT_STARTS_HOUR` | `6.0` | a bar night belongs to the Bangkok day that starts at 06:00 (check-in at 01:00 = the night before) |
| Stakes | `CHECKIN_NIGHTS_KEPT` | `14` |  |
| Stakes | `ANNOY_EMPTY_BELOW` | `10.0` |  |
| Stakes | `ANNOY_DRAG_MULT` | `0.85` | gains to every OTHER meter, per active annoyance |
| Stakes | `THIRSTY_WALK_MULT` | `0.75` |  |
| Stakes | `EARWORM_DUCK_DB` | `-9.0` |  |
| Stakes | `RUSTY_FUMBLE_SECONDS` | `2.0` |  |
| Stakes | `CALENDAR_HABIT_DAYS` | `7.0` |  |
| Stakes | `CALENDAR_HABIT_ENABLED` | `false` | until the events calendar (BACKLOG D1) exists |
| Stakes | `MINIGAME_MISS_BELOW` | `0.25` |  |
| Stakes | `RUSTY_MISS_BELOW` | `0.4` |  |
| Stakes | `MINIGAME_TRIES_PER_VISIT` | `3` |  |
| Stakes | `GOING_BONUS_MUSIC` | `10.0` | waits for the calendar (D1) |
| Stakes | `RETIRE_COOLDOWN_DAYS` | `7.0` |  |
| Nightlife | `DRUNK_FROM` | `3` | the drunk screen effect starts at this many drinks... |
| Nightlife | `DRUNK_FULL` | `10` | ...and grows to its strongest here |
| Nightlife | `WASTED_AFTER` | `10` | one more than this: WASTED |
| Nightlife | `DRUNK_SOBER_MINUTES` | `20.0` | provisional: one drink wears off per 20 game minutes (03-cast §5.1 had a state per 30) |
| Nightlife | `WATER_SOBER_DRINKS` | `2` | provisional: a glass of water takes two drinks off (it used to drop a state) |
| Nightlife | `DRUNK_WARN_FROM` | `8` | provisional: from here Nam's line on the Order row is a warning |
| Nightlife | `WASTED_LOCKOUT_HOURS` | `12.0` | on the game clock, saved; the debug clock (F2, F3) skips it |
| Nightlife | `WASTED_METER_VALUE` | `0.0` | provisional: "all minor needs unfulfilled" = the four meters to this |
| Nightlife | `WASTED_LINES` | `10` | nightlife.wasted.line.0..9 in i18n/strings_nightlife.csv, one at random |
| Nightlife | `SMOKE_SECONDS` | `8.0` | one cigarette; light_one_up lands when it is finished |
| Nightlife | `PLUMBING_DRINKS_TO` | `0.0` | Daniele: Check the plumbing resets the drink need to 0 |

Refill actions (gains per action, caps) are the `ACTIONS` table in the same file; decay per real hour: music 0.55, friends 0.50, drinks 0.70, nightlife 0.45.
