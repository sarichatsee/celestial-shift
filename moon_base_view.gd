extends Control
## The view of the Moon base: the first room, and the picture behind the title,
## level intro and debrief screens. It is drawn in code, so it needs no image
## file, and it shows the game state rather than decorating it:
##
##   sky             Sun by day; stars and a dark surface at night
##   solar panels    bright by day, dark at night
##   battery bank    fills and drains with the Battery meter
##   science lab     windows glow when science has power
##   main base       window is green when life support is on, amber when it is
##                   under the need, red when Air is low; the crew stand inside
##   roof shield     0 to 3 layers of Moon dirt, plus the part-built next layer
##   shelter         lights up, with the crew inside, when they shelter
##   greenhouse      lit when on, plants taller with more Food (from Level 2)
##   water tank      level, and the recycler light (from Level 2)
##   Sun and mast    a flare on the Sun and an amber beacon during a storm alert
##
## It only ever receives what the player can already see. It never learns
## whether a storm followed a flare.
##
## Everything is laid out on a 1280 x 720 canvas and scaled to fit.

const Kit = preload("res://ui_kit.gd")

const W := 1280.0
const H := 720.0
const HORIZON := 352.0
const GROUND := 428.0  # the line the buildings stand on
const INK := Color(0.05, 0.06, 0.09, 1.0)
const SUN_AT := Vector2(1140.0, 295.0)
const EARTH_AT := Vector2(462.0, 292.0)
const DOME_X := 700.0
const DOME_RX := 96.0
const DOME_RY := 90.0
const LAYER_GAP := 3.0
const LAYER_WIDTH := 11.0
const REGOLITH := Color(0.56, 0.5, 0.44, 1.0)

## What to draw. Every key is optional; see `_get` calls below for the defaults.
##   is_day (bool), battery (0..1), air (0..1), life_support_ok (bool),
##   science (bool), shield (int), shield_max (int), shield_part (0..1),
##   sheltering (bool), greenhouse ("" hidden, "off", "on"), food (0..1),
##   water (0..1, or -1 hidden), recycler_on (bool), alert ("" / "M" / "X"),
##   labels ({"solar": "...", ...}; a missing label is not drawn)
var view: Dictionary = {}

var _day := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_view(new_view: Dictionary) -> void:
	if new_view == view:
		return
	view = new_view.duplicate(true)
	queue_redraw()


func _draw() -> void:
	var fit: float = maxf(size.x / W, size.y / H)
	draw_set_transform((size - Vector2(W, H) * fit) / 2.0, 0.0, Vector2(fit, fit))
	_day = bool(view.get("is_day", true))
	var alert := str(view.get("alert", ""))

	_draw_sky(alert)
	_draw_ground()
	_draw_cable()
	_draw_solar_panels()
	_draw_battery(clampf(float(view.get("battery", 0.25)), 0.0, 1.0))
	_draw_tubes(str(view.get("greenhouse", "")) != "")
	_draw_science_lab(bool(view.get("science", false)))
	_draw_shield(int(view.get("shield", 0)), int(view.get("shield_max", 3)), float(view.get("shield_part", 0.0)))
	_draw_dome()
	_draw_shelter(bool(view.get("sheltering", false)))
	var greenhouse := str(view.get("greenhouse", ""))
	if greenhouse != "":
		_draw_greenhouse(greenhouse == "on", clampf(float(view.get("food", 0.5)), 0.0, 1.0))
	var water := float(view.get("water", -1.0))
	if water >= 0.0:
		_draw_water_tank(clampf(water, 0.0, 1.0), bool(view.get("recycler_on", true)))
	_draw_mast(alert != "")
	_draw_labels(greenhouse != "", water >= 0.0)


# ---------------------------------------------------------------- small helpers
## Building colours go dim and a little blue at night. Lights do not use this.
func _lit(color: Color) -> Color:
	if _day:
		return color
	return Color(color.r * 0.42, color.g * 0.47, color.b * 0.6, color.a)


