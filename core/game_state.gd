class_name GameState
extends Node

## Estado global da equipe, economia e museu do ScanDig.
## Autoridade: o host (peer 1) é o único que altera o estado. Clientes enviam
## pedidos via request_*() e recebem o estado completo por snapshot.

signal money_changed(new_amount: int)
signal collection_updated(total_found: int, max_items: int)
signal item_sold(item_name: String, value: int)
signal item_donated(item_name: String, reward: int)
signal upgrades_changed(upgrade_levels: Dictionary)
signal purchase_result(upgrade_id: String, success: bool, message: String)
signal state_synced()
## Só o peer que comprou recebe. item_id = ToolData.id.
signal item_purchase_result(item_id: String, success: bool, message: String)
signal progression_changed(unlocked_maps: Array, defeated_bosses: Array)
## Só o peer que pediu recebe.
signal map_unlock_result(map_id: String, success: bool, message: String)

const HOST_PEER_ID: int = 1
## Fração do valor paga como recompensa ao doar um item inédito ao museu.
const MUSEUM_REWARD_RATIO: float = 0.5
## Espaços da mochila sem nenhum upgrade.
const BASE_BACKPACK_CAPACITY: int = 3
## Catálogo de ferramentas compráveis (ToolData); o nome do arquivo é o id.
const TOOLS_DIR: String = "res://items/tools"
## Definições de mapa (MapData); arquivo <id>.tres, id == nome do arquivo.
const MAPS_DIR: String = "res://items/maps"
## Chefe que precisa ser vencido antes de pagar o desbloqueio de cada mapa.
const MAP_UNLOCK_BOSSES: Dictionary = {
	"campo": {"boss_id": "king_crab", "boss_name": "Caranguejo-Rei"},
	"ruinas": {"boss_id": "giant_mole", "boss_name": "Toupeira Gigante"},
	"cratera": {"boss_id": "ancient_guardian", "boss_name": "Guardião Ancestral"},
}

## Definição da loja: custo de cada nível, mapa que precisa estar desbloqueado para
## comprar cada nível ("" = sem trava) e nível máximo. Tabela aprovada na #25.
const UPGRADES: Dictionary = {
	"detector": {"name": "Detector", "costs": [300, 600, 1200, 2000, 15000, 25000],
		"required_maps": ["", "", "campo", "ruinas", "cratera", "cratera"], "max_level": 6},
	"pinpointer": {"name": "Pinpointer de Precisão", "costs": [500, 18000],
		"required_maps": ["", "cratera"], "max_level": 2},
	"shovel": {"name": "Pá de Fibra", "costs": [800, 1200, 12000],
		"required_maps": ["", "ruinas", "cratera"], "max_level": 3},
	"backpack": {"name": "Mochila Reforçada", "costs": [400, 800, 1600, 1800, 10000],
		"required_maps": ["", "", "campo", "ruinas", "cratera"], "max_level": 5},
}

static var instance: GameState = null

@export var team_money: int = 100
@export var current_day: int = 1
@export var discovered_items: Array[String] = []
## Mantido por compatibilidade: espelha 1 + upgrade_levels["detector"].
@export var equipped_detector_level: int = 1
@export var max_museum_items: int = 0

## upgrade_id -> nível comprado (0 = não comprado).
var upgrade_levels: Dictionary = {}
## Mapas pagos; mapas com unlock_cost <= 0 (a Praia) não precisam estar aqui.
var unlocked_maps: Array[String] = []
var defeated_bosses: Array[String] = []


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	if max_museum_items <= 0:
		max_museum_items = _count_catalog_items()
	_ensure_upgrade_keys()
	_validate_upgrades()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)


# --- Consulta (seguro em qualquer peer) ---------------------------------------

func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))


func get_upgrade_max_level(upgrade_id: String) -> int:
	if not UPGRADES.has(upgrade_id):
		return 0
	return int(UPGRADES[upgrade_id]["max_level"])


## Custo do próximo nível, ou -1 se já está no máximo / não existe.
func get_next_upgrade_cost(upgrade_id: String) -> int:
	if not UPGRADES.has(upgrade_id):
		return -1
	var level: int = get_upgrade_level(upgrade_id)
	var costs: Array = UPGRADES[upgrade_id]["costs"]
	if level >= costs.size() or level >= get_upgrade_max_level(upgrade_id):
		return -1
	return int(costs[level])


