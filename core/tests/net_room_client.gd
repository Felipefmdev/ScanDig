## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_room_client.gd [-- --force-relay]
## Par: core/tests/net_room_host.gd (suba o host antes). Entra pelo código, na Praia, no
## meio da expedição (#30). Sem o noray: "SKIP noray offline".
extends SceneTree
const CODE_FILE: String = "user://net_room_code.txt"
var summary: Dictionary = {}
var _fails: int = 0
func _w(s: float) -> void:
	await create_timer(s).timeout
func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()):
		if t >= timeout_s:
			return false
		await _w(0.25)
		t += 0.25
	return true
func _scene_name() -> String:
	return String(current_scene.name) if current_scene != null else "null"
func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("CLIENT FAIL ", msg)
func _finish() -> void:
	print("CLIENT RESULT fails=%d" % _fails)
	quit(_fails)
## O noray aceita TCP em address:port em até 2 s?
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
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("net_room_client")
	var net: NetworkManager = NetworkManager.instance
	var sm: SessionManager = SessionManager.instance
	if not await _noray_up(net.noray_address, net.noray_port):
		print("CLIENT SKIP noray offline (%s:%d)" % [net.noray_address, net.noray_port])
		_finish()
		return
	sm.expedition_ended.connect(func(s: Dictionary) -> void: summary = s)
	var has_code: bool = await _wait_until(func() -> bool: return FileAccess.file_exists(CODE_FILE), 20.0)
	_check(has_code, "sem código do host em 20 s")
	if not has_code:
		_finish()
		return
	# Digitado como o jogador faria: minúsculas e com hífen.
	var typed: String = RoomCode.format_for_display(FileAccess.get_file_as_string(CODE_FILE)).to_lower()
	var t0: int = Time.get_ticks_msec()
	var stages: Array[String] = []
	net.online_join_progress.connect(func(stage: String) -> void:
		stages.append(stage)
		print("CLIENT STAGE ", stage, " t=", Time.get_ticks_msec() - t0, "ms"))
	net.connection_error.connect(func(message: String) -> void: print("CLIENT ERROR_MSG ", message))
	var connected_ms: Array[int] = [-1]
	net.connection_succeeded.connect(func() -> void: connected_ms[0] = Time.get_ticks_msec() - t0)
	print("CLIENT code=", typed, " force_relay=", net.noray_force_relay)
	_check(net.join_code(typed) == OK, "join_code")
	var connected: bool = await _wait_until(func() -> bool: return connected_ms[0] >= 0, 20.0)
	print("CLIENT connected_ms=", connected_ms[0], " stages=", stages, " room=", net.get_room_code(), " online_room=", net.is_online_room())
	_check(connected, "não conectou em 20 s")
	var expected: Array[String] = ["registrando", "punch", "conectado"]
	if net.noray_force_relay:
		expected[1] = "relay"
	_check(stages == expected, "etapas %s" % str(stages))
	_check(net.is_online_room() and net.get_room_code() == RoomCode.normalize(typed), "is_online_room/get_room_code no cliente")
	var in_map: bool = await _wait_until(func() -> bool: return _scene_name() == "MapPraia" and sm.is_in_expedition(), 10.0)
	print("CLIENT scene_after_join=", _scene_name(), " in_exp=", sm.is_in_expedition())
	_check(in_map, "não entrou na Praia em 10 s")
	var back: bool = await _wait_until(func() -> bool: return _scene_name() == "LobbyBase" and not summary.is_empty(), 60.0)
	print("CLIENT scene_end=", _scene_name(), " day=", GameState.instance.current_day, " money=", GameState.instance.team_money, " museum=", GameState.instance.discovered_items)
	_check(back, "não voltou ao lobby com resumo")
	_check(GameState.instance.current_day == 2, "day=%d" % GameState.instance.current_day)
	_check(summary.get("entries", []).size() == 1, "summary_entries=%d" % summary.get("entries", []).size())
	_finish()
