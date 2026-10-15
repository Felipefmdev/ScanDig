class_name NetworkManager
extends Node

## Gerenciador de conexão de rede multiplayer via ENetMultiplayerPeer.
## Também cuida dos nomes dos jogadores (o host é a fonte da verdade) e do UPnP opcional.

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()
## O próprio peer saiu da sessão por disconnect_game() (não emite em queda nem no _exit_tree).
## was_host = este peer era o servidor online antes de sair.
signal session_left(was_host: bool)
## A lista connected_players mudou (entrada, saída ou nome). Emitido em todos os peers.
signal players_changed()
## Erro legível para a UI (também emitido junto com connection_failed quando for o caso).
signal connection_error(message: String)
## Só no host, depois de start_upnp(): resultado do mapeamento de porta.
signal upnp_finished(success: bool, public_ip: String, message: String)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4
const NAME_MAX_LENGTH: int = 16
const JOIN_TIMEOUT_SEC: float = 10.0
const SETTINGS_PATH: String = "user://scandig_settings.cfg"
const HOST_PEER_ID: int = 1
## Tempo máximo que a saída da sessão espera a thread do UPnP terminar.
const UPNP_STOP_TIMEOUT_MSEC: int = 3000

static var instance: NetworkManager = null

## {peer_id: {"peer_id": int, "name": String}}. No host é a lista oficial; nos clientes vem do _rpc_sync_players.
var connected_players: Dictionary = {}
var enet_peer: ENetMultiplayerPeer = null
## Carregado do SETTINGS_PATH no _ready.
var local_player_name: String = ""
## Preenchido quando o UPnP dá certo; "" senão.
var public_ip: String = ""

## Só para testes: devolve um objeto com a API do UPNP (discover, get_gateway, ...) no lugar do real.
var _upnp_factory: Callable = Callable()
## Só no host: peer_id -> nome escolhido pelo jogador (sem os nomes padrão).
var _registered_names: Dictionary = {}
var _join_timer: Timer = null
var _upnp_thread: Thread = null
var _upnp_semaphore: Semaphore = null
var _upnp_mutex: Mutex = Mutex.new()
var _upnp_cancelled: bool = false
## Threads de UPnP que passaram do limite na saída; juntadas no _exit_tree.
var _stale_upnp_threads: Array[Thread] = []
## No _exit_tree a limpeza não emite sinais: quem ouve pode já estar fora da árvore.
var _shutting_down: bool = false


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	_shutting_down = true
	_cleanup_peer()
	for thread: Thread in _stale_upnp_threads:
		thread.wait_to_finish()
	_stale_upnp_threads.clear()


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
	_join_timer = Timer.new()
	_join_timer.one_shot = true
	_join_timer.timeout.connect(_on_join_timeout)
	add_child(_join_timer)
	_load_settings()


func _get_multiplayer_api() -> MultiplayerAPI:
	if is_inside_tree():
		return multiplayer
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).get_multiplayer()
	return null


# --- Sessão -----------------------------------------------------------------------

func host_game(port: int = DEFAULT_PORT) -> Error:
	_cleanup_peer()
	enet_peer = ENetMultiplayerPeer.new()
	var error: Error = enet_peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		push_error("NetworkManager: Falha ao iniciar servidor na porta %d. Código de erro: %d" % [port, error])
		enet_peer = null
		connection_error.emit("Não foi possível hospedar: a porta %d já está em uso." % port)
		return error

	var mp: MultiplayerAPI = _get_multiplayer_api()
	if mp != null:
		mp.multiplayer_peer = enet_peer

	connected_players.clear()
	_registered_names.clear()
	if not local_player_name.is_empty():
		_registered_names[HOST_PEER_ID] = local_player_name
	# O Host é registrado como peer 1
	connected_players[HOST_PEER_ID] = {"peer_id": HOST_PEER_ID, "name": ""}
	_rebuild_host_names()
	player_connected.emit(HOST_PEER_ID)
	players_changed.emit()
	return OK


