class_name VictoryScreen
extends CanvasLayer

## Tela "Jogo concluído" (#81). Abre só na vitória ao vivo (GameState.game_victory: o chefe final
## GameState.FINAL_BOSS_ID, o Colosso do Tesouro da Ilha, vencido nesta sessão; #115). Carregar um
## save concluído, entrar no meio ou reconectar não abre.
## Mostra Peças do museu, Peças intactas (#93), Fragmentos do mapa (#115), Segredos e Diário, ao
## lado as estatísticas da campanha (#141: GameState.stats, tempo de jogo e conquistas) e tem
## os botões "Continuar explorando" e "Créditos" (o mesmo
## cartão troca para os créditos; "Voltar" ou Esc volta às contagens). Enquanto está aberta,
## o player não se mexe (is_settings_open) e o menu de pausa não abre. Fecha na troca de cena.
## Autoload CoreVictoryScreen, camada 46: acima da pausa (45), abaixo da SessionUI (50) para o
## carregamento cobrir.

signal open_changed(open: bool)

const TITLE_TEXT: String = "Jogo concluído"
const SUBTITLE_TEXT: String = "O Colosso do Tesouro foi vencido e o mapa do tesouro está completo.\nLeve o Ídolo de Ouro, o tesouro principal, ao Museu.\nAinda há peças, segredos e bichos por achar."
## Linhas "Campanha" (#141): chave -> rótulo. Chaves de Achievements.STAT_KEYS vêm do
## GameState.stats; "play_time" é o tempo do save (só o host sabe) e "achievements" a contagem.
const CAMPAIGN_ROWS: Array[Array] = [
	["expeditions", "Expedições"], ["items_found", "Peças desenterradas"],
	["items_sold", "Peças vendidas"], ["items_donated", "Peças doadas"],
	["money_earned", "Dinheiro ganho"], ["creatures_defeated", "Criaturas derrotadas"],
	["digs", "Pazadas"], ["dig_depth_cm", "Profundidade escavada"],
	["play_time", "Tempo de jogo"], ["achievements", "Conquistas"],
]
const CREDITS_TITLE: String = "— CRÉDITOS —"
## Fonte única dos créditos (veio do overlay do gameplay/environment/crater_altar.gd).
const CREDITS_TEXT: String = "Maestro / Lead_Gameplay (Antigravity #2) — Coordenação e Arquitetura Geral\nBroca (Dev_Player) — Controle em 1ª Pessoa, Ferramentas, Terrenos e Segredos\nSonda (Dev_Enemies) — Inteligência Artificial, Inimigos e Chefes\nDev B — Sistemas Core, Interface, HUD e Multiplayer Cooperativo\nFelipe — Concepção, Arte Low-Poly Toon e Direção Criativa"

static var instance: VictoryScreen = null

var root_control: Control = null
var card: PanelContainer = null
var items_value: Label = null
var intact_value: Label = null
var fragments_value: Label = null
var secrets_value: Label = null
var creatures_value: Label = null
## Estatísticas da campanha (#141): chave de CAMPAIGN_ROWS -> Label do valor.
var campaign_values: Dictionary = {}
var continue_button: Button = null
var credits_button: Button = null
var credits_back_button: Button = null
## Vistas do mesmo cartão: contagens (padrão ao abrir) e créditos.
var summary_view: Control = null
var credits_view: Control = null
## Foco antes de abrir (#135), devolvido ao fechar.
var _focus_before: Control = null
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
	if not _open or not (event.is_action_pressed(&"pause", false, true) or event.is_action_pressed(&"ui_cancel", false, true)):
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
	UiFocus.link_chain([continue_button, credits_button])
	var before: Control = get_viewport().gui_get_focus_owner()
	if before != null and not root_control.is_ancestor_of(before):
		_focus_before = before
	continue_button.grab_focus()
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
	# O foco volta aonde estava (#135); sem ele (vitória na expedição e volta ao lobby), à Base.
	var before: Control = _focus_before
	_focus_before = null
	if is_instance_valid(before) and before.is_visible_in_tree():
		before.grab_focus()
	elif is_inside_tree():
		get_tree().call_group(UiFocus.HOME_GROUP, &"focus_home")
	open_changed.emit(false)


func show_credits() -> void:
	summary_view.visible = false
	credits_view.visible = true
	if credits_back_button.is_visible_in_tree():
		credits_back_button.grab_focus()


