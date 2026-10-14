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

const HOST_PEER_ID: int = 1
## Fração do valor paga como recompensa ao doar um item inédito ao museu.
const MUSEUM_REWARD_RATIO: float = 0.5
## Espaços da mochila sem nenhum upgrade.
const BASE_BACKPACK_CAPACITY: int = 3
## Catálogo de ferramentas compráveis (ToolData); o nome do arquivo é o id.
const TOOLS_DIR: String = "res://items/tools"

## Definição da loja: custo de cada nível e nível máximo.
const UPGRADES: Dictionary = {
	"detector": {"name": "Detector", "costs": [300, 600, 1200], "max_level": 3},
	"pinpointer": {"name": "Pinpointer de Precisão", "costs": [500], "max_level": 1},
	"shovel": {"name": "Pá de Fibra", "costs": [800], "max_level": 1},
	"backpack": {"name": "Mochila Reforçada", "costs": [400, 800, 1600], "max_level": 3},
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


## Espaços da mochila: 3 (sem upgrade) a 6.
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


func is_authority() -> bool:
	return multiplayer.is_server()


func get_total_catalog_items() -> int:
	if max_museum_items <= 0:
		max_museum_items = _count_catalog_items()
	return max_museum_items


## Consulta para UI e gameplay. Devolve null se o id for inválido ou não existir.
func get_tool_data(item_id: String) -> ToolData:
	# Só aceita nomes simples: impede que um cliente carregue arquivos fora de TOOLS_DIR.
	if item_id.is_empty() or not item_id.is_valid_filename():
		return null
	if item_id.contains("/") or item_id.contains("\\") or item_id.contains(".."):
		return null
	var tool_path: String = "%s/%s.tres" % [TOOLS_DIR, item_id]
	if not ResourceLoader.exists(tool_path):
		return null
	var tool: ToolData = load(tool_path) as ToolData
	if tool == null or String(tool.id) != item_id:
		return null
	return tool


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
	var message: String = ""
	var cost: int = get_next_upgrade_cost(upgrade_id)
	if not UPGRADES.has(upgrade_id):
		message = "Upgrade desconhecido."
	elif cost < 0:
		message = "%s já está no nível máximo." % UPGRADES[upgrade_id]["name"]
	elif team_money < cost:
		message = "Saldo insuficiente para %s (Custo: R$ %d)." % [UPGRADES[upgrade_id]["name"], cost]
	else:
		team_money -= cost
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


# --- Sincronização -------------------------------------------------------------

func get_snapshot() -> Dictionary:
	return {
		"team_money": team_money,
		"current_day": current_day,
		# Array/Dictionary sem tipo: serializam de forma previsível via RPC e JSON.
		"discovered_items": Array(discovered_items),
		"upgrade_levels": upgrade_levels.duplicate(),
	}


## Aplica um snapshot localmente e emite todos os sinais de atualização.
## No host, prefira load_snapshot() para que os clientes também recebam.
func apply_snapshot(data: Dictionary) -> void:
	team_money = int(data.get("team_money", team_money))
	current_day = int(data.get("current_day", current_day))
	if data.get("discovered_items") is Array:
		var items: Array[String] = []
		for item: Variant in data["discovered_items"]:
			var item_id: String = str(item)
			if not item_id.is_empty() and not items.has(item_id):
				items.append(item_id)
		discovered_items = items
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
	_broadcast_snapshot()


func _is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func _ensure_upgrade_keys() -> void:
	for key: String in UPGRADES.keys():
		if not upgrade_levels.has(key):
			upgrade_levels[key] = 0


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
