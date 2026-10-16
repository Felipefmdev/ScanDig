class_name BossHud
extends CanvasLayer

## Barra de vida de chefe (nome + barra) criada em código, igual em todos os peers (#40/#41:
## Polvo, Corvo-Rei, Espantalho). O Caranguejo-Rei e a Toupeira usam a versão da cena.

var bar: ProgressBar = null


static func create(title: String, max_value: float, fill_color: Color) -> BossHud:
	var hud: BossHud = BossHud.new()
	hud.name = "BossHud"
	hud.layer = 2
	hud.visible = false
	var panel: VBoxContainer = VBoxContainer.new()
	panel.theme = preload("res://ui/theme/scandig_theme.tres")
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-260.0, 70.0)
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	var name_label: Label = Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override(&"font_color", UiPalette.GOLD)
	name_label.add_theme_color_override(&"font_outline_color", UiPalette.INK)
	name_label.add_theme_constant_override(&"outline_size", 6)
	name_label.add_theme_font_size_override(&"font_size", 22)
	panel.add_child(name_label)
	hud.bar = ProgressBar.new()
	hud.bar.theme_type_variation = &"BossBar"
	hud.bar.custom_minimum_size = Vector2(0.0, 18.0)
	hud.bar.show_percentage = false
	hud.bar.max_value = max_value
	hud.bar.value = max_value
	hud.bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hud.bar)
	return hud


func set_health(value: float) -> void:
	if bar != null:
		bar.value = value
