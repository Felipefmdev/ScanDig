class_name TitleScreen
extends Node3D

## Tela inicial (#100), a main scene do projeto: Continuar (só com save), Novo jogo, Carregar,
## Multiplayer, Configurações e Sair, sobre uma vista lenta da base (fundo 3D só de enfeite: sem
## jogador, rede nem spawners). Solo ativa o slot, aplica e abre a base sem o MultiplayerMenu;
## Multiplayer abre a base com ele, usando o slot escolhido. Com --bot=, --script/-s (GUT, testes,
## capturas) a tela é pulada e a base abre como antes.

const ORBIT_SPEED: float = 0.05
const TAGLINE: String = "Detecção de metais e escavação cooperativa"
const DEFAULT_VERSION: String = "0.1.0"
## Hover/foco dos botões: leve escala a partir do centro.
const BUTTON_FOCUS_SCALE: float = 1.04
## Logo: balanço lento (graus) e respiração da escala.
const LOGO_SWAY_DEG: float = 2.0
const LOGO_SWAY_SECONDS: float = 2.6
## Palmeiras do fundo: o colormap Kenney fica pálido na luz da Praia. Um toon próprio (só aqui; o
## .glb fica intocado) multiplicado por PALM_TINT leva o tronco ao marrom e as folhas ao verde das
## palmeiras dos mapas (PalmModel).
const PALM_NODES: Array[NodePath] = [^"Props/Palm1", ^"Props/Palm2"]
const PALM_TINT: Color = Color(0.56, 0.5, 0.44)
const NEW_GAME_CONFIRM: String = "Começar um jogo novo no slot %d?\nO progresso atual dele vai para o backup."
const DELETE_CONFIRM: String = "Apagar o slot %d? Isso não pode ser desfeito."
const SLOT_TITLES: Dictionary = {
	"load": "Carregar jogo",
	"new": "Novo jogo: escolha o slot",
	"coop": "Multiplayer: escolha o slot do host",
}

static var instance: TitleScreen = null

## Testes: false = monta a tela mesmo rodando no GUT (que seria pulado) e não troca de cena.
var auto_skip: bool = true
var scene_change_enabled: bool = true
## Última cena pedida por launch() (os testes conferem sem trocar de cena).
var launched_scene: String = ""

var ui_layer: CanvasLayer = null
var root_control: Control = null
var main_card: PanelContainer = null
var continue_button: Button = null
var new_game_button: Button = null
var load_button: Button = null
var coop_button: Button = null
var settings_button: Button = null
var quit_button: Button = null
var slots_panel: PanelContainer = null
var slots_title: Label = null
var slot_buttons: Array[Button] = []
var slot_delete_buttons: Array[Button] = []
var slots_back_button: Button = null
var confirm_panel: PanelContainer = null
var confirm_label: Label = null
var confirm_ok_button: Button = null
var confirm_cancel_button: Button = null
var message_label: Label = null
var logo_label: Label = null
var tagline_label: Label = null
var version_label: Label = null
var settings_menu: SettingsMenu = null
## "load" | "new" | "coop": o que clicar num slot faz.
var slot_mode: String = "load"

var _confirm_action: Callable = Callable()
var _pivot: Node3D = null


## Bots (--bot=), GUT e testes/capturas (--script / -s) não passam pela tela inicial. --bot= só
## vale em build de debug (o DebugBridge também só roda nela): no .exe release é ignorado.
static func should_skip(args: PackedStringArray, user_args: PackedStringArray, debug_build: bool = true) -> bool:
	for arg: String in args:
		if arg == "--script" or arg == "-s" or arg.contains("gut_cmdln"):
			return true
	for arg: String in user_args:
		if debug_build and arg.begins_with("--bot="):
			return true
	return false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	if auto_skip and should_skip(OS.get_cmdline_args(), OS.get_cmdline_user_args(), OS.is_debug_build()):
		SessionManager.launch_mode = ""
		_skip_to_lobby()
		return
	SessionManager.launch_mode = ""
	_pivot = get_node_or_null(^"CameraPivot") as Node3D
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_tint_palms()
	_build()
	show_main()


