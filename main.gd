extends Control

const GameState = preload("res://game_state.gd")

@export var orbit_texture: Texture2D
@export var greenhouse_plant0_texture: Texture2D
@export var greenhouse_plant1_texture: Texture2D

var game := GameState.new()
var in_greenhouse := false

@onready var artwork: TextureRect = $Artwork
@onready var placeholder: Label = $Placeholder
@onready var hud: Label = $TopBar/HUD
@onready var job_label: Label = $TopBar/JobLabel
@onready var job_bar: ProgressBar = $TopBar/JobBar
@onready var orbit_button: Button = $TopBar/Orbit
@onready var greenhouse_button: Button = $TopBar/Greenhouse
@onready var notice: Label = $BottomBar/Notice
@onready var room_status: Label = $BottomBar/RoomStatus
@onready var crop_picker: OptionButton = $BottomBar/Actions/CropPicker
@onready var plant_button: Button = $BottomBar/Actions/Plant
@onready var harvest_button: Button = $BottomBar/Actions/Harvest
@onready var scan_button: Button = $BottomBar/Actions/Scan
@onready var supplies_button: Button = $BottomBar/Actions/Supplies
@onready var shield_button: Button = $BottomBar/Actions/Shield
@onready var wait_button: Button = $BottomBar/Actions/Wait
@onready var next_button: Button = $BottomBar/Actions/Next
@onready var reset_button: Button = $BottomBar/Actions/Reset


func _ready() -> void:
	for crop in GameState.CROPS:
		crop_picker.add_item("%s · %d days · +%d food" % [
			crop["name"], crop["grow_days"], crop["yield"]
		])
	crop_picker.select(0)
	job_bar.max_value = GameState.MAX_JOB_STANDING

	orbit_button.pressed.connect(_show_room.bind(false))
	greenhouse_button.pressed.connect(_show_room.bind(true))
	plant_button.pressed.connect(func() -> void:
		game.plant(crop_picker.selected)
		_refresh()
	)
	harvest_button.pressed.connect(func() -> void:
		game.harvest()
		_refresh()
	)
	scan_button.pressed.connect(func() -> void:
		game.scan_sun()
		_refresh()
	)
	supplies_button.pressed.connect(func() -> void:
		game.request_supplies()
		_refresh()
	)
	shield_button.pressed.connect(func() -> void:
		game.raise_shields()
		_refresh()
	)
	wait_button.pressed.connect(func() -> void:
		game.wait_one_turn()
		_refresh()
	)
	next_button.pressed.connect(func() -> void:
		game.start_next_cycle()
		_refresh()
	)
	reset_button.pressed.connect(func() -> void:
		game = GameState.new()
		crop_picker.select(0)
		_show_room(false)
	)

	# Optional PNGs. Inspector assignments take priority over these paths.
	orbit_texture = _find_art(orbit_texture, "res://assets/orbit.png")
	greenhouse_plant0_texture = _find_art(
		greenhouse_plant0_texture, "res://assets/greenhouse_plant0.png"
	)
	greenhouse_plant1_texture = _find_art(
		greenhouse_plant1_texture, "res://assets/greenhouse_plant1.png"
	)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_show_room(false)
		KEY_2:
			_show_room(true)
		_:
			return
	get_viewport().set_input_as_handled()


func _show_room(show_greenhouse: bool) -> void:
	in_greenhouse = show_greenhouse
	_refresh()


func _refresh() -> void:
	var stage := game.crop_stage()
	var empty := stage == GameState.CropStage.EMPTY
	var harvestable := stage == GameState.CropStage.READY
	var storm_in := GameState.DAYS_PER_CYCLE - game.day
	var forecast := "STORM IN %d DAYS" % storm_in
	var fired := game.job_standing == 0
	if game.storm_resolved:
		forecast = "STORM PASSED"
	if fired:
		forecast = "MISSION ENDED"
	hud.text = "CYCLE %02d    DAY %02d / %d    ACTIONS %d    FOOD %d    |    %s" % [
		game.cycle, game.day, GameState.DAYS_PER_CYCLE, game.actions_left(), game.food, forecast
	]
	job_label.text = "JOB STANDING %d/%d" % [game.job_standing, GameState.MAX_JOB_STANDING]
	job_bar.value = game.job_standing
	orbit_button.set_pressed_no_signal(not in_greenhouse)
	greenhouse_button.set_pressed_no_signal(in_greenhouse)

	artwork.texture = orbit_texture
	placeholder.text = "ORBIT"
	room_status.text = _orbit_status()
	if in_greenhouse:
		artwork.texture = (
			greenhouse_plant1_texture if harvestable else greenhouse_plant0_texture
		)
		placeholder.text = "GREENHOUSE / STATE %d" % int(harvestable)
		room_status.text = _crop_status(stage)
	placeholder.visible = artwork.texture == null

	var taking_actions := game.can_act()
	crop_picker.visible = in_greenhouse and empty and taking_actions
	plant_button.visible = crop_picker.visible
	harvest_button.visible = in_greenhouse and harvestable and taking_actions
	var orbit_actions := not in_greenhouse and taking_actions
	scan_button.visible = orbit_actions
	scan_button.disabled = game.report_status != GameState.ReportStatus.UNSCANNED
	supplies_button.visible = orbit_actions
	supplies_button.tooltip_text = "Send the report to Earth and request food."
	if game.report_status != GameState.ReportStatus.READY:
		supplies_button.tooltip_text = "Without a fresh report, Earth will deny food and deduct 1 job standing."
	shield_button.visible = orbit_actions
	shield_button.disabled = game.shielded
	wait_button.visible = taking_actions
	next_button.visible = game.storm_resolved and not fired
	notice.text = game.notice


func _orbit_status() -> String:
	var shields := "Shields raised" if game.shielded else "Shields down"
	match game.report_status:
		GameState.ReportStatus.READY:
			return "%s flare forecast · Report ready to send · %s" % [game.flare_strength(), shields]
		GameState.ReportStatus.SENT:
			return "%s flare forecast · Report sent · Food inbound · %s" % [game.flare_strength(), shields]
		_:
			return "Forecast unknown · Requesting supplies now costs 1 job standing · %s" % shields


func _crop_status(stage: int) -> String:
	if stage == GameState.CropStage.EMPTY:
		return "Plot empty · Choose a crop and plant it"
	var crop: Dictionary = GameState.CROPS[game.crop_index]
	if stage == GameState.CropStage.READY:
		return "%s · Ready to harvest for %d food" % [crop["name"], crop["yield"]]
	return "%s · Growing · %d days until harvest" % [
		crop["name"], int(crop["grow_days"]) - game.crop_age
	]


func _find_art(assigned: Texture2D, path: String) -> Texture2D:
	if assigned != null:
		return assigned
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	return null
