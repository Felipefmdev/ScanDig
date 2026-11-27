class_name PauseMenu
extends CanvasLayer

## Menu de pausa (#77): Continuar, Configurações, Voltar à base, Sair da sessão, Sair para o menu
## principal (#100) e Sair do jogo.
## Em solo pausa a árvore; em coop não pausa (o player consulta is_open() e para o input local).
## Não abre com o carregamento, o resumo do dia ou o aviso de queda do host na tela.
## Autoload CorePauseMenu. Abre e fecha pela ação "pause" (Esc); dentro das Configurações ou da
## confirmação de saída, o Esc volta ao cartão. Também mostra o contador de FPS (Jogabilidade).

signal open_changed(open: bool)

const CARD_FADE_DURATION: float = 0.16

const QUIT_TEXT: String = "Sair do jogo?\nO progresso da base é salvo ao fim de cada expedição."
const MAIN_MENU_BASE_TEXT: String = "Voltar ao menu principal?\nO progresso da base é salvo agora."
const MAIN_MENU_EXPEDITION_TEXT: String = "Voltar ao menu principal?\nA expedição em andamento não é salva."
const MAIN_MENU_COOP_TEXT: String = "Sair da sessão e voltar ao menu principal?"

static var instance: PauseMenu = null

var root_control: Control = null
var card: PanelContainer = null
var pause_subtitle_label: Label = null
var _pause_subtitle_row: HBoxContainer = null
var _pause_subtitle_icon: TextureRect = null
var continue_button: Button = null
var settings_button: Button = null
var return_button: Button = null
var leave_button: Button = null
var main_menu_button: Button = null
var quit_button: Button = null
var quit_icon: TextureRect = null
var _quit_badge: PanelContainer = null
var quit_label: Label = null
var quit_panel: PanelContainer = null
var quit_yes_button: Button = null
var quit_no_button: Button = null
var settings_menu: SettingsMenu = null
## Foco antes de abrir (#135), devolvido ao fechar.
var _focus_before: Control = null
var fps_label: Label = null

var _open: bool = false
var _paused_by_me: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _fps_refresh: float = 0.0
var _card_tween: Tween = null
var _animated_card: Control = null
## O que o "Sim" da confirmação faz: "quit" (Sair do jogo) ou "title" (menu principal).
var _confirm_target: String = "quit"


static func is_open() -> bool:
	return instance != null and instance._open


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if _paused_by_me and is_inside_tree():
		get_tree().paused = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control = get_node_or_null(^"Root") as Control
	if root_control == null:
		push_warning("PauseMenu: nó Root ausente; menu desativado.")
		return
	_build()
	root_control.visible = false
	_build_fps_label()
	var sm: SettingsManager = SettingsManager.instance
	if sm != null:
		sm.settings_changed.connect(_on_settings_changed)
		_on_settings_changed(SettingsManager.GAMEPLAY, sm.get_section(SettingsManager.GAMEPLAY))


func _unhandled_input(event: InputEvent) -> void:
	# B/Esc (ui_cancel) com o menu aberto faz o mesmo que a pausa: volta uma camada (#102).
	var cancel: bool = _open and event.is_action_pressed(&"ui_cancel", false, true)
	if not event.is_action_pressed(&"pause", false, true) and not cancel:
		return
	if _open and settings_menu.visible:
		settings_menu.call(&"_on_back_pressed")
	elif _open and quit_panel.visible:
		_show_card()
	else:
		toggle()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if fps_label == null or not fps_label.visible:
		return
	_fps_refresh -= delta
	if _fps_refresh <= 0.0:
		_fps_refresh = 0.5
		fps_label.text = "%d FPS" % int(Engine.get_frames_per_second())


