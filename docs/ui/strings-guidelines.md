# Black Cabin Tamagotchi — String Table Guidelines

Status: v1, 2026-10-27. Owner: session 2B. English and Thai ship together
(DECISIONS.md); Thai is a first-class language, not a translation pass.

## 1. Where strings live

- One table: `game/i18n/strings.csv`, columns `key,en,th,context,max`.
  Godot imports it as a Translation; code calls `tr("key")`.
- No user-facing text in scenes or scripts, including debug-visible labels
  that might ship. A string missing a `th` value fails the export check.
- `context` is mandatory: where it appears, who says it, what fills each
  placeholder. Translators see only the table.
- `max` is the length budget for that key (section 4), in grapheme clusters.

## 2. Keys

- Format: `screen.element.variant`, lowercase snake_case, ASCII only.
  Examples: `flat.cta.go_out`, `flat.cta.go_out_welcome_back`,
  `hud.next_set`, `sheet.bar.order`, `need.music.name`,
  `vibe.glowing`, `mg.pour.tier_3`, `npc.mali.greet.hearts_2`.
- Keys describe meaning, not wording: `sheet.bar.order`, not
  `sheet.bar.order_a_drink`. Wording can change; keys cannot.
- Never build a sentence from fragments ("You got" + N + "points"). One key
  per full sentence, with named placeholders.
- Reuse a key only when meaning *and* context match. "Done" on a result card
  and "Done" in the wall editor are two keys; Thai may want different words.

## 3. Placeholders, numbers, plurals

- Named placeholders in braces: `{name}`, `{count}`, `{minutes}`,
  `{regular}`. Never positional `%s`; Thai word order differs.
- **Plurals:** Thai has no grammatical plural; English has one/other. Use
  paired keys with a `_one` / `_other` suffix, resolved by a helper
  `trn(key, count)`:
  `recap.nights_one` = "{count} night out", `recap.nights_other` =
  "{count} nights out", `th` for both = "ออกไป {count} คืน". The helper
  falls back to `_other` when `_one` is absent, so Thai fills only `_other`.
- **Counters and classifiers:** Thai counts with a classifier (เพลง for
  songs, แก้ว for glasses, คืน for nights). Keep the noun inside the string,
  never as a separate "unit" key.
- **Numbers:** Arabic digits in both languages (no Thai numerals). Format
  thousands with a comma in both.
- **Dates and times:** formatted by code from the locale, never in a string.
  English: "Tue 27 Oct", "21:14". Thai: "อ. 27 ต.ค.", "21:14 น." The year,
  where shown, is Gregorian in English and Buddhist Era (+543) in Thai
  (2026 → 2569). Clock is 24-hour in both.
- **Names** in placeholders (`{regular}`, player name) are never translated
  or transliterated by code; each regular has an authored `en` and `th`
  display name in the cast table.

## 4. Length budgets

Budgets are in grapheme clusters (a Thai base letter with its vowel and tone
marks counts as one). Thai usually runs shorter than English in characters
but taller on screen; the budget is the same for both, and the layout
reserves Thai line-height.

| Component | Max | Lines | Notes |
|---|---|---|---|
| Primary button | 18 | 1 | Never wraps; shrink-to-fit is forbidden |
| Secondary / ghost button | 14 | 1 | |
| Tab label | 10 | 1 | Creator and album tabs share a row of 4–5 |
| Meter name | 10 | 1 | `display.s` |
| Zone name | 16 | 1 | |
| Sheet action title | 26 | 1 | |
| Sheet action sub-line | 34 | 1 | |
| Toast | 40 | 1 | |
| Context hint | 50 | 2 | |
| Speech bubble line | 90 | 3 | Longer lines split into two keys (`_a`, `_b`) |
| Candle Talk topic card | 22 | 2 | 3 cards side by side |
| Postcard | 120 | 4 | |
| Memory caption | 40 | 2 | |
| Recap stat | 32 | 1 | |
| Settings row | 28 | 1 | |
| Disabled-reason caption | 40 | 1 | |
| Push notification (later) | 60 | 1 | OS truncates |

A CI check fails any value over `max`. Test both languages at 130% text
size; if Thai breaks a layout, fix the layout before shortening the Thai.

## 5. Brand-fixed strings

These are never translated, transliterated or restyled, and are not in the
translatable columns (they live in `brand.*` keys with `th` = `en`):

- **BLACK CABIN** — always Latin capitals. As a logo it is the neon asset;
  in running text it is typeset as "BLACK CABIN" in both languages
  (not "แบล็ค เคบิน").
- Performer and band names as the performers spell them.
- Real staff names when the venue supplies them; their Thai spelling comes
  from the person, not from us.
- Drink brand names, if any are licensed.

Game terms that *are* translated but must be consistent use a glossary
(`docs/ui/glossary.csv`, to be created with the first Thai pass): the four
needs, Vibe states, memory types, minigame names, Regular Rank titles.
Proposed rule: minigame names stay English in both languages (they read as
names on the arcade and the bar menu), with a Thai subtitle key
(`mg.pour.subtitle`).

## 6. Voice

- Warm, short, bar-staff friendly. Second person, present tense.
- Never guilt: banned in both languages are "abandoned", "neglected",
  "forgot", "miss out", and their Thai equivalents (ทอดทิ้ง, ละเลย, ลืม).
- English uses sentence case; only `display.s` labels render uppercase, by
  style, not in the string.
- Thai uses a casual-polite register (no ครับ/ค่ะ particles in UI chrome;
  regulars may use them in dialogue, per their character in the cast bible).
  Gendered particles in player-facing system text are avoided.
- Punctuation: Thai uses a space, not a full stop, between sentences in
  dialogue; no exclamation stacking in either language.

## 7. Process

A native Bangkok Thai writer writes `th` from `context`, not as a literal
translation of `en`; every string is reviewed in-game in both languages
before it is final.
