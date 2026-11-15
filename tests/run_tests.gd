extends SceneTree
## Tests for Lunar Night Shift. Run them without opening the editor:
##
##   godot --headless --path . --script res://tests/run_tests.gd
##
## Every function whose name starts with `test_` is a test. A test passes if all
## of its checks pass and it reaches its last line (`done()`).

const GameState = preload("res://game_state.gd")
const Numbers = preload("res://game_numbers.gd")
const GameText = preload("res://game_text.gd")
const StormsData = preload("res://storms_data.gd")
const Facts = preload("res://facts.gd")

var _passed := 0
var _failed: Array[String] = []
var _test := ""
var _ok := true
var _completed := false


func _initialize() -> void:
	var seen := {}
	for method in get_method_list():
		var method_name := str(method["name"])
		if not method_name.begins_with("test_") or seen.has(method_name):
			continue
		seen[method_name] = true
		_test = method_name
		_ok = true
		_completed = false
		call(method_name)
		if not _completed:
			_fail("the test stopped before its last line (see the error above)")
		if _ok:
			_passed += 1
		else:
			_failed.append(method_name)
	print("%d passed, %d failed" % [_passed, _failed.size()])
	quit(1 if _failed.size() > 0 else 0)


# ---------------------------------------------------------------- tiny harness
func done() -> void:
	_completed = true


func _fail(message: String) -> void:
	_ok = false
	printerr("FAIL  %s\n      %s" % [_test, message])


func check(condition: bool, message: String = "check failed") -> void:
	if not condition:
		_fail(message)


## Equal by value. Numbers compare as numbers (20 equals 20.0), lists and
## dictionaries item by item.
func eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _same(actual, expected):
		_fail("%s expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])


func _same(a: Variant, b: Variant) -> bool:
	var a_number: bool = a is int or a is float
	var b_number: bool = b is int or b is float
	if a_number and b_number:
		return absf(float(a) - float(b)) < 1e-9
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]):
				return false
		return true
	if typeof(a) != typeof(b):
		return false
	return a == b


func plan(over: Dictionary = {}) -> Dictionary:
	var pl := GameState.new_plan()
	pl.merge(over, true)
	return pl


## A fresh game. `numbers` are test-only overrides (never used for parity).
func new_game(numbers: Dictionary = {}) -> GameState:
	var g := GameState.new()
	if not numbers.is_empty():
		g.p.merge(numbers, true)
		g.start_game()
	return g


## Play `count` turns with the same plan. Returns the last result.
func play(g: GameState, count: int, pl: Dictionary) -> Dictionary:
	var result := {}
	for i in count:
		result = g.take_turn(pl)
		check(str(result["status"]) != "invalid", "turn %d: %s" % [g.turn, str(result.get("message", ""))])
	return result


## A careful, legal plan for the current turn: enough charge for the night.
func careful_plan(g: GameState) -> Dictionary:
	if g.is_day():
		var with_food := g.has_food()
		return plan({"life_support": 3, "charge": 4, "greenhouse": with_food, "science": 2 if with_food else 3})
	return plan({"life_support": 3})


## Play `count` careful turns. With `shelter` true, shelter on every alert.
func play_careful(g: GameState, count: int, shelter: bool = false) -> Dictionary:
	var result := {}
	for i in count:
		var pl := careful_plan(g)
		if shelter and not g.alert_for_turn().is_empty():
			pl["shelter"] = true
			pl["science"] = 0
		result = g.take_turn(pl)
		check(str(result["status"]) != "invalid", "turn %d: %s" % [g.turn, str(result.get("message", ""))])
	return result


## Skip the day: 7 turns of holding Air steady and charging a little.
func to_night(g: GameState, charge: int = 4) -> void:
	play(g, 7, plan({"life_support": 3, "charge": charge}))
	check(not g.is_day(), "should be night")


## A fresh game at the start of the given level (sheltering on the way).
func at_level(n: int, numbers: Dictionary = {}) -> GameState:
	var g := new_game(numbers)
	while g.level < n:
		eq(play_careful(g, 14, true), {"status": "level_won"}, "on the way to level %d" % n)
		g.next_level()
	return g


## Play careful turns (staying in the main base) until the given turn is the current one.
func until_turn(g: GameState, target: int) -> void:
	while g.turn < target:
		play_careful(g, 1)


# ---------------------------------------------------------------- check_plan (section 4.8)
func test_a_sensible_plan_is_ok() -> void:
	var g := new_game()
	eq(g.check_plan(plan({"life_support": 3, "science": 3, "charge": 4})), "ok")
	done()


func test_rule_1_no_negative_power() -> void:
	var g := new_game()
	for key in ["life_support", "shield", "science", "charge"]:
		eq(g.check_plan(plan({key: -1})), "No negative power", key)
	done()


func test_rule_2_life_support_max_5() -> void:
	var g := new_game()
	eq(g.check_plan(plan({"life_support": 6})), "Life support can't go above 5")
	eq(g.check_plan(plan({"life_support": 5})), "ok")
	done()


func test_rule_3_no_charging_at_night() -> void:
	var g := new_game()
	eq(g.check_plan(plan({"life_support": 3, "charge": 1})), "ok")
	to_night(g)
	eq(g.check_plan(plan({"life_support": 3, "charge": 1})), "No sunlight: you can't charge at night")
	done()


func test_rule_4_no_science_while_sheltering() -> void:
	var g := new_game()
	eq(g.check_plan(plan({"shelter": true, "science": 1})), "No science while sheltering")
	done()


func test_rule_5_no_shelter_without_an_alert() -> void:
	var g := new_game()
	check(g.alert_for_turn().is_empty(), "Level 1 has no alerts")
	eq(g.check_plan(plan({"life_support": 3, "shelter": true})), "No storm alert this turn")
	done()


func test_rule_6_shield_already_full() -> void:
	var g := new_game()
	play(g, 4, plan({"life_support": 3, "shield": 6}))  # 24 power = 3 levels
	eq(g.shield, 3)
	eq(g.check_plan(plan({"life_support": 3, "shield": 1})), "The shield is already full")
	done()


func test_rule_7_no_greenhouse_on_level_1() -> void:
	var g := new_game()
	eq(g.check_plan(plan({"life_support": 3, "greenhouse": true})), "No greenhouse on this level")
	done()


func test_rule_8_not_enough_power_day_and_night() -> void:
	var g := new_game()
	eq(g.check_plan(plan({"life_support": 5, "science": 5})), "ok")
	eq(g.check_plan(plan({"life_support": 5, "science": 6})), "Not enough power")
	to_night(g, 0)  # battery still 10
	eq(g.check_plan(plan({"life_support": 5, "science": 5})), "ok")
	eq(g.check_plan(plan({"life_support": 5, "science": 6})), "Not enough power")
	done()


func test_an_invalid_plan_changes_nothing() -> void:
	var g := new_game()
	play(g, 2, plan({"life_support": 3, "shield": 3, "charge": 2, "science": 2}))
	var before := var_to_str([g.get_state(), g.get_debrief()])
	var bad := [
		plan({"life_support": -1}), plan({"life_support": 6}), plan({"shelter": true, "science": 2}),
		plan({"life_support": 3, "shelter": true}), plan({"life_support": 3, "greenhouse": true}),
		plan({"life_support": 5, "science": 9}),
	]
	for pl in bad:
		var result: Dictionary = g.take_turn(pl)
		eq(result["status"], "invalid")
		check(result.get("message", "") != "", "an invalid result has a message")
		eq(var_to_str([g.get_state(), g.get_debrief()]), before, "state changed")
	done()


# ---------------------------------------------------------------- the controls (section 4.4)
func test_life_support_3_holds_air() -> void:
	var g := new_game()
	play(g, 3, plan({"life_support": 3}))
	eq(g.air, 60)
	done()


