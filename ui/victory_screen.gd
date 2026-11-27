class_name VictoryScreen
extends CanvasLayer

## Tela "Jogo concluído" (#81). Abre só na vitória ao vivo (GameState.game_victory: o chefe final
## GameState.FINAL_BOSS_ID vencido nesta sessão). Carregar um
## save concluído, entrar no meio ou reconectar não abre.
## Mostra Peças do museu, Peças intactas (#93), Segredos e Diário, ao
## lado as estatísticas da campanha (#141: GameState.stats, tempo de jogo e conquistas) e tem
## os botões "Continuar explorando" e "Créditos" (o mesmo
## cartão troca para a CreditsView, com os sons CC0 #149; "Voltar" ou Esc volta às contagens). Enquanto está aberta,
## o player não se mexe (is_settings_open) e o menu de pausa não abre. Fecha na troca de cena.
## Autoload CoreVictoryScreen, camada 46: acima da pausa (45), abaixo da SessionUI (50) para o
## carregamento cobrir.

signal open_changed(open: bool)

const TITLE_TEXT: String = "Jogo concluído"
const SUBTITLE_TEXT: String = "O Guardião do Sinal foi vencido na Lua.\nA expedição chegou ao destino do sinal.\nAinda há peças, segredos e bichos por achar."
## Linhas "Campanha" (#141): chave -> rótulo. Chaves de Achievements.STAT_KEYS vêm do
## GameState.stats; "play_time" é o tempo do save (só o host sabe) e "achievements" a contagem.
const CAMPAIGN_ROWS: Array[Array] = [
	["expeditions", "Expedições"], ["items_found", "Peças desenterradas"],
	["items_sold", "Peças vendidas"], ["items_donated", "Peças doadas"],
	["money_earned", "Dinheiro ganho"], ["creatures_defeated", "Criaturas derrotadas"],
	["digs", "Pazadas"], ["dig_depth_cm", "Profundidade escavada"],
	["play_time", "Tempo de jogo"], ["achievements", "Conquistas"],
]

static var instance: VictoryScreen = null

var root_control: Control = null
var card: PanelContainer = null
var items_value: Label = null
var intact_value: Label = null
var secrets_value: Label = null
var creatures_value: Label = null
## Estatísticas da campanha (#141): chave de CAMPAIGN_ROWS -> Label do valor.
var campaign_values: Dictionary = {}
var continue_button: Button = null
var credits_button: Button = null
var credits_back_button: Button = null
## Vistas do mesmo cartão: contagens (padrão ao abrir) e créditos.
var summary_view: Control = null
var credits_view: CreditsView = null
## Foco antes de abrir (#135), devolvido ao fechar.
var _focus_before: Control = null
var credits_label: Label = null
var _trophy_icon: TextureRect = null
var _collection_card: PanelContainer = null
var _collection_bar: ProgressBar = null
var _collection_pct_label: Label = null
var _campaign_card: PanelContainer = null
var _actions_row: HBoxContainer = null

var _open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _game_state: GameState = null
var _fit_center: FitCenterContainer = null


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
	# The previous modal returns mouse/focus before this screen captures ownership.
	get_tree().call_group(&"world_upgrade_shops", &"close")
	refresh()
	show_summary()
	_open = true
	root_control.visible = true
	var dim: CanvasItem = root_control.get_node_or_null(^"Dim") as CanvasItem
	if dim != null:
		UiMotion.fade_backdrop(dim, true)
	UiMotion.pop_in(card, true, 0.94, 0.20)
	UiMotion.pop_in(_collection_card, true, 0.96, 0.18, 0.04)
	UiMotion.pop_in(_campaign_card, true, 0.96, 0.18, 0.08)
	UiMotion.pop_in(_actions_row, true, 0.97, 0.17, 0.11)
	if _trophy_icon != null:
		UiMotion.breathe_emblem(_trophy_icon, 1.07, 2.8, 1.2, true)
	if SessionUI.instance != null:
		SessionUI.instance._place_toast()
	UiFocus.link_chain([continue_button, credits_button])
	UiFocus.link_row([continue_button, credits_button])
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
	for item: Control in [card, _collection_card, _campaign_card, _actions_row]:
		if item != null:
			UiMotion.stop(item)
	if _trophy_icon != null:
		UiMotion.stop(_trophy_icon, true)
	root_control.visible = false
	_fit_center.offset_top = 0.0
	Input.mouse_mode = _previous_mouse_mode
	if SessionUI.instance != null and SessionUI.instance.expedition_bar != null:
		SessionUI.instance.call(&"_refresh_expedition_bar")
		SessionUI.instance._place_toast()
	# O foco volta aonde estava (#135); sem ele (vitória na expedição e volta ao lobby), à Base.
	var before: Control = _focus_before
	_focus_before = null
	if is_instance_valid(before) and before.is_visible_in_tree():
		before.grab_focus()
	elif is_inside_tree():
		get_tree().call_group(UiFocus.HOME_GROUP, &"focus_home")
	open_changed.emit(false)


