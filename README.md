# Lunar Night Shift — balanced browser game

Open `game/index.html` in a browser. No installation or server is required.

- Easy has one two-step mission, three stars and supplies between stages.
- Medium/Hard retain longer missions, radiation restrictions and remote repairs.
- NASA DONKI records and retrieval metadata are bundled for offline play.
- Run checks with `node tests/run.js`.
- See `game/README.md` for rules, data refresh and validation details.

Legacy `tools/balance_sim.py`, `tools/build_storms.py`, `game/data.js`, `game/storms.js` and `game/text.js` are retained for reference and are not used by the current game. Refresh current data with `game/tools/fetch_nasa.py`.

---

## Original Godot prototype
# Orbit 27 · Godot 4 controls prototype

Unzip the project. In Godot 4 Project Manager, choose **Import**, select
`project.godot`, and open it. Press **F5** to run. This is a separate 2D
project you can use to demo the controls before integrating them.

## Add your artwork

The project runs with labeled placeholders. Copy your PNGs into `assets/`:

| File | When shown |
| --- | --- |
| `orbit.png` | Orbit view |
| `greenhouse_plant0.png` | Greenhouse is empty or the crop is still growing |
| `greenhouse_plant1.png` | Greenhouse crop is ready to harvest |

You can also select the root node in `main.tscn` and assign the three
textures in the Inspector. Inspector assignments take priority. The canvas
is 1280 × 720 and the images fill it.

## Show the team

Switch between **Orbit** and **Greenhouse** with the tabs or **1** / **2**.
Navigation is free. Each action advances nine days. The storm hits on the
third action, at day 27.

- **Get supplies.** In Orbit, click **Scan Sun** to record the flare
  strength, then **Request supplies** to send the report to Earth. Take
  your last action and start the next cycle to receive three food. A
  report can only be sent once, and a new scan is available each cycle.
- **Get fired.** Restart, then click **Request supplies** three times
  without scanning. Each denial costs one point on the job standing bar.
  At zero, the mission ends. A successful report restores one point up
  to the maximum of three. You can also skip contacting Earth.
- **See the storm trade-off.** In cycle one, plant a potato, scan the
  Sun, then choose between sending the report for food or raising the
  shields to save the crop. A strong storm destroys an unshielded crop.
  A mild storm leaves it intact. The demo alternates strong and mild
  storms, starting with strong.
- **Show the greenhouse art.** Plant a radish, advance time to day 18,
  and harvest it for two food. The art switches to state 1 once the crop
  is harvestable.

## Code map

- `game_state.gd` owns the cycle, crops, storms, job standing, and supply deliveries.
- `main.gd` connects buttons and updates the views and HUD.
- `main.tscn` contains the editable UI and background.
