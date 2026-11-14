extends Control
## The screen of Lunar Night Shift, in the style of the Orbit 27 controls
## prototype: full-screen artwork, a top bar with the two rooms and the HUD, and a
## bottom bar with the status lines and the controls.
##
## It draws the state, reads clicks and calls the rules (game_state.gd). It never
## changes a game number itself, and every word comes from game_text.gd.
##
## NO PEEKING: before a turn is played this file only knows what
## game.alert_for_turn() returns (flare class, date, dots). Whether a storm
## followed is read from game.get_debrief(), which holds played turns only.

const GameState = preload("res://game_state.gd")
const GameText = preload("res://game_text.gd")
const StormsData = preload("res://storms_data.gd")
const Kit = preload("res://ui_kit.gd")
const BarChart = preload("res://bar_chart.gd")
const DotRow = preload("res://dot_row.gd")
const SoundFx = preload("res://sound_fx.gd")
const LiveSun = preload("res://live_sun.gd")

# Display-only settings (they never change a rule).
const AIR_LOW_PCT := 30.0  # the Air meter warns under this
const DOSE_HIGH := 60.0  # same line as the "radiation is high" tip
const STEPPERS := ["life_support", "shield", "science", "charge"]

@export var orbit_texture: Texture2D
@export var greenhouse_plant0_texture: Texture2D
@export var greenhouse_plant1_texture: Texture2D

var T: Dictionary = GameText.TEXT
var game := GameState.new()
var screen := "title"  # "title", "intro", "game", "debrief" or "science"
var in_greenhouse := false

var plan: Dictionary = GameState.new_plan()  # the player's plan for this turn (not sent yet)
var choice := ""  # on an alert turn: "" (not chosen yet), "shelter" or "stay"
var science_before_shelter := 0
var hint := ""  # a one-off friendly message (night falls, new meters)
var last_control := ""  # the control touched last: its hint shows in the notice line
var report: Dictionary = {}  # what happened on the turn just played
var new_meters_seen := false
var live_info: Dictionary = {}  # "The Sun right now" (empty while loading)

var sound: SoundFx
var live_sun: LiveSun

# built in code (see the _build_ functions)
var meters_panel: PanelContainer
var recycler_label: Label
var shield_dots: DotRow
var shield_note: Label
var alert_panel: PanelContainer
var alert_title: Label
var alert_dots: DotRow
var alert_chance: Label
var alert_when: Label
var shelter_button: Button
var stay_button: Button
var report_panel: PanelContainer
var report_label: Label
var greenhouse_cell: VBoxContainer
var greenhouse_toggle: Button
var power_label: Label
var power_note: Label
var end_turn_button: Button
var sound_button: Button
var flare_glow: TextureRect
var overlay: Control
var overlay_card: PanelContainer
var overlay_scroll: ScrollContainer
var overlay_content: VBoxContainer
var _meters := {}
var _steppers := {}

@onready var artwork: TextureRect = $Artwork
@onready var night_shade: ColorRect = $NightShade
@onready var placeholder: Label = $Placeholder
@onready var top_bar: ColorRect = $TopBar
@onready var hud: Label = $TopBar/HUD
@onready var dose_label: Label = $TopBar/DoseLabel
@onready var dose_bar: ProgressBar = $TopBar/DoseBar
@onready var orbit_button: Button = $TopBar/Orbit
@onready var greenhouse_button: Button = $TopBar/Greenhouse
@onready var bottom_bar: ColorRect = $BottomBar
@onready var room_status: Label = $BottomBar/RoomStatus
@onready var tools: HBoxContainer = $BottomBar/Tools
@onready var notice: Label = $BottomBar/Notice
@onready var actions: HBoxContainer = $BottomBar/Actions


func _ready() -> void:
	# Optional PNGs. Inspector assignments take priority over these paths.
	orbit_texture = _find_art(orbit_texture, "res://assets/orbit.png")
	greenhouse_plant0_texture = _find_art(greenhouse_plant0_texture, "res://assets/greenhouse_plant0.png")
	greenhouse_plant1_texture = _find_art(greenhouse_plant1_texture, "res://assets/greenhouse_plant1.png")

	orbit_button.text = _t("rooms.orbit")
	greenhouse_button.text = _t("rooms.greenhouse")
	orbit_button.pressed.connect(_show_room.bind(false))
	greenhouse_button.pressed.connect(_show_room.bind(true))
	dose_bar.add_theme_stylebox_override("background", Kit.flat(Kit.C_WELL, 6, Kit.C_LINE, 1))
	dose_bar.add_theme_stylebox_override("fill", Kit.flat(Kit.C_DANGER, 6))

	sound = SoundFx.new()
	add_child(sound)

	_build_flare_glow()
	_build_meters()
	_build_alert()
	_build_report()
	_build_actions()
	_build_overlay()

	live_sun = LiveSun.new()
	add_child(live_sun)
	live_sun.loaded.connect(_on_live_sun_loaded)
	live_sun.start(StormsData.DATA.get("live_snapshot"))

	_show_title()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or screen != "game":
		return
	match key.keycode:
		KEY_1:
			_show_room(false)
		KEY_2:
			_show_room(true)
		_:
			return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- small helpers
## The words at a dotted path in game_text.gd, with {placeholders} filled:
## _t("meters.turn", {"turn": 3, "total": 14})
func _t(path: String, values: Dictionary = {}) -> String:
	var node: Variant = T
	for key in path.split("."):
		node = node[key]
	return str(node).format(values)


## A game number as an int: _n("LS_NEEDED")
func _n(key: String) -> int:
	return int(game.p[key])


## Numbers on screen: at most one decimal, and no "10.0".
func _num(value: float) -> String:
	var rounded := snappedf(value, 0.1)
	if is_equal_approx(rounded, roundf(rounded)):
		return str(int(roundf(rounded)))
	return "%.1f" % rounded