func test_life_support_below_3_drains_air() -> void:
	var g := new_game()
	g.take_turn(plan({"life_support": 2}))
	eq(g.air, 52)
	g.take_turn(plan({"life_support": 0}))
	eq(g.air, 28)
	done()


func test_life_support_above_3_adds_air_up_to_60() -> void:
	var g := new_game()
	play(g, 2, plan({"life_support": 1}))  # 60 -> 28
	g.take_turn(plan({"life_support": 4}))
	eq(g.air, 36)
	g.take_turn(plan({"life_support": 5}))
	eq(g.air, 52)
	g.take_turn(plan({"life_support": 5}))
	eq(g.air, 60)
	done()


func test_air_at_0_loses_the_level() -> void:
	var g := new_game()
	var result := play(g, 3, plan({"life_support": 0}))  # 60 -> 36 -> 12 -> 0
	eq(result, {"status": "lost", "reason": "air"})
	eq(g.air, 0)
	done()


func test_shield_8_power_per_level_spread_over_turns() -> void:
	var g := new_game()
	g.take_turn(plan({"life_support": 3, "shield": 5}))
	eq([g.shield, g.shield_progress], [0, 5])
	g.take_turn(plan({"life_support": 3, "shield": 5}))
	eq([g.shield, g.shield_progress], [1, 2])
	play(g, 2, plan({"life_support": 3, "shield": 7}))
	eq([g.shield, g.shield_progress], [3, 0])
	done()


func test_science_1_power_is_1_star() -> void:
	var g := new_game()
	g.take_turn(plan({"life_support": 3, "science": 7}))
	eq(g.stars, 7)
	done()


func test_charge_puts_08_in_the_battery_capped_at_40() -> void:
	var g := new_game()
	g.take_turn(plan({"life_support": 3, "charge": 5}))
	eq(g.battery, 14.0)
	play(g, 6, plan({"life_support": 3, "charge": 7}))  # would reach 47.6
	eq(g.battery, 40.0)
	done()


func test_day_power_not_spent_is_lost() -> void:
	var g := new_game()
	g.take_turn(plan({"life_support": 3}))  # 7 of 10 unspent
	eq(g.battery, 10.0)
	eq(g.power_available(), 10.0)
	done()


func test_sun_pays_by_day_battery_pays_at_night() -> void:
	var g := new_game()
	check(g.is_day(), "starts by day")
	eq(g.power_available(), 10.0)
	to_night(g, 5)  # 10 + 7 * 4 = 38
	eq(g.battery, 38.0)
	eq(g.power_available(), 38.0)
	g.take_turn(plan({"life_support": 3, "science": 2, "shield": 1}))
	eq(g.battery, 32.0)
	eq(g.stars, 2)
	done()


func test_turns_1_to_7_are_day() -> void:
	var g := new_game()
	var days: Array = []
	for expected_turn in range(1, 15):
		eq(g.turn, expected_turn)
		days.append(g.get_state()["is_day"])
		g.take_turn(careful_plan(g))
	eq(days, [true, true, true, true, true, true, true, false, false, false, false, false, false, false])
	done()


func test_total_spend_adds_everything_up() -> void:
	var g := at_level(2)
	eq(g.total_spend(plan({"life_support": 3, "shield": 2, "science": 1, "charge": 1, "greenhouse": true})), 8)
	to_night(g)
	eq(g.total_spend(plan({"life_support": 3, "greenhouse": true})), 7)
	done()


# ---------------------------------------------------------------- food and water (section 4.6)
func test_level_1_has_no_food_or_water() -> void:
	var g := new_game()
	var st := g.get_state()
	check(st["food"] == null and st["water"] == null, "food and water are null on Level 1")
	var info := g.get_level_info()
	eq([info["has_food"], info["has_storms"]], [false, false])
	done()


func test_level_2_starts_with_16_food_and_30_water() -> void:
	var g := at_level(2)
	var st := g.get_state()
	eq([st["food"], st["water"]], [16, 30])
	check(g.get_level_info()["has_food"], "Level 2 has food")
	done()


func test_crew_eats_2_and_recycler_keeps_water_at_1() -> void:
	var g := at_level(2)
	g.take_turn(plan({"life_support": 3}))
	eq([g.food, g.water], [14, 29])
	done()


func test_recycler_off_uses_2_water() -> void:
	var g := at_level(2)
	g.take_turn(plan({"life_support": 2}))
	eq([g.food, g.water], [14, 28])
	done()


func test_greenhouse_grows_3_food_drinks_1_water_costs_1_by_day() -> void:
	var g := at_level(2)
	eq(g.check_plan(plan({"life_support": 5, "science": 4, "greenhouse": true})), "ok")
	eq(g.check_plan(plan({"life_support": 5, "science": 5, "greenhouse": true})), "Not enough power")
	g.take_turn(plan({"life_support": 3, "greenhouse": true}))
	eq([g.food, g.water], [17, 28])
	done()


func test_greenhouse_at_night_costs_4() -> void:
	var g := at_level(2)
	to_night(g, 5)  # battery 38
	g.take_turn(plan({"life_support": 3, "greenhouse": true}))
	eq(g.battery, 31.0)
	done()


func test_no_greenhouse_food_runs_out_on_turn_9() -> void:
	var g := at_level(2)
	var result := {}
	for i in 8:
		result = g.take_turn(plan({"life_support": 3, "charge": 4 if g.is_day() else 0}))
	eq(result, {"status": "continue"})
	eq(g.food, 0)
	eq(g.take_turn(plan({"life_support": 3})), {"status": "lost", "reason": "food"})
	done()


func test_water_below_0_loses_the_level() -> void:
	# Water is a calm meter: with the real numbers careful play never runs out,
	# so this test uses a smaller tank (test-only override) to reach the check.
	var g := at_level(2, {"WATER_START": 3})
	eq(play(g, 3, plan({"life_support": 3})), {"status": "continue"})
	eq(g.water, 0)
	eq(g.take_turn(plan({"life_support": 3})), {"status": "lost", "reason": "water"})
	done()


func test_lose_checks_air_before_food() -> void:
	var g := at_level(2, {"FOOD_START": 4, "START_AIR": 24})
	# air 0 and food -2 on the same turn
	eq(play(g, 3, plan({"life_support": 2})), {"status": "lost", "reason": "air"})
	done()


func test_debrief_counts_water_the_recycler_saved() -> void:
	var g := at_level(2)
	play(g, 2, plan({"life_support": 3}))
	g.take_turn(plan({"life_support": 2}))
	g.take_turn(plan({"life_support": 4}))
	eq(g.get_debrief()["recycler_saved"], 3)
	done()


# ---------------------------------------------------------------- levels (sections 4.3, 4.9)
func test_level_won_after_turn_14() -> void:
	var g := new_game()
	eq(play_careful(g, 13), {"status": "continue"})
	eq(g.take_turn(careful_plan(g)), {"status": "level_won"})
	done()


func test_no_more_turns_after_a_level_ends() -> void:
	var g := new_game()
	play_careful(g, 14)
	var before := var_to_str(g.get_state())
	eq(g.take_turn(plan({"life_support": 3}))["status"], "invalid")
	eq(var_to_str(g.get_state()), before)
	done()


func test_next_level_carries_shield_and_stars_resets_the_rest() -> void:
	var g := new_game()
	for i in 14:
		if g.is_day():  # 14 shield power; Air drains by day
			g.take_turn(plan({"life_support": 2, "charge": 4, "shield": 2, "science": 2}))
		else:
			g.take_turn(plan({"life_support": 3}))
	eq([g.shield, g.shield_progress, g.stars, g.air], [1, 6, 14, 4])
	g.next_level()
	eq([g.level, g.turn, g.is_day()], [2, 1, true])
	eq([g.shield, g.shield_progress, g.stars, g.dose], [1, 6, 14, 0])
	eq([g.battery, g.air, g.food, g.water], [10, 60, 16, 30])
	done()


