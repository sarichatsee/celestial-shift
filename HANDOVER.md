# Lunar Night Shift: handover for the coding agent

> **Engine change, 2026-11-14.** The team decided to build the game in **Godot 4**, in the style of the
> Orbit 27 controls prototype (this settles the open question in section 3.2 and replaces D4). The rules
> (section 4), the NASA data (section 5), the tests and parity table (section 9) and the facts list
> (section 12) still apply as written. The file layout and the JavaScript interfaces in section 6 are
> replaced by the Godot scripts listed in `README.md`: the same functions exist in `game_state.gd` with
> snake_case names, and `tools/build_storms.py` now writes `storms_data.gd`. The browser build stays on the
> `lunar-night-shift` branch.
>
> **Added 2026-11-15, Godot only.** A short game (three levels of 8 turns, no food or water, playing
> turns 5 to 12 of the Space Weather window and turns 3 to 10 of The Big One window), missions (a job for
> one turn that pays bonus science) and three stars per level (safe, science goal, missions). None of
> this is in `tools/balance_sim.py`. It never changes the numbers in sections 4 and 9: the full game's
> `stars` still counts only science power, mission rewards go to a separate `bonus`, and the parity
> table is tested as before. The new numbers are in `game_numbers.gd` (`SHORT`, `LEVELS_SHORT`,
> `MISSIONS`, and each level's `science_goal` and `missions_goal`).
>
> **Rule change, 2026-11-15 (team decision).** Storm strength now depends on the flare letter the alert
> shows: an M-class storm adds 10 / 7 / 5 / 3 Radiation at shield levels 0 to 3, an X-class storm
> 25 / 16 / 11 / 6. This replaces `DOSE_BY_SHIELD: [20, 13, 9, 5]` wherever sections 4 and 9 mention it.
> The simulator has the rule as the preset `tuned_class` (`DOSE_BY_CLASS`); `tuned_food` still prints the
> old table. The game's numbers are now `tuned_class`, and the table in section 9.2 is what it prints.

You are building **Lunar Night Shift**, a browser game for kids aged 7 to 12, for the NASA Space Apps 2026 hackathon. This file is your complete brief. It replaces the two planning PDFs, which aren't in the repo. Read all of it before you write code.

Written 2026-11-14 (hackathon day 1). Every number below was checked against the balance simulator in `tools/balance_sim.py`. Every NASA data fact marked *verified* was tested against the live APIs that day.

---

## 0. Your job in one paragraph

Build the game as **plain HTML, CSS and JavaScript in a new `game/` folder** (no framework, no build step, no npm packages). The game has 4 levels of 14 turns. Each turn the player splits one power budget between life support, shield, science, charging the battery, and (from Level 2) a greenhouse. Real solar flares from NASA's DONKI database trigger storm alerts, and the player chooses Shelter or Stay. The real record decides whether a storm hit, and the debrief shows the real date. Your engine must reproduce the simulator's results exactly (section 9.2). Work through the milestones in section 10 in order, and keep the game playable after every one.
---

## 1. Context

**Challenge:** "Build a Junior Astronaut Mission Trainer" (NASA Space Apps 2026). Kids aged 7 to 12 run a lunar or Martian outpost, balancing life support, radiation shielding, power and food. Each choice must cost something real.

What the challenge page says makes a solution stand out (design for these):
- **Real NASA data in the mechanics**, attributed inside the tool. Never invented numbers dressed up as real.
- **Linking the shielding decision to actual current space weather**, which is the live panel in section 5.8.
- **Replayability**, so players can try other strategies and learn from failure without feeling punished.
- **A short explanation of which datasets were used and why.**
- **Avoid "safe" choices with no cost, and avoid too many systems at once.** "A simple game that teaches a real constraint beats a beautiful one that doesn't."
- **Browser-playable with no download or account.** Saved data is fine, but never present saved data as live.

**The lesson the player should leave with:** on the Moon everything shares one power supply, so every choice costs something. Sunlight is free but only lasts half the time, so the night must be paid for in advance. Safety costs score, and radiation never goes away.

---

## 2. What's already in the repo

| Path | What it is | Your rule |
|---|---|---|
| `project.godot`, `main.gd`, `game_state.gd`, `main.tscn`, `node_2d.tscn`, `icon.svg*`, `assets/*.png*`, `README.md` | "Orbit 27", an earlier Godot 4 controls prototype with a different design | **Do not modify or delete.** Reference only. |
| `tools/balance_sim.py` | Python balance simulator. It is the **reference implementation of the rules.** | Read it. Don't change presets without a human's OK. |
| `tools/donki_alerts_2024.json` | 136 real 2024 flare alerts from DONKI, with links and whether a particle storm followed | Input for the build script (offline mode) |
| `HANDOVER.md` | This file | Update section 12 when you verify things |

Run the simulator with `python3 tools/balance_sim.py --preset tuned_class --food`.

---

## 3. Decisions

### 3.1 Already made: do not reopen

| ID | Decision |
|---|---|
| D1 | **Turn-based.** No timers, ticks or real-time night. |
| D3 | **4 levels.** Dose (radiation), shield, shield progress and stars carry over between levels. Battery, Air, Food and Water reset each level. |
| D4 | **Plain HTML, CSS and JS** in `game/`. No framework or build tools. It must work by double-clicking `game/index.html` (file://) **and** when served. |
| D5 | Storm levels use **real 2024 DONKI stretches**. The August 1972 storm is only a fact card. |
| D6 | The alert shows the **flare class and a storm chance computed from class alone.** It never shows whether a storm followed. This is the "no peeking" rule. |
| D7 | Sunlight is use-it-or-lose-it. At night you can only spend what the battery holds. |
| D8 | After a loss, the player **retries the same level** with the values it started with. |
| D9 | **Food via a greenhouse switch**, plus a "Green Thumb" level before the storm levels. |
| D10 | **Water is a calm meter.** The recycler is tied to life support, and water should rarely end a game. |
| D11 | Numbers = the simulator's `tuned_class` preset (section 4.10): `tuned_food` plus storm strength by flare letter. |
| D12 | Storm odds come from **real archive rates** (section 5.5), shown as dots out of 10, never as percentages. |

### 3.2 Still open: ask a human, don't decide

- Whether to stay with Godot instead. If anyone says the team switched engines, stop and ask for a new brief.
- Extra years of DONKI data for a random pool of storm stretches. That's a stretch goal; the default is fixed windows.
- Shelter cost 1 vs 2. It's a near-tie in the simulator; use 1 until told otherwise.
- Any science fact not marked *verified* in section 12.

---

## 4. Game rules (the spec)

### 4.1 Levels

| # | Name | Food and water | Storms | What it teaches |
|---|---|---|---|---|
| 1 | First Night | no | none | Sunlight is free but the night must be paid for in advance. Air needs power every turn. |
| 2 | Green Thumb | yes | none | Grow food while the sun shines. The recycler keeps water steady. |
| 3 | Space Weather | yes | real window starting **2024-01-13** | Real alerts. Sheltering costs now; radiation never resets. |
| 4 | The Big One | yes | real window starting **2024-05-05** (the May 2024 storm) | Shielding vs sheltering, short on power and long on danger. |

Win the game by finishing Level 4. The score is stars.

### 4.2 One level = 14 turns

- **Turns 1 to 7 are DAY.** The sun gives 10 power per turn, and power you don't spend is lost.
- **Turns 8 to 14 are NIGHT.** No sun. The player can only spend what the battery holds.
- 1 turn = 2 Earth days. On storm levels, turn *i* covers the real dates `[start + 2(i-1) days, start + 2i days)`, in UTC.

### 4.3 Meters

| Meter (on screen) | Code name | Start | Max / limit | Goes up | Goes down | Lose when | Resets each level? |
|---|---|---|---|---|---|---|---|
| Battery | `battery` | 10 | 40 | Charging in daytime (80% arrives) | Spending at night | (never directly) | yes |
| Air | `air` | 60 | 60 (can't be overfilled) | Life support above 3 (back up to 60) | Life support below 3: 8 per missing power | Air ≤ 0 | yes |
| Water | `water` | 30 | none | never | 1 per turn with the recycler on (life support ≥ 3), 2 per turn if off, plus 1 more in a greenhouse turn | Water < 0 | yes (Levels 2 to 4 only) |
| Food | `food` (days) | 16 (supply lander) | none | Greenhouse +3 per turn | Crew eats 2 per turn | Food < 0 | yes (Levels 2 to 4 only) |
| Radiation | `dose` | 0 | limit 100 | A storm hits | never | Dose ≥ 100 | **no**, carries over all game |

Also on screen: **Stars** (score, carries over), **Shield level 0 to 3** (carries over), and the turn number with DAY/NIGHT. Say "Radiation" on screen and use "dose" only in code.

### 4.4 What the player does each turn (every choice costs something)

| Control | Cost | Gain | Rules |
|---|---|---|---|
| Life support (0 to 5) | 1 power per point | 3 holds Air steady. Each point above 3 adds 8 Air (up to 60). | Below 3 drains Air 8 per missing point **and** stops the water recycler. |
| Shield (+/-) | 8 power per shield level, can be spread over turns | Every later storm does less: an M-class storm 10 / 7 / 5 / 3 and an X-class storm 25 / 16 / 11 / 6 at levels 0 / 1 / 2 / 3 | Max level 3. Permanent; carries over. |
| Science (+/-) | 1 power | 1 star | Nothing for survival. Not allowed while sheltering. |
| Charge battery (+/-) | 1 power puts 0.8 into the battery | Power for the night | **Day only.** Capped at 40. |
| Greenhouse (switch) | 1 power by day, **4 at night** (grow lights) | +3 food, plants drink +1 water | Levels 2 to 4 only. |
| Shelter (alert turns only) | 1 power + no science this turn | Storm radiation 1.5 instead of the full hit (0 if it was a false alarm) | Only offered when there's an alert. |

Budget math for a careful player, so you can sanity-check: the day gives 7 × 10 = 70 power. Life support uses 21 by day and 21 at night. The battery needs about 21 by sunset (10 to start, plus charging 14, of which 11.2 arrives). The greenhouse takes about 4 by day. That leaves about 31 for the shield (24 for a full one) and science.

### 4.5 Storms and the "no peeking" rule

- On a turn with a real alert, the player sees: the flare class (e.g. `X5.8`), a storm-chance picture (dots out of 10 from section 5.5), and two buttons: **Shelter (costs 1 power, no science this turn)** or **Stay in the main base**.
- After the turn, the saved real record decides what happened:

| | A storm really followed | False alarm |
|---|---|---|
| Shelter | Radiation +1.5. Paid 1 power and the turn's science. | No radiation. Paid for nothing. |
| Stay | Radiation by shield level (shield **after** this turn's building): M-class +10 / 7 / 5 / 3, X-class +25 / 16 / 11 / 6 | No radiation. Kept the science. |

- **No peeking:** `followed` lives only inside `game.js`. `alertForTurn()` and `getState()` must never expose it, or anything derived from it, before the turn is played. The debrief may show it for turns already played.

### 4.6 Food and water (Levels 2 to 4)

- A level needs 28 food (14 turns × 2). The lander brings 16, so the greenhouse must run about 4 times. By day that costs 4 power total; at night the same food costs 16.
- Water is a **calm** meter. Careful play ends a level around 11 of 30. An always-on greenhouse brings it down to about 2. The lesson is that the recycler (part of life support) keeps water steady.
- The debrief shows: **"Your recycler saved N water this level."** N = (number of turns with life support ≥ 3) × (2 − 1).

### 4.7 Turn resolution order (exact; must match the simulator)

`takeTurn(plan)`:
1. `checkPlan(plan)`. If it isn't `"ok"`, return `{status: "invalid", message}` and **change nothing**.
2. If night: `battery -= totalSpend(plan)`. By day the sun pays.
3. `air = clamp(air + (lifeSupport − 3) × 8, 0, 60)`.
4. `addToShield(plan.shield)`: progress += power; while progress ≥ 8 and shield < 3, then shield += 1 and progress −= 8.
5. If not sheltering: `stars += science`.
6. If day: `battery = min(40, battery + charge × 0.8)`.
7. If the level has food: if greenhouse, `food += 3` and `water −= 1`. Then `food −= 2`. Then `water −= (lifeSupport ≥ 3 ? 1 : 2)`.
8. `resolveStorm(shelter)`: if this turn has a storm and it followed, `dose += shelter ? 1.5 : DOSE_BY_CLASS[letter the alert shows][shield]`. Log it for the debrief.
9. Push `{turn, battery, air, water, food, dose, plan}` to history.
10. Lose checks **in this order**: air ≤ 0 → `lost/air`; dose ≥ 100 → `lost/dose`; food < 0 → `lost/food`; water < 0 → `lost/water`.
11. If turn == 14: return `level_won`, or `game_won` on Level 4.
12. `turn += 1`, then return `continue`.

`totalSpend(plan)` = lifeSupport + shield + science + charge + (shelter ? 1 : 0) + (greenhouse ? (day ? 1 : 4) : 0).

### 4.8 `checkPlan(plan)` rules (return the first that fails, else `"ok"`)

1. Any negative number → "No negative power"
2. lifeSupport > 5 → "Life support can't go above 5"
3. Night and charge > 0 → "No sunlight: you can't charge at night"
4. Shelter and science > 0 → "No science while sheltering"
5. Shelter on a turn with no alert → "No storm alert this turn" (an addition to the simulator; harmless for parity)
6. Shield already 3 and shield > 0 → "The shield is already full"
7. Greenhouse on a level without food → "No greenhouse on this level"
8. totalSpend > powerAvailable → "Not enough power"

Messages are shown to kids. Keep them short, and keep the words in `text.js` (section 6.5).

### 4.9 Win, lose, retry

- **Lose:** "Mission Control brings the crew home." No death screens. The debrief explains why and offers a one-tap **Retry**.
- **Retry:** restore dose, shield, shieldProgress and stars to the values the level started with, then restart the level.
- **Next level:** dose, shield, shieldProgress and stars carry over.

### 4.10 Numbers (`game/data.js`)

```js
TURNS_PER_LEVEL: 14,  DAY_TURNS: 7,      SOLAR_POWER: 10,
START_BATTERY: 10,    BATTERY_MAX: 40,   CHARGE_EFFICIENCY: 0.8,
START_AIR: 60,        AIR_MAX: 60,       LS_NEEDED: 3,  LS_MAX: 5,  AIR_PER_POWER: 8,
SHIELD_COST: 8,       MAX_SHIELD: 3,     SHELTER_COST: 1,
DOSE_LIMIT: 100,      SHELTER_DOSE: 1.5, DOSE_BY_CLASS: {M: [10, 7, 5, 3], X: [25, 16, 11, 6]},
FOOD_START: 16,       FOOD_EATEN: 2,     FOOD_PER_GREENHOUSE: 3,
GREENHOUSE_DAY: 1,    GREENHOUSE_NIGHT: 4,
WATER_START: 30,      WATER_USED: 1,     WATER_USED_NO_RECYCLER: 2,  GREENHOUSE_WATER: 1,
```

Each number is tagged `// [TUNE]` in code. If a human changes one, re-run the simulator with the same `--set` values and update the parity table.

---

## 5. NASA data

### 5.1 DONKI API facts (*verified* 2026-11-14)

- **DONKI moved on 2026-09-30.** Use `https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD`, and the same with `/SEP` for particle storms.
- **No API key.** Responses send `Access-Control-Allow-Origin: *`, so the browser can call them directly, even from file://.
- **At most 60 days per request.** Longer ranges return the text `API Error: Date range cannot exceed 60 days` (not JSON), so fetch in chunks.
- The old routes are broken: `kauai.ccmc.gsfc.nasa.gov` doesn't connect, and `api.nasa.gov/DONKI/*` returns 404. Don't use either.
- Fields used: on FLR records, `flrID`, `classType`, `peakTime` (`YYYY-MM-DDTHH:MMZ`), `link`, `linkedEvents`, `sentNotifications`. On SEP records, `sepID`, `eventTime`, `linkedEvents`.

### 5.2 Which flares are alerts, and which "followed"

- **Alert** = class X, or class M with magnitude ≥ 5, **and** a non-empty `sentNotifications` (a real alert from NASA's Moon to Mars Space Weather Analysis Office).
- **Followed** = the flare's `linkedEvents` contains an ID with `-SEP-`, **or** any SEP record's `linkedEvents` contains this `flrID`. Check both directions, because the links are not symmetric: in 2024, SEPs point to 39 flares but flares point to only 35.

### 5.3 Turning a real window into a level

For a start date S, turn *i* = `floor((peakTime − S 00:00 UTC) / 2 days) + 1`, kept if 1 to 14. For each turn with alerts:
- **Shown alert** = the strongest flare in that turn (X beats M, then higher magnitude).
- **Followed** = true if **any** alerted flare in that turn followed.
- Keep **all** flares in the turn so the debrief can say which flare brought the storm. The strongest one isn't always it: in turn 5 of the May window, the X8.7 shown did not cause the storm, but another flare that turn did.

### 5.4 Default windows (expected build output; your tests should assert these)

**Space Weather, start 2024-01-13** (runs to 2024-02-09)

| Turn | Shown flare | Peak (UTC) | Storm followed | Alerts in turn |
|---|---|---|---|---|
| 6 | M5.1 | 2024-01-23 03:31 | no | 1 |
| 9 | M6.8 | 2024-01-29 04:38 | yes | 1 |
| 13 | M5.1 | 2024-02-07 03:31 | no | 1 |
| 14 | X3.3 | 2024-02-09 13:14 | yes | 1 |

**The Big One, start 2024-05-05** (runs to 2024-06-01)

| Turn | Shown flare | Peak (UTC) | Storm followed | Alerts in turn |
|---|---|---|---|---|
| 1 | X4.5 | 2024-05-06 06:35 | no | 5 |
| 2 | X1.0 | 2024-05-08 01:41 | yes | 9 |
| 3 | X3.9 | 2024-05-10 06:54 | yes | 4 |
| 4 | X5.8 | 2024-05-11 01:23 | yes | 4 |
| 5 | X8.7 | 2024-05-14 16:51 | yes | 4 |
| 6 | X3.4 | 2024-05-15 08:37 | no | 2 |
| 7 | M7.2 | 2024-05-17 21:08 | no | 1 |
| 12 | X2.8 | 2024-05-27 07:08 | no | 1 |
| 13 | X1.4 | 2024-05-29 14:37 | no | 2 |
| 14 | X1.4 | 2024-06-01 08:48 | no | 4 |

Alternates already checked in the simulator: Space Weather from **2024-08-22** and The Big One from **2024-09-29**. The Big One needs **at least 3 storm turns**, otherwise ignoring storms becomes a safe strategy. 2024 has only two such stretches: start dates 2024-04-15 to 05-09, and 2024-09-29 to 10-09.

### 5.5 Storm chance (dots out of 10)

From 2024 alerts (*verified*): X-class **14 of 54** followed, so **3 of 10 dots**. M5+ **9 of 82** followed, so **1 of 10 dots**. The build script recomputes these from whatever years it loads. Text: "About 3 in 10 flares like this sent a radiation storm." The dots depend on class only (no peeking).

### 5.6 Radiation measured at the Moon (NASA OSDR RadLab, LRO/CRaTER)

- API: `https://visualization.osdr.nasa.gov/radlab/api/?celestial_body=Moon&instrument_id&timestamp>=START&timestamp<END&absorbed_dose_rate&format=csv`
- It returns hourly `absorbed_dose_rate` (µGy/h) from LRO's CRaTER (`instrument_id` like `CRaTER-D1D2`, `trajectory` "Lunar orbit").
- *Verified* values for the May 2024 window, as per-turn mean (max) in µGy/h:
  - t1 5.1 (5.6), t2 5.3 (6.3)
  - t3 120 (1438), t4 663 (1929), t5 946 (3152), t6 367 (624)
  - t7 39 (123), t8 9.1 (12.4)
  - Quiet level ≈ 5 µGy/h. The highest daily mean was ≈ 1,530 on 2024-05-14, about **300× normal**.
- Bake the **per-turn mean** for every window into `storms.js` at build time. In the debrief, show it as bars of "times a quiet day" with storm turns marked. Never use it to decide gameplay.

### 5.7 Build script: `tools/build_storms.py` → `game/storms.js`

- Python 3, standard library only.
- `python3 tools/build_storms.py --offline` builds from `tools/donki_alerts_2024.json` without the internet (no Moon dose; set `moonDose: null`).
- `python3 tools/build_storms.py --years 2024` fetches FLR and SEP in ≤60-day chunks (sleep 1 second between calls), plus RadLab for each window. It caches raw responses in `tools/cache/`, which goes in `.gitignore`.
- Writes `game/storms.js` as a **classic script** (no ES modules, so file:// works):

```js
globalThis.LNS = globalThis.LNS || {};
globalThis.LNS.STORMS = {
  savedOn: "2026-11-14",
  source: "NASA DONKI (ccmc.gsfc.nasa.gov/DONKI), NASA OSDR RadLab (LRO/CRaTER)",
  chance: { X: { followed: 14, total: 54, dots: 3 }, M: { followed: 9, total: 82, dots: 1 } },
  windows: {
    spaceWeather: [ /* default first */ {
      start: "2024-01-13",
      turns: [ { turn: 6, shown: { cls: "M", fullClass: "M5.1", peak: "2024-01-23T03:31Z", link: "https://..." },
                 followed: false,
                 flares: [ { fullClass, peak, link, followed } ] } ],
      moonDose: [ /* 14 numbers, µGy/h per-turn mean, or null */ ]
    } ],
    bigOne: [ { start: "2024-05-05", /* ... */ } ]
  },
  // the last 30 days at build time: the live panel's offline fallback (section 5.8)
  liveSnapshot: { savedOn: "2026-11-14", windowDays: 30, bigFlares: 10, latest: { fullClass, date }, particleStorms: 0 }
};
```

### 5.8 Live panel: "The Sun right now" (title screen; should-have)

- On load, fetch FLR and SEP for the **last 30 days** from the endpoint in 5.1, with a **4-second timeout**. Never block the Start button.
- On success, show: **LIVE · checked HH:MM**, the number of big (M or X) flares in the last 30 days, the latest big flare (class and date), the number of particle storms, and a busy meter: quiet 0–2, busy 3–9, very busy 10+ [TUNE]. As a sanity check, there were 10 M/X flares in the 30 days before 2026-11-14.
- On failure, show the saved numbers from `LNS.STORMS.liveSnapshot`, labelled **"Saved on 14 Nov 2026"**. **Never label saved data as live.**
- Stretch: a "This month's Sun" bonus level built from the last 28 days. Say on screen that storm links for the newest days may still be added by analysts.

### 5.9 Attribution and honesty

- Every storm card has the real date, class, a **DONKI link** (`target="_blank" rel="noopener"`), and the sentence "This flare really happened on 11 May 2024, recorded in NASA's DONKI database."
- The Science Behind It page credits:
  - DONKI (NASA CCMC / Moon to Mars Space Weather Analysis Office)
  - OSDR RadLab (LRO/CRaTER)
  - NOAA's Space Weather Prediction Center, the official US source for space weather forecasts
  - CSA (Canadian Space Agency) education resources, if used
- Footer: "Not made or endorsed by NASA. Uses public NASA data." **No NASA logo or insignia anywhere.**

---

## 6. Architecture

### 6.1 Files

```
game/
  index.html   the only page; loads the scripts in the order below
  style.css    layout, colours, animations
  data.js      LNS.NUMBERS (section 4.10)
  text.js      LNS.TEXT: every kid-facing word (section 6.5)
  storms.js    LNS.STORMS: generated by tools/build_storms.py, never hand-edited (section 5.7)
  game.js      LNS.Engine: the rules. No DOM access at all (section 6.3)
  live.js      LNS.Live: "The Sun right now" fetch with saved fallback (sections 5.8, 6.4)
  sound.js     LNS.Sound: WebAudio beeps and mute (section 6.4)
  base.js      LNS.Base: the base picture, plus base.css (section 6.4)
  ui.js        draws state, reads clicks, calls the engine. Never changes numbers.
  assets/      SVG/PNG, each with a licence note in assets/CREDITS.md
  dev/         dev-only pages (e.g. base-demo.html with sliders for the picture); not linked from the game
tools/build_storms.py         builds game/storms.js (section 5.7)
tools/balance_sim.py          the rules reference (already exists)
tests/run.js                  node tests/run.js, Node built-ins only
.github/workflows/pages.yml   deploys game/ to GitHub Pages (section 13)
AI_USE_LOG.md                 section 14
```

`index.html` loads, in this order: `style.css`, `base.css`, then `data.js`, `text.js`, `storms.js`, `game.js`, `live.js`, `sound.js`, `base.js`, `ui.js` (classic scripts, no modules). The base picture draws inside `#base-picture`.

**All kid-facing text lives in `text.js`**, so wording can change without touching logic. Mark every unchecked fact with `TODO(verify)`.

Keep these modules separate even though one agent writes them all: each can be tested on its own, and a teammate can take one over later.

### 6.2 Three layers

`data.js + storms.js + text.js` (facts, no logic) → `game.js` (rules, never draws) → `ui.js + index.html` (screen, never changes numbers). The screen asks the engine questions and sends the player's plan. That is the whole connection.

### 6.3 Engine API (`LNS.Engine`)

| Function | Returns |
|---|---|
| `startGame()` | – (Level 1, fresh) |
| `getState()` | a **copy**, so changing it changes nothing: `{level, levelCount, turn, turnsPerLevel, isDay, battery, air, water, food, dose, shield, shieldProgress, stars}` (water and food are `null` on Level 1) |
| `getLevelInfo()` | `{index /* 0..3 */, name, hasFood, hasStorms, windowStart /* or null */, turnDates(turn) /* -> {from, to} or null */}` |
| `isDay()` / `powerAvailable()` / `totalSpend(plan)` | bool / number / number |
| `checkPlan(plan)` | `"ok"` or the message text from `LNS.TEXT.messages[key]`, with an English fallback inside `game.js` |
| `alertForTurn()` | `null` or `{cls: "X"\|"M", fullClass: "X5.8", date: "2024-05-11", dots: 3}`, **never** `followed` |
| `takeTurn(plan)` | `{status: "continue" \| "level_won" \| "game_won" \| "lost" \| "invalid", reason?: "air"\|"dose"\|"food"\|"water", message?}` |
| `getDebrief(result)` | see below |
| `nextLevel()` / `retryLevel()` | – |

```js
plan = { lifeSupport, shield, science, charge, shelter, greenhouse }   // numbers and booleans

getDebrief(result) -> {
  result, levelIndex,
  history: [ { turn, battery, air, water, food, dose } ],
  storms:  [ { turn, fullClass, date, link, followed, sheltered, dose,
               causes: [ { fullClass, date, link } ] } ],          // only turns already played
  moonDose: number[14] | null, stormTurns: number[],
  recyclerSaved: number | null,
  tipKey: "lostAir" | "lostDose" | "lostFood" | "lostWater" | "highDose" | "default", tip
}
```

### 6.4 Other modules

```js
// live.js: never rejects; falls back to LNS.STORMS.liveSnapshot
LNS.Live.load({ timeoutMs: 4000 }) -> Promise<{
  mode: "live" | "saved", checkedAt /* ISO, live only */, savedOn /* date, saved only */,
  bigFlares, latest: { fullClass, date } | null, particleStorms,
  busy: "quiet" | "busy" | "veryBusy"        // 0–2 / 3–9 / 10+  [TUNE]
}>

// sound.js: never throws, silent until the first user click
LNS.Sound.play("click" | "alert" | "stormHit" | "shelter" | "levelWon" | "lost")
LNS.Sound.setMuted(bool); LNS.Sound.isMuted()

// base.js: mount once, then update after every change (cheap, idempotent)
LNS.Base.mount(document.getElementById("base-picture"))
LNS.Base.update({
  isDay, turn,
  airPct, batteryPct, dosePct,     // 0..100
  waterPct, foodPct,               // 0..100, or null on Level 1
  shield,                          // 0..3
  lifeSupportOk,                   // plan.lifeSupport >= 3 (also the recycler light)
  sciencePowered, greenhouse /* null | "off" | "on" */, sheltering,
  alert /* null | { cls } */, ended /* null | "won" | "lost" */
})
```

`ui.js` builds the `view` from `getState()` plus the player's current, unsent plan. The picture shows state, it doesn't decorate it:

| Picture | Driven by | How |
|---|---|---|
| Sky | `isDay` | Sun by day, stars and Earth by night |
| Battery bank | `batteryPct` | Fills and drains |
| Life-support room | `airPct`, `lifeSupportOk` | Green when OK, pulsing amber when Air is under 30% |
| Water tank and recycler light | `waterPct`, `lifeSupportOk` | Tank level; light green when on, orange when off; hidden when null |
| Greenhouse | `greenhouse`, `foodPct` | Dark when off, lit when on, plants fuller with more food; hidden when null |
| Science lab | `sciencePowered` | Glows when powered |
| Roof shield | `shield` | 0–3 layers of Moon dirt |
| Shelter room | `sheltering` | Crew icons move into the small shielded room |
| Sun flare | `alert` | Flare on the sun (bigger for X) |
| End | `ended` | Sunrise celebration on "won"; a calm "crew heading home" on "lost" |

### 6.5 `LNS.TEXT` keys

Placeholders are `{name}`, filled by a small `fmt(str, vars)` in `ui.js`.

```js
globalThis.LNS.TEXT = {
  title:    { name, howTo: [line1, line2, line3], start, science, disclaimer },
  levels:   [ { name, intro }, { name, intro }, { name, intro }, { name, intro } ],  // index 0..3
  meters:   { battery, air, water, food, radiation, shield, stars, recyclerOn, recyclerOff, day, night, turn },
  controls: { lifeSupport, shield, science, charge, chargeDayOnly, greenhouse, greenhouseCost, endTurn, powerLeft, mute },
  alert:    { title /* "Mission Control spotted an {fullClass} flare!" */,
              chance /* "About {dots} in 10 flares like this sent a radiation storm." */, shelter, stay },
  messages: { negative, lsMax, noChargeNight, noScienceShelter, noAlert, shieldFull, noGreenhouse,
              notEnoughPower, nightHint, newMeters },
  tips:     { lostAir, lostDose, lostFood, lostWater, highDose, default },
  debrief:  { won, lost, why: { air, dose, food, water },
              stormCard /* "This flare really happened on {date}, recorded in NASA's DONKI database." */,
              followedYes, followedNo, sheltered, stayed, causedBy /* "The storm came from the {fullClass} flare on {date}." */,
              recyclerSaved /* "Your recycler saved {n} water this level." */,
              batteryChart, moonChart, moonChartNote, reflection, next, retry, again },
  live:     { heading, liveLabel /* "LIVE · checked {time}" */, savedLabel /* "Saved on {date}" */,
              bigFlares, latest, particleStorms, quiet, busy, veryBusy },
  science:  { heading, intro, rows: [ { game, real, verified } ], datasets: [ { name, url, why } ], credits, disclaimer }
};
```

### 6.6 Rules for the code

- The engine is deterministic: no `Math.random`. If a random window pool is ever added, pass in a seeded RNG.
- Every script is a **classic script** that attaches to `globalThis.LNS` (that's `window` in the browser), so the same files load in the browser and in `tests/run.js` under Node with `vm`.
- Check first, change second (section 4.7, step 1).
- Store dose as a float and show it rounded.

---

## 7. Screens

1. **Title:** the name, a 3-line how-to-play, **Start**, "Science Behind It", the live Sun panel (5.8), and the footer disclaimer.
2. **Level intro:** 1–2 sentences from `text.js`. Storm levels add the real dates: "This month really happened: 13 January to 9 February 2024."
3. **Game screen** (works at 1366×768, 1024×768 and 768×1024 with no horizontal scroll):

```
+--------------------------------------------------------------------+
| LEVEL 3: Space Weather      Turn 6 of 14   DAY   (23-24 Jan 2024)  |
+-----------------------------+--------------------------------------+
| Battery   [=====.....] 18   |  BASE PICTURE (SVG)                  |
| Air       [========..] 52   |  sky: sun by day, stars by night     |
| Water     [=======...] 24 ● |  rooms light up when powered,        |
|           (● recycler on)   |  flash when in trouble; greenhouse   |
| Food      [====......] 14   |  plants grow; shield layers on roof  |
| Radiation [==........] 20   |                                      |
| Shield (o)(o)( )  Stars 31  |                                      |
+-----------------------------+--------------------------------------+
| ALERT: Mission Control spotted an M5.1 flare!   ●○○○○○○○○○          |
| About 1 in 10 flares like this sent a radiation storm.             |
| [ Shelter (1 power, no science) ]   [ Stay in the main base ]       |
+--------------------------------------------------------------------+
| POWER LEFT: 4                                                      |
| Life support [-] 3 [+]   Shield [-] 0 [+]   Science [-] 3 [+]      |
| Charge [-] 0 [+] (day only)   Greenhouse [ON/OFF] (1 by day, 4 at night) |
| <message from checkPlan>                         [ END TURN ]      |
+--------------------------------------------------------------------+
```

   - Food and Water (and the greenhouse switch) appear from Level 2 with a one-time "New!" hint.
   - The recycler light next to Water: green when life support ≥ 3, orange when off.
   - End turn is disabled while `checkPlan ≠ "ok"`, and the message is shown.
   - **A new turn starts from the previous turn's plan**, with shelter off and charge 0 at night. If it doesn't fit, reduce science, then shield, then greenhouse (never life support) until it does. At sunset show a hint: "Night! Only battery power now."
4. **Debrief** (after every level, win or loss):
   - Headline, why it happened, and **one tip**.
   - Battery bar chart across 14 turns.
   - Storm cards with real dates and DONKI links.
   - On storm levels, the Moon radiation chart.
   - On food levels, the recycler line.
   - The reflection question "What would you do differently next time?"
   - Buttons: Next level, Retry, Play again.
5. **Science Behind It:** a table of what's real and what's simplified:
   - 1 turn = 2 days. A real lunar day and night are each about 14 Earth days.
   - 20% charging loss is a game number.
   - The Radiation bar is a simplified stand-in for real dose in mSv against lifetime limits (`TODO(verify)` against NASA-STD-3001).
   - The storm chance uses only the flare class; real forecasters use more and still get false alarms.
   - Real shelters are thick walls of water, supplies or Moon dirt.
   - Storm particles reach the Moon's night side too.
   - Cosmic rays are not modelled.
   - Crops really take weeks to grow.
   - ISS water recovery is about 98% (`TODO(verify)`).
   - Plus the datasets list and credits (5.9).

**Tips** (`getDebrief`, first match wins):
1. Lost (air): "Life support needs power every turn, even at night. Charge the battery in daylight."
2. Lost (dose): "Radiation never goes away. Build shielding, or shelter when a big flare is spotted."
3. Lost (food): "Grow food while the sun shines: the greenhouse costs 1 power by day but 4 at night."
4. Lost (water): "Keep life support at 3 or more so the water recycler keeps running."
5. Dose > 60: "You made it, but your radiation is high. The next levels have more storms."
6. Otherwise: "Great work. Could you earn more stars without losing safety?"

---

## 8. Kids, accessibility, privacy

- **Words:** short sentences, an icon plus under about 10 words per message, and buttons that say what they do. Explain every number once in a hint.
- **Accessibility:**
  - Tap targets ≥ 44 px, and no dragging.
  - Meters show an icon, text and shape (not colour alone).
  - Keyboard play and visible focus.
  - Respect `prefers-reduced-motion`.
  - A mute button. Sounds come from WebAudio beeps, so there are no licence issues, and nothing plays before the first click.
- **Tone:** tension yes, fright no. No jump scares or death screens.
- **Privacy:** no accounts, analytics, cookies or third-party fonts and CDNs. The only network calls are the optional DONKI live fetch. Saving progress (a stretch goal) goes in `localStorage` wrapped in try/catch.

---

## 9. Testing and verification

### 9.1 Unit tests (`node tests/run.js`)

- Each `checkPlan` rule (4.8), and that an invalid plan changes nothing.
- Each row of the table in 4.4 has its stated effect.
- **No peeking:** `alertForTurn()` and `getState()` contain no `followed` key or value, on any turn.
- Carry-over and reset (4.3), retry restores the level's starting values, and day power is lost.
- `storms.js` default windows match the tables in 5.4.

### 9.2 Parity with the simulator (the acceptance test)

Port `Policy` and the strategy list from `tools/balance_sim.py` (`strategies(p, food=True)`) to `tests/run.js`. Play them through your engine with the default windows, and assert this table. It comes from `python3 tools/balance_sim.py --preset tuned_food --food`:

| Strategy | Result | Stars | Dose | Shield |
|---|---|---|---|---|
| all science, never charge | lost L1 (air) | 49 | 0 | – |
| bank Air by day, never charge | lost L1 (air) | 49 | 0 | – |
| never shelter, no shield | lost L4 (dose) | 107 | 110.0 | – |
| always shelter, no shield | won | 108 | 9.0 | 0 |
| full shield early, never shelter | won | 104 | 33.0 | 3 |
| shelter on X, 1 shield | won | 107 | 14.5 | 1 |
| shelter on X, 2 shields | won | 99 | 12.5 | 2 |
| never use the greenhouse | lost L2 (food) | 60 | 0 | – |
| greenhouse only at night | won | 49 | 14.5 | 1 |
| greenhouse always on | won | 30 | 14.5 | 1 |

"Stars" for a loss = stars at the moment of the loss. If a row disagrees, find the bug by comparing turn by turn with the Python engine. **Never change numbers to make a test pass.** Note that your `checkPlan` rule 5 doesn't affect these policies, because they only shelter on alerts.

### 9.3 Manual checks before calling a milestone done

- Open `game/index.html` by double-click **and** via `python3 -m http.server -d game 8000`.
- Play Level 1 start to finish in under 5 minutes.
- Check 1366×768, 1024×768 and 768×1024 with no horizontal scroll, and with the keyboard only.
- Turn off the network: the title screen shows "Saved on …", and the game is fully playable.

---

## 10. Build order (keep it playable after every step)

| # | Milestone | Done when |
|---|---|---|
| M1 | `data.js`, `game.js`, `tests/run.js` (engine only, Levels 1–2, no storms) | Unit tests pass. Level 1 is playable from the console. |
| M2 | `tools/build_storms.py --offline` → `storms.js`, storms in the engine | 5.4 tables asserted. **Parity table (9.2) passes.** |
| M3 | Game screen: meters, controls, End turn, base picture placeholder | A whole level is playable using only the screen. |
| M4 | Alert box with dots, Shelter/Stay, debrief with storm cards, tips, retry/next | **Must-haves done:** Levels 1–4 playable, real dates in the debrief. |
| M5 | Title, level intros, Science page, battery chart, Moon radiation chart (online build), recycler line | Should-haves done. |
| M6 | Live Sun panel with saved fallback | Works online and offline, labels correct. |
| M7 | Polish: base picture states, sounds and mute, accessibility, responsive, Pages workflow | 9.3 passes on all sizes. |
| Stretch | More DONKI years and a random window pool (Big One windows need ≥3 storm turns); "This month's Sun" level; upgrade between levels; hint mode; saved progress; read-aloud (`speechSynthesis`) | Only after M7, and only if a human agrees. |

If time runs short, cut from the bottom. **Never cut the real storms or the debrief.** The live panel is the first should-have to go.

---

## 11. Don'ts

- Don't add frameworks, bundlers, npm packages, CDNs or web fonts.
- Don't touch the Godot prototype files.
- Don't compute anything the player sees from `followed` before the turn is played.
- Don't present saved data as live, and don't invent dates or numbers. Every storm comes from DONKI.
- Don't use the NASA logo, or wording that suggests NASA made or endorses the game.
- Don't use photos, video or voices of anyone under 18 in anything you produce.
- Don't change the `[TUNE]` numbers without a human, and if they change, re-run the simulator.
- Don't push to `main`. Work on a branch, make small commits, and keep the game working after each one.

---

## 12. Facts: verified vs to verify

**Verified on 2026-11-14 (APIs):**
- The DONKI move, endpoint, 60-day limit, CORS and broken old routes (5.1).
- The 2024 alert counts and odds (5.5).
- The window tables (5.4).
- The CRaTER May 2024 values (5.6).
- 10 M/X flares in the 30 days before 2026-11-14.

**Checked by the team on 2026-11-15** (the team said so; the coding agent did not check these):
- Every Science page row that was marked `TODO(verify)` on that date: lunar day and night, battery
  losses, the Radiation bar and career limits, what shelters are made of, storms at night, cosmic rays,
  crop growth, ISS water recovery.
- How the May 2024 storm is described in the Level 4 intro.

**Researched by the coding agent on 2026-11-15 from NASA Science pages, and marked as checked by the
team the same day.** The sentences used are quoted above each row in `game_text.gd`.
- `why_moon`: Earth has an atmosphere and a global magnetic field; the Moon has neither
  (https://science.nasa.gov/moon/solar-wind/).
- `flare_classes`: classes A, B, C, M, X, each 10 times stronger than the one before
  (https://science.nasa.gov/sun/solar-storms-and-flares/).
- `flare_vs_storm`: a flare is light (about 8 minutes to Earth); a radiation storm is fast particles
  (about 30 minutes or less for the fastest) (same page).

**Written by the coding agent on 2026-11-15 and marked as checked by the team the same day:**
- `storm_strength` (Science page only): "A bigger flare does not always mean a bigger radiation storm",
  with the M6.8 and X3.3 turns of the saved Moon measurements as the example (365.25 and 363.36).

**Still to verify (your human checks these; mark them in `game_text.gd` with `TODO(verify)` and never mark one verified yourself):**
- The August 1972 storm between Apollo 16 and 17 (not used in the game).
- NASA Veggie and CSA food-production facts beyond "real crops take weeks to grow" (not used in the game).
- Any other science sentence you write.

---

## 13. Hosting

Add `.github/workflows/pages.yml` that uploads `game/` with `actions/upload-pages-artifact` and deploys with `actions/deploy-pages`. A human must enable Pages (Settings → Pages → Source: GitHub Actions). Don't do that yourself.

## 14. AI-use log

The challenge rules require a description of how AI tools were used. Append one line per session to `AI_USE_LOG.md`, with the date, the tool (e.g. "Claude Fable 5.2 coding agent") and what it produced or changed. Earlier work: the balance simulator, the 2024 storm extract and this handover were produced with Claude Code (Opus 5.5) on 2026-11-14.