## "2024-05-11" -> "11 May 2024"
func _fmt_date(iso: String, long_month: bool = false, with_year: bool = true) -> String:
	var parts := iso.split("-")
	var months: Array = T["dates"]["months_long"] if long_month else T["dates"]["months_short"]
	var words := "%d %s" % [int(parts[2]), str(months[int(parts[1]) - 1])]
	if with_year:
		words += " " + parts[0]
	return words


## {"from": "2024-01-23", "to": "2024-01-24"} -> "23–24 Jan 2024"
func _fmt_range(dates: Dictionary, long_month: bool = false) -> String:
	var first := str(dates["from"])
	var last := str(dates["to"])
	if first.substr(0, 7) == last.substr(0, 7):
		return "%d–%s" % [int(first.substr(8, 2)), _fmt_date(last, long_month)]
	return "%s – %s" % [_fmt_date(first, long_month, first.substr(0, 4) != last.substr(0, 4)), _fmt_date(last, long_month)]


func _find_art(assigned: Texture2D, path: String) -> Texture2D:
	if assigned != null:
		return assigned
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	return null


func _focus(node: Control) -> void:
	(func() -> void:
		if not is_instance_valid(node) or not node.is_inside_tree():
			return
		node.grab_focus()
		if overlay.visible:
			# the card scrolls to the focused button before its text has been
			# laid out; a fresh screen should start at the top
			await get_tree().process_frame
			await get_tree().process_frame
			overlay_scroll.scroll_vertical = 0
	).call_deferred()


## Anchor a control and set its edges. `anchors` holds left, top, right, bottom
## (as position and size). Right and bottom go first: a left or top anchor may
## never pass the opposite one, so the other order silently clamps it.
func _place(node: Control, anchors: Rect2, left: float, top: float, right: float, bottom: float) -> void:
	node.anchor_right = anchors.size.x
	node.anchor_bottom = anchors.size.y
	node.anchor_left = anchors.position.x
	node.anchor_top = anchors.position.y
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom


# ---------------------------------------------------------------- building the screen (once)
## A soft glow over the Sun while a flare alert is up. It only says "there is an alert".
func _build_flare_glow() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.45, 0.85))
	gradient.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	flare_glow = TextureRect.new()
	flare_glow.texture = texture
	flare_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flare_glow.stretch_mode = TextureRect.STRETCH_SCALE
	flare_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flare_glow.position = Vector2(470, 120)
	flare_glow.size = Vector2(480, 480)
	flare_glow.visible = false
	add_child(flare_glow)
	move_child(flare_glow, artwork.get_index() + 1)
	var pulse := create_tween().set_loops()
	pulse.tween_property(flare_glow, "modulate:a", 0.4, 0.9)
	pulse.tween_property(flare_glow, "modulate:a", 1.0, 0.9)


