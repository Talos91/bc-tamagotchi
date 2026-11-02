extends RefCounted
## Every tunable number of the needs system, in one place. Source of truth: docs/design/02-gdd.md §2.
## No logic here beyond tiny lookups. Change a number here and nowhere else. Tests read these constants
## rather than copying values, except where they assert the GDD's own stated figures.

# --- Meters (GDD §2.1) ---------------------------------------------------------------------------
const MUSIC := "music"
const FRIENDS := "friends"
const DRINKS := "drinks"
const NIGHTLIFE := "nightlife"
const METERS: Array[String] = ["music", "friends", "drinks", "nightlife"]

const METER_MAX := 100.0  # §2.1 "float 0-100"
const METER_MIN := 0.0
const START_VALUE := 75.0  # GDD §2.1 (start value line)

## Points lost per REAL hour (§2.1 table). Full to empty is 100 / rate: 7.6, 8.3, 6.0, 9.3 days.
const DECAY_PER_HOUR := {
	"music": 0.55,
	"friends": 0.50,
	"drinks": 0.70,
	"nightlife": 0.45,
}

## §2.1 soft floor: below SOFT_FLOOR_BELOW, decay is multiplied by SOFT_FLOOR_FACTOR.
## Factor 0.3 (was 0.5): DECISIONS "Orchestrator calls after wave 2" (a), so the 6-9 day empty window in §2 holds.
const SOFT_FLOOR_BELOW := 30.0
const SOFT_FLOOR_FACTOR := 0.3

## §2.1 personality modifier: lowers one meter's decay by 10%.
const PERSONALITY_DECAY_MULT := 0.9
const PERSONALITIES := {  # §7.1
	"night_owl": "nightlife",
	"music_nerd": "music",
	"social_butterfly": "friends",
	"easy_sipper": "drinks",
}

## §2.1 Out of Town toggle: freezes decay for up to 14 days, once per 30 days.
const OUT_OF_TOWN_MAX_DAYS := 14.0
const OUT_OF_TOWN_COOLDOWN_DAYS := 30.0

# --- Vibe (GDD §2.2) -----------------------------------------------------------------------------
const VIBE_GLOWING := "glowing"
const VIBE_GOOD := "good"
const VIBE_MEH := "meh"
const VIBE_HOMEBODY := "homebody"
## Lower bound (inclusive) of each state, highest first. Vibe = average of the four meters.
const VIBE_THRESHOLDS := [
	["glowing", 80.0],  # 80-100
	["good", 50.0],  # 50-79
	["meh", 25.0],  # 25-49
	["homebody", 0.0],  # 0-24
]
const GLOWING_MEMORY_BONUS := 0.25  # §2.2 +25% memory drop chance (consumed by the memories system)

# --- Visits and diminishing returns (GDD §2.4, §1.1) ---------------------------------------------
## Per meter, per visit: cumulative points up to TIER_1 count in full, up to TIER_2 at TIER_2_FACTOR,
## beyond that at TIER_3_FACTOR.
const DIMINISH_TIER_1_END := 40.0
const DIMINISH_TIER_2_END := 80.0
const DIMINISH_TIER_1_FACTOR := 1.0
const DIMINISH_TIER_2_FACTOR := 0.5
const DIMINISH_TIER_3_FACTOR := 0.25

## Daily multiplier by visit number within the real day: 1st x1.0, 2nd x0.75, 3rd and later x0.5.
const DAILY_VISIT_MULT: Array[float] = [1.0, 0.75, 0.5]
## A visit ends after this many (game) seconds without an action (§2.4: "idle for 10 minutes").
const VISIT_IDLE_SECONDS := 600.0
## Day boundary for the daily multiplier. DECISIONS.md: Bangkok time by default (UTC+7).
const DAY_UTC_OFFSET_HOURS := 7.0