func test_next_level_does_nothing_unless_won() -> void:
	var g := new_game()
	g.take_turn(plan({"life_support": 3}))
	g.next_level()
	eq([g.level, g.turn], [1, 2])
	done()


func test_retry_restores_the_level_start() -> void:
	var g := at_level(2)
	var start := g.get_state()
	play(g, 3, plan({"life_support": 0, "shield": 5, "science": 5}))  # loses on Air
	check(g.stars != int(start["stars"]), "stars changed during the level")
	g.retry_level()
	eq(g.get_state(), start)
	eq(g.get_debrief()["history"], [])
	eq(g.take_turn(plan({"life_support": 3}))["status"], "continue")
	done()


func test_start_game_starts_over() -> void:
	var g := at_level(2)
	g.start_game()
	eq([g.level, g.turn, g.stars, g.shield, g.shield_progress, g.dose], [1, 1, 0, 0, 0, 0])
	done()


func test_get_state_is_a_copy_with_the_documented_keys() -> void:
	var g := new_game()
	var st := g.get_state()
	eq(st.keys(), ["level", "level_count", "turn", "turns_per_level", "is_day", "battery", "air", "water",
		"food", "dose", "shield", "shield_progress", "stars"])
	eq([st["level_count"], st["turns_per_level"]], [4, 14])
	st["air"] = 1
	st["stars"] = 999
	eq([g.get_state()["air"], g.get_state()["stars"]], [60, 0])
	done()


func test_debrief_history_and_tips() -> void:
	var g := new_game()
	play(g, 2, plan({"life_support": 3, "charge": 5}))
	var d := g.get_debrief()
	eq(d["history"].size(), 2)
	eq(d["history"][0].keys(), ["turn", "battery", "air", "water", "food", "dose"])
	eq([d["level_index"], d["tip_key"]], [0, "default"])
	check(d["recycler_saved"] == null and d["moon_dose"] == null, "no recycler or Moon dose on Level 1")
	var result := play(g, 3, plan({"life_support": 0}))
	d = g.get_debrief(result)
	eq([d["result"]["status"], d["tip_key"]], ["lost", "lost_air"])
	check(str(d["tip"]).begins_with("Life support needs power every turn"), "the lost-air tip")
	done()


# ---------------------------------------------------------------- saved storm data (section 5.4)
func _window_rows(key: String) -> Array:
	var rows: Array = []
	for t in StormsData.DATA["windows"][key][0]["turns"]:
		rows.append([t["turn"], t["shown"]["full_class"], t["shown"]["peak"], t["followed"], t["flares"].size()])
	return rows


func test_space_weather_window_matches_the_handover_table() -> void:
	eq(StormsData.DATA["windows"]["space_weather"][0]["start"], "2024-01-13")
	# turn, shown flare, peak (UTC), storm followed, alerts in turn
	eq(_window_rows("space_weather"), [
		[6, "M5.1", "2024-01-23T03:31Z", false, 1],
		[9, "M6.8", "2024-01-29T04:38Z", true, 1],
		[13, "M5.1", "2024-02-07T03:31Z", false, 1],
		[14, "X3.3", "2024-02-09T13:14Z", true, 1],
	])
	done()


func test_big_one_window_matches_the_handover_table() -> void:
	eq(StormsData.DATA["windows"]["big_one"][0]["start"], "2024-05-05")
	eq(_window_rows("big_one"), [
		[1, "X4.5", "2024-05-06T06:35Z", false, 5],
		[2, "X1.0", "2024-05-08T01:41Z", true, 9],
		[3, "X3.9", "2024-05-10T06:54Z", true, 4],
		[4, "X5.8", "2024-05-11T01:23Z", true, 4],
		[5, "X8.7", "2024-05-14T16:51Z", true, 4],
		[6, "X3.4", "2024-05-15T08:37Z", false, 2],
		[7, "M7.2", "2024-05-17T21:08Z", false, 1],
		[12, "X2.8", "2024-05-27T07:08Z", false, 1],
		[13, "X1.4", "2024-05-29T14:37Z", false, 2],
		[14, "X1.4", "2024-06-01T08:48Z", false, 4],
	])
	done()


func test_every_saved_turn_is_well_formed_with_a_donki_link() -> void:
	for key in StormsData.DATA["windows"]:
		for window in StormsData.DATA["windows"][key]:
			check(window["moon_dose"] == null or window["moon_dose"].size() == 14, "14 Moon dose values or null")
			for t in window["turns"]:
				check(int(t["turn"]) >= 1 and int(t["turn"]) <= 14, "turn in 1..14")
				eq(t["shown"]["cls"], str(t["shown"]["full_class"]).substr(0, 1))
				var any_followed := false
				for flare in t["flares"]:
					any_followed = any_followed or bool(flare["followed"])
					check(str(flare["link"]).begins_with("https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/"), str(flare["link"]))
					# the flare's peak is inside the turn's two real days
					var peak_unix := int(Time.get_unix_time_from_datetime_string(str(flare["peak"]).trim_suffix("Z") + ":00"))
					var start_unix := int(Time.get_unix_time_from_datetime_string(str(window["start"])))
					eq(floori(float(peak_unix - start_unix) / 172800.0) + 1, int(t["turn"]), "peak %s" % str(flare["peak"]))
				eq(t["followed"], any_followed)
	done()


func test_storm_chance_counts_and_dots() -> void:
	eq(StormsData.DATA["chance"], {
		"X": {"followed": 14, "total": 54, "dots": 3}, "M": {"followed": 9, "total": 82, "dots": 1},
	})
	done()


func test_the_big_one_has_at_least_3_storm_turns() -> void:
	for window in StormsData.DATA["windows"]["big_one"]:
		var storm_turns := 0
		for t in window["turns"]:
			if bool(t["followed"]):
				storm_turns += 1
		check(storm_turns >= 3, str(window["start"]))
	done()


# ---------------------------------------------------------------- storms in the rules (section 4.5)
func test_levels_3_and_4_have_the_real_alerts() -> void:
	var g := new_game()
	var seen := {}
	for lv in range(1, 5):
		var turns: Array = []
		for t in range(1, 15):
			if not g.alert_for_turn().is_empty():
				turns.append(t)
			play_careful(g, 1, true)
		seen[lv] = turns
		g.next_level()
	eq(seen, {1: [], 2: [], 3: [6, 9, 13, 14], 4: [1, 2, 3, 4, 5, 6, 7, 12, 13, 14]})
	done()


func test_alert_shows_class_date_and_dots_only() -> void:
	var g := at_level(3)
	until_turn(g, 6)
	eq(g.alert_for_turn(), {"cls": "M", "full_class": "M5.1", "date": "2024-01-23", "dots": 1})
	eq(at_level(4).alert_for_turn(), {"cls": "X", "full_class": "X4.5", "date": "2024-05-06", "dots": 3})
	done()


func test_level_info_and_turn_dates() -> void:
	var g := at_level(3)
	var info := g.get_level_info()
	eq([info["index"], info["name"], info["has_food"], info["has_storms"], info["window_start"]],
		[2, "Space Weather", true, true, "2024-01-13"])
	eq(g.turn_dates(1), {"from": "2024-01-13", "to": "2024-01-14"})
	eq(g.turn_dates(6), {"from": "2024-01-23", "to": "2024-01-24"})
	eq(g.turn_dates(14), {"from": "2024-02-08", "to": "2024-02-09"})
	eq(at_level(4).turn_dates(14), {"from": "2024-05-31", "to": "2024-06-01"})
	eq(new_game().turn_dates(3), {})
	done()


func test_stay_in_a_real_storm_20_with_no_shield() -> void:
	var g := at_level(3)
	until_turn(g, 9)
	eq(g.dose, 0)
	g.take_turn(plan({"life_support": 3}))
	eq(g.dose, 20)
	done()


