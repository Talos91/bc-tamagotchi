# Black Cabin Tamagotchi — Coins

Status: draft v1 (2026-10-28). Reads: `DECISIONS.md` (coins yes, decor no;
the app is a bridge to the real bar), `02-gdd.md` §2, §5–§12, §14,
`03-cast.md` §5, `ui/style-guide.md`. Replaces "Cabin Tokens" in GDD §5.3,
§10.1 and §12. The real-world bridge gets its own chapter; §7 here covers only
what coins can do there.

---

## 1. Role

Coins are **the tab you run at your local**: a quiet record that you've been
coming in, which buys you choice (which drink, which shirt, which frame) and,
through the bridge, a small thank-you at the real bar. They are never the
reason to visit. Needs are.

| Coins must never… | Because |
|---|---|
| Gate a need refill. Every need point a coin can reach is reachable free in the same visit (§5). | Pillar 1: going out is the care, not paying. |
| Buy decay freezes, multipliers, hearts, ranks or memories directly | Relief from needs for coins is anxiety monetisation (GDD §12). |
| Decorate, build or change the venue | Pillar 3 and DECISIONS: the room is authored. The Flat's frames are personal, not venue. |
| Be lost: no expiry, no cap on balance, no going negative, no penalty for absence or neglect | Neglect stakes (DECISIONS) belong to needs, not the wallet. Taking coins away would make the bridge feel punitive. |
| Create time pressure: no sales timers, rotating shops, "only N left", "5 more coins!" nudges | GDD §10.2 bans FOMO. |
| Make alcohol cheaper than non-alcohol | A mocktail costs the same as the cocktail in its band (§3.1). No happy-hour multipliers. |
| Look like baht | Glyph is a brass coin with the lamp mark, never ฿. In-game prices must not be read as real bar prices. |
| Move between players | §6. |

---

## 2. Earning

All values are starting numbers for `rules.gd` (§9). Per-visit sources take the
daily visit multiplier (GDD §2.4: ×1.0, ×0.75, ×0.5). Welcome Back does **not**
double coins; it gives a flat gift instead.

| Source | Coins | Limit | First playable |
|---|---|---|---|
| First visit of the (Bangkok) day | 10 | once per day | Yes |
| Minigame result: good / great / perfect tier | 2 / 3 / 5 | first 4 results per visit pay the tier; after that 1 each | Yes |
| Applaud at least once during a set | 1 | 2 sets per visit | Yes |
| Encore present | 3 | per encore | Live-ops |
| New memory dropped | 2 | 3 per visit | Yes |
| Candle Talk heart gained | 10 | per heart (FP max 9 hearts in total) | Yes |
| Welcome Back gift ("This one's on me", plus the float) | 10 | per Welcome Back | Yes |
| Week Recap (Monday) | 5 per day visited last week | max 5 days (25) | Yes |
| Weekly stamp card | 5 per stamp | 4 stamps (20) | Live-ops |
| Starting wallet | 20 | once | Yes |

**Ceilings (because coins have real value through §7):** 60 coins per Bangkok
day and 250 per Bangkok week, all sources. Past the ceiling, results still
show their tier and need gains; the coin line reads "That's plenty for
tonight" (same caption as the minigame AGAIN rule). A normal player never sees it.

### 2.1 Weekly budget

| Source | 3-visit player (Tue, Thu, Sat) | 7-visit player (one a day) |
|---|---|---|
| First visit of the day | 30 | 70 |
| Minigames (4 per visit, mostly great) | 36 | 84 |
| Applause | 3 | 7 |
| New memories (fewer as the album fills) | 12 | 14 |
| Hearts | 10 | 20 |
| Week Recap | 15 | 25 |
| Stamp card (live-ops) | 10 | 20 |
| **Total** | **~115** | **~240** (just under the 250 ceiling) |

Seven visits earn about 2× three visits, not 2.3×: daily players are
rewarded but don't run away.

---

## 3. Spending

### 3.1 The bar menu