# --- Full and empty (GDD §2.5) -------------------------------------------------------------------
## Gains past 100 convert to Tab at this ratio (Tab = progression XP, §10).
const OVERFLOW_TO_TAB_RATIO := 1.0

# --- Welcome Back (GDD §2.5) ---------------------------------------------------------------------
const WELCOME_BACK_VIBE_BELOW := 25.0  # first visit after Vibe has been below 25...
const WELCOME_BACK_AWAY_DAYS := 7.0  # ...or after 7+ days away
## All gains doubled. REPLACES the daily visit multiplier while active, never stacks with it
## (DECISIONS "Orchestrator calls after wave 2" (b)); see Needs.apply_action.
const WELCOME_BACK_GAIN_MULT := 2.0
const WELCOME_BACK_MINUTES := 15.0  # for 15 minutes

# --- Notifications (GDD §2.6), consumed by a later session ---------------------------------------
const NOTIFY_LOWEST_METER_CROSSES := 40.0
const NOTIFY_MAX_PER_WEEK := 2
const NOTIFY_QUIET_AFTER_HOUR := 22

# --- Debug clock (GDD §14: 1 real minute = 1 game hour) ------------------------------------------
const DEBUG_CLOCK_MULTIPLIER := 60.0

# --- Persistence ---------------------------------------------------------------------------------
const SAVE_PATH := "user://save.json"
const AUTOSAVE_SECONDS := 30.0
const VISIT_LOG_MAX := 200

# --- Refill actions (GDD §2.3) -------------------------------------------------------------------
## gains: meter -> base points, or [min, max] for score-scaled actions (score 0..1, low skill earns min).
## cap_per_visit: max base points of this action per visit ("Capped at +N per visit").
## once_per_visit: only the first call per visit counts ("First time ... each visit").
## daily_once: needs a key (e.g. the regular's id); one gain per key per day ("once per regular per day").
## Source of each base value: GDD §2.3, except candle_talk_lean (DECISIONS (k); 03-cast §3.1).
const ACTIONS := {
	"order_drink": {"label": "Order a drink (free one is on the house)", "zone": "Bar", "gains": {"drinks": 15.0}},
	"pour_perfect": {"label": "Pour Perfect / Shake & Serve", "zone": "Bar", "gains": {"drinks": [20.0, 30.0]}},
	"try_new_drink": {"label": "Try a drink you've never had", "zone": "Bar", "gains": {"drinks": 5.0}},
	"listen_song": {"label": "Listen to one song", "zone": "Stage", "gains": {"music": 5.0}},
	"finish_set": {"label": "Finish a full set (4 songs)", "zone": "Stage", "gains": {"music": 5.0, "nightlife": 5.0}},
	"front_row_rhythm": {"label": "Front Row Rhythm (per song)", "zone": "Stage", "gains": {"music": [12.0, 18.0]}},
	"applaud": {"label": "Applaud / request a song", "zone": "Stage", "gains": {"music": 2.0}, "cap_per_visit": 6.0},
	"headline_set": {"label": "Headline Night set (70%+)", "zone": "Stage", "gains": {"music": 40.0, "nightlife": 20.0}},
	"candle_talk": {"label": "Candle Talk with a regular", "zone": "Candle Floor", "gains": {"friends": [10.0, 20.0]}, "daily_once": true},
	## Bonus on a good Candle Talk (result extra.lean, candle fully lit). The talk itself is already once per
	## regular per day, so this fires at most as often. DECISIONS (k) approves +5; 03-cast §3.1 proposed it.
	"candle_talk_lean": {"label": "Candle Talk lean bonus (candle fully lit)", "zone": "Candle Floor", "gains": {"friends": 5.0}},
	"sit_with": {"label": "Sit at a table 60 s", "zone": "Any table", "gains": {"friends": 8.0}, "daily_once": true},
	"bar_chat": {"label": "Chat at the bar 60 s", "zone": "Bar", "gains": {"friends": 3.0}, "cap_per_visit": 6.0},  # provisional (DECISIONS 2026-11-02)
	"social_verb": {"label": "Receive a wave / cheers / high five", "zone": "Any", "gains": {"friends": 2.0}, "cap_per_visit": 10.0},
	"quiz_night": {"label": "Quiz Night / Name That Tune", "zone": "Long Table", "gains": {"music": 5.0, "friends": [10.0, 15.0]}},
	"dance_30s": {"label": "Dance under the disco ball (30 s)", "zone": "Dance floor", "gains": {"nightlife": 3.0}, "cap_per_visit": 15.0},
	"dance_off": {"label": "Dance-off minigame", "zone": "Dance floor", "gains": {"nightlife": [12.0, 20.0]}},
	"pinball": {"label": "Pinball (one game)", "zone": "Lounge", "gains": {"nightlife": [10.0, 20.0]}},
	"enter_lounge": {"label": "First time in the Lounge", "zone": "Lounge", "gains": {"nightlife": 5.0}, "once_per_visit": true},
	"last_song": {"label": "Stay until the last song", "zone": "Any", "gains": {"nightlife": 10.0}, "once_per_visit": true},
	## Provisional (DECISIONS "Playtest of 33dc5b9", BACKLOG B12): a cigarette by the smoking-room window is a chat
	## with whoever is there, so it feeds Friends a little; two count per visit. Call for Daniele on the Questions tab.
	"light_one_up": {"label": "Light one up (a cigarette)", "zone": "Smoking room", "gains": {"friends": 3.0}, "cap_per_visit": 6.0},
	## 06-stakes §2, §10.6: applied by the result card after any minigame round that is not a miss.
	"minigame_played": {"label": "Finish a minigame (not a miss)", "zone": "Any", "gains": {"nightlife": 3.0}, "cap_per_visit": 9.0},
}

