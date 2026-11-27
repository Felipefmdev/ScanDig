class_name WeatherHud
extends CanvasLayer

## Aviso do clima (#99), só na tela local: um pop-up no "warning" ("Chuva chegando…") e outro
## no fim ("O tempo abriu"), sem selo fixo durante o evento. Fica no canto superior direito,
## logo abaixo da barra de Ameaça do Subsolo (fora do HUD do jogador, da barra de expedição e
## do radar). Estilo do tema: ToastPanel / ToastLabel.
## O texto acompanha o tamanho do texto do HUD (grupo settings_hud_text).
## Autoload CoreWeatherUI; escuta CoreWeather.weather_changed.

const THEME: Theme = preload("res://ui/theme/scandig_theme.tres")
const WARNING_TEXTS: Dictionary = {
	WeatherManager.KIND_RAIN: "Chuva chegando…",
	WeatherManager.KIND_BLIZZARD: "Nevasca chegando…",
	WeatherManager.KIND_ASHSTORM: "Tempestade de cinzas chegando…",
}
const CLEAR_TEXT: String = "O tempo abriu"
const TOAST_SECONDS: float = 3.5
const TOAST_ENTER_DURATION: float = 0.16
const TOAST_EXIT_DURATION: float = 0.20
## Canto superior direito, abaixo da barra de Ameaça (em unidades da tela base).
const MARGIN_RIGHT: float = 24.0
const TOAST_TOP: float = 88.0
const STACK_GAP: float = 8.0

static var instance: WeatherHud = null

var root_control: Control = null
var stack: VBoxContainer = null
var toast_panel: PanelContainer = null
var toast_label: Label = null
var _toast_icon: TextureRect = null
## Aviso do atalho F3 (debug), criado só no primeiro uso, abaixo do aviso do clima.
var debug_panel: PanelContainer = null
var _toast_tween: Tween = null
var _debug_token: int = 0


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	layer = 6
	_build()
	var weather: WeatherManager = WeatherManager.instance
	if weather != null:
		weather.weather_changed.connect(_on_weather_changed)
		weather.debug_toast.connect(show_debug_toast)


func _build() -> void:
	root_control = Control.new()
	root_control.name = "Root"
	root_control.theme = THEME
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_to_group(SettingsManager.HUD_TEXT_GROUP)
	add_child(root_control)

	stack = VBoxContainer.new()
	stack.name = "WeatherStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	stack.add_theme_constant_override("separation", int(STACK_GAP))
	stack.anchor_left = 1.0
	stack.anchor_right = 1.0
	stack.offset_top = TOAST_TOP
	stack.offset_right = -MARGIN_RIGHT
	stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root_control.add_child(stack)

	toast_panel = _chip()
	toast_label = toast_panel.find_child("ToastLabel", true, false) as Label
	_toast_icon = toast_panel.find_child("ToastIcon", true, false) as TextureRect
	toast_panel.name = "WeatherToast"
	stack.add_child(toast_panel)
	toast_panel.visible = false


func _chip() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ToastRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	panel.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.name = "ToastIcon"
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	row.add_child(icon)
	var label: Label = Label.new()
	label.name = "ToastLabel"
	label.theme_type_variation = &"ToastLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)
	return panel


static func _icon_for_toast(text: String) -> String:
	var low: String = text.to_lower()
	if low.contains("chuva") or low.contains("rain"):
		return "rain"
	if low.contains("nevasca") or low.contains("blizzard") or low.contains("snow"):
		return "snow"
	if low.contains("cinzas") or low.contains("ash"):
		return "ash"
	if low.contains("abriu") or low.contains("clear"):
		return "sun"
	return ""


func _on_weather_changed(kind: String, phase: String) -> void:
	match phase:
		WeatherManager.PHASE_WARNING:
			show_toast(str(WARNING_TEXTS.get(kind, "")))
		WeatherManager.PHASE_ACTIVE:
			pass
		_:
			# kind vazio = troca de cena / fim da expedição: sem aviso.
			if kind.is_empty():
				hide_toast()
			else:
				show_toast(CLEAR_TEXT)


static func _bg_for_icon(icon_name: String) -> Color:
	match icon_name:
		"sun":
			return UiPalette.GREEN_BOTTLE
		"ash":
			return UiPalette.WOOD_DARK.lerp(UiPalette.RED_BURNT, 0.48)
		"rain", "snow":
			return UiPalette.METAL.darkened(0.28)
	return UiPalette.GREEN_BOTTLE


func _apply_toast_tone(panel: PanelContainer, bg: Color) -> void:
	var base: StyleBoxFlat = panel.get_theme_stylebox(&"panel", &"ToastPanel") as StyleBoxFlat
	var box: StyleBoxFlat = base.duplicate() as StyleBoxFlat if base != null else StyleBoxFlat.new()
	if base == null:
		box.set_border_width_all(2)
		box.border_color = UiPalette.INK
		box.set_corner_radius_all(6)
		box.content_margin_left = 14.0
		box.content_margin_right = 14.0
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
	box.bg_color = bg
	panel.add_theme_stylebox_override(&"panel", box)


func show_toast(text: String) -> void:
	if text.is_empty():
		return
	_cancel_toast_tween()
	toast_label.text = text
	var icon_name: String = _icon_for_toast(text)
	_apply_toast_tone(toast_panel, _bg_for_icon(icon_name))
	if _toast_icon != null:
		_toast_icon.texture = UiIcons.get_icon(icon_name, 22) if not icon_name.is_empty() else null
		_toast_icon.visible = _toast_icon.texture != null
	toast_panel.modulate.a = 1.0
	toast_panel.show()
	if not is_inside_tree():
		return
	UiMotion.toast_enter(toast_panel, _toast_icon, false)
	_toast_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(toast_panel, ^"modulate:a", 0.0, TOAST_EXIT_DURATION)
	_toast_tween.tween_callback(toast_panel.hide)


func show_debug_toast(text: String) -> void:
	if debug_panel == null:
		debug_panel = _chip()
		debug_panel.name = "WeatherDebugToast"
		stack.add_child(debug_panel)
	_debug_token += 1
	var token: int = _debug_token
	var dbg_label: Label = debug_panel.find_child("ToastLabel", true, false) as Label
	if dbg_label != null:
		dbg_label.text = text
	debug_panel.visible = true
	if not is_inside_tree():
		return
	await get_tree().create_timer(2.0, false).timeout
	if token == _debug_token and is_instance_valid(debug_panel):
		debug_panel.visible = false


func hide_toast() -> void:
	_cancel_toast_tween()
	toast_panel.hide()
	toast_panel.modulate.a = 1.0


func _cancel_toast_tween() -> void:
	if _toast_tween != null:
		_toast_tween.kill()
		_toast_tween = null
	UiMotion.stop(toast_panel)
	UiMotion.stop(_toast_icon)
