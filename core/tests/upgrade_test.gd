# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/upgrade_test.gd
extends SceneTree

var _fails: int = 0
var _last_result: Dictionary = {}

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _on_purchase_result(upgrade_id: String, success: bool, message: String) -> void:
	_last_result = {"upgrade_id": upgrade_id, "success": success, "message": message}

func _buy(gs: GameState, upgrade_id: String) -> Dictionary:
	_last_result = {}
	gs.request_buy_upgrade(upgrade_id)
	await _wait(3)
	return _last_result

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	var gs: GameState = GameState.instance
	_check(gs != null, "GameState presente")
	gs.purchase_result.connect(_on_purchase_result)
	gs.load_snapshot({"team_money": 10000, "current_day": 1, "discovered_items": [], "upgrade_levels": {}})

	_check(gs.get_backpack_capacity() == 3, "mochila inicial 3: %d" % gs.get_backpack_capacity())
	_check(gs.get_shovel_level() == 1, "pa inicial 1: %d" % gs.get_shovel_level())
	_check(not gs.has_pinpointer(), "sem pinpointer inicial")

	# Níveis 1 e 2 da mochila não têm trava de mapa.
	var expected_costs: Array[int] = [400, 800]
	for i in range(2):
		var money_before: int = gs.team_money
		var result: Dictionary = await _buy(gs, "backpack")
		_check(result.get("success", false) == true, "compra mochila %d ok" % (i + 1))
		_check(gs.get_backpack_capacity() == 4 + i, "mochila %d: %d" % [4 + i, gs.get_backpack_capacity()])
		_check(money_before - gs.team_money == expected_costs[i], "custo %d: %d" % [expected_costs[i], money_before - gs.team_money])
	var money_locked: int = gs.team_money
	var third: Dictionary = await _buy(gs, "backpack")
	_check(third.get("success", true) == false, "terceira compra falha sem Campo: %s" % str(third.get("message", "")))
	_check(third.get("message", "") == "Desbloqueie Campo Antigo primeiro.", "mensagem da trava do Campo")
	_check(gs.get_backpack_capacity() == 5 and gs.team_money == money_locked, "trava não muda mochila nem saldo")

	gs.load_snapshot({"unlocked_maps": ["campo"]})
	var money_before_third: int = gs.team_money
	third = await _buy(gs, "backpack")
	_check(third.get("success", false) == true, "terceira compra ok com Campo: %s" % str(third.get("message", "")))
	_check(gs.get_backpack_capacity() == 6, "mochila 6: %d" % gs.get_backpack_capacity())
	_check(money_before_third - gs.team_money == 1600, "custo 1600: %d" % (money_before_third - gs.team_money))
	_check(gs.team_money == 10000 - 2800, "saldo final %d" % gs.team_money)

	var shovel: Dictionary = await _buy(gs, "shovel")
	var pinpointer: Dictionary = await _buy(gs, "pinpointer")
	_check(shovel.get("success", false) == true and gs.get_shovel_level() == 2, "pa nivel 2: %d" % gs.get_shovel_level())
	_check(pinpointer.get("success", false) == true and gs.has_pinpointer(), "pinpointer comprado")
	_check(gs.get_pinpointer_level() == 1, "pinpointer nivel 1: %d" % gs.get_pinpointer_level())

	gs.apply_snapshot({"upgrade_levels": {"detector": 1}})
	_check(gs.get_upgrade_level("backpack") == 0, "save v2 sem backpack -> 0")
	gs.apply_snapshot({"upgrade_levels": {"backpack": 99}})
	_check(gs.get_upgrade_level("backpack") == 5, "backpack 99 limitado a 5: %d" % gs.get_upgrade_level("backpack"))

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
