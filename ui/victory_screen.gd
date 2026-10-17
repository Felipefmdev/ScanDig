class_name VictoryScreen
extends CanvasLayer

## Tela "Jogo concluído" (#81). Abre só na vitória ao vivo (GameState.game_victory: the_sleeper
## vencido nesta sessão). Carregar um save concluído, entrar no meio ou reconectar não abre.
## Mostra Peças do museu, Peças intactas (#93), Segredos e Diário e tem os botões "Continuar explorando" e "Créditos" (o mesmo
## cartão troca para os créditos; "Voltar" ou Esc volta às contagens). Enquanto está aberta,
## o player não se mexe (is_settings_open) e o menu de pausa não abre. Fecha na troca de cena.
## Autoload CoreVictoryScreen, camada 46: acima da pausa (45), abaixo da SessionUI (50) para o
## carregamento cobrir.

signal open_changed(open: bool)

const TITLE_TEXT: String = "Jogo concluído"
const SUBTITLE_TEXT: String = "O Que Dorme foi vencido. O museu continua aberto:\nainda há peças, segredos e bichos por achar."
const CREDITS_TITLE: String = "— CRÉDITOS —"
## Fonte única dos créditos (veio do overlay do gameplay/environment/crater_altar.gd).
const CREDITS_TEXT: String = "Maestro / Lead_Gameplay (Antigravity #2) — Coordenação e Arquitetura Geral\nBroca (Dev_Player) — Controlo 1ª Pessoa, Ferramentas, Terrenos e Segredos\nSonda (Dev_Enemies) — Inteligência Artificial, Inimigos e Chefes\nDev B — Sistemas Core, Interface, HUD e Multiplayer Cooperativo\nFelipe — Concepção, Arte Low-Poly Toon e Direção Criativa"

static var instance: VictoryScreen = null

var root_control: Control = null
var card: PanelContainer = null
var items_value: Label = null
var intact_value: Label = null
var secrets_value: Label = null
var creatures_value: Label = null
var continue_button: Button = null
var credits_button: Button = null
var credits_back_button: Button = null
## Vistas do mesmo cartão: contagens (padrão ao abrir) e créditos.
var summary_view: Control = null
var credits_view: Control = null
var credits_label: Label = null

var _open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _game_state: GameState = null


static func is_open() -> bool:
	return instance != null and instance._open


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control = get_node_or_null(^"Root") as Control
	if root_control == null:
		push_warning("VictoryScreen: nó Root ausente; tela desativada.")
		set_process(false)
		return
	_build()
	root_control.visible = false
	if SessionManager.instance != null:
		SessionManager.instance.scene_changing.connect(func(_target: String) -> void: close())
	_connect_game_state()


## O GameState pode surgir depois (testes, ordem dos autoloads): tenta a cada frame até achar.
func _process(_delta: float) -> void:
	_connect_game_state()


func _connect_game_state() -> void:
	var gs: GameState = GameState.instance
	if gs == null or gs == _game_state:
		set_process(gs == null)
		return
	_game_state = gs
	gs.game_victory.connect(open)
	gs.state_synced.connect(_on_state_synced)
	set_process(false)


## Jogo zerado (reset ou outro save): a vitória não vale mais. Pelo state_synced porque o
## reset_state zera game_completed antes do snapshot (sem game_completed_changed).
func _on_state_synced() -> void:
	if _open and _game_state != null and not _game_state.is_game_completed():
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event.is_action_pressed(&"pause", false, true):
		return
	if credits_view.visible:
		show_summary()
	else:
		close()
	get_viewport().set_input_as_handled()


# --- Abrir / fechar ------------------------------------------------------------

func open() -> void:
	if _open or root_control == null:
		return
	# Em coop o menu de pausa pode estar aberto quando o chefe cai: fecha antes (devolve o mouse).
	if PauseMenu.instance != null and PauseMenu.is_open():
		PauseMenu.instance.close()
	refresh()
	show_summary()
	_open = true
	root_control.visible = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# O cartão da expedição (SessionUI, camada 50) ficaria por cima do escurecimento e clicável.
	if SessionUI.instance != null and SessionUI.instance.expedition_bar != null:
		SessionUI.instance.expedition_bar.visible = false
	open_changed.emit(true)


