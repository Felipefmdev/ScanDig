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
## Preparation was cancelled; the same station can offer boarding again.
signal rocket_travel_cancelled(token: int)
signal passage_travel_failed(message: String)
## Só no host: a expedição vai terminar AGORA. Emitido dentro de request_end_expedition(),
## depois de advance_day() + save_game() e ANTES de avisar os peers (_rpc_return_to_lobby).
## Quem escuta pode remover nós replicados de forma síncrona (remove_child + queue_free)
## para que os despawns saiam antes do RPC de volta ao lobby.
signal expedition_ending(map_id: String)
## Em todos os peers: a cena pedida em _change_scene terminou de carregar (um frame depois dos
## _ready dela). A noite (#109) se aplica aqui, antes de o peer se avisar pronto ao host.
signal scene_loaded(scene_path: String)

const LOBBY_SCENE: String = "res://world/lobby_base.tscn"
## Tela inicial (#100), a main scene do projeto.
const TITLE_SCENE: String = "res://world/title_screen.tscn"
## Como a base foi aberta pela tela inicial (#100): "solo" esconde o MultiplayerMenu, "coop"
## mostra. "" (bots, testes, cena aberta direto) = como sempre foi.
const LAUNCH_SOLO: String = "solo"
const LAUNCH_COOP: String = "coop"
const MAP_SCENE_FORMAT: String = "res://world/map_%s.tscn"
const MAPS_DIR: String = "res://items/maps"
const HOST_PEER_ID: int = 1
## Ordem de progressão; ids fora da lista vão para o fim, em ordem alfabética.
const MAP_ORDER: Array[String] = ["praia", "campo", "ruinas", "geleira", "cratera"]

static var instance: SessionManager = null
## Intenção de lançamento lida pelo lobby no _ready (LAUNCH_SOLO, LAUNCH_COOP ou "").
static var launch_mode: String = ""

var _current_map: MapData = null
## Expedição noturna (#109): escolhida pelo host na mesa e levada no RPC de entrada e no sync.
## Só vale para mapas com config em NightMode.NIGHT_BY_MAP; volta a false no lobby.
var _night: bool = false
## Testes: false = os RPCs de cena só mudam o estado, sem trocar a cena de verdade.
var scene_change_enabled: bool = true
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
## Owner-local carried references survive only the rocket scene transition.
var _rocket_payload: Dictionary = {}
const ROCKET_SPAWN_META: StringName = &"_rocket_spawn_spawner"
const ROCKET_PREPARE_TIMEOUT_MSEC: int = 10000
var _rocket_sequence: int = 0
var _rocket_phase: String = "IDLE"
var _rocket_token: int = 0
var _rocket_roster: Array[int] = []
var _rocket_acked: Array[int] = []
var _rocket_owner_prepared: bool = false
var _rocket_cleanup_started: bool = false
var _rocket_prepare_started_msec: int = 0
var _rocket_owner_flags: Dictionary = {}
## Payload observation outlives action/publication suspension and the commit RPC.
## The old owner can still receive damage until it leaves the scene tree.
var _rocket_payload_owner: WeakRef = null
var _rocket_payload_token: int = 0
var _rocket_payload_connections: Array[Dictionary] = []
## Empty for the lunar rocket; terrestrial passages supply their canonical route.
var _passage_context: Dictionary = {}
## Scene readiness outlives the owner's one-shot payload restoration.
const PASSAGE_LOAD_TIMEOUT_MSEC: int = 30000
var _passage_loading: Dictionary = {}
var _passage_recovering: bool = false
var _passage_arrival: Dictionary = {}


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
	if multiplayer.is_server() and not _passage_loading.is_empty() and Time.get_ticks_msec() - int(_passage_loading["started"]) >= PASSAGE_LOAD_TIMEOUT_MSEC:
		fail_passage_transition(int(_passage_loading["token"]), "O destino não terminou de carregar. Tente novamente pela base.")
	if multiplayer.is_server() and _rocket_phase == "PREPARING" and Time.get_ticks_msec() - _rocket_prepare_started_msec >= ROCKET_PREPARE_TIMEOUT_MSEC:
		cancel_rocket_transition(_rocket_token)
	if _pending_scene_path.is_empty() or _awaiting_scene_frame:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var current: Node = tree.current_scene
	if current == null or current.scene_file_path != _pending_scene_path:
		return
	var scene_path: String = _pending_scene_path
	_pending_scene_path = ""
	# Espera um frame para todos os _ready da cena nova rodarem.
	_awaiting_scene_frame = true
	await tree.process_frame
	_awaiting_scene_frame = false
	if not is_inside_tree():
		return
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
		if map_data != null and not map_data.id.is_empty() and map_data.id != "lua":
			maps.append(map_data)
	maps.sort_custom(_compare_map_order)
	return maps


