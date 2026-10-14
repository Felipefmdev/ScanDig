## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/scene_ready_test.gd
extends SceneTree

var _fails: int = 0
var _signals: Array[Dictionary] = []

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

func _initialize() -> void:
	_run.call_deferred()

func _on_peer_scene_ready(peer_id: int, map_id: String) -> void:
	var scene_name: String = String(current_scene.name) if current_scene != null else "null"
	_signals.append({"peer_id": peer_id, "map_id": map_id, "scene": scene_name})

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	var sm: SessionManager = SessionManager.instance
	_check(sm != null, "SessionManager presente")
	sm.peer_scene_ready.connect(_on_peer_scene_ready)
	await _wait(5)
	_check(_signals.is_empty(), "lobby não gera peer_scene_ready")

	sm.request_start_expedition("praia")
	var got: bool = await _wait_until(func() -> bool: return not _signals.is_empty(), 5.0)
	_check(got, "peer_scene_ready chegou em 5 s")
	await _wait(10)
	_check(_signals.size() == 1, "peer_scene_ready uma vez só: %s" % str(_signals))
	if not _signals.is_empty():
		var first: Dictionary = _signals[0]
		_check(first["peer_id"] == 1 and first["map_id"] == "praia", "sinal (1, praia): %s" % str(first))
		_check(first["scene"] == "MapPraia", "cena no momento do sinal: %s" % str(first["scene"]))
	_check(sm.get_ready_peers() == [1], "get_ready_peers [1]: %s" % str(sm.get_ready_peers()))
	_check(sm.is_peer_scene_ready(1), "is_peer_scene_ready(1)")

	sm.request_end_expedition()
	var back: bool = await _wait_until(func() -> bool: return current_scene != null and current_scene.name == "LobbyBase", 5.0)
	await _wait(10)
	_check(back, "voltou ao lobby")
	_check(sm.get_ready_peers().is_empty(), "get_ready_peers vazio no lobby: %s" % str(sm.get_ready_peers()))
	_check(not sm.is_peer_scene_ready(1), "is_peer_scene_ready(1) false no lobby")
	_check(_signals.size() == 1, "nenhum peer_scene_ready novo: %d" % _signals.size())

	GameState.instance.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
