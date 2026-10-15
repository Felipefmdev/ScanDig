class_name SessionManager
extends Node

## Fluxo de sessão: lobby <-> expedição. O host decide as trocas de cena e
## propaga para todos via RPC; quem entra no meio recebe a cena atual + estado.

signal scene_changing(target_scene: String)
signal expedition_started(map_id: String)
signal expedition_ended(summary: Dictionary)
signal host_lost()
## Só no host: um peer (inclusive o próprio host, id 1) terminou de carregar o mapa atual.
signal peer_scene_ready(peer_id: int, map_id: String)
## Só no host: a expedição vai terminar AGORA. Emitido dentro de request_end_expedition(),
## depois de advance_day() + save_game() e ANTES de avisar os peers (_rpc_return_to_lobby).
## Quem escuta pode remover nós replicados de forma síncrona (remove_child + queue_free)
## para que os despawns saiam antes do RPC de volta ao lobby.
signal expedition_ending(map_id: String)

const LOBBY_SCENE: String = "res://world/lobby_base.tscn"
const MAP_SCENE_FORMAT: String = "res://world/map_%s.tscn"
const MAPS_DIR: String = "res://items/maps"
const HOST_PEER_ID: int = 1
## Ordem de progressão; ids fora da lista vão para o fim, em ordem alfabética.
const MAP_ORDER: Array[String] = ["praia", "campo", "ruinas", "geleira", "cratera"]

static var instance: SessionManager = null

var _current_map: MapData = null
var _last_summary: Dictionary = {}
## Resumo em construção (só no host, durante a expedição).
var _pending_summary: Dictionary = {}
## Só no host: peers cujo mapa atual já carregou.
var _ready_peers: Array[int] = []
## Cena pedida em _change_scene e ainda não carregada ("" = nenhuma).
var _pending_scene_path: String = ""
## Evita dois "aguarda frame" ao mesmo tempo em _process.
var _awaiting_scene_frame: bool = false
## request_end_expedition() em andamento: impede reentrada vinda de quem ouve expedition_ending.
var _ending: bool = false


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if NetworkManager.instance != null:
		NetworkManager.instance.session_left.connect(_on_session_left)
	else:
		push_warning("SessionManager: NetworkManager indisponível; sair da sessão não voltará ao lobby.")
	var state: GameState = GameState.instance
	if state != null:
		state.item_sold.connect(_on_item_sold)
		state.item_donated.connect(_on_item_donated)
	else:
		push_warning("SessionManager: GameState indisponível; resumo do dia ficará sem entradas.")


## A Godot 4.3 não avisa quando change_scene_to_file termina: compara a cena atual com a pedida.
func _process(_delta: float) -> void:
	if _pending_scene_path.is_empty() or _awaiting_scene_frame:
		return
	var current: Node = get_tree().current_scene
	if current == null or current.scene_file_path != _pending_scene_path:
		return
	var scene_path: String = _pending_scene_path
	_pending_scene_path = ""
	# Espera um frame para todos os _ready da cena nova rodarem.
	_awaiting_scene_frame = true
	await get_tree().process_frame
	_awaiting_scene_frame = false
	# Outra troca começou durante a espera: o aviso desta cena já não vale.
	if not _pending_scene_path.is_empty():
		return
	_on_scene_loaded(scene_path)


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
	maps.sort_custom(_compare_map_order)
	return maps


func can_start_map(map_id: String) -> bool:
	var map_data: MapData = _find_map(map_id)
	var state: GameState = GameState.instance
	if map_data == null or state == null:
		return false
	if not state.is_map_unlocked(map_id) or not ResourceLoader.exists(MAP_SCENE_FORMAT % map_id):
		return false
	return map_data.required_detector_level <= state.equipped_detector_level


## Tudo o que a UI precisa para uma linha da lista de mapas (chaves sempre presentes).
func get_map_status(map_id: String) -> Dictionary:
	var status: Dictionary = {
		"map_id": map_id,
		"display_name": "",
		"unlocked": false,
		"has_scene": false,
		"playable": false,
		"unlock_cost": 0,
		"required_boss_id": "",
		"required_boss_name": "",
		"boss_defeated": false,
		"can_unlock": false,
		"reason": "Mapa desconhecido.",
	}
	var map_data: MapData = _find_map(map_id)
	var state: GameState = GameState.instance
	if map_data == null or state == null:
		return status

	var boss: Dictionary = GameState.MAP_UNLOCK_BOSSES.get(map_id, {})
	var boss_id: String = str(boss.get("boss_id", ""))
	var unlocked: bool = state.is_map_unlocked(map_id)
	var has_scene: bool = ResourceLoader.exists(MAP_SCENE_FORMAT % map_id)
	var playable: bool = can_start_map(map_id)
	var block_reason: String = state.get_map_unlock_block_reason(map_id)

	var reason: String = ""
	if not unlocked:
		reason = block_reason if not block_reason.is_empty() else "Desbloqueie por R$ %d." % map_data.unlock_cost
	elif not has_scene:
		reason = "Em breve."
	elif not playable:
		reason = "Requer detector nível %d." % map_data.required_detector_level

	status["display_name"] = map_data.display_name
	status["unlocked"] = unlocked
	status["has_scene"] = has_scene
	status["playable"] = playable
	status["unlock_cost"] = map_data.unlock_cost
	status["required_boss_id"] = boss_id
	status["required_boss_name"] = str(boss.get("boss_name", ""))
	status["boss_defeated"] = boss_id.is_empty() or state.is_boss_defeated(boss_id)
	status["can_unlock"] = block_reason.is_empty()
	status["reason"] = reason
	return status


