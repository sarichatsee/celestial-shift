# Lunar Night Shift · Godot 4

A game for kids aged 7 to 12, built for NASA Space Apps 2026 ("Build a Junior
Astronaut Mission Trainer"). You keep a Moon base running for four levels of
14 turns. Every turn you share one power budget between life support, the
shield, science, charging the battery and the greenhouse. Real solar flares
from NASA's DONKI database set off storm alerts: shelter, or stay and do
science? The real record decides what happened, and the debrief shows the
real dates.

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
exactly the stars, radiation and shield that `tools/balance_sim.py` prints
(HANDOVER.md section 9.2).

## How a turn works

- **Day (turns 1 to 7):** the sun gives 10 power. Power you don't spend is lost.
- **Night (turns 8 to 14):** only the battery. Charge it by day.
- **Life support:** 3 holds Air steady and runs the water recycler.
- **Shield:** 8 power builds one layer. It lasts for the whole game.
- **Science:** 1 power is 1 star. Stars are the score.
- **Greenhouse (from Level 2):** grows 3 food; 1 power by day, 4 at night.
- **Storm alert (Levels 3 and 4):** you see the flare class, a chance in
  dots out of 10, what a storm would add to Radiation in the base and in the
  shelter, and the stars sheltering gives up. Never the outcome. Shelter
  costs 1 power and the turn's science.

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
| `game_numbers.gd` | Every game number, each tagged `[TUNE]`. Change one only with the simulator. |
| `game_text.gd` | Every word a player reads. Unchecked science facts are marked `TODO(verify)`. |
| `storms_data.gd` | Saved NASA data. **Generated** by `tools/build_storms.py`; never edit by hand. |
| `game_state.gd` | The rules. No nodes, no randomness. The only reader of whether a storm followed. |
| `main.gd`, `main.tscn` | The screen: draws the state, reads clicks, calls the rules. |
| `ui_kit.gd` | Colours and small builders, so the look lives in one place. |
| `moon_base_view.gd` | The picture of the Moon base, drawn from the meters and the plan. |
| `bar_chart.gd`, `dot_row.gd` | The debrief charts and the dots (storm chance, shield layers). |
| `live_sun.gd` | "The Sun right now" on the title screen: live DONKI fetch with a saved fallback. |
| `sound_fx.gd` | Beeps made in code (no sound files), with a mute button. |
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

`export_presets.cfg` exports to `web-export/`. The files there, and the copy
at the repo root, are still the Orbit 27 prototype: re-export from the Godot
editor to publish this version.
