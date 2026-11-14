extends RefCounted

enum CropStage { EMPTY, GROWING, READY }
enum ReportStatus { UNSCANNED, READY, SENT }

const DAYS_PER_ACTION := 9
const DAYS_PER_CYCLE := 27
const MAX_JOB_STANDING := 3
const FOOD_PER_DELIVERY := 3
const CROPS := [
	{"name": "Radish", "grow_days": 18, "yield": 2},
	{"name": "Potato", "grow_days": 27, "yield": 4},
]

var cycle := 1
var day := 0
var food := 0
var shielded := false
var storm_resolved := false
var job_standing := MAX_JOB_STANDING
var report_status := ReportStatus.UNSCANNED
var supplies_pending := false

var crop_index := -1
var crop_age := 0
var notice := "Scan the Sun for a reading before requesting supplies from Earth."


func can_act() -> bool:
	return not storm_resolved and job_standing > 0


func flare_is_strong() -> bool:
	# Fixed sequence for the demo. The first storm is strong.
	return cycle % 2 == 1


func flare_strength() -> String:
	return "Strong" if flare_is_strong() else "Mild"


@warning_ignore("integer_division")
func actions_left() -> int:
	if not can_act():
		return 0
	return (DAYS_PER_CYCLE - day) / DAYS_PER_ACTION


func crop_stage() -> CropStage:
	if crop_index == -1:
		return CropStage.EMPTY
	if crop_age >= int(CROPS[crop_index]["grow_days"]):
		return CropStage.READY
	return CropStage.GROWING


func plant(index: int) -> void:
	if not can_act() or crop_stage() != CropStage.EMPTY:
		return
	if index < 0 or index >= CROPS.size():
		return
	crop_index = index
	crop_age = 0
	_spend_action("Planted %s." % CROPS[index]["name"])


func harvest() -> void:
	if not can_act() or crop_stage() != CropStage.READY:
		return
	var amount := int(CROPS[crop_index]["yield"])
	food += amount
	_clear_crop()
	_spend_action("Harvested %d food." % amount)


func raise_shields() -> void:
	if not can_act() or shielded:
		return
	shielded = true
	_spend_action("Greenhouse shields raised for this cycle.")


func scan_sun() -> void:
	if not can_act() or report_status != ReportStatus.UNSCANNED:
		return
	report_status = ReportStatus.READY
	_spend_action("Solar reading recorded. Forecast: %s." % flare_strength())


func request_supplies() -> void:
	if not can_act():
		return
	if report_status == ReportStatus.READY:
		report_status = ReportStatus.SENT
		supplies_pending = true
		job_standing = mini(job_standing + 1, MAX_JOB_STANDING)
		_spend_action("Earth accepted the report. %d food arrives next cycle." % FOOD_PER_DELIVERY)
		return

	job_standing -= 1
	var message := "Request denied. Earth needs a fresh report. Job standing -1."
	if job_standing == 0:
		message += " Earth has terminated your contract."
	_spend_action(message)


func wait_one_turn() -> void:
	if can_act():
		_spend_action("Advanced time by %d days." % DAYS_PER_ACTION)


func start_next_cycle() -> void:
	if not storm_resolved or job_standing == 0:
		return
	cycle += 1
	day = 0
	shielded = false
	storm_resolved = false
	report_status = ReportStatus.UNSCANNED
	notice = "Cycle %02d has begun." % cycle
	if supplies_pending:
		food += FOOD_PER_DELIVERY
		supplies_pending = false
		notice += " Earth delivered %d food." % FOOD_PER_DELIVERY


func _spend_action(message: String) -> void:
	var previous_stage := crop_stage()
	day += DAYS_PER_ACTION
	notice = message
	if previous_stage == CropStage.GROWING:
		crop_age += DAYS_PER_ACTION
		if crop_stage() == CropStage.READY:
			notice += " Your crop is ready to harvest."
	if day == DAYS_PER_CYCLE:
		_resolve_storm()


func _resolve_storm() -> void:
	storm_resolved = true
	if not flare_is_strong():
		notice += " A mild storm passed without damaging the greenhouse."
	elif crop_stage() == CropStage.EMPTY:
		notice += " A strong storm passed while the greenhouse was empty."
	elif shielded:
		notice += " The shields protected your crop through a strong storm."
	else:
		_clear_crop()
		notice += " A strong storm destroyed the unshielded crop."


func _clear_crop() -> void:
	crop_index = -1
	crop_age = 0
