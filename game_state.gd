extends RefCounted
## The rules of Lunar Night Shift. No nodes, no drawing, no randomness: which
## missions are posted on which turns is worked out from `mission_seed` alone.
##
## The reference implementation is tools/balance_sim.py. take_turn() follows
## HANDOVER.md section 4.7 step by step, and tests/run_tests.gd checks the
## results against the simulator's parity table (section 9.2).
##
## NO PEEKING: whether a storm really followed a flare (`followed`) is read in
## exactly one place before a turn is played: _resolve_storm(), which runs inside
## take_turn(). alert_for_turn() and get_state() never return it or anything
## computed from it. get_debrief() shows it only for turns already played.
##
## A plan is a Dictionary:
##   {"life_support": 3, "shield": 0, "science": 2, "charge": 4, "shelter": false, "greenhouse": true}
##
## STARS AND MISSIONS are extra rules the simulator does not have. They never
## touch the simulator's numbers: a mission's reward goes to `bonus`, not `stars`,
## and everything about them is read through get_progress(), not get_state().
## Missions never look at the storm record.

const Numbers = preload("res://game_numbers.gd")
const StormsData = preload("res://storms_data.gd")
const GameText = preload("res://game_text.gd")

const EPS := 1e-9  # the battery is a float (charging adds 0.8 per power)
const HIGH_DOSE_TIP := 60.0  # the "your radiation is high" tip shows above this

## Copies, so a test can change a number or a storm record without touching the real ones.
var p: Dictionary = Numbers.DEFAULTS.duplicate(true)
var levels: Array = Numbers.LEVELS.duplicate(true)
var storms: Dictionary = StormsData.DATA.duplicate(true)

var level := 1
var turn := 1
var battery := 0.0
var air := 0
var food := 0
var water := 0
var dose := 0.0
var shield := 0
var shield_progress := 0
var stars := 0  # science from the Science control: what the simulator counts

var mode := "full"  # "full" (four levels of 14 turns) or "short" (three levels of 8)
var mission_seed := 0  # decides which missions are posted when; the same seed, the same game
var bonus := 0  # science from missions
var missions_done := 0  # missions finished on this level
var ratings: Array = []  # stars (0 to 3) for each level finished so far, by level index

var _missions := {}  # this level: turn -> mission id
var _mission_log: Array = []  # this level: {turn, id, done, reward} for the turns played
var _phase := "playing"  # "playing", or the status that ended the level
var _history: Array = []
var _storm_log: Array = []
var _level_start: Dictionary = {}
var _last_result: Dictionary = {}


func _init() -> void:
	start_game()


static func new_plan() -> Dictionary:
	return {
		"life_support": 0, "shield": 0, "science": 0, "charge": 0, "shelter": false, "greenhouse": false
	}


# ---------------------------------------------------------------- levels
## Choose the full or the short game. Resets every number to that game's own
## and starts at Level 1.
func set_mode(new_mode: String) -> void:
	mode = "short" if new_mode == "short" else "full"
	p = Numbers.DEFAULTS.duplicate(true)
	if mode == "short":
		p.merge(Numbers.SHORT, true)
		levels = Numbers.LEVELS_SHORT.duplicate(true)
	else:
		levels = Numbers.LEVELS.duplicate(true)
	start_game()


func start_game() -> void:
	dose = 0.0
	shield = 0
	shield_progress = 0
	stars = 0
	bonus = 0
	ratings = []
	_start_level(1)


func _start_level(n: int) -> void:
	level = n
	turn = 1
	battery = float(p["START_BATTERY"])
	air = int(p["START_AIR"])
	# Food and water reset each level, like the battery and the air.
	food = int(p["FOOD_START"]) if has_food() else 0
	water = int(p["WATER_START"]) if has_food() else 0
	_history = []
	_storm_log = []
	_phase = "playing"
	_level_start = {
		"dose": dose, "shield": shield, "shield_progress": shield_progress, "stars": stars, "bonus": bonus,
	}
	_last_result = {}
	missions_done = 0
	_mission_log = []
	_missions = _plan_missions(n)


## Same level again, with the dose, shield and stars it started with.
func retry_level() -> void:
	dose = float(_level_start["dose"])
	shield = int(_level_start["shield"])
	shield_progress = int(_level_start["shield_progress"])
	stars = int(_level_start["stars"])
	bonus = int(_level_start["bonus"])
	_start_level(level)


## Dose, shield, shield progress and stars carry over. Only after a level is won.
func next_level() -> void:
	if _phase != "level_won" or level >= levels.size():
		return
	_start_level(level + 1)