func _build_meters() -> void:
	meters_panel = Kit.panel()
	meters_panel.position = Vector2(24, 88)
	meters_panel.custom_minimum_size = Vector2(320, 0)
	add_child(meters_panel)
	var box := Kit.vbox(5)
	meters_panel.add_child(box)
	var specs := [
		["battery", Kit.C_SUN], ["air", Kit.C_GOOD], ["water", Kit.C_WATER], ["food", Kit.C_FOOD],
		["radiation", Kit.C_DANGER],
	]
	for spec in specs:
		var key := str(spec[0])
		var row := Kit.hbox(8)
		var name_label := Kit.label(_t("meters." + key), 17)
		name_label.custom_minimum_size = Vector2(96, 0)
		var bar := Kit.meter(spec[1])
		var value_label := Kit.label("", 17)
		value_label.custom_minimum_size = Vector2(66, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(name_label)
		row.add_child(bar)
		row.add_child(value_label)
		box.add_child(row)
		_meters[key] = {"row": row, "name": name_label, "bar": bar, "value": value_label}
		if key == "water":
			recycler_label = Kit.label("", 14, Kit.C_MUTED)
			box.add_child(recycler_label)
	var shield_row := Kit.hbox(8)
	var shield_name := Kit.label(_t("meters.shield"), 17)
	shield_name.custom_minimum_size = Vector2(96, 0)
	shield_row.add_child(shield_name)
	shield_dots = DotRow.new()
	shield_dots.on_color = Kit.C_STATUS
	shield_dots.set_dots(0, _n("MAX_SHIELD"))
	shield_row.add_child(shield_dots)
	shield_note = Kit.label("", 14, Kit.C_MUTED)
	shield_row.add_child(shield_note)
	box.add_child(shield_row)


func _build_alert() -> void:
	alert_panel = PanelContainer.new()
	alert_panel.add_theme_stylebox_override("panel", Kit.flat(Color(0.16, 0.1, 0.04, 0.95), 8, Kit.C_SUN, 2, 12))
	alert_panel.position = Vector2(390, 88)  # clear of the meters panel
	alert_panel.custom_minimum_size = Vector2(866, 0)
	alert_panel.visible = false
	add_child(alert_panel)
	var box := Kit.vbox(6)
	alert_panel.add_child(box)
	var head := Kit.hbox(14)
	head.add_child(Kit.label(_t("alert.heading"), 16, Kit.C_SUN))
	alert_title = Kit.label("", 22)
	head.add_child(alert_title)
	box.add_child(head)
	var odds := Kit.hbox(10)
	alert_dots = DotRow.new()
	odds.add_child(alert_dots)
	alert_chance = Kit.label("", 18)
	odds.add_child(alert_chance)
	box.add_child(odds)
	alert_when = Kit.label("", 15, Kit.C_MUTED)
	box.add_child(alert_when)
	var choices := Kit.hbox(12)
	shelter_button = Kit.button("", 360)
	shelter_button.toggle_mode = true
	shelter_button.pressed.connect(_choose.bind("shelter"))
	stay_button = Kit.button("", 300)
	stay_button.toggle_mode = true
	stay_button.pressed.connect(_choose.bind("stay"))
	choices.add_child(shelter_button)
	choices.add_child(stay_button)
	box.add_child(choices)


## One line just above the bottom bar: what the saved record says about the last turn.
func _build_report() -> void:
	report_panel = PanelContainer.new()
	report_panel.visible = false
	add_child(report_panel)
	_place(report_panel, Rect2(0.0, 1.0, 1.0, 1.0), 24.0, -262.0, -24.0, -218.0)
	report_label = Kit.label("", 18)
	report_label.clip_text = true
	report_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	report_panel.add_child(report_label)


func _build_actions() -> void:
	for key in STEPPERS:
		var cell := Kit.vbox(2)
		var name_label := Kit.label(_t("controls." + key), 16, Kit.C_STATUS)
		cell.add_child(name_label)
		var row := Kit.hbox(4)
		var minus := Kit.button("-", Kit.TAP)
		var plus := Kit.button("+", Kit.TAP)
		for step_button in [minus, plus]:
			step_button.add_theme_font_size_override("font_size", 26)
			step_button.tooltip_text = _t("controls.hints." + key)
		var value := Kit.label("0", 26)
		value.custom_minimum_size = Vector2(40, Kit.TAP)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		minus.pressed.connect(_step.bind(key, -1))
		plus.pressed.connect(_step.bind(key, 1))
		row.add_child(minus)
		row.add_child(value)
		row.add_child(plus)
		cell.add_child(row)
		actions.add_child(cell)
		_steppers[key] = {"cell": cell, "minus": minus, "plus": plus, "value": value}

	greenhouse_cell = Kit.vbox(2)
	greenhouse_cell.add_child(Kit.label(_t("controls.greenhouse"), 16, Kit.C_STATUS))
	greenhouse_toggle = Kit.button(_t("controls.off"), 120)
	greenhouse_toggle.toggle_mode = true
	greenhouse_toggle.tooltip_text = _t("controls.hints.greenhouse") + " " + _t("controls.greenhouse_cost") + "."
	greenhouse_toggle.pressed.connect(_toggle_greenhouse)
	greenhouse_cell.add_child(greenhouse_toggle)
	actions.add_child(greenhouse_cell)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(spacer)

	var power_cell := Kit.vbox(0)
	power_cell.alignment = BoxContainer.ALIGNMENT_CENTER
	power_label = Kit.label("", 24, Kit.C_SUN)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_note = Kit.label("", 14, Kit.C_MUTED)
	power_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_cell.add_child(power_label)
	power_cell.add_child(power_note)
	actions.add_child(power_cell)

	end_turn_button = Kit.button(_t("controls.end_turn"), 170, true)
	end_turn_button.custom_minimum_size = Vector2(170, 64)
	end_turn_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	end_turn_button.add_theme_font_size_override("font_size", 22)
	end_turn_button.pressed.connect(_end_turn)
	actions.add_child(end_turn_button)

	sound_button = Kit.button(_t("controls.sound_on"), 130)
	sound_button.pressed.connect(_toggle_sound)
	tools.add_child(sound_button)
	var title_button := Kit.button(_t("controls.title"), 150)
	title_button.pressed.connect(_show_title)
	tools.add_child(title_button)


## The title, level intro, debrief and Science screens share one centred card.
func _build_overlay() -> void:
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.5)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_card = Kit.panel(Kit.C_BAR, 22, 10)
	overlay.add_child(overlay_card)
	overlay_scroll = ScrollContainer.new()
	overlay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay_scroll.follow_focus = true
	overlay_card.add_child(overlay_scroll)
	overlay_content = Kit.vbox(12)
	overlay_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_scroll.add_child(overlay_content)
	var footer := Kit.label(_t("title.disclaimer"), 14, Kit.C_HUD)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(footer)
	_place(footer, Rect2(0.0, 1.0, 1.0, 1.0), 0.0, -34.0, 0.0, -10.0)


## Show the shared card, `height` canvas pixels tall, with nothing in it yet.
func _open_overlay(height: float) -> void:
	for child in overlay_content.get_children():
		overlay_content.remove_child(child)
		child.queue_free()
	_place(overlay_card, Rect2(0.5, 0.5, 0.5, 0.5), -460.0, -height / 2.0 - 12.0, 460.0, height / 2.0 - 12.0)
	overlay_scroll.scroll_vertical = 0
	overlay.visible = true
	_set_game_visible(false)
	_refresh_art()


func _set_game_visible(showing: bool) -> void:
	top_bar.visible = showing
	bottom_bar.visible = showing
	meters_panel.visible = showing
	if not showing:
		alert_panel.visible = false
		report_panel.visible = false


# ---------------------------------------------------------------- title, intro, science
func _show_title() -> void:
	screen = "title"
	in_greenhouse = false
	_open_overlay(620.0)
	overlay_content.add_child(Kit.label(_t("title.name"), 54, Kit.C_SUN))
	overlay_content.add_child(Kit.label(_t("title.tagline"), 22, Kit.C_TEXT, true))
	var number := 1
	for line in T["title"]["how_to"]:
		var step_card := Kit.panel(Kit.C_CARD, 10, 6)
		step_card.add_child(Kit.label("%d.  %s" % [number, str(line)], 19, Kit.C_TEXT, true))
		overlay_content.add_child(step_card)
		number += 1
	var buttons := Kit.hbox(12)
	var start_button := Kit.button(_t("title.start"), 250, true)
	start_button.pressed.connect(_start_mission)
	var science_button := Kit.button(_t("title.science"), 230)
	science_button.pressed.connect(_show_science)
	buttons.add_child(start_button)
	buttons.add_child(science_button)
	overlay_content.add_child(buttons)
	overlay_content.add_child(_live_card())
	_focus(start_button)


func _start_mission() -> void:
	sound.play("click")
	game.start_game()
	new_meters_seen = false
	_show_intro()


