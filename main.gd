extends Control
## The screen of Lunar Night Shift, in the style of the Orbit 27 controls
## prototype: full-screen artwork, a top bar with the HUD, and a bottom bar with
## the mission line and the controls, grouped by what they are for.
##
## It draws the state, reads clicks and calls the rules (game_state.gd). It never
## changes a game number itself, and every word comes from game_text.gd.
##
## NO PEEKING: before a turn is played this file only knows what
## game.alert_for_turn() returns (flare class, date, dots). Whether a storm
## followed is read from game.get_debrief(), which holds played turns only.

const GameState = preload("res://game_state.gd")
const Numbers = preload("res://game_numbers.gd")
const GameText = preload("res://game_text.gd")
const StormsData = preload("res://storms_data.gd")
const Kit = preload("res://ui_kit.gd")
const BarChart = preload("res://bar_chart.gd")
const DotRow = preload("res://dot_row.gd")
const SoundFx = preload("res://sound_fx.gd")
const LiveSun = preload("res://live_sun.gd")
const MoonBaseView = preload("res://moon_base_view.gd")
const StarRow = preload("res://star_row.gd")
const Facts = preload("res://facts.gd")

# Display-only settings (they never change a rule).
const AIR_LOW_PCT := 30.0  # the Air meter warns under this
const DOSE_HIGH := 60.0  # same line as the "radiation is high" tip
const STEPPERS := ["life_support", "shield", "science", "charge"]
## The controls in the bottom bar, grouped by purpose: [words key, steppers, colour].
## The greenhouse switch joins the first group on levels that have one.
const GROUPS := [
	["running", ["life_support", "charge"], Kit.C_GOOD],
	["protection", ["shield"], Kit.C_WATER],
	["science", ["science"], Kit.C_SUN],
]
## The buildings of the Moon base that open a card when clicked, and where each
## one is on the 1280 x 720 canvas (moon_base_view.gd draws them there). The
## areas are bigger than the drawings so they are easy to hit.
const PARTS := ["solar", "battery", "science", "base", "shelter", "greenhouse", "water"]
const PART_RECTS := {
	"solar": Rect2(42, 356, 272, 102),
	"battery": Rect2(340, 362, 88, 96),
	"science": Rect2(432, 330, 120, 128),
	"base": Rect2(596, 296, 208, 162),
	"shelter": Rect2(850, 366, 96, 92),
	"greenhouse": Rect2(960, 374, 174, 84),
	"water": Rect2(1138, 348, 56, 110),
}

## Optional picture of the Moon base. Without one the base is drawn in code
## (moon_base_view.gd) and shows the game state.
@export var base_texture: Texture2D
@export var greenhouse_plant0_texture: Texture2D
@export var greenhouse_plant1_texture: Texture2D

var T: Dictionary = GameText.TEXT
var game := GameState.new()
var screen := "title"  # "title", "intro", "game", "debrief" or "science"
var in_greenhouse := false  # looking inside the greenhouse
var open_part := ""  # the building whose card is open, or ""

var plan: Dictionary = GameState.new_plan()  # the player's plan for this turn (not sent yet)
var choice := ""  # on an alert turn: "" (not chosen yet), "shelter" or "stay"
var science_before_shelter := 0
var hint := ""  # a one-off friendly message (night falls, new meters)
var last_control := ""  # the control touched last: its hint shows in the notice line
var report: Dictionary = {}  # what happened on the turn just played
var note := ""  # the real-life fact told this turn (a fact id), or ""
var facts_seen := {}  # the facts already told in this game: each is told once
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
var alert_stakes: Label
var alert_cost: Label
var goals_panel: PanelContainer
var note_panel: PanelContainer
var note_label: Label
var alert_note: Label
var _goal_rows := {}  # "safe" / "science" / "missions" -> {star, words}
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
var base_view: MoonBaseView
var click_hint: Label
var part_card: PanelContainer
var part_card_box: VBoxContainer
var _hotspots := {}
var _card_updates: Array[Callable] = []
var _card_wide := 430.0
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
@onready var back_button: Button = $TopBar/Back
@onready var bottom_bar: ColorRect = $BottomBar
@onready var room_status: Label = $BottomBar/RoomStatus
@onready var tools: HBoxContainer = $BottomBar/Tools
@onready var notice: Label = $BottomBar/Notice
@onready var actions: HBoxContainer = $BottomBar/Actions


func _ready() -> void:
	# Optional PNGs. Inspector assignments take priority over these paths.
	base_texture = _find_art(base_texture, "res://assets/moon_base.png")
	greenhouse_plant0_texture = _find_art(greenhouse_plant0_texture, "res://assets/greenhouse_plant0.png")
	greenhouse_plant1_texture = _find_art(greenhouse_plant1_texture, "res://assets/greenhouse_plant1.png")

	back_button.text = _t("rooms.back")
	back_button.pressed.connect(_show_room.bind(false))
	click_hint = Kit.label(_t("rooms.click_hint"), 16, Kit.C_MUTED)
	click_hint.position = Vector2(24, 0)
	click_hint.size = Vector2(330, 74)
	click_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(click_hint)
	dose_bar.add_theme_stylebox_override("background", Kit.flat(Kit.C_WELL, 6, Kit.C_LINE, 1))
	dose_bar.add_theme_stylebox_override("fill", Kit.flat(Kit.C_DANGER, 6))

	sound = SoundFx.new()
	add_child(sound)

	_build_base_view()
	_build_hotspots()
	_build_meters()
	_build_alert()
	_build_note()
	_build_goals()
	_build_report()
	_build_part_card()
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
			_show_room(true)  # look inside the greenhouse
		KEY_ESCAPE:
			if open_part != "":
				_close_part()
			elif in_greenhouse:
				_show_room(false)
			else:
				return
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
## The drawn view of the Moon base, just above the artwork layer.
func _build_base_view() -> void:
	base_view = MoonBaseView.new()
	add_child(base_view)
	move_child(base_view, artwork.get_index() + 1)
	base_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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
	alert_panel.position = Vector2(390, 88)  # between the meters panel and the goals panel
	alert_panel.custom_minimum_size = Vector2(556, 0)
	alert_panel.visible = false
	add_child(alert_panel)
	var box := Kit.vbox(6)
	alert_panel.add_child(box)
	var head := Kit.hbox(14)
	head.add_child(Kit.label(_t("alert.heading"), 16, Kit.C_SUN))
	alert_title = Kit.label("", 22)
	head.add_child(alert_title)
	alert_when = Kit.label("", 14, Kit.C_MUTED)
	alert_when.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alert_when.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(alert_when)
	box.add_child(head)
	var odds := Kit.hbox(10)
	alert_dots = DotRow.new()
	odds.add_child(alert_dots)
	alert_chance = Kit.label("", 18)
	odds.add_child(alert_chance)
	box.add_child(odds)
	# what is at stake if a storm comes: each answer says what it would add
	alert_stakes = Kit.label("", 17, Kit.C_SUN)
	box.add_child(alert_stakes)
	var choices := Kit.hbox(12)
	shelter_button = Kit.button("", 0)
	stay_button = Kit.button("", 0)
	for choice_button in [shelter_button, stay_button]:
		choice_button.toggle_mode = true
		choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_button.add_theme_font_size_override("font_size", 18)
		choices.add_child(choice_button)
	shelter_button.pressed.connect(_choose.bind("shelter"))
	stay_button.pressed.connect(_choose.bind("stay"))
	box.add_child(choices)
	alert_cost = Kit.label("", 15, Kit.C_MUTED)
	box.add_child(alert_cost)
	# a real-life fact, when there is one to tell on an alert turn
	alert_note = Kit.label("", 15, Kit.C_WATER, true)
	alert_note.custom_minimum_size.x = 526.0
	alert_note.visible = false
	box.add_child(alert_note)