func can_start_map(map_id: String) -> bool:
	# The Moon is reached from the Cratera rocket during the same expedition.
	if map_id == "lua":
		return false
	var map_data: MapData = _find_map(map_id)
	var state: GameState = GameState.instance
	if map_data == null or state == null:
		return false
	if not state.is_map_unlocked(map_id) or not ResourceLoader.exists(MAP_SCENE_FORMAT % map_id):
		return false
	# Equipamento melhora a exploração; não é pedágio para rotas permanentes.
	return true


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
	if map_id == "lua":
		reason = block_reason
	elif not unlocked:
		reason = block_reason
	elif not has_scene:
		reason = "Em breve."

	status["display_name"] = map_data.display_name
	status["unlocked"] = unlocked
	status["has_scene"] = has_scene
	status["playable"] = playable
	status["unlock_cost"] = 0
	status["required_boss_id"] = boss_id
	status["required_boss_name"] = str(boss.get("boss_name", ""))
	status["boss_defeated"] = boss_id.is_empty() or state.is_boss_defeated(boss_id)
	# O menu só consulta progresso: nenhuma entrada pode abrir uma rota daqui.
	status["can_unlock"] = false
	status["reason"] = reason
	return status


func is_in_expedition() -> bool:
	return _current_map != null


func get_current_map() -> MapData:
	return _current_map


## A expedição atual é noturna (#109). false no lobby e fora de sessão.
static func is_night() -> bool:
	return instance != null and instance._night and instance._current_map != null


## Argumentos do _rpc_sync_scene para quem entra no meio: o mapa atual ("" = lobby) e a noite.
func get_sync_scene_args() -> Array:
	var map_id: String = _current_map.id if _current_map != null else ""
	return [map_id, _night and _current_map != null]


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

func request_start_expedition(map_id: String, night: bool = false) -> void:
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
	night = night and NightMode.is_available(map_id)
	_pending_summary = {
		"day": state.current_day,
		"map_id": map_id,
		"map_name": map_data.display_name,
		"night": night,
		"money_start": money,
		"money_end": money,
		"money_earned": 0,
		"entries": [],
	}
	_call_all(&"_rpc_enter_map", [map_id, night])


func request_end_expedition() -> void:
	if not multiplayer.is_server():
		push_warning("SessionManager: apenas o host pode encerrar a expedição.")
		return
	if not is_in_expedition() or _ending:
		return
	if _rocket_phase == "COMMITTING":
		return
	if _rocket_phase == "PREPARING":
		cancel_rocket_transition(_rocket_token)
	_ending = true
	var map_id: String = _current_map.id
	var summary: Dictionary = _pending_summary.duplicate(true)
	var state: GameState = GameState.instance
	if state != null:
		summary["money_end"] = state.team_money
		summary["money_earned"] = state.team_money - int(summary.get("money_start", state.team_money))
		# Estatísticas da expedição (#141) antes do snapshot do novo dia e do save.
		if Achievements.instance != null:
			Achievements.instance.record_expedition_end(bool(summary.get("night", false)))
		state.advance_day()
	var save: SaveManager = SaveManager.instance
	if save != null:
		save.save_game()
	_pending_summary = {}
	# Antes do RPC: despawns feitos aqui chegam aos clientes antes da volta ao lobby (#22).
	expedition_ending.emit(map_id)
	_call_all(&"_rpc_return_to_lobby", [summary])
	_ending = false


## Local owner only: inventory never crosses the network or a disk save here.
func capture_rocket_payload(player: Player) -> bool:
	if player == null or not player.is_local() or player.inventory == null:
		return false
	_rocket_payload = _rocket_payload_state(player)
	return true


func _rocket_payload_state(player: Player) -> Dictionary:
	return {
		"slots": player.inventory.slots.duplicate(),
		"selected": player.inventory.selected_slot,
		"health": player.health, "hunger": player.hunger,
		"money": player.session_money, "count": player.session_items_count,
		"downed": player.is_downed,
	}


func _observe_rocket_payload(player: Player) -> void:
	_stop_observing_rocket_payload()
	_rocket_payload_owner = weakref(player)
	_rocket_payload_token = _rocket_token
	var refresh: Callable = _refresh_rocket_payload
	_observe_rocket_signal(player, &"health_changed", func(_value: float, _maximum: float) -> void: refresh.call())
	_observe_rocket_signal(player, &"hunger_changed", func(_value: float, _maximum: float) -> void: refresh.call())
	_observe_rocket_signal(player.inventory, &"inventory_changed", refresh)
	_observe_rocket_signal(player.inventory, &"selected_slot_changed", func(_slot: int) -> void: refresh.call())
	_observe_rocket_signal(player, &"player_downed", func(_actor: Player) -> void: refresh.call())
	# died precedes the actual drop/downed/respawn consequences; never snapshot it
	# as final state. Exit observes the completed owner state even after commit.
	_observe_rocket_signal(player, &"tree_exiting", _rocket_payload_owner_exiting)


