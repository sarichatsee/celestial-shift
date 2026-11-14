extends Node
## The game's sounds. Each cue plays its file from sound_effects/. If a file is
## missing, the cue falls back to a short beep made in code, so the game never
## goes silent or fails because of a sound. Nothing plays before the player
## presses a button.
##
##   play("click" | "invalid" | "alert" | "storm_hit" | "shelter" | "shield"
##        | "false_alarm" | "low" | "level_won" | "lost")
##
## Clicks have their own player, so a click never cuts off a storm sound.

const FOLDER := "res://sound_effects/"
const MIX_RATE := 22050
const VOLUME := 9000.0  # of 32767, for the code-made beeps
const MAX_SECONDS := 6.0  # longer sounds fade out here, so they do not run into the next turns
const FADE_SECONDS := 1.0

## Cue -> [file, gain in dB]. The gains bring the files to a similar level:
## they come from each file's measured peak, not from listening. Adjust by ear.
const FILES := {
	"click": ["button_click.mp3", 4.0],
	"invalid": ["invalid_action.mp3", -2.0],
	"alert": ["storm_alert.mp3", 10.0],
	"storm_hit": ["storm_hit.mp3", -6.0],
	"shelter": ["shield_activate.mp3", -1.0],  # a storm came and the crew was sheltered
	"shield": ["shield_activate.mp3", -1.0],  # a shield layer was finished
	"false_alarm": ["false_alarm.mp3", 0.0],
	"low": ["low_resource_alert.mp3", -6.0],
	"level_won": ["level_won.mp3", -4.0],
	"lost": ["level_lost.mp3", 6.0],
}
const UI_CUES := ["click", "invalid"]

## The fallback beeps. Each is a list of notes: [frequency in Hz, length in seconds].
const BEEPS := {
	"click": [[660.0, 0.05]],
	"invalid": [[220.0, 0.09], [196.0, 0.12]],
	"alert": [[880.0, 0.12], [660.0, 0.12], [880.0, 0.14]],
	"storm_hit": [[220.0, 0.18], [165.0, 0.26]],
	"shelter": [[440.0, 0.08], [330.0, 0.14]],
	"shield": [[392.0, 0.08], [523.25, 0.14]],
	"false_alarm": [[523.25, 0.1], [659.25, 0.14]],
	"low": [[330.0, 0.14], [330.0, 0.14]],
	"level_won": [[523.25, 0.12], [659.25, 0.12], [783.99, 0.22]],
	"lost": [[392.0, 0.18], [329.63, 0.18], [261.63, 0.3]],
}

var muted := false

var _ui_player: AudioStreamPlayer
var _event_player: AudioStreamPlayer
var _streams := {}  # cue -> AudioStream
var _gains := {}  # cue -> dB
var _fade: Tween


func _ready() -> void:
	_ui_player = AudioStreamPlayer.new()
	add_child(_ui_player)
	_event_player = AudioStreamPlayer.new()
	add_child(_event_player)
	for cue in BEEPS:
		var file: Array = FILES.get(cue, [])
		var path := FOLDER + str(file[0]) if not file.is_empty() else ""
		if path != "" and ResourceLoader.exists(path):
			_streams[cue] = load(path)
			_gains[cue] = float(file[1])
		else:
			_streams[cue] = _make_beep(BEEPS[cue])
			_gains[cue] = 0.0


## True when the cue plays its file (false: the code-made beep).
func uses_file(cue: String) -> bool:
	return _streams.get(cue) is AudioStreamMP3


func play(cue: String) -> void:
	if muted or not _streams.has(cue):
		return
	var stream: AudioStream = _streams[cue]
	if cue in UI_CUES:
		_ui_player.stream = stream
		_ui_player.volume_db = float(_gains[cue])
		_ui_player.play()
		return
	if _fade != null:
		_fade.kill()
	_event_player.stream = stream
	_event_player.volume_db = float(_gains[cue])
	_event_player.play()
	if stream.get_length() > MAX_SECONDS + FADE_SECONDS:
		_fade = create_tween()
		_fade.tween_interval(MAX_SECONDS)
		_fade.tween_property(_event_player, "volume_db", -60.0, FADE_SECONDS)
		_fade.tween_callback(_event_player.stop)


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		if _fade != null:
			_fade.kill()
		if _ui_player != null:
			_ui_player.stop()
		if _event_player != null:
			_event_player.stop()


func _make_beep(notes: Array) -> AudioStreamWAV:
	var total := 0
	for note in notes:
		total += int(float(note[1]) * MIX_RATE)
	var data := PackedByteArray()
	data.resize(total * 2)  # 16-bit mono
	var offset := 0
	for note in notes:
		var frequency := float(note[0])
		var count := int(float(note[1]) * MIX_RATE)
		for i in count:
			# a quick fade in and out, so the beep does not click
			var envelope: float = minf(1.0, minf(float(i) / 150.0, float(count - i) / 500.0))
			var sample := int(sin(TAU * frequency * float(i) / float(MIX_RATE)) * envelope * VOLUME)
			data.encode_s16(offset, sample)
			offset += 2
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
