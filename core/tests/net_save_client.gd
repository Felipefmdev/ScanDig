## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_save_client.gd
## Par: core/tests/net_save_host.gd (suba o host antes), porta 7789. O cliente tem o
## próprio save (dia 2, R$ 450), entra, recebe o estado do host (dia 5, R$ 3200), não
## grava e, ao sair, volta ao próprio save. Save isolado em user://test_saves/net_save_client.
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
		print("CLIENT FAIL ", msg)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	var save: SaveManager = SaveManager.instance
	var gs: GameState = GameState.instance
	var net: NetworkManager = NetworkManager.instance
	save.use_test_save_dir("net_save_client")
	gs.reset_state()
	save.save_to_file({"version": 4, "team_money": 450, "current_day": 2, "discovered_items": ["lata_enferrujada"]})
	save.set_save_path(save.save_path)
	var original: String = FileAccess.get_file_as_string(save.save_path)
	_check(save.continue_game() == OK and gs.team_money == 450 and gs.current_day == 2, "cliente com o próprio save aplicado")

	_check(net.join_game("127.0.0.1", PORT) == OK, "join_game")
	var synced: bool = await _wait_until(func() -> bool: return gs.current_day == 5 and gs.team_money == 3200, 15.0)
	print("CLIENT in_session day=", gs.current_day, " money=", gs.team_money, " applied=", save.is_progress_applied())
	_check(synced, "recebeu dia 5 / R$ 3200 do host")
	_check(not save.is_progress_applied(), "em sessão o progresso local não está aplicado")
	_check(save.save_game() == ERR_UNAUTHORIZED, "cliente não grava")
	_check(save.continue_game() == ERR_UNAUTHORIZED and save.start_new_game() == ERR_UNAUTHORIZED, "cliente não troca o progresso em sessão")

	net.disconnect_game()
	var restored: bool = await _wait_until(func() -> bool: return gs.current_day == 2 and gs.team_money == 450, 5.0)
	print("CLIENT after_leave day=", gs.current_day, " money=", gs.team_money, " museum=", gs.discovered_items, " applied=", save.is_progress_applied())
	_check(restored and gs.discovered_items == ["lata_enferrujada"], "voltou ao próprio save")
	_check(save.is_progress_applied(), "progresso local aplicado de novo")
	_check(FileAccess.get_file_as_string(save.save_path) == original, "save do cliente intacto")
	print("CLIENT RESULT fails=%d" % _fails)
	quit(_fails)
