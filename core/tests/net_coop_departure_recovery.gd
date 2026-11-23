extends SceneTree
## Em dois terminais com perfis Godot isolados, execute na raiz do projeto:
## godot --headless --path . --script res://core/tests/net_coop_departure_recovery.gd -- host host 7864
## godot --headless --path . --script res://core/tests/net_coop_departure_recovery.gd -- client host 7864
## Troque o segundo argumento por "client" ou "timeout" em ambos para os outros cenários.

const BEACH: String = "res://world/map_praia.tscn"
const DAY: int = 3
const MONEY: int = 775
const PREVIOUS_SUMMARY: Dictionary = {"day": 2, "map_id": "campo"}

class FailingSession extends SessionManager:
	var fail_first_load: bool = false
	var force_first_timeout: bool = false
	var beach_attempts: int = 0
	var invalid_results_sent: bool = false
	var client_checked: bool = false

	func _perform_scene_change(scene_path: String) -> Error:
		if scene_path == BEACH:
			beach_attempts += 1
			if not multiplayer.is_server() and _departure_token > 1:
				invalid_results_sent = true
				_rpc_recover_coop_departure(_departure_token)
				_rpc_report_scene_ready.rpc_id(HOST_PEER_ID, "praia")
				_rpc_report_departure_result.rpc_id(HOST_PEER_ID, _departure_token - 1, "praia", false, false)
				_rpc_report_departure_result.rpc_id(HOST_PEER_ID, _departure_token, "campo", false, false)
				_rpc_report_departure_result.rpc_id(HOST_PEER_ID, _departure_token, "praia", true, false)
			if fail_first_load and beach_attempts == 1:
				print("INJECTED ERR_CANT_OPEN")
				return ERR_CANT_OPEN
		return super._perform_scene_change(scene_path)

	func _on_scene_loaded(scene_path: String) -> void:
		var time_out: bool = scene_path == BEACH and force_first_timeout and _departure_token == 1
		if time_out and not multiplayer.is_server():
			return
		if scene_path == BEACH and not multiplayer.is_server() and invalid_results_sent:
			var sequence: int = _scene_change_sequence
			await get_tree().create_timer(1.5).timeout
			if sequence != _scene_change_sequence:
				return
		super._on_scene_loaded(scene_path)
		if time_out:
			_departure_deadline = Time.get_ticks_msec()


	@rpc("any_peer", "call_remote", "reliable")
	func _rpc_fixture_checked() -> void:
		if multiplayer.is_server() and multiplayer.get_remote_sender_id() > HOST_PEER_ID:
			client_checked = true


var _fails: int = 0
var _started: int = 0
var _failed: int = 0
var _ended: int = 0
var _ending: int = 0
var _cleanup_loaded: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		print("FAIL ", message)