func join_game(ip_address: String, port: int = DEFAULT_PORT) -> Error:
	var target_ip: String = ip_address.strip_edges()
	if target_ip.is_empty():
		target_ip = "127.0.0.1"
	if not target_ip.is_valid_ip_address():
		connection_error.emit("Endereço inválido: %s" % target_ip)
		return ERR_INVALID_PARAMETER

	_cleanup_peer()
	enet_peer = ENetMultiplayerPeer.new()
	var error: Error = enet_peer.create_client(target_ip, port)
	if error != OK:
		push_error("NetworkManager: Falha ao conectar ao servidor em %s:%d. Código de erro: %d" % [target_ip, port, error])
		enet_peer = null
		connection_error.emit("Não foi possível conectar (host offline, porta fechada ou sala cheia).")
		return error

	var mp: MultiplayerAPI = _get_multiplayer_api()
	if mp != null:
		mp.multiplayer_peer = enet_peer

	connected_players.clear()
	if _join_timer != null:
		_join_timer.start(JOIN_TIMEOUT_SEC)
	return OK


func disconnect_game() -> void:
	# Captura antes da limpeza: depois dela o peer é offline e is_server() dá true sempre.
	var mp: MultiplayerAPI = _get_multiplayer_api()
	var was_online: bool = enet_peer != null or (mp != null and mp.multiplayer_peer != null and not (mp.multiplayer_peer is OfflineMultiplayerPeer))
	var was_host: bool = was_online and mp != null and mp.has_multiplayer_peer() and mp.is_server()
	_cleanup_peer()
	if was_online:
		session_left.emit(was_host)


func _cleanup_peer() -> void:
	if _join_timer != null:
		_join_timer.stop()
	_stop_upnp()
	if enet_peer != null:
		enet_peer.close()
		enet_peer = null

	var mp: MultiplayerAPI = _get_multiplayer_api()
	if mp != null and mp.multiplayer_peer != null and not (mp.multiplayer_peer is OfflineMultiplayerPeer):
		mp.multiplayer_peer = OfflineMultiplayerPeer.new()

	_registered_names.clear()
	if not connected_players.is_empty():
		connected_players.clear()
		if not _shutting_down:
			players_changed.emit()


# --- Nomes ------------------------------------------------------------------------

## Limpa (strip, sem caracteres de controle, no máximo NAME_MAX_LENGTH). Pode devolver "".
static func sanitize_player_name(raw: String) -> String:
	var clean: String = ""
	for i in range(raw.length()):
		var code: int = raw.unicode_at(i)
		if code >= 32 and code != 127:
			clean += raw[i]
	clean = clean.strip_edges()
	return clean.left(NAME_MAX_LENGTH).strip_edges()


## Troca o nome local; persist=false não grava o arquivo (para testes). Se online, propaga.
func set_local_player_name(player_name: String, persist: bool = true) -> void:
	local_player_name = sanitize_player_name(player_name)
	if persist:
		_save_settings()
	if not _is_online():
		return
	if multiplayer.is_server():
		if local_player_name.is_empty():
			_registered_names.erase(HOST_PEER_ID)
		else:
			_registered_names[HOST_PEER_ID] = local_player_name
		_rebuild_host_names()
		_broadcast_players()
		players_changed.emit()
	else:
		_rpc_register_name.rpc_id(HOST_PEER_ID, local_player_name)


## Nome para exibir: o nome registrado, ou "Host" para o peer 1, ou "Jogador N"
## (N = posição 1-based na lista ordenada de ids).
func get_player_name(peer_id: int) -> String:
	if connected_players.has(peer_id):
		var entry: Dictionary = connected_players[peer_id]
		var entry_name: String = str(entry.get("name", ""))
		if not entry_name.is_empty():
			return entry_name
	return _default_player_name(peer_id)