**The first drink of every visit is on the house, any drink on the menu**
(Nam: "It's always on the house, the first one"). Water is always free. Pour
Perfect is always free ("You pour, it's on me"). Coins buy the second drink
onward.

| Band | Examples (24 coasters at launch) | Price | Time to afford (3-visit player) |
|---|---|---|---|
| Free | Water, soda water, house drink, any first drink, Pour Perfect | 0 | — |
| Pour | Lager, Thai iced tea, coffee, soft drinks (8) | 4 | a third of a visit |
| Mixed | Highball, whisky soda, house cocktails **and their mocktails** (10) | 6 | half a visit |
| Signature | Staff and regulars' signatures, the weekly featured drink, Hiro's off-menu (6) | 9 | under one visit |

Every paid drink refills Drinks exactly like a free order (+15, GDD §2.3),
through the same diminishing returns. Coins buy variety (coasters faster), a
specific glass in your hand for Cheers, and tipsiness pacing (`03-cast.md` §5).
At Merry, Nam serves water and mocktails only; paid mocktails stay available.

### 3.2 Everything else

| Item | What it does | Price band | Time to afford (3-visit / 7-visit) |
|---|---|---|---|
| **Tip jar** (stage) | One per song break. Crowd Vibe +10 (helps the encore for the whole room), your request vote counts double, the performer nods and may name you in banter ("This one's for…"). No need points. 5 lifetime tips to one act: a "Tip Jar" polaroid with them. | 3 | instant |
| **Buy a round** (at a table, social verb) | Everyone at the table gets their usual: Drinks +10 each (players), a reaction line (regulars). You get Friends +5 through normal diminishing returns. Counts as one shared activity toward a regular's heart, once per regular per week. Once per visit. | 3 per person served (round of 4 = 12) | half a visit |
| **Wardrobe: small** (hat, accessory, held item) | Cosmetic | 30 | 2 visits / 1 day |
| **Wardrobe: mid** (top, bottom, shoes) | Cosmetic | 60 | ~1 week / 3 days |
| **Performer tee** | Unlocks after you've heard that act once; never leaves the rail | 80 | ~1 week / 3 days |
| **Wardrobe: statement** (outer layer, full look) | Cosmetic | 120 | ~1.5 weeks / 4 days |
| **Memory frames** (Flat's Memory Wall) | Wood / brass / velvet-mat / neon-edge / gig-poster. Plain frame is free. | 20 / 35 / 35 / 50 / 50 | 1–2 visits |

Wardrobe pieces live on a **merch rail by the Entrance** (venue dressing that
already exists, not a shop screen). About half of the ~60 launch items are
coin-priced; the rest come from hearts, memories and the stamp card as in GDD
§7.2. Live-ops adds 8–12 cosmetics a month, half coin-priced, which roughly
matches what a 3-visit player saves in a month. Nothing on the rail ever
leaves it.

**Typical spend:** one paid drink, one tip per visit, one round a week ≈ 35
coins. A 3-visit player saves ~80 a week; a 7-visit player ~170.

---

## 4. The wallet in the UI

| Where | How |
|---|---|
| Flat (check-in) | Top right, as in the mockup: coin glyph + number in `caption`, Cream on `bg.base` 80%. No gold, no glow. |
| Venue HUD | Same chip left of the Album button, 60% opacity. Hidden during sets and minigames (HUD compresses). |
| Spending sheets (bar menu, tip jar, round, merch rail) | Balance in the sheet header; prices beside each row. A row you can't afford shows the price at 40% with "Not tonight", never "Need N more". |
| Minigame result card | One line under the need gain: coin glyph "+3". |
| Walk-out summary | One line after the meters: "Coins +24". The only place a total is shown. |
| Week Recap | "Coins +15 for last week" in the card. |

**Celebration without grind:** coins never get their own toast, banner, shower
or sound sting; a soft single clink on the result card is the maximum. The HUD
number updates with a 400 ms roll and nothing else. Gains are always the
second line, under the need, so the night reads first and the money second.
No coin tallies, no streak counters, no "earn N more today".

---

## 5. Coins and needs

| Way to fill Drinks | Coins | Drinks | Extras |
|---|---|---|---|
| First drink of the visit (any drink) | 0 | +15 | +5 and a coaster if new |
| Pour Perfect (repeatable) | 0 | +20–30 | Minigame coins |
| Water | 0 | 0 | Drops one tipsiness state |
| Second drink onward | 4–9 | +15 | Coaster if new; tipsiness if alcoholic |
| Someone buys you a round | 0 | +10 | Friends verb |

**Zero-coin rule:** a player with an empty wallet can fill every meter to 100.
Music (songs, sets, Front Row Rhythm), Friends (Candle Talk, sitting, verbs) and
Nightlife (pinball, dancing, Lounge) never touch coins; Drinks fills from the
free drink plus Pour Perfect. **The GDD §2.3 sample visit costs 0 coins.** A
test in the needs suite should assert it.

**Diminishing returns:** paid and free gains share the same per-visit pool
(GDD §2.4). Buying three extra drinks fills Drinks no faster than pouring
three; coins never raise a ceiling. Whatever the neglect consequence turns out
to be (DECISIONS, open), coins are never the way out of it.

---

## 6. Multiplayer later

| Rule | Detail |
|---|---|
| One wallet per character, server-side from the first sign-in | P1 keeps `coins` and a ledger in the local save. On first sign-in the local balance migrates once, capped at 250 × weeks since install, so edited saves can't seed the server. |
| Presence never shows a balance | Other players see your outfit and your drink, never a price or a wallet. |
| What crosses between players | Consumables you pay for on their behalf: a round (they get a drink), a tip (the room gets Crowd Vibe). Nothing that persists. |
| Never tradeable | Coins, wardrobe items, frames, memories bought or earned, real-world vouchers (§7). The GDD's Swap polaroids stays a 1:1 duplicate swap with no coins attached. |
| Echoes (P2) | Cheering an echo earns its owner the Friends +2, no coins. |
| No marketplace, no gifting of items, no coin transfer | Removes the reason to farm accounts. |

---

## 7. Coins and the real Black Cabin

Coins are the one number that crosses from the game to the bar. That makes
them worth farming, so the design keeps real rewards **small, rare, slow and
verified in person**.

### 7.1 What coins can and can't reach

| Real reward | Coins? | Price / entry | Limit | Time to afford (3-visit) |
|---|---|---|---|---|
| Discount voucher (e.g. 10% off the bill) | Buy | 150 | 1 a week | ~2 weeks of savings |
| A drink at the real bar (house list) | Buy | 300 | 1 a month | ~4 weeks |
| Merch raffle (monthly draw: tee, tote, signed setlist) | Enter | 50 per entry | 3 entries per draw | <1 week |
| Song request slot (real set, that night) | Buy | 100 | 1 a month; the venue sets slots per night; you must be checked in at the real bar | ~1.5 weeks |
| Table booking | **Never** | free service in the app | — | — |
| Real event calendar | **Never** | free | — | — |
| Ordering to the table (if built) | **Never**; paid in real money. A voucher may apply. | — | — | — |

Bookings, the calendar and ordering are **services**: they must work the same
for a new player with 0 coins and a regular with 2,000. A prize you can win
can't be a seat you need.

Real rewards don't refund needs, don't drop memories and don't count toward
in-game unlocks: the game doesn't reward spending real money at the bar
(DECISIONS 21+; also alcohol-promotion law, see §7.5).

### 7.2 Redemption flow (outline)

1. **Claim in the app.** Coins move from wallet to a voucher in the Pocket
   (Album tab). Server records it. The voucher lasts 30 days; **if it expires
   unused, the coins come back** (nothing is lost, §1).
2. **At the bar, tap "Use now".** The app shows a rotating QR and a 4-character
   code, valid 10 minutes, with the reward and the player's character.
3. **Staff verify in seconds.** Staff scan with a staff app, or type the code
   on a staff screen: green tick, reward name, "Mark used". Single use;
   server-side.
4. **One redemption per real visit** (one per account per Bangkok day), so a
   table can't stack phones.

Raffle entries need no staff step; winners get a voucher like any other.

### 7.3 Anti-abuse

| Risk | Rule |
|---|---|
| Farming | Daily 60 / weekly 250 ceilings (§2); minigame coins drop to 1 after 4 results; daily visit multiplier. |
| Edited local saves | Only the server ledger can claim real rewards. Coins earned offline sync with timestamps; the server rejects any day above the ceiling. |
| Multiple accounts | Real rewards need a verified account (phone number), one per person. Optional: 2 weeks of account age before the first claim. |
| Code sharing | Codes rotate, last 10 minutes, are single use and show the character for staff to glance at. |
| Trading | No coin or voucher transfer (§6). |
| Bot minigames | Server sanity checks on score rate per minigame; flagged accounts keep the game, lose claims. |

### 7.4 How it changes the budget

Before the bridge, coins needed no ceiling. Now: hard daily and weekly caps,
real-reward prices pegged to **weeks** of a 3-visit player's surplus (~80 a
week), and monthly limits on the expensive ones. Black Cabin's cost is then
bounded per active player: at most ~4 vouchers, 1 drink, 1 song slot and 3
raffle entries a month. In-game items stay cheap, so most coins still go on
drinks, tips and shirts; the real rewards are a nice surprise, not the job.