func _tint_palms() -> void:
	for path: NodePath in PALM_NODES:
		var palm: Node = get_node_or_null(path)
		if palm == null:
			continue
		ToonKit.apply_to_imported(palm)
		for node: Node in palm.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node as MeshInstance3D
			for s: int in mi.mesh.get_surface_count():
				var toon: ShaderMaterial = mi.get_surface_override_material(s) as ShaderMaterial
				if toon == null:
					continue
				var tinted: ShaderMaterial = toon.duplicate() as ShaderMaterial
				tinted.set_shader_parameter(&"albedo_color", PALM_TINT)
				mi.set_surface_override_material(s, tinted)


## Um frame depois: se o bot (ou quem abriu o título) já trocou de cena, o título saiu e não faz
## nada; senão abre a base. Trocar dentro do _ready se perde quando o título veio de uma troca.
func _skip_to_lobby() -> void:
	await get_tree().process_frame
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file(SessionManager.LOBBY_SCENE)


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotate_y(ORBIT_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel") and not event.is_action_pressed(&"pause", false, true):
		return
	if confirm_panel.visible:
		_hide_confirm()
	elif settings_menu.visible:
		settings_menu.call(&"_on_back_pressed")
	elif slots_panel.visible:
		show_main()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Telas ---------------------------------------------------------------------------

func show_main() -> void:
	refresh()
	slots_panel.visible = false
	confirm_panel.visible = false
	settings_menu.visible = false
	main_card.visible = true
	_focus_first([continue_button, new_game_button])


## Seletor de slots: "load" (Carregar), "new" (Novo jogo) ou "coop".
func show_slots(mode: String) -> void:
	slot_mode = mode
	slots_title.text = str(SLOT_TITLES.get(mode, ""))
	refresh_slots()
	main_card.visible = false
	confirm_panel.visible = false
	slots_panel.visible = true
	var preferred: int = _save().last_used_slot() if _save() != null else -1
	if preferred < 1:
		preferred = 1
	slot_buttons[preferred - 1].grab_focus()


func show_settings() -> void:
	main_card.visible = false
	settings_menu.refresh()
	settings_menu.visible = true
	settings_menu.focus_first()


## Continuar só aparece com um save válido; o foco vai para o primeiro botão visível.
func refresh() -> void:
	var save: SaveManager = _save()
	continue_button.visible = save != null and save.last_used_slot() > 0
	if continue_button.visible:
		var summary: Dictionary = save.get_slot_summary(save.last_used_slot())
		continue_button.tooltip_text = _slot_line(summary)
	_link_focus([continue_button, new_game_button, load_button, coop_button, settings_button, quit_button])


func refresh_slots() -> void:
	var save: SaveManager = _save()
	for i: int in SaveManager.SLOT_COUNT:
		var summary: Dictionary = save.get_slot_summary(i + 1) if save != null else {"exists": false}
		slot_buttons[i].text = "Slot %d   %s" % [i + 1, _slot_line(summary)]
		slot_delete_buttons[i].visible = bool(summary.get("exists", false))
	var focus_chain: Array = []
	for i: int in SaveManager.SLOT_COUNT:
		focus_chain.append(slot_buttons[i])
	focus_chain.append(slots_back_button)
	_link_focus(focus_chain)
	for i: int in SaveManager.SLOT_COUNT:
		var row_neighbor: NodePath = slot_delete_buttons[i].get_path() if slot_delete_buttons[i].visible else NodePath("")
		slot_buttons[i].focus_neighbor_right = row_neighbor
		slot_delete_buttons[i].focus_neighbor_left = slot_buttons[i].get_path()


## "Dia 12 • R$ 1.234 • Museu 14/52 • 15/10 00:46 ★", "Vazio" ou "Save ilegível".
static func _slot_line(summary: Dictionary) -> String:
	if not bool(summary.get("exists", false)):
		return "Vazio"
	if not bool(summary.get("valid", false)):
		return "Save ilegível"
	var line: String = "Dia %d  •  %s  •  Museu %d/%d" % [int(summary["day"]), UiFormat.money(int(summary["money"])),
		int(summary["museum_found"]), int(summary["museum_total"])]
	if int(summary.get("saved_at", 0)) > 0:
		line += "  •  " + _format_saved_at(int(summary["saved_at"]))
	if bool(summary.get("game_completed", false)):
		line += "  ★"
	return line


## Unix (UTC) -> "dd/mm hh:mm" no fuso do sistema.
static func _format_saved_at(unix_time: int) -> String:
	var bias_minutes: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time + bias_minutes * 60)
	return "%02d/%02d %02d:%02d" % [int(d["day"]), int(d["month"]), int(d["hour"]), int(d["minute"])]


