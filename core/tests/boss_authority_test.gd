## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/boss_authority_test.gd
## Fase 4 (#5) e #45: chefe, missão e segredo só são aceitos do host. O host abre o próprio cliente
## (o mesmo script com "-- client") na porta 7798. Grava o save: faça backup.
extends SceneTree
const PORT: int = 7798
const BOSS_ID: String = "king_crab"
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

	# O cliente manda os chefes falsos e depois compra o detector (aceito de qualquer peer).
	# RPC confiável no mesmo nó chega em ordem: com o detector comprado, os chefes já passaram.
	var bought: bool = await _wait_until(func() -> bool: return gs.get_upgrade_level("detector") == 1, 20.0)
	_check(bought, "a compra do cliente não chegou em 20 s")
	_check(gs.defeated_bosses.is_empty(), "chefe do cliente foi aceito: %s" % str(gs.defeated_bosses))
	_check(not gs.is_boss_defeated(BOSS_ID), "king_crab não pode vir do cliente")
	_check(gs.completed_quests.is_empty() and gs.found_secrets.is_empty(), "missão/segredo do cliente aceitos: %s / %s" % [str(gs.completed_quests), str(gs.found_secrets)])

	# Chamada local do host (como o chefe faz no _process_dying): aceita e sincroniza.
	gs.request_report_boss_defeated(BOSS_ID)
	_check(gs.is_boss_defeated(BOSS_ID), "host direto não marcou king_crab: %s" % str(gs.defeated_bosses))
	gs.request_complete_quest("ze_anzol")
	_check(gs.is_quest_completed("ze_anzol"), "host direto não concluiu ze_anzol")

	# O cliente confirma que recebeu o snapshot e o quest_completed comprando o pinpointer.
	var acked: bool = await _wait_until(func() -> bool: return gs.get_upgrade_level("pinpointer") == 1, 10.0)
	_check(acked, "o cliente não recebeu king_crab em 10 s")
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
	await _w(1.0)
	# Os dois caminhos: rpc_id direto e o request_* (que no cliente também vira rpc_id(1)).
	gs.rpc_id(1, &"_host_report_boss_defeated", BOSS_ID)
	gs.request_report_boss_defeated("giant_mole")
	gs.rpc_id(1, &"_host_complete_quest", "ze_anzol")
	gs.request_report_secret("praia_polvo")
	# Campo Antigo (#45): missão da Lurdes, segredo e chefe extra também só do host.
	gs.request_complete_quest("lurdes_chaves")
	gs.request_report_secret("campo_espantalho")
	gs.request_report_boss_defeated("crow_king")
	gs.request_buy_upgrade("detector")
	var quest_signals: Array[String] = []
	gs.quest_completed.connect(func(quest_id: String, reward: int) -> void: quest_signals.append("%s:%d" % [quest_id, reward]))
	var synced: bool = await _wait_until(func() -> bool: return gs.is_boss_defeated(BOSS_ID) and quest_signals == ["ze_anzol:600"], 10.0)
	if synced:
		gs.request_buy_upgrade("pinpointer")
		await _w(1.0)
	net.disconnect_game()
	quit(0 if synced else 1)