## Points along part of an ellipse. Angles in radians; PI to TAU is the top half.
func _arc(center: Vector2, rx: float, ry: float, from: float = PI, to: float = TAU, steps: int = 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var angle: float = lerpf(from, to, float(i) / float(steps))
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_colored_polygon(_arc(center, rx, ry, 0.0, TAU, 28), color)


func _outline(points: PackedVector2Array, width: float = 2.5, color: Color = INK, closed: bool = true) -> void:
	var line := points.duplicate()
	if closed and line.size() > 2:
		line.append(line[0])
	draw_polyline(line, color, width, true)


func _box(rect: Rect2, color: Color, radius: int = 4, border: float = 2.5, border_color: Color = INK) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border_color
	style.set_border_width_all(int(round(border)))
	style.anti_aliasing = true
	draw_style_box(style, rect)


func _glow(center: Vector2, radius: float, color: Color) -> void:
	for step in 4:
		var part: float = float(4 - step) / 4.0
		draw_circle(center, radius * part, Color(color.r, color.g, color.b, color.a * 0.3))


func _ground_shadow(center_x: float, half_width: float) -> void:
	_ellipse(Vector2(center_x, GROUND + 2.0), half_width, 7.0, Color(0.0, 0.0, 0.0, 0.28))


## A crew member seen through a window: helmet, visor and shoulders.
func _crew(at: Vector2, helmet: float) -> void:
	_box(Rect2(at.x - helmet, at.y + helmet * 0.7, helmet * 2.0, helmet * 1.1), Color(0.95, 0.96, 0.98), 3, 1.5)
	draw_circle(at, helmet, Color(0.95, 0.96, 0.98))
	draw_arc(at, helmet, 0.0, TAU, 20, INK, 1.5, true)
	draw_circle(at + Vector2(0.0, 0.5), helmet * 0.58, Color(0.16, 0.24, 0.36))


# ---------------------------------------------------------------- sky and ground
func _draw_sky(alert: String) -> void:
	var top := Color(0.0, 0.0, 0.015)
	var low := Color(0.03, 0.04, 0.09) if _day else Color(0.015, 0.025, 0.075)
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, HORIZON + 20.0), Vector2(0, HORIZON + 20.0)]),
		PackedColorArray([top, top, low, low]))

	var random := RandomNumberGenerator.new()
	random.seed = 27  # the same stars every time
	for i in 110:
		var at := Vector2(random.randf_range(0.0, W), random.randf_range(78.0, HORIZON - 8.0))
		var star_size: float = random.randf_range(0.6, 1.7)
		var bright: float = random.randf_range(0.5, 1.0) * (0.3 if _day else 1.0)
		draw_circle(at, star_size, Color(0.92, 0.95, 1.0, bright))

	# Earth
	_glow(EARTH_AT, 40.0, Color(0.4, 0.65, 1.0, 0.35))
	draw_circle(EARTH_AT, 26.0, Color(0.2, 0.46, 0.85))
	_ellipse(EARTH_AT + Vector2(-8.0, -6.0), 9.0, 7.0, Color(0.3, 0.68, 0.42))
	_ellipse(EARTH_AT + Vector2(9.0, 8.0), 8.0, 5.0, Color(0.3, 0.68, 0.42))
	draw_arc(EARTH_AT + Vector2(2.0, -2.0), 17.0, PI * 0.9, PI * 1.6, 12, Color(1, 1, 1, 0.75), 3.0, true)
	draw_arc(EARTH_AT + Vector2(-3.0, 6.0), 15.0, PI * 0.1, PI * 0.6, 12, Color(1, 1, 1, 0.7), 3.0, true)
	draw_arc(EARTH_AT, 26.0, 0.0, TAU, 40, INK, 2.0, true)

	if not _day:
		if alert != "":
			# the Sun is below the horizon at night: only its storm glow shows
			_glow(Vector2(SUN_AT.x, HORIZON + 14.0), 150.0 if alert == "X" else 110.0, Color(1.0, 0.5, 0.12, 0.5))
		return

	# Sun, with a flare while an alert is up (bigger for an X flare)
	if alert != "":
		var reach: float = 50.0 if alert == "X" else 28.0
		_glow(SUN_AT, 70.0 + reach * 1.6, Color(1.0, 0.5, 0.12, 0.55))
		for ray in 14:
			var angle: float = TAU * float(ray) / 14.0 + 0.2
			var tip: float = 40.0 + reach * (1.0 if ray % 2 == 0 else 0.6)
			draw_colored_polygon(PackedVector2Array([
				SUN_AT + Vector2(cos(angle - 0.13), sin(angle - 0.13)) * 34.0,
				SUN_AT + Vector2(cos(angle), sin(angle)) * tip,
				SUN_AT + Vector2(cos(angle + 0.13), sin(angle + 0.13)) * 34.0,
			]), Color(1.0, 0.56, 0.14, 0.95))
	else:
		_glow(SUN_AT, 78.0, Color(1.0, 0.85, 0.45, 0.4))
	draw_circle(SUN_AT, 34.0, Color(1.0, 0.84, 0.36))
	draw_circle(SUN_AT, 26.0, Color(1.0, 0.93, 0.62))
	if alert != "":
		draw_circle(SUN_AT + Vector2(-12.0, 8.0), 9.0 if alert == "X" else 6.0, Color(1.0, 1.0, 0.95))
	draw_arc(SUN_AT, 34.0, 0.0, TAU, 40, Color(0.75, 0.42, 0.1), 2.0, true)