func show_summary() -> void:
	credits_view.visible = false
	summary_view.visible = true
	if credits_button.is_visible_in_tree():
		credits_button.grab_focus()


## Contagens do GameState na hora em que abre.
func refresh() -> void:
	var gs: GameState = GameState.instance
	if gs == null:
		return
	items_value.text = "%d / %d" % [gs.discovered_items.size(), gs.get_total_catalog_items()]
	var intact: Variant = gs.get(&"intact_items")
	intact_value.text = "%d / %d" % [(intact as Array).size() if intact is Array else 0, gs.get_total_catalog_items()]
	fragments_value.text = "%d / %d" % [gs.map_fragments.size(), GameState.MAP_FRAGMENT_IDS.size()]
	secrets_value.text = "%d / %d" % [gs.found_secrets.size(), GameState.SECRETS.size()]
	creatures_value.text = "%d / %d" % [gs.seen_creatures.size(), GameState.CREATURES.size()]
	for row: Array in CAMPAIGN_ROWS:
		(campaign_values[row[0]] as Label).text = campaign_value_text(gs, str(row[0]))


## Valor de uma linha "Campanha" como aparece na tela.
static func campaign_value_text(gs: GameState, key: String) -> String:
	match key:
		"money_earned":
			return UiFormat.money(gs.get_stat(key))
		"dig_depth_cm":
			return "%s m" % UiFormat.thousands(int(gs.get_stat(key) / 100.0))
		"play_time":
			var save: SaveManager = SaveManager.instance
			return UiFormat.play_time(int(save.play_time_s)) if save != null and gs.is_authority() else "—"
		"achievements":
			var total: int = Achievements.ids().size()
			var done: int = 0
			for id: String in gs.achievements:
				if Achievements.ids().has(id):
					done += 1
			return "%d / %d" % [done, total]
	return UiFormat.thousands(gs.get_stat(key))


# --- Montagem ------------------------------------------------------------------

func _build() -> void:
	# Encolhe para caber em telas baixas com ui_scale 1.3 (#146).
	var center: FitCenterContainer = FitCenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)

	card = PanelContainer.new()
	card.name = "VictoryCard"
	card.theme_type_variation = &"WornPanel"
	card.custom_minimum_size = Vector2(720, 0)
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
	summary_view.name = "SummaryView"
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

	var columns: HBoxContainer = HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 22)
	box.add_child(columns)
	var grid: GridContainer = _stats_column(columns, "Coleção", 2)
	items_value = _count_row(grid, "Peças do museu")
	intact_value = _count_row(grid, "Peças intactas")
	fragments_value = _count_row(grid, "Fragmentos do mapa")
	secrets_value = _count_row(grid, "Segredos")
	creatures_value = _count_row(grid, "Diário de campo")
	columns.add_child(VSeparator.new())
	# Duas colunas de pares (rótulo, valor): a mesma altura das contagens ao lado.
	var campaign: GridContainer = _stats_column(columns, "Campanha", 4)
	campaign.name = "CampaignGrid"
	for row: Array in CAMPAIGN_ROWS:
		campaign_values[row[0]] = _count_row(campaign, str(row[1]))

	continue_button = Button.new()
	continue_button.text = "Continuar explorando"
	continue_button.theme_type_variation = &"PrimaryButton"
	continue_button.custom_minimum_size = Vector2(320, 48)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.focus_mode = Control.FOCUS_ALL
	continue_button.pressed.connect(close)
	box.add_child(continue_button)
	credits_button = Button.new()
	credits_button.text = "Créditos"
	credits_button.custom_minimum_size = Vector2(320, 44)
	credits_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	credits_button.focus_mode = Control.FOCUS_ALL
	credits_button.pressed.connect(show_credits)
	box.add_child(credits_button)

	credits_view = _build_credits()
	credits_view.name = "CreditsView"
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
	credits_back_button.focus_mode = Control.FOCUS_ALL
	credits_back_button.pressed.connect(show_summary)
	box.add_child(credits_back_button)
	return box


## Coluna com título e grade (columns = 2 × pares rótulo/valor).
func _stats_column(parent: Control, title_text: String, grid_columns: int) -> GridContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	var title: Label = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", UiPalette.WOOD)
	column.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = grid_columns
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	return grid


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