# ---------------------------------------------------------------- questions
func has_food() -> bool:
	return bool(levels[level - 1]["food"])


func is_day() -> bool:
	return turn <= int(p["DAY_TURNS"])


func power_available() -> float:
	if is_day():
		return float(p["SOLAR_POWER"])
	return battery


func total_spend(plan: Dictionary) -> int:
	var spend: int = int(plan["life_support"]) + int(plan["shield"]) + int(plan["science"]) + int(plan["charge"])
	if bool(plan["shelter"]):
		spend += int(p["SHELTER_COST"])
	if bool(plan["greenhouse"]):
		if is_day():
			spend += int(p["GREENHOUSE_DAY"])
		else:
			spend += int(p["GREENHOUSE_NIGHT"])
	return spend


## A copy of everything the screen may show. `water` and `food` are null on Level 1.
func get_state() -> Dictionary:
	var state := {
		"level": level,
		"level_count": levels.size(),
		"turn": turn,
		"turns_per_level": int(p["TURNS_PER_LEVEL"]),
		"is_day": is_day(),
		"battery": battery,
		"air": air,
		"water": null,
		"food": null,
		"dose": dose,
		"shield": shield,
		"shield_progress": shield_progress,
		"stars": stars,
	}
	if has_food():
		state["water"] = water
		state["food"] = food
	return state


## {index, name, has_food, has_storms, window_start}. window_start is "" on levels without storms.
func get_level_info() -> Dictionary:
	var window := _storm_window(level)
	var start := ""
	if not window.is_empty():
		start = _add_days(str(window["start"]), 2 * _offset())
	return {
		"index": level - 1,
		"name": str(level_text()["name"]),
		"has_food": has_food(),
		"has_storms": not window.is_empty(),
		"window_start": start,
	}


## The words for the current level (name, intro): the short game has its own.
func level_text() -> Dictionary:
	return GameText.TEXT["levels_short" if mode == "short" else "levels"][level - 1]


## How many turns of the saved window this level skips (the short game plays
## 16 of the 28 real days).
func _offset() -> int:
	return int(levels[level - 1].get("offset", 0))


## The real dates a turn covers: {"from": "2024-01-23", "to": "2024-01-24"}, both days
## included. Empty on levels without storms.
func turn_dates(for_turn: int) -> Dictionary:
	var window := _storm_window(level)
	if window.is_empty():
		return {}
	var start := _add_days(str(window["start"]), 2 * _offset())
	return {"from": _add_days(start, 2 * (for_turn - 1)), "to": _add_days(start, 2 * for_turn - 1)}


## "ok", or the first rule that fails (HANDOVER.md section 4.8). Changes nothing.
func check_plan(plan: Dictionary) -> String:
	for key in ["life_support", "shield", "science", "charge"]:
		var amount: Variant = plan.get(key, 0)
		if not (amount is int or amount is float) or amount < 0:
			return _message("negative")
	if int(plan["life_support"]) > int(p["LS_MAX"]):
		return _message("ls_max")
	if not is_day() and int(plan["charge"]) > 0:
		return _message("no_charge_night")
	if bool(plan["shelter"]) and int(plan["science"]) > 0:
		return _message("no_science_shelter")
	if bool(plan["shelter"]) and _storm_this_turn().is_empty():
		return _message("no_alert")
	if shield >= int(p["MAX_SHIELD"]) and int(plan["shield"]) > 0:
		return _message("shield_full")
	if bool(plan["greenhouse"]) and not has_food():
		return _message("no_greenhouse")
	if float(total_spend(plan)) > power_available() + EPS:
		return _message("not_enough_power")
	return "ok"


## What the screen is ALLOWED to know about this turn's flare: {cls, full_class, date, dots}.
## Empty when there is no alert. Never `followed`.
func alert_for_turn() -> Dictionary:
	var storm := _storm_this_turn()
	if storm.is_empty():
		return {}
	var shown: Dictionary = storm["shown"]
	var chance: Dictionary = storms["chance"][shown["cls"]]
	return {
		"cls": str(shown["cls"]),
		"full_class": str(shown["full_class"]),
		"date": str(shown["peak"]).substr(0, 10),
		"dots": int(chance["dots"]),  # from the flare class alone: the same for every flare of that class
	}