func _observe_rocket_signal(source: Object, signal_name: StringName, callback: Callable) -> void:
	source.connect(signal_name, callback)
	_rocket_payload_connections.append({"source":weakref(source),"signal":signal_name,"callback":callback})


func _refresh_rocket_payload() -> void:
	if _rocket_payload.is_empty() or _rocket_payload_token != _rocket_token or _rocket_payload_owner == null:
		return
	var player: Player = _rocket_payload_owner.get_ref() as Player
	if is_instance_valid(player) and is_instance_valid(player.inventory) and player.is_local():
		_rocket_payload = _rocket_payload_state(player)


func _rocket_payload_owner_exiting() -> void:
	_refresh_rocket_payload()
	_stop_observing_rocket_payload()


func _stop_observing_rocket_payload() -> void:
	for connection: Dictionary in _rocket_payload_connections:
		var source_ref: WeakRef = connection["source"] as WeakRef
		var source: Object = source_ref.get_ref() if source_ref != null else null
		var signal_name: StringName = connection["signal"]
		var callback: Callable = connection["callback"]
		if is_instance_valid(source) and source.is_connected(signal_name, callback):
			source.disconnect(signal_name, callback)
	_rocket_payload_connections.clear()
	_rocket_payload_owner = null
	_rocket_payload_token = 0


## Called after the new owner's Player finishes its normal initialization.
func restore_rocket_payload(player: Player) -> bool:
	if _rocket_payload.is_empty() or player == null or not player.is_local() or player.inventory == null:
		return false
	_refresh_rocket_payload()
	_stop_observing_rocket_payload()
	var payload: Dictionary = _rocket_payload
	_rocket_payload = {}
	var slots: Array = payload["slots"]
	player.inventory.capacity = maxi(player.inventory.capacity, slots.size())
	for index: int in player.inventory.slots.size():
		player.inventory.slots[index] = slots[index] if index < slots.size() else null
	player.inventory.selected_slot = clampi(int(payload["selected"]),0,player.inventory.capacity-1)
	player.health = clampf(float(payload["health"]),0.0,player.max_health)
	player.hunger = clampf(float(payload["hunger"]),0.0,player.max_hunger)
	player.session_money = int(payload["money"])
	player.session_items_count = int(payload["count"])
	# Apply the real setter (groups/avatar/HUD), without replaying death/drop/RPC.
	player.is_downed = bool(payload.get("downed", false))
	player.inventory.inventory_changed.emit()
	player.inventory.selected_slot_changed.emit(player.inventory.selected_slot)
	player.health_changed.emit(player.health,player.max_health)
	player._refresh_hunger_hud()
	player._update_session_hud()
	if _rocket_phase == "COMMITTING" or _passage_recovering:
		_passage_recovering = false
		_reset_rocket_transition(false, false)
	return true


## Internal host entry after the rocket validates participants, tools and proximity.
## This is deliberately not an any-peer RPC and does not end/restart the day.
func request_rocket_travel() -> bool:
	if not multiplayer.is_server() or _ending or _current_map == null or _rocket_phase != "IDLE":
		return false
	if _current_map.id != "cratera" or GameState.instance == null:
		return false
	if not GameState.instance.is_quest_completed("vega_foguete"):
		return false
	if _find_map("lua") == null or not ResourceLoader.exists(MAP_SCENE_FORMAT % "lua"):
		return false
	var roster: Array[int] = _rocket_connected_roster()
	for peer_id: int in roster:
		if not is_peer_scene_ready(peer_id):
			return false
	_rocket_sequence += 1
	_rocket_token = _rocket_sequence
	_rocket_roster = roster
	_rocket_acked.clear()
	_rocket_phase = "PREPARING"
	_rocket_prepare_started_msec = Time.get_ticks_msec()
	_call_all(&"_rpc_prepare_rocket", [_rocket_token, _rocket_roster.duplicate()])
	return true


