class_name SteamPeer
extends MultiplayerPeerExtension

## Spike #54: MultiplayerPeer da Steam em GDScript para a Godot 4.3 (o SteamMultiplayerPeer
## do GodotSteam só existe para 4.4+). Topologia estrela: só o host fala com todos; o
## SceneMultiplayer repassa cliente -> cliente (server relay), como no ENet.
## O transporte é injetado: SteamTransport (Steam Networking Messages, com o relay SDR da
## Steam) no jogo, UdpTransport nos testes com dois processos e uma conta só.
##
## Mensagem: [tipo:u8][remetente:u32][...]. DATA leva [canal:u8][modo:u8][payload].

const PROTOCOL_VERSION: int = 1
const KIND_HELLO: int = 1      # cliente -> host: [id][canal de escuta:u8][versão:u16]
const KIND_WELCOME: int = 2    # host -> cliente
const KIND_DATA: int = 3
const KIND_REJECT: int = 4     # host -> cliente: [motivo:u8]
const KIND_BYE: int = 5
const KIND_PING: int = 6
const REJECT_FULL: int = 1
const REJECT_VERSION: int = 2
const PING_INTERVAL_MS: int = 1000
const PEER_TIMEOUT_MS: int = 10000
const HEADER_SIZE: int = 5

## Transporte mínimo que o peer usa. `remote` é a chave do outro lado (SteamID na Steam).
class Transport:
	extends RefCounted
	func poll() -> void:
		pass
	## [[remote: int, data: PackedByteArray], ...]
	func receive() -> Array:
		return []
	func send(_remote: int, _channel: int, _data: PackedByteArray, _reliable: bool) -> bool:
		return false
	func close_remote(_remote: int) -> void:
		pass
	func close() -> void:
		pass


## Steam Networking Messages: sessões por SteamID, relay SDR automático, sem porta aberta.
class SteamTransport:
	extends Transport
	const SEND_UNRELIABLE_NO_NAGLE: int = 1
	const SEND_RELIABLE_NO_NAGLE: int = 9
	const MAX_MESSAGES_PER_POLL: int = 64
	var steam: Object = null
	var listen_channel: int = 0
	## Lobby da sessão: só aceita pedido de sessão de quem é membro dele (conferido na hora).
	## 0 = aceita qualquer pedido (só para testes).
	var lobby_id: int = 0

	func _init(steam_singleton: Object, channel: int = 0) -> void:
		steam = steam_singleton
		listen_channel = channel
		steam.connect("network_messages_session_request", _on_session_request)

	func _on_session_request(remote_steam_id: int) -> void:
		if lobby_id == 0 or _is_lobby_member(remote_steam_id):
			steam.call("acceptSessionWithUser", remote_steam_id)
		else:
			push_warning("SteamTransport: pedido de sessão de quem não está no lobby ignorado.")

	func _is_lobby_member(steam_id: int) -> bool:
		for i in range(int(steam.call("getNumLobbyMembers", lobby_id))):
			if int(steam.call("getLobbyMemberByIndex", lobby_id, i)) == steam_id:
				return true
		return false

	func poll() -> void:
		steam.call("run_callbacks")

	func receive() -> Array:
		var out: Array = []
		var messages: Array = steam.call("receiveMessagesOnChannel", listen_channel, MAX_MESSAGES_PER_POLL)
		for message: Dictionary in messages:
			out.append([int(message["identity"]), message["payload"] as PackedByteArray])
		return out

	func send(remote: int, channel: int, data: PackedByteArray, reliable: bool) -> bool:
		var flags: int = SEND_RELIABLE_NO_NAGLE if reliable else SEND_UNRELIABLE_NO_NAGLE
		return int(steam.call("sendMessageToUser", remote, data, flags, channel)) == 1

	func close_remote(remote: int) -> void:
		steam.call("closeSessionWithUser", remote)

	func close() -> void:
		if steam.is_connected("network_messages_session_request", _on_session_request):
			steam.disconnect("network_messages_session_request", _on_session_request)


## Só para testes: o mesmo protocolo sobre UDP em 127.0.0.1. `remote` = porta do outro lado.
class UdpTransport:
	extends Transport
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	var host_address: String = "127.0.0.1"

	func _init(bind_port: int) -> void:
		udp.bind(bind_port, "127.0.0.1")

	func receive() -> Array:
		var out: Array = []
		while udp.get_available_packet_count() > 0:
			var data: PackedByteArray = udp.get_packet()
			out.append([udp.get_packet_port(), data])
		return out

	func send(remote: int, _channel: int, data: PackedByteArray, _reliable: bool) -> bool:
		udp.set_dest_address(host_address, remote)
		return udp.put_packet(data) == OK

	func close() -> void:
		udp.close()


var transport: Transport = null
## Canal de escuta deste lado (0 no jogo; o teste de loopback usa outro no cliente).
var listen_channel: int = 0
var max_clients: int = 3

