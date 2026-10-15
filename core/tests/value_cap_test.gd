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

	# Tetos calculados do catálogo: o rebalanceamento de base_value (#19) não quebra o teste.
	var alianca_expected: int = int(ceil(float(alianca.base_value) * BuriedSpot.RARE_VALUE_MULTIPLIER * BuriedSpot.PERFECT_BONUS_MULTIPLIER))
	var alianca_max: int = gs.get_max_item_value(alianca)
	_check(alianca_max == alianca_expected, "teto alianca_ouro %d: %d" % [alianca_expected, alianca_max])
	var chave_expected: int = int(ceil(float(chave.base_value) * BuriedSpot.RARE_VALUE_MULTIPLIER * BuriedSpot.PERFECT_BONUS_MULTIPLIER))
	var chave_max: int = gs.get_max_item_value(chave)
	_check(chave_max == chave_expected, "teto chave_enferrujada %d: %d" % [chave_expected, chave_max])
	_check(alianca_max > alianca.base_value, "teto acima do base_value: %d > %d" % [alianca_max, alianca.base_value])
	_check(gs.get_max_item_value(null) == 0, "teto de item nulo 0")

	var rare_perfect: int = alianca_max - 1
	var delta: int = await _sell_delta(gs, "alianca_ouro", rare_perfect)
	_check(delta == rare_perfect, "venda rara+perfeita %d: %d" % [rare_perfect, delta])
	delta = await _sell_delta(gs, "alianca_ouro", alianca_max * 10 + 1000)
	_check(delta == alianca_max, "venda trapaça limitada a %d: %d" % [alianca_max, delta])
	delta = await _sell_delta(gs, "alianca_ouro", -50)
	_check(delta == 0, "venda negativa 0: %d" % delta)
	var normal: int = maxi(int(float(alianca.base_value) * 0.8), 1)
	delta = await _sell_delta(gs, "alianca_ouro", normal)
	_check(delta == normal, "venda comum %d: %d" % [normal, delta])

	var donated_value: int = chave_max - 1
	var reward_expected: int = int(round(float(donated_value) * GameState.MUSEUM_REWARD_RATIO))
	var money_before: int = gs.team_money
	gs.request_report_discovery("chave_enferrujada", donated_value)
	await _wait(3)
	var reward: int = gs.team_money - money_before
	_check(reward == reward_expected, "doação chave_enferrujada recompensa %d: %d" % [reward_expected, reward])
	_check(gs.discovered_items.has("chave_enferrujada"), "chave_enferrujada no museu")

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
