## Teste headless (#81), cliente do par net_victory_* (ver net_victory_host.gd). Sem argumento:
## está na sala na vitória (recebe game_victory 1x, tela aberta com as contagens). Com "-- --late":
## entra depois (recebe o estado concluído, mas nem game_victory nem a tela).
extends SceneTree
const PORT: int = 7811
var _late: bool = false
var _victories: int = 0
var _completed_signals: int = 0
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
	_late = OS.get_cmdline_user_args().has("--late")
	var tag: String = "CLIENT late" if _late else "CLIENT"
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	SaveManager.instance.use_test_save_dir("net_victory_late" if _late else "net_victory_client")
	var gs: GameState = GameState.instance
	gs.game_victory.connect(func() -> void: _victories += 1)
	gs.game_completed_changed.connect(func(_c: bool) -> void: _completed_signals += 1)
	print(tag, " join=", NetworkManager.instance.join_game("127.0.0.1", PORT))
	var completed: bool = await _wait_until(func() -> bool: return gs.is_game_completed(), 20.0)
	_check(completed, "não recebeu game_completed em 20 s")
	if not _late:
		await _wait_until(func() -> bool: return _victories > 0, 3.0)
	# Folga para uma vitória repetida (não deve vir).
	await _w(2.0)
	var screen: VictoryScreen = VictoryScreen.instance
	print(tag, " completed=", gs.is_game_completed(), " victories=", _victories, " completed_signals=", _completed_signals,
		" open=", VictoryScreen.is_open(), " items=", screen.items_value.text, " secrets=", screen.secrets_value.text,
		" diary=", screen.creatures_value.text)
	_check(_completed_signals == 1, "game_completed_changed=%d" % _completed_signals)
	if _late:
		_check(_victories == 0, "atrasado recebeu game_victory=%d" % _victories)
		_check(not VictoryScreen.is_open(), "tela abriu no cliente atrasado")
	else:
		_check(_victories == 1, "game_victory=%d" % _victories)
		_check(VictoryScreen.is_open(), "tela não abriu")
		# O snapshot chegou antes da vitória: as contagens já são as novas.
		_check(screen.secrets_value.text == "1 / %d" % GameState.SECRETS.size(), "segredos=" + screen.secrets_value.text)
		_check(screen.creatures_value.text == "2 / %d" % GameState.CREATURES.size(), "diário=" + screen.creatures_value.text)
	print(tag, " RESULT fails=%d" % _fails)
	quit(_fails)