## "The Sun right now". Saved numbers are labelled as saved, never as live.
func _live_card() -> Control:
	var card := Kit.panel(Kit.C_CARD, 12, 8)
	var box := Kit.vbox(3)
	card.add_child(box)
	var head := Kit.hbox(14)
	head.add_child(Kit.label(_t("live.heading"), 16, Kit.C_SUN))
	box.add_child(head)
	if live_info.is_empty():
		box.add_child(Kit.label(_t("live.loading"), 18, Kit.C_MUTED))
		return card
	var mode := str(live_info["mode"])
	if mode == "none":
		box.add_child(Kit.label(_t("live.unavailable"), 18, Kit.C_MUTED, true))
		return card
	if mode == "live":
		head.add_child(Kit.label(_t("live.live_label", {"time": live_info["checked_at"]}), 16, Kit.C_GOOD))
	else:
		head.add_child(Kit.label(_t("live.saved_label", {"date": _fmt_date(str(live_info["saved_on"]))}), 16, Kit.C_WARN))
	box.add_child(Kit.label(
		_t("live.big_flares", {"n": live_info["big_flares"]}) + "  ·  " + _t("live." + str(live_info["busy"])), 19
	))
	if live_info["latest"] == null:
		box.add_child(Kit.label(_t("live.no_latest"), 17))
	else:
		box.add_child(Kit.label(_t("live.latest", {
			"full_class": live_info["latest"]["full_class"], "date": _fmt_date(str(live_info["latest"]["date"])),
		}), 17))
	box.add_child(Kit.label(_t("live.particle_storms", {"n": live_info["particle_storms"]}), 17))
	box.add_child(Kit.label(_t("live.source"), 14, Kit.C_MUTED))
	return card


func _on_live_sun_loaded(info: Dictionary) -> void:
	live_info = info
	if screen == "title":
		_show_title()


## One or two sentences before each level. Storm levels add their real dates.
func _show_intro() -> void:
	screen = "intro"
	in_greenhouse = false
	_open_overlay(420.0)
	var info := game.get_level_info()
	var total := _n("TURNS_PER_LEVEL")
	overlay_content.add_child(Kit.label(_t("intro.level", {"n": game.level, "total": game.levels.size()}), 16, Kit.C_STATUS))
	overlay_content.add_child(Kit.label(str(info["name"]), 46, Kit.C_SUN))
	overlay_content.add_child(Kit.label(str(T["levels"][int(info["index"])]["intro"]), 22, Kit.C_TEXT, true))
	if bool(info["has_storms"]):
		var first := str(game.turn_dates(1)["from"])
		var last := str(game.turn_dates(total)["to"])
		overlay_content.add_child(Kit.label(_t("intro.real_dates", {
			"from": _fmt_date(first, true, first.substr(0, 4) != last.substr(0, 4)), "to": _fmt_date(last, true),
		}), 20, Kit.C_WATER, true))
	var go_button := Kit.button(_t("intro.go"), 250, true)
	go_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go_button.pressed.connect(_begin_level)
	overlay_content.add_child(go_button)
	_focus(go_button)


func _show_science() -> void:
	screen = "science"
	_open_overlay(650.0)
	overlay_content.add_child(Kit.label(_t("science.heading"), 36, Kit.C_SUN))
	overlay_content.add_child(Kit.label(_t("science.intro"), 19, Kit.C_TEXT, true))
	for row in T["science"]["rows"]:
		var card := Kit.panel(Kit.C_CARD, 10, 6)
		var columns := Kit.hbox(16)
		card.add_child(columns)
		var game_side := Kit.vbox(2)
		game_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		game_side.add_child(Kit.label(_t("science.game_column"), 13, Kit.C_STATUS))
		game_side.add_child(Kit.label(str(row["game"]), 17, Kit.C_TEXT, true))
		var real_side := Kit.vbox(2)
		real_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		real_side.add_child(Kit.label(_t("science.real_column"), 13, Kit.C_STATUS))
		real_side.add_child(Kit.label(str(row["real"]), 17, Kit.C_TEXT, true))
		if not bool(row["verified"]):
			real_side.add_child(Kit.label(_t("science.unverified"), 14, Kit.C_WARN, true))
		columns.add_child(game_side)
		columns.add_child(real_side)
		overlay_content.add_child(card)
	overlay_content.add_child(Kit.label(_t("science.datasets_heading"), 24, Kit.C_SUN))
	for dataset in T["science"]["datasets"]:
		overlay_content.add_child(Kit.link(str(dataset["name"]), str(dataset["url"])))
		overlay_content.add_child(Kit.label(str(dataset["why"]), 17, Kit.C_TEXT, true))
	overlay_content.add_child(Kit.label(_t("science.credits_heading"), 24, Kit.C_SUN))
	for line in T["science"]["credits"]:
		overlay_content.add_child(Kit.label(str(line), 17, Kit.C_TEXT, true))
	overlay_content.add_child(Kit.label(
		_t("science.saved_note", {"date": _fmt_date(str(StormsData.DATA["saved_on"]))}), 15, Kit.C_MUTED, true
	))
	overlay_content.add_child(Kit.label(_t("science.disclaimer"), 15, Kit.C_MUTED, true))
	var back_button := Kit.button(_t("title.back"), 160, true)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(_show_title)
	overlay_content.add_child(back_button)
	_focus(back_button)


# ---------------------------------------------------------------- the plan
## Power still needed to finish the shield (so the player can't pour power into a full one).
func _shield_room() -> int:
	return maxi(0, _n("SHIELD_COST") * (_n("MAX_SHIELD") - game.shield) - game.shield_progress)


## The most a stepper may show. The rules still have the last word (check_plan).
func _max_for(key: String) -> int:
	var power := maxi(0, int(floor(game.power_available() + 1e-9)))
	match key:
		"life_support":
			return _n("LS_MAX")
		"shield":
			return mini(_shield_room(), power)
		"charge":
			return power if game.is_day() else 0
		"science":
			return 0 if bool(plan["shelter"]) else power
	return 0


