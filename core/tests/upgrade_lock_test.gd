# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/upgrade_lock_test.gd
## Travas da loja por mapa (#25/#46/#49). Custos e mapas vêm de GameState.UPGRADES (#64): o teste
## confere as regras (trava antes do saldo, custo cobrado, máximo), não os preços.
## A tabela atual fica fixada só no economy_anchor_test.
extends SceneTree
const WORLD_SHOP: Script = preload("res://core/tests/world_shop_fixture.gd")
var _shop: Variant = null

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

func _buy(_gs: GameState, upgrade_id: String) -> Dictionary:
	return await _shop.buy_upgrade(upgrade_id)

func _map_name(map_id: String) -> String:
	var map_data: MapData = load("res://items/maps/%s.tres" % map_id) as MapData
	return map_data.display_name if map_data != null else map_id

func _total_cost(upgrade_id: String) -> int:
	var total: int = 0
	for cost: Variant in GameState.UPGRADES[upgrade_id]["costs"]:
		total += int(cost)
	return total

## Compra todos os níveis de um upgrade, abrindo cada mapa exigido só depois de ver a trava.
func _walk_upgrade(gs: GameState, upgrade_id: String) -> void:
	var entry: Dictionary = GameState.UPGRADES[upgrade_id]
	var upgrade_name: String = str(entry["name"])
	var costs: Array = entry["costs"]
	var required_maps: Array = entry["required_maps"]
	var max_level: int = int(entry["max_level"])
	var unlocked: Array[String] = []
	gs.load_snapshot({"team_money": _total_cost(upgrade_id) + 1000, "upgrade_levels": {}, "unlocked_maps": [], "defeated_bosses": []})
	await _wait(2)
	for level in range(max_level):
		var cost: int = int(costs[level])
		var required_map: String = str(required_maps[level])
		_check(gs.get_next_upgrade_cost(upgrade_id) == cost, "%s nível %d custa o da tabela: %d / %d" % [upgrade_id, level + 1, gs.get_next_upgrade_cost(upgrade_id), cost])
		_check(gs.get_next_upgrade_required_map(upgrade_id) == required_map, "%s nível %d exige '%s': '%s'" % [upgrade_id, level + 1, required_map, gs.get_next_upgrade_required_map(upgrade_id)])
		if not required_map.is_empty() and not unlocked.has(required_map):
			var lock_msg: String = "Desbloqueie %s primeiro." % _map_name(required_map)
			_check(gs.get_upgrade_block_reason(upgrade_id) == lock_msg, "%s nível %d travado: %s" % [upgrade_id, level + 1, gs.get_upgrade_block_reason(upgrade_id)])
			var money_locked: int = gs.team_money
			var locked: Dictionary = await _buy(gs, upgrade_id)
			_check(locked.get("success", true) == false and locked.get("message", "") == lock_msg, "%s nível %d: compra falha pela trava: %s" % [upgrade_id, level + 1, str(locked.get("message", ""))])
			_check(gs.team_money == money_locked and gs.get_upgrade_level(upgrade_id) == level, "%s: trava não muda saldo nem nível" % upgrade_id)
			unlocked.append(required_map)
			gs.load_snapshot({"unlocked_maps": unlocked})
			await _wait(2)
		_check(gs.get_upgrade_block_reason(upgrade_id) == "", "%s nível %d liberado: %s" % [upgrade_id, level + 1, gs.get_upgrade_block_reason(upgrade_id)])
		var money_before: int = gs.team_money
		var bought: Dictionary = await _buy(gs, upgrade_id)
		_check(bought.get("success", false) == true, "%s nível %d comprado: %s" % [upgrade_id, level + 1, str(bought.get("message", ""))])
		_check(money_before - gs.team_money == cost and gs.get_upgrade_level(upgrade_id) == level + 1, "%s nível %d cobra %d: %d" % [upgrade_id, level + 1, cost, money_before - gs.team_money])
	var maxed: Dictionary = await _buy(gs, upgrade_id)
	_check(maxed.get("success", true) == false and maxed.get("message", "") == "%s já está no nível máximo." % upgrade_name, "%s no máximo: %s" % [upgrade_id, str(maxed.get("message", ""))])
	_check(gs.get_next_upgrade_cost(upgrade_id) == -1 and gs.get_next_upgrade_required_map(upgrade_id) == "", "%s: custo -1 e sem mapa no máximo" % upgrade_id)
	if upgrade_id == "detector":
		_check(gs.equipped_detector_level == 1 + max_level, "detector equipado = 1 + nível máximo: %d" % gs.equipped_detector_level)

