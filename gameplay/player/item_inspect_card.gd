class_name ItemInspectCard
extends PanelContainer

## Cartão de inspeção de item na mão (#88, inspirado no HeldInfo do How to Fish com identidade ScanDig).
## Usa WornPanel do tema do ScanDig e mostra nome, categoria, descrição, valor/estado e controlos.

var header_label: Label = null
var title_label: Label = null
var subtitle_label: Label = null
var description_label: Label = null
var stats_label: Label = null
var controls_title_label: Label = null
var controls_label: Label = null


func _init() -> void:
	name = "InspectCard"
	theme = preload("res://ui/theme/scandig_theme.tres")
	theme_type_variation = &"WornPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(350, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -378.0
	offset_right = -24.0
	offset_top = -170.0
	offset_bottom = 170.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	header_label = Label.new()
	header_label.name = "HeaderLabel"
	header_label.text = "🔍 FICHA DE CAMPO — SCANDIG"
	header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_label.add_theme_font_size_override("font_size", 15)
	header_label.add_theme_color_override("font_color", UiPalette.WOOD)
	box.add_child(header_label)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.theme_type_variation = &"TitleLabel"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", UiPalette.INK)
	box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label.add_theme_font_size_override("font_size", 15)
	subtitle_label.add_theme_color_override("font_color", UiPalette.WOOD)
	box.add_child(subtitle_label)

	var sep1: HSeparator = HSeparator.new()
	sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sep1)

	description_label = Label.new()
	description_label.name = "DescriptionLabel"
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(310, 0)
	description_label.add_theme_font_size_override("font_size", 15)
	description_label.add_theme_color_override("font_color", UiPalette.INK)
	box.add_child(description_label)

	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.custom_minimum_size = Vector2(310, 0)
	stats_label.add_theme_font_size_override("font_size", 15)
	stats_label.add_theme_color_override("font_color", UiPalette.GREEN_BOTTLE)
	box.add_child(stats_label)

	var sep2: HSeparator = HSeparator.new()
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sep2)

	controls_title_label = Label.new()
	controls_title_label.name = "ControlsTitleLabel"
	controls_title_label.text = "Controlos:"
	controls_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_title_label.add_theme_font_size_override("font_size", 15)
	controls_title_label.add_theme_color_override("font_color", UiPalette.WOOD)
	box.add_child(controls_title_label)

	controls_label = Label.new()
	controls_label.name = "ControlsLabel"
	controls_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.custom_minimum_size = Vector2(310, 0)
	controls_label.add_theme_font_size_override("font_size", 15)
	controls_label.add_theme_color_override("font_color", UiPalette.INK)
	box.add_child(controls_label)


func set_card_content(
	p_title: String,
	p_subtitle: String,
	p_description: String,
	p_stats: String,
	p_controls: PackedStringArray,
	p_stats_color: Color = UiPalette.GREEN_BOTTLE
) -> void:
	if title_label != null:
		title_label.text = p_title
	if subtitle_label != null:
		subtitle_label.text = p_subtitle
		subtitle_label.visible = not p_subtitle.is_empty()
	if description_label != null:
		description_label.text = p_description
	if stats_label != null:
		stats_label.text = p_stats
		stats_label.visible = not p_stats.is_empty()
		stats_label.add_theme_color_override("font_color", p_stats_color)
	if controls_label != null:
		controls_label.text = "\n".join(p_controls)


func get_full_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for lbl: Label in [header_label, title_label, subtitle_label, description_label, stats_label, controls_title_label, controls_label]:
		if lbl != null and not lbl.text.is_empty():
			parts.append(lbl.text)
	return "\n".join(parts)
