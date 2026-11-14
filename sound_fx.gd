extends Node
## Short beeps made in code. There are no sound files, so there are no licences
## to track, and nothing plays before the player presses a button.
##
##   play("click" | "alert" | "storm_hit" | "shelter" | "level_won" | "lost")

const MIX_RATE := 22050
const VOLUME := 9000.0  # of 32767

## Each sound is a list of notes: [frequency in Hz, length in seconds].
const SOUNDS := {
	"click": [[660.0, 0.05]],
	"alert": [[880.0, 0.12], [660.0, 0.12], [880.0, 0.14]],
	"storm_hit": [[220.0, 0.18], [165.0, 0.26]],
	"shelter": [[440.0, 0.08], [330.0, 0.14]],
	"level_won": [[523.25, 0.12], [659.25, 0.12], [783.99, 0.22]],
	"lost": [[392.0, 0.18], [329.63, 0.18], [261.63, 0.3]],
}

var muted := false

var _player: AudioStreamPlayer
var _streams := {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	for key in SOUNDS:
		_streams[key] = _make_stream(SOUNDS[key])


func play(sound: String) -> void:
	if muted or _player == null or not _streams.has(sound):
		return
	_player.stream = _streams[sound]
	_player.play()


func set_muted(value: bool) -> void:
	muted = value
	if muted and _player != null:
		_player.stop()


func _make_stream(notes: Array) -> AudioStreamWAV:
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