## Id do mapa exigido para o PRÓXIMO nível; "" se não há trava, se está no máximo ou se o upgrade não existe.
func get_next_upgrade_required_map(upgrade_id: String) -> String:
	if get_next_upgrade_cost(upgrade_id) < 0:
		return ""
	var required_maps: Array = UPGRADES[upgrade_id]["required_maps"]
	var level: int = get_upgrade_level(upgrade_id)
	return str(required_maps[level]) if level < required_maps.size() else ""


## "" se dá para comprar o próximo nível agora; senão o motivo, pronto para a UI.
func get_upgrade_block_reason(upgrade_id: String) -> String:
	if not UPGRADES.has(upgrade_id):
		return "Upgrade desconhecido."
	var upgrade_name: String = str(UPGRADES[upgrade_id]["name"])
	var cost: int = get_next_upgrade_cost(upgrade_id)
	if cost < 0:
		return "%s já está no nível máximo." % upgrade_name
	var required_map: String = get_next_upgrade_required_map(upgrade_id)
	if not required_map.is_empty() and not is_map_unlocked(required_map):
		var map_data: MapData = _load_map(required_map)
		if map_data == null:
			push_warning("GameState: mapa '%s' exigido por '%s' não existe em %s." % [required_map, upgrade_id, MAPS_DIR])
			return "Desbloqueie %s primeiro." % required_map
		return "Desbloqueie %s primeiro." % map_data.display_name
	if team_money < cost:
		return "Saldo insuficiente para %s (Custo: R$ %d)." % [upgrade_name, cost]
	return ""


## Espaços da mochila: 3 (sem upgrade) a 8.
func get_backpack_capacity() -> int:
	return BASE_BACKPACK_CAPACITY + get_upgrade_level("backpack")


## Teto anti-trapaça para o valor de um item: base × rara × perfeita.
func get_max_item_value(item_data: ItemData) -> int:
	if item_data == null:
		return 0
	return int(ceil(float(item_data.base_value) * BuriedSpot.RARE_VALUE_MULTIPLIER * BuriedSpot.PERFECT_BONUS_MULTIPLIER))


## Nível da pá na escala do player.shovel_level: 1 = pá básica.
func get_shovel_level() -> int:
	return 1 + get_upgrade_level("shovel")


func has_pinpointer() -> bool:
	return get_upgrade_level("pinpointer") > 0


## 0 a 2.
func get_pinpointer_level() -> int:
	return get_upgrade_level("pinpointer")


func is_authority() -> bool:
	return multiplayer.is_server()


func get_total_catalog_items() -> int:
	if max_museum_items <= 0:
		max_museum_items = _count_catalog_items()
	return max_museum_items


## Consulta para UI e gameplay. Devolve null se o id for inválido ou não existir.
func get_tool_data(item_id: String) -> ToolData:
	if not _is_safe_resource_id(item_id):
		return null
	var tool_path: String = "%s/%s.tres" % [TOOLS_DIR, item_id]
	if not ResourceLoader.exists(tool_path):
		return null
	var tool: ToolData = load(tool_path) as ToolData
	if tool == null or String(tool.id) != item_id:
		return null
	return tool


func is_map_unlocked(map_id: String) -> bool:
	var map_data: MapData = _load_map(map_id)
	if map_data == null:
		return false
	return map_data.unlock_cost <= 0 or unlocked_maps.has(map_id)


func is_boss_defeated(boss_id: String) -> bool:
	return defeated_bosses.has(boss_id)


## "" se pode desbloquear agora; senão o motivo, em português, pronto para a UI.
func get_map_unlock_block_reason(map_id: String) -> String:
	var map_data: MapData = _load_map(map_id)
	if map_data == null:
		return "Mapa desconhecido."
	if is_map_unlocked(map_id):
		return "%s já está desbloqueado." % map_data.display_name
	if MAP_UNLOCK_BOSSES.has(map_id):
		var boss: Dictionary = MAP_UNLOCK_BOSSES[map_id]
		if not is_boss_defeated(str(boss["boss_id"])):
			return "Vença o chefe %s primeiro." % str(boss["boss_name"])
	if team_money < map_data.unlock_cost:
		return "Saldo insuficiente para desbloquear %s (R$ %d)." % [map_data.display_name, map_data.unlock_cost]
	return ""


func get_item_display_name(item_id: String) -> String:
	var item_data: ItemData = _load_item(item_id)
	if item_data != null and not item_data.display_name.is_empty():
		return item_data.display_name
	return item_id