## Host-local only. A real scene endpoint supplies the route, never a client destination.
func request_passage_travel(endpoint: Node3D, requesting_peer: int) -> bool:
	if not _passage_loading.is_empty() or _passage_recovering or not _rocket_payload.is_empty():
		return false
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != 0 or _ending or _current_map == null or _rocket_phase != "IDLE":
		return false
	if not is_instance_valid(endpoint) or not endpoint.is_inside_tree():
		return false
	var script: Script = endpoint.get_script() as Script
	if script == null or script.resource_path != "res://gameplay/environment/boss_passage.gd":
		return false
	if not endpoint.has_method("validate_request") or int(endpoint.call("validate_request", requesting_peer)) != OK:
		return false
	var route_id: String = str(endpoint.get("route_id"))
	var source_map: String = str(endpoint.get("source_map"))
	var route: Dictionary = GameState.MAP_UNLOCK_BOSSES.get(route_id, {})
	var state: GameState = GameState.instance
	if route.is_empty() or state == null or not state.unlocked_maps.has(route_id) or source_map != _current_map.id:
		return false
	var origin: String = str(route["source_map"])
	if source_map != origin and source_map != route_id:
		return false
	var destination: String = route_id if source_map == origin else origin
	if _find_map(destination) == null or not ResourceLoader.exists(MAP_SCENE_FORMAT % destination):
		return false
	var roster: Array[int] = _rocket_connected_roster()
	for peer_id: int in roster:
		if not is_peer_scene_ready(peer_id):
			return false
		var actor: Player = HostSync.player_of(get_tree(), peer_id) as Player
		if actor == null or not actor.is_inside_tree() or actor.is_queued_for_deletion() or not actor.is_alive() or actor.is_downed:
			return false
		if String(actor.name) != str(peer_id) or actor.get_multiplayer_authority() != peer_id or actor.multiplayer != multiplayer:
			return false
		if Vector2(actor.global_position.x - endpoint.global_position.x, actor.global_position.z - endpoint.global_position.z).length() > 5.0:
			return false
	for node: Node in get_tree().get_nodes_in_group(EnemyBase.GROUP):
		var enemy: EnemyBase = node as EnemyBase
		if enemy != null and enemy.is_inside_tree() and enemy.is_alive() and enemy.multiplayer == multiplayer:
			if Vector2(enemy.global_position.x - endpoint.global_position.x, enemy.global_position.z - endpoint.global_position.z).length() <= 8.0:
				return false
	var save: SaveManager = SaveManager.instance
	if save == null or not save.is_progress_applied() or save.save_game(state) != OK:
		return false
	_rocket_sequence += 1
	_rocket_token = _rocket_sequence
	_rocket_roster = roster
	_rocket_acked.clear()
	_passage_context = {"route": route_id, "source": source_map, "destination": destination}
	_rocket_phase = "PREPARING"
	_rocket_prepare_started_msec = Time.get_ticks_msec()
	_call_all(&"_rpc_prepare_passage", [_rocket_token, roster.duplicate(), route_id, source_map])
	return true


@rpc("authority", "call_local", "reliable", 0)
func _rpc_prepare_passage(token: int, roster: Array, route_id: String, source_map: String) -> void:
	var route: Dictionary = GameState.MAP_UNLOCK_BOSSES.get(route_id, {})
	if route.is_empty() or _current_map == null or _current_map.id != source_map:
		return
	var origin: String = str(route["source_map"])
	if source_map != origin and source_map != route_id:
		return
	if _rocket_phase == "IDLE":
		if multiplayer.is_server() or token <= _rocket_sequence:
			return
	elif _rocket_phase != "PREPARING" or token != _rocket_token:
		return
	var destination: String = route_id if source_map == origin else origin
	var context: Dictionary = {"route": route_id, "source": source_map, "destination": destination}
	if not _passage_context.is_empty() and _passage_context != context:
		return
	_passage_context = context
	_rpc_prepare_rocket(token, roster)


@rpc("authority", "call_local", "reliable", 0)
func _rpc_rocket_travel() -> void:
	# Compatibility entry cannot bypass preparation or recapture inventory.
	if multiplayer.is_server():
		request_rocket_travel()


func get_rocket_transition() -> Dictionary:
	return {"phase":_rocket_phase,"token":_rocket_token,"roster":_rocket_roster.duplicate(),"acked":_rocket_acked.duplicate(),"destination":str(_passage_context.get("destination", "lua"))}


func get_passage_loading() -> Dictionary:
	return {"active": not _passage_loading.is_empty(), "token": int(_passage_loading.get("token", 0)), "roster": (_passage_loading.get("roster", []) as Array).duplicate(), "waiting_peers": (_passage_loading.get("waiting_peers", []) as Array).duplicate()}


func get_passage_arrival() -> Dictionary:
	return _passage_arrival.duplicate()


## Host-local recovery, never an arbitrary client destination or rollback.
func fail_passage_transition(token: int, message: String) -> bool:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != 0 or _passage_loading.is_empty() or token != int(_passage_loading["token"]):
		return false
	_call_all(&"_rpc_recover_passage", [token, message])
	return true


@rpc("authority", "call_local", "reliable", 0)
func _rpc_recover_passage(token: int, message: String) -> void:
	if _passage_loading.is_empty() or token != int(_passage_loading["token"]):
		return
	_refresh_rocket_payload()
	_release_rocket_owner(false)
	# Retain the token and observer until the old actor exits, then consume once
	# in the next real Player._ready. No day advance or economic rollback.
	_passage_recovering = not _rocket_payload.is_empty()
	_passage_arrival.clear()
	_rocket_phase = "IDLE"
	_current_map = null
	_night = false
	var waiting: Array = _passage_loading.get("waiting_peers", []).duplicate()
	_passage_loading.clear()
	_change_scene(LOBBY_SCENE)
	passage_travel_failed.emit(message)
	if multiplayer.is_server():
		for peer_id: int in waiting:
			_sync_peer_scene(peer_id)


