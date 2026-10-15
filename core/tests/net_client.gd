## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_client.gd
extends SceneTree
var summary: Dictionary = {}
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
## current_scene pode ser null durante a troca de cena.
func _scene_name() -> String:
	return String(current_scene.name) if current_scene != null else "null"
func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("CLIENT FAIL ", msg)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("net_client")
	SessionManager.instance.expedition_ended.connect(func(s: Dictionary) -> void: summary = s)
	print("CLIENT join=", NetworkManager.instance.join_game("127.0.0.1", 7790))
	var in_map: bool = await _wait_until(func() -> bool: return _scene_name() == "MapPraia" and SessionManager.instance.is_in_expedition(), 8.0)
	print("CLIENT scene_after_join=", _scene_name(), " in_exp=", SessionManager.instance.is_in_expedition())
	_check(in_map, "não entrou na Praia em 8 s")
	var back: bool = await _wait_until(func() -> bool: return _scene_name() == "LobbyBase" and not summary.is_empty(), 15.0)
	print("CLIENT scene_end=", _scene_name(), " day=", GameState.instance.current_day, " money=", GameState.instance.team_money, " museum=", GameState.instance.discovered_items)
	var entries: Array = summary.get("entries", [])
	print("CLIENT summary_entries=", entries)
	_check(back, "não voltou ao lobby com resumo em 15 s")
	_check(GameState.instance.current_day == 2, "day=%d" % GameState.instance.current_day)
	_check(entries.size() == 1, "summary_entries=%d" % entries.size())
	print("CLIENT RESULT fails=%d" % _fails)
	quit(_fails)
