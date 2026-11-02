# Stakes rules, as the player meets them

Source: `06-stakes.md` v3 (accepted by Daniele 2026-11-02, answers O1–O4 folded in), built in `dd4e03c`. Numbers live in `game/scripts/rules.gd`. If this page and `06-stakes.md` differ, the design doc wins.

## 1. The idea
Players should grow attached to their character, so losing one must mean something. **One need is fatal: go to Black Cabin, the real one.** Every other need only brings annoyances. Tone: playful ghost and zombie. The character "dies of boredom"; the copy talks about the character, never about the player.

## 2. The needs
| Need | Filled by | If neglected |
|---|---|---|
| **Go to Black Cabin** | A real visit: a table QR check-in, or a memory photo taken at the bar | **Fatal** |
| Drink | Order a drink, Pour Perfect, try a new drink | Thirsty |
| Music | Listen to songs, Front Row Rhythm, applaud | Earworm |
| Chat | Candle Talk, sit at a table, bar chat, a cigarette | Phone face |
| Minigame | Any minigame finished without a miss | Rusty |
| Event calendar | Open the calendar (not built yet) | Out of the loop |

## 3. What counts as a visit
- Only a **real visit** resets the fatal clock: a QR check-in while the bar is open (Tue–Sun 19:00–02:00 Bangkok), or a photo shared at the lounge TV corner on a night you checked in. One per bar night; a night runs 06:00 to 06:00 Bangkok.
- **Until the server exists**, any one refill action in the game stands in (a drink, a chat, a song). It counts the moment it lands. One flag, `REAL_VISIT_REQUIRED`, switches this off later.
- **O1:** the real-visit rule only bites a character that has checked in at the bar at least once.
- A character cannot die mid-visit: if the clock hits 21 days during a visit, death waits until the visit ends.
- **Out of Town** (up to 14 days, once per 30) freezes the clock. It cannot be started once Restless.

## 4. The clock and the warnings
| Days since last visit | Stage | What you see |
|---|---|---|
| 0–10 | Fine | Nothing |
| 10 | Restless | Chip "Restless", paces, a regular's postcard |
| 15 | Fading | Greyed, slumped on the kerb, lamps dim |
| 18 | Last Call | Translucent, chip "Last Call · 3 days", Nam's postcard |
| 21 | Dead, a ghost | A voxel ghost of the character, tombstone sticker on the club door |
| 28, 33 | Ghost reminders | Chip shows days left to bring the character back |
| 35 | Deleted | The farewell card, then a new game |

Days are shown, never a live countdown. Any counting visit before day 21 resets the clock and triggers **Welcome Back** (double gains for 15 minutes); from Last Call it also drops a "Close Call" polaroid.

| Player | Danger |
|---|---|
| 2–3 visits a week | Never |
| 1 visit a week | Never past Fine; Thirsty at most |
| 1 visit every 10–20 days | Warnings, never dead |
| Opens the app after creating, never plays | Dead day 21, deleted day 35 |

## 5. Death, the ghost window, revival
- At day 21 the character becomes a **ghost for 14 days**. Meters, coins and everything freeze; nothing the ghost does counts. It can still walk the club and watch the band.
- **O2:** before the server exists there is **no revival**; the window simply runs out. A debug "Fake check-in" exists for tests only.
- Later: a **QR check-in at the real bar** during the window revives the character, **once per 90 days**.
- A revived character comes back as a zombie for that visit, meters lifted to at least 40, keeps everything, and gets a "Lives: 2" mark.

## 6. Deletion is total
At day 35, or on a voluntary Retire, the character is deleted: look, name, meters, coins, wardrobe, hearts, memories, achievements, minigame bests, leaderboard rows. Nothing survives in the game. What stays: the account (sign-in, settings), real-world vouchers already claimed, and a **farewell card** the player can save or share before it goes. A new game starts from scratch. Retire has a 7-day cooldown.

## 7. Annoyances (stronger, but never touch coins)
A meter annoyance starts when its meter is below 10 and is cleared in the same visit by doing the thing. While any annoyance is on, gains to every other meter are **×0.85 per annoyance** (two on: ×0.72; four: ×0.52).
| Annoyance | Extra friction | Cleared by |
|---|---|---|
| Thirsty (Drink) | Walks 25 % slower | Any drink, water counts |
| Earworm (Music) | Club music ducked −9 dB | Hearing one song |
| Phone face (Chat) | Regulars do not wave you over; one extra tap on the first chat | Any chat |
| Rusty (Minigame) | 2-second fumble, higher miss line on the first minigame | Finishing any minigame |
| Out of the loop (Calendar, 7 days) | "?" on the Tonight board | Opening the calendar |

## 8. Minigames can be missed
- A round below **0.25** is a **miss**: no need gain, no coins, no best. While Rusty, the first round misses below 0.4.
- **3 rounds per minigame per visit**, misses included.
- A missed Candle Talk costs a try, never a heart. A missed Pour Perfect serves no drink.
- Every meter can still be filled to 100 with no coins.

## 9. Why players get attached
The character card ("At Black Cabin since 3 Oct · 23 nights out · Lives 1"), achievement stickers on the club door, "the usual" at the bar after three orders, regulars who remember you, Top patrons on the lounge board and corridor wall, the Flat, and the scar a revival leaves.

## 10. The memory rule (O3)
Only photos shared on a night the player **checked in** count as a memory at the bar. The memory need is the real one: a photo taken at the real Black Cabin and shared at the lounge TV corner.

## 11. The Flat (later unlock)
Rent a room on the second floor: **100 coins** to move in, **20 coins a week** (Mondays 00:00 Bangkok), up to 4 weeks ahead. Rent pauses while Out of Town or a ghost. It never buys relief from needs. If rent lapses: 7 days' grace, then moved out, things to storage, re-rent free of the move-in fee within 30 days.

## 12. Still to build
Retire settings screen, audio duck bus, notifications and postcards beyond the home text, the stitched-scar sticker, the Going bonus (all need push, wardrobe or the calendar), and the real server behind QR check-ins.