# --- Stakes (docs/design/06-stakes.md v3 §10.6; Daniele's: FATAL_DAYS, GHOST_WINDOW_DAYS, REVIVE_COOLDOWN_DAYS) --------
const FATAL_DAYS := 21.0              ## days without a counting visit (Out of Town excluded): the character dies
const GHOST_WINDOW_DAYS := 14.0       ## a ghost can be revived by a check-in this long, then it is deleted (day 35)
## Stake stage by days since the last counting visit, highest first (same shape as VIBE_THRESHOLDS). `ghost` and
## `deleted` are not here: they come from `dead_at`.
const STAKE_STAGES := [["last_call", 18.0], ["fading", 15.0], ["restless", 10.0], ["fine", 0.0]]
const STAGE_GHOST := "ghost"
const STAGE_DELETED := "deleted"
const GHOST_REMINDER_DAYS := [28.0, 33.0]   ## days since the last visit: a ghost's reminders
const REVIVE_COOLDOWN_DAYS := 90.0    ## one revival per this many days
const REVIVE_METER_FLOOR := 40.0      ## a revived character's meters are lifted to at least this
## false until the server exists. When true, in-game refills stop resetting the clock, but only for a character
## that has checked in at the bar at least once (DECISIONS 2026-11-02, O1).
const REAL_VISIT_REQUIRED := false
const STAKE_NOTIFY_OUTSIDE_BUDGET := ["last_call", "dead", "ghost_33"]
const STAKE_NOTIFY_FALLBACK_HOUR := 19
const NIGHT_STARTS_HOUR := 6.0        ## a bar night belongs to the Bangkok day that starts at 06:00 (check-in at 01:00 = the night before)
const CHECKIN_NIGHTS_KEPT := 14

## Annoyances (§7.1, §10.3). A meter annoyance is on while its meter is below ANNOY_EMPTY_BELOW and not yet seen to this visit.
const ANNOY_EMPTY_BELOW := 10.0
const ANNOY_DRAG_MULT := 0.85         ## gains to every OTHER meter, per active annoyance
const ANNOYANCES := {"thirsty": "drinks", "earworm": "music", "phone_face": "friends", "rusty": "nightlife", "out_of_loop": ""}
const THIRSTY_WALK_MULT := 0.75
const EARWORM_DUCK_DB := -9.0
const RUSTY_FUMBLE_SECONDS := 2.0
const CALENDAR_HABIT_DAYS := 7.0
const CALENDAR_HABIT_ENABLED := false ## until the events calendar (BACKLOG D1) exists