## IPv4 privados da máquina (10.x, 172.16–31.x, 192.168.x), para "jogar na mesma rede".
func get_local_addresses() -> Array[String]:
	var addresses: Array[String] = []
	for address: String in IP.get_local_addresses():
		if _is_private_ipv4(address) and not addresses.has(address):
			addresses.append(address)
	addresses.sort()
	return addresses


## Cliente -> host: nome escolhido pelo jogador.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_name(player_name: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or sender == 0:
		return
	var clean: String = sanitize_player_name(player_name)
	if clean.is_empty():
		# Sem nome: fica o padrão de get_player_name(sender).
		_registered_names.erase(sender)
	else:
		_registered_names[sender] = clean
	_rebuild_host_names()
	_broadcast_players()
	players_changed.emit()


## Host -> todos: lista oficial de jogadores.
@rpc("authority", "call_remote", "reliable")
func _rpc_sync_players(players: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != HOST_PEER_ID:
		return
	var synced: Dictionary = {}
	for key: Variant in players.keys():
		var value: Variant = players[key]
		if typeof(key) != TYPE_INT or not (value is Dictionary):
			continue
		var entry: Dictionary = value
		if typeof(entry.get("name")) != TYPE_STRING:
			continue
		var peer_id: int = key
		synced[peer_id] = {"peer_id": peer_id, "name": sanitize_player_name(entry["name"])}
	connected_players = synced
	players_changed.emit()


# --- UPnP -------------------------------------------------------------------------

## Só host online: tenta abrir `port` (UDP) no roteador via UPNP numa Thread; NÃO bloqueia.
## Resposta em upnp_finished. Nunca é chamado por host_game(): só pela UI.
func start_upnp(port: int = DEFAULT_PORT) -> void:
	if not _is_online() or not multiplayer.is_server():
		push_warning("NetworkManager: start_upnp ignorado (só o host online abre porta).")
		return
	if _upnp_thread != null:
		push_warning("NetworkManager: start_upnp ignorado (UPnP já em andamento).")
		return
	public_ip = ""
	_upnp_mutex.lock()
	_upnp_cancelled = false
	_upnp_mutex.unlock()
	_upnp_semaphore = Semaphore.new()
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_worker.bind(port, _upnp_semaphore))


## Roda na thread: descobre o gateway, mapeia a porta e, se mapeou, espera a saída
## da sessão para remover o mapeamento.
func _upnp_worker(port: int, release: Semaphore) -> void:
	var upnp: Object = _upnp_factory.call() if _upnp_factory.is_valid() else UPNP.new()
	var success: bool = false
	var ip: String = ""
	var message: String = ""
	var discover_result: int = int(upnp.call("discover"))
	var gateway: Object = upnp.call("get_gateway") if discover_result == UPNP.UPNP_RESULT_SUCCESS else null
	if gateway == null or not bool(gateway.call("is_valid_gateway")):
		message = "UPnP indisponível: abra a porta %d (UDP) no roteador ou jogue na mesma rede." % port
	elif int(upnp.call("add_port_mapping", port, port, "ScanDig", "UDP")) != UPNP.UPNP_RESULT_SUCCESS:
		message = "O roteador recusou abrir a porta %d (UPnP). Abra manualmente (UDP)." % port
	else:
		success = true
		ip = str(upnp.call("query_external_address"))
		message = "Porta %d aberta no roteador. Passe o IP %s aos amigos." % [port, ip]
	_upnp_mutex.lock()
	var cancelled: bool = _upnp_cancelled
	_upnp_mutex.unlock()
	if not cancelled:
		call_deferred(&"_on_upnp_finished", success, ip, message)
	if success:
		release.wait()
		upnp.call("delete_port_mapping", port, "UDP")


func _on_upnp_finished(success: bool, ip: String, message: String) -> void:
	_upnp_mutex.lock()
	var cancelled: bool = _upnp_cancelled
	_upnp_mutex.unlock()
	if cancelled:
		return
	public_ip = ip if success else ""
	upnp_finished.emit(success, public_ip, message)


