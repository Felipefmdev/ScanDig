class_name SettingsMenu
extends PanelContainer

## Tela de Configurações (#77): abas Vídeo / Áudio / Controles / Jogabilidade. Só fala com o
## SettingsManager. As mudanças ficam pendentes até Aplicar (aviso "Configurações salvas");
## Voltar com mudanças pendentes pergunta antes de descartar. Modo de janela e resolução pedem
## confirmação e voltam sozinhos em 10 s.

signal closed

const WINDOW_LABELS: Dictionary = {"windowed": "Janela", "fullscreen": "Tela cheia", "borderless": "Tela cheia sem borda"}
const QUALITY_LABELS: Dictionary = {"low": "Baixa", "medium": "Média", "high": "Alta"}
const AUDIO_LABELS: Dictionary = {"master": "Volume geral", "music": "Música", "sfx": "Efeitos"}
const TAB_VIDEO: int = 0
const TAB_AUDIO: int = 1
const TAB_CONTROLS: int = 2
const TAB_GAMEPLAY: int = 3
## Sensibilidade mostrada em % do padrão (0.0025 = 100 %), como no painel antigo do Esc.
const SENSITIVITY_UNIT: float = 0.0025
const CAPTURE_TEXT: String = "Pressione uma tecla…"
const SAVED_TEXT: String = "Configurações salvas"
const SAVED_SECONDS: float = 2.0
const DISCARD_TEXT: String = "Descartar alterações?\nAs mudanças que não foram aplicadas serão perdidas."

var tabs: TabContainer = null
var window_mode_option: OptionButton = null
var resolution_option: OptionButton = null
var vsync_check: CheckBox = null
var fps_option: OptionButton = null
var ui_scale_slider: HSlider = null
var ui_scale_value: Label = null
var quality_option: OptionButton = null
var audio_sliders: Dictionary = {}
var audio_values: Dictionary = {}
var apply_button: Button = null
var defaults_button: Button = null
var back_button: Button = null
var confirm_panel: PanelContainer = null
var confirm_label: Label = null
var keep_button: Button = null
var revert_button: Button = null
var control_buttons: Dictionary = {}
var conflict_panel: PanelContainer = null
var conflict_label: Label = null
var swap_button: Button = null
var conflict_cancel_button: Button = null
## Ação esperando tecla ("" = nenhuma) e o binding em conflito aguardando Trocar/Cancelar.
var capturing: String = ""
var _conflict_binding: Dictionary = {}
var sensitivity_slider: HSlider = null
var sensitivity_value: Label = null
var invert_y_check: CheckBox = null
var fov_slider: HSlider = null
var fov_value: Label = null
var bobbing_check: CheckBox = null
var show_fps_check: CheckBox = null
var hud_text_slider: HSlider = null
var hud_text_value: Label = null
var language_option: OptionButton = null
var buttons_row: HBoxContainer = null
var saved_notice: PanelContainer = null
var discard_panel: PanelContainer = null
var discard_button: Button = null
var discard_cancel_button: Button = null
## Valores pendentes logo depois do último refresh/Aplicar: diferente disso = mudança não aplicada.
var _clean_state: Dictionary = {}
var _saved_token: int = 0

var _resolutions: Array[Vector2i] = []
var _trial_left: float = 0.0