func test_shelter_in_a_real_storm_15_and_1_power() -> void:
	var g := at_level(3)
	until_turn(g, 9)
	var battery := g.battery
	eq(g.total_spend(plan({"life_support": 3, "shelter": true})), 4)
	g.take_turn(plan({"life_support": 3, "shelter": true}))
	eq(g.dose, 1.5)
	eq(g.battery, battery - 4.0)
	done()


func test_storm_stakes_match_what_a_storm_really_adds() -> void:
	# Level 3, turn 9 is a real storm. The stakes shown before the turn must be
	# exactly what the turn then adds, for staying and for sheltering.
	for shelter in [false, true]:
		var g := at_level(3)
		until_turn(g, 9)
		var pl := plan({"life_support": 3, "shelter": shelter})
		var stakes := g.storm_stakes(pl)
		var before := g.dose
		g.take_turn(pl)
		eq(g.dose - before, stakes["shelter"] if shelter else stakes["stay"])
	done()


func test_storm_stakes_count_a_shield_layer_finished_this_turn() -> void:
	var g := at_level(3)
	until_turn(g, 9)
	eq(g.storm_stakes(plan({"life_support": 3}))["stay"], 20.0)
	eq(g.storm_stakes(plan({"life_support": 3, "shield": 7}))["stay"], 20.0)
	var pl := plan({"life_support": 3, "shield": 8})
	eq(g.storm_stakes(pl)["stay"], 13.0)
	eq(g.storm_stakes(pl)["shelter"], 1.5)
	var before := g.dose
	g.take_turn(pl)
	eq(g.dose - before, 13.0)
	done()


func test_storm_stakes_never_depend_on_the_record() -> void:
	# The same numbers on a storm turn (9) and a turn with no storm after it (6).
	var g := at_level(3)
	until_turn(g, 6)
	var quiet := g.storm_stakes(plan({"life_support": 3}))
	until_turn(g, 9)
	eq(g.storm_stakes(plan({"life_support": 3})), quiet)
	done()


func test_shelter_means_no_science() -> void:
	var g := at_level(3)
	until_turn(g, 6)
	eq(g.check_plan(plan({"life_support": 3, "shelter": true, "science": 1})), "No science while sheltering")
	eq(g.check_plan(plan({"life_support": 3, "shelter": true, "charge": 6})), "ok")
	eq(g.check_plan(plan({"life_support": 3, "shelter": true, "charge": 7})), "Not enough power")
	done()


func test_false_alarm_no_radiation_either_way() -> void:
	for shelter in [true, false]:
		var g := at_level(3)
		until_turn(g, 6)
		g.take_turn(plan({"life_support": 3, "shelter": shelter}))
		eq(g.dose, 0)
		var cards: Array = g.get_debrief()["storms"]
		eq(cards.size(), 1)
		eq([cards[0]["turn"], cards[0]["followed"], cards[0]["sheltered"], cards[0]["dose"]], [6, false, shelter, 0])
	done()


func test_shield_counts_after_this_turns_building() -> void:
	var expected := [20, 13, 9, 5]
	for layers in range(0, 4):
		# build the shield in the daylight of Level 1, then carry it to Level 4
		var g := new_game()
		var left: int = layers * 8
		for i in 14:
			if g.is_day():
				var build := mini(4, left)
				left -= build
				g.take_turn(plan({"life_support": 3, "charge": 3, "shield": build}))
			else:
				g.take_turn(plan({"life_support": 3}))
		g.next_level()
		for lv in [2, 3]:
			play_careful(g, 14, true)
			g.next_level()
		eq([g.level, g.shield], [4, layers])
		g.take_turn(plan({"life_support": 3}))  # turn 1: a false alarm
		var before := g.dose
		g.take_turn(plan({"life_support": 3}))  # turn 2: a real storm, staying in the main base
		eq(g.dose - before, expected[layers], "shield %d" % layers)
	var g2 := at_level(4)
	var before2 := g2.dose
	g2.take_turn(plan({"life_support": 3}))
	# built on the storm turn itself
	eq(g2.take_turn(plan({"life_support": 2, "shield": 8}))["status"], "continue")
	eq([g2.shield, g2.dose - before2], [1, 13])
	done()


func test_radiation_carries_over_and_never_goes_down() -> void:
	var g := at_level(3)
	var last := 0.0
	for i in 14:
		play_careful(g, 1)
		check(g.dose >= last, "radiation went down")
		last = g.dose
	eq(last, 40)
	g.next_level()
	eq([g.level, g.dose], [4, 40])
	done()


func test_radiation_at_100_loses_and_retry_restores_the_dose() -> void:
	var g := at_level(3)
	play_careful(g, 14)  # 40
	g.next_level()
	var result := play_careful(g, 4)  # 60, 80, 100 on turns 2, 3, 4
	eq(result, {"status": "lost", "reason": "dose"})
	var d := g.get_debrief(result)
	eq([d["tip_key"], d["storm_turns"]], ["lost_dose", [2, 3, 4]])
	g.retry_level()
	eq([g.level, g.turn, g.dose], [4, 1, 40])
	done()


func test_high_radiation_tip_above_60() -> void:
	var g := at_level(4)  # sheltered through Level 3: 3.0
	play_careful(g, 4)  # + 20 on turns 2, 3 and 4
	eq(g.dose, 63)
	eq(g.get_debrief({"status": "level_won"})["tip_key"], "high_dose")
	var calm := at_level(4)
	play_careful(calm, 3)  # 43
	eq(calm.get_debrief({"status": "level_won"})["tip_key"], "default")
	done()


func test_debrief_storm_cards() -> void:
	var g := at_level(4)
	play(g, 4, plan({"life_support": 3, "shelter": true, "charge": 6}))
	g.take_turn(plan({"life_support": 3, "charge": 4}))  # turn 5: stay
	var d := g.get_debrief()
	var cards: Array = d["storms"]
	eq(cards.size(), 5)
	var card: Dictionary = cards[4]
	eq(card.keys(), ["turn", "full_class", "date", "link", "followed", "sheltered", "dose", "causes"])
	eq([card["full_class"], card["date"], card["followed"], card["sheltered"], card["dose"]],
		["X8.7", "2024-05-14", true, false, 20])
	check(str(card["link"]).begins_with("https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/"), "a DONKI link")
	# In this turn the X8.7 shown did not bring the storm: another flare did.
	check(card["causes"].size() >= 1, "the storm has a cause")
	for cause in card["causes"]:
		check(cause["full_class"] != "X8.7", "the X8.7 did not cause the storm")
	eq(card["causes"][0].keys(), ["full_class", "date", "link"])
	eq(cards[0]["causes"], [])  # turn 1 was a false alarm
	eq(d["storm_turns"], [2, 3, 4, 5])
	done()


# ---------------------------------------------------------------- no peeking (sections 4.5, 9.1)
func _deep_has_key(value: Variant, wanted: String) -> bool:
	if value is Dictionary:
		for key in value:
			if str(key) == wanted or _deep_has_key(value[key], wanted):
				return true
	elif value is Array:
		for item in value:
			if _deep_has_key(item, wanted):
				return true
	return false


## Everything the screen may ask before a turn, on every turn of every level.
func _visible_before_each_turn(g: GameState) -> Array:
	var seen: Array = []
	for lv in range(1, 5):
		for t in range(1, 15):
			var alert := g.alert_for_turn()
			var pl := careful_plan(g)
			pl["charge"] = 5 if g.is_day() else 0  # enough battery to shelter all night
			pl["science"] = 0
			if not alert.is_empty():
				pl["shelter"] = true
			seen.append({
				"state": g.get_state(), "alert": alert, "info": g.get_level_info(), "dates": g.turn_dates(t),
				"check": g.check_plan(pl), "power": g.power_available(), "spend": g.total_spend(pl),
			})
			var status := str(g.take_turn(pl)["status"])
			check(status in ["continue", "level_won", "game_won"], "L%d t%d: %s" % [lv, t, status])
		g.next_level()
	return seen


