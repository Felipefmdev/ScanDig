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

const SESSION_PATH: NodePath = ^"/root/CoreSession"

var _session: Node = null
var _maps: Array[MapData] = []

var _game_state: GameState = null
var _catalog_items: Array[ItemData] = []
var _pending_purchase: bool = false

const SHOP_BUTTONS: Array[String] = ["detector", "pinpointer", "shovel", "backpack"]
## Capacidade base da mochila usada quando o GameState ainda não define
## BASE_BACKPACK_CAPACITY (core antigo). Lida via mapa de constantes para não
## quebrar a análise estática enquanto a constante não existir.
const DEFAULT_BACKPACK_BASE: int = 3
const WAITING_GAME_STATE_TOOLTIP: String = "Aguardando conexão com o estado do jogo..."
## Tempo máximo aguardando purchase_result antes de liberar os botões novamente.
const PURCHASE_TIMEOUT_SEC: float = 5.0

var _purchase_timer: SceneTreeTimer = null
var _pending_unlock: bool = false
var _unlock_timer: SceneTreeTimer = null

## Cor das linhas de mapas que ainda não podem ser jogados.
const MAP_LOCKED_COLOR: Color = UiPalette.METAL


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
	_resolve_game_state()
	_setup_expeditions()
	if tab_container != null:
		tab_container.resized.connect(_sync_hidden_tab_widths)
		tab_container.tab_changed.connect(func(_tab: int) -> void: _sync_hidden_tab_widths())
		_sync_hidden_tab_widths.call_deferred()


## Layout: a Base tem a altura da maior aba (use_hidden_tabs_for_min_size). O TabContainer
## não dimensiona as abas ocultas, e um Container oculto não reorganiza os filhos; sem
## largura, os Labels com quebra de linha mediriam uma letra por linha e a Base ficaria
## gigante até cada aba ser aberta. Aqui os Labels com quebra das abas ocultas recebem a
## largura da aba atual (as abas são VBox sem margem, então é a largura deles).
func _sync_hidden_tab_widths() -> void:
	var current: Control = tab_container.get_current_tab_control()
	if current == null:
		return
	for i in range(tab_container.get_tab_count()):
		var page: Control = tab_container.get_tab_control(i)
		if page == current:
			continue
		for child: Node in page.get_children():
			var label: Label = child as Label
			if label != null and label.autowrap_mode != TextServer.AUTOWRAP_OFF and not is_equal_approx(label.size.x, current.size.x):
				label.size = Vector2(current.size.x, label.size.y)
				label.update_minimum_size()


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
		map_list.set_item_tooltip(idx, UiFormat.fix_money_spaces(str(status.get("reason", ""))))
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
	return map.display_name if not map.display_name.is_empty() else map.id


func _format_map_details(map: MapData) -> String:
	return "%s  •  Detector nível %d  •  %d pontos" % [_map_name(map), map.required_detector_level, map.spot_count]


func _format_map_row(map: MapData, status: Dictionary) -> String:
	if bool(status.get("playable", false)):
		return "✔ " + _format_map_details(map)
	if not bool(status.get("unlocked", false)):
		var row: String = "🔒 %s  •  %s" % [_map_name(map), UiFormat.money(int(status.get("unlock_cost", 0)))]
		var boss_name: String = str(status.get("required_boss_name", ""))
		if not boss_name.is_empty():
			row += "  •  Chefe: %s" % boss_name
			if bool(status.get("boss_defeated", false)):
				row += " ✔"
		return row
	if not bool(status.get("has_scene", false)):
		return "%s  •  Em breve" % _map_name(map)
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
		return "Requer detector nível %d." % map.required_detector_level
	return ""


func _refresh_expedition_buttons() -> void:
	_refresh_unlock_button()
	_refresh_depart_button()
	_refresh_map_status_label()


