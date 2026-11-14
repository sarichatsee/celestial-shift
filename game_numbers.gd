extends RefCounted
## The numbers of Lunar Night Shift. Facts only, no logic.
##
## Every number is the balance simulator's `tuned_food` preset
## (tools/balance_sim.py, HANDOVER.md section 4.10). Do not change a [TUNE]
## number without a human: re-run the simulator with the same --set values and
## update the parity table in tests/run_tests.gd.

const DEFAULTS := {
	"TURNS_PER_LEVEL": 14,  # [TUNE] turns in one level (1 turn = 2 Earth days)
	"DAY_TURNS": 7,  # [TUNE] turns 1..7 are day, the rest are night
	"SOLAR_POWER": 10,  # [TUNE] power from the sun in a day turn (use it or lose it)
	"START_BATTERY": 10,  # [TUNE] battery at the start of every level
	"BATTERY_MAX": 40,  # [TUNE] the battery can't hold more than this
	"CHARGE_EFFICIENCY": 0.8,  # [TUNE] 1 power spent on charging puts this much in the battery
	"START_AIR": 60,  # [TUNE] Air at the start of every level
	"AIR_MAX": 60,  # [TUNE] Air can't be overfilled
	"LS_NEEDED": 3,  # [TUNE] life support that holds Air steady (and runs the recycler)
	"LS_MAX": 5,  # [TUNE] the most life support in one turn
	"AIR_PER_POWER": 8,  # [TUNE] Air gained or lost per life-support point above or below LS_NEEDED
	"SHIELD_COST": 8,  # [TUNE] power for one shield level
	"MAX_SHIELD": 3,  # [TUNE] highest shield level
	"SHELTER_COST": 1,  # [TUNE] power to shelter for one turn
	"DOSE_LIMIT": 100,  # [TUNE] radiation that ends the mission
	"SHELTER_DOSE": 1.5,  # [TUNE] radiation from a storm while sheltering
	"DOSE_BY_SHIELD": [20, 13, 9, 5],  # [TUNE] radiation from a storm in the main base, by shield level 0..3
	"FOOD_START": 16,  # [TUNE] days of food the supply lander brings each level
	"FOOD_EATEN": 2,  # [TUNE] food the crew eats per turn
	"FOOD_PER_GREENHOUSE": 3,  # [TUNE] food grown in a greenhouse turn
	"GREENHOUSE_DAY": 1,  # [TUNE] greenhouse power by day (sunlight is free)
	"GREENHOUSE_NIGHT": 4,  # [TUNE] greenhouse power at night (grow lights)
	"WATER_START": 30,  # [TUNE] water in the tank at the start of a level
	"WATER_USED": 1,  # [TUNE] water lost per turn with the recycler on
	"WATER_USED_NO_RECYCLER": 2,  # [TUNE] water lost per turn with the recycler off
	"GREENHOUSE_WATER": 1,  # [TUNE] extra water the plants drink in a greenhouse turn
}

## The four levels (HANDOVER.md section 4.1). `window` names a list in the saved
## storm data (storms_data.gd); the first entry of that list is the level's real
## stretch of 2024. The on-screen names live in game_text.gd.
const LEVELS := [
	{"name": "First Night", "food": false, "window": ""},
	{"name": "Green Thumb", "food": true, "window": ""},
	{"name": "Space Weather", "food": true, "window": "space_weather"},
	{"name": "The Big One", "food": true, "window": "big_one"},
]