func _build_fps_label() -> void:
	fps_label = Label.new()
	fps_label.name = "FpsLabel"
	fps_label.theme = root_control.theme
	# Pílula escura no canto superior direito: não colide com o MoneyChip do canto esquerdo.
	var fps_pill: StyleBoxFlat = StyleBoxFlat.new()
	fps_pill.bg_color = Color(UiPalette.INK, 0.90)
	fps_pill.border_color = Color(UiPalette.WOOD, 0.85)
	fps_pill.set_border_width_all(1)
	fps_pill.set_corner_radius_all(4)
	fps_pill.content_margin_left = 8.0
	fps_pill.content_margin_right = 8.0
	fps_pill.content_margin_top = 2.0
	fps_pill.content_margin_bottom = 2.0
	fps_label.add_theme_stylebox_override(&"normal", fps_pill)
	fps_label.add_theme_font_size_override(&"font_size", 14)
	fps_label.add_theme_color_override(&"font_color", UiPalette.PAPER_LIGHT)
	fps_label.add_theme_color_override(&"font_outline_color", UiPalette.INK)
	fps_label.add_theme_constant_override(&"outline_size", 3)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.anchor_left = 1.0
	fps_label.anchor_right = 1.0
	fps_label.anchor_top = 0.0
	fps_label.anchor_bottom = 0.0
	fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fps_label.offset_left = -82.0
	fps_label.offset_right = -10.0
	fps_label.offset_top = 8.0
	fps_label.offset_bottom = 32.0
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.visible = false
	add_child(fps_label)


func _on_settings_changed(section: String, values: Dictionary) -> void:
	if section == SettingsManager.GAMEPLAY and fps_label != null:
		fps_label.visible = bool(values.get("show_fps", false))
		_fps_refresh = 0.0


# --- Abrir / fechar ------------------------------------------------------------

## Carregamento, resumo do dia, queda do host, tela de morte ou tela de vitória: o menu não abre por cima.
func can_open() -> bool:
	if root_control == null or VictoryScreen.is_open() or DeathScreen.is_open():
		return false
	var ui: SessionUI = SessionUI.instance
	if ui == null:
		return true
	for panel: Control in [ui.loading_screen, ui.summary_panel, ui.host_lost_panel]:
		if panel != null and panel.visible:
			return false
	return true


func open() -> bool:
	if _open:
		return true
	if not can_open():
		return false
	# Contextual shops relinquish focus/mouse before the pause menu records them.
	get_tree().call_group(&"world_upgrade_shops", &"close")
	_open = true
	_refresh_buttons()
	settings_menu.visible = false
	quit_panel.visible = false
	card.visible = true
	root_control.visible = true
	var dim: CanvasItem = root_control.get_node_or_null(^"Dim") as CanvasItem
	if dim != null:
		UiMotion.fade_backdrop(dim, true)
	_animate_card(card)
	_link_card_focus()
	_focus_before = get_viewport().gui_get_focus_owner()
	continue_button.grab_focus()
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# O cartão da expedição (SessionUI, camada 50) ficaria por cima do escurecimento e clicável.
	if SessionUI.instance != null and SessionUI.instance.expedition_bar != null:
		SessionUI.instance.expedition_bar.visible = false
	if not _is_online() and not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true
	open_changed.emit(true)
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	if settings_menu.visible:
		settings_menu.discard()
	root_control.visible = false
	_reset_card_transition()
	if _paused_by_me:
		get_tree().paused = false
		_paused_by_me = false
	Input.mouse_mode = _previous_mouse_mode
	if SessionUI.instance != null and SessionUI.instance.expedition_bar != null:
		SessionUI.instance.call(&"_refresh_expedition_bar")
	_restore_focus()
	open_changed.emit(false)


## Fechou (#135): o foco volta ao controle de antes (a aba da Base, no lobby); sem ele, à Base.
func _restore_focus() -> void:
	var before: Control = _focus_before
	_focus_before = null
	if is_instance_valid(before) and before.is_visible_in_tree():
		before.grab_focus()
	elif is_inside_tree():
		get_tree().call_group(UiFocus.HOME_GROUP, &"focus_home")


func toggle() -> void:
	if _open:
		close()
	else:
		open()


