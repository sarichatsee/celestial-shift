extends Control
## A small bar chart for the debrief: one column per turn, with a number above
## and the turn below. Used for the battery and for the radiation measured at the Moon.
##
## Each column is a Dictionary:
##   {"turn": 3, "height": 0.4, "text": "13.2", "night": false, "storm": false, "unplayed": false, "mark": ""}
## `height` is 0..1. `unplayed` draws an empty dashed slot instead of a bar.

const Kit = preload("res://ui_kit.gd")

const FONT_SIZE := 14
const TOP_ROOM := 24.0  # for the number above each bar
const BOTTOM_ROOM := 42.0  # for the turn number and the mark

var columns: Array = []
var day_color: Color = Kit.C_SUN
var night_color: Color = Kit.C_NIGHT
var storm_color: Color = Kit.C_DANGER


func _init() -> void:
	custom_minimum_size = Vector2(0, 190)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func set_columns(new_columns: Array) -> void:
	columns = new_columns
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Kit.C_WELL)
	if columns.is_empty():
		return
	var font := get_theme_default_font()
	var gap := 4.0
	var column_width: float = (size.x - gap * float(columns.size() + 1)) / float(columns.size())
	var bottom: float = size.y - BOTTOM_ROOM
	var room: float = bottom - TOP_ROOM
	for i in columns.size():
		var column: Dictionary = columns[i]
		var x: float = gap + float(i) * (column_width + gap)
		var night := bool(column.get("night", false))
		var storm := bool(column.get("storm", false))
		if night:
			draw_rect(Rect2(x, 2.0, column_width, size.y - 4.0), Color(0.56, 0.49, 1.0, 0.14))
		var bar_x: float = x + column_width * 0.15
		var bar_width: float = column_width * 0.7
		if bool(column.get("unplayed", false)):
			draw_rect(Rect2(bar_x, bottom - 18.0, bar_width, 18.0), Kit.C_LINE, false, 1.0)
		else:
			var height: float = maxf(3.0, room * clampf(float(column.get("height", 0.0)), 0.0, 1.0))
			var color := night_color if night else day_color
			if storm:
				color = storm_color
			draw_rect(Rect2(bar_x, bottom - height, bar_width, height), color)
			if storm:  # an outline as well as a colour, so it does not rely on colour alone
				draw_rect(Rect2(bar_x, bottom - height, bar_width, height), Color.WHITE, false, 2.0)
			draw_string(font, Vector2(x, 17.0), str(column.get("text", "")), HORIZONTAL_ALIGNMENT_CENTER,
				column_width, FONT_SIZE, Kit.C_TEXT)
		draw_string(font, Vector2(x, bottom + 17.0), str(column.get("turn", "")), HORIZONTAL_ALIGNMENT_CENTER,
			column_width, FONT_SIZE, Kit.C_MUTED)
		var mark := str(column.get("mark", ""))
		if mark != "":
			draw_string(font, Vector2(x, bottom + 34.0), mark, HORIZONTAL_ALIGNMENT_CENTER, column_width,
				FONT_SIZE - 2, storm_color)
