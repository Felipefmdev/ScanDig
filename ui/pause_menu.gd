class_name PauseMenu
extends CanvasLayer

## Menu de pausa (#77): Continuar, Configurações, Voltar à base, Sair da sessão, Sair para o menu
## principal (#100) e Sair do jogo.
## Em solo pausa a árvore; em coop não pausa (o player consulta is_open() e para o input local).
## Não abre com o carregamento, o resumo do dia ou o aviso de queda do host na tela.
## Autoload CorePauseMenu. Abre e fecha pela ação "pause" (Esc); dentro das Configurações ou da
## confirmação de saída, o Esc volta ao cartão. Também mostra o contador de FPS (Jogabilidade).

signal open_changed(open: bool)

const QUIT_TEXT: String = "Sair do jogo?\nO progresso da base é salvo ao fim de cada expedição."
const MAIN_MENU_BASE_TEXT: String = "Voltar ao menu principal?\nO progresso da base é salvo agora."
const MAIN_MENU_EXPEDITION_TEXT: String = "Voltar ao menu principal?\nA expedição em andamento não é salva."
const MAIN_MENU_COOP_TEXT: String = "Sair da sessão e voltar ao menu principal?"

static var instance: PauseMenu = null

var root_control: Control = null
var card: PanelContainer = null
var continue_button: Button = null
var settings_button: Button = null
var return_button: Button = null
var leave_button: Button = null
var main_menu_button: Button = null
var quit_button: Button = null
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
	# Texto claro com contorno: legível sobre o mundo e sobre os painéis do HUD.
	fps_label.add_theme_font_size_override(&"font_size", 14)
	fps_label.add_theme_color_override(&"font_color", UiPalette.PAPER)
	fps_label.add_theme_color_override(&"font_outline_color", UiPalette.INK)
	fps_label.add_theme_constant_override(&"outline_size", 5)
	fps_label.position = Vector2(6, 0)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.visible = false
	add_child(fps_label)


func _on_settings_changed(section: String, values: Dictionary) -> void:
	if section == SettingsManager.GAMEPLAY and fps_label != null:
		fps_label.visible = bool(values.get("show_fps", false))
		_fps_refresh = 0.0


# --- Abrir / fechar ------------------------------------------------------------

## Carregamento, resumo do dia, queda do host ou tela de vitória: o menu não abre por cima.
func can_open() -> bool:
	if root_control == null or VictoryScreen.is_open():
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
	_open = true
	_refresh_buttons()
	settings_menu.visible = false
	quit_panel.visible = false
	card.visible = true
	root_control.visible = true
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

func _button(text: String, variation: StringName = &"") -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 48)
	# Comando e teclado navegam (#102).
	button.focus_mode = Control.FOCUS_ALL
	if not variation.is_empty():
		button.theme_type_variation = variation
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
	var stack: VBoxContainer = VBoxContainer.new()
	center.add_child(stack)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var title: Label = Label.new()
	title.text = "Pausado"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	continue_button = _button("Continuar", &"PrimaryButton")
	settings_button = _button("Configurações")
	return_button = _button("Voltar à base")
	leave_button = _button("Sair da sessão", &"DangerButton")
	main_menu_button = _button("Sair para o menu principal")
	quit_button = _button("Sair do jogo", &"DangerButton")
	for button: Button in [continue_button, settings_button, return_button, leave_button, main_menu_button, quit_button]:
		box.add_child(button)
	card = _card(box)
	card.name = "PauseCard"
	stack.add_child(card)

	var quit_box: VBoxContainer = VBoxContainer.new()
	quit_box.add_theme_constant_override("separation", 12)
	quit_label = Label.new()
	quit_label.text = QUIT_TEXT
	quit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit_box.add_child(quit_label)
	quit_yes_button = _button("Sair", &"DangerButton")
	quit_no_button = _button("Cancelar")
	quit_box.add_child(quit_yes_button)
	quit_box.add_child(quit_no_button)
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


## Cima/baixo entre os botões visíveis do cartão e da confirmação (#102).
func _link_card_focus() -> void:
	UiFocus.link_chain([continue_button, settings_button, return_button, leave_button, main_menu_button, quit_button])


func _show_card() -> void:
	settings_menu.visible = false
	quit_panel.visible = false
	card.visible = true
	if continue_button.is_visible_in_tree():
		continue_button.grab_focus()


# --- Botões --------------------------------------------------------------------

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


func _on_settings_pressed() -> void:
	card.visible = false
	settings_menu.refresh()
	settings_menu.visible = true
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
	card.visible = false
	quit_panel.visible = true
	UiFocus.link_chain([quit_yes_button, quit_no_button])
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
	card.visible = false
	quit_panel.visible = true
	UiFocus.link_chain([quit_yes_button, quit_no_button])
	quit_no_button.grab_focus()


func _on_confirm_yes() -> void:
	if _confirm_target != "title":
		get_tree().quit()
		return
	close()
	if SessionManager.instance != null:
		SessionManager.instance.return_to_title()
