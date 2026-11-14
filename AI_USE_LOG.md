# AI-use log

One line per session or milestone: date, tool, what it produced or changed.

- 2026-11-14 · Claude Code (Opus 5.5) · Produced the balance simulator (`tools/balance_sim.py`), the 2024 storm extract (`tools/donki_alerts_2024.json`) and the handover brief (`HANDOVER.md`).
- 2026-11-14 · Claude Fable 5.2 coding agent · M1: wrote `game/data.js` (numbers), `game/game.js` (rules engine, no DOM), `tests/run.js` (unit tests) and a console-play `game/index.html`.
- 2026-11-14 · Claude Fable 5.2 coding agent · M2: wrote `tools/build_storms.py` (offline and online builds), generated `game/storms.js` from DONKI and RadLab, and added storm, no-peeking and simulator-parity tests.
- 2026-11-14 · Claude Fable 5.2 coding agent · M3: wrote the game screen (`game/index.html`, `style.css`, `ui.js`), all on-screen words (`text.js`), a placeholder base picture (`base.js`, `base.css`) and text/page tests.
- 2026-11-14 · Claude Fable 5.2 coding agent · M4: added the storm alert box (flare class, dots out of 10, Shelter/Stay), the after-turn storm report, and the debrief with real-date storm cards, DONKI links, tips and retry/next buttons.
- 2026-11-14 · Claude Fable 5.2 coding agent · M5: added the title screen, level intros with real dates, the Science Behind It page, the battery chart, the Moon radiation chart (RadLab data from the online build) and the recycler line.
- 2026-11-14 · Claude Fable 5.2 coding agent · Godot port: rewrote the game in Godot 4 on branch `godot-lunar-night-shift` in the style of the Orbit 27 prototype (`game_state.gd`, `game_numbers.gd`, `game_text.gd`, `main.gd`, `main.tscn`, UI helpers, `tests/run_tests.gd`), changed `tools/build_storms.py` to write `storms_data.gd`, and added the live Sun panel and beeps. Written without a Godot install on the machine: not yet run.
- 2026-11-14 · Claude Fable 5.2 coding agent · Godot port, first run: installed Godot 4.7.2 and ran the game. All 64 tests passed unchanged. Fixed four layout bugs found by playing it (last-turn report covered the screen, hidden "Not made or endorsed by NASA" footer, storm alert over the meters, "NEW" tab badge over the Radiation label), made card screens open at the top, added the Godot `.uid` files and `tools/.gdignore`.
