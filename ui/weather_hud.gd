class_name WeatherHud
extends CanvasLayer

## Aviso e ícone do clima (#99), só na tela local. No "warning" mostra o aviso ("Chuva
## chegando…"); no fim, "O tempo abriu". Enquanto o evento está ativo, mostra um chip com o
## clima no canto superior direito, logo abaixo da barra de Ameaça do Subsolo (fora do HUD do
## jogador, da barra de expedição e do radar). Estilo do tema: ToastPanel / ToastLabel.
## O texto acompanha o tamanho do texto do HUD (grupo settings_hud_text).
## Autoload CoreWeatherUI; escuta CoreWeather.weather_changed.

const THEME: Theme = preload("res://ui/theme/scandig_theme.tres")
const WARNING_TEXTS: Dictionary = {
	WeatherManager.KIND_RAIN: "Chuva chegando…",
	WeatherManager.KIND_BLIZZARD: "Nevasca chegando…",
	WeatherManager.KIND_ASHSTORM: "Tempestade de cinzas chegando…",
}
const ICON_TEXTS: Dictionary = {
	WeatherManager.KIND_RAIN: "☂ Chuva",
	WeatherManager.KIND_BLIZZARD: "❄ Nevasca",
	WeatherManager.KIND_ASHSTORM: "▲ Cinzas",
}
const CLEAR_TEXT: String = "O tempo abriu"
const TOAST_SECONDS: float = 3.5
## Canto superior direito, abaixo da barra de Ameaça (em unidades da tela base).
const MARGIN_RIGHT: float = 24.0
const ICON_TOP: float = 76.0
const STACK_GAP: float = 8.0

static var instance: WeatherHud = null

var root_control: Control = null
var stack: VBoxContainer = null
var icon_panel: PanelContainer = null
var icon_label: Label = null
var toast_panel: PanelContainer = null
var toast_label: Label = null
var _toast_token: int = 0


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
	stack.offset_top = ICON_TOP
	stack.offset_right = -MARGIN_RIGHT
	stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root_control.add_child(stack)

	icon_panel = _chip()
	icon_label = icon_panel.get_child(0) as Label
	icon_panel.name = "WeatherIcon"
	stack.add_child(icon_panel)
	toast_panel = _chip()
	toast_label = toast_panel.get_child(0) as Label
	toast_panel.name = "WeatherToast"
	stack.add_child(toast_panel)
	icon_panel.visible = false
	toast_panel.visible = false


func _chip() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var label: Label = Label.new()
	label.theme_type_variation = &"ToastLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _on_weather_changed(kind: String, phase: String) -> void:
	match phase:
		WeatherManager.PHASE_WARNING:
			icon_panel.visible = false
			show_toast(str(WARNING_TEXTS.get(kind, "")))
		WeatherManager.PHASE_ACTIVE:
			icon_label.text = str(ICON_TEXTS.get(kind, ""))
			icon_panel.visible = not icon_label.text.is_empty()
		_:
			icon_panel.visible = false
			# kind vazio = troca de cena / fim da expedição: sem aviso.
			if kind.is_empty():
				hide_toast()
			else:
				show_toast(CLEAR_TEXT)


func show_toast(text: String) -> void:
	if text.is_empty():
		return
	_toast_token += 1
	var token: int = _toast_token
	toast_label.text = text
	toast_panel.modulate.a = 1.0
	toast_panel.visible = true
	if not is_inside_tree():
		return
	await get_tree().create_timer(TOAST_SECONDS, false).timeout
	if token != _toast_token or not is_instance_valid(toast_panel):
		return
	var tween: Tween = create_tween()
	tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)
	await tween.finished
	if token == _toast_token:
		toast_panel.visible = false


func hide_toast() -> void:
	_toast_token += 1
	toast_panel.visible = false