## Motivo visível (sem passar o mouse) de não poder desbloquear ou partir para o mapa selecionado.
## Some quando dá para desbloquear ou partir; os tooltips continuam.
func _refresh_map_status_label() -> void:
	if map_status_label == null:
		return
	var reason: String = _get_map_status_reason(_get_selected_map())
	map_status_label.visible = not reason.is_empty()
	map_status_label.text = "🔒 " + UiFormat.fix_money_spaces(reason) if not reason.is_empty() else ""


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
	unlock_map_btn.text = "Desbloquear %s (%s)" % [_map_name(map), UiFormat.money(int(status.get("unlock_cost", 0)))]
	unlock_map_btn.disabled = _pending_unlock or not bool(status.get("can_unlock", false))
	unlock_map_btn.tooltip_text = UiFormat.fix_money_spaces(str(status.get("reason", ""))) if unlock_map_btn.disabled else ""


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


func _refresh_depart_button() -> void:
	if depart_btn == null:
		return
	var map: MapData = _get_selected_map()
	var reason: String = _get_depart_block_reason(map)
	depart_btn.disabled = not reason.is_empty()
	depart_btn.tooltip_text = UiFormat.fix_money_spaces(reason)
	depart_btn.text = "Partir para %s" % _map_name(map) if map != null else "Partir"


func _on_depart_pressed() -> void:
	var map: MapData = _get_selected_map()
	var reason: String = _get_depart_block_reason(map)
	if not reason.is_empty():
		_set_expedition_feedback(reason)
		return
	depart_btn.disabled = true
	_set_expedition_feedback("Preparando expedição para %s..." % _map_name(map))
	_session_call(&"request_start_expedition", [map.id])


func _set_expedition_feedback(msg: String) -> void:
	if expedition_feedback_label != null:
		expedition_feedback_label.text = UiFormat.fix_money_spaces(msg)


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
		_connect_game_state_signal(&"state_synced", _refresh_secrets_label)
	
	_refresh_museum_display()
	_refresh_secrets_label()
	_refresh_shop_buttons()


func _connect_game_state_signal(signal_name: StringName, callable: Callable) -> void:
	if _game_state.has_signal(signal_name) and not _game_state.is_connected(signal_name, callable):
		_game_state.connect(signal_name, callable)


func _load_catalog() -> void:
	_catalog_items.clear()
	var dir: DirAccess = DirAccess.open("res://items/catalog")
	if dir == null:
		push_error("BaseStationUI: Não foi possível abrir res://items/catalog")
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


func _setup_shop_buttons() -> void:
	for upgrade_id: String in SHOP_BUTTONS:
		var btn: Button = _get_shop_button(upgrade_id)
		if btn != null:
			btn.pressed.connect(_purchase_upgrade.bind(upgrade_id))


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
		return
	for upgrade_id: String in SHOP_BUTTONS:
		var btn: Button = _get_shop_button(upgrade_id)
		if btn == null:
			continue
		if not GameState.UPGRADES.has(upgrade_id):
			# Upgrade ainda não existe no core em execução.
			btn.visible = false
			continue
		btn.visible = true
		var display_name: String = GameState.UPGRADES[upgrade_id]["name"]
		var level: int = _game_state.get_upgrade_level(upgrade_id)
		var max_level: int = _game_state.get_upgrade_max_level(upgrade_id)
		var cost: int = _game_state.get_next_upgrade_cost(upgrade_id)
		var header: String = "%s  •  Nível %d/%d" % [display_name, level, max_level]
		if upgrade_id == "detector":
			# O radar começa no nível 1 com o detector no nível 0.
			header += " (radar Nv.%d)" % (level + 1)
		if cost < 0:
			btn.text = "%s\nNÍVEL MÁXIMO" % header
			btn.tooltip_text = "%s já está no nível máximo." % display_name
			btn.disabled = true
			continue
		var reason: String = _get_upgrade_block_reason(upgrade_id, cost)
		var required_map: String = _get_next_upgrade_required_map(upgrade_id)
		if not required_map.is_empty() and reason.begins_with("Desbloqueie"):
			btn.text = "%s\n🔒 Requer %s — %s" % [header, _get_map_display_name(required_map), UiFormat.money(cost)]
			btn.tooltip_text = UiFormat.fix_money_spaces(reason)
			btn.disabled = true
			continue
		btn.text = "%s\nComprar nível %d — %s" % [header, level + 1, UiFormat.money(cost)]
		if not reason.is_empty():
			btn.tooltip_text = UiFormat.fix_money_spaces(reason)
		elif upgrade_id == "detector":
			btn.tooltip_text = "Radar: Nv.%d → Nv.%d" % [level + 1, level + 2]
		elif upgrade_id == "backpack":
			var base: int = _get_backpack_base()
			btn.tooltip_text = "Mochila: %d → %d espaços" % [base + level, base + level + 1]
		else:
			btn.tooltip_text = ""
		btn.disabled = _pending_purchase or not reason.is_empty()