func _ready() -> void:
	theme_type_variation = &"WornPanel"
	custom_minimum_size = Vector2(640, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	var sm: SettingsManager = SettingsManager.instance
	if sm != null:
		sm.video_trial_finished.connect(_on_video_trial_finished)
	refresh()


func _process(delta: float) -> void:
	if saved_notice != null and saved_notice.visible:
		_place_saved_notice()
	if confirm_panel == null or not confirm_panel.visible:
		return
	_trial_left = maxf(_trial_left - delta, 0.0)
	confirm_label.text = "Manter este modo de vídeo?\nVoltando ao anterior em %d s." % ceili(_trial_left)


# --- Montagem ------------------------------------------------------------------

func _margin(child: Control, size: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, size)
	margin.add_child(child)
	return margin


func _row(grid: GridContainer, text: String, control: Control) -> void:
	var label: Label = Label.new()
	label.text = text
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _option(items: Array) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	for item: Variant in items:
		option.add_item(str(item))
	return option


func _slider_row(grid: GridContainer, text: String, min_value: float, max_value: float, step: float) -> Array:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	var value: Label = Label.new()
	value.custom_minimum_size = Vector2(64, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(slider)
	box.add_child(value)
	_row(grid, text, box)
	return [slider, value]


## Caixa de marcar com o texto do estado: "Ligado" / "Desligado".
func _checkbox() -> CheckBox:
	var check: CheckBox = CheckBox.new()
	check.text = "Desligado"
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(on: bool) -> void: check.text = "Ligado" if on else "Desligado")
	return check


func _grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	return grid


func _build() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(_margin(box, 18))

	var title: Label = Label.new()
	title.text = "Configurações"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 300)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)

	# Vídeo
	var video: GridContainer = _grid()
	window_mode_option = _option(WINDOW_LABELS.values())
	window_mode_option.item_selected.connect(func(_i: int) -> void: _update_resolution_enabled())
	_row(video, "Modo de janela", window_mode_option)
	_resolutions = SettingsManager.available_resolutions()
	var res_labels: Array = []
	for res: Vector2i in _resolutions:
		res_labels.append("%d × %d" % [res.x, res.y])
	resolution_option = _option(res_labels)
	_row(video, "Resolução", resolution_option)
	vsync_check = _checkbox()
	_row(video, "VSync", vsync_check)
	var fps_labels: Array = []
	for fps: int in SettingsManager.FPS_LIMITS:
		fps_labels.append("Ilimitado" if fps == 0 else str(fps))
	fps_option = _option(fps_labels)
	_row(video, "Limite de FPS", fps_option)
	var scale_row: Array = _slider_row(video, "Escala da interface", 90.0, 130.0, 5.0)
	ui_scale_slider = scale_row[0]
	ui_scale_value = scale_row[1]
	ui_scale_slider.value_changed.connect(func(v: float) -> void: ui_scale_value.text = "%d %%" % int(v))
	quality_option = _option(QUALITY_LABELS.values())
	_row(video, "Qualidade gráfica", quality_option)
	var video_page: MarginContainer = _margin(video, 14)
	video_page.name = "Vídeo"
	tabs.add_child(video_page)

	# Áudio
	var audio: GridContainer = _grid()
	for key: String in AUDIO_LABELS.keys():
		var row: Array = _slider_row(audio, AUDIO_LABELS[key], 0.0, 100.0, 5.0)
		var slider: HSlider = row[0]
		var value: Label = row[1]
		slider.value_changed.connect(func(v: float) -> void: value.text = "Mudo" if v <= 0.0 else "%d %%" % int(v))
		audio_sliders[key] = slider
		audio_values[key] = value
	var audio_page: MarginContainer = _margin(audio, 14)
	audio_page.name = "Áudio"
	tabs.add_child(audio_page)

	# Controles (etapa 2): uma linha por ação; clicar espera a tecla nova.
	var controls: GridContainer = _grid()
	for action: String in SettingsManager.CONTROL_ACTIONS:
		var bind_button: Button = Button.new()
		bind_button.custom_minimum_size = Vector2(0, 36)
		bind_button.focus_mode = Control.FOCUS_NONE
		bind_button.pressed.connect(start_capture.bind(action))
		control_buttons[action] = bind_button
		_row(controls, SettingsManager.ACTION_LABELS[action], bind_button)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls_page: MarginContainer = _margin(controls, 14)
	controls_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(controls_page)
	scroll.name = "Controles"
	tabs.add_child(scroll)

	# Jogabilidade (etapa 3): as opções do antigo painel do Esc do player e as novas.
	var gameplay: GridContainer = _grid()
	var sens_row: Array = _slider_row(gameplay, "Sensibilidade do mouse",
		roundf(SettingsManager.SENSITIVITY_RANGE.x / SENSITIVITY_UNIT * 100.0),
		roundf(SettingsManager.SENSITIVITY_RANGE.y / SENSITIVITY_UNIT * 100.0), 5.0)
	sensitivity_slider = sens_row[0]
	sensitivity_value = sens_row[1]
	sensitivity_slider.value_changed.connect(func(v: float) -> void: sensitivity_value.text = "%d %%" % int(v))
	invert_y_check = _checkbox()
	_row(gameplay, "Inverter eixo Y", invert_y_check)
	var fov_row: Array = _slider_row(gameplay, "Campo de visão", SettingsManager.FOV_RANGE.x, SettingsManager.FOV_RANGE.y, 1.0)
	fov_slider = fov_row[0]
	fov_value = fov_row[1]
	fov_slider.value_changed.connect(func(v: float) -> void: fov_value.text = "%d°" % int(v))
	bobbing_check = _checkbox()
	_row(gameplay, "Balanço da câmera ao andar", bobbing_check)
	show_fps_check = _checkbox()
	_row(gameplay, "Mostrar FPS", show_fps_check)
	var hud_row: Array = _slider_row(gameplay, "Tamanho do texto do HUD",
		SettingsManager.HUD_TEXT_SCALE_RANGE.x * 100.0, SettingsManager.HUD_TEXT_SCALE_RANGE.y * 100.0, 10.0)
	hud_text_slider = hud_row[0]
	hud_text_value = hud_row[1]
	hud_text_slider.value_changed.connect(func(v: float) -> void: hud_text_value.text = "%d %%" % int(v))
	# Idioma: só português por enquanto (sem tradução ainda).
	language_option = _option(["Português (Brasil)"])
	language_option.disabled = true
	language_option.tooltip_text = "Outros idiomas em breve."
	_row(gameplay, "Idioma", language_option)
	var gameplay_scroll: ScrollContainer = ScrollContainer.new()
	gameplay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gameplay_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gameplay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gameplay_page: MarginContainer = _margin(gameplay, 14)
	gameplay_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gameplay_scroll.add_child(gameplay_page)
	gameplay_scroll.name = "Jogabilidade"
	tabs.add_child(gameplay_scroll)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons_row = buttons
	buttons.add_theme_constant_override("separation", 12)
	defaults_button = Button.new()
	defaults_button.text = "Restaurar padrão"
	back_button = Button.new()
	back_button.text = "Voltar"
	apply_button = Button.new()
	apply_button.text = "Aplicar"
	apply_button.theme_type_variation = &"PrimaryButton"
	for button: Button in [defaults_button, back_button, apply_button]:
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		buttons.add_child(button)
	box.add_child(buttons)
	defaults_button.pressed.connect(_on_defaults_pressed)
	back_button.pressed.connect(_on_back_pressed)
	apply_button.pressed.connect(_on_apply_pressed)

	# Confirmação do modo de vídeo (por cima das abas).
	confirm_panel = PanelContainer.new()
	confirm_panel.theme_type_variation = &"WornPanel"
	confirm_panel.visible = false
	var confirm_box: VBoxContainer = VBoxContainer.new()
	confirm_box.add_theme_constant_override("separation", 12)
	confirm_label = Label.new()
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_box.add_child(confirm_label)
	var confirm_buttons: HBoxContainer = HBoxContainer.new()
	confirm_buttons.add_theme_constant_override("separation", 12)
	keep_button = Button.new()
	keep_button.text = "Manter"
	keep_button.theme_type_variation = &"PrimaryButton"
	revert_button = Button.new()
	revert_button.text = "Voltar ao anterior"
	for button: Button in [revert_button, keep_button]:
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		confirm_buttons.add_child(button)
	confirm_box.add_child(confirm_buttons)
	confirm_panel.add_child(_margin(confirm_box, 18))
	box.add_child(confirm_panel)
	# Conflito de tecla (por cima das abas).
	conflict_panel = PanelContainer.new()
	conflict_panel.theme_type_variation = &"WornPanel"
	conflict_panel.visible = false
	var conflict_box: VBoxContainer = VBoxContainer.new()
	conflict_box.add_theme_constant_override("separation", 12)
	conflict_label = Label.new()
	conflict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	conflict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	conflict_box.add_child(conflict_label)
	var conflict_buttons: HBoxContainer = HBoxContainer.new()
	conflict_buttons.add_theme_constant_override("separation", 12)
	conflict_cancel_button = Button.new()
	conflict_cancel_button.text = "Cancelar"
	swap_button = Button.new()
	swap_button.text = "Trocar"
	swap_button.theme_type_variation = &"PrimaryButton"
	for button: Button in [conflict_cancel_button, swap_button]:
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		conflict_buttons.add_child(button)
	conflict_box.add_child(conflict_buttons)
	conflict_panel.add_child(_margin(conflict_box, 18))
	box.add_child(conflict_panel)
	# Descartar alterações (Voltar com mudanças pendentes).
	discard_panel = PanelContainer.new()
	discard_panel.theme_type_variation = &"WornPanel"
	discard_panel.visible = false
	var discard_box: VBoxContainer = VBoxContainer.new()
	discard_box.add_theme_constant_override("separation", 12)
	var discard_label: Label = Label.new()
	discard_label.text = DISCARD_TEXT
	discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_box.add_child(discard_label)
	var discard_buttons: HBoxContainer = HBoxContainer.new()
	discard_buttons.add_theme_constant_override("separation", 12)
	discard_cancel_button = Button.new()
	discard_cancel_button.text = "Cancelar"
	discard_button = Button.new()
	discard_button.text = "Descartar"
	discard_button.theme_type_variation = &"DangerButton"
	for button: Button in [discard_cancel_button, discard_button]:
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		discard_buttons.add_child(button)
	discard_box.add_child(discard_buttons)
	discard_panel.add_child(_margin(discard_box, 18))
	box.add_child(discard_panel)
	discard_button.pressed.connect(discard)
	discard_cancel_button.pressed.connect(_hide_discard)

	# "Configurações salvas": por cima do painel (top_level), acima dos botões; some em ~2 s.
	saved_notice = PanelContainer.new()
	saved_notice.theme_type_variation = &"ToastPanel"
	saved_notice.top_level = true
	saved_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	saved_notice.visible = false
	var saved_label: Label = Label.new()
	saved_label.text = SAVED_TEXT
	saved_label.theme_type_variation = &"ToastLabel"
	saved_notice.add_child(saved_label)
	add_child(saved_notice)

	swap_button.pressed.connect(_on_swap_pressed)
	conflict_cancel_button.pressed.connect(_end_capture)
	keep_button.pressed.connect(func() -> void: SettingsManager.instance.confirm_video_trial())
	revert_button.pressed.connect(func() -> void: SettingsManager.instance.revert_video_trial())


