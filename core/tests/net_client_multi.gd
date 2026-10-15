## Teste headless (papel A ou B): "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_client_multi.gd -- A
## Par: core/tests/net_host_multi.gd (porta 7791). O A sobe 2 s antes do B.
extends SceneTree
const PORT: int = 7791
var _role: String = ""
var _prefix: String = "CLIENT_?"
var _fails: int = 0
var summary: Dictionary = {}
var _buy_result: Dictionary = {}
## Travas ligadas ao state_synced: estados passageiros (o A doa logo depois) não escapam do polling.
var _bought: bool = false
var _saw_converged: bool = false
var _host_gone: bool = false
var _host_lost: bool = false
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
## current_scene pode ser null durante a troca de cena.
func _scene_name() -> String:
	return String(current_scene.name) if current_scene != null else "null"
func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print(_prefix, " FAIL ", msg)
func _finish() -> void:
	print(_prefix, " RESULT fails=%d" % _fails)
	# Fica conectado até o host encerrar: ele conta os 3 peers no fim.
	await _wait_until(func() -> bool: return _host_gone, 30.0)
	quit(_fails)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_role = args[0] if args.size() > 0 else ""
	if _role != "A" and _role != "B":
		print("CLIENT FAIL papel ausente ou inválido (use -- A ou -- B): ", args)
		quit(1)
		return
	_prefix = "CLIENT_" + _role
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("net_client_multi")
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	sm.expedition_ended.connect(func(s: Dictionary) -> void: summary = s)
	gs.purchase_result.connect(func(upgrade_id: String, success: bool, message: String) -> void:
		if upgrade_id == "pinpointer" and _buy_result.is_empty():
			_buy_result = {"success": success, "message": message})
	gs.state_synced.connect(func() -> void: _on_state_synced(gs))
	NetworkManager.instance.server_disconnected.connect(func() -> void: _host_gone = true)
	sm.host_lost.connect(func() -> void: _host_lost = true)

	var join_err: Error = NetworkManager.instance.join_game("127.0.0.1", PORT)
	print(_prefix, " join=", join_err)
	_check(join_err == OK, "join_game=%d" % join_err)
	var in_map: bool = await _wait_until(func() -> bool: return _scene_name() == "MapPraia" and sm.is_in_expedition(), 10.0)
	print(_prefix, " scene_after_join=", _scene_name(), " in_exp=", sm.is_in_expedition())
	_check(in_map, "não entrou na Praia em 10 s")

	# Largada: _on_state_synced compra no mesmo frame em que o snapshot custo + 7 chega.
	var go: bool = await _wait_until(func() -> bool: return _bought, 15.0)
	_check(go, "sinal de largada não chegou em 15 s (money=%d)" % gs.team_money)
	var answered: bool = await _wait_until(func() -> bool: return not _buy_result.is_empty(), 8.0)
	_check(answered, "purchase_result não chegou em 8 s")
	print(_prefix, " buy_success=", _buy_result.get("success", false), " msg=", _buy_result.get("message", "<sem resposta>"))
	var converged: bool = await _wait_until(func() -> bool: return _saw_converged, 5.0)
	print(_prefix, " after_race pinpointer=", gs.get_upgrade_level("pinpointer"), " money=", gs.team_money)
	_check(converged, "não convergiu para pinpointer=1 money=7")

	if _role == "A":
		await _run_a(gs, sm)
	else:
		await _run_b(gs, sm)
	await _finish()
func _on_state_synced(gs: GameState) -> void:
	var level: int = gs.get_upgrade_level("pinpointer")
	if not _bought and level == 0 and gs.team_money == gs.get_next_upgrade_cost("pinpointer") + 7:
		_bought = true
		gs.request_buy_upgrade("pinpointer")
	if level == 1 and gs.team_money == 7:
		_saw_converged = true
func _run_a(gs: GameState, sm: SessionManager) -> void:
	gs.request_report_discovery("alianca_ouro", 1)
	var back: bool = await _wait_until(func() -> bool: return _scene_name() == "LobbyBase" and not summary.is_empty(), 25.0)
	_check(back, "não voltou ao lobby com resumo em 25 s")
	var entries: Array = summary.get("entries", [])
	_check(gs.current_day == 2, "day=%d" % gs.current_day)
	_check(summary.get("map_id", "") == "praia", "summary map_id=%s" % str(summary.get("map_id", "")))
	_check(entries.size() == 1, "summary_entries=%d" % entries.size())
	_check(gs.team_money > 7, "doação não rendeu: money=%d" % gs.team_money)
	print(_prefix, " final day=", gs.current_day, " money=", gs.team_money, " pinpointer=", gs.get_upgrade_level("pinpointer"), " entries=", entries)
func _run_b(gs: GameState, sm: SessionManager) -> void:
	await _w(1.0)
	NetworkManager.instance.disconnect_game()
	await _wait_until(func() -> bool: return _scene_name() == "LobbyBase" and not sm.is_in_expedition(), 3.0)
	print(_prefix, " after_leave scene=", _scene_name(), " in_exp=", sm.is_in_expedition(), " host_lost=", _host_lost)
	_check(_scene_name() == "LobbyBase" and not sm.is_in_expedition(), "saída voluntária não voltou ao lobby: scene=%s in_exp=%s" % [_scene_name(), sm.is_in_expedition()])
	_check(not _host_lost, "host_lost emitido numa saída voluntária")
	await _w(8.0)
	_host_gone = false
	var join_err: Error = NetworkManager.instance.join_game("127.0.0.1", PORT)
	print(_prefix, " rejoin_join=", join_err)
	_check(join_err == OK, "rejoin join_game=%d" % join_err)
	var in_lobby: bool = await _wait_until(func() -> bool: return _scene_name() == "LobbyBase" and not sm.is_in_expedition() and gs.current_day == 2, 10.0)
	_check(in_lobby, "rejoin não chegou ao lobby com day=2 em 10 s")
	print(_prefix, " rejoin scene=", _scene_name(), " day=", gs.current_day, " money=", gs.team_money, " pinpointer=", gs.get_upgrade_level("pinpointer"))