var _is_host: bool = false
var _unique_id: int = 0
var _status: ConnectionStatus = CONNECTION_DISCONNECTED
var _host_remote: int = 0
var _host_channel: int = 0
## peer_id -> {"remote": int, "channel": int, "last_rx": int, "last_tx": int}
var _peers: Dictionary = {}
var _peer_by_remote: Dictionary = {}
var _queue: Array[Dictionary] = []
var _target_peer: int = 0
var _transfer_channel: int = 0
var _transfer_mode: TransferMode = TRANSFER_MODE_RELIABLE
var _refuse: bool = false
var _hello_sent_ms: int = 0


func create_host(host_transport: Transport) -> Error:
	if _status != CONNECTION_DISCONNECTED:
		return ERR_ALREADY_IN_USE
	transport = host_transport
	_is_host = true
	_unique_id = 1
	_status = CONNECTION_CONNECTED
	return OK


## `host_remote`: SteamID do dono do lobby (ou a porta, no UdpTransport).
func create_client(client_transport: Transport, host_remote: int, host_channel: int = 0) -> Error:
	if _status != CONNECTION_DISCONNECTED:
		return ERR_ALREADY_IN_USE
	transport = client_transport
	_is_host = false
	_unique_id = generate_unique_id()
	_host_remote = host_remote
	_host_channel = host_channel
	_status = CONNECTION_CONNECTING
	_send_hello()
	return OK


func get_remote_for_peer(peer_id: int) -> int:
	if _peers.has(peer_id):
		return int(_peers[peer_id]["remote"])
	return 0


func get_peer_for_remote(remote: int) -> int:
	return int(_peer_by_remote.get(remote, 0))


# --- MultiplayerPeerExtension -----------------------------------------------------

func _get_unique_id() -> int:
	return _unique_id


func _is_server() -> bool:
	return _is_host


func _get_connection_status() -> ConnectionStatus:
	return _status


func _is_server_relay_supported() -> bool:
	return true


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable


func _is_refusing_new_connections() -> bool:
	return _refuse


func _set_target_peer(peer: int) -> void:
	_target_peer = peer


func _set_transfer_channel(channel: int) -> void:
	_transfer_channel = channel


func _get_transfer_channel() -> int:
	return _transfer_channel


func _set_transfer_mode(mode: TransferMode) -> void:
	_transfer_mode = mode


func _get_transfer_mode() -> TransferMode:
	return _transfer_mode


func _get_max_packet_size() -> int:
	return 512 * 1024 - HEADER_SIZE - 2


func _get_available_packet_count() -> int:
	return _queue.size()


func _get_packet_peer() -> int:
	return int(_queue[0]["from"]) if not _queue.is_empty() else 0


func _get_packet_channel() -> int:
	return int(_queue[0]["channel"]) if not _queue.is_empty() else 0


func _get_packet_mode() -> TransferMode:
	return int(_queue[0]["mode"]) as TransferMode if not _queue.is_empty() else TRANSFER_MODE_RELIABLE


func _get_packet_script() -> PackedByteArray:
	if _queue.is_empty():
		return PackedByteArray()
	return _queue.pop_front()["data"] as PackedByteArray


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var reliable: bool = _transfer_mode == TRANSFER_MODE_RELIABLE
	var message: PackedByteArray = _header(KIND_DATA)
	message.append(_transfer_channel)
	message.append(_transfer_mode)
	message.append_array(buffer)
	if not _is_host:
		# Cliente só fala com o host; o SceneMultiplayer já embrulhou o relay para outro peer.
		return OK if _send_to_host(message, reliable) else ERR_CONNECTION_ERROR
	for peer_id: int in _peers.keys():
		if _target_peer == 0 or _target_peer == peer_id or (_target_peer < 0 and -_target_peer != peer_id):
			_send_to_peer(peer_id, message, reliable)
	return OK


func _poll() -> void:
	if transport == null or _status == CONNECTION_DISCONNECTED:
		return
	transport.poll()
	var now: int = Time.get_ticks_msec()
	for item: Array in transport.receive():
		_handle(int(item[0]), item[1] as PackedByteArray, now)
	if _status == CONNECTION_CONNECTING and now - _hello_sent_ms > PING_INTERVAL_MS:
		_send_hello()
	for peer_id: int in _peers.keys():
		var info: Dictionary = _peers[peer_id]
		if now - int(info["last_rx"]) > PEER_TIMEOUT_MS:
			_drop_peer(peer_id, false)
		elif now - int(info["last_tx"]) > PING_INTERVAL_MS:
			_send_to_peer(peer_id, _header(KIND_PING), false)


func _disconnect_peer(peer: int, force: bool) -> void:
	if _peers.has(peer):
		_drop_peer(peer, not force)


func _close() -> void:
	if transport != null:
		for peer_id: int in _peers.keys():
			_send_to_peer(peer_id, _header(KIND_BYE), true)
			transport.close_remote(int(_peers[peer_id]["remote"]))
		transport.close()
	_peers.clear()
	_peer_by_remote.clear()
	_queue.clear()
	_status = CONNECTION_DISCONNECTED


