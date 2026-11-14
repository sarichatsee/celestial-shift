extends Node
## "The Sun right now": the last 30 days of big flares and particle storms from
## NASA DONKI, for the title screen. It never blocks the game and never fails:
## after 4 seconds without an answer it reports the saved numbers instead, and
## says so. Saved data is never labelled as live.
##
## Emits `loaded(info)` once, with:
##   {"mode": "live", "checked_at": "14:05", ...}      fetched just now
##   {"mode": "saved", "saved_on": "2026-11-14", ...}  the saved fallback
##   {"mode": "none"}                                   no answer and nothing saved
## plus "big_flares", "latest" ({full_class, date} or null), "particle_storms"
## and "busy" ("quiet", "busy" or "very_busy").

signal loaded(info: Dictionary)

# DONKI moved here on 2026-09-30. No API key; it allows requests from any web page.
const DONKI_URL := "https://ccmc.gsfc.nasa.gov/DONKI/WS/get/%s?startDate=%s&endDate=%s"
const TIMEOUT_SECONDS := 4.0
const WINDOW_DAYS := 30
const BUSY_FROM := 3  # [TUNE] big flares in 30 days: quiet 0-2, busy 3-9,
const VERY_BUSY_FROM := 10  # [TUNE] very busy 10 or more

var _snapshot: Variant = null
var _answers := {}  # "FLR" / "SEP" -> Array of records
var _finished := false


## `snapshot` is the saved "live_snapshot" from storms_data.gd, or null.
func start(snapshot: Variant) -> void:
	_snapshot = snapshot
	_answers = {}
	_finished = false
	var now := int(Time.get_unix_time_from_system())
	var end_date := Time.get_date_string_from_unix_time(now)
	var start_date := Time.get_date_string_from_unix_time(now - WINDOW_DAYS * 86400)
	for kind in ["FLR", "SEP"]:
		var request := HTTPRequest.new()
		request.timeout = TIMEOUT_SECONDS
		add_child(request)
		request.request_completed.connect(_on_request_completed.bind(kind, request))
		if request.request(DONKI_URL % [kind, start_date, end_date]) != OK:
			_finish_saved()
			return


static func busy_level(big_flares: int) -> String:
	if big_flares >= VERY_BUSY_FROM:
		return "very_busy"
	if big_flares >= BUSY_FROM:
		return "busy"
	return "quiet"


func _on_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, kind: String,
	request: HTTPRequest
) -> void:
	request.queue_free()
	if _finished:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_finish_saved()
		return
	var text := body.get_string_from_utf8().strip_edges()
	var records: Array = []
	if text != "":  # DONKI sends an empty body when there is nothing in the range
		var parsed: Variant = JSON.parse_string(text)
		if not parsed is Array:
			_finish_saved()
			return
		records = parsed
	_answers[kind] = records
	if _answers.has("FLR") and _answers.has("SEP"):
		_finish_live()


func _finish_live() -> void:
	var seen := {}
	var big: Array = []
	for flare in _answers["FLR"]:
		if not flare is Dictionary:
			continue
		var full_class := str(flare.get("classType", "")).to_upper()
		var peak := str(flare.get("peakTime", ""))
		var id := str(flare.get("flrID", peak))
		if peak == "" or seen.has(id) or not (full_class.begins_with("M") or full_class.begins_with("X")):
			continue
		seen[id] = true
		big.append({"full_class": full_class, "peak": peak})
	var latest: Variant = null
	for flare in big:
		if latest == null or str(flare["peak"]) > str(latest["peak"]):
			latest = flare
	var storms := {}
	for sep in _answers["SEP"]:
		if sep is Dictionary:
			storms[str(sep.get("sepID", storms.size()))] = true
	var info := {
		"mode": "live",
		"checked_at": Time.get_time_string_from_system(true).substr(0, 5),
		"big_flares": big.size(),
		"latest": null,
		"particle_storms": storms.size(),
		"busy": busy_level(big.size()),
	}
	if latest != null:
		info["latest"] = {"full_class": str(latest["full_class"]), "date": str(latest["peak"]).substr(0, 10)}
	_finished = true
	loaded.emit(info)


func _finish_saved() -> void:
	if _finished:
		return
	_finished = true
	if not _snapshot is Dictionary:
		loaded.emit({"mode": "none"})
		return
	var snapshot: Dictionary = _snapshot
	loaded.emit({
		"mode": "saved",
		"saved_on": str(snapshot.get("saved_on", "")),
		"big_flares": int(snapshot.get("big_flares", 0)),
		"latest": snapshot.get("latest"),
		"particle_storms": int(snapshot.get("particle_storms", 0)),
		"busy": busy_level(int(snapshot.get("big_flares", 0))),
	})