# --- Pedidos (chamar de qualquer peer; o host decide) -------------------------

## Regra "vender vs. doar": item inédito vai para o museu (recompensa de
## MUSEUM_REWARD_RATIO do valor); item repetido é vendido pelo valor final.
func request_report_discovery(item_id: String, final_value: int) -> void:
	_send_to_host(&"_host_report_discovery", [item_id, final_value])


func request_sell_item(item_id: String, final_value: int) -> void:
	_send_to_host(&"_host_sell_item", [item_id, final_value])


func request_donate_item(item_id: String) -> void:
	_send_to_host(&"_host_donate_item", [item_id, -1])


func request_buy_upgrade(upgrade_id: String) -> void:
	_send_to_host(&"_host_buy_upgrade", [upgrade_id])


## Desbloqueio pago de mapa. A resposta chega por map_unlock_result.
func request_unlock_map(map_id: String) -> void:
	_send_to_host(&"_host_unlock_map", [map_id])


## Chamado pelo gameplay quando um chefe morre.
func request_report_boss_defeated(boss_id: String) -> void:
	_send_to_host(&"_host_report_boss_defeated", [boss_id])


## Compra de ferramenta (ToolData). A resposta chega por item_purchase_result.
func request_purchase_item(item_id: String) -> void:
	_send_to_host(&"_host_purchase_item", [item_id])


func _send_to_host(method: StringName, args: Array) -> void:
	if is_authority():
		callv(method, args)
	else:
		var call_args: Array = [HOST_PEER_ID, method]
		call_args.append_array(args)
		callv(&"rpc_id", call_args)


# --- Execução no host ---------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _host_report_discovery(item_id: String, final_value: int) -> void:
	if not is_authority() or _load_item(item_id) == null:
		return
	if discovered_items.has(item_id):
		_host_sell_item(item_id, final_value)
	else:
		_host_donate_item(item_id, final_value)


@rpc("any_peer", "call_remote", "reliable")
func _host_sell_item(item_id: String, final_value: int) -> void:
	if not is_authority():
		return
	var item_data: ItemData = _load_item(item_id)
	if item_data == null:
		return
	# Itens inéditos devem ir para o museu; impede cliente de pular a regra.
	if not discovered_items.has(item_id):
		_host_donate_item(item_id, final_value)
		return
	var value: int = clampi(final_value, 0, get_max_item_value(item_data))
	team_money += value
	_broadcast_snapshot()
	_notify_sold(item_id, value)


@rpc("any_peer", "call_remote", "reliable")
func _host_donate_item(item_id: String, final_value: int) -> void:
	if not is_authority():
		return
	var item_data: ItemData = _load_item(item_id)
	if item_data == null or discovered_items.has(item_id):
		return
	var base: int = item_data.base_value if final_value < 0 else clampi(final_value, 0, get_max_item_value(item_data))
	var reward: int = int(round(float(base) * MUSEUM_REWARD_RATIO))
	discovered_items.append(item_id)
	team_money += reward
	_broadcast_snapshot()
	_notify_donated(item_id, reward)


@rpc("any_peer", "call_remote", "reliable")
func _host_buy_upgrade(upgrade_id: String) -> void:
	if not is_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()

	var success: bool = false
	var message: String = get_upgrade_block_reason(upgrade_id)
	if message.is_empty():
		team_money -= get_next_upgrade_cost(upgrade_id)
		upgrade_levels[upgrade_id] = get_upgrade_level(upgrade_id) + 1
		success = true
		message = "Compra realizada: %s (nível %d)!" % [UPGRADES[upgrade_id]["name"], get_upgrade_level(upgrade_id)]
		_broadcast_snapshot()

	if sender == multiplayer.get_unique_id():
		purchase_result.emit(upgrade_id, success, message)
	else:
		_receive_purchase_result.rpc_id(sender, upgrade_id, success, message)


@rpc("any_peer", "call_remote", "reliable")
func _host_purchase_item(item_id: String) -> void:
	if not is_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()

	var success: bool = false
	var message: String = ""
	var tool: ToolData = get_tool_data(item_id)
	if tool == null or tool.price <= 0:
		message = "Produto indisponível."
	elif team_money < tool.price:
		message = "Saldo insuficiente para %s (R$ %d)." % [tool.display_name, tool.price]
	else:
		team_money -= tool.price
		success = true
		message = "Comprado: %s" % tool.display_name
		_broadcast_snapshot()

	if sender == multiplayer.get_unique_id():
		item_purchase_result.emit(item_id, success, message)
	else:
		_receive_item_purchase_result.rpc_id(sender, item_id, success, message)