### 7.5 Needs a backend (Supabase) or Black Cabin

| Item | Owner |
|---|---|
| Server wallet and ledger, ceilings enforced server-side | Backend |
| Account verification (phone OTP) | Backend |
| Voucher issue, rotating code, single-use check, expiry with refund | Backend |
| Staff verify app or web screen | Backend + Black Cabin staff training |
| Raffle draw and winner notification | Backend |
| Song-slot inventory per night, check-in at the venue | Backend + Black Cabin |
| Reward catalogue and budget per month | Black Cabin |
| Legal check: alcohol promotion and free-drink giveaways under Thai law; raffle (prize draw) rules | Black Cabin / counsel. If free alcohol can't be a prize, the drink reward becomes non-alcoholic or a discount. |

---

## 8. Monetization

**Recommendation: coins are never sold for real money.**

- **21+ and alcohol:** selling a currency that buys drinks is paying real money
  for virtual alcohol, and with §7 for real alcohol vouchers. That is a pay
  path into alcohol promotion and a regulatory risk.
- **The bridge:** if coins can be bought, the real rewards are a discount
  bought in an app store, and anyone can buy a song slot. The value of a
  regular's coin comes from being a regular.
- **The brand:** Black Cabin's warmth is "first one's on the house". A coin
  store turns Nam into a cashier.
