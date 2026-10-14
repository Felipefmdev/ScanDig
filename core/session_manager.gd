class_name SessionManager
extends Node

## Fluxo de sessão: lobby <-> expedição. O host decide as trocas de cena e
## propaga para todos via RPC; quem entra no meio recebe a cena atual + estado.

signal scene_changing(target_scene: String)
signal expedition_started(map_id: String)
signal expedition_ended(summary: Dictionary)
signal host_lost()

const LOBBY_SCENE: String = "res://world/lobby_base.tscn"
const MAP_SCENE_FORMAT: String = "res://world/map_%s.tscn"
const MAPS_DIR: String = "res://items/maps"
const HOST_PEER_ID: int = 1

static var instance: SessionManager = null

var _current_map: MapData = null
var _last_summary: Dictionary = {}
## Resumo em construção (só no host, durante a expedição).
var _pending_summary: Dictionary = {}


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	var state: GameState = GameState.instance
	if state != null:
		state.item_sold.connect(_on_item_sold)
		state.item_donated.connect(_on_item_donated)
	else:
		push_warning("SessionManager: GameState indisponível; resumo do dia ficará sem entradas.")


# --- Consulta -------------------------------------------------------------------

func get_available_maps() -> Array[MapData]:
	var maps: Array[MapData] = []
	var dir: DirAccess = DirAccess.open(MAPS_DIR)
	if dir == null:
		return maps
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file_name: String in files:
		var clean_name: String = file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var map_data: MapData = ResourceLoader.load("%s/%s" % [MAPS_DIR, clean_name]) as MapData
		if map_data != null and not map_data.id.is_empty():
			maps.append(map_data)
	return maps


func can_start_map(map_id: String) -> bool:
	var map_data: MapData = _find_map(map_id)
	var state: GameState = GameState.instance
	if map_data == null or state == null:
		return false
	if not ResourceLoader.exists(MAP_SCENE_FORMAT % map_id):
		return false
	return map_data.required_detector_level <= state.equipped_detector_level


func is_in_expedition() -> bool:
	return _current_map != null


func get_current_map() -> MapData:
	return _current_map


func get_last_summary() -> Dictionary:
	return _last_summary.duplicate(true)


# --- Pedidos (só o host executa) -------------------------------------------------

func request_start_expedition(map_id: String) -> void:
	if not multiplayer.is_server():
		push_warning("SessionManager: apenas o host pode iniciar expedições.")
		return
	if is_in_expedition():
		push_warning("SessionManager: já existe uma expedição em andamento.")
		return
	if not can_start_map(map_id):
		push_warning("SessionManager: mapa '%s' indisponível." % map_id)
		return
	var state: GameState = GameState.instance
	var map_data: MapData = _find_map(map_id)
	var money: int = state.team_money
	_pending_summary = {
		"day": state.current_day,
		"map_id": map_id,
		"map_name": map_data.display_name,
		"money_start": money,
		"money_end": money,
		"money_earned": 0,
		"entries": [],
	}
	_call_all(&"_rpc_enter_map", [map_id])


func request_end_expedition() -> void:
	if not multiplayer.is_server():
		push_warning("SessionManager: apenas o host pode encerrar a expedição.")
		return
	if not is_in_expedition():
		return
	var summary: Dictionary = _pending_summary.duplicate(true)
	var state: GameState = GameState.instance
	if state != null:
		summary["money_end"] = state.team_money
		summary["money_earned"] = state.team_money - int(summary.get("money_start", state.team_money))
		state.advance_day()
	var save: SaveManager = SaveManager.instance
	if save != null:
		save.save_game()
	_pending_summary = {}
	_call_all(&"_rpc_return_to_lobby", [summary])


# --- RPCs (host -> todos) -------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _rpc_enter_map(map_id: String) -> void:
	var map_data: MapData = _find_map(map_id)
	if map_data == null:
		push_error("SessionManager: mapa '%s' não encontrado neste peer." % map_id)
		return
	_current_map = map_data
	_change_scene(MAP_SCENE_FORMAT % map_id)
	expedition_started.emit(map_id)


@rpc("authority", "call_local", "reliable")
func _rpc_return_to_lobby(summary: Dictionary) -> void:
	_current_map = null
	_last_summary = summary.duplicate(true)
	_change_scene(LOBBY_SCENE)
	expedition_ended.emit(_last_summary)


## Sincroniza a cena de um peer que entrou no meio (map_id vazio = lobby).
@rpc("authority", "call_remote", "reliable")
func _rpc_sync_scene(map_id: String) -> void:
	if map_id.is_empty():
		_current_map = null
		_change_scene(LOBBY_SCENE)
	else:
		_rpc_enter_map(map_id)


# --- Eventos ----------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	# O GameState já envia o snapshot completo; aqui enviamos a cena atual.
	if multiplayer.is_server() and peer_id != HOST_PEER_ID:
		var map_id: String = _current_map.id if _current_map != null else ""
		_rpc_sync_scene.rpc_id(peer_id, map_id)


func _on_server_disconnected() -> void:
	_current_map = null
	_pending_summary = {}
	_change_scene(LOBBY_SCENE)
	host_lost.emit()


func _on_item_sold(item_name: String, value: int) -> void:
	_add_entry(item_name, "sold", value)


func _on_item_donated(item_name: String, reward: int) -> void:
	_add_entry(item_name, "donated", reward)


func _add_entry(item_name: String, action: String, value: int) -> void:
	if not multiplayer.is_server() or _pending_summary.is_empty():
		return
	var entries: Array = _pending_summary["entries"]
	entries.append({"name": item_name, "action": action, "value": value})


# --- Utilitários ------------------------------------------------------------------

## Executa o RPC call_local em todos; offline, chama direto.
func _call_all(method: StringName, args: Array) -> void:
	if _is_online():
		var call_args: Array = [method]
		call_args.append_array(args)
		callv(&"rpc", call_args)
	else:
		callv(method, args)


func _change_scene(scene_path: String) -> void:
	var tree: SceneTree = get_tree()
	var current: Node = tree.current_scene
	if current != null and current.scene_file_path == scene_path:
		return
	scene_changing.emit(scene_path)
	tree.call_deferred(&"change_scene_to_file", scene_path)


func _find_map(map_id: String) -> MapData:
	if map_id.is_empty():
		return null
	for map_data: MapData in get_available_maps():
		if map_data.id == map_id:
			return map_data
	return null


func _is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
