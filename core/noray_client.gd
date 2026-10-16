class_name NorayClient
extends Node

## Cliente mínimo do servidor noray 1.5.x (github.com/foxssake/noray, MIT), usado pelo
## NetworkManager para o código de sala (#30). O handshake segue o addon netfox.noray (MIT).
##
## Protocolo: TCP de texto, uma linha "comando dados\n" por mensagem.
## 1. "register-host" -> "set-oid <oid>" e "set-pid <pid>".
## 2. O PID vai por UDP ao registrador, que responde "OK": a porta UDP de origem vira a
##    porta pública deste peer (o ENet tem de usar a mesma).
## 3. "connect <oid>" (punch) ou "connect-relay <oid>" (relay). Os dois lados recebem o
##    mesmo comando: "connect ip:porta" ou "connect-relay porta" (no IP do noray).
##    Sala inexistente: o comando volta sem dados.
## 4. Handshake UDP de 3 estados ("$rwx") para abrir o NAT antes do ENet.
## Todo await tem prazo e confere se a conexão ainda é a mesma.

## Host: um cliente pediu conexão. Abra o caminho com handshake_enet(peer, address, port).
signal connect_requested(address: String, port: int)
## A conexão TCP com o noray caiu sem close() local.
signal server_lost()

const CONNECT_TIMEOUT_SEC: float = 5.0
const REPLY_TIMEOUT_SEC: float = 5.0
const REGISTRAR_TIMEOUT_SEC: float = 3.0
const REGISTRAR_RESEND_SEC: float = 0.1
const HANDSHAKE_RESEND_SEC: float = 0.1
## Host: por quanto tempo manda o handshake depois de um pedido de conexão.
const HOST_HANDSHAKE_SEC: float = 5.0
const CMD_CONNECT: String = "connect"
const CMD_CONNECT_RELAY: String = "connect-relay"

## IPv4 do noray depois de connect_to_server.
var server_address: String = ""
## Open ID (o código da sala) e Private ID, depois de register.
var oid: String = ""
var pid: String = ""
## Porta UDP registrada no noray; o ENet deste peer tem de usar esta porta.
var local_port: int = 0

var _tcp: StreamPeerTCP = null
var _connected: bool = false
## Host recebe connect/connect-relay sem ter pedido; cliente recebe a resposta ao pedido.
var _is_host: bool = false
var _buffer: String = ""
## comando -> dados da última linha recebida e ainda não consumida.
var _replies: Dictionary = {}


func _process(_delta: float) -> void:
	if _tcp == null or not _connected:
		return
	_tcp.poll()
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		close()
		server_lost.emit()
		return
	var available: int = _tcp.get_available_bytes()
	if available <= 0:
		return
	var result: Array = _tcp.get_data(available)
	if int(result[0]) != OK:
		return
	var bytes: PackedByteArray = result[1]
	_buffer += bytes.get_string_from_utf8()
	var newline: int = _buffer.find("\n")
	while newline >= 0:
		_handle_line(_buffer.left(newline).strip_edges())
		_buffer = _buffer.substr(newline + 1)
		newline = _buffer.find("\n")


func is_connected_to_server() -> bool:
	return _tcp != null and _connected


## Abre o TCP com o noray. ERR_CANT_CONNECT se não abrir em CONNECT_TIMEOUT_SEC.
func connect_to_server(address: String, port: int) -> Error:
	close()
	var ip: String = address if address.is_valid_ip_address() else IP.resolve_hostname(address, IP.TYPE_IPV4)
	if ip.is_empty():
		return ERR_CANT_RESOLVE
	var tcp: StreamPeerTCP = StreamPeerTCP.new()
	if tcp.connect_to_host(ip, port) != OK:
		return ERR_CANT_CONNECT
	_tcp = tcp
	var deadline: int = _deadline(CONNECT_TIMEOUT_SEC)
	while true:
		if _tcp != tcp:
			return ERR_CANT_CONNECT
		tcp.poll()
		var status: StreamPeerTCP.Status = tcp.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			break
		if status != StreamPeerTCP.STATUS_CONNECTING or Time.get_ticks_msec() >= deadline:
			close()
			return ERR_CANT_CONNECT
		var tree: SceneTree = get_tree()
		if tree == null:
			close()
			return ERR_CANT_CONNECT
		await tree.process_frame
		if not is_inside_tree():
			close()
			return ERR_CANT_CONNECT
	tcp.set_no_delay(true)
	server_address = ip
	_connected = true
	return OK