func _draw_ground() -> void:
	var far := Color(0.74, 0.75, 0.78) if _day else Color(0.2, 0.23, 0.31)
	var near := Color(0.5, 0.51, 0.55) if _day else Color(0.1, 0.12, 0.17)
	var hill := Color(0.62, 0.63, 0.67) if _day else Color(0.15, 0.17, 0.24)
	var rim := Color(0.0, 0.0, 0.0, 0.45)

	for shape in [
		[Vector2(-10, 362), Vector2(70, 334), Vector2(160, 326), Vector2(255, 340), Vector2(345, 356)],
		[Vector2(800, 356), Vector2(890, 334), Vector2(985, 328), Vector2(1075, 338), Vector2(1170, 356)],
		[Vector2(1120, 360), Vector2(1200, 340), Vector2(1290, 336), Vector2(1290, 362)],
	]:
		var points := PackedVector2Array(shape)
		draw_colored_polygon(points, hill)
		_outline(points, 2.0, rim, false)

	draw_polygon(
		PackedVector2Array([
			Vector2(0, 358), Vector2(320, 350), Vector2(640, 346), Vector2(960, 350), Vector2(W, 358),
			Vector2(W, H), Vector2(0, H),
		]),
		PackedColorArray([far, far, far, far, far, near, near]))
	draw_polyline(
		PackedVector2Array([Vector2(0, 358), Vector2(320, 350), Vector2(640, 346), Vector2(960, 350), Vector2(W, 358)]),
		rim, 2.0, true)

	# craters: a dark bowl with a bright lower lip
	var bowl := Color(0.0, 0.0, 0.0, 0.2)
	var lip := Color(1.0, 1.0, 1.0, 0.3 if _day else 0.1)
	for crater in [
		[210.0, 480.0, 70.0, 12.0], [585.0, 488.0, 80.0, 13.0], [930.0, 478.0, 58.0, 10.0], [1150.0, 492.0, 76.0, 13.0],
		[375.0, 374.0, 30.0, 5.0], [1010.0, 376.0, 36.0, 6.0], [600.0, 370.0, 22.0, 4.0],
	]:
		var center := Vector2(crater[0], crater[1])
		_ellipse(center, crater[2], crater[3], bowl)
		draw_polyline(_arc(center, crater[2], crater[3], 0.1, PI - 0.1, 16), lip, 2.0, true)
		draw_polyline(_arc(center, crater[2], crater[3], PI + 0.1, TAU - 0.1, 16), rim, 2.0, true)


# ---------------------------------------------------------------- the base, left to right
func _draw_cable() -> void:
	draw_polyline(PackedVector2Array([
		Vector2(86, GROUND - 2.0), Vector2(266, GROUND - 2.0), Vector2(352, GROUND - 6.0),
	]), Color(0.12, 0.13, 0.16), 3.0, true)


func _draw_solar_panels() -> void:
	var glass := Color(0.2, 0.46, 0.96) if _day else Color(0.07, 0.12, 0.26)
	var grid := Color(0.75, 0.88, 1.0, 0.8) if _day else Color(0.3, 0.4, 0.6, 0.6)
	for post_x in [86.0, 176.0, 266.0]:
		_ground_shadow(post_x, 30.0)
		draw_rect(Rect2(post_x - 3.0, GROUND - 36.0, 6.0, 36.0), _lit(Color(0.45, 0.47, 0.52)))
		var a := Vector2(post_x - 38.0, GROUND - 34.0)
		var b := Vector2(post_x + 28.0, GROUND - 64.0)
		var c := Vector2(post_x + 38.0, GROUND - 48.0)
		var d := Vector2(post_x - 28.0, GROUND - 18.0)
		var panel := PackedVector2Array([a, b, c, d])
		draw_colored_polygon(panel, glass)
		draw_line(a.lerp(d, 0.5), b.lerp(c, 0.5), grid, 1.5, true)
		for cut in [0.33, 0.66]:
			draw_line(a.lerp(b, cut), d.lerp(c, cut), grid, 1.5, true)
		_outline(panel)
		if _day:
			draw_line(a.lerp(b, 0.1) + Vector2(2, 4), a.lerp(b, 0.3) + Vector2(2, 4), Color(1, 1, 1, 0.9), 2.5, true)


