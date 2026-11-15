# Lunar Night Shift · Godot 4

A game for kids aged 7 to 12, built for NASA Space Apps 2026 ("Build a Junior
Astronaut Mission Trainer"). You keep a Moon base running through the long
lunar night. Every turn you share one power budget between life support, the
shield, science, charging the battery and the greenhouse. Real solar flares
from NASA's DONKI database set off storm alerts: shelter, or stay and do
science? The real record decides what happened, and the debrief shows the
real dates.

There are two games on the title screen:

- **Short game:** three levels of 8 turns, no food or water. A good first
  game for younger players. Its storm levels play 16 real days out of the
  full game's 28.
- **Full game:** four levels of 14 turns, with the greenhouse and water.

Every level has **three stars**: keep the crew safe to the end, earn the
level's science goal, and finish enough **missions**. Mission Control posts
a mission about twice each day and twice each night (once in the short
game): a small job for that one turn, such as "put 5 or more power into
Science", that pays bonus science.

It grew out of the **Orbit 27 controls prototype** and keeps its look: the
full-screen artwork, the top bar and the bottom bar. The main view is the
Moon base. Click a building to open its card: what it does, its meter, and
the same control as the bottom bar. The greenhouse card has **Look inside**
(key **2**; **1** or **Esc** goes back). The rules, levels, storm data,
debrief and Science page come from the browser build on the
`lunar-night-shift` branch.

Not made or endorsed by NASA. Uses public NASA data.

## Run it

In the Godot 4 Project Manager choose **Import**, select `project.godot`, open
it and press **F5**. The canvas is 1280 × 720.

Run the tests without opening the editor:

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

The tests include the acceptance test: ten fixed strategies must finish with
exactly the science ("stars" in the simulator), radiation and shield that
`python3 tools/balance_sim.py --preset tuned_class --food` prints
(HANDOVER.md section 9.2). The short game, the
missions and the three stars are not in the simulator. They are kept apart
from its numbers: mission rewards go to a separate bonus count, and the
short game only overrides the number of turns.

## How a turn works

- **Day (turns 1 to 7; 1 to 4 in the short game):** the sun gives 10 power.
  Power you don't spend is lost.
- **Night (turns 8 to 14; 5 to 8 in the short game):** only the battery.
  Charge it by day.
- **Life support:** 3 holds Air steady and runs the water recycler.
- **Shield:** 8 power builds one layer. It lasts for the whole game.
- **Science:** 1 power is 1 science. Each level has a science goal.
- **Missions:** the line above the controls shows this turn's mission, or
  when the next one comes. It turns gold when your plan does it. A science
  mission can't be done from the shelter.
- **Greenhouse (from Level 2):** grows 3 food; 1 power by day, 4 at night.
- **Storm alert (the storm levels):** you see the flare class, a chance in
  dots out of 10, and two buttons that each say what a storm would add to
  Radiation: in the shelter, or in the main base. Never the outcome. Shelter
  costs 1 power and the turn's science.
- **Storm strength:** an X-class storm adds more Radiation than an M-class
  one: 25 against 10 with no shield, and 6 against 3 behind a full shield.

**Real-life facts** appear where they matter, one short sentence each:

- an "In real life" box the first time something happens (night falls, an
  alert, an alert with no storm, a storm that hits, a shield layer, the
  greenhouse, charging). Each fact is told once in a game;
- an "In real life" line on each building's card;
- on the debrief, "What really happened" (your answers to the alerts next
  to the real record) and one question to talk about.

All of them come from the Science page's list. A fact that is not marked
as checked stays on the Science page only, with a "still checking" note.

The controls sit in three boxes: **Keep the base running** (life support,
charging, greenhouse), **Protect the crew** (shield) and **Do science**.

## Add your artwork

The Moon base is drawn in code (`moon_base_view.gd`), so it can show the game
state: the battery filling, shield layers on the roof, the crew moving to the
shelter, a flare on the Sun during an alert. The greenhouse uses PNGs. Copy
yours into `assets/`:

| File | When shown |
| --- | --- |
| `moon_base.png` | Optional. Replaces the drawn Moon base with a still picture (which no longer shows the game state). Keep the buildings where the drawing has them, or move the click areas in `PART_RECTS` in `main.gd` |
| `greenhouse_plant0.png` | Inside the greenhouse, switched off |
| `greenhouse_plant1.png` | Inside the greenhouse, switched on |

You can also select the root node in `main.tscn` and assign the three
textures in the Inspector. Inspector assignments take priority. The images
fill the 1280 × 720 canvas.

## Code map

| File | What it is |
| --- | --- |
| `game_numbers.gd` | Every game number, each tagged `[TUNE]`. Change one only with the simulator. Also the short game's levels, the star goals and the mission list, which the simulator does not have. |
| `game_text.gd` | Every word a player reads, and the one list of real-life facts (`science.rows`). Unchecked facts are marked `TODO(verify)`. |
| `facts.gd` | Chooses which fact to show in play. Only facts a human has checked (`"verified": true`) are shown. |
| `storms_data.gd` | Saved NASA data. **Generated** by `tools/build_storms.py`; never edit by hand. |
| `game_state.gd` | The rules, for both games, with the missions and the stars. No nodes, no randomness. The only reader of whether a storm followed. |
| `main.gd`, `main.tscn` | The screen: draws the state, reads clicks, calls the rules. |
| `ui_kit.gd` | Colours and small builders, so the look lives in one place. |
| `moon_base_view.gd` | The picture of the Moon base, drawn from the meters and the plan. |
| `bar_chart.gd`, `dot_row.gd`, `star_row.gd` | The debrief charts, the dots (storm chance, shield layers) and the stars. |
| `live_sun.gd` | "The Sun right now" on the title screen: live DONKI fetch with a saved fallback. |
| `sound_fx.gd` | Plays the files in `sound_effects/`, with a mute button. A missing file falls back to a beep made in code. |
| `tests/run_tests.gd` | Unit tests, no-peeking tests and the simulator parity test. |
| `tools/balance_sim.py` | The reference implementation of the rules. Don't change it without a human. |
| `tools/build_storms.py` | Builds `storms_data.gd` from DONKI and RadLab (`--offline` uses the saved extract). |
| `HANDOVER.md` | The design brief: rules, data, tests and facts still to verify. |

## Rebuild the NASA data

```bash
python3 tools/build_storms.py --offline
```

```bash
python3 tools/build_storms.py --years 2024
```

The first uses `tools/donki_alerts_2024.json` and needs no internet (no Moon
radiation chart, no saved Sun snapshot). The second fetches DONKI and OSDR
RadLab and caches the raw answers in `tools/cache/`.

## Web build

`web-export/` holds the web build of this game. The hosting service serves
that folder. After changing the game, export it again (this needs Godot's
export templates: **Editor → Manage Export Templates**):

```bash
godot --headless --path . --export-release "Web" "web-export/Orbit 27 - Controls Prototype.html"
```

The file names are still the prototype's so the existing link keeps working.
The export files at the repo root are an old copy of the prototype and are
not used.

### Host it yourself

`web-export/` is a plain static website. Any static host can serve it as it
is; no server code or special headers are needed. Hosts that limit files to
25 MB will not work: the `.wasm` file is about 40 MB.

To try it on your own computer:

```bash
python3 -m http.server -d web-export 8010
```

To publish it with **GitHub Pages** from your own fork, use the workflow
kept in `tools/github-pages-workflow.yml`. It uploads `web-export/` on every
push that changes it. Do these once on github.com, in the fork:

1. On the branch `godot-lunar-night-shift`, choose **Add file → Create new
   file**, name it `.github/workflows/pages.yml`, paste the text of
   `tools/github-pages-workflow.yml` and commit.
2. **Actions** tab: enable workflows.
3. **Settings → Pages → Source:** GitHub Actions.
4. **Settings → Environments → github-pages → Deployment branches:** allow
   `godot-lunar-night-shift` (only the default branch is allowed at first).

Then push, or run "Publish the web build" by hand from the Actions tab. The
game appears at `https://<your-name>.github.io/<repository-name>/`.

In the team's own repository the workflow stays off until someone turns
Pages on there and adds the repository variable `DEPLOY_PAGES` = `true`.
