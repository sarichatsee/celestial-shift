extends Control
## A row of stars: filled ones and empty outlines. Drawn in code, because the
## default font has no star character. Filled against empty is a shape, not
## just a colour.

const Kit = preload("res://ui_kit.gd")

var filled: Array = [false, false, false]  # one true or false for each star
var star_size := 22.0
var on_color: Color = Kit.C_SUN
var off_color: Color = Kit.C_MUTED


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func set_stars(new_filled: Array) -> void:
	filled = new_filled.duplicate()
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(float(filled.size()) * (star_size + 6.0), star_size + 2.0)


func _draw() -> void:
	var outer: float = star_size / 2.0
	var inner: float = outer * 0.42
	for i in filled.size():
		var center := Vector2(outer + 1.0 + float(i) * (star_size + 6.0), size.y / 2.0 + 1.0)
		var points := PackedVector2Array()
		for corner in 10:
			var reach: float = outer if corner % 2 == 0 else inner
			var angle: float = -PI / 2.0 + float(corner) * PI / 5.0
			points.append(center + Vector2(cos(angle), sin(angle)) * reach)
		if bool(filled[i]):
			draw_colored_polygon(points, on_color)
		else:
			points.append(points[0])
			draw_polyline(points, off_color, 2.0, true)
