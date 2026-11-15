extends RefCounted
## Which real-life fact to show in play. The facts themselves are the Science
## page's rows in game_text.gd; this file only chooses among them.
##
## A fact is usable in play only if a human has checked it ("verified": true)
## and it has a short `note`. Everything else stays on the Science page.

const GameText = preload("res://game_text.gd")


## The fact row with this id, or {}.
static func row(id: String) -> Dictionary:
	for fact in GameText.TEXT["science"]["rows"]:
		if str(fact.get("id", "")) == id:
			return fact
	return {}


static func usable(id: String) -> bool:
	var fact := row(id)
	return not fact.is_empty() and bool(fact.get("verified", false)) and str(fact.get("note", "")) != ""


## The one-sentence note of a fact ("" if it may not be shown in play).
static func note(id: String) -> String:
	return str(row(id)["note"]) if usable(id) else ""


## The fact to tell after a turn. `events` lists what just happened, the most
## important first (the names are the keys of science.in_play.events). Returns
## the first usable fact not yet in `seen`, or "": each fact is told once.
static func pick(events: Array, seen: Dictionary) -> String:
	var lists: Dictionary = GameText.TEXT["science"]["in_play"]["events"]
	for event in events:
		for id in lists.get(str(event), []):
			if usable(str(id)) and not seen.has(str(id)):
				return str(id)
	return ""


## The fact for a building's card, or "".
static func for_building(key: String) -> String:
	var lists: Dictionary = GameText.TEXT["science"]["in_play"]["buildings"]
	for id in lists.get(key, []):
		if usable(str(id)):
			return str(id)
	return ""
