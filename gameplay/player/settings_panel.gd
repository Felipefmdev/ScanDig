extends PanelContainer

## Painel de opções do jogador ([Esc]). O jogo não pausa (é coop); só solta o mouse.

signal settings_changed(values: Dictionary)
signal closed

const SETTINGS: Script = preload("res://gameplay/player/player_settings.gd")

var values: Dictionary = {}
var sensitivity_slider: HSlider = null
var fov_slider: HSlider = null
var bobbing_check: CheckBox = null
var _sens_label: Label = null
var _fov_label: Label = null


func _ready() -> void:
	theme = load("res://ui/theme/scandig_theme.tres") as Theme
	theme_type_variation = &"WornPanel"
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(380, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = "Opções"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_sens_label = Label.new()
	box.add_child(_sens_label)
	sensitivity_slider = _slider(SETTINGS.SENSITIVITY_RANGE, 0.0001)
	sensitivity_slider.value_changed.connect(func(v: float) -> void: _set_value("mouse_sensitivity", v))
	box.add_child(sensitivity_slider)

	_fov_label = Label.new()
	box.add_child(_fov_label)
	fov_slider = _slider(SETTINGS.FOV_RANGE, 1.0)
	fov_slider.value_changed.connect(func(v: float) -> void: _set_value("fov", v))
	box.add_child(fov_slider)

	bobbing_check = CheckBox.new()
	bobbing_check.text = "Balanço da câmera ao andar"
	bobbing_check.toggled.connect(func(on: bool) -> void: _set_value("view_bobbing", on))
	box.add_child(bobbing_check)

	var back: Button = Button.new()
	back.text = "Voltar ao jogo  [Esc]"
	back.pressed.connect(func() -> void: closed.emit())
	box.add_child(back)


func _slider(range_v: Vector2, step_v: float) -> HSlider:
	var s: HSlider = HSlider.new()
	s.min_value = range_v.x
	s.max_value = range_v.y
	s.step = step_v
	s.custom_minimum_size = Vector2(320, 20)
	return s


## Mostra os valores atuais sem disparar settings_changed.
func show_values(v: Dictionary) -> void:
	values = SETTINGS.sanitize(v)
	sensitivity_slider.set_value_no_signal(values["mouse_sensitivity"])
	fov_slider.set_value_no_signal(values["fov"])
	bobbing_check.set_pressed_no_signal(values["view_bobbing"])
	_refresh_labels()


func _set_value(key: String, v: Variant) -> void:
	values[key] = v
	values = SETTINGS.sanitize(values)
	_refresh_labels()
	settings_changed.emit(values)


func _refresh_labels() -> void:
	var sens: float = float(values.get("mouse_sensitivity", 0.0025))
	_sens_label.text = tr("Sensibilidade do mouse: %d%%") % int(round(sens / 0.0025 * 100.0))
	_fov_label.text = tr("Campo de visão: %d°") % int(values.get("fov", 75.0))