## Faixa medida do aviso, mantida também nos créditos e após sua expiração.
## Encolhe só este cartão; não altera o layout compartilhado de outros modais.
func reserve_notice_space(height: float) -> void:
	if _fit_center != null:
		_fit_center.offset_top = height


func show_credits() -> void:
	summary_view.visible = false
	credits_view.visible = true
	UiMotion.switch_tab_page(credits_view, true)
	credits_view.focus_start()


func show_summary() -> void:
	credits_view.visible = false
	summary_view.visible = true
	if _open:
		UiMotion.switch_tab_page(summary_view, true)
	if credits_button.is_visible_in_tree():
		credits_button.grab_focus()


## Contagens do GameState na hora em que abre.
func refresh() -> void:
	var gs: GameState = GameState.instance
	if gs == null:
		return
	var total_items: int = gs.get_total_catalog_items()
	var found_items: int = gs.discovered_items.size()
	items_value.text = "%d / %d" % [found_items, total_items]
	items_value.add_theme_color_override(&"font_color", UiPalette.GREEN_BOTTLE if total_items > 0 and found_items >= total_items else UiPalette.WOOD_DARK)
	var intact: Variant = gs.get(&"intact_items")
	var intact_count: int = (intact as Array).size() if intact is Array else 0
	intact_value.text = "%d / %d" % [intact_count, total_items]
	intact_value.add_theme_color_override(&"font_color", UiPalette.GREEN_BOTTLE if total_items > 0 and intact_count >= total_items else UiPalette.WOOD_DARK)
	var found_secrets: int = gs.found_secrets.size()
	var total_secrets: int = GameState.SECRETS.size()
	secrets_value.text = "%d / %d" % [found_secrets, total_secrets]
	secrets_value.add_theme_color_override(&"font_color", UiPalette.GREEN_BOTTLE if total_secrets > 0 and found_secrets >= total_secrets else UiPalette.WOOD_DARK)
	var seen_creatures: int = gs.seen_creatures.size()
	var total_creatures: int = GameState.CREATURES.size()
	creatures_value.text = "%d / %d" % [seen_creatures, total_creatures]
	creatures_value.add_theme_color_override(&"font_color", UiPalette.GREEN_BOTTLE if total_creatures > 0 and seen_creatures >= total_creatures else UiPalette.WOOD_DARK)
	var sum_done: int = found_items + intact_count + found_secrets + seen_creatures
	var sum_total: int = maxi(total_items * 2 + total_secrets + total_creatures, 1)
	if _collection_bar != null:
		_collection_bar.max_value = sum_total
		_collection_bar.value = clampi(sum_done, 0, sum_total)
		var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
		bar_fill.bg_color = UiPalette.GREEN_BOTTLE if sum_done >= sum_total else UiPalette.ORANGE
		bar_fill.border_color = UiPalette.INK
		bar_fill.set_border_width_all(1)
		bar_fill.set_corner_radius_all(3)
		_collection_bar.add_theme_stylebox_override(&"fill", bar_fill)
	if _collection_pct_label != null:
		var pct: int = roundi(100.0 * float(sum_done) / float(sum_total))
		_collection_pct_label.text = "%d%%" % clampi(pct, 0, 100)
		_collection_pct_label.add_theme_color_override(&"font_color", UiPalette.GREEN_BOTTLE if sum_done >= sum_total else UiPalette.WOOD_DARK)
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
	_fit_center = center
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	UiFocus.follow_pointer(center)

	card = PanelContainer.new()
	card.name = "VictoryCard"
	card.theme_type_variation = &"WornPanel"
	card.custom_minimum_size = Vector2(720, 0)
	center.add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	card.add_child(margin)
	var views: VBoxContainer = VBoxContainer.new()
	margin.add_child(views)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	summary_view = box
	summary_view.name = "SummaryView"
	views.add_child(box)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 10)
	var trophy_icon: TextureRect = TextureRect.new()
	_trophy_icon = trophy_icon
	trophy_icon.texture = UiIcons.get_icon("trophy", 30)
	trophy_icon.custom_minimum_size = Vector2(30, 30)
	trophy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title: Label = Label.new()
	title.text = TITLE_TEXT
	title.theme_type_variation = &"TitleLabel"
	title_row.add_child(trophy_icon)
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
	columns.add_theme_constant_override("separation", 14)
	box.add_child(columns)
	var grid: GridContainer = _stats_column(columns, "Coleção", 2, "museum")
	_collection_card = grid.get_parent().get_parent() as PanelContainer
	items_value = _count_row(grid, "Peças do museu")
	intact_value = _count_row(grid, "Peças intactas")
	secrets_value = _count_row(grid, "Segredos")
	creatures_value = _count_row(grid, "Diário de campo")
	var col_vbox: VBoxContainer = grid.get_parent() as VBoxContainer
	if col_vbox != null:
		var prog_row: HBoxContainer = HBoxContainer.new()
		prog_row.add_theme_constant_override("separation", 8)
		prog_row.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
		_collection_bar = ProgressBar.new()
		_collection_bar.show_percentage = false
		_collection_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_collection_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_collection_bar.custom_minimum_size = Vector2(120, 10)
		_collection_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_collection_bar.focus_mode = Control.FOCUS_NONE
		var bar_track: StyleBoxFlat = StyleBoxFlat.new()
		bar_track.bg_color = UiPalette.PAPER_DARK
		bar_track.border_color = UiPalette.INK
		bar_track.set_border_width_all(1)
		bar_track.set_corner_radius_all(3)
		_collection_bar.add_theme_stylebox_override(&"background", bar_track)
		prog_row.add_child(_collection_bar)
		_collection_pct_label = Label.new()
		_collection_pct_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_collection_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_collection_pct_label.custom_minimum_size = Vector2(44, 0)
		prog_row.add_child(_collection_pct_label)
		col_vbox.add_child(prog_row)
	# Duas colunas de pares (rótulo, valor): a mesma altura das contagens ao lado.
	var campaign: GridContainer = _stats_column(columns, "Campanha", 4, "compass")
	_campaign_card = campaign.get_parent().get_parent() as PanelContainer
	campaign.name = "CampaignGrid"
	for row: Array in CAMPAIGN_ROWS:
		campaign_values[row[0]] = _count_row(campaign, str(row[1]))

	var actions_row: HBoxContainer = HBoxContainer.new()
	_actions_row = actions_row
	actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_row.add_theme_constant_override("separation", 12)
	box.add_child(actions_row)

	continue_button = Button.new()
	continue_button.text = "Continuar explorando"
	continue_button.theme_type_variation = &"PrimaryButton"
	continue_button.icon = UiIcons.get_icon("play", 20)
	continue_button.custom_minimum_size = Vector2(280, 46)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.focus_mode = Control.FOCUS_ALL
	continue_button.pressed.connect(close)
	UiMotion.attach_button(continue_button)
	actions_row.add_child(continue_button)
	credits_button = Button.new()
	credits_button.text = "Créditos"
	credits_button.icon = UiIcons.get_icon("heart", 20)
	credits_button.custom_minimum_size = Vector2(200, 46)
	credits_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	credits_button.focus_mode = Control.FOCUS_ALL
	credits_button.pressed.connect(show_credits)
	UiMotion.attach_button(credits_button)
	actions_row.add_child(credits_button)

	credits_view = _build_credits()
	credits_view.name = "CreditsView"
	credits_view.visible = false
	views.add_child(credits_view)


func _build_credits() -> CreditsView:
	var view: CreditsView = CreditsView.new()
	credits_label = view.team_label
	credits_back_button = view.back_button
	view.back_pressed.connect(show_summary)
	return view


## Coluna em cartão InsetPanel com subtítulo e grade (columns = 2 × pares rótulo/valor).
func _stats_column(parent: Control, title_text: String, grid_columns: int, icon_name: String = "") -> GridContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"InsetPanel"
	parent.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_theme_constant_override("separation", 6)
	if not icon_name.is_empty():
		var col_icon: TextureRect = TextureRect.new()
		col_icon.texture = UiIcons.get_icon(icon_name, 18)
		col_icon.custom_minimum_size = Vector2(18, 18)
		col_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		col_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		col_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_row.add_child(col_icon)
	var title: Label = Label.new()
	title.text = title_text
	title.theme_type_variation = &"SubtitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", UiPalette.WOOD_DARK)
	header_row.add_child(title)
	column.add_child(header_row)
	column.add_child(HSeparator.new())
	var grid: GridContainer = GridContainer.new()
	grid.columns = grid_columns
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
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