## Minigames (§7.2, §10.4): a round below MINIGAME_MISS_BELOW is a miss (RUSTY_MISS_BELOW for the first round while Rusty).
const MINIGAME_MISS_BELOW := 0.25
const RUSTY_MISS_BELOW := 0.4
const MINIGAME_TRIES_PER_VISIT := 3
const GOING_BONUS_MUSIC := 10.0       ## waits for the calendar (D1)
const RETIRE_COOLDOWN_DAYS := 7.0

# --- Nightlife (DECISIONS "Playtest of 33dc5b9", BACKLOG B12; scripts/zones/nightlife.gd) -------------
## Counted in alcoholic drinks this visit (scripts/zones/tipsiness.gd: menu category "alcohol", Order a drink, Try
## something new, an alcoholic Pour Perfect). DRUNK_FROM, DRUNK_FULL, WASTED_AFTER and the lockout are Daniele's;
## every other number here is provisional, for Daniele to confirm on the Questions tab.
const DRUNK_FROM := 3                 ## the drunk screen effect starts at this many drinks...
const DRUNK_FULL := 10                ## ...and grows to its strongest here
const WASTED_AFTER := 10              ## one more than this: WASTED
const DRUNK_SOBER_MINUTES := 20.0     ## provisional: one drink wears off per 20 game minutes (03-cast §5.1 had a state per 30)
const WATER_SOBER_DRINKS := 2         ## provisional: a glass of water takes two drinks off (it used to drop a state)
const DRUNK_WARN_FROM := 8            ## provisional: from here Nam's line on the Order row is a warning
const WASTED_LOCKOUT_HOURS := 12.0    ## on the game clock, saved; the debug clock (F2, F3) skips it
const WASTED_METER_VALUE := 0.0       ## provisional: "all minor needs unfulfilled" = the four meters to this
const WASTED_LINES := 10              ## nightlife.wasted.line.0..9 in i18n/strings_nightlife.csv, one at random
const SMOKE_SECONDS := 8.0            ## one cigarette; light_one_up lands when it is finished
const PLUMBING_DRINKS_TO := 0.0       ## Daniele: Check the plumbing resets the drink need to 0


## Stake stage for `days` since the last counting visit (06-stakes §10.1); never `ghost` or `deleted` (see Needs.stake_stage).
static func stake_stage(days: float) -> String:
	for t in STAKE_STAGES:
		if days >= t[1]:
			return t[0]
	return "fine"


## Vibe state for a Vibe value (§2.2).
static func vibe_state(vibe: float) -> String:
	for t in VIBE_THRESHOLDS:
		if vibe >= t[1]:
			return t[0]
	return VIBE_HOMEBODY


## Decay rate per real hour for a meter, with the personality modifier applied (§2.1).
static func decay_rate(meter: String, personality: String = "") -> float:
	var r: float = DECAY_PER_HOUR[meter]
	if PERSONALITIES.get(personality, "") == meter:
		r *= PERSONALITY_DECAY_MULT
	return r


## Gain multiplier for an action: Welcome Back x2 replaces the daily visit multiplier, never stacks (DECISIONS (b)).
static func gain_mult(visit_number: int, welcome: bool) -> float:
	return WELCOME_BACK_GAIN_MULT if welcome else daily_mult(visit_number)


## Daily visit multiplier for the n-th visit (1-based) of a day (§2.4).
static func daily_mult(visit_number: int) -> float:
	return DAILY_VISIT_MULT[clampi(visit_number - 1, 0, DAILY_VISIT_MULT.size() - 1)]