@rpc("any_peer", "call_remote", "reliable")
func _host_unlock_map(map_id: String) -> void:
	if not is_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()

	var success: bool = false
	var message: String = get_map_unlock_block_reason(map_id)
	if message.is_empty():
		var map_data: MapData = _load_map(map_id)
		team_money -= map_data.unlock_cost
		unlocked_maps.append(map_id)
		success = true
		message = "%s desbloqueado!" % map_data.display_name
		_broadcast_snapshot()

	if sender == multiplayer.get_unique_id():
		map_unlock_result.emit(map_id, success, message)
	else:
		_receive_map_unlock_result.rpc_id(sender, map_id, success, message)


@rpc("any_peer", "call_remote", "reliable")
func _host_report_boss_defeated(boss_id: String) -> void:
	if not is_authority() or defeated_bosses.has(boss_id):
		return
	for entry: Dictionary in MAP_UNLOCK_BOSSES.values():
		if str(entry["boss_id"]) == boss_id:
			defeated_bosses.append(boss_id)
			_broadcast_snapshot()
			return


# --- Sincronização -------------------------------------------------------------

func get_snapshot() -> Dictionary:
	return {
		"team_money": team_money,
		"current_day": current_day,
		# Array/Dictionary sem tipo: serializam de forma previsível via RPC e JSON.
		"discovered_items": Array(discovered_items),
		"upgrade_levels": upgrade_levels.duplicate(),
		"unlocked_maps": Array(unlocked_maps),
		"defeated_bosses": Array(defeated_bosses),
	}


## Aplica um snapshot localmente e emite todos os sinais de atualização.
## No host, prefira load_snapshot() para que os clientes também recebam.
func apply_snapshot(data: Dictionary) -> void:
	team_money = int(data.get("team_money", team_money))
	current_day = int(data.get("current_day", current_day))
	if data.get("discovered_items") is Array:
		discovered_items = _to_id_list(data["discovered_items"])
	if data.get("unlocked_maps") is Array:
		unlocked_maps = _to_id_list(data["unlocked_maps"])
	if data.get("defeated_bosses") is Array:
		defeated_bosses = _to_id_list(data["defeated_bosses"])
	if data.get("upgrade_levels") is Dictionary:
		# JSON devolve números como float e pode conter chaves obsoletas.
		var source: Dictionary = data["upgrade_levels"]
		var levels: Dictionary = {}
		for key: String in UPGRADES.keys():
			levels[key] = clampi(int(source.get(key, 0)), 0, get_upgrade_max_level(key))
		upgrade_levels = levels
	_ensure_upgrade_keys()
	equipped_detector_level = 1 + get_upgrade_level("detector")
	money_changed.emit(team_money)
	collection_updated.emit(discovered_items.size(), get_total_catalog_items())
	upgrades_changed.emit(upgrade_levels.duplicate())
	progression_changed.emit(Array(unlocked_maps), Array(defeated_bosses))
	state_synced.emit()


## Host: substitui o estado (ex.: carregar save) e propaga para todos.
func load_snapshot(data: Dictionary) -> void:
	if not is_authority():
		push_warning("GameState: load_snapshot ignorado em cliente.")
		return
	apply_snapshot(data)
	_broadcast_snapshot()


func _broadcast_snapshot() -> void:
	var snapshot: Dictionary = get_snapshot()
	apply_snapshot(snapshot)
	if _is_online():
		_receive_snapshot.rpc(snapshot)


@rpc("authority", "call_remote", "reliable")
func _receive_snapshot(data: Dictionary) -> void:
	apply_snapshot(data)


@rpc("any_peer", "call_remote", "reliable")
func _request_full_state() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if is_authority() and sender != 0 and sender != multiplayer.get_unique_id():
		_receive_snapshot.rpc_id(sender, get_snapshot())


func _notify_sold(item_id: String, value: int) -> void:
	_receive_sold(item_id, value)
	if _is_online():
		_receive_sold.rpc(item_id, value)


func _notify_donated(item_id: String, reward: int) -> void:
	_receive_donated(item_id, reward)
	if _is_online():
		_receive_donated.rpc(item_id, reward)


