## Teste headless (#81), host do par net_victory_*: vitória ao vivo chega 1x a quem está na sala
## e não chega a quem entra depois. Ordem:
##   "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_victory_host.gd
##   (3 s depois) ... --script res://core/tests/net_victory_client.gd
##   (quando o host imprimir "HOST victory_sent") ... --script res://core/tests/net_victory_client.gd -- --late
extends SceneTree
const PORT: int = 7811
var _victories: int = 0
var _joins: int = 0
var _fails: int = 0
func _w(s: float) -> void:
	await create_timer(s).timeout
func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("HOST FAIL ", msg)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("net_victory_host")
	GameState.instance.reset_state()
	GameState.instance.game_victory.connect(func() -> void: _victories += 1)
	print("HOST host_game=", NetworkManager.instance.host_game(PORT))
	root.multiplayer.peer_connected.connect(func(_id: int) -> void: _joins += 1)
	var t: float = 0.0
	while NetworkManager.instance.connected_players.size() < 2 and t < 15.0:
		await _w(0.5); t += 0.5
	_check(NetworkManager.instance.connected_players.size() == 2, "cliente não entrou")
	await _w(1.0)
	var data: Dictionary = GameState.instance.get_snapshot()
	data["seen_creatures"] = ["crab", "bat"]
	data["found_secrets"] = [GameState.SECRETS[0]]
	GameState.instance.load_snapshot(data)
	await _w(0.5)
	GameState.instance._host_report_boss_defeated("the_sleeper")
	# Chefe já derrotado: não repete a vitória.
	GameState.instance._host_report_boss_defeated("the_sleeper")
	print("HOST victory_sent completed=", GameState.instance.is_game_completed(), " open=", VictoryScreen.is_open())
	_check(_victories == 1, "host game_victory=%d" % _victories)
	_check(VictoryScreen.is_open(), "tela não abriu no host")
	# O primeiro cliente pode sair antes: conta entradas, não jogadores na sala.
	t = 0.0
	while _joins < 2 and t < 25.0:
		await _w(0.5); t += 0.5
	print("HOST joins=", _joins)
	_check(_joins == 2, "cliente atrasado não entrou")
	await _w(5.0)
	_check(_victories == 1, "host game_victory final=%d" % _victories)
	print("HOST RESULT fails=%d" % _fails)
	quit(_fails)