## Pede OID/PID e registra a porta UDP `bind_port` (0 = qualquer) no registrador.
## ERR_ALREADY_IN_USE se a porta estiver ocupada; ERR_TIMEOUT se o noray não responder.
func register(registrar_port: int, bind_port: int, as_host: bool) -> Error:
	if not is_connected_to_server():
		return ERR_CONNECTION_ERROR
	_is_host = as_host
	_replies.erase("set-oid")
	_replies.erase("set-pid")
	_send("register-host")
	var tcp: StreamPeerTCP = _tcp
	if not await _wait_for_replies(["set-oid", "set-pid"], REPLY_TIMEOUT_SEC, tcp):
		return ERR_TIMEOUT if _tcp == tcp else ERR_CONNECTION_ERROR
	oid = str(_replies["set-oid"])
	pid = str(_replies["set-pid"])

	var udp: PacketPeerUDP = PacketPeerUDP.new()
	if udp.bind(bind_port) != OK:
		return ERR_ALREADY_IN_USE
	udp.set_dest_address(server_address, registrar_port)
	var packet: PackedByteArray = pid.to_utf8_buffer()
	var result: Error = ERR_TIMEOUT
	var deadline: int = _deadline(REGISTRAR_TIMEOUT_SEC)
	var next_send: int = 0
	while Time.get_ticks_msec() < deadline:
		if _tcp != tcp:
			result = ERR_CONNECTION_ERROR
			break
		if Time.get_ticks_msec() >= next_send:
			udp.put_packet(packet)
			next_send = Time.get_ticks_msec() + int(REGISTRAR_RESEND_SEC * 1000.0)
		while udp.get_available_packet_count() > 0:
			var reply: String = udp.get_packet().get_string_from_utf8()
			# Só vale a resposta do próprio registrador.
			if udp.get_packet_ip() == server_address and udp.get_packet_port() == registrar_port:
				result = OK if reply == "OK" else FAILED
		if result != ERR_TIMEOUT:
			break
		var tree: SceneTree = get_tree()
		if tree == null:
			result = ERR_CONNECTION_ERROR
			break
		await tree.process_frame
		if not is_inside_tree():
			result = ERR_CONNECTION_ERROR
			break
	if result == OK:
		local_port = udp.get_local_port()
	udp.close()
	return result


## Cliente: pede a conexão com a sala `target_oid` pelo punch ou pelo relay.
## {"error": Error, "address": String, "port": int}; sala inexistente = ERR_DOES_NOT_EXIST.
func request_connect(target_oid: String, relay: bool) -> Dictionary:
	var command: String = CMD_CONNECT_RELAY if relay else CMD_CONNECT
	var reply: Dictionary = {"error": ERR_CONNECTION_ERROR, "address": "", "port": 0}
	if not is_connected_to_server():
		return reply
	_replies.erase(command)
	_send("%s %s" % [command, target_oid])
	var tcp: StreamPeerTCP = _tcp
	if not await _wait_for_replies([command], REPLY_TIMEOUT_SEC, tcp):
		reply["error"] = ERR_TIMEOUT if _tcp == tcp else ERR_CONNECTION_ERROR
		return reply
	var target: Dictionary = _parse_target(command, str(_replies[command]))
	_replies.erase(command)
	if target.is_empty():
		reply["error"] = ERR_DOES_NOT_EXIST
		return reply
	reply["error"] = OK
	reply["address"] = target["address"]
	reply["port"] = target["port"]
	return reply