# --- Protocolo --------------------------------------------------------------------

func _header(kind: int) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray([kind, 0, 0, 0, 0])
	bytes.encode_u32(1, _unique_id)
	return bytes


func _send_hello() -> void:
	var hello: PackedByteArray = _header(KIND_HELLO)
	hello.append(listen_channel)
	hello.resize(hello.size() + 2)
	hello.encode_u16(hello.size() - 2, PROTOCOL_VERSION)
	transport.send(_host_remote, _host_channel, hello, true)
	_hello_sent_ms = Time.get_ticks_msec()


func _send_to_host(message: PackedByteArray, reliable: bool) -> bool:
	if _peers.has(1):
		_peers[1]["last_tx"] = Time.get_ticks_msec()
	return transport.send(_host_remote, _host_channel, message, reliable)


func _send_to_peer(peer_id: int, message: PackedByteArray, reliable: bool) -> void:
	var info: Dictionary = _peers[peer_id]
	info["last_tx"] = Time.get_ticks_msec()
	transport.send(int(info["remote"]), int(info["channel"]), message, reliable)


func _handle(remote: int, data: PackedByteArray, now: int) -> void:
	if data.size() < HEADER_SIZE:
		return
	var kind: int = data[0]
	var sender: int = data.decode_u32(1)
	if _is_host:
		_handle_on_host(remote, kind, sender, data, now)
	else:
		_handle_on_client(remote, kind, data, now)


func _handle_on_host(remote: int, kind: int, sender: int, data: PackedByteArray, now: int) -> void:
	if kind == KIND_HELLO:
		if _peers.has(sender) and int(_peers[sender]["remote"]) == remote:
			_peers[sender]["last_rx"] = now
			_reply(remote, data, KIND_WELCOME)  # HELLO repetido: o WELCOME se perdeu
			return
		var version: int = data.decode_u16(HEADER_SIZE + 1) if data.size() >= HEADER_SIZE + 3 else 0
		if version != PROTOCOL_VERSION:
			_reply(remote, data, KIND_REJECT, REJECT_VERSION)
			return
		if _refuse or _peers.size() >= max_clients or sender <= 1 or _peers.has(sender):
			_reply(remote, data, KIND_REJECT, REJECT_FULL)
			return
		_peers[sender] = {"remote": remote, "channel": data[HEADER_SIZE], "last_rx": now, "last_tx": 0}
		_peer_by_remote[remote] = sender
		_reply(remote, data, KIND_WELCOME)
		peer_connected.emit(sender)
		return
	# Só aceita o que vem do remoto registrado para aquele id (sem forjar remetente).
	if not _peers.has(sender) or int(_peers[sender]["remote"]) != remote:
		return
	_peers[sender]["last_rx"] = now
	if kind == KIND_DATA:
		_enqueue(sender, data)
	elif kind == KIND_BYE:
		_drop_peer(sender, false)


func _handle_on_client(remote: int, kind: int, data: PackedByteArray, now: int) -> void:
	if remote != _host_remote:
		return
	if kind == KIND_WELCOME and _status == CONNECTION_CONNECTING:
		_peers[1] = {"remote": _host_remote, "channel": _host_channel, "last_rx": now, "last_tx": now}
		_peer_by_remote[_host_remote] = 1
		_status = CONNECTION_CONNECTED
		peer_connected.emit(1)
		return
	if kind == KIND_REJECT:
		_status = CONNECTION_DISCONNECTED
		return
	if not _peers.has(1):
		return
	_peers[1]["last_rx"] = now
	if kind == KIND_DATA:
		_enqueue(1, data)
	elif kind == KIND_BYE:
		_drop_peer(1, false)


func _reply(remote: int, hello: PackedByteArray, kind: int, reason: int = 0) -> void:
	var channel: int = hello[HEADER_SIZE] if hello.size() > HEADER_SIZE else 0
	var message: PackedByteArray = _header(kind)
	if kind == KIND_REJECT:
		message.append(reason)
	transport.send(remote, channel, message, true)


func _enqueue(from: int, data: PackedByteArray) -> void:
	if data.size() < HEADER_SIZE + 2:
		return
	_queue.append({"from": from, "channel": data[HEADER_SIZE], "mode": data[HEADER_SIZE + 1],
		"data": data.slice(HEADER_SIZE + 2)})


func _drop_peer(peer_id: int, notify: bool) -> void:
	var info: Dictionary = _peers[peer_id]
	if notify:
		_send_to_peer(peer_id, _header(KIND_BYE), true)
	transport.close_remote(int(info["remote"]))
	_peer_by_remote.erase(int(info["remote"]))
	_peers.erase(peer_id)
	peer_disconnected.emit(peer_id)
	if not _is_host:
		_status = CONNECTION_DISCONNECTED