# --- Valores -------------------------------------------------------------------

## Mostra os valores atuais do SettingsManager (descarta o que estava pendente).
func refresh() -> void:
	var sm: SettingsManager = SettingsManager.instance
	if sm == null:
		return
	var video: Dictionary = sm.get_section(SettingsManager.VIDEO)
	window_mode_option.select(maxi(WINDOW_LABELS.keys().find(video["window_mode"]), 0))
	var res_index: int = _resolutions.find(video["resolution"])
	if res_index < 0:
		res_index = _resolutions.find(Vector2i(1280, 720))
	if res_index >= 0:
		resolution_option.select(res_index)
	vsync_check.button_pressed = bool(video["vsync"])
	fps_option.select(maxi(SettingsManager.FPS_LIMITS.find(int(video["max_fps"])), 0))
	ui_scale_slider.value = roundf(float(video["ui_scale"]) * 100.0)
	ui_scale_value.text = "%d %%" % int(ui_scale_slider.value)
	quality_option.select(maxi(QUALITY_LABELS.keys().find(video["quality"]), 0))
	_update_resolution_enabled()
	_refresh_controls()
	var audio: Dictionary = sm.get_section(SettingsManager.AUDIO)
	for key: String in audio_sliders.keys():
		var slider: HSlider = audio_sliders[key]
		slider.value = roundf(float(audio[key]) * 100.0)
		(audio_values[key] as Label).text = "Mudo" if slider.value <= 0.0 else "%d %%" % int(slider.value)
	var gameplay: Dictionary = sm.get_section(SettingsManager.GAMEPLAY)
	sensitivity_slider.value = roundf(float(gameplay["mouse_sensitivity"]) / SENSITIVITY_UNIT * 100.0)
	sensitivity_value.text = "%d %%" % int(sensitivity_slider.value)
	invert_y_check.button_pressed = bool(gameplay["invert_y"])
	fov_slider.value = float(gameplay["fov"])
	fov_value.text = "%d°" % int(fov_slider.value)
	bobbing_check.button_pressed = bool(gameplay["view_bobbing"])
	show_fps_check.button_pressed = bool(gameplay["show_fps"])
	hud_text_slider.value = roundf(float(gameplay["hud_text_scale"]) * 100.0)
	hud_text_value.text = "%d %%" % int(hud_text_slider.value)
	_mark_clean()