# --- Ações ---------------------------------------------------------------------------

func _on_continue_pressed() -> void:
	var slot: int = _save().last_used_slot()
	if slot > 0:
		launch(slot, true, SessionManager.LAUNCH_SOLO)


func _on_slot_pressed(n: int) -> void:
	var occupied: bool = bool(_save().get_slot_summary(n).get("exists", false))
	match slot_mode:
		"new":
			if occupied:
				_ask(NEW_GAME_CONFIRM % n, launch.bind(n, false, SessionManager.LAUNCH_SOLO))
			else:
				launch(n, false, SessionManager.LAUNCH_SOLO)
		"coop":
			launch(n, occupied, SessionManager.LAUNCH_COOP)
		_:
			launch(n, occupied, SessionManager.LAUNCH_SOLO)


func _on_delete_pressed(n: int) -> void:
	_ask(DELETE_CONFIRM % n, _delete_slot.bind(n))


func _delete_slot(n: int) -> void:
	_save().delete_slot(n)
	show_slots(slot_mode)


## Ativa o slot, aplica (continuar ou jogo novo) e abre a base no modo pedido. Devolve o erro
## (sem trocar de cena) se o slot não pôde ser usado.
func launch(slot: int, continue_saved: bool, mode: String) -> Error:
	var save: SaveManager = _save()
	if save == null:
		return ERR_UNAVAILABLE
	var error: Error = save.select_slot(slot)
	if error == OK:
		error = save.continue_game() if continue_saved else save.start_new_game()
	# Save corrompido/de versão nova: o SaveManager já seguiu com jogo novo e avisa; a base abre.
	if error != OK and error != ERR_FILE_CORRUPT and error != ERR_FILE_UNRECOGNIZED:
		message_label.text = "Não foi possível usar o slot %d (erro %d)." % [slot, error]
		message_label.visible = true
		return error
	SessionManager.launch_mode = mode
	launched_scene = SessionManager.LOBBY_SCENE
	if scene_change_enabled and is_inside_tree():
		get_tree().change_scene_to_file(SessionManager.LOBBY_SCENE)
	return OK


func _ask(text: String, action: Callable) -> void:
	confirm_label.text = text
	_confirm_action = action
	slots_panel.visible = false
	main_card.visible = false
	confirm_panel.visible = true
	confirm_cancel_button.grab_focus()


func _on_confirm_ok() -> void:
	var action: Callable = _confirm_action
	_confirm_action = Callable()
	confirm_panel.visible = false
	if action.is_valid():
		action.call()


func _hide_confirm() -> void:
	_confirm_action = Callable()
	confirm_panel.visible = false
	show_slots(slot_mode)


func _save() -> SaveManager:
	return SaveManager.instance


# --- Montagem ------------------------------------------------------------------------