func _step(key: String, delta: int) -> void:
	var next := clampi(int(plan[key]) + delta, 0, _max_for(key))
	last_control = key
	if next != int(plan[key]):
		plan[key] = next
		hint = ""
		sound.play("click")
	_refresh()


func _toggle_greenhouse() -> void:
	plan["greenhouse"] = not bool(plan["greenhouse"])
	last_control = "greenhouse"
	hint = ""
	sound.play("click")
	_refresh()


## The player's answer to a storm alert. Sheltering stops science for the turn.
func _choose(what: String) -> void:
	if game.alert_for_turn().is_empty():
		return
	if what == "shelter" and not bool(plan["shelter"]):
		science_before_shelter = int(plan["science"])
		plan["science"] = 0
		plan["shelter"] = true
	elif what == "stay" and bool(plan["shelter"]):
		plan["shelter"] = false
		plan["science"] = science_before_shelter
		science_before_shelter = 0
	choice = what
	hint = ""
	sound.play("click")
	_refresh()


## A new turn starts from the last plan. If it no longer fits, cut science, then
## shield, then the greenhouse. Never life support: that is the player's call.
func _carry_plan_to_new_turn() -> void:
	plan["shelter"] = false
	choice = ""
	if science_before_shelter > 0:
		plan["science"] = science_before_shelter  # sheltering paused the science
	science_before_shelter = 0
	if not game.is_day():
		plan["charge"] = 0
	plan["shield"] = mini(int(plan["shield"]), _shield_room())
	if not game.has_food():
		plan["greenhouse"] = false
	for guard in 200:
		if float(game.total_spend(plan)) <= game.power_available() + 1e-9:
			break
		if int(plan["science"]) > 0:
			plan["science"] = int(plan["science"]) - 1
		elif int(plan["shield"]) > 0:
			plan["shield"] = int(plan["shield"]) - 1
		elif bool(plan["greenhouse"]):
			plan["greenhouse"] = false
		else:
			break


func _control_hint(key: String) -> String:
	match key:
		"life_support":
			return _t("controls.hints.life_support")
		"shield":
			if game.shield >= _n("MAX_SHIELD"):
				return _t("messages.shield_full") + "."
			return _t("controls.hints.shield")
		"science":
			return _t("controls.hints.no_science_shelter") if bool(plan["shelter"]) else _t("controls.hints.science")
		"charge":
			if game.is_day():
				return _t("controls.hints.charge")
			return _t("controls.charge_day_only") + ". " + _t("messages.no_charge_night") + "."
		"greenhouse":
			return _t("controls.hints.greenhouse") + " " + _t("controls.greenhouse_cost") + "."
	return ""


# ---------------------------------------------------------------- drawing the game screen (every change)
func _show_room(show_greenhouse: bool) -> void:
	if screen != "game":
		return
	in_greenhouse = show_greenhouse and game.has_food()
	_refresh()


func _set_meter(key: String, value: float, most: float, low: bool) -> void:
	var parts: Dictionary = _meters[key]
	var bar: ProgressBar = parts["bar"]
	var value_label: Label = parts["value"]
	bar.max_value = most
	bar.value = clampf(value, 0.0, most)
	value_label.text = _num(value) + ("  " + _t("meters.low") if low else "")
	value_label.add_theme_color_override("font_color", Kit.C_WARN if low else Kit.C_TEXT)
	bar.tooltip_text = "%s: %s / %s" % [_t("meters." + key), _num(value), _num(most)]