func test_alert_and_state_never_contain_followed() -> void:
	var seen := _visible_before_each_turn(new_game())
	eq(seen.size(), 56)
	var alerts := 0
	for view in seen:
		check(not _deep_has_key(view, "followed"), "a `followed` key is visible")
		check(not var_to_str(view).contains("followed"), "the word `followed` is visible")
		var alert: Dictionary = view["alert"]
		if not alert.is_empty():
			alerts += 1
			eq(alert.keys(), ["cls", "full_class", "date", "dots"])
			for key in alert:
				check(not (alert[key] is bool), "no true/false in the alert: nothing that could be the answer")
		var booleans: Array = []
		for key in view["state"]:
			if view["state"][key] is bool:
				booleans.append(key)
		eq(booleans, ["is_day"])
	eq(alerts, 14)
	done()


func test_dots_depend_on_the_flare_class_only() -> void:
	for view in _visible_before_each_turn(new_game()):
		var alert: Dictionary = view["alert"]
		if not alert.is_empty():
			eq(alert["dots"], 3 if alert["cls"] == "X" else 1)
	done()


func test_flipping_followed_changes_nothing_shown_before_the_turn() -> void:
	var flipped_game := new_game()
	for key in flipped_game.storms["windows"]:
		for window in flipped_game.storms["windows"][key]:
			for t in window["turns"]:
				t["followed"] = not bool(t["followed"])
				for flare in t["flares"]:
					flare["followed"] = not bool(flare["followed"])
	var real := _visible_before_each_turn(new_game())
	var flipped := _visible_before_each_turn(flipped_game)
	eq(real.size(), flipped.size())
	var doses_differ := false
	for i in real.size():
		for part in ["alert", "info", "dates", "check", "power", "spend"]:
			eq(flipped[i][part], real[i][part], "view %d, %s" % [i, part])
		if not _same(flipped[i]["state"]["dose"], real[i]["state"]["dose"]):
			doses_differ = true
	# ...while what happens after the turn does change (the flip is really wired in)
	check(doses_differ, "the flipped record should change the radiation")
	# and the real saved data was not touched by the flip
	eq(StormsData.DATA["windows"]["space_weather"][0]["turns"][0]["followed"], false)
	done()


func test_debrief_only_shows_played_turns() -> void:
	var g := at_level(4)
	var fake: Array = []
	for i in range(1, 15):
		fake.append(i)
	g.storms["windows"]["big_one"][0]["moon_dose"] = fake
	var d := g.get_debrief()
	eq(d["storms"], [])
	eq(d["storm_turns"], [])
	eq(d["moon_dose"], [null, null, null, null, null, null, null, null, null, null, null, null, null, null])
	play(g, 3, plan({"life_support": 3, "shelter": true}))
	d = g.get_debrief()
	eq(d["storms"].size(), 3)
	eq(d["storm_turns"], [2, 3])
	eq(d["moon_dose"], [1, 2, 3, null, null, null, null, null, null, null, null, null, null, null])
	done()


# ---------------------------------------------------------------- parity with tools/balance_sim.py (section 9.2)
# A port of `Policy` and `strategies(p, food=True)` from tools/balance_sim.py.
# Strategies only ever see the alert (its class), never whether a storm followed.
func _policy(policy_name: String, over: Dictionary = {}) -> Dictionary:
	var pol := {
		"name": policy_name, "day_ls": 3, "charge_to": 0, "shield_to": 0, "shelter": "never", "night_ls": 3,
		"grow": "day",
	}
	pol.merge(over, true)
	return pol


func _wants_shelter(pol: Dictionary, alert: Dictionary) -> bool:
	if alert.is_empty():
		return false
	return str(pol["shelter"]) == "always" or (str(pol["shelter"]) == "X" and str(alert["cls"]) == "X")


func _shield_needed(pol: Dictionary, s: Dictionary, p: Dictionary) -> int:
	if int(s["shield"]) >= mini(int(pol["shield_to"]), int(p["MAX_SHIELD"])):
		return 0
	return int(p["SHIELD_COST"]) * (int(pol["shield_to"]) - int(s["shield"])) - int(s["shield_progress"])


func _food_short(s: Dictionary, p: Dictionary) -> bool:
	var turns_left: int = int(p["TURNS_PER_LEVEL"]) - int(s["turn"]) + 1
	return int(s["food"]) < int(p["FOOD_EATEN"]) * turns_left


func _wants_greenhouse(pol: Dictionary, s: Dictionary, p: Dictionary, is_day: bool) -> bool:
	var grow := str(pol["grow"])
	if s["food"] == null or grow == "never":
		return false
	if grow == "always":
		return true
	if grow == "night" and is_day:
		return false
	return _food_short(s, p)  # 'day' growers only use it at night in an emergency


func _policy_plan(pol: Dictionary, s: Dictionary, p: Dictionary, is_day: bool, alert: Dictionary) -> Dictionary:
	var pl := GameState.new_plan()
	if is_day:
		var budget: int = int(p["SOLAR_POWER"])
		if _wants_shelter(pol, alert):
			pl["shelter"] = true
			budget -= int(p["SHELTER_COST"])
		var ls: int = 0
		if str(pol["day_ls"]) == "bank":
			ls = int(p["LS_MAX"]) if int(s["air"]) < int(p["AIR_MAX"]) else int(p["LS_NEEDED"])
		else:
			ls = int(pol["day_ls"])
		pl["life_support"] = mini(mini(ls, budget), int(p["LS_MAX"]))
		budget -= int(pl["life_support"])
		if _wants_greenhouse(pol, s, p, true) and budget >= int(p["GREENHOUSE_DAY"]):
			pl["greenhouse"] = true
			budget -= int(p["GREENHOUSE_DAY"])
		var need: float = maxf(0.0, float(pol["charge_to"]) - float(s["battery"])) / float(p["CHARGE_EFFICIENCY"])
		pl["charge"] = mini(budget, int(ceil(need - 1e-9)))
		budget -= int(pl["charge"])
		pl["shield"] = mini(budget, _shield_needed(pol, s, p))
		budget -= int(pl["shield"])
		if bool(pl["shelter"]):
			pl["charge"] = int(pl["charge"]) + budget  # no science while sheltering: bank the rest
		else:
			pl["science"] = budget
		return pl
	# night: only the battery
	var b: float = float(s["battery"])
	if _wants_shelter(pol, alert) and b >= float(p["SHELTER_COST"]):
		pl["shelter"] = true
		b -= float(p["SHELTER_COST"])
	pl["life_support"] = mini(int(pol["night_ls"]), int(b + 1e-9))
	b -= float(int(pl["life_support"]))
	if _wants_greenhouse(pol, s, p, false) and b >= float(p["GREENHOUSE_NIGHT"]):
		pl["greenhouse"] = true
		b -= float(p["GREENHOUSE_NIGHT"])
	var grow := str(pol["grow"])
	if (grow == "night" or grow == "always") and s["food"] != null:
		return pl  # night growers keep the rest of the battery for the greenhouse
	var nights_after: int = int(p["TURNS_PER_LEVEL"]) - int(s["turn"])
	var spare := int(b - float(nights_after * int(pol["night_ls"])) + 1e-9)
	if spare > 0:
		pl["shield"] = mini(spare, _shield_needed(pol, s, p))
		if not bool(pl["shelter"]):
			pl["science"] = spare - int(pl["shield"])
	return pl