func _run() -> void:
	_shop = WORLD_SHOP.new()
	if not _shop.setup(self,"upgrade_lock"):
		_check(false,"physical fixture: "+str(_shop.errors))
		_shop.cleanup()
		quit(_fails)
		return
	var gs: GameState = GameState.instance
	_check(gs != null, "GameState presente")
	gs.purchase_result.connect(_on_purchase_result)
	gs.load_snapshot({"team_money":10000,"upgrade_levels":{}})
	_last_result = {}
	gs.request_buy_upgrade("detector")
	await _wait(3)
	_check(_last_result.get("success",true) == false and gs.team_money == 10000 and gs.get_upgrade_level("detector") == 0,"legacy upgrade endpoint denied despite sufficient balance")

	# Tabela coerente: um custo e um mapa por nível, mapas existentes e custos positivos.
	for upgrade_id: String in GameState.UPGRADES.keys():
		var entry: Dictionary = GameState.UPGRADES[upgrade_id]
		var max_level: int = int(entry["max_level"])
		_check((entry["costs"] as Array).size() == max_level and (entry["required_maps"] as Array).size() == max_level, "%s: custos e mapas por nível" % upgrade_id)
		for cost: Variant in entry["costs"]:
			_check(int(cost) > 0, "%s: custo positivo %d" % [upgrade_id, int(cost)])
		for map_id: Variant in entry["required_maps"]:
			_check(str(map_id).is_empty() or SessionManager.MAP_ORDER.has(str(map_id)), "%s: mapa '%s' existe" % [upgrade_id, map_id])

	# Cada upgrade, nível a nível: trava, custo cobrado e máximo.
	for upgrade_id: String in GameState.UPGRADES.keys():
		await _walk_upgrade(gs, upgrade_id)

	# Historical equipment-tier ordering stays coherent; detector is no longer an entry toll.
	var detector_maps: Array = GameState.UPGRADES["detector"]["required_maps"]
	for map_id: String in SessionManager.MAP_ORDER:
		var map_data: MapData = load("res://items/maps/%s.tres" % map_id) as MapData
		var level_index: int = map_data.required_detector_level - 2
		if level_index < 0:
			continue
		var gate: String = str(detector_maps[level_index]) if level_index < detector_maps.size() else "?"
		var ok: bool = gate.is_empty() or SessionManager.MAP_ORDER.find(gate) < SessionManager.MAP_ORDER.find(map_id)
		_check(ok, "detector Nv.%d de %s se compra antes (trava '%s')" % [map_data.required_detector_level, map_id, gate])

	# Trava aberta e saldo baixo: o motivo é o saldo, com o custo formatado.
	var pin_cost: int = int(GameState.UPGRADES["pinpointer"]["costs"][0])
	gs.load_snapshot({"team_money": pin_cost - 1, "upgrade_levels": {}, "unlocked_maps": []})
	await _wait(2)
	var pin_name: String = str(GameState.UPGRADES["pinpointer"]["name"])
	_check(gs.get_upgrade_block_reason("pinpointer") == "Saldo insuficiente para %s (Custo: %s)." % [pin_name, MoneyFormat.money(pin_cost)], "motivo de saldo: %s" % gs.get_upgrade_block_reason("pinpointer"))
	# Trava fechada e saldo baixo: a trava vem antes do saldo.
	var shovel_map: String = str(GameState.UPGRADES["shovel"]["required_maps"][1])
	gs.load_snapshot({"team_money": 0, "unlocked_maps": [], "upgrade_levels": {"shovel": 1}})
	await _wait(2)
	_check(not shovel_map.is_empty() and gs.get_upgrade_block_reason("shovel") == "Desbloqueie %s primeiro." % _map_name(shovel_map), "trava antes do saldo: %s" % gs.get_upgrade_block_reason("shovel"))

	# Save antigo: nível comprado antes da trava continua valendo.
	gs.load_snapshot({"team_money": 0, "upgrade_levels": {"detector": 3}, "unlocked_maps": []})
	await _wait(2)
	_check(gs.get_upgrade_level("detector") == 3, "save antigo mantém detector 3: %d" % gs.get_upgrade_level("detector"))
	_check(gs.get_next_upgrade_required_map("detector") == str(detector_maps[3]), "save antigo: próximo exige '%s'" % str(detector_maps[3]))

	_check(gs.get_upgrade_block_reason("xyz") == "Upgrade desconhecido.", "upgrade desconhecido")
	_check(gs.get_next_upgrade_required_map("xyz") == "", "required_map de upgrade desconhecido vazio")
	var money_unknown: int = gs.team_money
	var unknown: Dictionary = await _buy(gs,"xyz")
	_check(not bool(unknown.get("success",true)) and unknown.get("message","") == "Upgrade desconhecido." and gs.team_money == money_unknown,"unknown upgrade rejected at real counter without charge")

	_check(_shop.errors.is_empty(),"bounded correlated physical replies: "+str(_shop.errors))
	_shop.cleanup()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