## Cliente: handshake de 3 estados pela porta registrada, só com pacotes de address:port.
## OK = os dois lados se ouviram; ERR_BUSY = só ouvimos o outro lado (dá para tentar o
## ENet mesmo assim); ERR_TIMEOUT = nada chegou em `timeout_sec`.
func handshake_udp(address: String, port: int, timeout_sec: float) -> Error:
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	if udp.bind(local_port) != OK:
		return ERR_ALREADY_IN_USE
	udp.set_dest_address(address, port)
	var did_read: bool = false
	var did_handshake: bool = false
	var result: Error = ERR_TIMEOUT
	var deadline: int = _deadline(timeout_sec)
	var next_send: int = 0
	while Time.get_ticks_msec() < deadline and result != OK:
		while udp.get_available_packet_count() > 0:
			var text: String = udp.get_packet().get_string_from_ascii()
			if udp.get_packet_ip() != address or udp.get_packet_port() != port or not text.begins_with("$"):
				continue
			did_read = true
			if text.contains("r"):
				did_handshake = true
			if text.contains("x") and did_handshake:
				result = OK
		if Time.get_ticks_msec() >= next_send:
			udp.put_packet(_handshake_status(did_read, did_handshake).to_ascii_buffer())
			next_send = Time.get_ticks_msec() + int(HANDSHAKE_RESEND_SEC * 1000.0)
		if result != OK:
			var tree: SceneTree = get_tree()
			if tree == null:
				result = ERR_CONNECTION_ERROR
				break
			await tree.process_frame
			if not is_inside_tree():
				result = ERR_CONNECTION_ERROR
				break
	udp.close()
	if result != OK and did_read:
		result = ERR_BUSY
	return result


## Host: o socket do ENet não lê pacotes soltos, então só manda "$rwx" ao cliente
## (ou à porta de relay dele) por HOST_HANDSHAKE_SEC, enquanto o peer estiver aberto.
func handshake_enet(peer: ENetMultiplayerPeer, address: String, port: int) -> void:
	var packet: PackedByteArray = _handshake_status(true, true, true).to_ascii_buffer()
	var deadline: int = _deadline(HOST_HANDSHAKE_SEC)
	while Time.get_ticks_msec() < deadline:
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or peer.host == null:
			return
		peer.host.socket_send(address, port, packet)
		var tree: SceneTree = get_tree()
		if tree == null:
			return
		await tree.create_timer(HANDSHAKE_RESEND_SEC).timeout
		if not is_inside_tree():
			return


## Fecha o TCP e esquece o registro. Não emite server_lost.
func close() -> void:
	_connected = false
	if _tcp != null:
		_tcp.disconnect_from_host()
		_tcp = null
	_buffer = ""
	_replies.clear()
	_is_host = false
	oid = ""
	pid = ""
	local_port = 0


func _handle_line(line: String) -> void:
	if line.is_empty():
		return
	var space: int = line.find(" ")
	var command: String = line if space < 0 else line.left(space)
	var data: String = "" if space < 0 else line.substr(space + 1).strip_edges()
	if _is_host and (command == CMD_CONNECT or command == CMD_CONNECT_RELAY):
		var target: Dictionary = _parse_target(command, data)
		if not target.is_empty():
			connect_requested.emit(str(target["address"]), int(target["port"]))
		return
	_replies[command] = data


## "connect ip:porta" ou "connect-relay porta" (no IP do noray). {} se inválido.
func _parse_target(command: String, data: String) -> Dictionary:
	var address: String = server_address
	var port_text: String = data
	if command == CMD_CONNECT:
		var colon: int = data.rfind(":")
		if colon <= 0:
			return {}
		address = data.left(colon)
		port_text = data.substr(colon + 1)
	if not address.is_valid_ip_address() or not port_text.is_valid_int():
		return {}
	var port: int = port_text.to_int()
	if port <= 0 or port > 65535:
		return {}
	return {"address": address, "port": port}


## Espera todas as `keys` em _replies, enquanto o TCP ainda for `tcp`.
func _wait_for_replies(keys: Array[String], timeout_sec: float, tcp: StreamPeerTCP) -> bool:
	var deadline: int = _deadline(timeout_sec)
	while Time.get_ticks_msec() < deadline:
		if _tcp != tcp or not _connected:
			return false
		var all_in: bool = true
		for key: String in keys:
			all_in = all_in and _replies.has(key)
		if all_in:
			return true
		var tree: SceneTree = get_tree()
		if tree == null:
			return false
		await tree.process_frame
		if not is_inside_tree():
			return false
	return false


func _send(line: String) -> void:
	if is_connected_to_server():
		_tcp.put_data((line + "\n").to_utf8_buffer())


static func _handshake_status(did_read: bool, did_handshake: bool, did_write: bool = true) -> String:
	return "$%s%s%s" % ["r" if did_read else "-", "w" if did_write else "-", "x" if did_handshake else "-"]


static func _deadline(seconds: float) -> int:
	return Time.get_ticks_msec() + int(seconds * 1000.0)