func _build() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)
	root_control = Control.new()
	root_control.name = "Root"
	root_control.theme = preload("res://ui/theme/scandig_theme.tres")
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root_control)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	center.add_child(stack)

	var title: Label = Label.new()
	title.name = "Logo"
	title.text = "ScanDig"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 72)
	title.add_theme_color_override(&"font_color", UiPalette.PAPER_LIGHT)
	title.add_theme_color_override(&"font_outline_color", UiPalette.WOOD_DARK)
	title.add_theme_constant_override(&"outline_size", 14)
	title.add_theme_color_override(&"font_shadow_color", UiPalette.SHADOW)
	title.add_theme_constant_override(&"shadow_offset_x", 3)
	title.add_theme_constant_override(&"shadow_offset_y", 5)
	stack.add_child(title)
	logo_label = title
	_animate_logo(title)

	# Faixa de madeira com a premissa, logo abaixo do logo.
	var ribbon: PanelContainer = PanelContainer.new()
	ribbon.name = "Tagline"
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ribbon_style: StyleBoxFlat = StyleBoxFlat.new()
	ribbon_style.bg_color = UiPalette.WOOD
	ribbon_style.border_color = UiPalette.INK
	ribbon_style.set_border_width_all(2)
	ribbon_style.set_corner_radius_all(6)
	ribbon_style.shadow_color = UiPalette.SHADOW
	ribbon_style.shadow_size = 2
	ribbon_style.shadow_offset = Vector2(2, 3)
	ribbon_style.content_margin_left = 16.0
	ribbon_style.content_margin_right = 16.0
	ribbon_style.content_margin_top = 4.0
	ribbon_style.content_margin_bottom = 4.0
	ribbon.add_theme_stylebox_override(&"panel", ribbon_style)
	tagline_label = Label.new()
	tagline_label.text = TAGLINE
	tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline_label.add_theme_font_size_override(&"font_size", 18)
	tagline_label.add_theme_color_override(&"font_color", UiPalette.PAPER_LIGHT)
	ribbon.add_child(tagline_label)
	stack.add_child(ribbon)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	continue_button = _button("Continuar", &"PrimaryButton", "play")
	new_game_button = _button("Novo jogo", &"", "new")
	load_button = _button("Carregar", &"", "load")
	coop_button = _button("Multiplayer", &"", "multiplayer")
	settings_button = _button("Configurações", &"", "gear")
	quit_button = _button("Sair", &"DangerButton", "door")
	for button: Button in [continue_button, new_game_button, load_button, coop_button, settings_button, quit_button]:
		box.add_child(button)
	main_card = _card(box)
	main_card.name = "MainCard"
	stack.add_child(main_card)

	# Seletor de slots
	var slots_box: VBoxContainer = VBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 10)
	slots_title = Label.new()
	slots_title.theme_type_variation = &"TitleLabel"
	slots_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slots_box.add_child(slots_title)
	for i: int in SaveManager.SLOT_COUNT:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var slot_button: Button = _button("Slot %d" % (i + 1))
		slot_button.custom_minimum_size = Vector2(520, 52)
		slot_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.pressed.connect(_on_slot_pressed.bind(i + 1))
		var delete_button: Button = _button("Apagar", &"DangerButton")
		delete_button.custom_minimum_size = Vector2(110, 52)
		delete_button.pressed.connect(_on_delete_pressed.bind(i + 1))
		row.add_child(slot_button)
		row.add_child(delete_button)
		slots_box.add_child(row)
		slot_buttons.append(slot_button)
		slot_delete_buttons.append(delete_button)
	slots_back_button = _button("Voltar")
	slots_back_button.pressed.connect(show_main)
	slots_box.add_child(slots_back_button)
	slots_panel = _card(slots_box)
	slots_panel.name = "SlotsPanel"
	stack.add_child(slots_panel)

	# Confirmação (apagar / jogo novo por cima de um save)
	var confirm_box: VBoxContainer = VBoxContainer.new()
	confirm_box.add_theme_constant_override("separation", 12)
	confirm_label = Label.new()
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_box.add_child(confirm_label)
	var confirm_row: HBoxContainer = HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 12)
	confirm_cancel_button = _button("Cancelar")
	confirm_ok_button = _button("Confirmar", &"DangerButton")
	for button: Button in [confirm_cancel_button, confirm_ok_button]:
		button.custom_minimum_size = Vector2(200, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		confirm_row.add_child(button)
	confirm_box.add_child(confirm_row)
	confirm_panel = _card(confirm_box)
	confirm_panel.name = "ConfirmPanel"
	stack.add_child(confirm_panel)
	confirm_cancel_button.pressed.connect(_hide_confirm)
	confirm_ok_button.pressed.connect(_on_confirm_ok)
	confirm_cancel_button.focus_neighbor_right = confirm_ok_button.get_path()
	confirm_ok_button.focus_neighbor_left = confirm_cancel_button.get_path()

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override(&"font_color", UiPalette.RED_BURNT)
	message_label.visible = false
	stack.add_child(message_label)

	settings_menu = SettingsMenu.new()
	settings_menu.visible = false
	stack.add_child(settings_menu)

	version_label = Label.new()
	version_label.name = "Version"
	version_label.text = "v" + game_version()
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.add_theme_font_size_override(&"font_size", 14)
	version_label.add_theme_color_override(&"font_color", UiPalette.PAPER_LIGHT)
	version_label.add_theme_color_override(&"font_outline_color", UiPalette.WOOD_DARK)
	version_label.add_theme_constant_override(&"outline_size", 6)
	version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version_label.offset_right = -14.0
	version_label.offset_bottom = -10.0
	root_control.add_child(version_label)
	settings_menu.closed.connect(show_main)

	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(show_slots.bind("new"))
	load_button.pressed.connect(show_slots.bind("load"))
	coop_button.pressed.connect(show_slots.bind("coop"))
	settings_button.pressed.connect(show_settings)
	quit_button.pressed.connect(func() -> void: get_tree().quit())


func _button(text: String, variation: StringName = &"", icon_name: String = "") -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 48)
	# Teclado/controle: os botões recebem foco (diferente do menu de pausa).
	button.focus_mode = Control.FOCUS_ALL
	if not variation.is_empty():
		button.theme_type_variation = variation
	if not icon_name.is_empty():
		button.icon = UiIcons.get_icon(icon_name, 48)
		button.expand_icon = false
		button.add_theme_constant_override(&"icon_max_width", 24)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_add_focus_scale(button)
	return button