func pending_gameplay() -> Dictionary:
	return {
		"mouse_sensitivity": sensitivity_slider.value / 100.0 * SENSITIVITY_UNIT,
		"invert_y": invert_y_check.button_pressed,
		"fov": fov_slider.value,
		"view_bobbing": bobbing_check.button_pressed,
		"show_fps": show_fps_check.button_pressed,
		"hud_text_scale": hud_text_slider.value / 100.0,
	}


func _pending_all() -> Dictionary:
	return {"video": pending_video(), "audio": pending_audio(), "gameplay": pending_gameplay()}


## Há mudança na tela que ainda não foi aplicada (os controles se aplicam na hora).
func has_pending_changes() -> bool:
	return _pending_all() != _clean_state


func _mark_clean() -> void:
	_clean_state = _pending_all()


func pending_video() -> Dictionary:
	var values: Dictionary = {
		"window_mode": WINDOW_LABELS.keys()[maxi(window_mode_option.selected, 0)],
		"vsync": vsync_check.button_pressed,
		"max_fps": SettingsManager.FPS_LIMITS[maxi(fps_option.selected, 0)],
		"ui_scale": ui_scale_slider.value / 100.0,
		"quality": QUALITY_LABELS.keys()[maxi(quality_option.selected, 0)],
	}
	if resolution_option.selected >= 0 and resolution_option.selected < _resolutions.size():
		values["resolution"] = _resolutions[resolution_option.selected]
	return values


