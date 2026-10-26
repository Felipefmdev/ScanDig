## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_host_multi.gd
## Par: core/tests/net_client_multi.gd -- A e -- B (porta 7791). Grava o save: faça backup.
extends SceneTree
const PORT: int = 7791
var _fails: int = 0
var scene_ready_pairs: Array[String] = []
## Ids dos clientes em ordem de chegada (o ENet sorteia os ids).
var arrivals: Array[int] = []
## Saldos vistos depois da largada: o 7 da corrida é passageiro (o A doa logo depois).
var money_history: Array[int] = []
var _race_started: bool = false
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
		print("HOST FAIL ", msg)
func _finish() -> void:
	print("HOST RESULT fails=%d" % _fails)
	quit(_fails)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("net_host_multi")
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	var net: NetworkManager = NetworkManager.instance
	sm.peer_scene_ready.connect(func(peer_id: int, map_id: String) -> void: scene_ready_pairs.append("%d:%s" % [peer_id, map_id]))
	net.player_connected.connect(func(peer_id: int) -> void:
		# O host_game também emite player_connected(1).
		if peer_id != 1 and not arrivals.has(peer_id):
			arrivals.append(peer_id))
	var host_err: Error = net.host_game(PORT)
	print("HOST host_game=", host_err)
	_check(host_err == OK, "host_game=%d" % host_err)
	sm.request_start_expedition("praia")

	var all_in: bool = await _wait_until(func() -> bool: return net.connected_players.size() == 3, 20.0)
	print("HOST players=", net.connected_players.size(), " arrivals=", arrivals)
	_check(all_in and arrivals.size() >= 2, "os 2 clientes não entraram em 20 s")
	if arrivals.size() < 2:
		_finish()
		return
	var id_a: int = arrivals[0]
	var id_b: int = arrivals[1]

	var both_ready: bool = await _wait_until(func() -> bool: return sm.is_peer_scene_ready(id_a) and sm.is_peer_scene_ready(id_b), 10.0)
	var clients: Array[int] = [id_a, id_b]
	clients.sort()
	var expected_ready: Array[int] = [1]
	expected_ready.append_array(clients)
	var ready_ok: bool = sm.get_ready_peers() == expected_ready
	print("HOST ready=", sm.get_ready_peers(), " ok=", ready_ok, " id_a=", id_a, " id_b=", id_b, " signals=", scene_ready_pairs)
	_check(both_ready and ready_ok, "ready esperado %s" % str(expected_ready))

	var counter: Node = current_scene.get_node("Banca/Upgrades")
	var both_in_range: bool = await _wait_until(func() -> bool:
		return bool(counter.call("host_can_purchase", id_a)) and bool(counter.call("host_can_purchase", id_b)), 10.0)
	_check(both_in_range, "dois clientes reais prontos, próximos e com LOS na banca")
	# Largada: saldo exato para UM pinpointer + 7. Os dois clientes compram ao ver isso.
	var cost: int = gs.get_next_upgrade_cost("pinpointer")
	_check(cost > 0, "custo do pinpointer=%d" % cost)
	gs.money_changed.connect(func(amount: int) -> void:
		if _race_started:
			money_history.append(amount))
	_race_started = true
	gs.load_snapshot({"team_money": cost + 7, "current_day": 1, "discovered_items": [], "upgrade_levels": {}})
	await _wait_until(func() -> bool: return gs.get_upgrade_level("pinpointer") == 1, 10.0)
	await _w(2.0)
	# Depois da compra vencedora o saldo tem que passar por 7 e nunca ficar negativo.
	var race_money: int = 7 if money_history.has(7) else gs.team_money
	var min_money: int = money_history.min() if not money_history.is_empty() else gs.team_money
	print("HOST race pinpointer=", gs.get_upgrade_level("pinpointer"), " money=", race_money, " now=", gs.team_money, " history=", money_history)
	_check(gs.get_upgrade_level("pinpointer") == 1, "pinpointer=%d" % gs.get_upgrade_level("pinpointer"))
	_check(money_history.has(7), "saldo nunca foi 7 depois da corrida: %s" % str(money_history))
	_check(min_money >= 0, "saldo negativo na corrida: %d" % min_money)

	var b_left: bool = await _wait_until(func() -> bool: return net.connected_players.size() == 2, 10.0)
	var after_leave_ok: bool = sm.get_ready_peers() == [1, id_a] and not sm.is_peer_scene_ready(id_b)
	print("HOST after_leave players=", net.connected_players.size(), " ready=", sm.get_ready_peers(), " ok=", after_leave_ok)
	_check(b_left, "B não saiu em 10 s")
	_check(after_leave_ok, "ready após saída do B")

	var found: bool = await _wait_until(func() -> bool: return gs.discovered_items.has("alianca_ouro"), 8.0)
	_check(found, "achado do A não chegou em 8 s")

	sm.request_end_expedition()
	await _w(4.0)
	print("HOST after_end ready=", sm.get_ready_peers(), " day=", gs.current_day)
	_check(sm.get_ready_peers().is_empty(), "ready após fim=%s" % str(sm.get_ready_peers()))
	_check(gs.current_day == 2, "day após fim=%d" % gs.current_day)

	var b_back: bool = await _wait_until(func() -> bool: return net.connected_players.size() == 3, 20.0)
	_check(b_back, "B não voltou em 20 s")
	await _w(3.0)
	print("HOST final day=", gs.current_day, " money=", gs.team_money, " pinpointer=", gs.get_upgrade_level("pinpointer"), " players=", net.connected_players.size())
	_finish()