func _draw_battery(level: float) -> void:
	_ground_shadow(384.0, 40.0)
	draw_rect(Rect2(374.0, GROUND - 58.0, 20.0, 8.0), _lit(Color(0.5, 0.52, 0.57)))
	_box(Rect2(352.0, GROUND - 52.0, 64.0, 52.0), _lit(Color(0.27, 0.3, 0.36)), 6)
	var well := Rect2(359.0, GROUND - 44.0, 50.0, 36.0)
	draw_rect(well, Color(0.03, 0.04, 0.06))
	var charge: Color = Kit.C_DANGER if level < 0.2 else Kit.C_SUN
	draw_rect(Rect2(well.position, Vector2(well.size.x * level, well.size.y)), charge)
	for cut in 3:
		var x: float = well.position.x + well.size.x * float(cut + 1) / 4.0
		draw_line(Vector2(x, well.position.y), Vector2(x, well.end.y), Color(0.03, 0.04, 0.06), 2.0)
	draw_rect(well, INK, false, 2.0)


func _draw_tubes(to_greenhouse: bool) -> void:
	var tube := _lit(Color(0.7, 0.74, 0.8))
	var spans := [[545.0, 610.0], [790.0, 860.0]]
	if to_greenhouse:
		spans.append([936.0, 968.0])
	for span in spans:
		var rect := Rect2(span[0], GROUND - 26.0, span[1] - span[0], 12.0)
		draw_rect(rect, tube)
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), INK, 2.0)
		draw_line(Vector2(rect.position.x, rect.end.y), rect.end, INK, 2.0)


func _draw_science_lab(powered: bool) -> void:
	var middle := Vector2(492.0, GROUND - 25.0)
	_ground_shadow(middle.x, 58.0)
	# telescope dish on the roof
	draw_line(Vector2(506.0, GROUND - 50.0), Vector2(506.0, GROUND - 68.0), INK, 3.0)
	var dish := _arc(Vector2(506.0, GROUND - 76.0), 20.0, 13.0, 0.25, PI + 0.25, 14)
	draw_colored_polygon(dish, _lit(Color(0.88, 0.9, 0.94)))
	_outline(dish, 2.0)
	draw_line(Vector2(506.0, GROUND - 76.0), Vector2(497.0, GROUND - 92.0), INK, 2.0, true)
	# the lab: a capsule on its side
	var shell := _arc(middle + Vector2(30.0, 0.0), 25.0, 25.0, -PI / 2.0, PI / 2.0, 14)
	shell.append_array(_arc(middle - Vector2(30.0, 0.0), 25.0, 25.0, PI / 2.0, PI * 1.5, 14))
	draw_colored_polygon(shell, _lit(Color(0.84, 0.87, 0.92)))
	_outline(shell)
	for window_x in [466.0, 492.0, 518.0]:
		var at := Vector2(window_x, GROUND - 28.0)
		if powered:
			_glow(at, 15.0, Color(0.45, 0.9, 1.0, 0.7))
		draw_circle(at, 7.5, Color(0.5, 0.93, 1.0) if powered else Color(0.07, 0.09, 0.13))
		draw_arc(at, 7.5, 0.0, TAU, 18, INK, 2.0, true)


func _layer_radius(layer: int, outer: bool) -> Vector2:
	var grow: float = LAYER_GAP + float(layer) * (LAYER_GAP + LAYER_WIDTH) + (LAYER_WIDTH if outer else 0.0)
	return Vector2(DOME_RX + grow, DOME_RY + grow)