func _finish_passage_loading_if_ready() -> void:
	if _passage_loading.is_empty() or _current_map == null or _current_map.id != str(_passage_loading["destination"]):
		return
	for peer_id: int in _passage_loading["roster"]:
		if not _ready_peers.has(peer_id):
			return
	var waiting: Array = _passage_loading["waiting_peers"].duplicate()
	_passage_loading.clear()
	for peer_id: int in waiting:
		_sync_peer_scene(peer_id)


func _rocket_connected_roster() -> Array[int]:
	var roster: Array[int] = [HOST_PEER_ID]
	if _is_online():
		for peer_id: int in multiplayer.get_peers():
			roster.append(peer_id)
	roster.sort()
	return roster


func _rocket_local_player() -> Player:
	for node: Node in get_tree().get_nodes_in_group(Player.LOCAL_GROUP):
		var player: Player = node as Player
		if player != null and player.is_node_ready() and player.is_local() and player.get_multiplayer() == multiplayer:
			return player
	return null


@rpc("authority", "call_local", "reliable", 0)
func _rpc_prepare_rocket(token: int, roster: Array) -> void:
	if token <= 0 or _current_map == null or _current_map.id != str(_passage_context.get("source", "cratera")):
		return
	var participants: Array[int] = []
	for value: Variant in roster:
		if not value is int or int(value) <= 0 or participants.has(int(value)):
			return
		participants.append(int(value))
	participants.sort()
	if not participants.has(HOST_PEER_ID) or not participants.has(multiplayer.get_unique_id()):
		return
	if _rocket_phase == "IDLE":
		if multiplayer.is_server() or token <= _rocket_sequence:
			return
		_rocket_sequence = token
		_rocket_token = token
		_rocket_roster = participants
		_rocket_phase = "PREPARING"
		_rocket_prepare_started_msec = Time.get_ticks_msec()
	if _rocket_phase != "PREPARING" or token != _rocket_token or participants != _rocket_roster:
		return
	if _rocket_owner_prepared:
		return
	var player: Player = _rocket_local_player()
	if player == null or not player.is_alive() or not capture_rocket_payload(player):
		return
	_observe_rocket_payload(player)
	_suspend_rocket_owner(player)
	_rocket_owner_prepared = true
	_send_rocket_prepare_ack(token)


func _send_rocket_prepare_ack(token: int) -> void:
	if multiplayer.is_server():
		_accept_rocket_prepare_ack.call_deferred(HOST_PEER_ID, token)
	elif _is_online():
		_rpc_ack_rocket.rpc_id(HOST_PEER_ID, token)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_ack_rocket(token: int) -> void:
	if multiplayer.is_server():
		_accept_rocket_prepare_ack.call_deferred(multiplayer.get_remote_sender_id(), token)


func _accept_rocket_prepare_ack(sender: int, token: int) -> bool:
	if not multiplayer.is_server() or _rocket_phase != "PREPARING" or token != _rocket_token:
		return false
	if sender <= 0 or not _rocket_roster.has(sender) or _rocket_acked.has(sender):
		return false
	if _rocket_connected_roster() != _rocket_roster:
		cancel_rocket_transition(token)
		return false
	if sender == HOST_PEER_ID and (not _rocket_owner_prepared or _rocket_payload.is_empty()):
		return false
	_rocket_acked.append(sender)
	_rocket_acked.sort()
	if _rocket_acked == _rocket_roster:
		# No yield between the final roster check, cleanup and ordered commit.
		_rocket_phase = "COMMITTING"
		_rocket_cleanup_started = true
		if not _cleanup_rocket_generation():
			return false
		_call_all(&"_rpc_commit_rocket", [token])
	return true


@rpc("authority", "call_local", "reliable", 0)
func _rpc_commit_rocket(token: int) -> void:
	if token != _rocket_token or not _rocket_owner_prepared or _rocket_payload.is_empty():
		return
	if multiplayer.is_server():
		if _rocket_phase != "COMMITTING" or not _rocket_cleanup_started or _rocket_acked != _rocket_roster:
			return
	elif _rocket_phase != "PREPARING":
		return
	var destination_id: String = str(_passage_context.get("destination", "lua"))
	var destination: MapData = _find_map(destination_id)
	if destination == null:
		return
	_rocket_phase = "COMMITTING"
	if not _passage_context.is_empty():
		_passage_loading = {"token": token, "roster": _rocket_roster.duplicate(), "waiting_peers": [], "destination": destination_id, "started": Time.get_ticks_msec()}
		_passage_arrival = {"route": str(_passage_context["route"]), "destination": destination_id}
	# Old owner remains frozen until removal. The new Player restores the cache once.
	_release_rocket_owner(false)
	_current_map = destination
	_night = _night and NightMode.is_available(destination_id) if not _passage_context.is_empty() else false
	if not _passage_context.is_empty() and multiplayer.is_server() and not _pending_summary.is_empty():
		var visited: Array = _pending_summary.get("visited_maps", [_passage_context["source"]])
		visited.append(destination_id)
		_pending_summary["visited_maps"] = visited
		_pending_summary["map_id"] = destination_id
		_pending_summary["map_name"] = destination.display_name
	_change_scene(MAP_SCENE_FORMAT % destination_id)


