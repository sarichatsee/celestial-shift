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

## The four levels of the full game (HANDOVER.md section 4.1). `window` names a
## list in the saved storm data (storms_data.gd); the first entry of that list is
## the level's real stretch of 2024. The on-screen names live in game_text.gd.
##
## The last three keys are for the stars and the missions, which the simulator
## does not have (see "Stars and missions" below):
##   science_goal       science to earn on this level for the second star  [TUNE]
##   missions_per_half  missions Mission Control posts by day, and again by night
##   missions_goal      missions to finish on this level for the third star  [TUNE]
const LEVELS := [
	{"name": "First Night", "food": false, "window": "", "science_goal": 22, "missions_per_half": 2, "missions_goal": 2},
	{"name": "Green Thumb", "food": true, "window": "", "science_goal": 20, "missions_per_half": 2, "missions_goal": 2},
	{"name": "Space Weather", "food": true, "window": "space_weather", "science_goal": 16, "missions_per_half": 2, "missions_goal": 2},
	{"name": "The Big One", "food": true, "window": "big_one", "science_goal": 14, "missions_per_half": 2, "missions_goal": 2},
]

## The short game, for younger players: three levels of 8 turns (4 day, 4 night)
## and no food or water. SHORT lists only the numbers that differ from DEFAULTS;
## every other rule is the same.
const SHORT := {
	"TURNS_PER_LEVEL": 8,  # [TUNE]
	"DAY_TURNS": 4,  # [TUNE]
}

## `offset` skips that many turns of the saved real window, so a short level
## plays a real, unbroken 16 days out of the 28:
##   Space Weather  21 Jan to 5 Feb 2024   one alert with no storm, then one real storm
##   The Big One    9 to 24 May 2024       three real storms in a row, then two quiet alerts
const LEVELS_SHORT := [
	{"name": "First Night", "food": false, "window": "", "offset": 0, "science_goal": 12, "missions_per_half": 1, "missions_goal": 1},
	{"name": "Space Weather", "food": false, "window": "space_weather", "offset": 4, "science_goal": 12, "missions_per_half": 1, "missions_goal": 1},
	{"name": "The Big One", "food": false, "window": "big_one", "offset": 2, "science_goal": 10, "missions_per_half": 1, "missions_goal": 1},
]

## Stars and missions. These are game rules made for this version; they are not
## in tools/balance_sim.py and they never change the simulator's numbers: a
## mission's reward is kept apart from the science the simulator counts.
##
## A mission is posted for one turn and asks something of that turn's plan:
##   when      "any", "day" or "night"
##   food      true: only on levels with the greenhouse
##   key       the part of the plan it looks at
##   at_least  the amount to reach ("greenhouse" just has to be on)
##   reward    bonus science for doing it  [TUNE]
const MISSIONS := [
	{"id": "sample_run", "when": "any", "food": false, "key": "science", "at_least": 3, "reward": 2},
	{"id": "big_experiment", "when": "day", "food": false, "key": "science", "at_least": 5, "reward": 4},
	{"id": "night_survey", "when": "night", "food": false, "key": "science", "at_least": 3, "reward": 4},
	{"id": "charge_up", "when": "day", "food": false, "key": "charge", "at_least": 5, "reward": 3},
	{"id": "deep_clean", "when": "any", "food": false, "key": "life_support", "at_least": 4, "reward": 2},
	{"id": "dig_crew", "when": "any", "food": false, "key": "shield", "at_least": 4, "reward": 3},
	{"id": "night_harvest", "when": "night", "food": true, "key": "greenhouse", "reward": 4},
]
## When the shield is already full, "dig_crew" is posted as this mission instead.
const MISSION_WHEN_SHIELD_FULL := "sample_run"