## A real-life fact about what just happened, in the same place as the alert
## box. (On an alert turn the fact is a line inside the alert box instead.)
func _build_note() -> void:
	note_panel = PanelContainer.new()
	note_panel.add_theme_stylebox_override("panel", Kit.flat(Color(0.04, 0.09, 0.14, 0.95), 8, Kit.C_WATER, 2, 12))
	note_panel.position = Vector2(390, 88)
	note_panel.custom_minimum_size = Vector2(556, 0)
	note_panel.visible = false
	add_child(note_panel)
	var box := Kit.vbox(2)
	note_panel.add_child(box)
	box.add_child(Kit.label(_t("science.in_real_life"), 13, Kit.C_WATER))
	note_label = Kit.label("", 18, Kit.C_TEXT, true)
	note_label.custom_minimum_size.x = 526.0
	box.add_child(note_label)


## The three stars of this level, top right: what each one asks, and how far along it is.
func _build_goals() -> void:
	goals_panel = Kit.panel()
	goals_panel.position = Vector2(962, 88)
	goals_panel.custom_minimum_size = Vector2(294, 0)
	goals_panel.visible = false
	add_child(goals_panel)
	var box := Kit.vbox(4)
	goals_panel.add_child(box)
	box.add_child(Kit.label(_t("stars.heading"), 14, Kit.C_SUN))
	for key in ["safe", "science", "missions"]:
		var row := Kit.hbox(6)
		var star := StarRow.new()
		star.star_size = 18.0
		star.set_stars([false])
		row.add_child(star)
		var words := Kit.label("", 16)
		row.add_child(words)
		box.add_child(row)
		_goal_rows[key] = {"star": star, "words": words}


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
	# one box for each purpose, so the controls read as three jobs, not five dials
	for group in GROUPS:
		var color: Color = group[2]
		var group_panel := PanelContainer.new()
		group_panel.add_theme_stylebox_override("panel", Kit.flat(Kit.C_CARD, 8, Color(color, 0.55), 1, 8))
		actions.add_child(group_panel)
		var group_box := Kit.vbox(2)
		group_panel.add_child(group_box)
		group_box.add_child(Kit.label(_t("controls.groups." + str(group[0])), 13, color))
		var cells := Kit.hbox(12)
		group_box.add_child(cells)
		for key in group[1]:
			var cell := Kit.vbox(2)
			var name_label := Kit.label(_t("controls." + key), 16, Kit.C_TEXT)
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
			cells.add_child(cell)
			_steppers[key] = {"cell": cell, "minus": minus, "plus": plus, "value": value}
		if str(group[0]) == "running":
			greenhouse_cell = Kit.vbox(2)
			greenhouse_cell.add_child(Kit.label(_t("controls.greenhouse"), 16, Kit.C_TEXT))
			greenhouse_toggle = Kit.button(_t("controls.off"), 120)
			greenhouse_toggle.toggle_mode = true
			greenhouse_toggle.tooltip_text = _t("controls.hints.greenhouse") + " " + _t("controls.greenhouse_cost") + "."
			greenhouse_toggle.pressed.connect(_toggle_greenhouse)
			greenhouse_cell.add_child(greenhouse_toggle)
			cells.add_child(greenhouse_cell)

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
	goals_panel.visible = showing
	if not showing:
		note_panel.visible = false
		_close_part()
		for key in _hotspots:
			(_hotspots[key] as Button).visible = false
		alert_panel.visible = false
		report_panel.visible = false


# ---------------------------------------------------------------- title, intro, science
func _show_title() -> void:
	screen = "title"
	in_greenhouse = false
	_open_overlay(650.0)
	overlay_content.add_child(Kit.label(_t("title.name"), 54, Kit.C_SUN))
	overlay_content.add_child(Kit.label(_t("title.tagline"), 22, Kit.C_TEXT, true))
	var number := 1
	for line in T["title"]["how_to"]:
		var step_card := Kit.panel(Kit.C_CARD, 10, 6)
		step_card.add_child(Kit.label("%d.  %s" % [number, str(line)], 19, Kit.C_TEXT, true))
		overlay_content.add_child(step_card)
		number += 1
	# two games: a short one to start with, and the full one
	var buttons := Kit.hbox(12)
	var short_button := Kit.button(_t("title.start_short"), 210, true)
	short_button.pressed.connect(_start_mission.bind("short"))
	var full_button := Kit.button(_t("title.start_full"), 210)
	full_button.pressed.connect(_start_mission.bind("full"))
	var science_button := Kit.button(_t("title.science"), 230)
	science_button.pressed.connect(_show_science)
	buttons.add_child(short_button)
	buttons.add_child(full_button)
	buttons.add_child(science_button)
	overlay_content.add_child(buttons)
	var short_numbers: Dictionary = Numbers.SHORT
	var full_numbers: Dictionary = Numbers.DEFAULTS
	overlay_content.add_child(Kit.label(
		_t("title.start_short") + ": " + _t("title.short_note", {
			"levels": Numbers.LEVELS_SHORT.size(), "turns": short_numbers["TURNS_PER_LEVEL"],
		}) + "\n" + _t("title.start_full") + ": " + _t("title.full_note", {
			"levels": Numbers.LEVELS.size(), "turns": full_numbers["TURNS_PER_LEVEL"],
		}), 16, Kit.C_MUTED, true))
	overlay_content.add_child(_live_card())
	_focus(short_button)