- **Pillar 2:** paid coins would make the earn ceilings feel like a paywall.
- **It isn't needed:** the game is commissioned by Black Cabin (DECISIONS),
  so revenue is a bonus, not the brief.

**If premium is needed:** direct-price cosmetics, never coins, never drinks:
performer merch packs (with a revenue share to the real act), a supporter
pack (outfit + frame + name on the in-game chalkboard), seasonal outfit packs.
No loot boxes, no paid raffle entries, no paid pass lane.

---

## 9. First playable cut

GDD §14 excluded "shop and tokens". This adds the smallest loop that proves
coins are fun without a shop.

| In (FP) | Out (live-ops / bridge) |
|---|---|
| Wallet in the save, Flat and HUD chip, result-card and walk-out lines | Merch rail and wardrobe purchases |
| Earning: first visit of the day, minigame tiers, applause, new memory, hearts, Welcome Back, Week Recap, ceilings | Encore, stamp card |
| Spending: second drink onward at the bar (6 FP drinks, 2 per paid band), tip jar for House Lights | Buy a round, performer tees |
| 3 memory frames (20 / 35 / 50) as the one save-up goal | All real-world rewards, server wallet, multiplayer |

**Exit criteria:** testers end every week with more coins than they started
with; no tester says a need was hard to fill for lack of coins; at least half
buy a frame by visit 5; testers can say in one sentence what coins are for.

