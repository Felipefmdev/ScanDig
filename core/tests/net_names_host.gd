## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_names_host.gd
## Par: core/tests/net_names_client.gd -- A e -- B (porta 7794). Sem UPnP; nomes com persist=false.
extends SceneTree
const PORT: int = 7794
var _fails: int = 0
var _changes: int = 0
## Ids dos clientes em ordem de chegada (o ENet sorteia os ids).
var arrivals: Array[int] = []
## Trava: o estado {Anfitrião, Ana, Bruno} é passageiro (o A troca de nome ao vê-lo).
var _saw_initial_names: bool = false
## Trava: o estado só com host + A também é passageiro (o A sai logo depois de vê-lo).
var _saw_b_leave: bool = false
var _changes_at_b_leave: int = 0
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
func _names(net: NetworkManager) -> Dictionary:
	var names: Dictionary = {}
	for peer_id: int in net.connected_players.keys():
		names[peer_id] = net.get_player_name(peer_id)
	return names
func _on_players_changed(net: NetworkManager) -> void:
	_changes += 1
	if arrivals.size() == 2 and _names(net) == {1: "Anfitrião", arrivals[0]: "Ana", arrivals[1]: "Bruno"}:
		_saw_initial_names = true
	var only_host_and_a: bool = (net.connected_players.size() == 2 and arrivals.size() == 2
			and net.connected_players.has(arrivals[0]) and not net.connected_players.has(arrivals[1]))
	if only_host_and_a and not _saw_b_leave:
		_saw_b_leave = true
		_changes_at_b_leave = _changes
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	var net: NetworkManager = NetworkManager.instance
	net.player_connected.connect(func(peer_id: int) -> void:
		if peer_id != 1 and not arrivals.has(peer_id):
			arrivals.append(peer_id))
	net.players_changed.connect(func() -> void: _on_players_changed(net))
	net.set_local_player_name("Anfitrião", false)
	var host_err: Error = net.host_game(PORT)
	print("HOST host_game=", host_err)
	_check(host_err == OK, "host_game=%d" % host_err)

	var all_in: bool = await _wait_until(func() -> bool: return net.connected_players.size() == 3, 20.0)
	_check(all_in and arrivals.size() == 2, "os 2 clientes não entraram em 20 s")
	if arrivals.size() < 2:
		_finish()
		return
	var id_a: int = arrivals[0]
	var id_b: int = arrivals[1]
	var initial: bool = await _wait_until(func() -> bool: return _saw_initial_names, 10.0)
	print("HOST initial_names ok=", initial, " id_a=", id_a, " id_b=", id_b)
	_check(initial, "nomes {Anfitrião, Ana, Bruno} não apareceram")

	var renamed: bool = await _wait_until(func() -> bool: return net.get_player_name(id_a) == "Ana Maria", 10.0)
	print("HOST names=", _names(net), " size=", net.connected_players.size(), " changes=", _changes)
	_check(renamed, "A não virou Ana Maria")
	_check(net.get_player_name(1) == "Anfitrião" and net.get_player_name(id_b) == "Bruno", "nomes do host e do B")
	_check(_changes > 0, "players_changed não emitido")

	var changes_before_leave: int = _changes
	var b_left: bool = await _wait_until(func() -> bool: return _saw_b_leave, 15.0)
	print("HOST after_leave size=2 ok=", b_left, " new_changes=", _changes_at_b_leave - changes_before_leave)
	_check(b_left, "não viu size 2 (host + A) depois da saída do B em 15 s")
	_check(_changes_at_b_leave > changes_before_leave, "players_changed não emitido na saída do B")
	_check(not net.connected_players.has(id_b), "B ainda na lista")

	# Espera o A terminar as checagens dele e sair.
	var a_left: bool = await _wait_until(func() -> bool: return net.connected_players.size() == 1, 15.0)
	_check(a_left, "A não saiu em 15 s")
	net.disconnect_game()
	_finish()
