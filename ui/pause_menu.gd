class_name PauseMenu
extends CanvasLayer

## Menu de pausa (#77): Continuar, Configurações, Voltar à base, Sair da sessão, Sair do jogo.
## Em solo pausa a árvore; em coop não pausa (o player consulta is_open() e para o input local).
## Não abre com o carregamento, o resumo do dia ou o aviso de queda do host na tela.
## Autoload CorePauseMenu. Abre e fecha pela ação "pause" (Esc); dentro das Configurações ou da
## confirmação de saída, o Esc volta ao cartão.

signal open_changed(open: bool)

const QUIT_TEXT: String = "Sair do jogo?\nO progresso da base é salvo ao fim de cada expedição."

static var instance: PauseMenu = null

var root_control: Control = null
var card: PanelContainer = null
var continue_button: Button = null
var settings_button: Button = null
var return_button: Button = null
var leave_button: Button = null
var quit_button: Button = null
var quit_panel: PanelContainer = null
var quit_yes_button: Button = null
var quit_no_button: Button = null
var settings_menu: SettingsMenu = null

var _open: bool = false
var _paused_by_me: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


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


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause", false, true):
		return
	if _open and settings_menu.visible:
		settings_menu.call(&"_on_back_pressed")
	elif _open and quit_panel.visible:
		_show_card()
	else:
		toggle()
	get_viewport().set_input_as_handled()


# --- Abrir / fechar ------------------------------------------------------------

## Carregamento, resumo do dia ou queda do host na tela: o menu não abre por cima.
func can_open() -> bool:
	if root_control == null:
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
		settings_menu.call(&"_on_back_pressed")
	root_control.visible = false
	if _paused_by_me:
		get_tree().paused = false
		_paused_by_me = false
	Input.mouse_mode = _previous_mouse_mode
	if SessionUI.instance != null and SessionUI.instance.expedition_bar != null:
		SessionUI.instance.call(&"_refresh_expedition_bar")
	open_changed.emit(false)


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
	button.focus_mode = Control.FOCUS_NONE
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
	quit_button = _button("Sair do jogo", &"DangerButton")
	for button: Button in [continue_button, settings_button, return_button, leave_button, quit_button]:
		box.add_child(button)
	card = _card(box)
	stack.add_child(card)

	var quit_box: VBoxContainer = VBoxContainer.new()
	quit_box.add_theme_constant_override("separation", 12)
	var quit_label: Label = Label.new()
	quit_label.text = QUIT_TEXT
	quit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit_box.add_child(quit_label)
	quit_yes_button = _button("Sair", &"DangerButton")
	quit_no_button = _button("Cancelar")
	quit_box.add_child(quit_yes_button)
	quit_box.add_child(quit_no_button)
	quit_panel = _card(quit_box)
	quit_panel.visible = false
	stack.add_child(quit_panel)

	settings_menu = SettingsMenu.new()
	settings_menu.visible = false
	stack.add_child(settings_menu)

	continue_button.pressed.connect(close)
	settings_button.pressed.connect(_on_settings_pressed)
	return_button.pressed.connect(_on_return_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	quit_no_button.pressed.connect(_show_card)
	quit_yes_button.pressed.connect(func() -> void: get_tree().quit())
	settings_menu.closed.connect(_show_card)


func _show_card() -> void:
	settings_menu.visible = false
	quit_panel.visible = false
	card.visible = true


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


## Mesmo fluxo do ReturnButton do SessionUI (pede ao SessionManager o fim da expedição).
func _on_return_pressed() -> void:
	close()
	var ui: SessionUI = SessionUI.instance
	if ui != null and ui.return_button != null:
		ui.return_button.pressed.emit()


## Mesmo fluxo do LeaveButton do SessionUI (abre a confirmação dele).
func _on_leave_pressed() -> void:
	close()
	var ui: SessionUI = SessionUI.instance
	if ui != null and ui.leave_button != null:
		ui.leave_button.pressed.emit()


func _on_quit_pressed() -> void:
	card.visible = false
	quit_panel.visible = true
