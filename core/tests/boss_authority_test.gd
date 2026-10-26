## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/boss_authority_test.gd
## Fase 4 (#5) e #45: chefe, missão e segredo só são aceitos do host. O host abre o próprio cliente
## (o mesmo script com "-- client") na porta 7798. Grava o save: faça backup.
extends SceneTree
const PORT: int = 7798
const BOSS_ID: String = "king_crab"

## Test-only transport barrier. Same reliable channel 0 as the forged core
## requests; no economy/gameplay operation is used as a synchronization marker.
class AuthorityProbe extends Node:
	var expected_peer: int = 0
	var stage: int = 0
	var armed: bool = false
	var allow_second: bool = false
	var received: Array[int] = []
	var failures: Array[String] = []

	@rpc("authority", "call_remote", "reliable", 0)
	func arm() -> void:
		if not multiplayer.is_server() and multiplayer.get_remote_sender_id() == 1:
			armed = true

	@rpc("any_peer", "call_remote", "reliable", 0)
	func checkpoint(value: int) -> void:
		var sender: int = multiplayer.get_remote_sender_id()
		if not multiplayer.is_server() or sender <= 1 or sender != expected_peer or not multiplayer.get_peers().has(sender):
			failures.append("probe sender invalido: %d (esperado %d)" % [sender, expected_peer])
			return
		if value != stage + 1 or value not in [1, 2] or (value == 2 and not allow_second):
			failures.append("probe fora de ordem: %d apos %d" % [value, stage])
			return
		stage = value
		received.append(value)


var _probe: AuthorityProbe = null
var _fails: int = 0
func _w(s: float) -> void:
	await create_timer(s).timeout
## Checa `cond` a cada 0,25 s; devolve true assim que vale, false ao estourar o tempo.
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
		print("FAIL ", msg)
func _initialize() -> void:
	_probe = AuthorityProbe.new()
	_probe.name = "BossAuthorityProbe"
	root.add_child(_probe) # Stable RPC path, independent of current_scene changes.
	if OS.get_cmdline_user_args().has("client"):
		_run_client.call_deferred()
	else:
		_run_host.call_deferred()


func _run_host() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("boss_authority_test")
	var gs: GameState = GameState.instance
	var net: NetworkManager = NetworkManager.instance
	_check(gs != null and net != null, "GameState e NetworkManager presentes")
	if gs == null or net == null:
		_finish()
		return
	var host_err: Error = net.host_game(PORT)
	_check(host_err == OK, "host_game=%d" % host_err)
	gs.load_snapshot({"team_money": 5000, "current_day": 1, "discovered_items": [], "upgrade_levels": {}, "unlocked_maps": [], "defeated_bosses": []})

	var pid: int = OS.create_process(OS.get_executable_path(),
		["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://core/tests/boss_authority_test.gd", "--", "client"])
	_check(pid > 0, "cliente não abriu: pid=%d" % pid)

	# Arm only after identifying the actual connected guest. The client waits
	# for this test-only handshake before sending attacks and stage 1.
	var registered: bool = await _wait_until(func() -> bool: return root.get_multiplayer().get_peers().size() == 1, 20.0)
	_check(registered, "guest ENet real nao registrou em 20 s")
	if registered:
		_probe.expected_peer = int(root.get_multiplayer().get_peers()[0])
		_probe.rpc_id(_probe.expected_peer, &"arm")
	# Reliable requests from the same guest/channel are ordered across node paths.
	var attacked: bool = await _wait_until(func() -> bool: return _probe.stage == 1, 20.0)
	_check(attacked, "probe stage1 apos ataques nao chegou em 20 s")
	_check(_probe.received == [1] and _probe.failures.is_empty(), "probe stage1 valida sender e ordem: %s / %s" % [str(_probe.received), str(_probe.failures)])
	_check(gs.defeated_bosses.is_empty(), "chefe do cliente foi aceito: %s" % str(gs.defeated_bosses))
	_check(not gs.is_boss_defeated(BOSS_ID), "king_crab não pode vir do cliente")
	_check(gs.completed_quests.is_empty() and gs.found_secrets.is_empty(), "missão/segredo do cliente aceitos: %s / %s" % [str(gs.completed_quests), str(gs.found_secrets)])

	# Chamada local do host (como o chefe faz no _process_dying): aceita e sincroniza.
	_probe.allow_second = true
	gs.request_report_boss_defeated(BOSS_ID)
	_check(gs.is_boss_defeated(BOSS_ID), "host direto não marcou king_crab: %s" % str(gs.defeated_bosses))
	gs.request_complete_quest("ze_anzol")
	_check(gs.is_quest_completed("ze_anzol"), "host direto não concluiu ze_anzol")

	# Stage 2 is emitted only after the real guest observes snapshot + quest signal.
	var acked: bool = await _wait_until(func() -> bool: return _probe.stage == 2, 10.0)
	_check(acked, "o cliente não recebeu king_crab em 10 s")
	_check(_probe.received == [1, 2] and _probe.failures.is_empty(), "probe stage2 valida guest e ordem: %s / %s" % [str(_probe.received), str(_probe.failures)])
	_check(gs.defeated_bosses == [BOSS_ID], "defeated_bosses final: %s" % str(gs.defeated_bosses))

	await _w(1.0)
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	gs.reset_state()
	net.disconnect_game()
	_finish()


func _finish() -> void:
	print("RESULT fails=%d" % _fails)
	quit(_fails)


func _run_client() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	var gs: GameState = GameState.instance
	var net: NetworkManager = NetworkManager.instance
	var connected: Array[bool] = [false]
	net.connection_succeeded.connect(func() -> void: connected[0] = true)
	net.join_game("127.0.0.1", PORT)
	var joined: bool = await _wait_until(func() -> bool: return connected[0], 10.0)
	if not joined:
		quit(1)
		return
	var armed: bool = await _wait_until(func() -> bool: return _probe.armed, 20.0)
	if not armed:
		print("FAIL probe arm nao chegou do host real em 20 s")
		net.disconnect_game()
		quit(1)
		return
	var quest_signals: Array[String] = []
	gs.quest_completed.connect(func(quest_id: String, reward: int) -> void: quest_signals.append("%s:%d" % [quest_id, reward]))
	# Os dois caminhos: rpc_id direto e o request_* (que no cliente também vira rpc_id(1)).
	gs.rpc_id(1, &"_host_report_boss_defeated", BOSS_ID)
	gs.request_report_boss_defeated("giant_mole")
	gs.rpc_id(1, &"_host_complete_quest", "ze_anzol")
	gs.request_report_secret("praia_polvo")
	# Campo Antigo (#45): missão da Lurdes, segredo e chefe extra também só do host.
	gs.request_complete_quest("lurdes_chaves")
	gs.request_report_secret("campo_espantalho")
	gs.request_report_boss_defeated("crow_king")
	_probe.rpc_id(1, &"checkpoint", 1)
	var synced: bool = await _wait_until(func() -> bool: return gs.is_boss_defeated(BOSS_ID) and quest_signals == ["ze_anzol:600"], 10.0)
	if synced:
		_probe.rpc_id(1, &"checkpoint", 2)
		await _w(1.0)
	net.disconnect_game()
	quit(0 if synced else 1)