---

## 10. Constants for `rules.gd`

| Constant | Value |
|---|---|
| `COIN_START` | 20 |
| `COIN_FIRST_VISIT_OF_DAY` | 10 |
| `COIN_MINIGAME_TIER` | `[2, 3, 5]` (good, great, perfect; tiers from `minigame_base.gd` 0.6 / 0.85) |
| `COIN_MINIGAME_FULL_PER_VISIT` | 4 |
| `COIN_MINIGAME_AFTER_FULL` | 1 |
| `COIN_APPLAUD_SET` / `COIN_APPLAUD_SETS_PER_VISIT` | 1 / 2 |
| `COIN_ENCORE` | 3 |
| `COIN_NEW_MEMORY` / `COIN_NEW_MEMORY_PER_VISIT` | 2 / 3 |
| `COIN_HEART` | 10 |
| `COIN_WELCOME_BACK` | 10 |
| `COIN_RECAP_PER_DAY` / `COIN_RECAP_MAX_DAYS` | 5 / 5 |
| `COIN_STAMP` | 5 |
| `COIN_DAILY_MULT` | reuse `DAILY_VISIT_MULT` |
| `COIN_CAP_DAY` / `COIN_CAP_WEEK` | 60 / 250 |
| `FREE_DRINKS_PER_VISIT` | 1 (any drink; water and Pour Perfect always free) |
| `DRINK_PRICE` | `{"free": 0, "pour": 4, "mixed": 6, "signature": 9}` |
| `TIP_PRICE` / `TIP_CROWD_VIBE` / `TIP_VOTE_WEIGHT` | 3 / 10 / 2 |
| `ROUND_PRICE_PER_PERSON` / `ROUND_DRINKS_GAIN` / `ROUND_BUYER_FRIENDS` | 3 / 10 / 5, once per visit |
| `WARDROBE_PRICE` | `{"small": 30, "mid": 60, "tee": 80, "statement": 120}` |
| `FRAME_PRICE` | `{"plain": 0, "wood": 20, "brass": 35, "velvet": 35, "neon": 50, "poster": 50}` |
| `REAL_PRICE` | `{"voucher": 150, "drink": 300, "raffle_entry": 50, "song_slot": 100}` |
| `REAL_VOUCHER_DAYS` / `REAL_CODE_MINUTES` / `REAL_REDEEM_PER_DAY` | 30 / 10 / 1 |
| `COIN_LEDGER_MAX` | 200 (matches `VISIT_LOG_MAX`) |

### 10.1 GDD amendments (one line each)

- **§2.3** Order a drink: "First drink each visit is on the house (any drink); later drinks cost coins (04-coins §3.1); Pour Perfect is always free."
- **§2.5** Welcome Back: "Also gives 10 coins; does not double coin earnings."
- **§5.3** Buy a round: "Spend coins (3 per person) …" replacing "tokens".
- **§6.2** Between songs: "Requests stay free; a tip (3 coins) doubles your vote and adds Crowd Vibe."
- **§7.2** Wardrobe: "the shop" becomes "the merch rail by the Entrance (coins, 04-coins §3.2)".
- **§7.3 / §8** Memory Wall: "Frames: plain free, five styles for coins."
- **§10.1** Weekly stamp card reward: "5 coins per stamp" replacing "token reward".
- **§11** Monthly cosmetics: "about half coin-priced on the merch rail."
- **§12** Replace the Cabin Tokens bullet: "Coins: see 04-coins. Never sold for real money; Night Pass has no paid lane."
- **§14** Out list: "shop and tokens" becomes "merch rail and real-world rewards (a minimal coin loop is in, 04-coins §9)".