func _strategies(p: Dictionary) -> Array:
	var night: int = int(p["LS_NEEDED"]) * (int(p["TURNS_PER_LEVEL"]) - int(p["DAY_TURNS"]))  # battery the night needs
	return [
		_policy("all science, never charge"),
		_policy("bank Air by day, never charge", {"day_ls": "bank"}),
		_policy("never shelter, no shield", {"charge_to": night}),
		_policy("always shelter, no shield", {"charge_to": night + 6, "shelter": "always"}),
		_policy("full shield early, never shelter", {"charge_to": night, "shield_to": 3}),
		_policy("shelter on X, 1 shield", {"charge_to": night + 4, "shield_to": 1, "shelter": "X"}),
		_policy("shelter on X, 2 shields", {"charge_to": night + 4, "shield_to": 2, "shelter": "X"}),
		_policy("never use the greenhouse", {"charge_to": night + 4, "grow": "never", "shield_to": 1, "shelter": "X"}),
		_policy("greenhouse only at night", {"charge_to": int(p["BATTERY_MAX"]), "grow": "night", "shield_to": 1, "shelter": "X"}),
		_policy("greenhouse always on", {"charge_to": int(p["BATTERY_MAX"]), "grow": "always", "shield_to": 1, "shelter": "X"}),
	]


## Play the whole game with one policy, no retries (like `play()` in the simulator).
func _play_policy(pol: Dictionary) -> Dictionary:
	var g := GameState.new()
	for guard in 1000:
		var result := g.take_turn(_policy_plan(pol, g.get_state(), g.p, g.is_day(), g.alert_for_turn()))
		var status := str(result["status"])
		if status == "invalid":
			return {"result": "invalid plan: %s" % str(result.get("message", "")), "stars": g.stars, "dose": g.dose, "shield": null}
		if status == "continue":
			continue
		if status == "lost":
			return {"result": "lost L%d (%s)" % [g.level, str(result["reason"])], "stars": g.stars, "dose": g.dose, "shield": null}
		if status == "game_won":
			return {"result": "won", "stars": g.stars, "dose": g.dose, "shield": g.shield}
		g.next_level()
	return {"result": "the game never ended", "stars": 0, "dose": 0.0, "shield": null}


func test_parity_with_the_balance_simulator() -> void:
	# From `python3 tools/balance_sim.py --preset tuned_food --food` (HANDOVER.md section 9.2).
	# NEVER change a number here to make the test pass: find the bug in the rules instead.
	var table := [
		# strategy, result, stars, dose, shield
		["all science, never charge", "lost L1 (air)", 49, 0.0, null],
		["bank Air by day, never charge", "lost L1 (air)", 49, 0.0, null],
		["never shelter, no shield", "lost L4 (dose)", 107, 100.0, null],
		["always shelter, no shield", "won", 108, 9.0, 0],
		["full shield early, never shelter", "won", 104, 30.0, 3],
		["shelter on X, 1 shield", "won", 107, 20.5, 1],
		["shelter on X, 2 shields", "won", 99, 16.5, 2],
		["never use the greenhouse", "lost L2 (food)", 60, 0.0, null],
		["greenhouse only at night", "won", 49, 20.5, 1],
		["greenhouse always on", "won", 30, 20.5, 1],
	]
	var policies := _strategies(Numbers.DEFAULTS)
	eq(policies.size(), table.size(), "the strategy list is the simulator's")
	for i in table.size():
		var row: Array = table[i]
		var pol: Dictionary = policies[i]
		eq(pol["name"], row[0], "strategy order")
		var got := _play_policy(pol)
		eq(got["result"], row[1], str(row[0]) + ": result")
		eq(got["stars"], row[2], str(row[0]) + ": stars")
		eq(got["dose"], row[3], str(row[0]) + ": dose")
		check(got["shield"] == row[4], "%s: shield expected %s, got %s" % [row[0], str(row[4]), str(got["shield"])])
	done()


# ---------------------------------------------------------------- the short game
func short_game(mission_seed: int = 0) -> GameState:
	var g := GameState.new()
	g.mission_seed = mission_seed
	g.set_mode("short")
	return g


## A short game at the start of level n, after careful play that shelters on every alert.
func short_at_level(n: int) -> GameState:
	var g := short_game()
	while g.level < n:
		eq(play_careful(g, 8, true), {"status": "level_won"}, "on the way to short level %d" % n)
		g.next_level()
	return g


func test_the_short_game_has_three_levels_of_eight_turns() -> void:
	var g := short_game()
	var st := g.get_state()
	eq([st["level_count"], st["turns_per_level"]], [3, 8])
	var days: Array = []
	for i in 8:
		days.append(g.is_day())
		play_careful(g, 1)
	eq(days, [true, true, true, true, false, false, false, false])
	for level in Numbers.LEVELS_SHORT:
		check(not bool(level["food"]), "no food or water in the short game")
	# every other number is the full game's, and the full game's are untouched
	for key in Numbers.DEFAULTS:
		if not Numbers.SHORT.has(key):
			eq(g.p[key], Numbers.DEFAULTS[key], str(key))
	eq([Numbers.DEFAULTS["TURNS_PER_LEVEL"], Numbers.DEFAULTS["DAY_TURNS"]], [14, 7])
	g.set_mode("full")
	eq([g.get_state()["level_count"], g.get_state()["turns_per_level"], g.level, g.turn], [4, 14, 1, 1])
	done()


func test_the_short_game_shows_the_same_real_flares_on_the_same_real_days() -> void:
	# [short level, the full game's level with the same window, turns skipped]
	for pair in [[2, 3, 4], [3, 4, 2]]:
		var short := short_at_level(int(pair[0]))
		var full := at_level(int(pair[1]))
		var skipped := int(pair[2])
		eq(int(Numbers.LEVELS_SHORT[int(pair[0]) - 1]["offset"]), skipped)
		eq(short.get_level_info()["window_start"], full.turn_dates(skipped + 1)["from"])
		var alerts := 0
		for t in range(1, 9):
			short.turn = t
			full.turn = t + skipped
			eq(short.alert_for_turn(), full.alert_for_turn(), "short level %d turn %d" % [pair[0], t])
			eq(short.turn_dates(t), full.turn_dates(t + skipped), "dates of turn %d" % t)
			if not short.alert_for_turn().is_empty():
				alerts += 1
		check(alerts >= 2, "the short level has alerts")
	# the days the Science page names
	eq(short_at_level(2).turn_dates(1)["from"], "2024-01-21")
	eq(short_at_level(2).turn_dates(8)["to"], "2024-02-05")
	eq(short_at_level(3).turn_dates(1)["from"], "2024-05-09")
	eq(short_at_level(3).turn_dates(8)["to"], "2024-05-24")
	done()


func test_the_short_game_storms_follow_the_real_record() -> void:
	var g := short_at_level(2)
	var gains := {}
	for t in range(1, 9):
		var before := g.dose
		var had_alert := not g.alert_for_turn().is_empty()
		play_careful(g, 1)  # stays in the main base
		if had_alert:
			gains[t] = g.dose - before
	# 23 January 2024: an M5.1 flare, no storm. 29 January: an M6.8 flare, and a storm.
	eq(gains, {2: 0.0, 5: 20.0})
	var d := g.get_debrief()
	eq(d["storm_turns"], [5])
	var saved: Array = StormsData.DATA["windows"]["space_weather"][0]["moon_dose"]
	eq(d["moon_dose"], saved.slice(4, 12))
	done()


func test_the_short_game_can_be_won_and_lost() -> void:
	var g := short_at_level(3)
	eq(play_careful(g, 8, true), {"status": "game_won"})
	eq(g.ratings.size(), 3)
	var lost := short_game()
	eq(play(lost, 3, plan({"life_support": 0})), {"status": "lost", "reason": "air"})
	eq(lost.ratings, [])
	done()


# ---------------------------------------------------------------- missions and stars
## A legal plan that does the mission posted for this turn.
func mission_plan(g: GameState) -> Dictionary:
	var mission := g.mission_for_turn()
	var pl := plan({"life_support": 3})
	if str(mission["key"]) == "greenhouse":
		pl["greenhouse"] = true
	else:
		pl[str(mission["key"])] = int(mission["at_least"])
	return pl


