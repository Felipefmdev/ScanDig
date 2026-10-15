## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/expedition_ending_test.gd
## Offline (host = peer 1). Grava o save: faça backup.
extends SceneTree

var _fails: int = 0
## Ordem de chegada de expedition_ending, scene_changing e expedition_ended.
var _log: Array[String] = []
var _ready_pairs: Array[String] = []
## O que o handler de expedition_ending viu no momento do sinal.
var _at_ending: Dictionary = {}
var _reenter: bool = false

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

func _on_expedition_ending(map_id: String) -> void:
	_log.append("expedition_ending:%s" % map_id)
	var sm: SessionManager = SessionManager.instance
	var saved: Dictionary = SaveManager.instance.load_from_file()
	_at_ending = {
		"map_id": map_id,
		"in_expedition": sm.is_in_expedition(),
		"current_map": sm.get_current_map().id if sm.get_current_map() != null else "",
		"scene": _scene_name(),
		"day": GameState.instance.current_day,
		"saved_day": int(saved.get("current_day", -1)),
	}
	# Simula o PlayersRoot do Dev A: tira um nó replicado da árvore na hora.
	var target: Node = current_scene.get_node_or_null(^"Players") if current_scene != null else null
	if target == null and current_scene != null and current_scene.get_child_count() > 0:
		target = current_scene.get_child(0)
	if target != null:
		target.get_parent().remove_child(target)
		target.queue_free()
		_at_ending["removed"] = String(target.name)
	if _reenter:
		sm.request_end_expedition()

func _start_expedition(sm: SessionManager) -> bool:
	_ready_pairs.clear()
	sm.request_start_expedition("praia")
	return await _wait_until(func() -> bool: return _ready_pairs.has("1:praia"), 5.0)

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	_check(gs != null and sm != null, "autoloads presentes")
	sm.expedition_ending.connect(_on_expedition_ending)
	sm.scene_changing.connect(func(target: String) -> void: _log.append("scene_changing:%s" % target.get_file()))
	sm.expedition_ended.connect(func(_summary: Dictionary) -> void: _log.append("expedition_ended"))
	sm.peer_scene_ready.connect(func(peer_id: int, map_id: String) -> void: _ready_pairs.append("%d:%s" % [peer_id, map_id]))

	# Sem expedição: nada é emitido.
	sm.request_end_expedition()
	await _wait(5)
	_check(_log.is_empty(), "lobby: request_end_expedition não emite nada: %s" % str(_log))

	# Expedição normal.
	_check(await _start_expedition(sm), "peer_scene_ready(1, praia)")
	var day_before: int = gs.current_day
	gs.request_report_discovery("moeda_antiga", 10)
	await _wait(3)
	_log.clear()
	sm.request_end_expedition()
	var back: bool = await _wait_until(func() -> bool: return _scene_name() == "LobbyBase", 5.0)
	await _wait(5)
	print("LOG ", _log)
	print("AT_ENDING ", _at_ending)
	_check(back, "voltou ao lobby")
	_check(_log.count("expedition_ending:praia") == 1, "expedition_ending uma vez só")
	var i_ending: int = _log.find("expedition_ending:praia")
	var i_scene: int = _log.find("scene_changing:lobby_base.tscn")
	var i_ended: int = _log.find("expedition_ended")
	_check(i_ending >= 0 and i_scene > i_ending and i_ended > i_ending, "ordem: ending antes de scene_changing(lobby) e de expedition_ended: %s" % str(_log))
	_check(_at_ending.get("map_id") == "praia" and _at_ending.get("current_map") == "praia", "map_id praia no sinal")
	_check(_at_ending.get("in_expedition") == true, "is_in_expedition() true no sinal")
	_check(_at_ending.get("scene") == "MapPraia", "cena ainda é o mapa no sinal: %s" % str(_at_ending.get("scene")))
	_check(_at_ending.get("day") == day_before + 1, "dia já avançou no sinal: %s" % str(_at_ending.get("day")))
	_check(_at_ending.get("saved_day") == day_before + 1, "save já gravado com o dia novo: %s" % str(_at_ending.get("saved_day")))
	_check(_at_ending.has("removed"), "handler removeu um nó do mapa: %s" % str(_at_ending.get("removed", "")))
	var summary: Dictionary = sm.get_last_summary()
	var entries: Array = summary.get("entries", [])
	_check(summary.get("map_id", "") == "praia" and int(summary.get("day", -1)) == day_before, "resumo: map_id e dia: %s" % str(summary))
	_check(entries.size() == 1, "resumo com 1 entrada: %d" % entries.size())
	_check(int(summary.get("money_earned", 0)) == int(summary.get("money_end", 0)) - int(summary.get("money_start", 0)), "resumo: money_earned consistente")
	_check(not sm.is_in_expedition() and gs.current_day == day_before + 1, "fora da expedição, dia +1")

	# Reentrada: o handler pede o fim de novo dentro do sinal.
	_check(await _start_expedition(sm), "segunda expedição pronta")
	var day_reenter: int = gs.current_day
	_reenter = true
	_log.clear()
	sm.request_end_expedition()
	back = await _wait_until(func() -> bool: return _scene_name() == "LobbyBase", 5.0)
	await _wait(5)
	_reenter = false
	print("LOG_REENTRADA ", _log)
	_check(back, "reentrada: voltou ao lobby")
	_check(_log.count("expedition_ending:praia") == 1, "reentrada: um único expedition_ending")
	_check(_log.count("expedition_ended") == 1, "reentrada: um único expedition_ended")
	_check(gs.current_day == day_reenter + 1, "reentrada: dia avançou só 1: %d -> %d" % [day_reenter, gs.current_day])

	# Sem expedição de novo: nada.
	_log.clear()
	sm.request_end_expedition()
	await _wait(5)
	_check(_log.is_empty(), "lobby de novo: nada emitido: %s" % str(_log))

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