# --- Montagem ------------------------------------------------------------------

func _button(text: String, variation: StringName = &"", icon_name: String = "") -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 48)
	# Comando e teclado navegam (#102).
	button.focus_mode = Control.FOCUS_ALL
	if not variation.is_empty():
		button.theme_type_variation = variation
	if not icon_name.is_empty():
		button.icon = UiIcons.get_icon(icon_name, 22)
	UiMotion.attach_button(button)
	return button


func _card(child: Control) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"WornPanel"
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_child(child)
	panel.add_child(margin)
	return panel


func _build() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	UiFocus.follow_pointer(center)
	var stack: VBoxContainer = VBoxContainer.new()
	center.add_child(stack)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override(&"separation", 8)
	var title_icon: TextureRect = TextureRect.new()
	title_icon.texture = UiIcons.get_icon("compass", 32)
	title_icon.custom_minimum_size = Vector2(24, 24)
	title_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(title_icon)
	var title: Label = Label.new()
	title.text = "Pausado"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	box.add_child(title_row)
	_pause_subtitle_row = HBoxContainer.new()
	_pause_subtitle_row.name = "PauseSubtitleRow"
	_pause_subtitle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_subtitle_row.add_theme_constant_override(&"separation", 6)
	_pause_subtitle_row.visible = false
	_pause_subtitle_icon = TextureRect.new()
	_pause_subtitle_icon.name = "PauseSubtitleIcon"
	_pause_subtitle_icon.texture = UiIcons.get_icon("map", 24)
	_pause_subtitle_icon.custom_minimum_size = Vector2(18, 18)
	_pause_subtitle_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pause_subtitle_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pause_subtitle_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pause_subtitle_row.add_child(_pause_subtitle_icon)
	pause_subtitle_label = Label.new()
	pause_subtitle_label.name = "PauseSubtitleLabel"
	pause_subtitle_label.theme_type_variation = &"HintLabel"
	pause_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_subtitle_label.visible = false
	_pause_subtitle_row.add_child(pause_subtitle_label)
	box.add_child(_pause_subtitle_row)
	box.add_child(HSeparator.new())
	continue_button = _button("Continuar", &"PrimaryButton", "play")
	var continue_focus: StyleBoxFlat = root_control.theme.get_stylebox(&"focus", &"PrimaryButton").duplicate() as StyleBoxFlat
	continue_focus.draw_center = false
	continue_focus.border_color = UiPalette.PAPER_LIGHT
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		continue_focus.set_border_width(side, 1)
		continue_focus.set_expand_margin(side, 0.0)
	_set_continue_focus(InputDevice.using_pointer(), continue_focus)
	if InputDevice.instance != null:
		InputDevice.instance.pointer_changed.connect(_set_continue_focus.bind(continue_focus))
	settings_button = _button("Configurações", &"", "gear")
	return_button = _button("Voltar à base", &"", "home")
	leave_button = _button("Sair da sessão", &"DangerButton", "multiplayer")
	main_menu_button = _button("Sair para o menu principal", &"", "compass")
	quit_button = _button("Sair do jogo", &"DangerButton", "door")
	for button: Button in [continue_button, settings_button, return_button, leave_button, main_menu_button, quit_button]:
		box.add_child(button)
	card = _card(box)
	card.name = "PauseCard"
	stack.add_child(card)

	var quit_box: VBoxContainer = VBoxContainer.new()
	quit_box.add_theme_constant_override("separation", 12)
	_quit_badge = PanelContainer.new()
	_quit_badge.name = "QuitBadge"
	_quit_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var qbadge_style: StyleBoxFlat = StyleBoxFlat.new()
	qbadge_style.bg_color = UiPalette.PAPER_LIGHT
	qbadge_style.border_color = UiPalette.INK
	qbadge_style.set_border_width_all(2)
	qbadge_style.set_corner_radius_all(28)
	qbadge_style.shadow_color = UiPalette.SHADOW
	qbadge_style.shadow_size = 1
	qbadge_style.shadow_offset = Vector2(1, 2)
	qbadge_style.content_margin_left = 10.0
	qbadge_style.content_margin_right = 10.0
	qbadge_style.content_margin_top = 10.0
	qbadge_style.content_margin_bottom = 10.0
	_quit_badge.add_theme_stylebox_override(&"panel", qbadge_style)
	quit_icon = TextureRect.new()
	quit_icon.name = "QuitIcon"
	quit_icon.texture = UiIcons.get_icon("warning", 28)
	quit_icon.custom_minimum_size = Vector2(28, 28)
	quit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	quit_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quit_badge.add_child(quit_icon)
	quit_box.add_child(_quit_badge)
	quit_label = Label.new()
	quit_label.text = QUIT_TEXT
	quit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit_box.add_child(quit_label)
	quit_box.add_child(HSeparator.new())
	var quit_row: HBoxContainer = HBoxContainer.new()
	quit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quit_row.add_theme_constant_override("separation", 12)
	quit_yes_button = _button("Sair", &"DangerButton", "door")
	quit_no_button = _button("Cancelar")
	for button: Button in [quit_yes_button, quit_no_button]:
		button.custom_minimum_size = Vector2(184, 46)
		quit_row.add_child(button)
	quit_box.add_child(quit_row)
	quit_panel = _card(quit_box)
	quit_panel.name = "QuitPanel"
	quit_panel.visible = false
	stack.add_child(quit_panel)

	settings_menu = SettingsMenu.new()
	settings_menu.name = "SettingsMenu"
	settings_menu.visible = false
	stack.add_child(settings_menu)

	continue_button.pressed.connect(close)
	settings_button.pressed.connect(_on_settings_pressed)
	return_button.pressed.connect(_on_return_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	quit_no_button.pressed.connect(_show_card)
	quit_yes_button.pressed.connect(_on_confirm_yes)
	settings_menu.closed.connect(_show_card)


func _set_continue_focus(pointer: bool, focus: StyleBoxFlat) -> void:
	if pointer:
		continue_button.remove_theme_stylebox_override(&"focus")
	else:
		continue_button.add_theme_stylebox_override(&"focus", focus)


## Cima/baixo entre os botões visíveis do cartão e da confirmação (#102).
func _link_card_focus() -> void:
	UiFocus.link_chain([continue_button, settings_button, return_button, leave_button, main_menu_button, quit_button])


func _show_card() -> void:
	settings_menu.visible = false
	quit_panel.visible = false
	card.visible = true
	_animate_card(card)
	if continue_button.is_visible_in_tree():
		continue_button.grab_focus()


# --- Botões --------------------------------------------------------------------

func _animate_card(panel: Control) -> void:
	if not _open:
		return
	_reset_card_transition()
	_animated_card = panel
	_card_tween = UiMotion.pop_in(panel, true, 0.955, CARD_FADE_DURATION)
	var emblem: Control = (_quit_badge as Control) if _quit_badge != null else (quit_icon as Control)
	if panel == quit_panel and emblem != null:
		UiMotion.breathe_emblem(emblem, 1.055, 2.4, 1.1, true)
	elif emblem != null:
		UiMotion.stop(emblem, true)


func _reset_card_transition() -> void:
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	_card_tween = null
	if is_instance_valid(_animated_card):
		UiMotion.stop(_animated_card)
	_animated_card = null
	var emblem: Control = (_quit_badge as Control) if _quit_badge != null else (quit_icon as Control)
	if emblem != null:
		UiMotion.stop(emblem, true)


func _session() -> Node:
	return get_node_or_null(^"/root/CoreSession")


func _is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func _is_host() -> bool:
	return GameState.instance.is_authority() if GameState.instance != null else multiplayer.is_server()


## Voltar à base: só o host, em expedição. Sair da sessão: online (host ou cliente).
func _refresh_buttons() -> void:
	var session: Node = _session()
	var in_expedition: bool = session != null and bool(session.call(&"is_in_expedition"))
	return_button.visible = in_expedition and _is_host()
	leave_button.visible = _is_online()
	if pause_subtitle_label != null:
		if in_expedition and session.has_method(&"get_current_map"):
			var map: MapData = session.call(&"get_current_map") as MapData
			var map_name: String = ""
			if map != null:
				map_name = map.display_name if not map.display_name.is_empty() else map.id
			var map_title: String = tr(map_name) if not map_name.is_empty() else ""
			var night: bool = SessionManager.is_night()
			if not map_title.is_empty() and night:
				map_title = tr("%s (noite)") % map_title
			if _pause_subtitle_icon != null:
				_pause_subtitle_icon.texture = UiIcons.get_icon("moon" if night else "map", 24)
			var day: int = GameState.instance.current_day if GameState.instance != null else 1
			pause_subtitle_label.text = tr("%s  •  Dia %d") % [map_title, day] if not map_title.is_empty() else ""
			var has_sub: bool = not pause_subtitle_label.text.is_empty()
			pause_subtitle_label.visible = has_sub
			if _pause_subtitle_row != null:
				_pause_subtitle_row.visible = has_sub
		else:
			pause_subtitle_label.text = ""
			pause_subtitle_label.visible = false
			if _pause_subtitle_row != null:
				_pause_subtitle_row.visible = false


func _on_settings_pressed() -> void:
	card.visible = false
	settings_menu.refresh()
	settings_menu.visible = true
	_animate_card(settings_menu)
	settings_menu.focus_first()


## Pede ao SessionUI o fim da expedição (a barra não tem mais o botão, #122).
func _on_return_pressed() -> void:
	close()
	var ui: SessionUI = SessionUI.instance
	if ui != null:
		ui.request_return_to_base()


## Mesmo fluxo do LeaveButton do SessionUI (abre a confirmação dele).
func _on_leave_pressed() -> void:
	close()
	var ui: SessionUI = SessionUI.instance
	if ui != null and ui.leave_button != null:
		ui.leave_button.pressed.emit()


func _on_quit_pressed() -> void:
	_confirm_target = "quit"
	quit_label.text = QUIT_TEXT
	quit_yes_button.text = "Sair"
	quit_yes_button.icon = UiIcons.get_icon("door", 22)
	card.visible = false
	quit_panel.visible = true
	_animate_card(quit_panel)
	UiFocus.link_chain([quit_yes_button, quit_no_button])
	quit_yes_button.focus_neighbor_right = quit_yes_button.get_path_to(quit_no_button)
	quit_no_button.focus_neighbor_left = quit_no_button.get_path_to(quit_yes_button)
	quit_no_button.grab_focus()


## Mesma confirmação do Sair do jogo, com o texto do caso (base, expedição ou coop).
func _on_main_menu_pressed() -> void:
	_confirm_target = "title"
	var session: Node = _session()
	var in_expedition: bool = session != null and bool(session.call(&"is_in_expedition"))
	if _is_online():
		quit_label.text = MAIN_MENU_COOP_TEXT
	else:
		quit_label.text = MAIN_MENU_EXPEDITION_TEXT if in_expedition else MAIN_MENU_BASE_TEXT
	quit_yes_button.text = "Ir para o menu"
	quit_yes_button.icon = UiIcons.get_icon("compass", 22)
	card.visible = false
	quit_panel.visible = true
	_animate_card(quit_panel)
	UiFocus.link_chain([quit_yes_button, quit_no_button])
	quit_yes_button.focus_neighbor_right = quit_yes_button.get_path_to(quit_no_button)
	quit_no_button.focus_neighbor_left = quit_no_button.get_path_to(quit_yes_button)
	quit_no_button.grab_focus()


func _on_confirm_yes() -> void:
	if _confirm_target != "title":
		get_tree().quit()
		return
	close()
	if SessionManager.instance != null:
		SessionManager.instance.return_to_title()