func pending_audio() -> Dictionary:
	var values: Dictionary = {}
	for key: String in audio_sliders.keys():
		values[key] = (audio_sliders[key] as HSlider).value / 100.0
	return values


func _update_resolution_enabled() -> void:
	# Resolução só vale em janela; em tela cheia vale a do monitor.
	resolution_option.disabled = WINDOW_LABELS.keys()[maxi(window_mode_option.selected, 0)] != "windowed"


# --- Botões --------------------------------------------------------------------

func _on_apply_pressed() -> void:
	var sm: SettingsManager = SettingsManager.instance
	if sm == null:
		return
	sm.set_section(SettingsManager.AUDIO, pending_audio())
	sm.set_section(SettingsManager.GAMEPLAY, pending_gameplay())
	var video: Dictionary = pending_video()
	if SettingsManager.needs_video_trial(sm.get_section(SettingsManager.VIDEO), video):
		_trial_left = SettingsManager.VIDEO_TRIAL_SECONDS
		confirm_panel.visible = true
		tabs.visible = false
		sm.begin_video_trial(video)
	else:
		sm.set_section(SettingsManager.VIDEO, video)
		_mark_clean()
		show_saved_notice()


func _on_defaults_pressed() -> void:
	var sm: SettingsManager = SettingsManager.instance
	if sm == null:
		return
	if tabs.current_tab == TAB_CONTROLS:
		_end_capture()
		sm.reset_controls()
	elif tabs.current_tab == TAB_GAMEPLAY:
		sm.restore_defaults(SettingsManager.GAMEPLAY)
	elif tabs.current_tab == TAB_AUDIO:
		sm.restore_defaults(SettingsManager.AUDIO)
	elif tabs.current_tab == TAB_VIDEO:
		var defaults: Dictionary = (SettingsManager.DEFAULTS[SettingsManager.VIDEO] as Dictionary).duplicate()
		if SettingsManager.needs_video_trial(sm.get_section(SettingsManager.VIDEO), defaults):
			_trial_left = SettingsManager.VIDEO_TRIAL_SECONDS
			confirm_panel.visible = true
			tabs.visible = false
			sm.begin_video_trial(defaults)
		else:
			sm.restore_defaults(SettingsManager.VIDEO)
	refresh()


## Voltar (botão ou Esc): com mudanças não aplicadas pergunta antes; com a pergunta na tela,
## cancela a pergunta.
func _on_back_pressed() -> void:
	if discard_panel.visible:
		_hide_discard()
		return
	var sm: SettingsManager = SettingsManager.instance
	var trial: bool = sm != null and sm.is_video_trial_active()
	if not trial and capturing.is_empty() and has_pending_changes():
		hide_saved_notice()
		discard_panel.visible = true
		tabs.visible = false
		buttons_row.visible = false
		return
	discard()