## The turns of the current level that have a mission, with each mission's id.
func posted(g: GameState) -> Dictionary:
	var found := {}
	var kept := g.turn
	for t in range(1, int(g.p["TURNS_PER_LEVEL"]) + 1):
		g.turn = t
		if not g.mission_for_turn().is_empty():
			found[t] = str(g.mission_for_turn()["id"])
	g.turn = kept
	return found


func test_missions_come_twice_by_day_and_twice_by_night() -> void:
	for mission_seed in 6:
		var g := GameState.new()
		g.mission_seed = mission_seed
		g.start_game()
		for level in range(1, 5):
			var found := posted(g)
			var by_day := 0
			for t in found:
				var mission: Dictionary = {}
				for m in Numbers.MISSIONS:
					if str(m["id"]) == str(found[t]):
						mission = m
				if int(t) <= 7:
					by_day += 1
				check(str(mission["when"]) in ["any", "day" if int(t) <= 7 else "night"], "%s on turn %d" % [found[t], t])
				check(g.has_food() or not bool(mission["food"]), "%s needs the greenhouse" % str(found[t]))
			eq([found.size(), by_day], [4, 2], "seed %d level %d" % [mission_seed, level])
			check(not (level == 1 and found.has(1)), "the first turn of the game is free")
			eq(g.get_progress()["missions_posted"], 4)
			if level < 4:
				eq(play_careful(g, 14, true), {"status": "level_won"})
				g.next_level()
	var short := short_game(3)
	var found_short := posted(short)
	eq(found_short.size(), 2)
	done()


func test_missions_depend_only_on_the_seed() -> void:
	var a := GameState.new()
	var b := GameState.new()
	a.mission_seed = 7
	b.mission_seed = 7
	a.start_game()
	b.start_game()
	eq(posted(a), posted(b))
	var kinds := {}
	for mission_seed in 12:
		var g := GameState.new()
		g.mission_seed = mission_seed
		g.start_game()
		kinds[var_to_str(posted(g))] = true
	check(kinds.size() > 6, "different seeds give different missions")
	# a retry brings the same missions back
	var before := posted(a)
	play_careful(a, 3)
	a.retry_level()
	eq(posted(a), before)
	done()


func test_a_finished_mission_pays_bonus_science_and_nothing_else() -> void:
	var g := new_game()
	g._missions = {1: "big_experiment", 2: "charge_up"}
	var mission := g.mission_for_turn()
	eq([mission["id"], mission["key"], mission["at_least"], mission["reward"]], ["big_experiment", "science", 5, 4])
	check(not g.mission_met(plan({"life_support": 3, "science": 4})), "4 is not enough")
	check(g.mission_met(mission_plan(g)), "5 does it")
	eq(g.next_mission()["turn"], 2)
	eq(g.next_mission()["mission"]["id"], "charge_up")
	play(g, 1, mission_plan(g))
	eq([g.stars, g.bonus, g.missions_done, g.level_science()], [5, 4, 1, 9])
	# turn 2: missed
	play(g, 1, plan({"life_support": 3, "charge": 4}))
	eq([g.stars, g.bonus, g.missions_done], [5, 4, 1])
	eq(g.next_mission(), {})
	var log: Array = g.get_debrief()["missions"]
	eq(log, [
		{"turn": 1, "id": "big_experiment", "done": true, "reward": 4},
		{"turn": 2, "id": "charge_up", "done": false, "reward": 3},
	])
	# a turn with no mission pays nothing
	check(g.mission_for_turn().is_empty() and not g.mission_met(plan({"science": 7})), "no mission on turn 3")
	done()


func test_missions_never_change_what_the_simulator_counts() -> void:
	var a := GameState.new()
	var b := GameState.new()
	a.start_game()
	b.start_game()
	a._missions = {2: "sample_run", 3: "dig_crew", 9: "night_survey"}
	b._missions = {}  # no missions at all
	for i in 14:
		var pl := careful_plan(a)
		a.take_turn(pl)
		b.take_turn(pl)
		eq(a.get_state(), b.get_state(), "turn %d" % (i + 1))
	check(a.bonus > 0 and b.bonus == 0, "only the bonus differs")
	done()


func test_a_science_mission_cannot_be_done_from_the_shelter() -> void:
	var g := at_level(3)
	until_turn(g, 6)  # a real alert
	g._missions = {6: "sample_run"}
	check(g.mission_met(plan({"life_support": 3, "science": 3})), "staying and doing science does it")
	check(not g.mission_met(plan({"life_support": 3, "shelter": true})), "sheltering does not")
	done()


func test_the_dig_crew_gets_other_work_when_the_shield_is_full() -> void:
	var g := new_game()
	g._missions = {1: "dig_crew"}
	eq(g.mission_for_turn()["key"], "shield")
	g.shield = 3
	eq(g.mission_for_turn()["id"], Numbers.MISSION_WHEN_SHIELD_FULL)
	eq(g.check_plan(mission_plan(g)), "ok")
	done()


func test_missions_never_read_the_storm_record() -> void:
	var a := at_level(3)
	var b := at_level(3)
	for record in b.storms["windows"]["space_weather"][0]["turns"]:
		record["followed"] = not bool(record["followed"])
	eq(posted(a), posted(b))
	for t in posted(a):
		a.turn = int(t)
		b.turn = int(t)
		eq(a.mission_met(mission_plan(a)), b.mission_met(mission_plan(b)))
	done()


func test_three_stars_safe_science_and_missions() -> void:
	var g := new_game()
	g._missions = {2: "sample_run", 3: "charge_up", 9: "night_survey", 10: "deep_clean"}
	# nothing is earned before the level is finished
	eq(g.get_rating(), {"safe": false, "science": false, "missions": false, "stars": 0})
	eq(g.get_progress()["science_goal"], Numbers.LEVELS[0]["science_goal"])
	eq(g.get_progress()["missions_goal"], 2)
	# day: 2 science a turn. Turn 2 has no 3 science, turn 3 charges 5.
	for t in range(1, 8):
		play(g, 1, plan({"life_support": 3, "science": 2, "charge": 5}))
	eq([g.stars, g.missions_done, g.bonus], [14, 1, 3])
	# night: the survey on turn 9
	for t in range(8, 15):
		var result := g.take_turn(plan({"life_support": 3, "science": 3 if t == 9 else 0}))
		if t == 14:
			eq(result, {"status": "level_won"})
	eq([g.stars, g.missions_done, g.bonus, g.level_science()], [17, 2, 7, 24])
	eq(g.get_rating(), {"safe": true, "science": true, "missions": true, "stars": 3})
	eq(g.ratings, [3])
	eq(g.get_debrief()["rating"]["stars"], 3)
	# the next level starts its own count
	g.next_level()
	eq([g.level_science(), g.missions_done, g.bonus, g.get_progress()["science"]], [0, 0, 7, 24])
	eq([g.get_progress()["stars_earned"], g.get_progress()["stars_possible"]], [3, 12])
	done()


func test_a_level_with_no_science_and_no_missions_earns_one_star() -> void:
	var g := new_game()
	g._missions = {}
	for t in range(1, 8):
		play(g, 1, plan({"life_support": 3, "charge": 5}))
	eq(play(g, 7, plan({"life_support": 3})), {"status": "level_won"})
	eq(g.get_rating(), {"safe": true, "science": false, "missions": false, "stars": 1})
	done()


func test_a_lost_level_earns_no_stars_and_a_retry_takes_the_bonus_back() -> void:
	var g := new_game()
	g._missions = {1: "big_experiment"}
	play(g, 1, plan({"life_support": 3, "science": 7}))
	eq([g.bonus, g.missions_done], [4, 1])
	eq(play(g, 3, plan({"life_support": 0})), {"status": "lost", "reason": "air"})
	eq(g.get_rating()["stars"], 0)
	eq(g.ratings, [])
	g.retry_level()
	eq([g.stars, g.bonus, g.missions_done, g.level_science(), g.get_debrief()["missions"]], [0, 0, 0, 0, []])
	done()