func _refresh() -> void:
	if screen != "game":
		return
	var info := game.get_level_info()
	var with_food := bool(info["has_food"])
	var day := game.is_day()
	var available := game.power_available()
	var spend := game.total_spend(plan)
	var problem := game.check_plan(plan)
	if problem == "ok":
		problem = ""
	var alert := game.alert_for_turn()  # class, date and dots only: never the outcome
	var need_choice := not alert.is_empty() and choice == ""
	var total_turns := _n("TURNS_PER_LEVEL")
	var nights_left: int = total_turns - maxi(game.turn, _n("DAY_TURNS") + 1) + 1
	var is_new := with_food and hint == _t("messages.new_meters")

	# top bar
	var hud_values := {
		"level": game.level, "name": str(info["name"]).to_upper(), "turn": "%02d" % game.turn,
		"total": total_turns, "phase": _t("meters.day") if day else _t("meters.night"), "stars": game.stars,
	}
	var dates := game.turn_dates(game.turn)
	if dates.is_empty():
		hud.text = _t("hud.line", hud_values)
	else:
		hud_values["dates"] = _fmt_range(dates)
		hud.text = _t("hud.line_dates", hud_values)
	dose_label.text = _t("hud.radiation", {"dose": _num(game.dose), "limit": _n("DOSE_LIMIT")})
	dose_bar.max_value = float(_n("DOSE_LIMIT"))
	dose_bar.value = game.dose
	orbit_button.set_pressed_no_signal(not in_greenhouse)
	greenhouse_button.set_pressed_no_signal(in_greenhouse)
	greenhouse_button.disabled = not with_food
	greenhouse_button.text = _t("rooms.greenhouse") + ("  " + _t("meters.new") if is_new else "")

	# meters
	_set_meter("battery", game.battery, float(_n("BATTERY_MAX")),
		not day and game.battery + 1e-9 < float(_n("LS_NEEDED") * nights_left))
	_set_meter("air", float(game.air), float(_n("AIR_MAX")),
		float(game.air) / float(_n("AIR_MAX")) * 100.0 < AIR_LOW_PCT)
	_set_meter("radiation", game.dose, float(_n("DOSE_LIMIT")), game.dose > DOSE_HIGH)
	for key in ["water", "food"]:
		var parts: Dictionary = _meters[key]
		(parts["row"] as Control).visible = with_food
		(parts["name"] as Label).text = _t("meters." + key) + ("  " + _t("meters.new") if is_new else "")
		(parts["name"] as Label).add_theme_color_override("font_color", Kit.C_SUN if is_new else Kit.C_TEXT)
	if with_food:
		_set_meter("water", float(game.water), float(_n("WATER_START")), game.water < 2 * _n("WATER_USED_NO_RECYCLER"))
		# a full Food bar feeds the whole level
		_set_meter("food", float(game.food), float(_n("FOOD_EATEN") * total_turns), game.food < 2 * _n("FOOD_EATEN"))
	var recycler_on: bool = int(plan["life_support"]) >= _n("LS_NEEDED")
	recycler_label.visible = with_food
	recycler_label.text = "      " + (_t("meters.recycler_on") if recycler_on else _t("meters.recycler_off"))
	recycler_label.add_theme_color_override("font_color", Kit.C_GOOD if recycler_on else Kit.C_WARN)
	shield_dots.set_dots(game.shield, _n("MAX_SHIELD"))
	if game.shield >= _n("MAX_SHIELD"):
		shield_note.text = _t("rooms.shield_full")
	else:
		shield_note.text = _t("rooms.shield_progress", {"done": game.shield_progress, "cost": _n("SHIELD_COST")})
	meters_panel.reset_size.call_deferred()

	# the plan
	for key in STEPPERS:
		var stepper: Dictionary = _steppers[key]
		var amount := int(plan[key])
		(stepper["value"] as Label).text = str(amount)
		(stepper["minus"] as Button).disabled = amount <= 0
		(stepper["plus"] as Button).disabled = amount >= _max_for(key)
	greenhouse_cell.visible = with_food
	greenhouse_toggle.set_pressed_no_signal(bool(plan["greenhouse"]))
	greenhouse_toggle.text = _t("controls.on") if bool(plan["greenhouse"]) else _t("controls.off")

	# power, notice, end turn
	var left := available - float(spend)
	power_label.text = _t("controls.power_left", {"n": _num(left)})
	power_label.add_theme_color_override("font_color", Kit.C_DANGER if left < -1e-9 else Kit.C_SUN)
	power_note.text = _t("controls.power_from_sun" if day else "controls.power_from_battery", {"n": _num(available)})
	var friendly := hint
	if need_choice:
		friendly = _t("alert.choose")
	if problem != "":
		notice.text = "!  " + problem
		notice.add_theme_color_override("font_color", Kit.C_WARN)
	elif friendly != "":
		notice.text = friendly
		notice.add_theme_color_override("font_color", Kit.C_SUN)
	else:
		notice.text = _control_hint(last_control)
		notice.add_theme_color_override("font_color", Kit.C_TEXT)
	end_turn_button.disabled = problem != "" or need_choice
	room_status.text = _greenhouse_status(recycler_on) if in_greenhouse else _orbit_status(alert)

	# what the saved record said about the last turn
	report_panel.visible = not report.is_empty()
	if not report.is_empty():
		var hit := bool(report["hit"])
		report_label.text = _t("report.heading") + ":  " + str(report["text"])
		report_panel.add_theme_stylebox_override("panel",
			Kit.flat(Kit.C_PANEL, 8, Kit.C_DANGER if hit else Kit.C_WATER, 2, 10))

	# the storm alert
	alert_panel.visible = not alert.is_empty()
	if not alert.is_empty():
		alert_title.text = _t("alert.title", {"full_class": alert["full_class"]})
		alert_dots.set_dots(int(alert["dots"]), 10)
		alert_dots.tooltip_text = "%d / 10" % int(alert["dots"])
		alert_chance.text = _t("alert.chance", {"dots": alert["dots"]})
		alert_when.text = _t("alert.when", {"date": _fmt_date(str(alert["date"]))})
		var shelter_words := _t("alert.shelter", {"cost": _n("SHELTER_COST")})
		var stay_words := _t("alert.stay")
		shelter_button.text = _t("alert.chosen", {"text": shelter_words}) if choice == "shelter" else shelter_words
		stay_button.text = _t("alert.chosen", {"text": stay_words}) if choice == "stay" else stay_words
		shelter_button.set_pressed_no_signal(choice == "shelter")
		stay_button.set_pressed_no_signal(choice == "stay")
		alert_panel.reset_size.call_deferred()

	_refresh_art()


## The artwork behind everything: the room, the night, and a glow on the Sun during an alert.
func _refresh_art() -> void:
	var playing := screen == "game"
	var growing := playing and bool(plan["greenhouse"])
	if in_greenhouse:
		artwork.texture = greenhouse_plant1_texture if growing else greenhouse_plant0_texture
		placeholder.text = _t("rooms.greenhouse_placeholder", {"state": int(growing)})
	else:
		artwork.texture = orbit_texture
		placeholder.text = _t("rooms.orbit_placeholder")
	placeholder.visible = artwork.texture == null
	night_shade.color.a = 0.5 if (playing and not game.is_day()) else 0.0
	flare_glow.visible = playing and not in_greenhouse and not game.alert_for_turn().is_empty()


func _orbit_status(alert: Dictionary) -> String:
	var parts := PackedStringArray()
	if alert.is_empty():
		parts.append(_t("rooms.orbit_quiet"))
	else:
		parts.append(_t("rooms.orbit_alert", {"full_class": alert["full_class"]}))
	var shield_words := _t("rooms.shield_status", {"shield": game.shield, "max": _n("MAX_SHIELD")})
	if game.shield >= _n("MAX_SHIELD"):
		shield_words += " (" + _t("rooms.shield_full") + ")"
	else:
		shield_words += " (" + _t("rooms.shield_progress", {"done": game.shield_progress, "cost": _n("SHIELD_COST")}) + ")"
	parts.append(shield_words)
	parts.append(_t("rooms.sheltering") if bool(plan["shelter"]) else _t("rooms.in_base"))
	return " · ".join(parts)


