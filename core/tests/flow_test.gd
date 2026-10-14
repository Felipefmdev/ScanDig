## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/flow_test.gd
extends SceneTree

var _fails: int = 0

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	_check(gs != null and sm != null, "autoloads presentes")
	_check(current_scene != null and current_scene.name == "LobbyBase", "lobby carregado")
	var day0: int = gs.current_day
	var money0: int = gs.team_money
	_check(sm.get_available_maps().size() >= 1, "mapas disponiveis")
	_check(sm.can_start_map("praia"), "pode iniciar praia")
	sm.request_start_expedition("praia")
	await _wait(30)
	_check(sm.is_in_expedition(), "em expedicao")
	_check(current_scene != null and current_scene.name == "MapPraia", "cena praia: %s" % (current_scene.name if current_scene else "null"))
	gs.request_report_discovery("moeda_antiga", 100)
	gs.request_report_discovery("moeda_antiga", 100)
	await _wait(2)
	sm.request_end_expedition()
	await _wait(30)
	_check(not sm.is_in_expedition(), "fim da expedicao")
	_check(current_scene != null and current_scene.name == "LobbyBase", "voltou ao lobby")
	_check(gs.current_day == day0 + 1, "dia avancou %d->%d" % [day0, gs.current_day])
	var s: Dictionary = sm.get_last_summary()
	print("summary: ", s)
	_check((s.get("entries", []) as Array).size() == 2, "2 entradas no resumo")
	_check(gs.team_money > money0, "dinheiro aumentou")
	_check(gs.discovered_items.has("moeda_antiga"), "moeda no museu")
	print("RESULT fails=%d" % _fails)
	quit(_fails)