# ---------------------------------------------------------------- one turn
## Returns {"status": "continue" | "level_won" | "game_won" | "lost" | "invalid"},
## with "reason" ("air", "dose", "food", "water") when lost and "message" when invalid.
func take_turn(plan: Dictionary) -> Dictionary:
	# 1. check first, change second
	if _phase != "playing":
		return {"status": "invalid", "message": _message("level_over")}
	var problem := check_plan(plan)
	if problem != "ok":
		return {"status": "invalid", "message": problem}

	var day := is_day()
	var with_food := has_food()
	var life_support := int(plan["life_support"])
	var sheltered := bool(plan["shelter"])
	# the mission is judged on the plan as it was sent, before anything changes
	var mission := mission_for_turn()
	var mission_done := not mission.is_empty() and mission_met(plan)
	# 2. at night the battery pays; by day the sun does
	if not day:
		battery -= float(total_spend(plan))
	# 3. air
	air = clampi(air + (life_support - int(p["LS_NEEDED"])) * int(p["AIR_PER_POWER"]), 0, int(p["AIR_MAX"]))
	# 4. shield
	_add_to_shield(int(plan["shield"]))
	# 5. science
	if not sheltered:
		stars += int(plan["science"])
	if not mission.is_empty():
		_mission_log.append({
			"turn": turn, "id": str(mission["id"]), "done": mission_done, "reward": int(mission["reward"]),
		})
		if mission_done:
			bonus += int(mission["reward"])
			missions_done += 1
	# 6. charging
	if day:
		battery = minf(float(p["BATTERY_MAX"]), battery + float(int(plan["charge"])) * float(p["CHARGE_EFFICIENCY"]))
	# 7. food and water
	if with_food:
		if bool(plan["greenhouse"]):
			food += int(p["FOOD_PER_GREENHOUSE"])
			water -= int(p["GREENHOUSE_WATER"])
		food -= int(p["FOOD_EATEN"])
		if life_support >= int(p["LS_NEEDED"]):
			water -= int(p["WATER_USED"])
		else:
			water -= int(p["WATER_USED_NO_RECYCLER"])
	# 8. the real record decides
	_resolve_storm(sheltered)
	# 9. history
	var entry := get_state()
	entry["plan"] = plan.duplicate()
	_history.append(entry)
	# 10. lose checks, in this order
	if air <= 0:
		return _end({"status": "lost", "reason": "air"})
	if dose >= float(p["DOSE_LIMIT"]):
		return _end({"status": "lost", "reason": "dose"})
	if with_food and food < 0:
		return _end({"status": "lost", "reason": "food"})
	if with_food and water < 0:
		return _end({"status": "lost", "reason": "water"})
	# 11. the level ends after the last turn
	if turn == int(p["TURNS_PER_LEVEL"]):
		return _end({"status": "game_won" if level == levels.size() else "level_won"})
	# 12. next turn
	turn += 1
	return {"status": "continue"}


## How much Radiation a storm would add this turn IF one comes, with this plan:
## {"stay": in the main base, "shelter": in the shelter}. Numbers only: it uses
## the flare letter the alert shows and never whether a storm followed, so it is
## safe to show before the turn is played. Both are 0 on a turn with no alert.
## Shield power in the plan counts: the shield is built before a storm arrives.
func storm_stakes(plan: Dictionary) -> Dictionary:
	var alert := alert_for_turn()
	if alert.is_empty():
		return {"stay": 0.0, "shelter": 0.0}
	var layers := shield
	var progress := shield_progress + maxi(0, int(plan.get("shield", 0)))
	while progress >= int(p["SHIELD_COST"]) and layers < int(p["MAX_SHIELD"]):
		layers += 1
		progress -= int(p["SHIELD_COST"])
	return {"stay": float(_dose_by_shield(str(alert["cls"]))[layers]), "shelter": float(p["SHELTER_DOSE"])}


## Radiation from a storm in the main base, by shield level, for a flare letter
## ("M" or "X"): an X-class storm hits harder.
func _dose_by_shield(cls: String) -> Array:
	return p["DOSE_BY_CLASS"][cls]


func _add_to_shield(power: int) -> void:
	shield_progress += power
	while shield_progress >= int(p["SHIELD_COST"]) and shield < int(p["MAX_SHIELD"]):
		shield += 1
		shield_progress -= int(p["SHIELD_COST"])


## What REALLY happened, from the saved record. The only reader of `followed`.
func _resolve_storm(sheltered: bool) -> void:
	var storm := _storm_this_turn()
	if storm.is_empty():
		return
	var gained := 0.0
	if bool(storm["followed"]):
		if sheltered:
			gained = float(p["SHELTER_DOSE"])
		else:
			gained = float(_dose_by_shield(str(storm["shown"]["cls"]))[shield])
	dose += gained
	_storm_log.append({"turn": turn, "sheltered": sheltered, "dose": gained, "record": storm})