func is_in_expedition() -> bool:
	return _current_map != null


func get_current_map() -> MapData:
	return _current_map


func get_last_summary() -> Dictionary:
	return _last_summary.duplicate(true)


## Só faz sentido no host; nos clientes devolve false.
func is_peer_scene_ready(peer_id: int) -> bool:
	return multiplayer.is_server() and _ready_peers.has(peer_id)


## Só faz sentido no host; nos clientes devolve []. Ordenado.
func get_ready_peers() -> Array[int]:
	if not multiplayer.is_server():
		return []
	var peers: Array[int] = _ready_peers.duplicate()
	peers.sort()
	return peers


# --- Pedidos (só o host executa) -------------------------------------------------

func request_start_expedition(map_id: String) -> void:
	if not multiplayer.is_server():
		push_warning("SessionManager: apenas o host pode iniciar expedições.")
		return
	if is_in_expedition():
		push_warning("SessionManager: já existe uma expedição em andamento.")
		return
	# Ninguém escolheu "Continuar"/"Novo jogo": aplica o save antes (o fim da expedição grava
	# por cima dele). Vem antes do can_start_map, porque o save pode desbloquear o mapa.
	if SaveManager.instance != null:
		SaveManager.instance.ensure_progress_applied()
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
	if not is_in_expedition() or _ending:
		return
	_ending = true
	var map_id: String = _current_map.id
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
	# Antes do RPC: despawns feitos aqui chegam aos clientes antes da volta ao lobby (#22).
	expedition_ending.emit(map_id)
	_call_all(&"_rpc_return_to_lobby", [summary])
	_ending = false


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


## Cliente -> host: o mapa atual terminou de carregar neste peer.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_report_scene_ready(map_id: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or sender == 0 or _current_map == null:
		return
	# Aviso atrasado de um mapa anterior.
	if map_id != _current_map.id:
		return
	_mark_ready(sender, map_id)


# --- Eventos ----------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	# O GameState já envia o snapshot completo; aqui enviamos a cena atual.
	if multiplayer.is_server() and peer_id != HOST_PEER_ID:
		var map_id: String = _current_map.id if _current_map != null else ""
		_rpc_sync_scene.rpc_id(peer_id, map_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_ready_peers.erase(peer_id)


func _on_server_disconnected() -> void:
	_current_map = null
	_pending_summary = {}
	_ready_peers.clear()
	_change_scene(LOBBY_SCENE)
	host_lost.emit()


## O próprio peer saiu por disconnect_game(): volta ao lobby sem host_lost nem resumo.
## Aqui o peer já é offline (is_server() dá true sempre): só o was_host do sinal vale.
func _on_session_left(was_host: bool) -> void:
	if was_host and _current_map != null:
		# Guarda dinheiro e museu ganhos até aqui, sem avançar o dia.
		var save: SaveManager = SaveManager.instance
		if save != null:
			save.save_game()
	_current_map = null
	_pending_summary = {}
	_ready_peers.clear()
	_change_scene(LOBBY_SCENE)


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
	# Toda troca de cena invalida quem estava pronto; cada peer reavisa ao carregar.
	_ready_peers.clear()
	_pending_scene_path = scene_path
	var tree: SceneTree = get_tree()
	var current: Node = tree.current_scene
	if current != null and current.scene_file_path == scene_path:
		return
	scene_changing.emit(scene_path)
	tree.call_deferred(&"change_scene_to_file", scene_path)


func _on_scene_loaded(scene_path: String) -> void:
	if _current_map == null or scene_path != MAP_SCENE_FORMAT % _current_map.id:
		return
	if multiplayer.is_server():
		_mark_ready(HOST_PEER_ID, _current_map.id)
	elif _is_online():
		_rpc_report_scene_ready.rpc_id(HOST_PEER_ID, _current_map.id)


func _mark_ready(peer_id: int, map_id: String) -> void:
	if _ready_peers.has(peer_id):
		return
	_ready_peers.append(peer_id)
	peer_scene_ready.emit(peer_id, map_id)


func _compare_map_order(a: MapData, b: MapData) -> bool:
	var index_a: int = MAP_ORDER.find(a.id)
	var index_b: int = MAP_ORDER.find(b.id)
	if index_a == -1 and index_b == -1:
		return a.id < b.id
	if index_a == -1 or index_b == -1:
		return index_b == -1
	return index_a < index_b


func _find_map(map_id: String) -> MapData:
	if map_id.is_empty():
		return null
	for map_data: MapData in get_available_maps():
		if map_data.id == map_id:
			return map_data
	return null


func _is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