func _wait_for(condition: Callable, seconds: float = 7.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(condition.call()) and Time.get_ticks_msec() < deadline:
		await process_frame
	return bool(condition.call())


func _in_scene(path: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == path


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3 or args[0] not in ["host", "client"] or args[1] not in ["host", "client", "timeout"]:
		print("Uso: -- host|client host|client|timeout <porta>")
		quit(2)
		return
	var host: bool = args[0] == "host"
	var original: SessionManager = SessionManager.instance
	root.remove_child(original)
	original.free()
	var session: FailingSession = FailingSession.new()
	session.name = "CoreSession"
	session.fail_first_load = args[0] == args[1]
	session.force_first_timeout = args[1] == "timeout"
	root.add_child(session)
	SessionUI.instance._connect_session()
	SessionManager.launch_mode = SessionManager.LAUNCH_COOP
	session.expedition_started.connect(func(_id: String) -> void: _started += 1)
	session.expedition_start_failed.connect(func(_message: String) -> void:
		_failed += 1
		_check(_in_scene(SessionManager.LOBBY_SCENE), "a falha é sinalizada na Base já carregada"))
	session.expedition_ended.connect(func(_summary: Dictionary) -> void: _ended += 1)
	session.expedition_ending.connect(func(_id: String) -> void: _ending += 1)

	var save: SaveManager = SaveManager.instance
	session.scene_loaded.connect(func(path: String) -> void:
		if host and path == SessionManager.LOBBY_SCENE and session.is_starting_expedition():
			_check(not session.is_in_expedition(), "a Base carregada já limpa o mapa provisório")
			_check(save.start_new_game() == ERR_BUSY, "novo jogo bloqueado antes da conclusão da recuperação"))
	save.use_test_save_dir("coop-departure-239")
	change_scene_to_file(SessionManager.LOBBY_SCENE)
	await process_frame
	await process_frame
	var state: GameState = GameState.instance
	if host:
		state.load_snapshot({"current_day": DAY, "team_money": MONEY})
		save.last_map = "campo"
		_check(save.save_game() == OK, "grava apenas o save inicial isolado")
	session._last_summary = PREVIOUS_SUMMARY.duplicate(true)
	var save_hash: String = FileAccess.get_sha256(save.save_path) if host else ""
	var before: Dictionary = state.get_snapshot()

	var net: NetworkManager = NetworkManager.instance
	var port: int = int(args[2])
	var connection: Error = net.host_game(port) if host else net.join_game("127.0.0.1", port)
	if connection != OK:
		print("CONNECTION ERROR ", connection)
		quit(2)
		return
	var peer_id: int = 0
	if host:
		print("HOST LISTENING")
		if not await _wait_for(func() -> bool: return root.multiplayer.get_peers().size() == 1):
			print("MISSING CLIENT")
			quit(2)
			return
		peer_id = root.multiplayer.get_peers()[0]
		_check(session.request_start_expedition("praia", true) == OK, "primeira partida aceita")
		_check(session.request_start_expedition("praia", true) == ERR_BUSY, "recusa pedido concorrente")

	_check(await _wait_for(func() -> bool: return _failed > 0), "a falha de qualquer peer é recebida")
	_check(_in_scene(SessionManager.LOBBY_SCENE), "ambos voltam à Base")
	_check(not session.is_in_expedition() and session.get_current_map() == null, "não deixa expedição ativa")
	_check(not SessionManager.is_night() and not NightFx.instance.is_active() and session.get_ready_peers().is_empty(), "limpa noite e ready")
	_check(_failed == 1 and _started == 0 and _ending == 0 and _ended == 0, "emite só uma falha, sem iniciar ou encerrar dia")
	_check(session.get_last_summary() == PREVIOUS_SUMMARY, "preserva resumo anterior")
	_check(state.current_day == DAY and state.team_money == MONEY, "preserva dia e dinheiro")
	if host:
		_check(state.get_snapshot() == before, "preserva o progresso do host")
		_check(FileAccess.get_sha256(save.save_path) == save_hash and save.last_map == "campo", "preserva o save e último mapa")
		_check(session.request_start_expedition("praia", true) == OK, "permite tentar novamente no mesmo mapa")
		session._rpc_report_departure_result(session._departure_token, "praia", false, false)
		session.request_end_expedition()
		await create_timer(0.6).timeout
		_check(session.is_starting_expedition() and _started == 0, "aguarda a confirmação real do cliente")
		_check(SessionUI.instance.loading_screen.visible, "overlay continua visível enquanto aguarda o peer")
		_check(not SessionUI.instance.expedition_bar.visible and not SessionUI.instance.leave_button.visible,
			"barra e Sair ficam ocultos durante a partida provisória")
		_check(session.get_ready_peers().is_empty(), "ready antigo de mesma cena não publica jogadores durante a espera")
	_check(await _wait_for(func() -> bool: return _started == 1 and _in_scene(BEACH)), "segunda partida chega à Praia")
	_check(session.beach_attempts >= 1 and _failed == 1, "o retry carrega o mapa sem falha duplicada")
	if session.fail_first_load:
		_check(session.beach_attempts == 2, "o peer que falhou faz um segundo carregamento")
	if not host:
		_check(session.invalid_results_sent, "cliente enviou resultados com token, mapa e fase incorretos durante o retry")
	_check(SessionManager.is_night(), "mantém a opção de noite na segunda partida")
	session.scene_loaded.connect(func(path: String) -> void:
		if path == SessionManager.LOBBY_SCENE:
			_cleanup_loaded = true)
	if host:
		_check(session.get_ready_peers() == [1, peer_id], "só publica ready depois da partida efetiva")
		_check(FileAccess.get_sha256(save.save_path) == save_hash, "retry não grava")
		_check(_ended == 0 and _ending == 0 and state.current_day == DAY, "fim de expedição ignorado enquanto o retry carrega")
		# Espera o cliente terminar as asserções antes de fechar o transporte.
		_check(await _wait_for(func() -> bool: return session.client_checked), "cliente terminou de verificar o retry")
		net.disconnect_game()
	else:
		session._rpc_fixture_checked.rpc_id(SessionManager.HOST_PEER_ID)
	_check(await _wait_for(func() -> bool: return _cleanup_loaded and _in_scene(SessionManager.LOBBY_SCENE)), "fixture termina com a Base carregada")
	await process_frame
	print("RESULT fails=%d" % _fails)
	quit(1 if _fails else 0)
