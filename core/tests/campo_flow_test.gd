## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/campo_flow_test.gd
## Chefe vencido → desbloqueio do Campo → expedição no map_campo → volta ao lobby com resumo.
extends SceneTree

const CAMPO_SCENE: String = "res://world/map_campo.tscn"

var _fails: int = 0
var _unlock_result: Dictionary = {}
var _ready_signals: Array[Dictionary] = []

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

func _on_map_unlock_result(map_id: String, success: bool, message: String) -> void:
	_unlock_result = {"map_id": map_id, "success": success, "message": message}

func _on_peer_scene_ready(peer_id: int, map_id: String) -> void:
	_ready_signals.append({"peer_id": peer_id, "map_id": map_id})

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("campo_flow_test")
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	_check(gs != null and sm != null, "GameState e SessionManager presentes")
	if gs == null or sm == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	gs.map_unlock_result.connect(_on_map_unlock_result)
	sm.peer_scene_ready.connect(_on_peer_scene_ready)
	# Preço e detector vêm do campo.tres (#64): sobram 500 depois do desbloqueio.
	var campo_data: MapData = load("res://items/maps/campo.tres") as MapData
	gs.load_snapshot({"team_money": campo_data.unlock_cost + 500, "current_day": 1, "discovered_items": [], "upgrade_levels": {"detector": campo_data.required_detector_level - 1}, "unlocked_maps": [], "defeated_bosses": []})
	await _wait(3)

	gs.request_report_boss_defeated("king_crab")
	await _wait(3)
	_check(gs.is_boss_defeated("king_crab"), "king_crab vencido")
	gs.request_unlock_map("campo")
	var unlocked: bool = await _wait_until(func() -> bool: return not _unlock_result.is_empty(), 5.0)
	_check(unlocked and _unlock_result.get("map_id", "") == "campo" and _unlock_result.get("success", false) == true, "desbloqueio campo ok: %s" % str(_unlock_result))
	_check(gs.team_money == 500, "dinheiro 500: %d" % gs.team_money)
	_check(sm.can_start_map("campo"), "can_start_map campo")

	var day0: int = gs.current_day
	sm.request_start_expedition("campo")
	var ready: bool = await _wait_until(func() -> bool:
		return _ready_signals.any(func(s: Dictionary) -> bool: return s["peer_id"] == 1 and s["map_id"] == "campo"), 10.0)
	_check(ready, "peer_scene_ready(1, campo) em 10 s: %s" % str(_ready_signals))
	var scene_path: String = current_scene.scene_file_path if current_scene != null else "null"
	_check(scene_path == CAMPO_SCENE, "cena do campo: %s" % scene_path)
	_check(sm.is_in_expedition(), "em expedição")
	await _wait(30)

	sm.request_end_expedition()
	var back: bool = await _wait_until(func() -> bool: return current_scene != null and current_scene.name == "LobbyBase", 5.0)
	await _wait(10)
	_check(back, "voltou ao lobby")
	_check(not sm.is_in_expedition(), "fim da expedição")
	_check(gs.current_day == day0 + 1, "dia avançou %d->%d" % [day0, gs.current_day])
	var summary: Dictionary = sm.get_last_summary()
	_check(summary.get("map_id", "") == "campo", "resumo do campo: %s" % str(summary.get("map_id", "")))

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