@rpc("authority", "call_remote", "reliable")
func _receive_sold(item_id: String, value: int) -> void:
	item_sold.emit(get_item_display_name(item_id), value)


@rpc("authority", "call_remote", "reliable")
func _receive_donated(item_id: String, reward: int) -> void:
	item_donated.emit(get_item_display_name(item_id), reward)


@rpc("authority", "call_remote", "reliable")
func _receive_purchase_result(upgrade_id: String, success: bool, message: String) -> void:
	purchase_result.emit(upgrade_id, success, message)


@rpc("authority", "call_remote", "reliable")
func _receive_item_purchase_result(item_id: String, success: bool, message: String) -> void:
	item_purchase_result.emit(item_id, success, message)


@rpc("authority", "call_remote", "reliable")
func _receive_map_unlock_result(map_id: String, success: bool, message: String) -> void:
	map_unlock_result.emit(map_id, success, message)


func _on_peer_connected(peer_id: int) -> void:
	# Sincronização completa para quem entra.
	if is_authority() and _is_online():
		_receive_snapshot.rpc_id(peer_id, get_snapshot())


func _on_connected_to_server() -> void:
	# Redundância caso o snapshot do host chegue antes de o nó estar pronto.
	if not is_authority():
		_request_full_state.rpc_id(HOST_PEER_ID)


# --- Utilitários ----------------------------------------------------------------

## Host: avança para o próximo dia e propaga o snapshot para todos.
func advance_day() -> void:
	if not is_authority():
		push_warning("GameState: advance_day ignorado em cliente.")
		return
	current_day += 1
	_broadcast_snapshot()


func reset_state() -> void:
	if not is_authority():
		return
	team_money = 100
	current_day = 1
	discovered_items.clear()
	upgrade_levels.clear()
	unlocked_maps.clear()
	defeated_bosses.clear()
	_broadcast_snapshot()


func _is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func _ensure_upgrade_keys() -> void:
	for key: String in UPGRADES.keys():
		if not upgrade_levels.has(key):
			upgrade_levels[key] = 0


## Só aceita nomes simples: impede que um cliente carregue arquivos fora das pastas do catálogo.
func _is_safe_resource_id(resource_id: String) -> bool:
	if resource_id.is_empty() or not resource_id.is_valid_filename():
		return false
	return not (resource_id.contains("/") or resource_id.contains("\\") or resource_id.contains(".."))


## Confere a tabela UPGRADES: um custo e um mapa exigido por nível, e mapas existentes.
func _validate_upgrades() -> void:
	for upgrade_id: String in UPGRADES.keys():
		var entry: Dictionary = UPGRADES[upgrade_id]
		var costs: Array = entry["costs"]
		var required_maps: Array = entry["required_maps"]
		var max_level: int = int(entry["max_level"])
		if costs.size() != max_level or required_maps.size() != max_level:
			push_error("GameState: UPGRADES['%s'] tem %d custos, %d required_maps e max_level %d." % [upgrade_id, costs.size(), required_maps.size(), max_level])
		for map_id: Variant in required_maps:
			if not str(map_id).is_empty() and _load_map(str(map_id)) == null:
				push_error("GameState: UPGRADES['%s'] exige o mapa '%s', que não existe em %s." % [upgrade_id, map_id, MAPS_DIR])


func _load_map(map_id: String) -> MapData:
	if not _is_safe_resource_id(map_id):
		return null
	var map_path: String = "%s/%s.tres" % [MAPS_DIR, map_id]
	if not ResourceLoader.exists(map_path):
		return null
	var map_data: MapData = load(map_path) as MapData
	if map_data == null or map_data.id != map_id:
		return null
	return map_data


## Converte uma lista do snapshot/JSON em ids únicos e não vazios.
func _to_id_list(source: Array) -> Array[String]:
	var ids: Array[String] = []
	for value: Variant in source:
		var id: String = str(value)
		if not id.is_empty() and not ids.has(id):
			ids.append(id)
	return ids


func _load_item(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	var catalog_path: String = "res://items/catalog/%s.tres" % item_id
	if not ResourceLoader.exists(catalog_path):
		return null
	return ResourceLoader.load(catalog_path) as ItemData


func _count_catalog_items() -> int:
	var dir: DirAccess = DirAccess.open("res://items/catalog")
	if dir == null:
		return 0

	var count: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			var clean_name: String = file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				count += 1
		file_name = dir.get_next()
	return count