## Start a new game: "short" or "full". Each new game gets its own missions.
func _start_mission(mode: String) -> void:
	sound.play("click")
	game.mission_seed = randi()
	game.set_mode(mode)
	new_meters_seen = false
	facts_seen = {}
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
	_open_overlay(500.0)
	var info := game.get_level_info()
	var total := _n("TURNS_PER_LEVEL")
	overlay_content.add_child(Kit.label(_t("intro.level", {"n": game.level, "total": game.levels.size()}), 16, Kit.C_STATUS))
	overlay_content.add_child(Kit.label(str(info["name"]), 46, Kit.C_SUN))
	overlay_content.add_child(Kit.label(str(game.level_text()["intro"]), 22, Kit.C_TEXT, true))
	if bool(info["has_storms"]):
		var first := str(game.turn_dates(1)["from"])
		var last := str(game.turn_dates(total)["to"])
		overlay_content.add_child(Kit.label(_t("intro.real_dates", {
			"from": _fmt_date(first, true, first.substr(0, 4) != last.substr(0, 4)), "to": _fmt_date(last, true),
		}), 20, Kit.C_WATER, true))
	# what the three stars of this level ask for
	var progress := game.get_progress()
	var goals := Kit.panel(Kit.C_CARD, 10, 6)
	var goals_box := Kit.vbox(4)
	goals.add_child(goals_box)
	goals_box.add_child(Kit.label(_t("stars.heading"), 14, Kit.C_SUN))
	for words in [
		_t("stars.safe"), _t("stars.science", {"goal": progress["science_goal"]}),
		_missions_goal_words(int(progress["missions_goal"])),
	]:
		goals_box.add_child(_star_line(false, str(words), 19))
	overlay_content.add_child(goals)
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
		if row.has("source"):
			real_side.add_child(Kit.link(_t("science.source_link", {"name": row["source_name"]}), str(row["source"])))
		if not bool(row["verified"]):
			real_side.add_child(Kit.label(_t("science.unverified"), 14, Kit.C_WARN, true))
		columns.add_child(game_side)
		columns.add_child(real_side)
		overlay_content.add_child(card)
	overlay_content.add_child(Kit.label(_t("science.notes_heading"), 24, Kit.C_SUN))
	for line in T["science"]["notes"]:
		overlay_content.add_child(Kit.label(str(line), 17, Kit.C_TEXT, true))
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


# ---------------------------------------------------------------- the buildings and their cards
## An invisible button over each building. A button gives hover, keyboard focus
## and Enter for free; the outline shows which building is open.
func _build_hotspots() -> void:
	var place := base_view.get_index() + 1
	for key in PARTS:
		var area: Rect2 = PART_RECTS[key]
		var spot := Button.new()
		spot.toggle_mode = true
		spot.position = area.position
		spot.size = area.size
		spot.tooltip_text = _t("rooms.labels." + key)
		spot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var open_look := Kit.flat(Color(1.0, 0.82, 0.29, 0.1), 10, Kit.C_SUN, 3)
		spot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		spot.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		spot.add_theme_stylebox_override("hover", Kit.flat(Color(1, 1, 1, 0.07), 10, Kit.C_SUN, 2))
		spot.add_theme_stylebox_override("pressed", open_look)
		spot.add_theme_stylebox_override("hover_pressed", open_look)
		spot.add_theme_stylebox_override("focus", Kit.flat(Color(0, 0, 0, 0), 10, Color.WHITE, 2))
		spot.visible = false
		spot.pressed.connect(_toggle_part.bind(key))
		add_child(spot)
		move_child(spot, place)
		place += 1
		_hotspots[key] = spot


func _build_part_card() -> void:
	part_card = PanelContainer.new()
	# solid, because a card can sit over the alert box
	part_card.add_theme_stylebox_override("panel", Kit.flat(Color(Kit.C_BAR, 1.0), 10, Kit.C_SUN, 2, 14))
	part_card.visible = false
	add_child(part_card)
	part_card_box = Kit.vbox(8)
	part_card.add_child(part_card_box)


## The greenhouse and the water tank arrive on Level 2.
func _part_exists(key: String) -> bool:
	return game.has_food() or not (key in ["greenhouse", "water"])


func _toggle_part(key: String) -> void:
	if open_part == key:
		_close_part()
		sound.play("click")
		_refresh()
	else:
		_open_part(key)


func _close_part() -> void:
	open_part = ""
	_card_updates.clear()
	if part_card != null:
		part_card.visible = false


