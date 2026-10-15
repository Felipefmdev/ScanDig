## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_save_host.gd
## Par: core/tests/net_save_client.gd (sobe 3 s depois), porta 7789. Host com save
## (dia 5, R$ 3200) abre com host_game sem escolher nada: o save é aplicado antes do
## primeiro snapshot. Save isolado em user://test_saves/net_save_host.
extends SceneTree
const PORT: int = 7789
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
func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("HOST FAIL ", msg)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	var save: SaveManager = SaveManager.instance
	var gs: GameState = GameState.instance
	var net: NetworkManager = NetworkManager.instance
	save.use_test_save_dir("net_save_host")
	gs.reset_state()
	save.save_to_file({"version": 4, "team_money": 3200, "current_day": 5, "discovered_items": ["moeda_antiga"]})
	save.set_save_path(save.save_path)
	var original: String = FileAccess.get_file_as_string(save.save_path)
	_check(not save.is_progress_applied() and gs.team_money == 100, "save ainda não aplicado antes de hospedar")

	_check(net.host_game(PORT) == OK, "host_game")
	print("HOST after_host_game day=", gs.current_day, " money=", gs.team_money, " applied=", save.is_progress_applied())
	_check(save.is_progress_applied() and gs.current_day == 5 and gs.team_money == 3200, "host_game aplicou o save")

	var joined: bool = await _wait_until(func() -> bool: return net.connected_players.size() >= 2, 20.0)
	_check(joined, "cliente não entrou em 20 s")
	var left: bool = await _wait_until(func() -> bool: return net.connected_players.size() == 1, 30.0)
	_check(left, "cliente não saiu em 30 s")
	print("HOST players=", net.connected_players.size(), " day=", gs.current_day, " money=", gs.team_money)
	_check(gs.current_day == 5 and gs.team_money == 3200, "host mantém o próprio estado")
	_check(FileAccess.get_file_as_string(save.save_path) == original, "save do host intacto")
	net.disconnect_game()
	print("HOST RESULT fails=%d" % _fails)
	quit(_fails)
