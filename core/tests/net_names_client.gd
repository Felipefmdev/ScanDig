## Teste headless (papel A ou B): "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_names_client.gd -- A
## Par: core/tests/net_names_host.gd (porta 7794). O A sobe 2 s antes do B. Nomes com persist=false.
extends SceneTree
const PORT: int = 7794
const FINAL_NAMES: Array[String] = ["Ana Maria", "Anfitrião", "Bruno"]
var _role: String = ""
var _prefix: String = "CLIENT_?"
var _fails: int = 0
var _changes: int = 0
var _saw_initial_names: bool = false
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
		print(_prefix, " FAIL ", msg)
func _initialize() -> void:
	_run.call_deferred()
## Nomes de todos os peers, ordenados (independe dos ids sorteados).
func _sorted_names(net: NetworkManager) -> Array[String]:
	var names: Array[String] = []
	for peer_id: int in net.connected_players.keys():
		names.append(net.get_player_name(peer_id))
	names.sort()
	return names
func _on_players_changed(net: NetworkManager) -> void:
	_changes += 1
	if _sorted_names(net) == ["Ana", "Anfitrião", "Bruno"]:
		_saw_initial_names = true
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
	SaveManager.instance.use_test_save_dir("net_names_client")
	var net: NetworkManager = NetworkManager.instance
	net.players_changed.connect(func() -> void: _on_players_changed(net))
	# O B manda espaços sobrando: o host sanitiza para "Bruno".
	net.set_local_player_name("Ana" if _role == "A" else "  Bruno    ", false)
	var join_err: Error = net.join_game("127.0.0.1", PORT)
	print(_prefix, " join=", join_err, " local_name=", net.local_player_name)
	_check(join_err == OK, "join_game=%d" % join_err)

	if _role == "A":
		var initial: bool = await _wait_until(func() -> bool: return _saw_initial_names, 15.0)
		_check(initial, "nomes {Ana, Anfitrião, Bruno} não apareceram")
		net.set_local_player_name("Ana Maria", false)

	var converged: bool = await _wait_until(func() -> bool: return _sorted_names(net) == FINAL_NAMES, 15.0)
	print(_prefix, " names=", _sorted_names(net), " size=", net.connected_players.size(), " me=", net.get_player_name(get_multiplayer().get_unique_id()), " changes=", _changes)
	_check(converged, "nomes não convergiram para %s" % str(FINAL_NAMES))
	_check(net.connected_players.size() == 3, "size=%d" % net.connected_players.size())
	_check(_changes > 0, "players_changed não emitido")

	if _role == "B":
		await _w(1.0)
		net.disconnect_game()
		print(_prefix, " left size=", net.connected_players.size())
	else:
		var changes_before_leave: int = _changes
		var b_left: bool = await _wait_until(func() -> bool: return net.connected_players.size() == 2, 15.0)
		print(_prefix, " after_leave size=", net.connected_players.size(), " names=", _sorted_names(net), " new_changes=", _changes - changes_before_leave)
		_check(b_left, "não viu o B sair")
		_check(_changes > changes_before_leave, "players_changed não emitido na saída do B")
		net.disconnect_game()
	print(_prefix, " RESULT fails=%d" % _fails)
	quit(_fails)