# ---------------------------------------------------------------- words and sources
func _says(text: Variant, number: Variant) -> void:
	var regex := RegEx.create_from_string("(^|[^0-9.])" + str(number).replace(".", "\\.") + "([^0-9]|$)")
	check(regex.search(str(text)) != null, "\"%s\" should say %s" % [str(text), str(number)])


func test_numbers_written_in_the_words_match_the_numbers() -> void:
	var t: Dictionary = GameText.TEXT
	var n: Dictionary = Numbers.DEFAULTS
	_says(t["messages"]["ls_max"], n["LS_MAX"])
	_says(t["tips"]["lost_food"], n["GREENHOUSE_DAY"])
	_says(t["tips"]["lost_food"], n["GREENHOUSE_NIGHT"])
	_says(t["tips"]["lost_water"], n["LS_NEEDED"])
	_says(t["controls"]["greenhouse_cost"], n["GREENHOUSE_DAY"])
	_says(t["controls"]["greenhouse_cost"], n["GREENHOUSE_NIGHT"])
	_says(t["controls"]["hints"]["life_support"], n["LS_NEEDED"])
	_says(t["controls"]["hints"]["shield"], n["SHIELD_COST"])
	_says(t["controls"]["hints"]["charge"], n["CHARGE_EFFICIENCY"])
	_says(t["controls"]["hints"]["greenhouse"], n["FOOD_PER_GREENHOUSE"])
	_says(t["controls"]["hints"]["greenhouse"], n["GREENHOUSE_WATER"])
	_says(t["title"]["how_to"][0], n["SOLAR_POWER"])
	_says(t["levels"][0]["intro"], n["SOLAR_POWER"])
	_says(t["levels"][0]["intro"], n["DAY_TURNS"])
	_says(t["levels"][1]["intro"], n["FOOD_START"])
	_says(t["levels"][1]["intro"], n["FOOD_EATEN"])
	check(str(t["debrief"]["why"]["won"]).contains("{turns}"), "the win line takes the number of turns")
	# the short game's first level says its own numbers
	_says(t["levels_short"][0]["intro"], n["SOLAR_POWER"])
	_says(t["levels_short"][0]["intro"], Numbers.SHORT["DAY_TURNS"])
	# the storm odds on the Science page are the saved counts
	var odds: String = t["science"]["rows"][1]["real"]
	var chance: Dictionary = StormsData.DATA["chance"]
	for number in [chance["X"]["followed"], chance["X"]["total"], chance["M"]["followed"], chance["M"]["total"]]:
		_says(odds, number)
	done()


func test_words_are_complete_and_honest() -> void:
	var t: Dictionary = GameText.TEXT
	eq(t["title"]["how_to"].size(), 3)
	eq(t["levels"].size(), Numbers.LEVELS.size())
	eq(t["levels_short"].size(), Numbers.LEVELS_SHORT.size())
	for mission in Numbers.MISSIONS:
		var id := str(mission["id"])
		check(str(t["missions"]["names"].get(id, "")) != "" and str(t["missions"]["asks"].get(id, "")) != "",
			"words for the mission " + id)
	for reason in ["air", "dose", "food", "water"]:
		check(str(t["debrief"]["why"][reason]) != "", reason)
	for row in t["science"]["rows"]:
		check(str(row["game"]) != "" and str(row["real"]) != "" and row["verified"] is bool, "a Science row")
	eq(t["title"]["disclaimer"], "Not made or endorsed by NASA. Uses public NASA data.")
	# the rules speak the words of game_text.gd
	var g := new_game()
	eq(g.check_plan(plan({"life_support": 5, "science": 9})), t["messages"]["not_enough_power"])
	eq(g.get_level_info()["name"], "First Night")
	done()


func test_every_fact_has_an_id_and_the_play_lists_point_at_real_facts() -> void:
	var science: Dictionary = GameText.TEXT["science"]
	var ids := {}
	for row in science["rows"]:
		var id := str(row.get("id", ""))
		check(id != "" and not ids.has(id), "a fact needs its own id: " + id)
		ids[id] = true
		if row.has("source"):
			check(str(row["source"]).begins_with("https://") and str(row.get("source_name", "")) != "", id + ": source")
	for group in ["events", "buildings"]:
		var lists: Dictionary = science["in_play"][group]
		for key in lists:
			for id in lists[key]:
				check(ids.has(str(id)), "%s.%s points at a missing fact: %s" % [group, key, id])
				check(str(Facts.row(str(id)).get("note", "")) != "", "%s is used in play but has no note" % id)
	# every building of the base has a list, even if nothing in it is usable yet
	for key in ["solar", "battery", "science", "base", "shelter", "greenhouse", "water"]:
		check(science["in_play"]["buildings"].has(key), key)
	done()


func test_only_checked_facts_are_shown_in_play() -> void:
	for row in GameText.TEXT["science"]["rows"]:
		var id := str(row["id"])
		var may_show: bool = bool(row["verified"]) and str(row.get("note", "")) != ""
		eq(Facts.usable(id), may_show, id)
		eq(Facts.note(id), str(row["note"]) if may_show else "", id)
	check(not Facts.usable("no_such_fact") and Facts.note("no_such_fact") == "", "an unknown fact is never shown")
	# an unchecked fact is skipped: the next one in the list is told instead
	var lists: Dictionary = GameText.TEXT["science"]["in_play"]
	for group in ["events", "buildings"]:
		for key in lists[group]:
			var picked := Facts.pick([key], {}) if group == "events" else Facts.for_building(str(key))
			if picked != "":
				check(bool(Facts.row(picked)["verified"]), "%s.%s showed an unchecked fact" % [group, key])
				check(lists[group][key].has(picked), "%s.%s" % [group, key])
	done()


func test_each_fact_is_told_once_and_the_first_event_comes_first() -> void:
	var seen := {}
	var first := Facts.pick(["night"], seen)
	eq(first, "lunar_night")
	seen[first] = true
	eq(Facts.pick(["night"], seen), "", "told once")
	# the first event in the list wins; when it has nothing new, the next one speaks
	eq(Facts.pick(["greenhouse", "charge"], seen), "crops")
	seen["crops"] = true
	eq(Facts.pick(["greenhouse", "charge"], seen), "battery_loss")
	eq(Facts.pick([], {}), "")
	eq(Facts.pick(["no_such_event"], {}), "")
	# a list is told in order, one fact each time
	var told: Array = []
	var seen_alerts := {}
	for i in 6:
		var id := Facts.pick(["false_alarm"], seen_alerts)
		if id != "":
			told.append(id)
			seen_alerts[id] = true
	var expected: Array = []
	for id in GameText.TEXT["science"]["in_play"]["events"]["false_alarm"]:
		if Facts.usable(str(id)):
			expected.append(str(id))
	eq(told, expected)
	done()


func test_every_level_has_a_question() -> void:
	for group in ["levels", "levels_short"]:
		for level in GameText.TEXT[group]:
			check(str(level.get("question", "")).ends_with("?"), "%s: %s" % [group, level["name"]])
	done()


func test_only_the_rules_read_the_saved_storm_record() -> void:
	var dir := DirAccess.open("res://")
	check(dir != null, "can list res://")
	if dir != null:
		for file in dir.get_files():
			if not file.ends_with(".gd") or file in ["game_state.gd", "storms_data.gd", "game_text.gd"]:
				continue
			var code := FileAccess.get_file_as_string("res://" + file)
			check(not code.contains("StormsData.DATA[\"windows\"]") and not code.contains("storms[\"windows\"]"),
				file + " must not read the saved storm windows")
			if file != "main.gd":  # main.gd may show it for played turns (from get_debrief)
				check(not code.contains("\"followed\""), file + " mentions `followed`")
	var rules := FileAccess.get_file_as_string("res://game_state.gd")
	check(not rules.contains("randi") and not rules.contains("randf") and not rules.contains("get_node"),
		"the rules are deterministic and touch no nodes")
	done()