func _end(result: Dictionary) -> Dictionary:
	_phase = str(result["status"])
	_last_result = result
	if _phase in ["level_won", "game_won"]:
		while ratings.size() < level:
			ratings.append(0)
		ratings[level - 1] = int(get_rating()["stars"])
	return result


# ---------------------------------------------------------------- stars and missions
## Science earned on this level so far, missions included.
func level_science() -> int:
	return (stars + bonus) - (int(_level_start["stars"]) + int(_level_start["bonus"]))


## Everything the screen shows about science, missions and stars.
func get_progress() -> Dictionary:
	var info: Dictionary = levels[level - 1]
	var earned := 0
	for count in ratings:
		earned += int(count)
	return {
		"science": stars + bonus,  # the whole game so far
		"bonus": bonus,
		"level_science": level_science(),
		"science_goal": int(info.get("science_goal", 0)),
		"missions_done": missions_done,
		"missions_goal": int(info.get("missions_goal", 0)),
		"missions_posted": _missions.size(),
		"stars_earned": earned,  # on the levels finished so far
		"stars_possible": 3 * levels.size(),
	}


## The three stars of this level:
##   safe      the crew finished the level
##   science   the level's science goal was reached
##   missions  enough missions were finished
## A level that was not finished earns no stars, whatever else was done.
func get_rating() -> Dictionary:
	var progress := get_progress()
	var safe := _phase in ["level_won", "game_won"]
	var science := int(progress["level_science"]) >= int(progress["science_goal"])
	var missions := int(progress["missions_done"]) >= int(progress["missions_goal"])
	var count := 0
	if safe:
		count = 1 + int(science) + int(missions)
	return {"safe": safe, "science": science, "missions": missions, "stars": count}


## The mission posted for this turn: {id, key, at_least, reward}, or {}.
func mission_for_turn() -> Dictionary:
	return _mission_on(turn)


## The next mission still to come on this level: {turn, mission}, or {}.
## Missions are made up for the game, so showing one early gives nothing away.
func next_mission() -> Dictionary:
	for t in range(turn + 1, int(p["TURNS_PER_LEVEL"]) + 1):
		if _missions.has(t):
			return {"turn": t, "mission": _mission_on(t)}
	return {}


## Would this plan finish this turn's mission? Reads only the plan.
func mission_met(plan: Dictionary) -> bool:
	var mission := mission_for_turn()
	if mission.is_empty():
		return false
	var key := str(mission["key"])
	if key == "greenhouse":
		return bool(plan.get("greenhouse", false))
	if key == "science" and bool(plan.get("shelter", false)):
		return false  # no science is done from the shelter
	return int(plan.get(key, 0)) >= int(mission["at_least"])


func _mission_on(a_turn: int) -> Dictionary:
	if not _missions.has(a_turn):
		return {}
	var id := str(_missions[a_turn])
	if id == "dig_crew" and shield >= int(p["MAX_SHIELD"]):
		id = Numbers.MISSION_WHEN_SHIELD_FULL
	for mission in Numbers.MISSIONS:
		if str(mission["id"]) == id:
			return mission.duplicate()
	return {}


## Which missions are posted on which turns of level n. It depends only on
## `mission_seed`, the game mode and the level, so retrying a level brings the
## same missions back. The very first turn of the game is left free, to learn
## the controls.
func _plan_missions(n: int) -> Dictionary:
	var info: Dictionary = levels[n - 1]
	var per_half := int(info.get("missions_per_half", 0))
	var planned := {}
	if per_half <= 0:
		return planned
	var key := "%d:%d:%s" % [mission_seed, n, mode]
	var day_turns := int(p["DAY_TURNS"])
	var last_turn := int(p["TURNS_PER_LEVEL"])
	var with_food := bool(info["food"])
	var used: Array = []
	for half: String in ["day", "night"]:
		var first := 1 if half == "day" else day_turns + 1
		var final := day_turns if half == "day" else last_turn
		var turns: Array = []
		for t in range(first, final + 1):
			if not (n == 1 and t == 1):
				turns.append(t)
		_shuffle(turns, key + ":turns:" + half)
		var pool: Array = []
		for mission in Numbers.MISSIONS:
			var fits_time := str(mission["when"]) == "any" or str(mission["when"]) == half
			if fits_time and (with_food or not bool(mission["food"])):
				pool.append(str(mission["id"]))
		_shuffle(pool, key + ":pool:" + half)
		for i in mini(per_half, turns.size()):
			# a mission not yet used on this level, if there is one
			var id := str(pool[i % pool.size()])
			for candidate in pool:
				if not used.has(candidate):
					id = str(candidate)
					break
			used.append(id)
			planned[int(turns[i])] = id
	return planned