## The roof shield: finished layers of Moon dirt, the part-built next layer, and
## a dashed outline of the layers still to come.
func _draw_shield(layers: int, most: int, part: float) -> void:
	var foot := Vector2(DOME_X, GROUND)
	var random := RandomNumberGenerator.new()
	random.seed = 9
	for layer in most:
		var inner := _layer_radius(layer, false)
		var outer := _layer_radius(layer, true)
		var share: float = 1.0 if layer < layers else (clampf(part, 0.0, 1.0) if layer == layers else 0.0)
		if share < 1.0:
			var ghost := _arc(foot, outer.x, outer.y, PI, TAU, 36)
			for dash in range(0, ghost.size() - 1, 2):
				draw_line(ghost[dash], ghost[dash + 1], Color(1.0, 1.0, 1.0, 0.3), 1.5, true)
		if share < 0.06:
			continue
		var to: float = PI + PI * share
		var steps: int = maxi(4, int(36.0 * share))
		var band := _arc(foot, outer.x, outer.y, PI, to, steps)
		var back := _arc(foot, inner.x, inner.y, PI, to, steps)
		back.reverse()
		band.append_array(back)
		draw_colored_polygon(band, _lit(REGOLITH))
		_outline(band, 2.0)
		for speck in int(26.0 * share):
			var angle: float = random.randf_range(PI + 0.05, to - 0.03)
			var depth: float = random.randf_range(0.25, 0.75)
			var at := foot + Vector2(cos(angle) * lerpf(inner.x, outer.x, depth), sin(angle) * lerpf(inner.y, outer.y, depth))
			draw_circle(at, 1.6, Color(0.0, 0.0, 0.0, 0.35))


func _draw_dome() -> void:
	var foot := Vector2(DOME_X, GROUND)
	_ground_shadow(DOME_X, DOME_RX + 12.0)
	var shell := _arc(foot, DOME_RX, DOME_RY)
	draw_colored_polygon(shell, _lit(Color(0.87, 0.9, 0.95)))
	for rib in [0.68, 0.34]:
		draw_polyline(_arc(foot, DOME_RX * rib, DOME_RY, PI, TAU, 24), Color(0.0, 0.0, 0.0, 0.16), 1.5, true)
	_outline(shell, 3.0)

	# the window shows how life support is doing
	var air := float(view.get("air", 1.0))
	var light := Color(0.72, 1.0, 0.8)
	if air < 0.3:
		light = Color(1.0, 0.45, 0.4)
	elif not bool(view.get("life_support_ok", true)):
		light = Color(1.0, 0.74, 0.34)
	var window := Rect2(DOME_X - 56.0, GROUND - 70.0, 112.0, 36.0)
	_glow(window.get_center(), 60.0, Color(light.r, light.g, light.b, 0.35))
	_box(window, light, 10)
	if not bool(view.get("sheltering", false)):
		for crew_x in [-30.0, 0.0, 30.0]:
			_crew(Vector2(DOME_X + crew_x, GROUND - 56.0), 8.5)
		_box(window, Color(0, 0, 0, 0), 10)  # the frame, over the crew's shoulders
	_box(Rect2(DOME_X - 13.0, GROUND - 24.0, 26.0, 24.0), _lit(Color(0.36, 0.4, 0.48)), 4)


func _draw_shelter(sheltering: bool) -> void:
	_ground_shadow(898.0, 50.0)
	var walls := PackedVector2Array([
		Vector2(856, GROUND), Vector2(868, GROUND - 38.0), Vector2(928, GROUND - 38.0), Vector2(940, GROUND),
	])
	var mound := _arc(Vector2(898.0, GROUND - 36.0), 42.0, 18.0)
	draw_colored_polygon(mound, _lit(REGOLITH))
	_outline(mound, 2.0)
	draw_colored_polygon(walls, _lit(Color(0.42, 0.46, 0.55)))
	_outline(walls, 3.5 if sheltering else 2.5, Kit.C_GOOD if sheltering else INK)
	var window := Rect2(874.0, GROUND - 30.0, 48.0, 24.0)
	if sheltering:
		_glow(window.get_center(), 46.0, Color(1.0, 0.9, 0.55, 0.6))
		_box(window, Color(1.0, 0.92, 0.62), 6)
		for crew_x in [-14.0, 0.0, 14.0]:
			_crew(Vector2(898.0 + crew_x, GROUND - 21.0), 5.5)
		_box(window, Color(0, 0, 0, 0), 6)
	else:
		_box(window, Color(0.06, 0.08, 0.11), 6)


