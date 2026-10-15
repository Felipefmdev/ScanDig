## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/leave_session_test.gd
## Host sozinho na porta 7792. Grava o save: faça backup.
extends SceneTree

const PORT: int = 7792

var _fails: int = 0
var _left: Array[bool] = []
var _host_lost_count: int = 0
var _ready_pairs: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()):
		if t >= timeout_s:
			return false
		await create_timer(0.1).timeout
		t += 0.1
	return true

## current_scene pode ser null durante a troca de cena.
func _scene_name() -> String:
	return String(current_scene.name) if current_scene != null else "null"

func _initialize() -> void:
	_run.call_deferred()

func _host(net: NetworkManager) -> Error:
	# Fechar o servidor ENet pode levar alguns frames para liberar a porta.
	var err: Error = net.host_game(PORT)
	var tries: int = 0
	while err != OK and tries < 10:
		await _wait(10)
		err = net.host_game(PORT)
		tries += 1
	return err

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	var net: NetworkManager = NetworkManager.instance
	_check(gs != null and sm != null and net != null, "autoloads presentes")
	net.session_left.connect(func(was_host: bool) -> void: _left.append(was_host))
	sm.host_lost.connect(func() -> void: _host_lost_count += 1)
	sm.peer_scene_ready.connect(func(peer_id: int, map_id: String) -> void: _ready_pairs.append("%d:%s" % [peer_id, map_id]))

	# Offline no lobby: nada acontece.
	net.disconnect_game()
	await _wait(10)
	_check(_left.is_empty(), "offline: session_left não emitido: %s" % str(_left))
	_check(_scene_name() == "LobbyBase", "offline: continua no lobby: %s" % _scene_name())

	# Host em expedição sai.
	var err: Error = await _host(net)
	_check(err == OK, "host_game(%d)=%d" % [PORT, err])
	sm.request_start_expedition("praia")
	var ready: bool = await _wait_until(func() -> bool: return _ready_pairs.has("1:praia"), 5.0)
	_check(ready, "peer_scene_ready(1, praia)")
	var day_before: int = gs.current_day
	gs.load_snapshot({"team_money": 4321})
	net.disconnect_game()
	var back: bool = await _wait_until(func() -> bool: return _scene_name() == "LobbyBase" and not sm.is_in_expedition(), 3.0)
	await _wait(5)
	_check(_left == [true], "session_left(true) uma vez: %s" % str(_left))
	_check(back and _scene_name() == "LobbyBase", "voltou ao lobby: %s" % _scene_name())
	_check(not sm.is_in_expedition(), "fora da expedição")
	_check(sm.get_ready_peers().is_empty(), "ready_peers vazio: %s" % str(sm.get_ready_peers()))
	_check(_host_lost_count == 0, "host_lost não emitido: %d" % _host_lost_count)
	_check(gs.current_day == day_before, "dia não avançou: %d -> %d" % [day_before, gs.current_day])
	var saved: Dictionary = SaveManager.instance.load_from_file()
	_check(int(saved.get("team_money", -1)) == 4321, "save com team_money 4321: %s" % str(saved.get("team_money")))
	_check(int(saved.get("current_day", -1)) == day_before, "save sem avançar o dia: %s" % str(saved.get("current_day")))

	# Host no lobby sai: emite, mas não troca de cena.
	_left.clear()
	err = await _host(net)
	_check(err == OK, "host_game(%d) de novo=%d" % [PORT, err])
	net.disconnect_game()
	await _wait(10)
	_check(_left == [true], "lobby: session_left(true): %s" % str(_left))
	_check(_scene_name() == "LobbyBase", "lobby: continua no lobby: %s" % _scene_name())
	_check(_host_lost_count == 0, "lobby: host_lost não emitido: %d" % _host_lost_count)

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
