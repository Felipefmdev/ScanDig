## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_errors_test.gd
## Opcional, SÓ com autorização do dono da rede: acrescente "-- upnp" para testar o UPnP real.
## ATENÇÃO: "-- upnp" abre de verdade a porta 7797 (UDP) no roteador e fecha logo depois.
## Sem o argumento, a parte real imprime "UPNP skipped"; a thread é testada com um UPnP falso (sem rede).
extends SceneTree

const BUSY_PORT: int = 7796
const TIMEOUT_PORT: int = 7795
const FAKE_UPNP_PORT: int = 7793
const REAL_UPNP_PORT: int = 7797
const SILENT_IP: String = "10.255.255.1"

var _fails: int = 0
var _errors: Array[String] = []
var _failed_count: int = 0
var _upnp_results: Array[Dictionary] = []


## UPnP falso: mesma API usada pelo NetworkManager (discover, get_gateway, ...), sem rede.
class FakeGateway extends RefCounted:
	var valid: bool = true
	func is_valid_gateway() -> bool:
		return valid


class FakeUpnp extends RefCounted:
	var delay_msec: int = 0
	var gateway_valid: bool = true
	var map_result: int = UPNP.UPNP_RESULT_SUCCESS
	## Compartilhado com o teste: registra o que a thread chamou.
	var call_log: Dictionary = {}
	func discover() -> int:
		OS.delay_msec(delay_msec)
		return UPNP.UPNP_RESULT_SUCCESS
	func get_gateway() -> Object:
		var gateway: FakeGateway = FakeGateway.new()
		gateway.valid = gateway_valid
		return gateway
	func query_external_address() -> String:
		return "203.0.113.7"
	func add_port_mapping(port: int, _port_internal: int, _desc: String, proto: String) -> int:
		call_log["mapped"] = "%d/%s" % [port, proto]
		return map_result
	func delete_port_mapping(port: int, proto: String) -> int:
		call_log["deleted"] = "%d/%s" % [port, proto]
		return UPNP.UPNP_RESULT_SUCCESS


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()):
		if t >= timeout_s:
			return false
		await create_timer(0.1).timeout
		t += 0.1
	return true

func _initialize() -> void:
	_run.call_deferred()

func _is_offline() -> bool:
	return get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer

func _last_error() -> String:
	return _errors[-1] if not _errors.is_empty() else ""

