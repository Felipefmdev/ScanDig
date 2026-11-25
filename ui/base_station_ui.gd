class_name BaseStationUI
extends Control

## Painel da Base/Tenda: Museu e revisitas. Comércio acontece nas bancas dos mapas.

@onready var tab_container: TabContainer = _resolve_node("TabContainer", "PanelContainer/MarginContainer/VBoxContainer/TabContainer") as TabContainer

# Loja
@onready var buy_detector_btn: Button = _resolve_node("BuyDetectorButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/BuyDetectorButton") as Button
@onready var buy_pinpointer_btn: Button = _resolve_node("BuyPinpointerButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/BuyPinpointerButton") as Button
@onready var buy_shovel_btn: Button = _resolve_node("BuyShovelButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/BuyShovelButton") as Button
@onready var buy_backpack_btn: Button = _resolve_node("BuyBackpackButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/BuyBackpackButton") as Button
@onready var shop_feedback_label: Label = _resolve_node("ShopFeedbackLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/ShopFeedbackLabel") as Label

enum MuseumFilter { ALL, DISCOVERED, PENDING }

const CATALOG_SORT_ACCENTS: Dictionary = {
	"á": "a", "à": "a", "â": "a", "ã": "a",
	"é": "e", "ê": "e", "í": "i", "ó": "o", "ô": "o", "õ": "o", "ú": "u", "ü": "u", "ç": "c",
}