func cancel_rocket_transition(token: int) -> bool:
	if not multiplayer.is_server() or _rocket_phase != "PREPARING" or token != _rocket_token or _rocket_cleanup_started:
		return false
	_call_all(&"_rpc_cancel_rocket", [token])
	# Held transport in tests (and synchronous disconnect hooks) still needs local cancel.
	if _rocket_phase == "PREPARING" and _rocket_token == token:
		_rpc_cancel_rocket(token)
	return true


@rpc("authority", "call_local", "reliable", 0)
func _rpc_cancel_rocket(token: int) -> void:
	if _rocket_phase == "PREPARING" and token == _rocket_token and not _rocket_cleanup_started:
		_reset_rocket_transition(true, true)
		rocket_travel_cancelled.emit(token)


func _suspend_rocket_owner(player: Player) -> void:
	var sync: MultiplayerSynchronizer = player.net_sync
	_rocket_owner_flags = {"player":weakref(player),"physics":player.is_physics_processing(),"input":player.is_processing_input(),"unhandled":player.is_processing_unhandled_input()}
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	if player.dig_animator != null:
		# Its process emits delayed dig/swing impacts independently of Player physics.
		_rocket_owner_flags["animator"] = weakref(player.dig_animator)
		_rocket_owner_flags["animator_process"] = player.dig_animator.is_processing()
		player.dig_animator.set_process(false)
	if sync != null and sync.is_multiplayer_authority():
		var grants: Dictionary = {}
		var peers: Array[int] = [HOST_PEER_ID]
		for peer_id: int in multiplayer.get_peers():
			if not peers.has(peer_id): peers.append(peer_id)
		for peer_id: int in peers: grants[peer_id] = sync.get_visibility_for(peer_id)
		_rocket_owner_flags["sync"] = weakref(sync)
		_rocket_owner_flags["public"] = sync.public_visibility
		_rocket_owner_flags["grants"] = grants
		# A false filter vetoes even explicit peer grants; public=false alone does not.
		sync.add_visibility_filter(_rocket_owner_can_publish)
		sync.public_visibility = false
		for peer_id: int in peers: sync.set_visibility_for(peer_id, false)
		sync.update_visibility()


func _rocket_owner_can_publish(_peer_id: int) -> bool:
	return false


func _release_rocket_owner(restore_flags: bool) -> void:
	var player_ref: WeakRef = _rocket_owner_flags.get("player") as WeakRef
	var player: Player = player_ref.get_ref() as Player if player_ref != null else null
	var sync_ref: WeakRef = _rocket_owner_flags.get("sync") as WeakRef
	var sync: MultiplayerSynchronizer = sync_ref.get_ref() as MultiplayerSynchronizer if sync_ref != null else null
	if restore_flags:
		if is_instance_valid(player):
			player.set_physics_process(bool(_rocket_owner_flags["physics"]))
			player.set_process_input(bool(_rocket_owner_flags["input"]))
			player.set_process_unhandled_input(bool(_rocket_owner_flags["unhandled"]))
		var animator_ref: WeakRef = _rocket_owner_flags.get("animator") as WeakRef
		var animator: Node = animator_ref.get_ref() as Node if animator_ref != null else null
		if is_instance_valid(animator):
			animator.set_process(bool(_rocket_owner_flags["animator_process"]))
		if is_instance_valid(sync) and sync.is_inside_tree() and sync.is_multiplayer_authority():
			var grants: Dictionary = _rocket_owner_flags.get("grants",{})
			for peer_id: int in grants: sync.set_visibility_for(peer_id,bool(grants[peer_id]))
			sync.public_visibility = bool(_rocket_owner_flags["public"])
			sync.remove_visibility_filter(_rocket_owner_can_publish)
			sync.update_visibility()
	_rocket_owner_flags.clear()


func _reset_rocket_transition(restore_flags: bool, discard_payload: bool) -> void:
	_stop_observing_rocket_payload()
	_release_rocket_owner(restore_flags)
	if discard_payload: _rocket_payload.clear()
	_rocket_phase = "IDLE"
	_rocket_token = 0
	_rocket_roster.clear()
	_rocket_acked.clear()
	_rocket_owner_prepared = false
	_rocket_cleanup_started = false
	_rocket_prepare_started_msec = 0
	_passage_context.clear()