func _greenhouse_status(recycler_on: bool) -> String:
	if not game.has_food():
		return _t("rooms.greenhouse_none")
	var parts := PackedStringArray()
	var cost := _n("GREENHOUSE_DAY") if game.is_day() else _n("GREENHOUSE_NIGHT")
	if bool(plan["greenhouse"]):
		parts.append(_t("rooms.greenhouse_on", {"food": _n("FOOD_PER_GREENHOUSE")}))
	else:
		parts.append(_t("rooms.greenhouse_off"))
	parts.append(_t("rooms.greenhouse_cost", {"cost": cost}))
	parts.append(_t("meters.recycler_on") if recycler_on else _t("meters.recycler_off"))
	var turns_fed := int(floor(float(maxi(0, game.food)) / float(_n("FOOD_EATEN"))))
	parts.append(_t("rooms.food_left", {"turns": turns_fed}))
	return " · ".join(parts)


# ---------------------------------------------------------------- playing
func _begin_level() -> void:
	screen = "game"
	plan = GameState.new_plan()
	plan["life_support"] = _n("LS_NEEDED")
	report = {}
	hint = ""
	choice = ""
	last_control = ""
	science_before_shelter = 0
	in_greenhouse = false
	if game.has_food() and not new_meters_seen:
		hint = _t("messages.new_meters")
		new_meters_seen = true
	overlay.visible = false
	_set_game_visible(true)
	sound.play("alert" if not game.alert_for_turn().is_empty() else "click")
	_refresh()
	_focus(end_turn_button)


func _end_turn() -> void:
	if not game.alert_for_turn().is_empty() and choice == "":
		return  # the alert needs an answer first
	var played_turn := game.turn
	var result := game.take_turn(plan.duplicate())
	var status := str(result["status"])
	if status == "invalid":
		_refresh()
		return
	report = _build_turn_report(played_turn)  # after the turn: the record may be shown
	hint = ""
	last_control = ""
	if status != "continue":
		_show_debrief(result)
		return
	_carry_plan_to_new_turn()
	if game.turn == _n("DAY_TURNS") + 1:
		hint = _t("messages.night_hint")
	var cue := "click"
	if not report.is_empty() and bool(report["hit"]):
		cue = "shelter" if bool(report["sheltered"]) else "storm_hit"
	if not game.alert_for_turn().is_empty():
		in_greenhouse = false  # look at the Sun
		if cue == "click":
			cue = "alert"
	sound.play(cue)
	_refresh()


## What the saved record says about the turn that was just played.
func _build_turn_report(played_turn: int) -> Dictionary:
	var cards: Array = game.get_debrief()["storms"]
	if cards.is_empty():
		return {}
	var card: Dictionary = cards[cards.size() - 1]
	if int(card["turn"]) != played_turn:
		return {}
	var parts := PackedStringArray()
	var causes: Array = card["causes"]
	if bool(card["followed"]):
		var shown_caused_it := false
		for cause in causes:
			if str(cause["link"]) == str(card["link"]):
				shown_caused_it = true
		if shown_caused_it or causes.is_empty():
			parts.append(_t("report.storm", {"full_class": card["full_class"]}))
		else:
			parts.append(_t("report.storm_other"))
			parts.append(_t("debrief.caused_by", {
				"full_class": causes[0]["full_class"], "date": _fmt_date(str(causes[0]["date"])),
			}))
		parts.append(_t("report.sheltered" if bool(card["sheltered"]) else "report.stayed", {"dose": _num(float(card["dose"]))}))
	else:
		parts.append(_t("report.false_alarm", {"full_class": card["full_class"]}))
		parts.append(_t("report.sheltered_nothing" if bool(card["sheltered"]) else "report.stayed_nothing"))
	return {"text": " ".join(parts), "hit": bool(card["followed"]), "sheltered": bool(card["sheltered"])}


func _toggle_sound() -> void:
	sound.set_muted(not sound.muted)
	sound_button.text = _t("controls.sound_off") if sound.muted else _t("controls.sound_on")
	sound.play("click")


# ---------------------------------------------------------------- debrief
func _show_debrief(result: Dictionary) -> void:
	screen = "debrief"
	in_greenhouse = false
	var d := game.get_debrief(result)
	var status := str(result["status"])
	var lost := status == "lost"
	sound.play("lost" if lost else "level_won")
	_open_overlay(650.0)

	var headline := _t("debrief.lost")
	if status == "game_won":
		headline = _t("debrief.game_won")
	elif not lost:
		headline = _t("debrief.won")
	overlay_content.add_child(Kit.label(headline, 36, Kit.C_SUN, true))
	var why := _t("debrief.why." + str(result["reason"])) if lost else _t("debrief.why.won")
	overlay_content.add_child(Kit.label(why, 22, Kit.C_TEXT, true))
	overlay_content.add_child(Kit.label(_t("debrief.score", {
		"stars": game.stars, "dose": _num(game.dose), "limit": _n("DOSE_LIMIT"), "shield": game.shield,
		"max": _n("MAX_SHIELD"),
	}), 17, Kit.C_MUTED))

	var tip_card := Kit.striped_card(Kit.C_SUN)
	tip_card.add_child(Kit.label(_t("debrief.tip_heading") + ":  " + str(d["tip"]), 19, Kit.C_TEXT, true))
	overlay_content.add_child(tip_card)

	var buttons := Kit.hbox(12)
	var first_button: Button = null
	if status == "level_won":
		var next_button := Kit.button(_t("debrief.next"), 200, true)
		next_button.pressed.connect(_on_next_level)
		buttons.add_child(next_button)
		first_button = next_button
	var retry_button := Kit.button(_t("debrief.retry"), 240, lost)
	retry_button.pressed.connect(_on_retry_level)
	buttons.add_child(retry_button)
	if first_button == null and lost:
		first_button = retry_button
	var again_button := Kit.button(_t("debrief.again"), 280, status == "game_won")
	again_button.pressed.connect(_start_mission)
	buttons.add_child(again_button)
	if first_button == null:
		first_button = again_button
	overlay_content.add_child(buttons)

	# the real flares of this level: only the turns that were played
	if bool(game.get_level_info()["has_storms"]):
		overlay_content.add_child(Kit.label(_t("debrief.storms_heading"), 24, Kit.C_SUN))
		var cards: Array = d["storms"]
		if cards.is_empty():
			overlay_content.add_child(Kit.label(_t("debrief.no_storms_played"), 17, Kit.C_MUTED))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		for card in cards:
			grid.add_child(_storm_card(card))
		overlay_content.add_child(grid)

	overlay_content.add_child(Kit.label(_t("debrief.battery_chart"), 24, Kit.C_SUN))
	overlay_content.add_child(_battery_chart(d))
	overlay_content.add_child(Kit.label(_t("debrief.battery_chart_note"), 15, Kit.C_MUTED, true))

	var moon := _moon_chart(d)
	if moon != null:
		overlay_content.add_child(Kit.label(_t("debrief.moon_chart"), 24, Kit.C_SUN))
		overlay_content.add_child(moon)
		overlay_content.add_child(Kit.label(
			_t("debrief.moon_chart_note", {"date": _fmt_date(str(StormsData.DATA["saved_on"]))}), 15, Kit.C_MUTED, true
		))

	if d["recycler_saved"] != null:
		overlay_content.add_child(Kit.label(_t("debrief.recycler_saved", {"n": d["recycler_saved"]}), 20, Kit.C_WATER, true))
	overlay_content.add_child(Kit.label(_t("debrief.reflection"), 22, Kit.C_SUN, true))
	_focus(first_button)


