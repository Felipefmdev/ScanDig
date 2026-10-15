## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_room_errors_test.gd
## Erros da sala online (#30): código inválido e noray fora do ar sempre rodam; sala
## inexistente precisa do noray local (sem ele: "SKIP noray offline").
extends SceneTree
const DEAD_NORAY_PORT: int = 8899
## O erro tem de chegar bem antes do prazo de 15 s do join.
const ERROR_LIMIT_MS: int = 8000
var _fails: int = 0
var _errors: Array[String] = []
func _w(s: float) -> void:
	await create_timer(s).timeout
func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()):
		if t >= timeout_s:
			return false
		await _w(0.1)
		t += 0.1
	return true
func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1
func _noray_up(address: String, port: int) -> bool:
	var tcp: StreamPeerTCP = StreamPeerTCP.new()
	if tcp.connect_to_host(address, port) != OK:
		return false
	var t: float = 0.0
	while t < 2.0:
		tcp.poll()
		if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			tcp.disconnect_from_host()
			return true
		if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTING:
			return false
		await _w(0.05)
		t += 0.05
	return false
## Roda `start` e espera o primeiro connection_error; devolve [mensagem, ms].
func _first_error(start: Callable) -> Array:
	_errors.clear()
	var t0: int = Time.get_ticks_msec()
	start.call()
	await _wait_until(func() -> bool: return not _errors.is_empty(), 12.0)
	return [_errors[0] if not _errors.is_empty() else "", Time.get_ticks_msec() - t0]
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("net_room_errors_test")
	var net: NetworkManager = NetworkManager.instance
	net.connection_error.connect(func(message: String) -> void: _errors.append(message))
	var failed: Array[int] = [0]
	net.connection_failed.connect(func() -> void: failed[0] += 1)

	# Código inválido: na hora, sem tocar no noray.
	for code: String in ["", "ABC", "O0I-1XY", "K7Q3MX9", "K7Q_3M"]:
		_errors.clear()
		var err: Error = net.join_code(code)
		_check(err == ERR_INVALID_PARAMETER and _errors == ["Código de sala inválido."], "inválido %s: %s" % [JSON.stringify(code), str(_errors)])
	_check(net.get_room_code().is_empty() and not net.is_online_room(), "código inválido não abre sala")

	# Noray fora do ar (porta sem servidor).
	var real_port: int = net.noray_port
	net.noray_port = DEAD_NORAY_PORT
	var result: Array = await _first_error(func() -> void: net.join_code("K7Q-3MX"))
	print("noray_off_join_ms=", result[1])
	_check(result[0] == "Servidor de salas fora do ar." and int(result[1]) <= ERROR_LIMIT_MS, "join sem noray: %s em %d ms" % [result[0], result[1]])
	_check(failed[0] == 1, "connection_failed no cliente: %d" % failed[0])
	result = await _first_error(func() -> void: net.host_online(7799))
	print("noray_off_host_ms=", result[1])
	_check(result[0] == "Servidor de salas fora do ar." and int(result[1]) <= ERROR_LIMIT_MS, "host sem noray: %s em %d ms" % [result[0], result[1]])
	_check(not net._is_online() and not net.is_online_room(), "sem peer depois do erro")
	net.noray_port = real_port

	# Noray no ar mas sem NORAY_OID_LENGTH=6: OID de 21 caracteres. Injetado direto, sem rede.
	var codes: Array[String] = []
	net.room_code_ready.connect(func(code: String) -> void: codes.append(code))
	_errors.clear()
	net._open_host_room(7799, "-ULy5ouMvB5rz7UTQ5QzL")
	_check(_errors == ["Servidor de salas mal configurado: código com 21 caracteres (esperado 6)."], "OID fora do formato: %s" % str(_errors))
	_check(codes.is_empty(), "sem room_code_ready com OID inválido: %s" % str(codes))
	_check(not net._is_online() and net.enet_peer == null and not net.is_online_room(), "ENet fechado com OID inválido")

	# Sala inexistente: precisa do noray.
	if not await _noray_up(net.noray_address, net.noray_port):
		print("SKIP noray offline (sala inexistente)")
	else:
		result = await _first_error(func() -> void: net.join_code("ZZZ-ZZZ"))
		print("room_not_found_ms=", result[1])
		_check(result[0] == "Sala não encontrada." and int(result[1]) <= ERROR_LIMIT_MS, "sala inexistente: %s em %d ms" % [result[0], result[1]])
		_check(not net._is_online(), "sem peer depois da sala inexistente")

	print("RESULT fails=%d" % _fails)
	quit(_fails)