func _draw_greenhouse(on: bool, food: float) -> void:
	var foot := Vector2(1047.0, GROUND)
	_ground_shadow(foot.x, 90.0)
	var glass := _arc(foot, 81.0, 46.0)
	if on:
		_glow(foot + Vector2(0.0, -20.0), 100.0, Color(0.6, 1.0, 0.6, 0.35))
	draw_colored_polygon(glass, Color(0.74, 0.98, 0.72) if on else Color(0.13, 0.2, 0.19))
	# plants: taller with more Food
	var leaf := Color(0.16, 0.6, 0.26) if on else Color(0.1, 0.3, 0.17)
	for plant in 6:
		var x: float = foot.x - 60.0 + float(plant) * 24.0
		var tall: float = 8.0 + 20.0 * food
		draw_line(Vector2(x, GROUND - 3.0), Vector2(x, GROUND - 3.0 - tall), leaf, 2.5, true)
		_ellipse(Vector2(x - 5.0, GROUND - 3.0 - tall), 6.0, 3.5, leaf)
		_ellipse(Vector2(x + 5.0, GROUND - 5.0 - tall), 6.0, 3.5, leaf)
		if food > 0.5:
			_ellipse(Vector2(x - 4.0, GROUND - 3.0 - tall * 0.5), 5.0, 3.0, leaf)
	for rib in [0.62, 0.22]:
		draw_polyline(_arc(foot, 81.0 * rib, 46.0, PI, TAU, 20), Color(0.0, 0.0, 0.0, 0.3), 1.5, true)
	_outline(glass, 3.0)


func _draw_water_tank(level: float, recycler_on: bool) -> void:
	_ground_shadow(1166.0, 28.0)
	_box(Rect2(1146.0, GROUND - 60.0, 40.0, 60.0), _lit(Color(0.7, 0.74, 0.8)), 8)
	var well := Rect2(1153.0, GROUND - 52.0, 26.0, 44.0)
	draw_rect(well, Color(0.03, 0.04, 0.06))
	draw_rect(Rect2(well.position.x, well.end.y - well.size.y * level, well.size.x, well.size.y * level), Kit.C_WATER)
	draw_rect(well, INK, false, 2.0)
	# the recycler light: green when on, orange when off
	var lamp := Vector2(1166.0, GROUND - 70.0)
	draw_line(lamp, Vector2(1166.0, GROUND - 60.0), INK, 3.0)
	var lamp_color: Color = Kit.C_GOOD if recycler_on else Kit.C_WARN
	_glow(lamp, 13.0, Color(lamp_color.r, lamp_color.g, lamp_color.b, 0.6))
	draw_circle(lamp, 5.5, lamp_color)
	draw_arc(lamp, 5.5, 0.0, TAU, 16, INK, 1.5, true)


func _draw_mast(alert: bool) -> void:
	var top := Vector2(1228.0, GROUND - 108.0)
	draw_line(Vector2(1228.0, GROUND), top, _lit(Color(0.6, 0.63, 0.7)), 4.0)
	draw_line(Vector2(1214.0, GROUND), Vector2(1228.0, GROUND - 40.0), _lit(Color(0.6, 0.63, 0.7)), 2.0, true)
	draw_line(Vector2(1242.0, GROUND), Vector2(1228.0, GROUND - 40.0), _lit(Color(0.6, 0.63, 0.7)), 2.0, true)
	draw_line(top + Vector2(-12.0, 20.0), top + Vector2(12.0, 20.0), _lit(Color(0.6, 0.63, 0.7)), 3.0)
	if alert:
		_glow(top, 34.0, Color(1.0, 0.7, 0.2, 0.9))
	draw_circle(top, 6.5, Kit.C_SUN if alert else Color(0.45, 0.14, 0.14))
	draw_arc(top, 6.5, 0.0, TAU, 16, INK, 1.5, true)


func _draw_labels(with_greenhouse: bool, with_water: bool) -> void:
	var labels: Dictionary = view.get("labels", {})
	if labels.is_empty():
		return
	var places := {"solar": 176.0, "battery": 384.0, "science": 492.0, "base": DOME_X, "shelter": 898.0}
	if with_greenhouse:
		places["greenhouse"] = 1047.0
	if with_water:
		places["water"] = 1166.0
	var font := get_theme_default_font()
	var font_size := 13
	for key in places:
		var words := str(labels.get(key, ""))
		if words == "":
			continue
		var wide: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var left: float = float(places[key]) - wide / 2.0
		_box(Rect2(left - 6.0, GROUND + 8.0, wide + 12.0, 20.0), Color(0.02, 0.04, 0.05, 0.72), 6, 0.0)
		draw_string(font, Vector2(left, GROUND + 23.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.93, 0.96, 0.93))