func close() -> void:
	if not _open:
		return
	_open = false
	root_control.visible = false
	Input.mouse_mode = _previous_mouse_mode
	if SessionUI.instance != null and SessionUI.instance.expedition_bar != null:
		SessionUI.instance.call(&"_refresh_expedition_bar")
	open_changed.emit(false)


func show_credits() -> void:
	summary_view.visible = false
	credits_view.visible = true


func show_summary() -> void:
	credits_view.visible = false
	summary_view.visible = true


## Contagens do GameState na hora em que abre.
func refresh() -> void:
	var gs: GameState = GameState.instance
	if gs == null:
		return
	items_value.text = "%d / %d" % [gs.discovered_items.size(), gs.get_total_catalog_items()]
	var intact: Variant = gs.get(&"intact_items")
	intact_value.text = "%d / %d" % [(intact as Array).size() if intact is Array else 0, gs.get_total_catalog_items()]
	secrets_value.text = "%d / %d" % [gs.found_secrets.size(), GameState.SECRETS.size()]
	creatures_value.text = "%d / %d" % [gs.seen_creatures.size(), GameState.CREATURES.size()]


# --- Montagem ------------------------------------------------------------------

func _build() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)

	card = PanelContainer.new()
	card.name = "VictoryCard"
	card.theme_type_variation = &"WornPanel"
	card.custom_minimum_size = Vector2(460, 0)
	center.add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	card.add_child(margin)
	var views: VBoxContainer = VBoxContainer.new()
	margin.add_child(views)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	summary_view = box
	views.add_child(box)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 10)
	var star: Label = Label.new()
	star.text = "★"
	star.theme_type_variation = &"TitleLabel"
	star.add_theme_color_override(&"font_color", UiPalette.GOLD)
	star.add_theme_color_override(&"font_outline_color", UiPalette.WOOD_DARK)
	star.add_theme_constant_override(&"outline_size", 4)
	var title: Label = Label.new()
	title.text = TITLE_TEXT
	title.theme_type_variation = &"TitleLabel"
	title_row.add_child(star)
	title_row.add_child(title)
	box.add_child(title_row)

	var subtitle: Label = Label.new()
	subtitle.text = SUBTITLE_TEXT
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override(&"font_color", UiPalette.WOOD)
	box.add_child(subtitle)
	box.add_child(HSeparator.new())

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	items_value = _count_row(grid, "Peças do museu")
	intact_value = _count_row(grid, "Peças intactas")
	secrets_value = _count_row(grid, "Segredos")
	creatures_value = _count_row(grid, "Diário de campo")
	box.add_child(grid)

	continue_button = Button.new()
	continue_button.text = "Continuar explorando"
	continue_button.theme_type_variation = &"PrimaryButton"
	continue_button.custom_minimum_size = Vector2(320, 48)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.pressed.connect(close)
	box.add_child(continue_button)
	credits_button = Button.new()
	credits_button.text = "Créditos"
	credits_button.custom_minimum_size = Vector2(320, 44)
	credits_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	credits_button.focus_mode = Control.FOCUS_NONE
	credits_button.pressed.connect(show_credits)
	box.add_child(credits_button)

	credits_view = _build_credits()
	credits_view.visible = false
	views.add_child(credits_view)


func _build_credits() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var title: Label = Label.new()
	title.text = CREDITS_TITLE
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", UiPalette.WOOD_DARK)
	box.add_child(title)
	box.add_child(HSeparator.new())
	credits_label = Label.new()
	credits_label.text = CREDITS_TEXT
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.add_theme_color_override(&"font_color", UiPalette.INK)
	credits_label.add_theme_constant_override(&"line_spacing", 6)
	box.add_child(credits_label)
	box.add_child(HSeparator.new())
	credits_back_button = Button.new()
	credits_back_button.text = "Voltar"
	credits_back_button.theme_type_variation = &"PrimaryButton"
	credits_back_button.custom_minimum_size = Vector2(320, 48)
	credits_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	credits_back_button.focus_mode = Control.FOCUS_NONE
	credits_back_button.pressed.connect(show_summary)
	box.add_child(credits_back_button)
	return box


func _count_row(grid: GridContainer, text: String) -> Label:
	var name_label: Label = Label.new()
	name_label.text = text
	grid.add_child(name_label)
	var value: Label = Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(90, 0)
	value.add_theme_color_override(&"font_color", UiPalette.WOOD_DARK)
	grid.add_child(value)
	return value