func _abandon_rocket_transition() -> void:
	_passage_arrival.clear()
	_passage_loading.clear()
	_passage_recovering = false
	if multiplayer.is_server() and _rocket_phase == "PREPARING":
		cancel_rocket_transition(_rocket_token)
	_reset_rocket_transition(true, true)


func _cleanup_rocket_generation() -> bool:
	if not multiplayer.is_server():
		return false
	var scene: Node = get_tree().current_scene
	if scene == null:
		return true
	var spawned: Array[Node] = []
	_collect_rocket_spawned(scene, spawned)
	# Quiesce host publication in this generation, including authored stateful nodes.
	# Those authored nodes remain in place; only the explicit spawn list is removed.
	_quiesce_rocket_host_syncs(scene)
	for node: Node in spawned:
		var parent: Node = node.get_parent()
		if parent != null:
			parent.remove_child(node) # Spawner still alive: enqueue reliable despawn now.
			node.queue_free()
	return true


func _collect_rocket_spawned(root: Node, result: Array[Node]) -> void:
	if root is PlayersRoot or root is SpotSpawner or root is PickupsRoot or root is EnemySpawner:
		for child: Node in root.get_children():
			if not child.has_meta(ROCKET_SPAWN_META):
				continue
			var marker: WeakRef = child.get_meta(ROCKET_SPAWN_META) as WeakRef
			var spawner: MultiplayerSpawner = marker.get_ref() as MultiplayerSpawner if marker != null else null
			if is_instance_valid(spawner) and spawner.is_inside_tree() and spawner.get_parent() == root and spawner.is_multiplayer_authority() and spawner.get_node_or_null(spawner.spawn_path) == root:
				result.append(child)
	for child: Node in root.get_children():
		_collect_rocket_spawned(child, result)


func _quiesce_rocket_host_syncs(root: Node) -> void:
	if root is MultiplayerSynchronizer:
		var sync: MultiplayerSynchronizer = root as MultiplayerSynchronizer
		if sync.is_multiplayer_authority():
			sync.add_visibility_filter(_rocket_owner_can_publish)
			sync.public_visibility = false
			sync.update_visibility()
	for child: Node in root.get_children():
		_quiesce_rocket_host_syncs(child)


# --- RPCs (host -> todos) -------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _rpc_enter_map(map_id: String, night: bool = false) -> void:
	var map_data: MapData = _find_map(map_id)
	if map_data == null:
		push_error("SessionManager: mapa '%s' não encontrado neste peer." % map_id)
		return
	_current_map = map_data
	_passage_arrival.clear()
	_night = night and NightMode.is_available(map_id)
	_change_scene(MAP_SCENE_FORMAT % map_id)
	expedition_started.emit(map_id)


@rpc("authority", "call_local", "reliable")
func _rpc_return_to_lobby(summary: Dictionary) -> void:
	_passage_arrival.clear()
	_passage_loading.clear()
	_passage_recovering = false
	_reset_rocket_transition(true, true)
	_current_map = null
	_night = false
	_last_summary = summary.duplicate(true)
	_change_scene(LOBBY_SCENE)
	expedition_ended.emit(_last_summary)


## Sincroniza a cena de um peer que entrou no meio (map_id vazio = lobby).
@rpc("authority", "call_remote", "reliable")
func _rpc_sync_scene(map_id: String, night: bool = false, arrival: Dictionary = {}) -> void:
	if map_id.is_empty():
		_current_map = null
		_night = false
		_change_scene(LOBBY_SCENE)
	else:
		_rpc_enter_map(map_id, night)
		# Applied before the deferred scene load and the normal PlayerSpawner.
		var route_id: String = str(arrival.get("route", ""))
		var route: Dictionary = GameState.MAP_UNLOCK_BOSSES.get(route_id, {})
		if not route.is_empty() and map_id in [route_id, str(route["source_map"])] and str(arrival.get("destination", "")) == map_id:
			_passage_arrival = {"route": route_id, "destination": map_id}


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
	if multiplayer.is_server() and not _passage_loading.is_empty():
		var waiting: Array = _passage_loading["waiting_peers"]
		if peer_id != HOST_PEER_ID and not waiting.has(peer_id):
			waiting.append(peer_id)
		return
	if multiplayer.is_server() and _rocket_phase == "PREPARING":
		cancel_rocket_transition(_rocket_token)
	# O GameState já envia o snapshot completo; aqui enviamos a cena atual.
	if multiplayer.is_server() and peer_id != HOST_PEER_ID:
		_sync_peer_scene(peer_id)


func _sync_peer_scene(peer_id: int) -> void:
	var args: Array = get_sync_scene_args()
	_rpc_sync_scene.rpc_id(peer_id, args[0], args[1], get_passage_arrival())


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server() and _rocket_phase == "PREPARING":
		cancel_rocket_transition(_rocket_token)
	_ready_peers.erase(peer_id)
	if multiplayer.is_server() and not _passage_loading.is_empty():
		(_passage_loading["roster"] as Array).erase(peer_id)
		(_passage_loading["waiting_peers"] as Array).erase(peer_id)
		_finish_passage_loading_if_ready()