func _on_next_level() -> void:
	sound.play("click")
	game.next_level()
	_show_intro()


func _on_retry_level() -> void:
	game.retry_level()
	_begin_level()


func _storm_card(card: Dictionary) -> Control:
	var followed := bool(card["followed"])
	var node := Kit.striped_card(Kit.C_DANGER if followed else Kit.C_MUTED)
	node.custom_minimum_size = Vector2(405, 0)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := Kit.vbox(4)
	node.add_child(box)
	box.add_child(Kit.label(_t("debrief.storm_turn", {"turn": card["turn"], "full_class": card["full_class"]}), 21))
	box.add_child(Kit.label(_t("debrief.storm_card", {"date": _fmt_date(str(card["date"]))}), 15, Kit.C_MUTED, true))
	box.add_child(Kit.label(
		_t("debrief.followed_yes") if followed else _t("debrief.followed_no"), 18,
		Kit.C_DANGER if followed else Kit.C_GOOD, true
	))
	box.add_child(Kit.label(
		(_t("debrief.sheltered") if bool(card["sheltered"]) else _t("debrief.stayed"))
		+ " " + _t("debrief.dose_gain", {"dose": _num(float(card["dose"]))}), 17, Kit.C_TEXT, true
	))
	# The strongest flare of the turn is not always the one that sent the storm.
	var causes: Array = card["causes"]
	var others: Array = []
	for cause in causes:
		if str(cause["link"]) != str(card["link"]):
			others.append(cause)
	if others.size() == 1 and causes.size() == 1:
		box.add_child(Kit.label(_t("debrief.caused_by", {
			"full_class": others[0]["full_class"], "date": _fmt_date(str(others[0]["date"])),
		}), 15, Kit.C_MUTED, true))
		box.add_child(Kit.link(_t("debrief.storm_link", {"full_class": others[0]["full_class"]}), str(others[0]["link"])))
	elif not others.is_empty():
		box.add_child(Kit.label(_t("debrief.caused_by_many"), 15, Kit.C_MUTED, true))
		for cause in causes:
			box.add_child(Kit.link(_t("debrief.storm_link_short", {
				"full_class": cause["full_class"], "date": _fmt_date(str(cause["date"])),
			}), str(cause["link"])))
	box.add_child(Kit.link(_t("debrief.storm_link", {"full_class": card["full_class"]}), str(card["link"])))
	return node


## The battery at the end of every turn played.
func _battery_chart(d: Dictionary) -> BarChart:
	var history: Array = d["history"]
	var columns: Array = []
	for turn_number in range(1, _n("TURNS_PER_LEVEL") + 1):
		var column := {"turn": turn_number, "night": turn_number > _n("DAY_TURNS")}
		if turn_number <= history.size():
			var battery := float(history[turn_number - 1]["battery"])
			column["height"] = battery / float(_n("BATTERY_MAX"))
			column["text"] = _num(battery)
		else:
			column["unplayed"] = true
		columns.append(column)
	var chart := BarChart.new()
	chart.set_columns(columns)
	return chart


## Radiation really measured at the Moon in this level's month, as "times a quiet
## day". Shown after the level only; it never decides anything in the game.
func _moon_chart(d: Dictionary) -> BarChart:
	var quiet: Variant = StormsData.DATA.get("moon_quiet")
	if d["moon_dose"] == null or quiet == null:
		return null
	var values: Array = d["moon_dose"]
	var storm_turns: Array = d["storm_turns"]
	var top := 1.0
	for value in values:
		if value != null:
			top = maxf(top, float(value) / float(quiet))
	var columns: Array = []
	for i in values.size():
		var turn_number := i + 1
		var column := {"turn": turn_number, "night": turn_number > _n("DAY_TURNS")}
		if values[i] == null:
			column["unplayed"] = true
		else:
			var times := float(values[i]) / float(quiet)
			column["height"] = times / top
			column["text"] = _t("debrief.moon_times", {"n": str(int(roundf(times))) if times >= 10.0 else _num(times)})
			if storm_turns.has(turn_number):
				column["storm"] = true
				column["mark"] = _t("debrief.moon_storm")
		columns.append(column)
	var chart := BarChart.new()
	chart.day_color = Kit.C_WATER
	chart.night_color = Kit.C_WATER
	chart.set_columns(columns)
	return chart
