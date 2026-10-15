# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/upgrade_lock_test.gd
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
	gs.load_snapshot({"team_money": 100000, "current_day": 1, "discovered_items": [], "upgrade_levels": {}, "unlocked_maps": [], "defeated_bosses": []})

	# Sem mapas desbloqueados: detector 1 e 2 passam, o 3 pede o Campo.
	for i in range(2):
		var ok: Dictionary = await _buy(gs, "detector")
		_check(ok.get("success", false) == true, "detector nível %d sem trava" % (i + 1))
	_check(gs.equipped_detector_level == 3, "detector equipado Nv.3: %d" % gs.equipped_detector_level)
	_check(gs.get_next_upgrade_required_map("detector") == "campo", "próximo detector exige campo: %s" % gs.get_next_upgrade_required_map("detector"))
	_check(gs.get_upgrade_block_reason("detector") == "Desbloqueie Campo Antigo primeiro.", "motivo do Campo: %s" % gs.get_upgrade_block_reason("detector"))
	var money_before: int = gs.team_money
	var locked: Dictionary = await _buy(gs, "detector")
	_check(locked.get("success", true) == false and locked.get("message", "") == "Desbloqueie Campo Antigo primeiro.", "compra 3 falha pelo Campo: %s" % str(locked.get("message", "")))
	_check(gs.team_money == money_before and gs.get_upgrade_level("detector") == 2, "trava não muda saldo nem nível")

	# Campo aberto: o 3 passa, o 4 pede as Ruínas.
	gs.load_snapshot({"unlocked_maps": ["campo"]})
	var third: Dictionary = await _buy(gs, "detector")
	_check(third.get("success", false) == true, "detector nível 3 com Campo: %s" % str(third.get("message", "")))
	_check(gs.equipped_detector_level == 4, "detector equipado Nv.4: %d" % gs.equipped_detector_level)
	_check(gs.get_next_upgrade_required_map("detector") == "ruinas", "próximo detector exige ruinas: %s" % gs.get_next_upgrade_required_map("detector"))
	_check(gs.get_upgrade_block_reason("detector") == "Desbloqueie Ruínas primeiro.", "motivo das Ruínas: %s" % gs.get_upgrade_block_reason("detector"))

	# Tudo aberto: detector até o nível 6 (equipado 7) e depois máximo.
	gs.load_snapshot({"unlocked_maps": ["campo", "ruinas", "cratera"]})
	for level in range(4, 7):
		var bought: Dictionary = await _buy(gs, "detector")
		_check(bought.get("success", false) == true, "detector nível %d: %s" % [level, str(bought.get("message", ""))])
	_check(gs.get_upgrade_level("detector") == 6 and gs.equipped_detector_level == 7, "detector Nv.6 / equipado 7: %d / %d" % [gs.get_upgrade_level("detector"), gs.equipped_detector_level])
	var maxed: Dictionary = await _buy(gs, "detector")
	_check(maxed.get("success", true) == false and maxed.get("message", "") == "Detector já está no nível máximo.", "detector no máximo: %s" % str(maxed.get("message", "")))
	_check(gs.get_next_upgrade_required_map("detector") == "", "required_map vazio no máximo")
	_check(gs.team_money == 100000 - (300 + 600 + 1200 + 2000 + 15000 + 25000), "saldo após 6 níveis: %d" % gs.team_money)

	# Trava aberta e saldo baixo: o motivo é o saldo (a trava vem antes, mas está satisfeita).
	gs.load_snapshot({"team_money": 100})
	_check(gs.get_upgrade_block_reason("pinpointer") == "Saldo insuficiente para Pinpointer de Precisão (Custo: R$ 500).", "motivo de saldo: %s" % gs.get_upgrade_block_reason("pinpointer"))
	# Trava fechada e saldo baixo: a trava vem antes do saldo.
	gs.load_snapshot({"unlocked_maps": [], "upgrade_levels": {"shovel": 1}})
	_check(gs.get_upgrade_block_reason("shovel") == "Desbloqueie Ruínas primeiro.", "trava antes do saldo: %s" % gs.get_upgrade_block_reason("shovel"))

	# Save antigo: nível comprado antes da trava continua valendo.
	gs.load_snapshot({"team_money": 0, "upgrade_levels": {"detector": 3}, "unlocked_maps": []})
	_check(gs.get_upgrade_level("detector") == 3, "save antigo mantém detector 3: %d" % gs.get_upgrade_level("detector"))
	_check(gs.get_next_upgrade_required_map("detector") == "ruinas", "save antigo: próximo exige ruinas")

	_check(gs.get_upgrade_block_reason("xyz") == "Upgrade desconhecido.", "upgrade desconhecido")
	_check(gs.get_next_upgrade_required_map("xyz") == "", "required_map de upgrade desconhecido vazio")

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