## Roda o UPnP falso e devolve {elapsed_msec, result, log}.
func _fake_upnp_run(net: NetworkManager, fake_config: Dictionary) -> Dictionary:
	var call_log: Dictionary = {}
	net._upnp_factory = func() -> Object:
		var fake: FakeUpnp = FakeUpnp.new()
		fake.delay_msec = int(fake_config.get("delay_msec", 300))
		fake.gateway_valid = bool(fake_config.get("gateway_valid", true))
		fake.map_result = int(fake_config.get("map_result", UPNP.UPNP_RESULT_SUCCESS))
		fake.call_log = call_log
		return fake
	_upnp_results.clear()
	var started: int = Time.get_ticks_msec()
	net.start_upnp(FAKE_UPNP_PORT)
	var elapsed: int = Time.get_ticks_msec() - started
	await _wait_until(func() -> bool: return not _upnp_results.is_empty(), 5.0)
	return {"elapsed_msec": elapsed, "result": _upnp_results[0] if not _upnp_results.is_empty() else {}, "log": call_log}

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("net_errors_test")
	var net: NetworkManager = NetworkManager.instance
	_check(net != null, "NetworkManager presente")
	net.connection_error.connect(func(message: String) -> void: _errors.append(message))
	net.connection_failed.connect(func() -> void: _failed_count += 1)
	net.upnp_finished.connect(func(success: bool, ip: String, message: String) -> void:
		_upnp_results.append({"success": success, "ip": ip, "message": message}))

	# --- sanitize_player_name
	_check(NetworkManager.sanitize_player_name("  Ana  ") == "Ana", "sanitize strip")
	var long_name: String = "abcdefghijklmnopqrstuvwxyz1234"
	_check(NetworkManager.sanitize_player_name(long_name) == long_name.left(16), "sanitize corta em 16: %s" % NetworkManager.sanitize_player_name(long_name))
	_check(NetworkManager.sanitize_player_name("A\t\tB\nC") == "ABC", "sanitize remove controle: %s" % NetworkManager.sanitize_player_name("A\t\tB\nC"))
	_check(NetworkManager.sanitize_player_name("") == "", "sanitize vazio")

	# --- start_upnp offline: não emite nem cria thread
	net.start_upnp(FAKE_UPNP_PORT)
	await _wait(10)
	_check(_upnp_results.is_empty(), "start_upnp offline não emite")

	# --- IP inválido
	_errors.clear()
	var invalid: Error = net.join_game("abc")
	_check(invalid == ERR_INVALID_PARAMETER, "join abc = ERR_INVALID_PARAMETER: %d" % invalid)
	_check(_last_error() == "Endereço inválido: abc", "mensagem de IP inválido: %s" % _last_error())
	_check(_is_offline(), "IP inválido não cria peer")

	# --- Porta ocupada
	var holder: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var hold_err: Error = holder.create_server(BUSY_PORT)
	_check(hold_err == OK, "teste segura a porta %d" % BUSY_PORT)
	_errors.clear()
	var busy: Error = net.host_game(BUSY_PORT)
	_check(busy != OK, "host_game na porta ocupada falha: %d" % busy)
	_check(_last_error().contains("a porta %d já está em uso" % BUSY_PORT), "mensagem de porta em uso: %s" % _last_error())
	_check(_is_offline(), "porta ocupada não deixa peer")
	holder.close()

	# --- Timeout do join (IP que não responde) + start_upnp como cliente
	_errors.clear()
	_failed_count = 0
	var join_err: Error = net.join_game(SILENT_IP, TIMEOUT_PORT)
	_check(join_err == OK, "join no IP mudo inicia: %d" % join_err)
	_upnp_results.clear()
	net.start_upnp(FAKE_UPNP_PORT)
	await _wait(10)
	_check(_upnp_results.is_empty(), "start_upnp como cliente não emite")
	var started: int = Time.get_ticks_msec()
	var timed_out: bool = await _wait_until(func() -> bool: return _failed_count > 0, 12.0)
	var waited: float = (Time.get_ticks_msec() - started) / 1000.0
	_check(timed_out, "connection_failed em até 12 s (%.1f s)" % waited)
	_check(_last_error().contains("não respondeu em 10 s"), "mensagem de timeout: %s" % _last_error())
	_check(_failed_count == 1, "connection_failed uma vez: %d" % _failed_count)
	_check(_is_offline(), "timeout volta a offline")

	# --- Thread do UPnP com UPnP falso (sem rede)
	var host_err: Error = net.host_game(FAKE_UPNP_PORT)
	_check(host_err == OK, "host para UPnP falso: %d" % host_err)
	var run: Dictionary = await _fake_upnp_run(net, {"delay_msec": 500})
	var result: Dictionary = run["result"]
	_check(int(run["elapsed_msec"]) < 200, "start_upnp não bloqueia com discover de 500 ms: %d ms" % int(run["elapsed_msec"]))
	_check(result.get("success", false) == true and result.get("ip", "") == "203.0.113.7", "falso: sucesso com IP: %s" % str(result))
	_check(result.get("message", "") == "Porta %d aberta no roteador. Passe o IP 203.0.113.7 aos amigos." % FAKE_UPNP_PORT, "falso: mensagem de sucesso")
	_check(net.public_ip == "203.0.113.7", "public_ip preenchido: %s" % net.public_ip)
	var leave_start: int = Time.get_ticks_msec()
	net.disconnect_game()
	var leave_msec: int = Time.get_ticks_msec() - leave_start
	var call_log: Dictionary = run["log"]
	_check(leave_msec < 3000, "disconnect_game com UPnP < 3 s: %d ms" % leave_msec)
	_check(call_log.get("mapped", "") == "%d/UDP" % FAKE_UPNP_PORT and call_log.get("deleted", "") == "%d/UDP" % FAKE_UPNP_PORT, "falso: mapeia e remove ao sair: %s" % str(call_log))
	_check(net.public_ip == "", "public_ip limpo ao sair")

	net.host_game(FAKE_UPNP_PORT)
	run = await _fake_upnp_run(net, {"gateway_valid": false})
	result = run["result"]
	_check(result.get("success", true) == false and result.get("message", "") == "UPnP indisponível: abra a porta %d (UDP) no roteador ou jogue na mesma rede." % FAKE_UPNP_PORT, "falso: sem gateway: %s" % str(result))
	net.disconnect_game()

	net.host_game(FAKE_UPNP_PORT)
	run = await _fake_upnp_run(net, {"map_result": UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING})
	result = run["result"]
	_check(result.get("success", true) == false and result.get("message", "") == "O roteador recusou abrir a porta %d (UPnP). Abra manualmente (UDP)." % FAKE_UPNP_PORT, "falso: roteador recusa: %s" % str(result))
	_check(not (run["log"] as Dictionary).has("deleted"), "falso: recusa não tenta remover")
	net.disconnect_game()

	# Saída no meio da descoberta: espera a thread (< 3 s), remove o mapeamento e não emite.
	net.host_game(FAKE_UPNP_PORT)
	var cancel_log: Dictionary = {}
	net._upnp_factory = func() -> Object:
		var fake: FakeUpnp = FakeUpnp.new()
		fake.delay_msec = 1500
		fake.call_log = cancel_log
		return fake
	_upnp_results.clear()
	net.start_upnp(FAKE_UPNP_PORT)
	await _wait(5)
	leave_start = Time.get_ticks_msec()
	net.disconnect_game()
	leave_msec = Time.get_ticks_msec() - leave_start
	await _wait(10)
	_check(leave_msec < 3000, "saída durante a descoberta < 3 s: %d ms" % leave_msec)
	_check(_upnp_results.is_empty(), "saída durante a descoberta não emite upnp_finished")
	_check(cancel_log.get("deleted", "") == "%d/UDP" % FAKE_UPNP_PORT, "saída durante a descoberta remove o mapeamento: %s" % str(cancel_log))
	net._upnp_factory = Callable()

	# --- UPnP real (opcional; abre a porta no roteador de verdade)
	if OS.get_cmdline_user_args().has("upnp"):
		net.host_game(REAL_UPNP_PORT)
		_upnp_results.clear()
		var real_start: int = Time.get_ticks_msec()
		net.start_upnp(REAL_UPNP_PORT)
		var real_elapsed: int = Time.get_ticks_msec() - real_start
		_check(real_elapsed < 200, "start_upnp real não bloqueia: %d ms" % real_elapsed)
		var got: bool = await _wait_until(func() -> bool: return not _upnp_results.is_empty(), 20.0)
		_check(got, "upnp_finished real em até 20 s")
		var real: Dictionary = _upnp_results[0] if got else {}
		_check(not str(real.get("message", "")).is_empty(), "upnp_finished real com mensagem")
		print("UPNP success=%s ip=%s msg=%s" % [str(real.get("success", false)), str(real.get("ip", "")), str(real.get("message", ""))])
		var real_leave: int = Time.get_ticks_msec()
		net.disconnect_game()
		_check(Time.get_ticks_msec() - real_leave < 3000, "disconnect_game real < 3 s: %d ms" % (Time.get_ticks_msec() - real_leave))
	else:
		print("UPNP skipped")

	print("RESULT fails=%d" % _fails)
	quit(_fails)