## Mixes a list in an order that depends only on `key`: the same key, the same order.
func _shuffle(list: Array, key: String) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := int(absi(hash("%s:%d" % [key, i])) % (i + 1))
		var kept: Variant = list[i]
		list[i] = list[j]
		list[j] = kept


# ---------------------------------------------------------------- debrief
## Everything the debrief screen shows. Pass the result that ended the level
## (or nothing, to look at the level so far).
func get_debrief(result: Dictionary = {}) -> Dictionary:
	if result.is_empty():
		result = _last_result if not _last_result.is_empty() else {"status": "continue"}
	var played := _history.size()

	var history: Array = []
	for h in _history:
		history.append({
			"turn": h["turn"], "battery": h["battery"], "air": h["air"], "water": h["water"],
			"food": h["food"], "dose": h["dose"],
		})

	# Only turns already played are in the log, so `followed` may be shown here.
	var cards: Array = []
	var storm_turns: Array = []
	for entry in _storm_log:
		var record: Dictionary = entry["record"]
		var shown: Dictionary = record["shown"]
		var causes: Array = []
		for flare in record["flares"]:
			if bool(flare["followed"]):
				causes.append({
					"full_class": str(flare["full_class"]), "date": str(flare["peak"]).substr(0, 10),
					"link": str(flare["link"]),
				})
		cards.append({
			"turn": int(entry["turn"]),
			"full_class": str(shown["full_class"]),
			"date": str(shown["peak"]).substr(0, 10),
			"link": str(shown["link"]),
			"followed": bool(record["followed"]),
			"sheltered": bool(entry["sheltered"]),
			"dose": float(entry["dose"]),
			"causes": causes,
		})
		if bool(record["followed"]):
			storm_turns.append(int(entry["turn"]))

	# Measured radiation at the Moon, for the chart. Turns not yet played stay
	# hidden (null) so a lost level's debrief can't show storms still to come.
	var moon_dose: Variant = null
	var window := _storm_window(level)
	if not window.is_empty() and window.get("moon_dose") != null:
		var values: Array = []
		var saved: Array = window["moon_dose"]
		for i in int(p["TURNS_PER_LEVEL"]):
			var at := i + _offset()
			if i < played and at < saved.size():
				values.append(saved[at])
			else:
				values.append(null)
		moon_dose = values

	var recycler_saved: Variant = null
	if has_food():
		var turns_on := 0
		for h in _history:
			if int(h["plan"]["life_support"]) >= int(p["LS_NEEDED"]):
				turns_on += 1
		recycler_saved = turns_on * (int(p["WATER_USED_NO_RECYCLER"]) - int(p["WATER_USED"]))

	var tip_key := "default"
	if str(result["status"]) == "lost":
		tip_key = str({"air": "lost_air", "dose": "lost_dose", "food": "lost_food", "water": "lost_water"}.get(
			result.get("reason", ""), "default"
		))
	elif dose > HIGH_DOSE_TIP:
		tip_key = "high_dose"

	return {
		"result": result,
		"level_index": level - 1,
		"history": history,
		"storms": cards,
		"moon_dose": moon_dose,
		"storm_turns": storm_turns,
		"recycler_saved": recycler_saved,
		"tip_key": tip_key,
		"tip": str(GameText.TEXT["tips"][tip_key]),
		"rating": get_rating(),
		"progress": get_progress(),
		"missions": _mission_log.duplicate(true),
	}


# ---------------------------------------------------------------- helpers
func _message(key: String) -> String:
	return str(GameText.TEXT["messages"][key])


## The saved real stretch of 2024 for level n, or {} (Levels 1 and 2).
func _storm_window(n: int) -> Dictionary:
	var key := str(levels[n - 1]["window"])
	if key == "":
		return {}
	var all: Dictionary = storms.get("windows", {})
	var list: Array = all.get(key, [])
	if list.is_empty():
		return {}
	return list[0]


## The saved record for the current turn, or {}. Internal: it holds `followed`.
func _storm_this_turn() -> Dictionary:
	var window := _storm_window(level)
	if window.is_empty():
		return {}
	for record in window["turns"]:
		if int(record["turn"]) == turn + _offset():
			return record
	return {}


func _add_days(iso_date: String, days: int) -> String:
	var unix := int(Time.get_unix_time_from_datetime_string(iso_date)) + days * 86400
	return Time.get_date_string_from_unix_time(unix)