## Open the card of one building: what it is for, its meter, and the same
## control as the bottom bar. The card changes the same plan; nothing is hidden
## in it that the bottom bar and the meters do not also show.
func _open_part(key: String) -> void:
	if screen != "game" or in_greenhouse or not _part_exists(key):
		return
	open_part = key
	_card_updates.clear()
	for child in part_card_box.get_children():
		part_card_box.remove_child(child)
		child.queue_free()

	var head := Kit.hbox(10)
	var title := Kit.label(_t("rooms.labels." + key), 22, Kit.C_SUN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Kit.button(_t("rooms.close"), Kit.TAP)
	close.pressed.connect(_toggle_part.bind(key))
	head.add_child(close)
	part_card_box.add_child(head)

	var wide := 430.0
	_card_wide = wide
	match key:
		"solar":
			_card_words(_t("rooms.about.solar", {"solar": _n("SOLAR_POWER")}))
		"battery":
			_card_words(_t("rooms.about.battery", {"max": _n("BATTERY_MAX")}))
			_card_meter(part_card_box, "battery", Kit.C_SUN)
			_card_stepper(part_card_box, "charge")
		"science":
			_card_words(_t("rooms.about.science"))
			var so_far := Kit.label("", 17)
			part_card_box.add_child(so_far)
			_card_updates.append(func() -> void:
				var now := game.get_progress()
				so_far.text = _t("rooms.science_so_far", {"science": now["level_science"], "goal": now["science_goal"]}))
			_card_stepper(part_card_box, "science")
		"base":
			wide = 640.0
			_card_wide = wide
			_card_words(_t("rooms.about.base"))
			var columns := Kit.hbox(24)
			part_card_box.add_child(columns)
			var air_side := Kit.vbox(8)
			air_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			columns.add_child(air_side)
			_card_meter(air_side, "air", Kit.C_GOOD)
			_card_stepper(air_side, "life_support")
			var shield_side := Kit.vbox(8)
			shield_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			columns.add_child(shield_side)
			var shield_row := Kit.hbox(8)
			shield_row.add_child(Kit.label(_t("meters.shield"), 17))
			var dots := DotRow.new()
			dots.on_color = Kit.C_STATUS
			shield_row.add_child(dots)
			var shield_words := Kit.label("", 14, Kit.C_MUTED)
			shield_row.add_child(shield_words)
			shield_side.add_child(shield_row)
			_card_updates.append(func() -> void:
				dots.set_dots(game.shield, _n("MAX_SHIELD"))
				shield_words.text = shield_note.text)
			_card_stepper(shield_side, "shield")
		"shelter":
			wide = 640.0
			_card_wide = wide
			_card_words(_t("rooms.about.shelter", {"cost": _n("SHELTER_COST")}))
			var quiet := Kit.label(_t("rooms.no_alert"), 17, Kit.C_MUTED)
			part_card_box.add_child(quiet)
			# on an alert turn the card repeats the whole alert, because it can
			# sit over the alert box: class, chance, stakes and the two answers
			var flare := Kit.label("", 18, Kit.C_SUN)
			part_card_box.add_child(flare)
			var odds := Kit.hbox(10)
			var odds_dots := DotRow.new()
			odds.add_child(odds_dots)
			var odds_words := Kit.label("", 16)
			odds.add_child(odds_words)
			part_card_box.add_child(odds)
			var stakes := Kit.label("", 16)
			part_card_box.add_child(stakes)
			var choices := Kit.hbox(10)
			var shelter_copy := Kit.button("", 0)
			shelter_copy.toggle_mode = true
			shelter_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			shelter_copy.pressed.connect(_choose.bind("shelter"))
			var stay_copy := Kit.button("", 0)
			stay_copy.toggle_mode = true
			stay_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stay_copy.pressed.connect(_choose.bind("stay"))
			choices.add_child(shelter_copy)
			choices.add_child(stay_copy)
			part_card_box.add_child(choices)
			var cost := Kit.label("", 15, Kit.C_MUTED)
			part_card_box.add_child(cost)
			_card_updates.append(func() -> void:
				var alert_now := game.alert_for_turn()
				var alert_up := not alert_now.is_empty()
				quiet.visible = not alert_up
				for part in [flare, odds, stakes, choices, cost]:
					(part as Control).visible = alert_up
				cost.text = alert_cost.text
				if alert_up:
					flare.text = alert_title.text
					odds_dots.set_dots(int(alert_now["dots"]), 10)
					odds_words.text = alert_chance.text
				stakes.text = alert_stakes.text
				shelter_copy.text = shelter_button.text
				stay_copy.text = stay_button.text
				shelter_copy.set_pressed_no_signal(choice == "shelter")
				stay_copy.set_pressed_no_signal(choice == "stay"))
		"greenhouse":
			_card_words(_t("rooms.about.greenhouse") + " " + _t("controls.hints.greenhouse"))
			_card_words(_t("controls.greenhouse_cost") + ".", 15, Kit.C_MUTED)
			_card_meter(part_card_box, "food", Kit.C_FOOD)
			var row := Kit.hbox(10)
			var toggle := Kit.button("", 120)
			toggle.toggle_mode = true
			toggle.pressed.connect(_toggle_greenhouse)
			row.add_child(toggle)
			var inside := Kit.button(_t("rooms.look_inside"), 150)
			inside.pressed.connect(_show_room.bind(true))
			row.add_child(inside)
			part_card_box.add_child(row)
			_card_updates.append(func() -> void:
				toggle.text = greenhouse_toggle.text
				toggle.set_pressed_no_signal(bool(plan["greenhouse"])))
		"water":
			_card_words(_t("rooms.about.water", {
				"used": _n("WATER_USED"), "more": _n("WATER_USED_NO_RECYCLER"), "needed": _n("LS_NEEDED"),
			}))
			_card_meter(part_card_box, "water", Kit.C_WATER)
			var recycler := Kit.label("", 16)
			part_card_box.add_child(recycler)
			_card_updates.append(func() -> void:
				var on: bool = int(plan["life_support"]) >= _n("LS_NEEDED")
				recycler.text = _t("meters.recycler_on") if on else _t("meters.recycler_off")
				recycler.add_theme_color_override("font_color", Kit.C_GOOD if on else Kit.C_WARN))

	# what this building is like in real life (a checked fact, or nothing)
	var fact_id := Facts.for_building(key)
	if fact_id != "":
		var real_head := Kit.label(_t("science.in_real_life"), 13, Kit.C_WATER)
		part_card_box.add_child(real_head)
		var real_words := _card_words(Facts.note(fact_id), 16)
		if key == "shelter":
			# on an alert turn the card is full: the alert comes first
			_card_updates.append(func() -> void:
				var quiet_turn := game.alert_for_turn().is_empty()
				real_head.visible = quiet_turn
				real_words.visible = quiet_turn)

	part_card.custom_minimum_size = Vector2(wide, 0)
	part_card.modulate.a = 0.0  # shown once it has been measured and placed
	part_card.visible = true
	sound.play("click")
	_refresh()
	_place_part_card(key)
	_focus(close)


## Put the card just above its building, clear of the meters panel on the left.
## Wrapped text only knows its height after a frame or two, so measure then.
func _place_part_card(key: String) -> void:
	var area: Rect2 = PART_RECTS[key]
	for pass_number in 3:
		await get_tree().process_frame
		await get_tree().process_frame
		if open_part != key:
			return
		part_card.reset_size()
		var card: Vector2 = part_card.size
		part_card.position = Vector2(
			clampf(area.get_center().x - card.x / 2.0, 390.0, maxf(390.0, 1256.0 - card.x)),
			maxf(84.0, area.position.y - card.y - 10.0))
		part_card.modulate.a = 1.0


## A line of words in the open card.
func _card_words(words: String, font_size: int = 17, color: Color = Kit.C_TEXT) -> Label:
	var line := Kit.label(words, font_size, color, true)
	line.custom_minimum_size.x = _card_wide - 30.0
	part_card_box.add_child(line)
	return line


## A copy of one meter from the meters panel, kept in step with it.
func _card_meter(into: Container, key: String, color: Color) -> void:
	var row := Kit.hbox(8)
	var name_label := Kit.label(_t("meters." + key), 17)
	name_label.custom_minimum_size = Vector2(70, 0)
	var bar := Kit.meter(color)
	var value_label := Kit.label("", 17)
	value_label.custom_minimum_size = Vector2(66, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)
	row.add_child(bar)
	row.add_child(value_label)
	into.add_child(row)
	_card_updates.append(func() -> void:
		var main_bar: ProgressBar = _meters[key]["bar"]
		bar.max_value = main_bar.max_value
		bar.value = main_bar.value
		value_label.text = (_meters[key]["value"] as Label).text)


## A copy of one bottom-bar control: the same plan, the same limits.
func _card_stepper(into: Container, key: String) -> void:
	var row := Kit.hbox(6)
	var name_label := Kit.label(_t("controls." + key), 16, Kit.C_STATUS)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var minus := Kit.button("-", Kit.TAP)
	var plus := Kit.button("+", Kit.TAP)
	for step_button in [minus, plus]:
		step_button.add_theme_font_size_override("font_size", 26)
	var value := Kit.label("0", 26)
	value.custom_minimum_size = Vector2(40, Kit.TAP)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	minus.pressed.connect(_step.bind(key, -1))
	plus.pressed.connect(_step.bind(key, 1))
	row.add_child(name_label)
	row.add_child(minus)
	row.add_child(value)
	row.add_child(plus)
	into.add_child(row)
	var note := Kit.label("", 14, Kit.C_MUTED, true)
	into.add_child(note)
	_card_updates.append(func() -> void:
		var main_stepper: Dictionary = _steppers[key]
		value.text = (main_stepper["value"] as Label).text
		minus.disabled = (main_stepper["minus"] as Button).disabled
		plus.disabled = (main_stepper["plus"] as Button).disabled
		note.text = _control_hint(key))


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
		_plan_sound()
	_refresh()


## The sound of a change to the plan: a click, or the "can't do that" sound
## when the plan no longer fits (the notice line says why).
func _plan_sound() -> void:
	sound.play("click" if game.check_plan(plan) == "ok" else "invalid")


## The meters that are low right now (the same test the meters panel uses).
func _low_meters() -> Array:
	var low: Array = []
	var total_turns := _n("TURNS_PER_LEVEL")
	var nights_left: int = total_turns - maxi(game.turn, _n("DAY_TURNS") + 1) + 1
	if not game.is_day() and game.battery + 1e-9 < float(_n("LS_NEEDED") * nights_left):
		low.append("battery")
	if float(game.air) / float(_n("AIR_MAX")) * 100.0 < AIR_LOW_PCT:
		low.append("air")
	if game.dose > DOSE_HIGH:
		low.append("radiation")
	if game.has_food():
		if game.water < 2 * _n("WATER_USED_NO_RECYCLER"):
			low.append("water")
		if game.food < 2 * _n("FOOD_EATEN"):
			low.append("food")
	return low


func _toggle_greenhouse() -> void:
	plan["greenhouse"] = not bool(plan["greenhouse"])
	last_control = "greenhouse"
	hint = ""
	_plan_sound()
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
	_plan_sound()
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
	if in_greenhouse:
		_close_part()
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
	var is_new := with_food and hint == _t("messages.new_meters")
	var progress := game.get_progress()

	# top bar
	var hud_values := {
		"level": game.level, "name": str(info["name"]).to_upper(), "turn": "%02d" % game.turn,
		"total": total_turns, "phase": _t("meters.day") if day else _t("meters.night"),
		"earned": progress["stars_earned"], "possible": progress["stars_possible"],
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
	back_button.visible = in_greenhouse
	click_hint.visible = not in_greenhouse

	# meters
	var low := _low_meters()
	_set_meter("battery", game.battery, float(_n("BATTERY_MAX")), low.has("battery"))
	_set_meter("air", float(game.air), float(_n("AIR_MAX")), low.has("air"))
	_set_meter("radiation", game.dose, float(_n("DOSE_LIMIT")), low.has("radiation"))
	for key in ["water", "food"]:
		var parts: Dictionary = _meters[key]
		(parts["row"] as Control).visible = with_food
		(parts["name"] as Label).text = _t("meters." + key) + ("  " + _t("meters.new") if is_new else "")
		(parts["name"] as Label).add_theme_color_override("font_color", Kit.C_SUN if is_new else Kit.C_TEXT)
	if with_food:
		_set_meter("water", float(game.water), float(_n("WATER_START")), low.has("water"))
		# a full Food bar feeds the whole level
		_set_meter("food", float(game.food), float(_n("FOOD_EATEN") * total_turns), low.has("food"))
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

	# the mission line (or, inside the greenhouse, what the greenhouse is doing)
	var mission := game.mission_for_turn()
	var status_color: Color = Kit.C_MUTED
	if in_greenhouse:
		room_status.text = _greenhouse_status(recycler_on)
		status_color = Kit.C_STATUS
	elif not mission.is_empty():
		var mission_ready := game.mission_met(plan)
		room_status.text = _t("missions.ready" if mission_ready else "missions.line", _mission_words(mission))
		status_color = Kit.C_SUN if mission_ready else Kit.C_TEXT
	else:
		var coming := game.next_mission()
		if coming.is_empty():
			room_status.text = _t("missions.none_left")
		else:
			room_status.text = _t("missions.next", {
				"name": _mission_words(coming["mission"])["name"], "turn": coming["turn"],
			})
	room_status.add_theme_color_override("font_color", status_color)

	# the three stars of this level
	var science_reached: bool = int(progress["level_science"]) >= int(progress["science_goal"])
	var missions_reached: bool = int(progress["missions_done"]) >= int(progress["missions_goal"])
	_set_goal("safe", false, _t("stars.safe"))  # only known at the end of the level
	_set_goal("science", science_reached, _t("stars.science_now", {
		"goal": progress["science_goal"], "now": progress["level_science"],
	}))
	_set_goal("missions", missions_reached, _t("stars.missions_now", {
		"text": _missions_goal_words(int(progress["missions_goal"])), "now": progress["missions_done"],
	}))
	goals_panel.reset_size.call_deferred()

	# what the saved record said about the last turn
	report_panel.visible = not report.is_empty()
	if not report.is_empty():
		var edge: Color = Kit.C_WATER
		if bool(report["hit"]):
			edge = Kit.C_DANGER
		elif bool(report["mission_done"]):
			edge = Kit.C_SUN
		report_label.text = _t("report.heading") + ":  " + str(report["text"])
		report_panel.add_theme_stylebox_override("panel", Kit.flat(Kit.C_PANEL, 8, edge, 2, 10))

	# a real-life fact about what just happened: its own box, or a line of the alert box
	var note_words := Facts.note(note) if note != "" else ""
	note_panel.visible = note_words != "" and alert.is_empty()
	note_label.text = note_words
	alert_note.visible = note_words != "" and not alert.is_empty()
	alert_note.text = _t("science.in_real_life") + ":  " + note_words
	if note_panel.visible:
		note_panel.reset_size.call_deferred()

	# the storm alert
	alert_panel.visible = not alert.is_empty()
	if not alert.is_empty():
		alert_title.text = _t("alert.title", {"full_class": alert["full_class"]})
		alert_dots.set_dots(int(alert["dots"]), 10)
		alert_dots.tooltip_text = "%d / 10" % int(alert["dots"])
		alert_chance.text = _t("alert.chance", {"dots": alert["dots"]})
		alert_when.text = _t("alert.when", {"date": _fmt_date(str(alert["date"]))})
		var stakes := game.storm_stakes(plan)  # numbers only: what a storm WOULD add
		alert_stakes.text = _t("alert.stakes")
		if bool(plan["shelter"]):
			alert_cost.text = _t("alert.cost_paid")
		elif int(plan["science"]) > 0:
			alert_cost.text = _t("alert.cost_science", {"cost": _n("SHELTER_COST"), "science": int(plan["science"])})
		else:
			alert_cost.text = _t("alert.cost", {"cost": _n("SHELTER_COST")})
		var shelter_words := _t("alert.shelter", {"dose": _num(stakes["shelter"])})
		var stay_words := _t("alert.stay", {"dose": _num(stakes["stay"])})
		shelter_button.text = _t("alert.chosen", {"text": shelter_words}) if choice == "shelter" else shelter_words
		stay_button.text = _t("alert.chosen", {"text": stay_words}) if choice == "stay" else stay_words
		shelter_button.set_pressed_no_signal(choice == "shelter")
		stay_button.set_pressed_no_signal(choice == "stay")
		alert_panel.reset_size.call_deferred()

	# the buildings, and the card of the one that is open
	if open_part != "" and (in_greenhouse or not _part_exists(open_part)):
		_close_part()
	for key in _hotspots:
		var spot: Button = _hotspots[key]
		spot.visible = not in_greenhouse and _part_exists(key)
		spot.set_pressed_no_signal(open_part == key)
	for update in _card_updates:
		update.call()

	_refresh_art()


## The picture behind everything: the Moon base or the greenhouse.
func _refresh_art() -> void:
	var playing := screen == "game"
	var growing := playing and bool(plan["greenhouse"])
	base_view.visible = not in_greenhouse and base_texture == null
	if in_greenhouse:
		artwork.texture = greenhouse_plant1_texture if growing else greenhouse_plant0_texture
		placeholder.text = _t("rooms.greenhouse_placeholder", {"state": int(growing)})
	else:
		artwork.texture = base_texture
		placeholder.text = _t("rooms.base_placeholder")
	if base_view.visible:
		base_view.set_view(_base_view_state())
	placeholder.visible = artwork.texture == null and not base_view.visible
	# the drawn base has its own night; a picture file gets a dark wash instead
	night_shade.color.a = 0.5 if (playing and not game.is_day() and not base_view.visible) else 0.0


## What the Moon base picture shows: the meters and the unsent plan, nothing
## more. The alert is the player's view of it (class only), never the outcome.
func _base_view_state() -> Dictionary:
	var playing := screen == "game"
	var with_food := game.has_food()
	var alert := game.alert_for_turn() if playing else {}
	var greenhouse := ""
	if with_food:
		greenhouse = "on" if (playing and bool(plan["greenhouse"])) else "off"
	var life_support_ok: bool = not playing or int(plan["life_support"]) >= _n("LS_NEEDED")
	var labels: Dictionary = T["rooms"]["labels"].duplicate()
	if playing and with_food and hint == _t("messages.new_meters"):
		for key in ["greenhouse", "water"]:
			labels[key] = str(labels[key]) + "  " + _t("meters.new")
	return {
		"is_day": game.is_day() if screen in ["game", "intro", "debrief"] else true,
		"battery": game.battery / float(_n("BATTERY_MAX")),
		"air": float(game.air) / float(_n("AIR_MAX")),
		"life_support_ok": life_support_ok,
		"science": playing and int(plan["science"]) > 0,
		"shield": game.shield,
		"shield_max": _n("MAX_SHIELD"),
		"shield_part": float(game.shield_progress) / float(_n("SHIELD_COST")),
		"sheltering": playing and bool(plan["shelter"]),
		"greenhouse": greenhouse,
		"food": float(game.food) / float(_n("FOOD_EATEN") * _n("TURNS_PER_LEVEL")) if with_food else 0.0,
		"water": float(game.water) / float(_n("WATER_START")) if with_food else -1.0,
		"recycler_on": life_support_ok,
		"alert": str(alert.get("cls", "")),
		"labels": labels,
	}


## The words of a mission: {name, ask, reward}, for the mission line and the reports.
func _mission_words(mission: Dictionary) -> Dictionary:
	var id := str(mission["id"])
	return {
		"name": _t("missions.names." + id),
		"ask": _t("missions.asks." + id, {"n": mission.get("at_least", 0)}),
		"reward": mission["reward"],
	}


func _missions_goal_words(goal: int) -> String:
	return _t("stars.missions_one") if goal == 1 else _t("stars.missions_many", {"goal": goal})


func _set_goal(key: String, reached: bool, words: String) -> void:
	var row: Dictionary = _goal_rows[key]
	(row["star"] as StarRow).set_stars([reached])
	(row["words"] as Label).text = words
	(row["words"] as Label).add_theme_color_override("font_color", Kit.C_SUN if reached else Kit.C_TEXT)


## One star (filled or empty) and a line of words.
func _star_line(reached: bool, words: String, font_size: int = 18) -> HBoxContainer:
	var row := Kit.hbox(8)
	var star := StarRow.new()
	star.star_size = float(font_size) + 2.0
	star.set_stars([reached])
	row.add_child(star)
	row.add_child(Kit.label(words, font_size, Kit.C_SUN if reached else Kit.C_TEXT, true))
	return row


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
	_close_part()
	_tell([] if game.alert_for_turn().is_empty() else ["alert"])
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
	var low_before := _low_meters()
	var shield_before := game.shield
	var played: Dictionary = plan.duplicate()
	var had_recycler: bool = game.has_food()
	var result := game.take_turn(plan.duplicate())
	var status := str(result["status"])
	if status == "invalid":
		sound.play("invalid")
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
	# One sound for the new turn, the most important first: a storm that came,
	# a new alert, a meter that has just gone low, a finished mission, the
	# all-clear after an alert, a finished shield layer, or a plain click.
	var cue := "click"
	var newly_low := false
	for key in _low_meters():
		if not low_before.has(key):
			newly_low = true
	var alert_now := not game.alert_for_turn().is_empty()
	if alert_now:
		in_greenhouse = false  # look at the Sun
		_close_part()  # the alert box needs the space
	# One real-life fact about what just happened, the most important first.
	var events: Array = []
	if not report.is_empty() and bool(report["hit"]):
		events.append("storm")
		if played_turn > _n("DAY_TURNS"):
			events.append("storm_night")
		events.append("storm_more")
	elif not report.is_empty() and bool(report["alert"]):
		events.append("false_alarm")
	if alert_now:
		events.append("alert")
	if game.turn == _n("DAY_TURNS") + 1:
		events.append("night")
	if game.shield > shield_before:
		events.append("shield")
	if had_recycler and int(played["life_support"]) < _n("LS_NEEDED"):
		events.append("recycler_off")
	if bool(played["greenhouse"]):
		events.append("greenhouse")
	if int(played["charge"]) > 0:
		events.append("charge")
	_tell(events)
	if not report.is_empty() and bool(report["hit"]):
		cue = "shelter" if bool(report["sheltered"]) else "storm_hit"
	elif alert_now:
		cue = "alert"
	elif newly_low:
		cue = "low"
	elif not report.is_empty() and bool(report["mission_done"]):
		cue = "mission"
	elif not report.is_empty() and bool(report["alert"]):
		cue = "false_alarm"
	elif game.shield > shield_before:
		cue = "shield"
	sound.play(cue)
	_refresh()


## Choose the real-life fact for this turn from what just happened (see
## facts.gd). Each fact is told once in a game; most turns have none.
func _tell(events: Array) -> void:
	note = Facts.pick(events, facts_seen)
	if note != "":
		facts_seen[note] = true


## What happened on the turn that was just played: the mission, and what the
## saved record says about the alert. {} when there is nothing to say.
func _build_turn_report(played_turn: int) -> Dictionary:
	var d := game.get_debrief()
	var parts := PackedStringArray()
	var mission_done := false
	var missions_played: Array = d["missions"]
	if not missions_played.is_empty() and int(missions_played[missions_played.size() - 1]["turn"]) == played_turn:
		var entry: Dictionary = missions_played[missions_played.size() - 1]
		mission_done = bool(entry["done"])
		parts.append(_t("missions.done" if mission_done else "missions.missed", {
			"name": _t("missions.names." + str(entry["id"])), "reward": entry["reward"],
		}))
	var cards: Array = d["storms"]
	if cards.is_empty() or int(cards[cards.size() - 1]["turn"]) != played_turn:
		if parts.is_empty():
			return {}
		return {"text": " ".join(parts), "hit": false, "sheltered": false, "alert": false, "mission_done": mission_done}
	var card: Dictionary = cards[cards.size() - 1]
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
	return {
		"text": " ".join(parts), "hit": bool(card["followed"]), "sheltered": bool(card["sheltered"]),
		"alert": true, "mission_done": mission_done,
	}


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
	var why := _t("debrief.why." + str(result["reason"])) if lost else _t("debrief.why.won", {"turns": _n("TURNS_PER_LEVEL")})
	overlay_content.add_child(Kit.label(why, 22, Kit.C_TEXT, true))

	# the three stars of this level, and what each one was for
	var rating: Dictionary = d["rating"]
	var progress: Dictionary = d["progress"]
	var stars_card := Kit.panel(Kit.C_CARD, 12, 8)
	var stars_box := Kit.vbox(4)
	stars_card.add_child(stars_box)
	var stars_head := Kit.hbox(14)
	var big_stars := StarRow.new()
	big_stars.star_size = 40.0
	big_stars.set_stars([bool(rating["safe"]), bool(rating["safe"]) and bool(rating["science"]),
		bool(rating["safe"]) and bool(rating["missions"])])
	stars_head.add_child(big_stars)
	var stars_words := Kit.vbox(0)
	stars_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars_words.add_child(Kit.label(_t("stars.level_stars", {"n": rating["stars"]}), 24, Kit.C_SUN))
	stars_words.add_child(Kit.label(_t("stars.total", {
		"earned": progress["stars_earned"], "possible": progress["stars_possible"],
	}), 15, Kit.C_MUTED))
	stars_head.add_child(stars_words)
	stars_box.add_child(stars_head)
	if lost:
		stars_box.add_child(Kit.label(_t("stars.none"), 17, Kit.C_MUTED, true))
	stars_box.add_child(_star_line(bool(rating["safe"]), _t("stars.safe")))
	stars_box.add_child(_star_line(not lost and bool(rating["science"]), _t("stars.science_now", {
		"goal": progress["science_goal"], "now": progress["level_science"],
	})))
	stars_box.add_child(_star_line(not lost and bool(rating["missions"]), _t("stars.missions_now", {
		"text": _missions_goal_words(int(progress["missions_goal"])), "now": progress["missions_done"],
	})))
	overlay_content.add_child(stars_card)
	overlay_content.add_child(Kit.label(_t("debrief.score", {
		"science": progress["science"], "dose": _num(game.dose), "limit": _n("DOSE_LIMIT"), "shield": game.shield,
		"max": _n("MAX_SHIELD"),
	}), 17, Kit.C_MUTED))

	var tip_card := Kit.striped_card(Kit.C_SUN)
	tip_card.add_child(Kit.label(_t("debrief.tip_heading") + ":  " + str(d["tip"]), 19, Kit.C_TEXT, true))
	overlay_content.add_child(tip_card)

	# one question about this level, to talk over
	var question_card := Kit.striped_card(Kit.C_WATER)
	question_card.add_child(Kit.label(
		_t("debrief.question_heading") + ":  " + str(game.level_text().get("question", _t("debrief.reflection"))),
		19, Kit.C_TEXT, true))
	overlay_content.add_child(question_card)

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
	again_button.pressed.connect(_start_mission.bind(game.mode))
	buttons.add_child(again_button)
	if first_button == null:
		first_button = again_button
	overlay_content.add_child(buttons)

	# the missions of the turns that were played
	var mission_log: Array = d["missions"]
	if not mission_log.is_empty():
		overlay_content.add_child(Kit.label(_t("missions.debrief_heading"), 24, Kit.C_SUN))
		for entry in mission_log:
			var mission_was_done := bool(entry["done"])
			overlay_content.add_child(Kit.label(
				_t("missions.debrief_done" if mission_was_done else "missions.debrief_missed", {
					"turn": entry["turn"], "name": _t("missions.names." + str(entry["id"])), "reward": entry["reward"],
				}), 17, Kit.C_TEXT if mission_was_done else Kit.C_MUTED))

	# the real flares of this level: only the turns that were played
	if bool(game.get_level_info()["has_storms"]):
		overlay_content.add_child(Kit.label(_t("debrief.storms_heading"), 24, Kit.C_SUN))
		var cards: Array = d["storms"]
		if cards.is_empty():
			overlay_content.add_child(Kit.label(_t("debrief.no_storms_played"), 17, Kit.C_MUTED))
		else:
			overlay_content.add_child(_recap_card(cards))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		for card in cards:
			grid.add_child(_storm_card(card))
		overlay_content.add_child(grid)

	overlay_content.add_child(Kit.label(_t("debrief.battery_chart"), 24, Kit.C_SUN))
	overlay_content.add_child(_battery_chart(d))
	overlay_content.add_child(Kit.label(_t("debrief.battery_chart_note", {
		"day_end": _n("DAY_TURNS"), "night_start": _n("DAY_TURNS") + 1, "last": _n("TURNS_PER_LEVEL"),
	}), 15, Kit.C_MUTED, true))

	var moon := _moon_chart(d)
	if moon != null:
		overlay_content.add_child(Kit.label(_t("debrief.moon_chart"), 24, Kit.C_SUN))
		overlay_content.add_child(moon)
		overlay_content.add_child(Kit.label(
			_t("debrief.moon_chart_note", {"date": _fmt_date(str(StormsData.DATA["saved_on"]))}), 15, Kit.C_MUTED, true
		))

	if d["recycler_saved"] != null:
		overlay_content.add_child(Kit.label(_t("debrief.recycler_saved", {"n": d["recycler_saved"]}), 20, Kit.C_WATER, true))
	_focus(first_button)


func _on_next_level() -> void:
	sound.play("click")
	game.next_level()
	_show_intro()


func _on_retry_level() -> void:
	game.retry_level()
	_begin_level()


## "What really happened": the player's answers to the alerts next to the real
## record. Counts only, from the turns that were played.
func _recap_card(cards: Array) -> Control:
	var storms := 0
	var sheltered := 0
	var sheltered_for_nothing := 0
	var stayed_and_hit := 0
	var dose_from_staying := 0.0
	for card in cards:
		var followed := bool(card["followed"])
		var in_shelter := bool(card["sheltered"])
		storms += int(followed)
		sheltered += int(in_shelter)
		if in_shelter and not followed:
			sheltered_for_nothing += 1
		if followed and not in_shelter:
			stayed_and_hit += 1
			dose_from_staying += float(card["dose"])
	var node := Kit.striped_card(Kit.C_WATER)
	var box := Kit.vbox(4)
	node.add_child(box)
	box.add_child(Kit.label(_t("debrief.recap_heading"), 20, Kit.C_WATER))
	box.add_child(Kit.label(" ".join(PackedStringArray([
		_count_words("debrief.recap_alerts", cards.size()), _count_words("debrief.recap_storms", storms),
		_count_words("debrief.recap_sheltered", sheltered),
	])), 18, Kit.C_TEXT, true))
	var closing := PackedStringArray()
	if stayed_and_hit > 0:
		closing.append(_t("debrief.recap_hits", {"dose": _num(dose_from_staying)}))
	if sheltered_for_nothing > 0:
		closing.append(_t("debrief.recap_extra"))
	if closing.is_empty():
		closing.append(_t("debrief.recap_match"))
	box.add_child(Kit.label(" ".join(closing), 17, Kit.C_MUTED, true))
	return node


## "1 time" or "3 times": the words at `path` + "_none", "_one" or "_many".
func _count_words(path: String, count: int) -> String:
	if count == 1:
		return _t(path + "_one")
	if count == 0 and path != "debrief.recap_alerts":
		return _t(path + "_none")
	return _t(path + "_many", {"n": count})


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
