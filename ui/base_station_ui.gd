class_name BaseStationUI
extends Control

## Painel da Base/Tenda contendo Loja de Equipamentos, Museu de Achados e Expedições.

@onready var tab_container: TabContainer = _resolve_node("TabContainer", "PanelContainer/MarginContainer/VBoxContainer/TabContainer") as TabContainer

# Loja
@onready var buy_detector_btn: Button = _resolve_node("BuyDetectorButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/BuyDetectorButton") as Button
@onready var buy_pinpointer_btn: Button = _resolve_node("BuyPinpointerButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/BuyPinpointerButton") as Button
@onready var buy_shovel_btn: Button = _resolve_node("BuyShovelButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/BuyShovelButton") as Button
@onready var buy_backpack_btn: Button = _resolve_node("BuyBackpackButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/BuyBackpackButton") as Button
@onready var shop_feedback_label: Label = _resolve_node("ShopFeedbackLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/ShopFeedbackLabel") as Label

# Museu
@onready var museum_item_list: ItemList = _resolve_node("MuseumItemList", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/MuseumItemList") as ItemList
@onready var item_select_box: OptionButton = _resolve_node("ItemSelectBox", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/HBoxContainer/ItemSelectBox") as OptionButton
@onready var sell_item_btn: Button = _resolve_node("SellItemButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/HBoxContainer/SellItemButton") as Button
@onready var register_item_btn: Button = _resolve_node("RegisterItemButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/HBoxContainer/RegisterItemButton") as Button
@onready var secrets_label: Label = _resolve_node("SecretsLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/SecretsLabel") as Label
@onready var museum_feedback_label: Label = _resolve_node("MuseumFeedbackLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/MuseumFeedbackLabel") as Label

# Expedições
@onready var map_list: ItemList = _resolve_node("MapList", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Expedições/MapList") as ItemList
@onready var unlock_map_btn: Button = _resolve_node("UnlockMapButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Expedições/UnlockMapButton") as Button
@onready var depart_btn: Button = _resolve_node("DepartButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Expedições/DepartButton") as Button
@onready var map_status_label: Label = _resolve_node("MapStatusLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Expedições/MapStatusLabel") as Label
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

var _purchase_timer: SceneTreeTimer = null
var _pending_unlock: bool = false
var _unlock_timer: SceneTreeTimer = null

## Rótulos curtos das abas (nome do nó -> rótulo): com os nomes completos a TabBar passava
## da largura da Base e aparecia a seta, com a Loja fora da vista. O nome do nó (usado nos
## caminhos do _resolve_node e no ui_tab dos bots) fica igual e vira a dica (tooltip) da aba.
const TAB_SHORT_TITLES: Dictionary = {
	"Loja de Equipamentos": "Loja",
	"Museu de Achados": "Museu",
	"Expedições": "Expedições",
	"Diário": "Diário",
	AchievementsTab.TAB_NAME: "Conquistas",
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
	_apply_tab_titles()
	# Borda de foco só navegando por teclado/comando; com o mouse, nada aceso (#122).
	UiFocus.follow_pointer(get_node_or_null(^"PanelContainer") as Control)
	add_to_group(UiFocus.HOME_GROUP)
	_resolve_game_state()
	_setup_expeditions()
	if tab_container != null:
		tab_container.resized.connect(_sync_hidden_tab_widths)
		tab_container.tab_changed.connect(func(_tab: int) -> void:
			_sync_hidden_tab_widths()
			_queue_fit_height())
		_sync_hidden_tab_widths.call_deferred()
		_focus_initial.call_deferred()
		get_viewport().size_changed.connect(_queue_fit_height)
		_queue_fit_height()


## Idioma trocado (#131): os textos fixos (abas, botões da cena) se traduzem sozinhos; as linhas
## montadas aqui (mapas, loja, museu, segredos, mapa do tesouro, diário) são refeitas.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fill_item_select_box()
		_refresh_map_list()
		_refresh_shop_buttons()
		_refresh_museum_display()
		_refresh_secrets_label()
		_refresh_journal_display()


## Rótulos curtos + nome completo na dica de cada aba.
func _apply_tab_titles() -> void:
	if tab_container == null:
		return
	var bar: TabBar = tab_container.get_tab_bar()
	for i: int in tab_container.get_tab_count():
		var page_name: String = tab_container.get_tab_control(i).name
		if TAB_SHORT_TITLES.has(page_name):
			tab_container.set_tab_title(i, TAB_SHORT_TITLES[page_name])
			bar.set_tab_tooltip(i, page_name)


## Comando/teclado (#102): a base abre com o foco na aba atual (no coop o menu de rede pega o
## foco primeiro). LB/RB (ou Ctrl+Tab) trocam de aba, se nenhum menu estiver por cima.
func _focus_initial() -> void:
	if SessionManager.launch_mode == SessionManager.LAUNCH_COOP or not is_visible_in_tree() or UiFocus.modal_open():
		return
	UiFocus.focus_tab_page(tab_container)


## Teclado/comando (#135): botões desativados (Comprar sem saldo, Partir bloqueado...) saem da
## navegação e a corrente da aba atual é refeita, para o que voltou a ficar ativo entrar de novo.
func _sync_focus() -> void:
	var buttons: Array = [unlock_map_btn, depart_btn, night_check, sell_item_btn, register_item_btn]
	for upgrade_id: String in SHOP_BUTTONS:
		buttons.append(_get_shop_button(upgrade_id))
	UiFocus.skip_disabled(buttons)
	if tab_container != null and tab_container.is_visible_in_tree():
		UiFocus.link_chain(UiFocus.focusables(tab_container.get_current_tab_control()))


## Uma camada por cima fechou sem foco para devolver (resumo do dia, #135): foco na aba atual.
func focus_home() -> void:
	if tab_container != null and is_visible_in_tree() and not PauseMenu.is_open() and not VictoryScreen.is_open():
		UiFocus.focus_tab_page(tab_container)


func _unhandled_input(event: InputEvent) -> void:
	if tab_container == null or not is_visible_in_tree() or PauseMenu.is_open() or VictoryScreen.is_open():
		return
	var step: int = UiFocus.tab_step(event)
	if step != 0:
		UiFocus.step_tab(tab_container, step)
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
	var refresh_one_arg: Callable = _refresh_expedition_buttons.unbind(1)
	if map_list != null:
		map_list.item_selected.connect(refresh_one_arg)
	if unlock_map_btn != null:
		unlock_map_btn.pressed.connect(_on_unlock_map_pressed)
	if depart_btn != null:
		depart_btn.pressed.connect(_on_depart_pressed)
		_build_night_check()
	if _session != null:
		for sig: StringName in [&"expedition_started", &"expedition_ended", &"scene_changing"]:
			if _session.has_signal(sig):
				_session.connect(sig, refresh_one_arg)
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
			map_list.add_item(_format_map_details(map))
			continue
		var idx: int = map_list.add_item(_format_map_row(map, status))
		map_list.set_item_tooltip(idx, UiFormat.fix_money_spaces(tr(str(status.get("reason", "")))))
		if not bool(status.get("playable", false)):
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
	return tr("%s  •  Detector nível %d  •  %d pontos") % [_map_name(map), map.required_detector_level, map.spot_count]


func _format_map_row(map: MapData, status: Dictionary) -> String:
	if bool(status.get("playable", false)):
		return "✔ " + _format_map_details(map)
	if not bool(status.get("unlocked", false)):
		var row: String = "🔒 %s  •  %s" % [_map_name(map), UiFormat.money(int(status.get("unlock_cost", 0)))]
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
	if bool(_session_call(&"is_in_expedition", [], false)):
		return "Já existe uma expedição em andamento."
	if not _is_host():
		return "Apenas o host pode iniciar a expedição."
	var status: Dictionary = _get_map_status(map)
	if not status.is_empty():
		return str(status.get("reason", ""))
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
	map_status_label.text = "🔒 " + UiFormat.fix_money_spaces(tr(reason)) if not reason.is_empty() else ""


func _get_map_status_reason(map: MapData) -> String:
	if map == null:
		return ""
	var status: Dictionary = _get_map_status(map)
	if status.is_empty():
		return _get_depart_block_reason(map)
	if not bool(status.get("unlocked", true)):
		return "" if bool(status.get("can_unlock", false)) else str(status.get("reason", ""))
	return _get_depart_block_reason(map)


func _can_request_unlock() -> bool:
	return _game_state != null and _game_state.has_method(&"request_unlock_map")


func _refresh_unlock_button() -> void:
	if unlock_map_btn == null:
		return
	var map: MapData = _get_selected_map()
	var status: Dictionary = _get_map_status(map)
	if status.is_empty() or bool(status.get("unlocked", true)) or not _can_request_unlock():
		unlock_map_btn.visible = false
		return
	unlock_map_btn.visible = true
	unlock_map_btn.text = tr("Desbloquear %s (%s)") % [_map_name(map), UiFormat.money(int(status.get("unlock_cost", 0)))]
	unlock_map_btn.disabled = _pending_unlock or not bool(status.get("can_unlock", false))
	unlock_map_btn.tooltip_text = UiFormat.fix_money_spaces(tr(str(status.get("reason", "")))) if unlock_map_btn.disabled else ""
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
	_session_call(&"request_start_expedition", [map.id, night])


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
	
	# Ordena pelo nome para exibição consistente
	_catalog_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.display_name < b.display_name
	)
	if _catalog_items.is_empty():
		push_warning("BaseStationUI: catálogo '%s' sem nenhum ItemData (.tres)." % catalog_dir)
		_mark_catalog_unavailable("Catálogo de itens vazio.")


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
	if sell_item_btn != null:
		sell_item_btn.pressed.connect(_on_sell_test_pressed)
	if register_item_btn != null:
		register_item_btn.pressed.connect(_on_register_test_pressed)
	_build_view_museum_button()


## Itens do catálogo na caixa de teste do Museu (nome no idioma atual; a seleção fica).
func _fill_item_select_box() -> void:
	if item_select_box == null:
		return
	var selected: int = item_select_box.selected
	item_select_box.clear()
	for i in range(_catalog_items.size()):
		var item: ItemData = _catalog_items[i]
		item_select_box.add_item("%s (%s)" % [tr(item.display_name), UiFormat.money(item.base_value)], i)
	if selected >= 0 and selected < item_select_box.item_count:
		item_select_box.select(selected)


## "Catálogo..." e o botão "Ver museu" na mesma linha (a aba não fica mais alta).
func _build_view_museum_button() -> void:
	if museum_item_list == null:
		return
	var page: Control = museum_item_list.get_parent() as Control
	var info: Label = page.get_node_or_null(^"MuseumInfoLabel") as Label
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
	
	museum_item_list.clear()
	var discovered: Array[String] = []
	if _game_state != null:
		discovered = _game_state.discovered_items
	
	for item in _catalog_items:
		var intact: bool = _game_state != null and _game_state.intact_items.has(item.id)
		museum_item_list.add_item(museum_line(item, discovered.has(item.id), intact))

	if tab_container != null and tab_container.get_tab_count() > 1:
		var museum_title: String = TAB_SHORT_TITLES.get(String(tab_container.get_tab_control(1).name), "Museu")
		if _game_state != null and _game_state.game_completed:
			museum_title = tr(museum_title) + MUSEUM_DONE_MARK
		tab_container.set_tab_title(1, museum_title)
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


## Linha mais larga que o card (ex.: "Ilha do Tesouro • Guardião" na grade de 3 colunas): a fonte
## desce até 10 antes de cair nas reticências (#146).
func _shrink_slot_label(lbl: Label, base_size: int) -> void:
	var font: Font = lbl.get_theme_font(&"font")
	var font_size: int = base_size
	while font_size > 10:
		var widest: float = 0.0
		for line: String in lbl.text.split("
"):
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		if widest <= lbl.size.x:
			break
		font_size -= 1
	lbl.add_theme_font_size_override(&"font_size", font_size)


func _build_journal_slot(id: String, title_text: String, sub_text: String, discovered: bool, accent: Color, is_boss: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = ("BossSlot_" if is_boss else "JournalSlot_") + id
	card.theme_type_variation = &"WornPanel"
	card. size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(150, 44)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var icon_rect := TextureRect.new()
	icon_rect.name = "MiniIcon"
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _build_journal_mini_texture(id, discovered, accent, is_boss)
	row.add_child(icon_rect)

	var lbl := Label.new()
	lbl.name = "SlotLabel"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.text = "%s\n%s" % [title_text, sub_text]
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.resized.connect(_shrink_slot_label.bind(lbl, 13))
	if not discovered:
		lbl.modulate = Color(0.68, 0.64, 0.58, 0.92)
	row.add_child(lbl)

	if is_boss:
		_boss_slot_labels[id] = lbl
	else:
		_journal_slot_labels[id] = lbl
	return card


static func _build_journal_mini_texture(id: String, discovered: bool, accent: Color, is_boss: bool) -> ImageTexture:
	var tex_size: int = 28
	var img: Image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var bg: Color = Color(0.20, 0.16, 0.12, 0.95) if discovered else Color(0.11, 0.09, 0.08, 0.95)
	var border: Color = accent.lightened(0.18) if discovered else Color(0.28, 0.24, 0.20, 0.85)
	var body_col: Color = accent if discovered else Color(0.04, 0.04, 0.05, 0.96)
	img.fill(bg)

	# Moldura tipo ficha de campo
	for i in range(tex_size):
		img.set_pixel(i, 0, border)
		img.set_pixel(i, tex_size - 1, border)
		img.set_pixel(0, i, border)
		img.set_pixel(tex_size - 1, i, border)

	# Silhueta / miniatura estilizada (variada por hash do id para dar forma própria a cada espécie)
	var h: int = absi(id.hash())
	var rx: float = 7.0 + float(h % 3)
	var ry: float = 6.0 + float(int(h / 3.0) % 3)
	var cx: float = 13.5
	var cy: float = 14.5
	for y in range(4, tex_size - 4):
		for x in range(4, tex_size - 4):
			var dx: float = (float(x) - cx) / rx
			var dy: float = (float(y) - cy) / ry
			var d2: float = dx * dx + dy * dy
			if d2 <= 1.0:
				img.set_pixel(x, y, body_col)
			elif is_boss and y <= 8 and absf(float(x) - cx) <= 6.0 and ((x + y) % 2 == 0):
				# Coroa/crista de guardião
				img.set_pixel(x, y, border if discovered else body_col)

	if discovered:
		var eye_col := Color(0.98, 0.96, 0.88, 1.0)
		img.set_pixel(11, 13, eye_col)
		img.set_pixel(16, 13, eye_col)
	else:
		# Ponto de interrogação central na silhueta escura
		var q_col := Color(0.56, 0.50, 0.42, 0.9)
		for px in range(12, 16):
			img.set_pixel(px, 10, q_col)
		img.set_pixel(15, 11, q_col)
		img.set_pixel(14, 12, q_col)
		img.set_pixel(13, 13, q_col)
		img.set_pixel(13, 14, q_col)
		img.set_pixel(13, 17, q_col)

	return ImageTexture.create_from_image(img)


func get_journal_creature_count() -> int:
	return journal_grid.get_child_count() if journal_grid != null else 0


func get_journal_slot_text(kind: String) -> String:
	var lbl: Label = _journal_slot_labels.get(kind, null) as Label
	return lbl.text if lbl != null else ""


func get_boss_slot_text(boss_id: String) -> String:
	var lbl: Label = _boss_slot_labels.get(boss_id, null) as Label
	return lbl.text if lbl != null else ""