## Fecha sem aplicar: desfaz o teste de vídeo e volta os valores da tela aos atuais.
func discard() -> void:
	_end_capture()
	hide_saved_notice()
	var sm: SettingsManager = SettingsManager.instance
	if sm != null and sm.is_video_trial_active():
		sm.revert_video_trial()
	_hide_discard()
	refresh()
	closed.emit()


func _hide_discard() -> void:
	discard_panel.visible = false
	buttons_row.visible = true
	tabs.visible = not confirm_panel.visible and not conflict_panel.visible


func show_saved_notice() -> void:
	_saved_token += 1
	var token: int = _saved_token
	saved_notice.modulate.a = 1.0
	saved_notice.visible = true
	_place_saved_notice()
	await get_tree().create_timer(SAVED_SECONDS * 0.75, true, false, true).timeout
	if token != _saved_token:
		return
	var tween: Tween = create_tween()
	tween.tween_property(saved_notice, "modulate:a", 0.0, SAVED_SECONDS * 0.25)
	await tween.finished
	if token == _saved_token:
		saved_notice.visible = false


func hide_saved_notice() -> void:
	_saved_token += 1
	saved_notice.visible = false


## Centrado no painel, logo acima dos botões (refeito a cada frame: o layout muda ao aplicar).
func _place_saved_notice() -> void:
	saved_notice.reset_size()
	var anchor_y: float = buttons_row.global_position.y if buttons_row.is_visible_in_tree() else global_position.y + size.y
	saved_notice.global_position = Vector2(global_position.x + (size.x - saved_notice.size.x) * 0.5, anchor_y - saved_notice.size.y - 10.0)


func _on_video_trial_finished(kept: bool) -> void:
	confirm_panel.visible = false
	tabs.visible = true
	refresh()
	if kept and is_visible_in_tree():
		show_saved_notice()


# --- Controles (etapa 2) -------------------------------------------------------

func _refresh_controls() -> void:
	var sm: SettingsManager = SettingsManager.instance
	if sm == null:
		return
	for action: String in control_buttons.keys():
		var button: Button = control_buttons[action]
		button.text = CAPTURE_TEXT if action == capturing else SettingsManager.binding_label(sm.get_binding(action))


## Clicou na ação: a próxima tecla ou botão do mouse vira o binding dela. Esc cancela.
func start_capture(action: String) -> void:
	capturing = action
	_conflict_binding = {}
	conflict_panel.visible = false
	_refresh_controls()


func _end_capture() -> void:
	capturing = ""
	_conflict_binding = {}
	if conflict_panel != null:
		conflict_panel.visible = false
		tabs.visible = true
	_refresh_controls()


func _input(event: InputEvent) -> void:
	if capturing.is_empty() or not _conflict_binding.is_empty() or not is_visible_in_tree():
		return
	var key: InputEventKey = event as InputEventKey
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if key != null and (not key.pressed or key.echo):
		return
	if mouse != null and not mouse.pressed:
		return
	if key == null and mouse == null:
		return
	get_viewport().set_input_as_handled()
	if key != null and (key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE):
		_end_capture()
		return
	capture_binding(SettingsManager.binding_from_event(event))


## Aplica o binding capturado; com conflito, pergunta antes de trocar.
func capture_binding(binding: Dictionary) -> void:
	var sm: SettingsManager = SettingsManager.instance
	if sm == null or capturing.is_empty() or binding.is_empty():
		return
	var other: String = sm.find_conflict(capturing, binding)
	if other.is_empty():
		sm.set_binding(capturing, binding)
		_end_capture()
		return
	_conflict_binding = binding
	conflict_label.text = "«%s» já está em %s.\nTrocar as duas ações?" % [SettingsManager.binding_label(binding), SettingsManager.ACTION_LABELS[other]]
	conflict_panel.visible = true
	tabs.visible = false


func _on_swap_pressed() -> void:
	var sm: SettingsManager = SettingsManager.instance
	if sm != null and not capturing.is_empty() and not _conflict_binding.is_empty():
		sm.set_binding(capturing, _conflict_binding, true)
	_end_capture()
