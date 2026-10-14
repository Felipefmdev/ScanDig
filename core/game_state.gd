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

const HOST_PEER_ID: int = 1
## Fração do valor paga como recompensa ao doar um item inédito ao museu.
const MUSEUM_REWARD_RATIO: float = 0.5

## Definição da loja: custo de cada nível e nível máximo.
const UPGRADES: Dictionary = {
	"detector": {"name": "Detector", "costs": [300, 600, 1200], "max_level": 3},
	"pinpointer": {"name": "Pinpointer de Precisão", "costs": [500], "max_level": 1},
	"shovel": {"name": "Pá de Fibra", "costs": [800], "max_level": 1},
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


func is_authority() -> bool:
	return multiplayer.is_server()


func get_total_catalog_items() -> int:
	if max_museum_items <= 0:
		max_museum_items = _count_catalog_items()
	return max_museum_items


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
	var value: int = clampi(final_value, 0, item_data.base_value)
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
	var base: int = item_data.base_value if final_value < 0 else clampi(final_value, 0, item_data.base_value)
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


# --- Sincronização -------------------------------------------------------------

func get_snapshot() -> Dictionary:
	return {
		"team_money": team_money,
		"current_day": current_day,
		"discovered_items": discovered_items.duplicate(),
		"upgrade_levels": upgrade_levels.duplicate(),
	}


## Aplica um snapshot localmente e emite todos os sinais de atualização.
## No host, prefira load_snapshot() para que os clientes também recebam.
func apply_snapshot(data: Dictionary) -> void:
	team_money = int(data.get("team_money", team_money))
	current_day = int(data.get("current_day", current_day))
	if data.has("discovered_items"):
		var items: Array[String] = []
		for item in data["discovered_items"]:
			items.append(str(item))
		discovered_items = items
	if data.has("upgrade_levels"):
		upgrade_levels = (data["upgrade_levels"] as Dictionary).duplicate()
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
	if is_authority():
		_receive_snapshot.rpc_id(multiplayer.get_remote_sender_id(), get_snapshot())


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


func _on_peer_connected(peer_id: int) -> void:
	# Sincronização completa para quem entra.
	if is_authority():
		_receive_snapshot.rpc_id(peer_id, get_snapshot())


func _on_connected_to_server() -> void:
	# Redundância caso o snapshot do host chegue antes de o nó estar pronto.
	_request_full_state.rpc_id(HOST_PEER_ID)


# --- Utilitários ----------------------------------------------------------------

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
