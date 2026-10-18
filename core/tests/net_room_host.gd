## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_room_host.gd [-- --noray=127.0.0.1:8890 hold=4]
## Par: core/tests/net_room_client.gd (sobe 4 s depois). Precisa do noray local (#30);
## sem ele: "SKIP noray offline". Porta 7799. Grava o save: faça backup.
extends SceneTree
const PORT: int = 7799
const CODE_FILE: String = "user://test_saves/net_room_code.txt"
var _fails: int = 0
var scene_ready_pairs: Array[String] = []
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
func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("HOST FAIL ", msg)
func _finish() -> void:
	print("HOST RESULT fails=%d" % _fails)
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
	var hold: float = 4.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("hold="):
			hold = arg.trim_prefix("hold=").to_float()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CODE_FILE.get_base_dir()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CODE_FILE))
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("net_room_host")
	var net: NetworkManager = NetworkManager.instance
	var sm: SessionManager = SessionManager.instance
	if not await _noray_up(net.noray_address, net.noray_port):
		print("HOST SKIP noray offline (%s:%d)" % [net.noray_address, net.noray_port])
		_finish()
		return
	sm.peer_scene_ready.connect(func(peer_id: int, map_id: String) -> void: scene_ready_pairs.append("%d:%s" % [peer_id, map_id]))
	net.online_join_progress.connect(func(stage: String) -> void: print("HOST STAGE ", stage))
	net.connection_error.connect(func(message: String) -> void: print("HOST ERROR_MSG ", message))
	var codes: Array[String] = []
	net.room_code_ready.connect(func(code: String) -> void: codes.append(code))
	var t0: int = Time.get_ticks_msec()
	_check(net.host_online(PORT) == OK, "host_online")
	var got_code: bool = await _wait_until(func() -> bool: return not codes.is_empty(), 10.0)
	print("HOST room_code=", codes, " ms=", Time.get_ticks_msec() - t0, " display=", RoomCode.format_for_display(codes[0]) if got_code else "")
	_check(got_code and RoomCode.is_valid(codes[0]), "room_code_ready com código válido: %s" % str(codes))
	if not got_code:
		_finish()
		return
	_check(net.is_online_room() and net.get_room_code() == codes[0], "is_online_room/get_room_code")
	_check(net.enet_peer != null and net.enet_peer.host.get_local_port() == PORT, "ENet na porta %d" % PORT)
	var file: FileAccess = FileAccess.open(CODE_FILE, FileAccess.WRITE)
	file.store_string(codes[0])
	file.close()

	sm.request_start_expedition("praia")
	await _w(1.0)
	print("HOST scene=", current_scene.name)
	var joined: bool = await _wait_until(func() -> bool: return net.connected_players.size() >= 2, 40.0)
	_check(joined, "cliente não entrou em 40 s")
	var client_id: int = 0
	for peer_id: int in net.connected_players.keys():
		if peer_id != 1:
			client_id = peer_id
	var ready_ok: bool = await _wait_until(func() -> bool: return sm.is_peer_scene_ready(client_id), 10.0)
	print("HOST scene_ready=", sm.get_ready_peers(), " client_id=", client_id, " signals=", scene_ready_pairs)
	_check(ready_ok, "peer_scene_ready do cliente")
	await _w(hold)
	GameState.instance.request_report_discovery("alianca_ouro", 400)
	await _w(1.0)
	sm.request_end_expedition()
	await _w(4.0)
	print("HOST day=", GameState.instance.current_day, " money=", GameState.instance.team_money)
	net.disconnect_game()
	_check(not net.is_online_room() and net.get_room_code().is_empty(), "disconnect_game fecha a sala")
	_finish()
