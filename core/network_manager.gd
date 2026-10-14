class_name NetworkManager
extends Node

## Gerenciador de conexão de rede multiplayer via ENetMultiplayerPeer.

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4

static var instance: NetworkManager = null

var connected_players: Dictionary = {}
var enet_peer: ENetMultiplayerPeer = null


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	_cleanup_peer()


func _ready() -> void:
	var mp: MultiplayerAPI = _get_multiplayer_api()
	if mp != null:
		if not mp.peer_connected.is_connected(_on_peer_connected):
			mp.peer_connected.connect(_on_peer_connected)
		if not mp.peer_disconnected.is_connected(_on_peer_disconnected):
			mp.peer_disconnected.connect(_on_peer_disconnected)
		if not mp.connected_to_server.is_connected(_on_connected_to_server):
			mp.connected_to_server.connect(_on_connected_to_server)
		if not mp.connection_failed.is_connected(_on_connection_failed):
			mp.connection_failed.connect(_on_connection_failed)
		if not mp.server_disconnected.is_connected(_on_server_disconnected):
			mp.server_disconnected.connect(_on_server_disconnected)


func _get_multiplayer_api() -> MultiplayerAPI:
	if is_inside_tree():
		return multiplayer
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).get_multiplayer()
	return null


func host_game(port: int = DEFAULT_PORT) -> Error:
	_cleanup_peer()
	enet_peer = ENetMultiplayerPeer.new()
	var error: Error = enet_peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		push_error("NetworkManager: Falha ao iniciar servidor na porta %d. Código de erro: %d" % [port, error])
		enet_peer = null
		return error
	
	var mp: MultiplayerAPI = _get_multiplayer_api()
	if mp != null:
		mp.multiplayer_peer = enet_peer
	
	connected_players.clear()
	
	# O Host é registrado como peer 1
	var host_data: Dictionary = {
		"peer_id": 1,
		"name": "Host",
	}
	connected_players[1] = host_data
	player_connected.emit(1)
	return OK


func join_game(ip_address: String, port: int = DEFAULT_PORT) -> Error:
	_cleanup_peer()
	var target_ip: String = ip_address.strip_edges()
	if target_ip.is_empty():
		target_ip = "127.0.0.1"
	
	enet_peer = ENetMultiplayerPeer.new()
	var error: Error = enet_peer.create_client(target_ip, port)
	if error != OK:
		push_error("NetworkManager: Falha ao conectar ao servidor em %s:%d. Código de erro: %d" % [target_ip, port, error])
		enet_peer = null
		return error
	
	var mp: MultiplayerAPI = _get_multiplayer_api()
	if mp != null:
		mp.multiplayer_peer = enet_peer
	
	connected_players.clear()
	return OK


func disconnect_game() -> void:
	_cleanup_peer()


func _cleanup_peer() -> void:
	if enet_peer != null:
		enet_peer.close()
		enet_peer = null
	
	var mp: MultiplayerAPI = _get_multiplayer_api()
	if mp != null and mp.multiplayer_peer != null:
		mp.multiplayer_peer = null
	
	connected_players.clear()


func _on_peer_connected(id: int) -> void:
	if not connected_players.has(id):
		connected_players[id] = {
			"peer_id": id,
			"name": "Jogador %d" % id,
		}
	player_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if connected_players.has(id):
		connected_players.erase(id)
	player_disconnected.emit(id)


func _on_connected_to_server() -> void:
	var my_id: int = 1
	var mp: MultiplayerAPI = _get_multiplayer_api()
	if mp != null:
		my_id = mp.get_unique_id()
	
	if not connected_players.has(my_id):
		connected_players[my_id] = {
			"peer_id": my_id,
			"name": "Jogador %d" % my_id,
		}
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	_cleanup_peer()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	_cleanup_peer()
	server_disconnected.emit()