## Libera a thread (que remove o mapeamento) e espera até UPNP_STOP_TIMEOUT_MSEC.
func _stop_upnp() -> void:
	public_ip = ""
	if _upnp_thread == null:
		return
	_upnp_mutex.lock()
	_upnp_cancelled = true
	_upnp_mutex.unlock()
	_upnp_semaphore.post()
	var deadline: int = Time.get_ticks_msec() + UPNP_STOP_TIMEOUT_MSEC
	while _upnp_thread.is_alive() and Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)
	if _upnp_thread.is_alive():
		push_warning("NetworkManager: UPnP ainda respondendo; a thread termina em segundo plano.")
		_stale_upnp_threads.append(_upnp_thread)
	else:
		_upnp_thread.wait_to_finish()
	_upnp_thread = null
	_upnp_semaphore = null


# --- Eventos ----------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if not connected_players.has(id):
		connected_players[id] = {"peer_id": id, "name": ""}
	if multiplayer.is_server():
		_rebuild_host_names()
		_broadcast_players()
	player_connected.emit(id)
	players_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if connected_players.has(id):
		connected_players.erase(id)
	_registered_names.erase(id)
	if multiplayer.is_server():
		_rebuild_host_names()
		_broadcast_players()
	player_disconnected.emit(id)
	players_changed.emit()


func _on_connected_to_server() -> void:
	if _join_timer != null:
		_join_timer.stop()
	var my_id: int = 1
	var mp: MultiplayerAPI = _get_multiplayer_api()
	if mp != null:
		my_id = mp.get_unique_id()

	if not connected_players.has(my_id):
		connected_players[my_id] = {"peer_id": my_id, "name": local_player_name}
	_rpc_register_name.rpc_id(HOST_PEER_ID, local_player_name)
	connection_succeeded.emit()
	players_changed.emit()


func _on_connection_failed() -> void:
	_cleanup_peer()
	connection_failed.emit()
	connection_error.emit("Não foi possível conectar (host offline, porta fechada ou sala cheia).")


func _on_join_timeout() -> void:
	_cleanup_peer()
	connection_failed.emit()
	connection_error.emit("O host não respondeu em %d s. Confira o IP e se a porta está aberta." % int(JOIN_TIMEOUT_SEC))


func _on_server_disconnected() -> void:
	_cleanup_peer()
	server_disconnected.emit()


# --- Utilitários ------------------------------------------------------------------

## Host: recalcula o "name" de cada entrada (nome escolhido ou padrão).
func _rebuild_host_names() -> void:
	for peer_id: int in connected_players.keys():
		var registered: String = str(_registered_names.get(peer_id, ""))
		connected_players[peer_id] = {
			"peer_id": peer_id,
			"name": registered if not registered.is_empty() else _default_player_name(peer_id),
		}


## Host: envia a lista oficial aos clientes. players_changed fica com quem chama.
func _broadcast_players() -> void:
	if _is_online() and multiplayer.is_server():
		_rpc_sync_players.rpc(connected_players.duplicate(true))


func _default_player_name(peer_id: int) -> String:
	if peer_id == HOST_PEER_ID:
		return "Host"
	var ids: Array = connected_players.keys()
	if not ids.has(peer_id):
		ids.append(peer_id)
	ids.sort()
	return "Jogador %d" % (ids.find(peer_id) + 1)


func _is_online() -> bool:
	var mp: MultiplayerAPI = _get_multiplayer_api()
	return mp != null and mp.has_multiplayer_peer() and not (mp.multiplayer_peer is OfflineMultiplayerPeer)


static func _is_private_ipv4(address: String) -> bool:
	if not address.is_valid_ip_address() or address.contains(":"):
		return false
	var parts: PackedStringArray = address.split(".")
	if parts.size() != 4:
		return false
	var a: int = parts[0].to_int()
	var b: int = parts[1].to_int()
	return a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168)


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		local_player_name = sanitize_player_name(str(config.get_value("player", "name", "")))


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("player", "name", local_player_name)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("NetworkManager: falha ao gravar %s (erro %d)." % [SETTINGS_PATH, error])