# Museu
@onready var _museum_catalog_filter: OptionButton = get_node_or_null(^"%MuseumCatalogFilter") as OptionButton
@onready var _museum_catalog_empty: Label = get_node_or_null(^"%MuseumCatalogEmpty") as Label
@onready var museum_item_list: ItemList = _resolve_node("MuseumItemList", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/MuseumItemList") as ItemList
@onready var item_select_box: OptionButton = _resolve_node("ItemSelectBox", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/HBoxContainer/ItemSelectBox") as OptionButton
@onready var sell_item_btn: Button = _resolve_node("SellItemButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/HBoxContainer/SellItemButton") as Button
@onready var register_item_btn: Button = _resolve_node("RegisterItemButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/HBoxContainer/RegisterItemButton") as Button
@onready var secrets_label: Label = _resolve_node("SecretsLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/SecretsLabel") as Label
@onready var museum_feedback_label: Label = _resolve_node("MuseumFeedbackLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/MuseumFeedbackLabel") as Label

# Expedições
@onready var map_list: ItemList = _resolve_node("MapList", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Expedições/MapList") as ItemList
@onready var unlock_map_btn: Button = _resolve_node("UnlockMapButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Expedições/UnlockMapButton") as Button
@onready var depart_btn: Button = _resolve_node("DepartButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Expedições/Actions/DepartButton") as Button
@onready var map_status_label: Label = _resolve_node("MapStatusLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Expedições/Actions/MapStatusLabel") as Label
@onready var expedition_feedback_label: Label = _resolve_node("ExpeditionFeedbackLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Expedições/ExpeditionFeedbackLabel") as Label

# Diário de Campo (#86)
@onready var journal_info_label: Label = _resolve_node("JournalInfoLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Diário/JournalInfoLabel") as Label
@onready var journal_grid: GridContainer = _resolve_node("JournalGrid", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Diário/JournalScroll/JournalContent/JournalGrid") as GridContainer
@onready var bosses_header_label: Label = _resolve_node("BossesHeaderLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Diário/JournalScroll/JournalContent/BossesHeaderLabel") as Label
@onready var bosses_grid: GridContainer = _resolve_node("BossesGrid", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Diário/JournalScroll/JournalContent/BossesGrid") as GridContainer

const SESSION_PATH: NodePath = ^"/root/CoreSession"

var _session: Node = null
var _maps: Array[MapData] = []

var _game_state: GameState = null
## upgrade_id -> {"row", "name", "pips", "detail"} das linhas da Loja.
var _shop_rows: Dictionary = {}
## Pasta dos ItemData do Museu; testes podem trocar antes do _ready.
var catalog_dir: String = "res://items/catalog"
var _catalog_items: Array[ItemData] = []
var _pending_purchase: bool = false

const SHOP_BUTTONS: Array[String] = ["detector", "pinpointer", "shovel", "backpack"]
## Capacidade base da mochila usada quando o GameState ainda não define
## BASE_BACKPACK_CAPACITY (core antigo). Lida via mapa de constantes para não
## quebrar a análise estática enquanto a constante não existir.
const DEFAULT_BACKPACK_BASE: int = 3
## Linhas da Loja (#119): ícone de UiIcons de cada melhoria, pips e largura do botão Comprar.
const SHOP_ICONS: Dictionary = {"detector": "detector", "pinpointer": "pinpointer", "shovel": "shovel", "backpack": "backpack"}
const SHOP_ICON_SIDE: float = 32.0
const SHOP_PIP_SIZE: Vector2 = Vector2(14, 8)
const SHOP_BUY_WIDTH: float = 128.0
## Estados do botão Comprar fora de compra (#122): papel claro com borda e texto na cor do motivo,
## em vez do bege apagado do disabled, que parecia quebrado.
const SHOP_NO_MONEY_TEXT: String = "Sem saldo"
const SHOP_STATE_NO_MONEY: Color = UiPalette.RED_BURNT
const SHOP_STATE_MAX: Color = UiPalette.GREEN_BOTTLE
const SHOP_STATE_LOCKED: Color = UiPalette.METAL
const WAITING_GAME_STATE_TOOLTIP: String = "Aguardando conexão com o estado do jogo..."
## Tempo máximo aguardando purchase_result antes de liberar os botões novamente.
const PURCHASE_TIMEOUT_SEC: float = 5.0
const TAB_FADE_DURATION: float = 0.11

var _purchase_timer: SceneTreeTimer = null
var _pending_unlock: bool = false
var _unlock_timer: SceneTreeTimer = null
var _tab_tween: Tween = null
var _animated_tab: Control = null

## Rótulos curtos das abas (nome do nó -> rótulo): com os nomes completos a TabBar passava
## da largura da Base e aparecia a seta, com a Loja fora da vista. O nome do nó (usado nos
## caminhos do _resolve_node e no ui_tab dos bots) fica igual e vira a dica (tooltip) da aba.
const MUSEUM_TAB_NAME: String = "Museu de Achados"
const TAB_SHORT_TITLES: Dictionary = {
	"Loja de Equipamentos": "Loja",
	MUSEUM_TAB_NAME: "Museu",
	"Expedições": "Expedições",
	"Diário": "Diário",
	AchievementsTab.TAB_NAME: "Conquistas",
}
const TAB_ICONS: Dictionary = {
	"Loja de Equipamentos": "wrench",
	MUSEUM_TAB_NAME: "museum",
	"Expedições": "compass",
	"Diário": "book",
	AchievementsTab.TAB_NAME: "trophy",
}
const MUSEUM_DONE_MARK: String = " ★"
## Aba Conquistas (#141), criada em runtime.
var achievements_tab: AchievementsTab = null

## Cor das linhas de mapas que ainda não podem ser jogados.
const MAP_LOCKED_COLOR: Color = UiPalette.METAL

## "Ver museu" (aba Museu): leva a câmera do lobby até a vitrine 3D (MuseumView, no lobby_base).
## Sem MuseumView na cena (a Base aberta sozinha, nos testes), o botão some.
var view_museum_btn: Button = null

## Expedição noturna (#109): "Noite" na mesa, por mapa (só os desbloqueados com config em
## NightMode.NIGHT_BY_MAP). A escolha fica guardada por mapa enquanto a Base existe.
var night_check: CheckButton = null
var _night_by_map: Dictionary = {}

## A Base cabe na tela (ui_scale 1.3 em 960x540 incluso): cada aba rola num ScrollContainer (com o
## nome da aba; o conteúdo vira o filho "Page") e a altura das abas é a do conteúdo da aba atual
## (#122: sem o vazio embaixo da Loja), limitada ao que cabe entre o topo da Base e a borda de baixo.
const BOTTOM_MARGIN: float = 12.0
const MIN_PAGE_HEIGHT: float = 120.0
var _page_scrolls: Array[ScrollContainer] = []
var _fit_queued: bool = false


func _resolve_node(unique_id: String, rel_path: String) -> Node:
	if has_node("%" + unique_id):
		return get_node("%" + unique_id)
	if has_node(rel_path):
		return get_node(rel_path)
	return find_child(unique_id, true, false)


func _ready() -> void:
	_decorate_header()
	_style_journal_heading(journal_info_label, "book")
	_style_journal_heading(bosses_header_label, "skull")
	if bosses_header_label != null:
		var content: Node = bosses_header_label.get_parent()
		var header_index: int = bosses_header_label.get_index()
		if header_index == 0 or not (content.get_child(header_index - 1) is HSeparator):
			var separator: HSeparator = HSeparator.new()
			content.add_child(separator)
			content.move_child(separator, header_index)
	if secrets_label != null:
		# Segredos por mapa: quebra só entre mapas (NBSP dentro de cada um).
		secrets_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_load_catalog()
	_setup_shop_buttons()
	_setup_museum_controls()
	# A loja já usa o CoreSession (nome dos mapas) no primeiro refresh.
	_session = get_node_or_null(SESSION_PATH)
	_build_achievements_tab()
	_wrap_pages_in_scroll()
	_hide_hub_shop()
	_apply_tab_titles()
	# Borda de foco só navegando por teclado/comando; com o mouse, nada aceso (#122).
	UiFocus.follow_pointer(get_node_or_null(^"PanelContainer") as Control)
	add_to_group(UiFocus.HOME_GROUP)
	_resolve_game_state()
	_setup_expeditions()
	if tab_container != null:
		tab_container.resized.connect(_sync_hidden_tab_widths)
		tab_container.tab_changed.connect(func(_tab: int) -> void:
			_animate_tab_content()
			_sync_hidden_tab_widths()
			_queue_fit_height()
			_sync_focus.call_deferred()
			_reveal_museum_header.call_deferred())
		_sync_hidden_tab_widths.call_deferred()
		_focus_initial.call_deferred()
		get_viewport().size_changed.connect(_queue_fit_height)
		_queue_fit_height()


func _decorate_header() -> void:
	var header: Label = get_node_or_null(^"PanelContainer/MarginContainer/VBoxContainer/HeaderLabel") as Label
	if header == null or header.get_parent() is HBoxContainer:
		return
	var vbox: Control = header.get_parent() as Control
	var idx: int = header.get_index()
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "HeaderRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	vbox.add_child(row)
	vbox.move_child(row, idx)
	var icon: TextureRect = TextureRect.new()
	icon.name = "HeaderIcon"
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = UiIcons.get_icon("home", 48)
	row.add_child(icon)
	header.reparent(row, false)


func _style_journal_heading(label: Label, icon_name: String) -> void:
	if label == null:
		return
	label.theme_type_variation = &"SubtitleLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var style: StyleBox = label.get_theme_stylebox(&"panel", &"SummaryTotalPanel").duplicate() as StyleBox
	var icon_left: float = style.get_margin(SIDE_LEFT)
	var icon_side: float = 20.0
	style.content_margin_left = icon_left + icon_side + 8.0
	label.add_theme_stylebox_override(&"normal", style)
	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = UiIcons.get_icon(icon_name, 40)
	label.add_child(icon)
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = icon_left
	icon.offset_right = icon_left + icon_side
	icon.offset_top = -icon_side * 0.5
	icon.offset_bottom = icon_side * 0.5


## Retain the old page as an inaccessible compatibility view while its presentation
## helpers migrate to the world shop. Neither keyboard nor controller may select it.
func _hide_hub_shop() -> void:
	if tab_container == null:
		return
	for index: int in tab_container.get_tab_count():
		if String(tab_container.get_tab_control(index).name) == "Loja de Equipamentos":
			tab_container.set_tab_hidden(index, true)
			if tab_container.current_tab == index:
				tab_container.current_tab = mini(index + 1, tab_container.get_tab_count() - 1)


## Idioma trocado (#131): os textos fixos (abas, botões da cena) se traduzem sozinhos; as linhas
## montadas aqui (mapas, loja, museu, segredos, mapa do tesouro, diário) são refeitas.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		var selected_item: ItemData = _get_selected_catalog_item()
		_sort_catalog()
		_fill_item_select_box(selected_item)
		_refresh_map_list()
		_refresh_shop_buttons()
		_refresh_museum_filter_text()
		_refresh_museum_display()
		_refresh_secrets_label()
		_refresh_journal_display()


## Rótulo, dica e ícone definidos pelo nome da página.
func _apply_tab_titles() -> void:
	if tab_container == null:
		return
	# O TabContainer repassa o limite à barra interna quando o tema muda.
	tab_container.add_theme_constant_override(&"icon_max_width", 16)
	var bar: TabBar = tab_container.get_tab_bar()
	bar.add_theme_constant_override(&"icon_max_width", 16)
	for i: int in tab_container.get_tab_count():
		var page_name: String = tab_container.get_tab_control(i).name
		if TAB_SHORT_TITLES.has(page_name):
			tab_container.set_tab_title(i, TAB_SHORT_TITLES[page_name])
			tab_container.set_tab_icon(i, UiIcons.get_icon(TAB_ICONS[page_name], 32))
			bar.set_tab_tooltip(i, page_name)


func _animate_tab_content() -> void:
	if _tab_tween != null:
		_tab_tween.kill()
		_tab_tween = null
	if is_instance_valid(_animated_tab):
		_animated_tab.modulate.a = 1.0
	_animated_tab = tab_container.get_current_tab_control()
	if _animated_tab == null or not tab_container.is_visible_in_tree():
		return
	_animated_tab.modulate.a = 0.8
	_tab_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tab_tween.tween_property(_animated_tab, ^"modulate:a", 1.0, TAB_FADE_DURATION)


## Comando/teclado (#102): a base abre com o foco na aba atual (no coop o menu de rede pega o
## foco primeiro). LB/RB (ou Ctrl+Tab) trocam de aba, se nenhum menu estiver por cima.
func _focus_initial() -> void:
	if SessionManager.launch_mode == SessionManager.LAUNCH_COOP or not is_visible_in_tree() or UiFocus.modal_open():
		return
	UiFocus.focus_tab_page(tab_container, [tab_container.get_tab_bar()])
	_reveal_museum_header.call_deferred()


## Teclado/comando (#135): botões desativados (Comprar sem saldo, Partir bloqueado...) saem da
## navegação e a corrente da aba atual é refeita, para o que voltou a ficar ativo entrar de novo.
func _sync_focus() -> void:
	var buttons: Array = [unlock_map_btn, depart_btn, night_check]
	if museum_dev_enabled(OS.is_debug_build(), OS.get_cmdline_user_args()):
		buttons.append_array([sell_item_btn, register_item_btn])
	for upgrade_id: String in SHOP_BUTTONS:
		buttons.append(_get_shop_button(upgrade_id))
	UiFocus.skip_disabled(buttons)
	if tab_container != null and tab_container.is_visible_in_tree():
		var bar: TabBar = tab_container.get_tab_bar()
		bar.focus_mode = Control.FOCUS_ALL
		var chain: Array = UiFocus.focusables(tab_container.get_current_tab_control())
		chain.append(bar)
		UiFocus.link_chain(chain)


## Uma camada por cima fechou sem foco para devolver (resumo do dia, #135): foco na aba atual.
func focus_home() -> void:
	if tab_container != null and is_visible_in_tree() and not PauseMenu.is_open() and not VictoryScreen.is_open():
		UiFocus.focus_tab_page(tab_container, [tab_container.get_tab_bar()])
		_reveal_museum_header.call_deferred()


## Reveal both progress and action at the Museum entry/home boundary, after layout/focus.
func _reveal_museum_header() -> void:
	if not is_instance_valid(view_museum_btn) or not view_museum_btn.is_visible_in_tree() or UiFocus.modal_open():
		return
	var page: ScrollContainer = tab_container.get_current_tab_control() as ScrollContainer
	if page == null or not page.is_ancestor_of(view_museum_btn):
		return
	view_museum_btn.grab_focus()
	page.scroll_vertical = 0


func _unhandled_input(event: InputEvent) -> void:
	if tab_container == null or not is_visible_in_tree() or PauseMenu.is_open() or VictoryScreen.is_open():
		return
	var step: int = UiFocus.tab_step(event)
	if step != 0:
		UiFocus.step_tab(tab_container, step, [tab_container.get_tab_bar()])
		get_viewport().set_input_as_handled()


## Layout: a Base tem a altura da maior aba (use_hidden_tabs_for_min_size). O TabContainer
## não dimensiona as abas ocultas, e um Container oculto não reorganiza os filhos; sem
## largura, os Labels com quebra de linha mediriam uma letra por linha e a Base ficaria
## gigante até cada aba ser aberta. Aqui os Labels com quebra das abas ocultas recebem a
## largura da aba atual (as abas são VBox sem margem, então é a largura deles). Com as abas
## dentro de ScrollContainers, a largura vem do ScrollContainer da aba atual (que o TabContainer
## dimensiona na hora), e vale também para o conteúdo da própria aba atual, que o ScrollContainer
## só reorganiza depois.
func _sync_hidden_tab_widths() -> void:
	var current_tab: Control = tab_container.get_current_tab_control()
	if current_tab == null:
		return
	var width: float = current_tab.size.x
	if current_tab is ScrollContainer:
		var bar: VScrollBar = (current_tab as ScrollContainer).get_v_scroll_bar()
		if bar.visible:
			width -= bar.size.x
	for i in range(tab_container.get_tab_count()):
		var page: Control = get_page(i)
		if page != tab_container.get_tab_control(i) and not is_equal_approx(page.size.x, width):
			page.size = Vector2(width, page.size.y)
		for child: Node in page.get_children():
			var label: Label = child as Label
			if label != null and label.autowrap_mode != TextServer.AUTOWRAP_OFF and not is_equal_approx(label.size.x, width):
				label.size = Vector2(width, label.size.y)
				label.update_minimum_size()


## Conteúdo da aba `index` (dentro do ScrollContainer da aba).
func get_page(index: int) -> Control:
	var tab: Control = tab_container.get_tab_control(index)
	if tab is ScrollContainer and tab.get_child_count() > 0:
		return tab.get_child(0) as Control
	return tab


func _wrap_pages_in_scroll() -> void:
	if tab_container == null:
		return
	var current: int = tab_container.current_tab
	for child: Node in tab_container.get_children():
		var page: Control = child as Control
		if page == null or page is ScrollContainer:
			continue
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		var index: int = page.get_index()
		var page_name: StringName = page.name
		page.name = "Page"
		scroll.name = page_name
		tab_container.add_child(scroll)
		tab_container.move_child(scroll, index)
		page.reparent(scroll, false)
		# ScrollContainer owns the page bounds after reparenting.
		page.set_anchors_preset(Control.PRESET_TOP_LEFT)
		page.visible = true
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.minimum_size_changed.connect(_queue_fit_height)
		_page_scrolls.append(scroll)
	tab_container.current_tab = current


func _queue_fit_height() -> void:
	if not _fit_queued:
		_fit_queued = true
		_fit_height.call_deferred()


## Altura das abas = a do conteúdo da aba atual, sem passar da borda de baixo da tela.
func _fit_height() -> void:
	_fit_queued = false
	var panel: Control = get_node_or_null(^"PanelContainer") as Control
	if _page_scrolls.is_empty() or panel == null or not is_inside_tree():
		return
	_sync_hidden_tab_widths()
	var current: ScrollContainer = tab_container.get_current_tab_control() as ScrollContainer
	if current == null or current.get_child_count() == 0:
		current = _page_scrolls[0]
	var content_h: float = (current.get_child(0) as Control).get_combined_minimum_size().y
	var current_h: float = _page_scrolls[0].custom_minimum_size.y
	var overhead: float = panel.get_combined_minimum_size().y - current_h
	var avail: float = get_viewport().get_visible_rect().size.y - panel.global_position.y - BOTTOM_MARGIN - overhead
	var h: float = minf(content_h, maxf(avail, MIN_PAGE_HEIGHT))
	if is_equal_approx(h, current_h):
		return
	for scroll: ScrollContainer in _page_scrolls:
		scroll.custom_minimum_size.y = h


# --- Expedições ---------------------------------------------------------------
# O SessionManager (autoload "CoreSession") é acessado dinamicamente e pode não existir.

func _setup_expeditions() -> void:
	_session = get_node_or_null(SESSION_PATH)
	if map_status_label != null:
		var warning_box: StyleBoxFlat = StyleBoxFlat.new()
		warning_box.bg_color = Color(UiPalette.RED_BURNT, 0.10)
		warning_box.border_color = Color(UiPalette.RED_BURNT, 0.55)
		warning_box.set_border_width_all(1)
		warning_box.border_width_left = 3
		warning_box.set_corner_radius_all(4)
		warning_box.content_margin_left = 5.0
		warning_box.content_margin_right = 4.0
		warning_box.content_margin_top = 0.0
		warning_box.content_margin_bottom = 0.0
		map_status_label.add_theme_stylebox_override(&"normal", warning_box)
		map_status_label.add_theme_constant_override(&"line_spacing", -2)
	var refresh_one_arg: Callable = _refresh_expedition_buttons.unbind(1)
	if map_list != null:
		map_list.fixed_icon_size = Vector2i(16, 16)
		map_list.item_selected.connect(func(_index: int) -> void:
			_set_expedition_feedback("")
			_refresh_expedition_buttons())
	if unlock_map_btn != null:
		unlock_map_btn.pressed.connect(_on_unlock_map_pressed)
	if depart_btn != null:
		depart_btn.size_flags_stretch_ratio = 0.32
		depart_btn.icon = UiIcons.get_icon("play", 18)
		depart_btn.pressed.connect(_on_depart_pressed)
		_build_night_check()
	if _session != null:
		for sig: StringName in [&"expedition_started", &"expedition_ended", &"scene_changing"]:
			if _session.has_signal(sig):
				_session.connect(sig, refresh_one_arg)
		if _session.has_signal(&"expedition_start_failed"):
			_session.connect(&"expedition_start_failed", _on_expedition_start_failed)
	multiplayer.connected_to_server.connect(_refresh_expedition_buttons)
	multiplayer.server_disconnected.connect(_refresh_expedition_buttons)
	multiplayer.peer_connected.connect(refresh_one_arg)
	_refresh_map_list()


func _session_call(method: StringName, args: Array = [], default_value: Variant = null) -> Variant:
	if _session != null and is_instance_valid(_session) and _session.has_method(method):
		return _session.callv(method, args)
	return default_value


func _refresh_map_list() -> void:
	_maps.clear()
	var result: Variant = _session_call(&"get_available_maps", [], [])
	if result is Array:
		for m: Variant in result:
			if m is MapData:
				_maps.append(m as MapData)
	if map_list == null:
		return
	var previous: int = map_list.get_selected_items()[0] if map_list.is_anything_selected() else 0
	map_list.clear()
	for map: MapData in _maps:
		var status: Dictionary = _get_map_status(map)
		if status.is_empty():
			# Core sem progressão de mapas: linha antiga.
			var legacy_idx: int = map_list.add_item(_format_map_details(map))
			map_list.set_item_icon(legacy_idx, UiIcons.get_icon("map", 18))
			continue
		var playable: bool = bool(status.get("playable", false))
		var idx: int = map_list.add_item(_format_map_row(map, status))
		map_list.set_item_icon(idx, UiIcons.get_icon("map" if playable else "lock", 18))
		if not playable:
			map_list.set_item_icon_modulate(idx, Color(0.82, 0.78, 0.72, 0.75))
		map_list.set_item_tooltip(idx, _map_progress_message(map, status))
		if not playable:
			# Continua selecionável para o jogador ver o motivo e poder desbloquear.
			map_list.set_item_custom_fg_color(idx, MAP_LOCKED_COLOR)
	if not _maps.is_empty():
		map_list.select(clampi(previous, 0, _maps.size() - 1))
	elif _session == null:
		_set_expedition_feedback("Sistema de expedições indisponível.")
	else:
		_set_expedition_feedback("Nenhum mapa disponível.")
	_refresh_expedition_buttons()


func _map_name(map: MapData) -> String:
	return tr(map.display_name) if not map.display_name.is_empty() else map.id


func _format_map_details(map: MapData) -> String:
	return tr("%s  •  %d pontos") % [_map_name(map), map.spot_count]


func _format_map_row(map: MapData, status: Dictionary) -> String:
	if bool(status.get("playable", false)):
		return "✔ " + _format_map_details(map)
	if not bool(status.get("unlocked", false)):
		var row: String = "🔒 %s" % _map_name(map)
		var boss_name: String = str(status.get("required_boss_name", ""))
		if not boss_name.is_empty():
			row += tr("  •  Chefe: %s") % tr(boss_name)
			if bool(status.get("boss_defeated", false)):
				row += " ✔"
		return row
	if not bool(status.get("has_scene", false)):
		return tr("%s  •  Em breve") % _map_name(map)
	return _format_map_details(map)


## Status de progressão do mapa vindo do core, ou {} se o core não suporta.
func _get_map_status(map: MapData) -> Dictionary:
	if map == null:
		return {}
	var result: Variant = _session_call(&"get_map_status", [map.id], {})
	return result as Dictionary if result is Dictionary else {}


func _map_progress_message(map: MapData, status: Dictionary) -> String:
	var reason: String = UiFormat.fix_money_spaces(tr(str(status.get("reason", ""))))
	if reason.is_empty() or bool(status.get("unlocked", false)) or not bool(status.get("boss_defeated", false)):
		return reason
	var route: Dictionary = GameState.MAP_UNLOCK_BOSSES.get(map.id, {})
	var source_id: String = str(route.get("source_map", ""))
	if source_id.is_empty():
		return reason
	var source_name: String = UiFormat.map_display_name(source_id, _maps)
	return "%s\n%s → %s" % [reason, source_name, _map_name(map)]


func _get_selected_map() -> MapData:
	if map_list == null or not map_list.is_anything_selected():
		return null
	var idx: int = map_list.get_selected_items()[0]
	return _maps[idx] if idx >= 0 and idx < _maps.size() else null


func _is_host() -> bool:
	if _game_state != null:
		return _game_state.is_authority()
	return multiplayer.is_server()


## Retorna o motivo pelo qual não é possível partir, ou "" se puder.
func _get_depart_block_reason(map: MapData) -> String:
	if _session == null:
		return "Sistema de expedições indisponível."
	if map == null:
		return "Selecione um mapa."
	if bool(_session_call(&"is_in_expedition", [], false)) or bool(_session_call(&"is_starting_expedition", [], false)):
		return "Já existe uma expedição em andamento."
	if not _is_host():
		return "Apenas o host pode iniciar a expedição."
	var status: Dictionary = _get_map_status(map)
	if not status.is_empty():
		return _map_progress_message(map, status)
	if not bool(_session_call(&"can_start_map", [map.id], false)):
		return tr("Requer detector nível %d.") % map.required_detector_level
	return ""


func _refresh_expedition_buttons() -> void:
	_refresh_unlock_button()
	_refresh_night_check()
	_refresh_depart_button()
	_refresh_map_status_label()


## Motivo visível (sem passar o mouse) de não poder desbloquear ou partir para o mapa selecionado.
## Some quando dá para desbloquear ou partir; os tooltips continuam.
func _refresh_map_status_label() -> void:
	if map_status_label == null:
		return
	var reason: String = _get_map_status_reason(_get_selected_map())
	map_status_label.visible = not reason.is_empty()
	map_status_label.text = "🔒 " + reason if not reason.is_empty() else ""


func _get_map_status_reason(map: MapData) -> String:
	if map == null:
		return ""
	var status: Dictionary = _get_map_status(map)
	if status.is_empty():
		return UiFormat.fix_money_spaces(tr(_get_depart_block_reason(map)))
	if not bool(status.get("unlocked", true)):
		return "" if bool(status.get("can_unlock", false)) else _map_progress_message(map, status)
	return UiFormat.fix_money_spaces(tr(_get_depart_block_reason(map)))


func _can_request_unlock() -> bool:
	return false # First opening belongs to the physical passage, never this menu.


func _refresh_unlock_button() -> void:
	if unlock_map_btn == null:
		return
	unlock_map_btn.visible = false
	unlock_map_btn.disabled = true
	_sync_focus()


func _on_unlock_map_pressed() -> void:
	var map: MapData = _get_selected_map()
	if map == null or _pending_unlock or not _can_request_unlock():
		return
	var status: Dictionary = _get_map_status(map)
	if not bool(status.get("can_unlock", false)):
		_set_expedition_feedback(str(status.get("reason", "")))
		return
	# Qualquer peer pode desbloquear; a resposta chega por map_unlock_result.
	_pending_unlock = true
	_refresh_unlock_button()
	_set_expedition_feedback("Processando desbloqueio...")
	var timer: SceneTreeTimer = get_tree().create_timer(PURCHASE_TIMEOUT_SEC)
	_unlock_timer = timer
	timer.timeout.connect(_on_unlock_timeout.bind(timer))
	_game_state.call(&"request_unlock_map", map.id)


func _on_unlock_timeout(timer: SceneTreeTimer) -> void:
	# Ignora timers de desbloqueios anteriores já respondidos.
	if not _pending_unlock or timer != _unlock_timer:
		return
	_pending_unlock = false
	_unlock_timer = null
	_set_expedition_feedback("Sem resposta do host. Tente novamente.")
	_refresh_unlock_button()


func _on_map_unlock_result(_map_id: String, _success: bool, message: String) -> void:
	_pending_unlock = false
	_unlock_timer = null
	_set_expedition_feedback(message)
	_refresh_map_list()


func _on_progression_changed(_unlocked_maps: Array, _defeated_bosses: Array) -> void:
	_refresh_map_list()
	# Mapa desbloqueado libera níveis da loja travados por ele.
	_refresh_shop_buttons()
	_refresh_journal_display()


func _refresh_depart_button() -> void:
	if depart_btn == null:
		return
	var map: MapData = _get_selected_map()
	var reason: String = _get_depart_block_reason(map)
	depart_btn.disabled = not reason.is_empty()
	depart_btn.tooltip_text = UiFormat.fix_money_spaces(tr(reason))
	_sync_focus()
	if map == null:
		depart_btn.text = "Partir"
	elif is_night_selected():
		depart_btn.text = tr("Partir para %s (noite)") % _map_name(map)
	else:
		depart_btn.text = tr("Partir para %s") % _map_name(map)


func _on_depart_pressed() -> void:
	var map: MapData = _get_selected_map()
	var reason: String = _get_depart_block_reason(map)
	if not reason.is_empty():
		_set_expedition_feedback(reason)
		return
	depart_btn.disabled = true
	var night: bool = is_night_selected()
	_set_expedition_feedback((tr("Preparando expedição noturna para %s...") if night else tr("Preparando expedição para %s...")) % _map_name(map))
	var result: Error = _session_call(&"request_start_expedition", [map.id, night], ERR_UNAVAILABLE)
	if result != OK:
		_refresh_expedition_buttons()
		reason = UiFormat.fix_money_spaces(tr(_get_depart_block_reason(map)))
		var reason_already_visible: bool = map_status_label != null and map_status_label.visible and map_status_label.text == "🔒 " + reason
		if reason.is_empty():
			reason = "Sistema de expedições indisponível."
		_set_expedition_feedback("" if reason_already_visible else reason)


func _on_expedition_start_failed(message: String) -> void:
	_refresh_expedition_buttons()
	_set_expedition_feedback(message)


func _build_night_check() -> void:
	night_check = CheckButton.new()
	night_check.name = "NightCheck"
	night_check.text = "Noite"
	night_check.icon = UiIcons.get_icon("moon", 48)
	night_check.add_theme_constant_override(&"icon_max_width", 20)
	night_check.tooltip_text = "Expedição noturna: mais achados raros e criaturas noturnas, mas pouca visão. A Lanterna de Magnésio e o visor do detector iluminam."
	night_check.focus_mode = Control.FOCUS_ALL
	night_check.toggled.connect(_on_night_toggled)
	var page: Node = depart_btn.get_parent()
	page.add_child(night_check)
	page.move_child(night_check, depart_btn.get_index())


## A noite vale para o mapa selecionado se ele está desbloqueado e tem config de noite.
func _night_available(map: MapData) -> bool:
	if map == null or not NightMode.is_available(map.id):
		return false
	return bool(_get_map_status(map).get("unlocked", false))


func is_night_selected() -> bool:
	var map: MapData = _get_selected_map()
	return _night_available(map) and bool(_night_by_map.get(map.id, false))


func _refresh_night_check() -> void:
	if night_check == null:
		return
	var map: MapData = _get_selected_map()
	night_check.visible = _night_available(map)
	night_check.disabled = not _is_host()
	night_check.set_pressed_no_signal(night_check.visible and bool(_night_by_map.get(map.id, false)))
	_sync_focus()


func _on_night_toggled(on: bool) -> void:
	var map: MapData = _get_selected_map()
	if map != null:
		_night_by_map[map.id] = on
	_refresh_depart_button()


func _set_expedition_feedback(msg: String) -> void:
	if expedition_feedback_label != null:
		expedition_feedback_label.text = UiFormat.fix_money_spaces(tr(msg))
		expedition_feedback_label.visible = not msg.is_empty()


func _resolve_game_state() -> void:
	if GameState.instance != null:
		_game_state = GameState.instance
	elif get_tree().root.has_node("CoreGameState"):
		_game_state = get_tree().root.get_node("CoreGameState") as GameState
	
	if _game_state != null:
		if not _game_state.money_changed.is_connected(_on_state_updated):
			_game_state.money_changed.connect(_on_state_updated)
		if not _game_state.collection_updated.is_connected(_on_collection_updated):
			_game_state.collection_updated.connect(_on_collection_updated)
		if not _game_state.item_sold.is_connected(_on_item_sold):
			_game_state.item_sold.connect(_on_item_sold)
		if not _game_state.item_donated.is_connected(_on_item_donated):
			_game_state.item_donated.connect(_on_item_donated)
		if not _game_state.upgrades_changed.is_connected(_on_upgrades_changed):
			_game_state.upgrades_changed.connect(_on_upgrades_changed)
		if not _game_state.purchase_result.is_connected(_on_purchase_result):
			_game_state.purchase_result.connect(_on_purchase_result)
		# Sinais da progressão de mapas: podem não existir em um core antigo.
		_connect_game_state_signal(&"map_unlock_result", _on_map_unlock_result)
		_connect_game_state_signal(&"progression_changed", _on_progression_changed)
		_connect_game_state_signal(&"secret_found", _on_secret_found)
		_connect_game_state_signal(&"creature_discovered", _on_creature_discovered)
		_connect_game_state_signal(&"state_synced", _on_state_synced)
		_connect_game_state_signal(&"game_completed_changed", _on_game_completed_changed)
	
	_refresh_museum_display()
	_refresh_secrets_label()
	_refresh_shop_buttons()
	_refresh_journal_display()


func _connect_game_state_signal(signal_name: StringName, callable: Callable) -> void:
	if _game_state.has_signal(signal_name) and not _game_state.is_connected(signal_name, callable):
		_game_state.connect(signal_name, callable)


func _load_catalog() -> void:
	_catalog_items.clear()
	var dir: DirAccess = DirAccess.open(catalog_dir)
	if dir == null:
		var err: Error = DirAccess.get_open_error()
		push_warning("BaseStationUI: catálogo '%s' não abriu (%s); Museu sem itens de teste, Loja segue normal." % [catalog_dir, error_string(err)])
		_mark_catalog_unavailable("Catálogo de itens indisponível.")
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			var clean_name: String = file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				var full_path: String = "res://items/catalog/%s" % clean_name
				var res: Resource = ResourceLoader.load(full_path)
				if res is ItemData:
					_catalog_items.append(res as ItemData)
		file_name = dir.get_next()
	
	_sort_catalog()
	if _catalog_items.is_empty():
		push_warning("BaseStationUI: catálogo '%s' sem nenhum ItemData (.tres)." % catalog_dir)
		_mark_catalog_unavailable("Catálogo de itens vazio.")


## Compara pelo nome exibido. Acentos do português não mudam a letra na ordenação.
func _sort_catalog() -> void:
	var sort_keys: Dictionary = {}
	for item: ItemData in _catalog_items:
		var key: String = ""
		for letter: String in tr(item.display_name).to_lower():
			key += String(CATALOG_SORT_ACCENTS.get(letter, letter))
		sort_keys[item] = key
	_catalog_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		var a_key: String = sort_keys[a]
		var b_key: String = sort_keys[b]
		var comparison: int = a_key.naturalnocasecmp_to(b_key)
		return a.id < b.id if comparison == 0 else comparison < 0)


## Museu sem catálogo: avisa na própria aba e trava os botões de teste.
func _mark_catalog_unavailable(message: String) -> void:
	if museum_feedback_label != null:
		museum_feedback_label.text = tr(message)
	if sell_item_btn != null:
		sell_item_btn.disabled = true
	if register_item_btn != null:
		register_item_btn.disabled = true
	_sync_focus()


func _setup_shop_buttons() -> void:
	for upgrade_id: String in SHOP_BUTTONS:
		var btn: Button = _get_shop_button(upgrade_id)
		if btn != null:
			btn.pressed.connect(_purchase_upgrade.bind(upgrade_id))
			_build_shop_row(upgrade_id, btn)


## Linha da Loja (#119): ícone, nome, pips de nível e uma linha de detalhe à esquerda; o botão
## Comprar (o mesmo Buy*Button da cena, com o preço) vai para a direita da linha.
func _build_shop_row(upgrade_id: String, btn: Button) -> void:
	if _shop_rows.has(upgrade_id):
		return
	var page: Node = btn.get_parent()
	var row: PanelContainer = PanelContainer.new()
	row.name = String(btn.name).trim_suffix("Button") + "Row"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = UiPalette.PAPER_LIGHT
	style.border_color = UiPalette.PAPER_DARK
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	row.add_theme_stylebox_override(&"panel", style)
	page.add_child(row)
	page.move_child(row, btn.get_index())
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	row.add_child(box)
	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.texture = UiIcons.get_icon(str(SHOP_ICONS.get(upgrade_id, "")), 64)
	icon.custom_minimum_size = Vector2(SHOP_ICON_SIDE, SHOP_ICON_SIDE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override(&"separation", 2)
	box.add_child(info)
	var name_label: Label = Label.new()
	name_label.name = "Name"
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	info.add_child(line)
	var pips: HBoxContainer = HBoxContainer.new()
	pips.name = "Pips"
	pips.add_theme_constant_override(&"separation", 3)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(pips)
	var detail: Label = Label.new()
	detail.name = "Detail"
	detail.add_theme_font_size_override(&"font_size", 13)
	detail.add_theme_color_override(&"font_color", UiPalette.WOOD)
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(detail)
	btn.reparent(box, false)
	btn.custom_minimum_size = Vector2(SHOP_BUY_WIDTH, 40)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.theme_type_variation = &"PrimaryButton"
	btn.clip_text = false
	btn.add_theme_font_size_override(&"font_size", 14)
	_shop_rows[upgrade_id] = {"row": row, "name": name_label, "pips": pips, "detail": detail}


## Pips de nível: `level` cheios (laranja) de `max_level`.
func _set_shop_pips(pips: HBoxContainer, level: int, max_level: int) -> void:
	while pips.get_child_count() < max_level:
		var pip: Panel = Panel.new()
		pip.custom_minimum_size = SHOP_PIP_SIZE
		pips.add_child(pip)
	while pips.get_child_count() > max_level:
		var extra: Node = pips.get_child(pips.get_child_count() - 1)
		pips.remove_child(extra)
		extra.queue_free()
	for i: int in pips.get_child_count():
		var pip_style: StyleBoxFlat = StyleBoxFlat.new()
		pip_style.bg_color = UiPalette.ORANGE if i < level else UiPalette.PAPER_DARK
		pip_style.border_color = UiPalette.INK
		pip_style.set_border_width_all(1)
		pip_style.set_corner_radius_all(3)
		(pips.get_child(i) as Panel).add_theme_stylebox_override(&"panel", pip_style)


func _set_shop_row(upgrade_id: String, display_name: String, level: int, max_level: int, detail: String) -> void:
	if not _shop_rows.has(upgrade_id):
		return
	var row: Dictionary = _shop_rows[upgrade_id]
	(row["name"] as Label).text = tr(display_name)
	(row["detail"] as Label).text = detail
	_set_shop_pips(row["pips"] as HBoxContainer, level, max_level)


func _get_shop_button(upgrade_id: String) -> Button:
	match upgrade_id:
		"detector":
			return buy_detector_btn
		"pinpointer":
			return buy_pinpointer_btn
		"shovel":
			return buy_shovel_btn
		"backpack":
			return buy_backpack_btn
	return null


func _get_backpack_base() -> int:
	if _game_state != null:
		var script: Script = _game_state.get_script() as Script
		if script != null:
			var constants: Dictionary = script.get_script_constant_map()
			if constants.has("BASE_BACKPACK_CAPACITY"):
				return int(constants["BASE_BACKPACK_CAPACITY"])
	return DEFAULT_BACKPACK_BASE


func _refresh_shop_buttons() -> void:
	if _game_state == null:
		# Core ainda carregando: nada clicável até o GameState chegar.
		for upgrade_id: String in SHOP_BUTTONS:
			var waiting_btn: Button = _get_shop_button(upgrade_id)
			if waiting_btn != null:
				waiting_btn.disabled = true
				waiting_btn.tooltip_text = WAITING_GAME_STATE_TOOLTIP
		_sync_focus()
		return
	for upgrade_id: String in SHOP_BUTTONS:
		var btn: Button = _get_shop_button(upgrade_id)
		if btn == null:
			continue
		if not GameState.UPGRADES.has(upgrade_id):
			# Upgrade ainda não existe no core em execução.
			btn.visible = false
			if _shop_rows.has(upgrade_id):
				(_shop_rows[upgrade_id]["row"] as Control).visible = false
			continue
		btn.visible = true
		var display_name: String = GameState.UPGRADES[upgrade_id]["name"]
		var level: int = _game_state.get_upgrade_level(upgrade_id)
		var max_level: int = _game_state.get_upgrade_max_level(upgrade_id)
		var cost: int = _game_state.get_next_upgrade_cost(upgrade_id)
		var detail: String = tr("Nível %d/%d") % [level, max_level]
		if upgrade_id == "detector":
			# O radar começa no nível 1 com o detector no nível 0.
			detail = tr("Nível %d/%d  •  radar Nv.%d") % [level, max_level, level + 1]
		if _shop_rows.has(upgrade_id):
			(_shop_rows[upgrade_id]["row"] as Control).visible = true
		if cost < 0:
			_set_shop_row(upgrade_id, display_name, level, max_level, detail)
			btn.text = "Máximo"
			btn.tooltip_text = tr("%s já está no nível máximo.") % tr(display_name)
			btn.disabled = true
			_set_shop_state(btn, SHOP_STATE_MAX)
			continue
		var reason: String = _get_upgrade_block_reason(upgrade_id, cost)
		var required_map: String = _get_next_upgrade_required_map(upgrade_id)
		if not required_map.is_empty() and not reason.is_empty() and not _game_state.is_map_unlocked(required_map):
			_set_shop_row(upgrade_id, display_name, level, max_level, tr("🔒 Requer %s") % tr(_get_map_display_name(required_map)))
			btn.text = "🔒 %s" % UiFormat.money(cost)
			btn.tooltip_text = UiFormat.fix_money_spaces(tr(reason))
			btn.disabled = true
			_set_shop_state(btn, SHOP_STATE_LOCKED)
			continue
		_set_shop_row(upgrade_id, display_name, level, max_level, detail)
		var no_money: bool = not reason.is_empty() and _game_state.team_money < cost
		btn.text = "%s\n%s" % [tr(SHOP_NO_MONEY_TEXT) if no_money else tr("Comprar"), UiFormat.money(cost)]
		_set_shop_state(btn, SHOP_STATE_NO_MONEY if no_money else Color.TRANSPARENT)
		if not reason.is_empty():
			btn.tooltip_text = UiFormat.fix_money_spaces(tr(reason))
		elif upgrade_id == "detector":
			btn.tooltip_text = tr("Radar: Nv.%d → Nv.%d") % [level + 1, level + 2]
		elif upgrade_id == "backpack":
			var base: int = _get_backpack_base()
			btn.tooltip_text = tr("Mochila: %d → %d espaços") % [base + level, base + level + 1]
		else:
			btn.tooltip_text = ""
		btn.disabled = _pending_purchase or not reason.is_empty()
	_sync_focus()


## Botão Comprar parado num estado (sem saldo, máximo, bloqueado): papel claro, borda e texto na
## cor `color`. Color.TRANSPARENT volta ao PrimaryButton do theme (comprável ou processando).
func _set_shop_state(btn: Button, color: Color) -> void:
	if color.a <= 0.0:
		btn.remove_theme_stylebox_override(&"disabled")
		btn.remove_theme_color_override(&"font_disabled_color")
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = UiPalette.PAPER_LIGHT
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	btn.add_theme_stylebox_override(&"disabled", style)
	btn.add_theme_color_override(&"font_disabled_color", color)


## Motivo do core para não comprar o próximo nível; core antigo: só checa o saldo.
func _get_upgrade_block_reason(upgrade_id: String, cost: int) -> String:
	if _game_state.has_method(&"get_upgrade_block_reason"):
		return str(_game_state.call(&"get_upgrade_block_reason", upgrade_id))
	if _game_state.team_money < cost:
		return tr("Saldo insuficiente (%s).") % UiFormat.money(_game_state.team_money)
	return ""


func _get_next_upgrade_required_map(upgrade_id: String) -> String:
	if _game_state.has_method(&"get_next_upgrade_required_map"):
		return str(_game_state.call(&"get_next_upgrade_required_map", upgrade_id))
	return ""


func _get_map_display_name(map_id: String) -> String:
	var status: Variant = _session_call(&"get_map_status", [map_id], {})
	var display_name: String = str((status as Dictionary).get("display_name", "")) if status is Dictionary else ""
	return display_name if not display_name.is_empty() else map_id


func _setup_museum_controls() -> void:
	_fill_item_select_box()
	var dev_ui: bool = museum_dev_enabled(OS.is_debug_build(), OS.get_cmdline_user_args())
	for id: String in ["SimLabel", "SimSeparator", "ItemSelectBox", "SellItemButton", "RegisterItemButton"]:
		var control: Control = find_child(id, true, false) as Control
		if control != null:
			control.visible = dev_ui
			if control is BaseButton:
				control.focus_mode = Control.FOCUS_ALL if dev_ui else Control.FOCUS_NONE
	if item_select_box != null:
		(item_select_box.get_parent() as Control).visible = dev_ui
	if sell_item_btn != null:
		sell_item_btn.pressed.connect(_on_sell_test_pressed)
	if register_item_btn != null:
		register_item_btn.pressed.connect(_on_register_test_pressed)
	_build_view_museum_button()
	if _museum_catalog_filter != null:
		_refresh_museum_filter_text()
		_museum_catalog_filter.item_selected.connect(func(_index: int) -> void:
			_refresh_museum_display())
	if museum_item_list != null:
		museum_item_list.resized.connect(_sync_museum_catalog_width)
		museum_item_list.item_selected.connect(func(_index: int) -> void:
			_ensure_museum_selection_visible.call_deferred())
		_sync_museum_catalog_width.call_deferred()


func _refresh_museum_filter_text() -> void:
	if _museum_catalog_filter == null:
		return
	var selected: int = maxi(_museum_catalog_filter.selected, MuseumFilter.ALL)
	_museum_catalog_filter.clear()
	_museum_catalog_filter.add_item(tr("Todos"), MuseumFilter.ALL)
	_museum_catalog_filter.add_item(tr("Descobertos"), MuseumFilter.DISCOVERED)
	_museum_catalog_filter.add_item(tr("Pendentes"), MuseumFilter.PENDING)
	_museum_catalog_filter.select(selected)
	_museum_catalog_empty.text = tr("Nenhum item neste filtro.")


static func museum_dev_enabled(debug_build: bool, args: PackedStringArray) -> bool:
	return debug_build and args.has("--dev-ui")


func _sync_museum_catalog_width() -> void:
	var padding: float = museum_item_list.get_theme_stylebox(&"panel").get_minimum_size().x + museum_item_list.get_theme_constant(&"h_separation")
	museum_item_list.fixed_column_width = maxi(1, floori(museum_item_list.size.x - padding))


## ItemList auto_height has no internal scroll; expose its current selection in the page.
func _ensure_museum_selection_visible() -> void:
	if not museum_item_list.has_focus() or not museum_item_list.is_visible_in_tree():
		return
	var selected: PackedInt32Array = museum_item_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	var ancestor: Node = museum_item_list.get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	var scroll: ScrollContainer = ancestor as ScrollContainer
	if scroll == null:
		return
	var row: Rect2 = museum_item_list.get_item_rect(index)
	row.position += museum_item_list.global_position
	var viewport: Rect2 = scroll.get_global_rect()
	if row.end.y > viewport.end.y:
		scroll.scroll_vertical += ceili(row.end.y - viewport.end.y + 4.0)
	elif row.position.y < viewport.position.y:
		scroll.scroll_vertical -= ceili(viewport.position.y - row.position.y + 4.0)


## Itens do catálogo na caixa de teste do Museu (nome no idioma atual; a seleção fica).
func _fill_item_select_box(selected_item: ItemData = null) -> void:
	if item_select_box == null:
		return
	var selected: int = _catalog_items.find(selected_item)
	item_select_box.clear()
	for i in range(_catalog_items.size()):
		var item: ItemData = _catalog_items[i]
		item_select_box.add_item("%s (%s)" % [tr(item.display_name), UiFormat.money(item.base_value)], i)
	if selected >= 0 and selected < item_select_box.item_count:
		item_select_box.select(selected)


## Progresso separado do catalogo; a pagina externa e a unica rolagem vertical.
func _build_view_museum_button() -> void:
	if museum_item_list == null:
		return
	var page: Control = museum_item_list.get_parent() as Control
	var info: Label = page.get_node_or_null(^"MuseumInfoLabel") as Label
	if secrets_label != null:
		var progress: PanelContainer = PanelContainer.new()
		progress.name = "MuseumProgress"
		progress.theme_type_variation = &"SummaryTotalPanel"
		var panel_style: StyleBox = get_theme_stylebox(&"panel", &"SummaryTotalPanel").duplicate() as StyleBox
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			panel_style.set_content_margin(side, 8.0)
		progress.add_theme_stylebox_override(&"panel", panel_style)
		page.add_child(progress)
		page.move_child(progress, 0)
		secrets_label.reparent(progress, false)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "MuseumInfoRow"
	page.add_child(row)
	page.move_child(row, info.get_index() if info != null else 0)
	if info != null:
		info.reparent(row, false)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	view_museum_btn = Button.new()
	view_museum_btn.name = "ViewMuseumButton"
	view_museum_btn.theme_type_variation = &"PrimaryButton"
	view_museum_btn.custom_minimum_size.y = 44.0
	var focus: StyleBoxFlat = get_theme_stylebox(&"focus", &"PrimaryButton").duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = UiPalette.PAPER_LIGHT
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		focus.set_border_width(side, 1)
		focus.set_expand_margin(side, 0.0)
	view_museum_btn.add_theme_stylebox_override(&"focus", focus)
	view_museum_btn.text = "Ver museu"
	view_museum_btn.tooltip_text = "Ver a vitrine do Museu ao lado da tenda"
	view_museum_btn.icon = UiIcons.get_icon("museum", 48)
	view_museum_btn.add_theme_constant_override(&"icon_max_width", 20)
	view_museum_btn.focus_mode = Control.FOCUS_ALL
	view_museum_btn.pressed.connect(_on_view_museum_pressed)
	row.add_child(view_museum_btn)
	_refresh_view_museum_button.call_deferred()


func _museum_view() -> MuseumView:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(MuseumView.GROUP) as MuseumView


func _refresh_view_museum_button() -> void:
	var view: MuseumView = _museum_view()
	view_museum_btn.visible = view != null and view.is_available()


func _on_view_museum_pressed() -> void:
	var view: MuseumView = _museum_view()
	if view == null:
		return
	if not view.closed.is_connected(_on_museum_view_closed):
		view.closed.connect(_on_museum_view_closed)
	view.open()


## De volta à tenda: o foco volta ao "Ver museu" (teclado e controle).
func _on_museum_view_closed() -> void:
	if view_museum_btn != null and view_museum_btn.is_visible_in_tree():
		view_museum_btn.grab_focus()


func _purchase_upgrade(upgrade_id: String) -> void:
	if _game_state == null:
		_set_shop_feedback("Erro: GameState não disponível.")
		return
	if _pending_purchase:
		return
	
	# A confirmação (ou recusa) chega pelo sinal purchase_result vindo do host.
	_pending_purchase = true
	_refresh_shop_buttons()
	_set_shop_feedback("Processando compra...")
	var timer: SceneTreeTimer = get_tree().create_timer(PURCHASE_TIMEOUT_SEC)
	_purchase_timer = timer
	timer.timeout.connect(_on_purchase_timeout.bind(timer))
	_game_state.request_buy_upgrade(upgrade_id)


func _on_purchase_timeout(timer: SceneTreeTimer) -> void:
	# Ignora timers de compras anteriores já respondidas.
	if not _pending_purchase or timer != _purchase_timer:
		return
	_pending_purchase = false
	_purchase_timer = null
	_set_shop_feedback("Sem resposta do host. Tente novamente.")
	_refresh_shop_buttons()


func _on_purchase_result(_upgrade_id: String, _success: bool, message: String) -> void:
	_pending_purchase = false
	_purchase_timer = null
	_set_shop_feedback(message)
	_refresh_shop_buttons()


func _on_upgrades_changed(_levels: Dictionary) -> void:
	_refresh_shop_buttons()
	# Nível do detector mudou: mapas podem ter sido liberados.
	_refresh_map_list()


func _on_sell_test_pressed() -> void:
	var selected_item: ItemData = _get_selected_catalog_item()
	if selected_item == null or _game_state == null:
		return
	_game_state.request_sell_item(selected_item.id, selected_item.base_value)


func _on_register_test_pressed() -> void:
	var selected_item: ItemData = _get_selected_catalog_item()
	if selected_item == null or _game_state == null:
		return
	if _game_state.discovered_items.has(selected_item.id):
		_set_museum_feedback(tr("%s já estava cadastrado no Museu!") % tr(selected_item.display_name))
		return
	_game_state.request_donate_item(selected_item.id)


func _get_selected_catalog_item() -> ItemData:
	if item_select_box == null or _catalog_items.is_empty():
		return null
	var selected_idx: int = item_select_box.selected
	if selected_idx >= 0 and selected_idx < _catalog_items.size():
		return _catalog_items[selected_idx]
	return null


func _refresh_museum_display() -> void:
	if museum_item_list == null:
		return
	
	var selected: PackedInt32Array = museum_item_list.get_selected_items()
	var selected_id: String = str(museum_item_list.get_item_metadata(selected[0])) if not selected.is_empty() else ""
	museum_item_list.clear()
	var discovered: Array[String] = []
	if _game_state != null:
		discovered = _game_state.discovered_items
	
	var filter_id: int = _museum_catalog_filter.get_selected_id() if _museum_catalog_filter != null else MuseumFilter.ALL
	for item: ItemData in _catalog_items:
		var found: bool = discovered.has(item.id)
		if (filter_id == MuseumFilter.DISCOVERED and not found) or (filter_id == MuseumFilter.PENDING and found):
			continue
		var intact: bool = _game_state != null and _game_state.intact_items.has(item.id)
		var index: int = museum_item_list.add_item(museum_line(item, found, intact))
		museum_item_list.set_item_metadata(index, item.id)
		if found:
			museum_item_list.set_item_custom_bg_color(index, Color(UiPalette.GOLD, 0.13) if intact else Color(UiPalette.GREEN_BOTTLE, 0.07))
		else:
			museum_item_list.set_item_custom_fg_color(index, UiPalette.WOOD)
		if item.id == selected_id and not selected_id.is_empty():
			museum_item_list.select(index)

	if _museum_catalog_empty != null:
		var has_items: bool = museum_item_list.item_count > 0
		if not has_items and museum_item_list.has_focus():
			_museum_catalog_filter.grab_focus()
		museum_item_list.visible = has_items
		_museum_catalog_empty.visible = not has_items
		_sync_focus()
		_queue_fit_height()
	if museum_item_list.has_focus() and museum_item_list.is_anything_selected():
		_ensure_museum_selection_visible.call_deferred()

	if tab_container != null:
		var museum_tab: Control = tab_container.get_node_or_null(NodePath(MUSEUM_TAB_NAME)) as Control
		if museum_tab != null:
			var museum_title: String = TAB_SHORT_TITLES[MUSEUM_TAB_NAME]
			if _game_state != null and _game_state.game_completed:
				museum_title = tr(museum_title) + MUSEUM_DONE_MARK
			tab_container.set_tab_title(tab_container.get_tab_idx_from_control(museum_tab), museum_title)
	if museum_feedback_label != null and museum_feedback_label.text.is_empty() and _game_state != null and _game_state.game_completed:
		museum_feedback_label.text = "🏆 Jogo concluído — Modo Museu completo ativo!"


## Linha do Museu. Itens que não são escavados (missão, relíquia escondida, troféu de chefe,
## easter egg) têm depth_cm 0: mostram "Achado especial" no lugar da profundidade.
static func museum_line(item: ItemData, is_found: bool, is_intact: bool = false) -> String:
	var status_str: String = I18n.t("[DESCOBERTO]") if is_found else "[ ? ]"
	var detail: String = I18n.t("Profundidade: %d cm") % item.depth_cm if item.depth_cm > 0 else I18n.t("Achado especial")
	var line: String = I18n.t("%s %s (Valor: %s | %s)") % [status_str, I18n.t(item.display_name), UiFormat.money(item.base_value), detail]
	return line + (I18n.t("  ✦ intacto") if is_intact else "")


func _refresh_secrets_label() -> void:
	if secrets_label == null:
		return
	# "Segredos — Praia 3/6 • Campo Antigo 0/6": contagem por mapa (prefixo do id do segredo).
	# NBSP dentro de cada mapa e antes do "•": se não couber, a linha só quebra entre mapas.
	var found: Array = Array(_game_state.found_secrets) if _game_state != null else []
	var maps: Variant = _session_call(&"get_available_maps", [], [])
	var map_ids: Array = maps as Array if maps is Array else []
	var counts: Dictionary = UiFormat.secret_counts_by_map(found)
	var parts: PackedStringArray = []
	for map_id: String in counts:
		parts.append(UiFormat.secret_count_text(map_id, counts[map_id], map_ids))
	secrets_label.text = tr("Segredos —") + UiFormat.NBSP + (UiFormat.NBSP + "• ").join(parts)
	var seen: int = _game_state.seen_creatures.size() if _game_state != null and "seen_creatures" in _game_state else 0
	secrets_label.text += "\n" + tr("Diário de campo —") + UiFormat.NBSP + tr("%d/%d criaturas") % [seen, GameState.CREATURES.size()]
	if _game_state != null and _game_state.game_completed:
		var museum_found: int = _game_state.discovered_items.size()
		var museum_total: int = _game_state.get_total_catalog_items()
		var secrets_found: int = _game_state.found_secrets.size()
		var secrets_total: int = GameState.SECRETS.size()
		secrets_label.text += "\n" + tr("★ Jogo concluído (Modo Museu completo) — Peças: %d/%d • Segredos: %d/%d • Diário: %d/%d") % [
			museum_found, museum_total,
			secrets_found, secrets_total,
			seen, GameState.CREATURES.size()
		]


func _on_game_completed_changed(_completed: bool) -> void:
	_refresh_secrets_label()
	_refresh_museum_display()
	_refresh_journal_display()


func _on_secret_found(_secret_id: String) -> void:
	_refresh_secrets_label()


func _on_creature_discovered(_kind: String) -> void:
	_refresh_secrets_label()
	_refresh_journal_display()


func _on_state_synced() -> void:
	_refresh_secrets_label()
	_refresh_journal_display()


func _on_state_updated(_amount: int) -> void:
	# Saldo mudou: reavalia quais upgrades e desbloqueios de mapa estão acessíveis.
	_refresh_shop_buttons()
	_refresh_map_list()


func _on_collection_updated(_total_found: int, _max_items: int) -> void:
	_refresh_museum_display()


func _on_item_sold(item_name: String, value: int) -> void:
	_set_museum_feedback(tr("Venda concluída: %s (+%s)") % [tr(item_name), UiFormat.money(value)])


func _on_item_donated(item_name: String, reward: int) -> void:
	_set_museum_feedback(tr("%s doado ao Museu! (+%s de recompensa)") % [tr(item_name), UiFormat.money(reward)])


func _set_shop_feedback(msg: String) -> void:
	if shop_feedback_label != null:
		shop_feedback_label.text = UiFormat.fix_money_spaces(tr(msg))


func _set_museum_feedback(msg: String) -> void:
	if museum_feedback_label != null:
		museum_feedback_label.text = UiFormat.fix_money_spaces(tr(msg))


# --- Conquistas (#141) ---------------------------------------------------------

func _build_achievements_tab() -> void:
	if tab_container == null or tab_container.has_node(AchievementsTab.TAB_NAME):
		return
	achievements_tab = AchievementsTab.new()
	tab_container.add_child(achievements_tab)


# --- Diário de Campo (#86) ----------------------------------------------------

const CREATURE_ORDER: Array[String] = [
	"crab", "hermit_crab", "seagull",
	"snake", "mole", "crow",
	"stone_guardian", "bat",
	"ice_wolf", "penguin", "walrus",
	"crawler", "floater",
]

const CREATURE_FIELD_META: Dictionary = {
	"crab": {"region": "Praia", "color": Color(0.86, 0.34, 0.22)},
	"hermit_crab": {"region": "Praia", "color": Color(0.78, 0.52, 0.26)},
	"seagull": {"region": "Praia", "color": Color(0.88, 0.90, 0.94)},
	"snake": {"region": "Campo", "color": Color(0.42, 0.68, 0.28)},
	"mole": {"region": "Campo", "color": Color(0.52, 0.36, 0.24)},
	"crow": {"region": "Campo", "color": Color(0.26, 0.28, 0.36)},
	"stone_guardian": {"region": "Ruínas", "color": Color(0.64, 0.60, 0.52)},
	"bat": {"region": "Ruínas", "color": Color(0.48, 0.34, 0.58)},
	"ice_wolf": {"region": "Geleira", "color": Color(0.56, 0.78, 0.92)},
	"penguin": {"region": "Geleira", "color": Color(0.24, 0.42, 0.68)},
	"walrus": {"region": "Geleira", "color": Color(0.62, 0.46, 0.38)},
	"crawler": {"region": "Cratera", "color": Color(0.76, 0.28, 0.48)},
	"floater": {"region": "Cratera", "color": Color(0.42, 0.86, 0.74)},
}

const BOSS_ORDER: Array[String] = [
	"king_crab", "giant_mole", "ancient_guardian", "frozen_mammoth",
	"octopus", "crow_king", "scarecrow", "idol_mummy",
	"cave_yeti", "ancient_walrus", "the_sleeper", "the_echo", "lunar_warden",
]

const BOSS_FIELD_META: Dictionary = {
	"king_crab": {"name": "Caranguejo-Rei", "region": "Praia", "color": Color(0.92, 0.28, 0.18)},
	"giant_mole": {"name": "Toupeira Gigante", "region": "Campo", "color": Color(0.62, 0.40, 0.22)},
	"ancient_guardian": {"name": "Guardião Ancestral", "region": "Ruínas", "color": Color(0.78, 0.68, 0.36)},
	"frozen_mammoth": {"name": "Mamute Congelado", "region": "Geleira", "color": Color(0.48, 0.74, 0.92)},
	"octopus": {"name": "Polvo do Abismo", "region": "Praia", "color": Color(0.68, 0.30, 0.56)},
	"crow_king": {"name": "Corvo-Rei", "region": "Campo", "color": Color(0.32, 0.28, 0.46)},
	"scarecrow": {"name": "Espantalho Vivo", "region": "Campo", "color": Color(0.82, 0.58, 0.24)},
	"idol_mummy": {"name": "Múmia do Ídolo", "region": "Ruínas", "color": Color(0.84, 0.74, 0.44)},
	"cave_yeti": {"name": "Yeti da Caverna", "region": "Geleira", "color": Color(0.78, 0.88, 0.96)},
	"ancient_walrus": {"name": "Morsa Anciã", "region": "Geleira", "color": Color(0.58, 0.44, 0.36)},
	"the_sleeper": {"name": "O Adormecido", "region": "Cratera", "color": Color(0.88, 0.32, 0.52)},
	"the_echo": {"name": "O Eco", "region": "Cratera", "color": Color(0.38, 0.90, 0.78)},
	"lunar_warden": {"name": "Guardião do Sinal", "region": "Lua", "color": Color(0.60, 0.23, 0.91)},
}

const JOURNAL_MINI_SIDE: int = 28
const JOURNAL_MINI_SCALE: float = 1.0
const JOURNAL_UNKNOWN_MARK: String = "M19 20Q19 15 24 15Q30 15 30 20Q30 23 27 25L24 28V30M24 34h.1"

# Coordenadas no viewBox 48 × 48: contorno, sombra, luz e detalhes de cada ficha.
const JOURNAL_MINI_PATHS: Dictionary = {
	"crab": [
		"M14 23L10 21Q5 20 6 14L9 11L10 15L14 14L16 18L15 21L18 23Q24 19 31 23L34 20L33 16L36 13L38 16L42 14L42 19Q40 23 35 23L33 25L39 28L40 31L34 29L33 30L38 34L36 36L31 32Q24 37 17 32L12 36L10 34L15 30L9 32L8 29Z",
		"M15 27Q23 30 34 25L34 29Q29 36 20 34Q16 33 15 27Z",
		"M17 25L20 21L22 24Z M26 24L28 21L31 25Z",
		"M21 28h.1M28 27h.1",
	],
	"hermit_crab": [
		"M13 32L8 33L6 31L9 28L7 25L10 21L13 24L12 27L16 27Q12 24 13 17Q14 9 25 9Q35 9 38 18Q41 25 36 30L41 34L39 37L33 34L29 37L25 35L21 37L17 34L13 37L10 36Z",
		"M16 25Q21 31 32 26L38 22Q39 27 34 31L27 34L20 31Z",
		"M16 17Q22 9 30 13L33 17Q24 14 21 20L18 23Z",
		"M33 17Q33 24 25 24Q20 24 21 20Q22 16 27 17Q30 18 27 20M12 28l2-2",
	],
	"seagull": [
		"M6 18Q12 15 18 19L23 23L29 16Q34 12 42 10L40 16L35 20L40 19L34 24L28 27Q27 31 22 32L16 35L17 31L10 32L14 28Q10 27 11 25L7 24L13 22Z",
		"M14 27L24 26L29 22L40 16L35 20L40 19L34 24L28 27Q27 31 22 32L16 35L17 31L10 32Z",
		"M7 24L12 22L15 24L12 26Z M21 23L29 17L36 14L31 19L25 24Z",
		"M15 23h.1M25 27l4-3",
	],
	"snake": [
		"M36 34Q29 36 25 31Q21 27 23 22L28 14Q29 11 25 12L21 17L16 19L10 18L7 14L10 10L19 9L23 7Q32 6 36 13Q39 19 34 23L29 27Q28 29 31 29L40 27Q43 27 41 30Z",
		"M24 9Q34 7 36 14Q38 19 34 23L29 27Q28 29 31 29L36 28L33 32Q25 33 26 27L31 20Q37 13 24 9Z",
		"M7 14L14 14L18 12L21 14L17 17L10 18Z",
		"M15 12h.1M30 16l4 2M27 20l4 3",
	],
	"mole": [
		"M6 33L10 30L11 24Q12 18 18 16Q19 11 27 11Q35 11 39 21L41 27L36 31L41 34L39 37L33 36L30 38L25 35L20 37L15 35L11 37Z",
		"M13 26Q19 32 27 28L37 24L41 27L35 32L39 34L33 35L26 34L19 36L13 33Z",
		"M7 33L11 30L17 32L13 34Z M24 27L31 21L38 24L39 27L35 29L30 28Z",
		"M29 18h.1M35 25h.1M14 32l-2 3",
	],
	"crow": [
		"M7 19L15 17Q16 10 22 10Q28 10 30 16L29 19Q34 22 35 27L42 33L39 34L41 38L34 35L35 39L28 34L24 33L22 37L18 37L20 33Q15 31 15 25L17 22L9 23Z",
		"M17 25L23 21Q29 20 34 27L40 34L35 33L38 37L30 33L26 32L21 33Z",
		"M8 19L17 17L19 20L16 22L9 22Z M22 13L25 14L23 16Z",
		"M19 18h.1M24 25l7 4",
	],
	"stone_guardian": [
		"M7 18L13 15L17 17L17 11L22 7L30 9L33 15L31 18L36 17L41 22L39 31L34 32L33 36L27 38L23 34L19 38L13 36L13 32L8 32L6 25Z",
		"M19 14L27 14L32 12L31 18L28 21L33 24L35 30L32 35L26 37L23 33L19 37L15 35L16 27Z",
		"M19 12L22 8L29 10L26 13Z M20 21L25 19L29 22L25 26Z",
		"M11 22l-2 5M21 16h5M36 23l2 4",
	],
	"bat": [
		"M6 11Q15 12 19 19L20 13L24 17L28 13L29 19Q35 12 42 11L40 20L41 26Q35 24 34 32Q29 29 26 35L24 37L22 35Q18 29 14 32Q12 26 7 27L8 20Z",
		"M7 13Q13 17 15 25L16 30Q12 26 7 27L8 20Z M41 13L40 20L41 26Q35 24 34 32L33 26Z",
		"M19 24L23 25L21 28Z M25 25L29 24L27 28Z M23 30L25 30L24 33Z",
		"M14 18l4 8M34 18l-4 9",
	],
	"ice_wolf": [
		"M7 25L12 18L16 19L20 14L25 15L29 11L33 8L35 15L39 10L40 20L42 23L38 29L33 30L30 37L26 37L26 30L20 29L17 37L13 37L13 29L8 32L6 30L11 25Z",
		"M13 23L24 21L28 17L35 20L40 19L42 23L38 29L33 30L30 37L26 37L26 30L20 29L17 37L13 37L15 28Z",
		"M21 16L26 16L29 12L33 9L34 15L28 19L24 21Z M36 24L42 23L38 28L34 28Z",
		"M36 20h.1M40 24h.1M18 25l5 1",
	],
	"penguin": [
		"M18 12Q22 7 28 9Q32 11 33 16L39 19L34 22Q39 28 38 32L33 30L32 34L37 36L35 39L28 38L25 36L22 39L15 39L12 37L16 34L14 30L9 32L9 28L15 21Z",
		"M17 17Q23 13 30 16L34 22Q38 28 38 32L33 30L32 34L28 37L23 35L18 35Q14 30 15 24Z",
		"M26 16Q32 16 31 22Q33 27 29 33Q24 35 21 31Q18 27 22 22L23 17Z M33 17L38 19L34 21Z",
		"M28 14h.1M13 37l5-1M30 36l4 1",
	],
	"walrus": [
		"M6 30Q8 26 13 24Q14 17 21 15Q25 10 33 12Q37 13 37 18Q42 20 41 23L37 27L37 33L33 37L30 36L29 31L25 34L18 34L13 37L8 36Z",
		"M10 30Q18 29 21 25L25 23L28 28L29 31L25 34L18 34L13 37L8 36Z",
		"M27 22Q30 18 33 20Q37 17 40 21L39 25L36 25L36 32L33 36L33 26L30 25L30 31L27 34L27 26Z",
		"M31 17h.1M36 22h.1M27 23l-3 1M38 24l3 1",
	],
	"crawler": [
		"M6 33L11 25L15 24L13 20L16 14L22 13L25 9L30 15L35 12L34 18L40 19L42 24L39 29L42 33L39 36L34 31L29 32L26 37L22 36L24 31L18 30L13 36L9 35L13 29L11 29L8 35Z",
		"M14 23L20 19L29 20L34 18L40 19L42 24L39 29L33 31L25 32L18 29Z",
		"M18 23Q26 19 32 23L29 27L22 28Z M24 14L25 10L28 15Z M34 25L38 22L39 25L36 28Z",
		"M25 24v2M18 16l2 1",
	],
	"floater": [
		"M8 20L11 15L17 13L18 7L23 12L28 11L31 7L32 13L39 16L42 21L39 26L34 28L36 33L33 38L30 36L31 31L28 28L27 35L23 39L20 36L22 29L18 27L15 32L15 36L11 37L10 32L13 27L9 24Z",
		"M8 20L15 22L22 20L29 22L37 20L42 21L39 26L34 28L27 26L22 29L13 27L9 24Z",
		"M13 21Q13 18 16 18Q19 18 19 21Q19 24 16 24Q13 24 13 21Z M21 21Q21 17 24 17Q27 17 27 21Q27 24 24 24Q21 24 21 21Z M30 22Q30 19 33 19Q36 19 36 22Q36 25 33 25Q30 25 30 22Z",
		"M16 21h.1M24 20h.1M33 22h.1",
	],
	"king_crab": [
		"M6 15L8 10L10 15L14 11L17 16L15 21L19 23L17 15L20 17L24 10L27 17L32 14L30 22L34 20L33 15L36 10L39 15L42 12L42 20L38 24L41 29L39 32L34 28L34 31L40 35L36 37L31 33L27 37L20 37L16 33L11 37L8 35L13 31L13 28L8 32L6 29L10 23L6 21Z",
		"M13 25L20 27L28 25L36 23L34 31L31 33L27 37L20 37L16 33Z",
		"M18 15L21 17L24 11L27 17L31 15L29 20L20 21Z M19 26L23 27L22 30Z M25 27L29 25L27 30Z",
		"M8 20l4-2M36 20l4-2M22 33h4",
	],
	"giant_mole": [
		"M6 29L8 23L14 23L16 16L22 11L31 11L37 15L39 20L42 24L39 29L34 30L41 33L40 37L34 35L33 39L27 36L24 39L20 36L14 38L13 36L7 37L6 33L10 30Z",
		"M8 28L16 26L22 28L29 26L34 23L42 24L39 29L34 30L40 34L39 37L34 35L33 39L27 36L24 39L20 36L14 38Z",
		"M23 24L26 19L34 20L39 23L39 26L33 28L27 27Z M7 33L12 29L16 31L13 34L9 36Z M29 32L34 31L39 34L34 34L33 38Z",
		"M26 16h.1M34 23h.1M31 22l-4 1",
	],
	"ancient_guardian": [
		"M6 22L9 15L14 14L18 17L18 11L21 8L24 10L27 7L32 10L32 16L36 14L41 17L42 24L40 30L34 30L33 36L27 39L24 35L21 39L15 36L14 30L8 31Z",
		"M7 22L15 22L19 17L23 19L30 16L35 21L42 24L40 30L34 30L33 36L27 39L24 35L21 39L15 36L14 30L8 31Z",
		"M19 11L22 9L24 11L27 8L31 11L28 14L21 14Z M24 20L28 25L24 31L20 26Z M10 17L13 16L15 19L10 21Z M35 19L38 16L40 19L38 22Z",
		"M21 16h2M26 16h2M10 26h2M36 26h2",
	],
	"frozen_mammoth": [
		"M6 27L9 18L14 15L17 9L21 14Q29 10 35 15L40 20L39 27L36 29L36 32Q38 34 41 30L42 33Q40 39 35 38L32 35L31 30L28 30L27 37L22 37L21 31L16 31L15 37L10 37L10 30L7 33Z",
		"M7 25L13 23L17 26L24 24L28 19L33 21L39 20L39 27L36 29L36 32Q38 34 41 30L42 33Q40 39 35 38L32 35L31 30L28 30L27 37L22 37L21 31L16 31L15 37L10 37L10 30L7 33Z",
		"M10 20L15 16L17 10L20 15L17 19L13 21Z M30 26Q32 32 37 32L40 29Q38 36 33 34L29 31L27 28Z",
		"M34 22h.1M27 18l-2 5M14 28l-1 2",
	],
	"octopus": [
		"M17 25Q12 21 14 15Q17 8 24 8Q32 8 35 15Q37 21 32 25Q39 29 42 23L42 28Q40 34 34 32Q37 38 40 35L40 38Q33 43 29 33Q29 39 24 40Q20 40 19 36Q23 38 24 31Q20 37 15 37Q9 37 8 32Q13 36 17 30Q9 32 6 26L6 23Q12 29 17 25Z",
		"M15 21Q24 25 34 20L32 25Q39 29 42 23L42 28Q40 34 34 32L36 36L34 37L29 30L27 33L23 31L19 34L15 33L17 30Q9 32 6 26L6 23Q12 29 17 25Z",
		"M18 14Q21 10 26 11L29 13L23 15L18 18Z M17 20L22 21L20 24Z M26 21L31 19L30 23Z",
		"M21 26q3 1 6-1M13 29h.1M36 30h.1",
	],
	"crow_king": [
		"M6 16L11 18L14 12L18 17L22 14L22 18L25 17L29 18L28 9L32 13L35 8L36 15L40 12L39 18L42 21L38 25L39 28L35 28L38 33L34 32L35 38L29 34L28 38L25 34L23 38L19 38L20 33Q13 30 13 27L10 29L11 25L7 25L8 21Z",
		"M11 21L19 23L23 20L29 21L32 19L38 20L42 21L38 25L39 28L35 28L38 33L34 32L35 38L29 34L28 38L25 34L23 38L19 38L20 33Q15 30 13 27L10 29L11 25L7 25Z",
		"M28 9L32 13L35 8L36 15L40 12L39 17L30 17Z M35 21L41 21L38 25L35 24Z",
		"M34 19h.1M17 22l4 7M20 22l5 6",
	],
	"scarecrow": [
		"M7 19L13 19L17 18L12 15L16 13L20 12L22 7L29 8L34 14L38 16L34 19L29 19L30 22L36 22L41 20L42 23L39 26L37 25L33 29L29 29L29 34L26 37L23 35L22 40L19 39L19 34L16 35L17 28L13 26L11 25L8 27L6 24Z",
		"M14 22L20 24L24 22L30 22L36 22L41 20L42 23L39 26L37 25L33 29L29 29L29 34L26 37L23 35L21 36L22 30L18 27Z",
		"M21 17L28 16L31 19L29 23L26 25L21 23Z M18 12L22 8L28 9L30 12L24 13Z",
		"M22 20h.1M27 19h.1M23 23l4-1M16 25l3-2",
	],
	"idol_mummy": [
		"M9 34L11 24L16 21L16 14L20 10L27 7L33 12L34 19L38 20L42 26L39 31L34 29L32 36L26 39L23 36L18 39L14 36L12 37Z",
		"M20 14L25 12L32 13L34 19L38 20L42 26L39 31L34 29L32 36L26 39L23 36L18 39L16 36L18 26L22 23Z",
		"M18 14L26 8L32 12L25 13Z M18 18L33 15L34 18L22 22L18 21Z M15 26L26 24L30 27L20 31L14 30Z M18 34L29 31L30 34L21 37Z",
		"M21 16l7-1M29 21l3-1M36 24l4 2",
	],
	"cave_yeti": [
		"M6 26L10 19L15 17L17 13L16 9L20 12L24 9L28 12L33 8L32 15L36 17L42 25L40 31L36 33L33 29L31 35L26 40L23 36L19 39L15 35L14 30L10 34L7 31Z",
		"M7 25L15 24L18 18L23 22L29 19L34 22L41 25L40 31L36 33L33 29L31 35L26 40L23 36L19 39L15 35L14 30L10 34L7 31Z",
		"M19 19L24 16L30 19L31 25L27 28L22 27L18 24Z M8 29l4-4 2 4-4 4Z M35 28l4-2 1 3-3 3Z",
		"M21 21h.1M27 21h.1M22 25l5-1",
	],
	"ancient_walrus": [
		"M6 31Q8 28 13 27Q13 20 19 18L16 13L22 15L26 8L29 14L34 11L34 17L39 19L42 24L39 29L38 35L34 39L31 38L31 32L28 33L24 37L18 36L14 39L8 38Z",
		"M7 32L16 29L20 24L25 23L28 26L31 29L31 32L28 33L24 37L18 36L14 39L8 38Z",
		"M17 14L22 16L26 9L29 15L33 12L33 17L23 19Z M26 24L32 22L37 21L41 24L38 28L37 34L34 38L34 27L31 28L30 34L27 37L27 28Z",
		"M29 20h.1M34 24h.1M25 27l-4 1M38 26l3 1",
	],
	"the_sleeper": [
		"M6 32L9 24L13 22L12 16L16 19L18 13L21 17L24 7L28 15L33 10L34 18L38 17L37 22L41 26L42 34L38 38L34 35L32 37L28 34L25 38L20 35L15 38L14 34L10 38Z",
		"M8 30L14 26L21 24L24 18L28 21L34 20L41 26L42 34L38 38L34 35L32 37L28 34L25 38L20 35L15 38L14 34L10 38Z",
		"M24 8L27 15L24 18L22 15Z M29 18L33 11L34 18L32 20Z M24 22L29 27L25 33L20 28Z M14 25L17 23L18 27L14 29Z",
		"M10 32l4-3M34 29l4 4M23 27l2-1",
	],
	"the_echo": [
		"M7 23L10 19L12 24L9 28Z M10 10L16 13L18 18L22 15L25 18L30 15L32 9L38 7L36 16L33 19L35 24L32 29L29 30L28 35L24 38L20 35L19 30L15 28L13 24L15 19L11 16Z M38 23L42 21L41 28L37 31Z M12 31L16 33L14 37L10 35Z M32 34L36 32L38 36L34 39Z",
		"M14 22L20 24L24 20L29 24L35 24L32 29L29 30L28 35L24 38L20 35L19 30L15 28Z",
		"M11 11L16 14L17 18L13 16Z M33 11L37 8L35 15L32 18Z M16 22L22 23L20 27L17 26Z M26 23L32 21L31 26L28 27Z M23 30L26 31L24 35Z",
		"M24 26v2",
	],
	"lunar_warden": [
		"M7 19L11 13L16 15L17 12L22 11L24 7L29 11L33 12L34 15L39 13L42 18L41 26L38 31L34 29L31 35L27 36L24 40L21 36L16 35L14 29L10 31L6 26Z",
		"M9 20L15 22L18 18L24 20L31 17L35 21L42 18L41 26L38 31L34 29L31 35L27 36L24 40L21 36L16 35L14 29L10 31L6 26Z",
		"M20 12L24 8L28 12L24 16Z M24 18L31 23L29 30L24 34L19 30L17 23Z M9 19L11 15L14 17L12 22Z M35 16L38 14L40 18L37 21Z",
		"M24 22l3 4-3 4-3-4z M13 24l1 2M36 24l-1 2",
	],
}
static var _journal_mini_cache: Dictionary = {}


var _journal_slot_labels: Dictionary = {}
var _boss_slot_labels: Dictionary = {}


func _refresh_journal_display() -> void:
	if journal_grid == null:
		return

	for child: Node in journal_grid.get_children():
		journal_grid.remove_child(child)
		child.queue_free()
	_journal_slot_labels.clear()

	var seen_list: Array = Array(_game_state.seen_creatures) if _game_state != null and "seen_creatures" in _game_state else []
	var defeated_list: Array = Array(_game_state.defeated_bosses) if _game_state != null and "defeated_bosses" in _game_state else []

	var seen_count: int = 0
	for kind: String in CREATURE_ORDER:
		if not GameState.CREATURES.has(kind):
			continue
		var is_seen: bool = seen_list.has(kind)
		if is_seen:
			seen_count += 1
		var creature_name: String = tr(str(GameState.CREATURES[kind]))
		var meta: Dictionary = CREATURE_FIELD_META.get(kind, {"region": "Sítio", "color": Color(0.7, 0.6, 0.4)})
		var region: String = tr(str(meta.get("region", "Sítio")))
		var accent: Color = meta.get("color", Color(0.7, 0.6, 0.4))
		var title_line: String = creature_name if is_seen else "???"
		var sub_line: String = tr("%s • Catalogado") % region if is_seen else tr("%s • Por avistar") % region
		var slot: PanelContainer = _build_journal_slot(kind, title_line, sub_line, is_seen, accent, false)
		journal_grid.add_child(slot)

	if journal_info_label != null:
		journal_info_label.text = tr("Caderno de Campo — Fauna dos Sítios (%d/%d) e Guardiões Abatidos:") % [seen_count, GameState.CREATURES.size()]

	if bosses_grid != null:
		for child: Node in bosses_grid.get_children():
			bosses_grid.remove_child(child)
			child.queue_free()
		_boss_slot_labels.clear()

		var defeated_count: int = 0
		for boss_id: String in BOSS_ORDER:
			var is_defeated: bool = defeated_list.has(boss_id)
			if is_defeated:
				defeated_count += 1
			var bmeta: Dictionary = BOSS_FIELD_META.get(boss_id, {"name": boss_id, "region": "Sítio", "color": Color(0.8, 0.4, 0.2)})
			var bname: String = tr(str(bmeta.get("name", boss_id)))
			var bregion: String = tr(str(bmeta.get("region", "Sítio")))
			var bcolor: Color = bmeta.get("color", Color(0.8, 0.4, 0.2))
			var btitle: String = "✔ %s" % bname if is_defeated else "???"
			var bsub: String = tr("%s • Vencido") % bregion if is_defeated else tr("%s • Guardião") % bregion
			var bslot: PanelContainer = _build_journal_slot(boss_id, btitle, bsub, is_defeated, bcolor, true)
			bosses_grid.add_child(bslot)

		if bosses_header_label != null:
			bosses_header_label.text = tr("Guardiões e Chefes de Sítio (%d/%d):") % [defeated_count, BOSS_ORDER.size()]


func _build_journal_slot(id: String, title_text: String, sub_text: String, discovered: bool, accent: Color, is_boss: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = ("BossSlot_" if is_boss else "JournalSlot_") + id
	card.theme_type_variation = &"InsetPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(150, 44)
	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.bg_color = UiPalette.PAPER_LIGHT if discovered else UiPalette.PAPER
	frame.border_color = Color(UiPalette.WOOD, 0.75 if discovered else 0.45)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(4)
	card.add_theme_stylebox_override(&"panel", frame)
	if discovered:
		frame.border_width_left = 4
		# StyleBoxFlat usa uma só cor de borda. Desenha a borda de destaque à esquerda por cima.
		var accent_border: StyleBoxFlat = StyleBoxFlat.new()
		accent_border.draw_center = false
		accent_border.border_width_left = 4
		accent_border.border_color = accent.darkened(0.1).lerp(UiPalette.INK, 0.35)
		accent_border.set_corner_radius_all(4)
		card.draw.connect(func() -> void:
			card.draw_style_box(accent_border, Rect2(Vector2.ZERO, card.size)))
		card.resized.connect(card.queue_redraw)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 2)
	card.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.name = "MiniIcon"
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.texture = _build_journal_mini_texture(id, discovered, accent, is_boss)
	row.add_child(icon_rect)

	var lbl: Label = Label.new()
	lbl.name = "SlotLabel"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.text = "%s\n%s" % [title_text, sub_text]
	# A grade rola na vertical: texto longo ganha linhas, sem reduzir a legibilidade.
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not discovered:
		lbl.add_theme_color_override(&"font_color", UiPalette.WOOD)
	row.add_child(lbl)

	if is_boss:
		_boss_slot_labels[id] = lbl
	else:
		_journal_slot_labels[id] = lbl
	return card


static func _build_journal_mini_texture(id: String, discovered: bool, accent: Color, is_boss: bool) -> ImageTexture:
	var paths: Array = JOURNAL_MINI_PATHS.get(id, []) if discovered else []
	var shape_known: bool = not paths.is_empty()
	var plate_key: String = "boss" if is_boss else "fauna"
	var cache_key: String = plate_key + ":" + (id + ":" + accent.to_html(false) if shape_known else "?")
	var cached: ImageTexture = _journal_mini_cache.get(cache_key) as ImageTexture
	if cached != null:
		return cached

	var paper: Color = UiPalette.PAPER_LIGHT if shape_known else UiPalette.PAPER_DARK
	var rim: Color = UiPalette.GOLD if is_boss else accent
	var border: Color = UiPalette.INK if shape_known else UiPalette.WOOD
	if not shape_known:
		rim = UiPalette.WOOD.lerp(UiPalette.PAPER_DARK, 0.55)

	var drawing: String
	if shape_known:
		var shade: Color = accent.lerp(UiPalette.INK, 0.36)
		var light: Color = accent.lerp(UiPalette.PAPER_LIGHT, 0.66)
		drawing = (
			"<path d=\"%s\" fill=\"#%s\" stroke=\"#%s\" stroke-width=\"1.8\" stroke-linejoin=\"round\"/>"
			+ "<path d=\"%s\" fill=\"#%s\"/><path d=\"%s\" fill=\"#%s\"/>"
			+ "<path d=\"%s\" fill=\"none\" stroke=\"#%s\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
		) % [paths[0], accent.to_html(false), border.to_html(false), paths[1], shade.to_html(false),
			paths[2], light.to_html(false), paths[3], border.to_html(false)]
	else:
		# A ficha fechada não revela a espécie pelo contorno ou pela cor.
		drawing = (
			"<path d=\"M24 10L35 16L39 26L34 34L24 39L14 34L9 26L13 16Z\" fill=\"#%s\"/>"
			+ "<path d=\"%s\" fill=\"none\" stroke=\"#%s\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
		) % [UiPalette.WOOD_DARK.to_html(false), JOURNAL_UNKNOWN_MARK, UiPalette.PAPER_LIGHT.to_html(false)]

	var svg: String = (
		"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 48 48\">"
		+ "<rect x=\"1.5\" y=\"1.5\" width=\"45\" height=\"45\" rx=\"6\" fill=\"#%s\" stroke=\"#%s\" stroke-width=\"2\"/>"
		+ "<rect x=\"4\" y=\"4\" width=\"40\" height=\"40\" rx=\"4\" fill=\"none\" stroke=\"#%s\"/>%s</svg>"
	) % [JOURNAL_MINI_SIDE, JOURNAL_MINI_SIDE, paper.to_html(false), border.to_html(false),
		rim.to_html(false), drawing]
	var image: Image = Image.new()
	if image.load_svg_from_string(svg, JOURNAL_MINI_SCALE) != OK or image.is_empty():
		push_warning("BaseStationUI: falha ao renderizar miniatura do Diário (%s)." % id)
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	# O Caderno usa o tamanho lógico da textura para calcular a largura dos botões.
	texture.set_size_override(Vector2i(JOURNAL_MINI_SIDE, JOURNAL_MINI_SIDE))
	_journal_mini_cache[cache_key] = texture
	return texture


func get_journal_creature_count() -> int:
	return journal_grid.get_child_count() if journal_grid != null else 0


func get_journal_slot_text(kind: String) -> String:
	var lbl: Label = _journal_slot_labels.get(kind, null) as Label
	return lbl.text if lbl != null else ""


func get_boss_slot_text(boss_id: String) -> String:
	var lbl: Label = _boss_slot_labels.get(boss_id, null) as Label
	return lbl.text if lbl != null else ""