## Hover e foco (mouse, teclado ou controle) crescem o botão um pouco; o contorno de foco do
## tema continua lá.
func _add_focus_scale(button: Button) -> void:
	var grow: Callable = func(on: bool) -> void:
		button.pivot_offset = button.size * 0.5
		var target: Vector2 = Vector2.ONE * (BUTTON_FOCUS_SCALE if on else 1.0)
		if not button.is_inside_tree():
			button.scale = target
			return
		var tween: Tween = button.create_tween()
		tween.tween_property(button, "scale", target, 0.08)
	button.mouse_entered.connect(grow.bind(true))
	button.focus_entered.connect(grow.bind(true))
	button.mouse_exited.connect(func() -> void: grow.call(button.has_focus()))
	button.focus_exited.connect(grow.bind(false))


## Balanço lento do logo (rotação em volta do centro), em loop.
func _animate_logo(logo: Label) -> void:
	logo.resized.connect(func() -> void: logo.pivot_offset = logo.size * 0.5)
	var tween: Tween = logo.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(logo, "rotation", deg_to_rad(LOGO_SWAY_DEG), LOGO_SWAY_SECONDS)
	tween.tween_property(logo, "rotation", deg_to_rad(-LOGO_SWAY_DEG), LOGO_SWAY_SECONDS)


## "0.1.0" de application/config/version (o mesmo do .exe).
static func game_version() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	return version if not version.is_empty() else DEFAULT_VERSION


func _card(child: Control) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"WornPanel"
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_child(child)
	panel.add_child(margin)
	return panel


## Encadeia o foco vertical (cima/baixo) só entre os visíveis, em anel.
func _link_focus(controls: Array) -> void:
	var visible_controls: Array[Control] = []
	for c: Variant in controls:
		var control: Control = c as Control
		if control != null and control.visible:
			visible_controls.append(control)
	var count: int = visible_controls.size()
	for i: int in count:
		var control: Control = visible_controls[i]
		control.focus_neighbor_top = visible_controls[(i - 1 + count) % count].get_path()
		control.focus_neighbor_bottom = visible_controls[(i + 1) % count].get_path()
		control.focus_previous = control.focus_neighbor_top
		control.focus_next = control.focus_neighbor_bottom


func _focus_first(candidates: Array) -> void:
	for c: Variant in candidates:
		var control: Control = c as Control
		if control != null and control.visible and control.is_inside_tree():
			control.grab_focus()
			return