## Motivo do core para não comprar o próximo nível; core antigo: só checa o saldo.
func _get_upgrade_block_reason(upgrade_id: String, cost: int) -> String:
	if _game_state.has_method(&"get_upgrade_block_reason"):
		return str(_game_state.call(&"get_upgrade_block_reason", upgrade_id))
	if _game_state.team_money < cost:
		return "Saldo insuficiente (%s)." % UiFormat.money(_game_state.team_money)
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
	if item_select_box != null:
		item_select_box.clear()
		for i in range(_catalog_items.size()):
			var item: ItemData = _catalog_items[i]
			item_select_box.add_item("%s (%s)" % [item.display_name, UiFormat.money(item.base_value)], i)
	
	if sell_item_btn != null:
		sell_item_btn.pressed.connect(_on_sell_test_pressed)
	if register_item_btn != null:
		register_item_btn.pressed.connect(_on_register_test_pressed)


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
		_set_museum_feedback("%s já estava cadastrado no Museu!" % selected_item.display_name)
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
		museum_item_list.add_item(museum_line(item, discovered.has(item.id)))


## Linha do Museu. Itens que não são escavados (missão, relíquia escondida, troféu de chefe,
## easter egg) têm depth_cm 0: mostram "Achado especial" no lugar da profundidade.
static func museum_line(item: ItemData, is_found: bool) -> String:
	var status_str: String = "[DESCOBERTO]" if is_found else "[ ? ]"
	var detail: String = "Profundidade: %d cm" % item.depth_cm if item.depth_cm > 0 else "Achado especial"
	return "%s %s (Valor: %s | %s)" % [status_str, item.display_name, UiFormat.money(item.base_value), detail]


func _refresh_secrets_label() -> void:
	if secrets_label == null:
		return
	# "Segredos — Praia 3/6 • Campo Antigo 0/6": contagem por mapa (prefixo do id do segredo).
	# NBSP dentro de cada mapa e antes do "•": se não couber, a linha só quebra entre mapas.
	var found: Array = Array(_game_state.found_secrets) if _game_state != null else []
	var maps: Variant = _session_call(&"get_available_maps", [], [])
	var map_list: Array = maps as Array if maps is Array else []
	var counts: Dictionary = UiFormat.secret_counts_by_map(found)
	var parts: PackedStringArray = []
	for map_id: String in counts:
		parts.append(UiFormat.secret_count_text(map_id, counts[map_id], map_list))
	secrets_label.text = "Segredos —" + UiFormat.NBSP + (UiFormat.NBSP + "• ").join(parts)


func _on_secret_found(_secret_id: String) -> void:
	_refresh_secrets_label()


func _on_state_updated(_amount: int) -> void:
	# Saldo mudou: reavalia quais upgrades e desbloqueios de mapa estão acessíveis.
	_refresh_shop_buttons()
	_refresh_map_list()


func _on_collection_updated(_total_found: int, _max_items: int) -> void:
	_refresh_museum_display()


func _on_item_sold(item_name: String, value: int) -> void:
	_set_museum_feedback("Venda concluída: %s (+%s)" % [item_name, UiFormat.money(value)])


func _on_item_donated(item_name: String, reward: int) -> void:
	_set_museum_feedback("%s doado ao Museu! (+%s de recompensa)" % [item_name, UiFormat.money(reward)])


func _set_shop_feedback(msg: String) -> void:
	if shop_feedback_label != null:
		shop_feedback_label.text = UiFormat.fix_money_spaces(msg)


func _set_museum_feedback(msg: String) -> void:
	if museum_feedback_label != null:
		museum_feedback_label.text = UiFormat.fix_money_spaces(msg)
