extends Control
## A row of dots: filled ones and empty rings. Used for the storm chance
## ("3 of 10") and the shield layers. Filled against empty is a shape, not
## just a colour.

const Kit = preload("res://ui_kit.gd")

var total := 10
var filled := 0
var dot_size := 16.0
var on_color: Color = Kit.C_SUN
var off_color: Color = Kit.C_MUTED


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func set_dots(new_filled: int, new_total: int) -> void:
	filled = new_filled
	total = new_total
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(float(total) * (dot_size + 4.0), dot_size + 2.0)


func _draw() -> void:
	var radius: float = dot_size / 2.0
	for i in total:
		var center := Vector2(radius + 1.0 + float(i) * (dot_size + 4.0), size.y / 2.0)
		if i < filled:
			draw_circle(center, radius, on_color)
		else:
			draw_arc(center, radius - 1.0, 0.0, TAU, 24, off_color, 2.0)
