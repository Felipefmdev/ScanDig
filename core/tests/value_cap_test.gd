# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/value_cap_test.gd
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

func _sell_delta(gs: GameState, item_id: String, final_value: int) -> int:
	var money_before: int = gs.team_money
	gs.request_sell_item(item_id, final_value)
	await _wait(3)
	return gs.team_money - money_before

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	var gs: GameState = GameState.instance
	_check(gs != null, "GameState presente")
	gs.load_snapshot({"team_money": 0, "current_day": 1, "discovered_items": ["alianca_ouro"], "upgrade_levels": {}})

	var alianca: ItemData = load("res://items/catalog/alianca_ouro.tres") as ItemData
	var chave: ItemData = load("res://items/catalog/chave_enferrujada.tres") as ItemData
	_check(alianca != null and chave != null, "itens do catálogo carregados")

	var alianca_max: int = gs.get_max_item_value(alianca)
	_check(alianca_max == 938, "teto alianca_ouro 938: %d" % alianca_max)
	var chave_max: int = gs.get_max_item_value(chave)
	var chave_expected: int = int(ceil(15 * 3.0 * 1.25))
	_check(chave_max == chave_expected and chave_max == 57, "teto chave_enferrujada 57: %d" % chave_max)
	_check(gs.get_max_item_value(null) == 0, "teto de item nulo 0")

	var delta: int = await _sell_delta(gs, "alianca_ouro", 937)
	_check(delta == 937, "venda rara+perfeita 937: %d" % delta)
	delta = await _sell_delta(gs, "alianca_ouro", 99999)
	_check(delta == 938, "venda trapaça limitada a 938: %d" % delta)
	delta = await _sell_delta(gs, "alianca_ouro", -50)
	_check(delta == 0, "venda negativa 0: %d" % delta)
	delta = await _sell_delta(gs, "alianca_ouro", 200)
	_check(delta == 200, "venda comum 200: %d" % delta)

	var money_before: int = gs.team_money
	gs.request_report_discovery("chave_enferrujada", 56)
	await _wait(3)
	var reward: int = gs.team_money - money_before
	_check(reward == int(round(56 * 0.5)) and reward == 28, "doação chave_enferrujada recompensa 28: %d" % reward)
	_check(gs.discovered_items.has("chave_enferrujada"), "chave_enferrujada no museu")

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