func _on_server_disconnected() -> void:
	_passage_arrival.clear()
	_passage_loading.clear()
	_passage_recovering = false
	_reset_rocket_transition(true, true)
	_current_map = null
	_night = false
	_pending_summary = {}
	_ready_peers.clear()
	_change_scene(LOBBY_SCENE)
	host_lost.emit()


## O próprio peer saiu por disconnect_game(): volta ao lobby sem host_lost nem resumo.
## Aqui o peer já é offline (is_server() dá true sempre): só o was_host do sinal vale.
func _on_session_left(was_host: bool) -> void:
	_passage_arrival.clear()
	_passage_loading.clear()
	_passage_recovering = false
	_reset_rocket_transition(true, true)
	if was_host and _current_map != null:
		# Guarda dinheiro e museu ganhos até aqui, sem avançar o dia.
		var save: SaveManager = SaveManager.instance
		if save != null:
			save.save_game()
	_current_map = null
	_night = false
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
	if not scene_change_enabled:
		return
	_pending_scene_path = scene_path
	var tree: SceneTree = get_tree()
	var current: Node = tree.current_scene
	if current != null and current.scene_file_path == scene_path:
		return
	scene_changing.emit(scene_path)
	_apply_scene_change.call_deferred(scene_path)


func _perform_scene_change(scene_path: String) -> Error:
	return get_tree().change_scene_to_file(scene_path)


func _apply_scene_change(scene_path: String) -> void:
	# A newer request supersedes this deferred operation.
	if _pending_scene_path != scene_path:
		return
	var error: Error = _perform_scene_change(scene_path)
	if error == OK:
		return
	_pending_scene_path = ""
	var message: String = "Não foi possível carregar o destino. Retorne pela base e tente novamente."
	if not _passage_loading.is_empty():
		var token: int = int(_passage_loading["token"])
		if multiplayer.is_server():
			fail_passage_transition(token, message)
		elif _is_online():
			_rpc_report_passage_failure.rpc_id(HOST_PEER_ID, token)
	else:
		passage_travel_failed.emit(message)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_report_passage_failure(token: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or sender <= 0 or _passage_loading.is_empty():
		return
	if (_passage_loading["roster"] as Array).has(sender):
		fail_passage_transition.call_deferred(token, "Um participante não conseguiu carregar o destino. Tente novamente pela base.")


func _on_scene_loaded(scene_path: String) -> void:
	scene_loaded.emit(scene_path)
	if _current_map == null or scene_path != MAP_SCENE_FORMAT % _current_map.id:
		return
	if _night and multiplayer.is_server():
		NightMode.apply_to_spawner(EnemySpawner.find(get_tree()), _current_map.id)
	if multiplayer.is_server():
		_mark_ready(HOST_PEER_ID, _current_map.id)
	elif _is_online():
		_rpc_report_scene_ready.rpc_id(HOST_PEER_ID, _current_map.id)


func _mark_ready(peer_id: int, map_id: String) -> void:
	if _current_map == null or _current_map.id != map_id:
		return
	if _ready_peers.has(peer_id):
		return
	_ready_peers.append(peer_id)
	peer_scene_ready.emit(peer_id, map_id)
	if multiplayer.is_server():
		_finish_passage_loading_if_ready()


func _compare_map_order(a: MapData, b: MapData) -> bool:
	var index_a: int = MAP_ORDER.find(a.id)
	var index_b: int = MAP_ORDER.find(b.id)
	if index_a == -1 and index_b == -1:
		return a.id < b.id
	if index_a == -1 or index_b == -1:
		return index_b == -1
	return index_a < index_b


func _find_map(map_id: String) -> MapData:
	# Narrative travel resolves its destination without offering it at the base.
	if map_id == "lua":
		return load("res://items/maps/lua.tres") as MapData
	if map_id.is_empty():
		return null
	for map_data: MapData in get_available_maps():
		if map_data.id == map_id:
			return map_data
	return null


func _is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


## Pausa → "Sair para o menu principal" (#100). Na base (host/offline) salva antes, como ao fim
## de uma expedição; dentro da expedição não salva (regra de sempre). Em coop sai da sessão pela
## rotina do "Sair da sessão" (disconnect_game). Depois limpa a expedição e abre a tela inicial.
func return_to_title() -> void:
	_abandon_rocket_transition()
	var save: SaveManager = SaveManager.instance
	var state: GameState = GameState.instance
	if _current_map == null and save != null and state != null and state.is_authority() and save.is_progress_applied():
		save.save_game()
	if _is_online() and NetworkManager.instance != null:
		NetworkManager.instance.disconnect_game()
	_current_map = null
	_night = false
	_pending_summary = {}
	_ending = false
	launch_mode = ""
	_change_scene(TITLE_SCENE)
