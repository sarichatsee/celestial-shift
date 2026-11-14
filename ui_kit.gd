extends RefCounted
## Colours and small builders for the console-style screen, so the look lives in
## one place. The bar colours are the ones the Orbit 27 prototype uses in main.tscn.

const C_BAR := Color(0.035, 0.055, 0.06, 0.96)
const C_PANEL := Color(0.035, 0.055, 0.06, 0.9)
const C_CARD := Color(0.09, 0.14, 0.16, 0.96)
const C_WELL := Color(0.02, 0.03, 0.04, 0.9)
const C_LINE := Color(0.25, 0.36, 0.36, 1.0)
const C_TEXT := Color(0.93, 0.96, 0.93, 1.0)
const C_HUD := Color(0.83, 0.91, 0.83, 1.0)
const C_STATUS := Color(0.68, 0.89, 0.79, 1.0)
const C_MUTED := Color(0.62, 0.72, 0.69, 1.0)
const C_SUN := Color(1.0, 0.82, 0.29, 1.0)
const C_GOOD := Color(0.39, 0.89, 0.59, 1.0)
const C_WARN := Color(1.0, 0.7, 0.28, 1.0)
const C_DANGER := Color(1.0, 0.49, 0.56, 1.0)
const C_WATER := Color(0.43, 0.78, 1.0, 1.0)
const C_FOOD := Color(0.71, 0.89, 0.42, 1.0)
const C_NIGHT := Color(0.7, 0.65, 1.0, 1.0)
const C_INK := Color(0.04, 0.06, 0.08, 1.0)

const TAP := 44  # the smallest button side, in canvas pixels


static func flat(color: Color, radius: int = 6, border: Color = Color(0, 0, 0, 0), border_width: int = 0, margin: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
	if margin > 0:
		box.set_content_margin_all(float(margin))
	return box


static func label(words: String, font_size: int = 0, color: Color = C_TEXT, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = words
	if font_size > 0:
		node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.custom_minimum_size = Vector2(200, 0)
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func button(words: String, min_width: int = 0, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = words
	node.custom_minimum_size = Vector2(min_width, TAP)
	if primary:
		make_primary(node)
	return node


## The one bright button on a screen (End turn, Start, Next level).
static func make_primary(node: Button) -> void:
	node.add_theme_stylebox_override("normal", flat(C_SUN, 6, C_SUN, 2, 10))
	node.add_theme_stylebox_override("hover", flat(C_SUN.lightened(0.25), 6, Color.WHITE, 2, 10))
	node.add_theme_stylebox_override("pressed", flat(C_SUN.darkened(0.15), 6, Color.WHITE, 2, 10))
	node.add_theme_stylebox_override("disabled", flat(Color(0.35, 0.33, 0.24, 1.0), 6, Color(0.35, 0.33, 0.24, 1.0), 2, 10))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		node.add_theme_color_override(color_name, C_INK)
	node.add_theme_color_override("font_disabled_color", Color(0.1, 0.1, 0.1, 0.8))


static func panel(color: Color = C_PANEL, margin: int = 12, radius: int = 8) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", flat(color, radius, C_LINE, 1, margin))
	return node


## A card with a coloured stripe down its left side (storm cards, tips).
static func striped_card(stripe: Color) -> PanelContainer:
	var box := flat(C_CARD, 8, stripe, 0, 12)
	box.border_color = stripe
	box.border_width_left = 8
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box)
	return node


static func meter(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(110, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", flat(C_WELL, 8, C_LINE, 1))
	bar.add_theme_stylebox_override("fill", flat(color, 8))
	return bar


static func vbox(separation: int = 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func hbox(separation: int = 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func link(words: String, url: String) -> LinkButton:
	var node := LinkButton.new()
	node.text = words
	node.uri = url  # opens in the system browser (a new tab in the web build)
	node.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	node.add_theme_color_override("font_color", C_WATER)
	node.custom_minimum_size = Vector2(0, 32)
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return node
