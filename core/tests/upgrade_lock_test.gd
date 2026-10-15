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

	# Sem mapas desbloqueados: detector 1, 2 e 3 passam (#46: o 3 custa 700 e saiu da trava do Campo).
	for i in range(2):
		var ok: Dictionary = await _buy(gs, "detector")
		_check(ok.get("success", false) == true, "detector nível %d sem trava" % (i + 1))
	_check(gs.get_next_upgrade_cost("detector") == 700, "detector nível 3 custa 700: %d" % gs.get_next_upgrade_cost("detector"))
	_check(gs.get_next_upgrade_required_map("detector") == "", "detector nível 3 sem mapa: %s" % gs.get_next_upgrade_required_map("detector"))
	_check(gs.get_upgrade_block_reason("detector") == "", "detector nível 3 sem motivo de bloqueio: %s" % gs.get_upgrade_block_reason("detector"))
	var money_third: int = gs.team_money
	var third: Dictionary = await _buy(gs, "detector")
	_check(third.get("success", false) == true, "detector nível 3 sem Campo: %s" % str(third.get("message", "")))
	_check(money_third - gs.team_money == 700, "custo do nível 3: %d" % (money_third - gs.team_money))
	_check(gs.equipped_detector_level == 4, "detector equipado Nv.4: %d" % gs.equipped_detector_level)

	# O 4 pede as Ruínas, mesmo com o Campo aberto.
	gs.load_snapshot({"unlocked_maps": ["campo"]})
	_check(gs.get_next_upgrade_required_map("detector") == "ruinas", "próximo detector exige ruinas: %s" % gs.get_next_upgrade_required_map("detector"))
	_check(gs.get_upgrade_block_reason("detector") == "Desbloqueie Ruínas primeiro.", "motivo das Ruínas: %s" % gs.get_upgrade_block_reason("detector"))
	var money_before: int = gs.team_money
	var locked: Dictionary = await _buy(gs, "detector")
	_check(locked.get("success", true) == false and locked.get("message", "") == "Desbloqueie Ruínas primeiro.", "compra 4 falha pelas Ruínas: %s" % str(locked.get("message", "")))
	_check(gs.team_money == money_before and gs.get_upgrade_level("detector") == 3, "trava não muda saldo nem nível")

	# #49: com as Ruínas compra o 4; o 5 (equipado Nv.6, que a Cratera exige) pede a Geleira.
	gs.load_snapshot({"unlocked_maps": ["campo", "ruinas"]})
	var fourth: Dictionary = await _buy(gs, "detector")
	_check(fourth.get("success", false) == true, "detector nível 4 com Ruínas: %s" % str(fourth.get("message", "")))
	_check(gs.get_next_upgrade_required_map("detector") == "geleira", "próximo detector exige geleira: %s" % gs.get_next_upgrade_required_map("detector"))
	_check(gs.get_upgrade_block_reason("detector") == "Desbloqueie Geleira Eterna primeiro.", "motivo da Geleira: %s" % gs.get_upgrade_block_reason("detector"))
	money_before = gs.team_money
	locked = await _buy(gs, "detector")
	_check(locked.get("success", true) == false and locked.get("message", "") == "Desbloqueie Geleira Eterna primeiro.", "compra 5 falha pela Geleira: %s" % str(locked.get("message", "")))
	_check(gs.team_money == money_before and gs.get_upgrade_level("detector") == 4, "trava da Geleira não muda saldo nem nível")

	# Com a Geleira compra o 5 (R$ 12.000); o 6 pede a Cratera.
	gs.load_snapshot({"unlocked_maps": ["campo", "ruinas", "geleira"]})
	_check(gs.get_next_upgrade_cost("detector") == 12000, "detector nível 5 custa 12000: %d" % gs.get_next_upgrade_cost("detector"))
	var fifth: Dictionary = await _buy(gs, "detector")
	_check(fifth.get("success", false) == true, "detector nível 5 com Geleira: %s" % str(fifth.get("message", "")))
	_check(gs.equipped_detector_level == 6, "detector equipado Nv.6 antes da Cratera: %d" % gs.equipped_detector_level)
	_check(gs.get_next_upgrade_required_map("detector") == "cratera", "próximo detector exige cratera: %s" % gs.get_next_upgrade_required_map("detector"))
	_check(gs.get_upgrade_block_reason("detector") == "Desbloqueie Cratera primeiro.", "motivo da Cratera: %s" % gs.get_upgrade_block_reason("detector"))

	# Tudo aberto: detector até o nível 6 (equipado 7) e depois máximo.
	gs.load_snapshot({"unlocked_maps": ["campo", "ruinas", "geleira", "cratera"]})
	var sixth: Dictionary = await _buy(gs, "detector")
	_check(sixth.get("success", false) == true, "detector nível 6 com Cratera: %s" % str(sixth.get("message", "")))
	_check(gs.get_upgrade_level("detector") == 6 and gs.equipped_detector_level == 7, "detector Nv.6 / equipado 7: %d / %d" % [gs.get_upgrade_level("detector"), gs.equipped_detector_level])
	var maxed: Dictionary = await _buy(gs, "detector")
	_check(maxed.get("success", true) == false and maxed.get("message", "") == "Detector já está no nível máximo.", "detector no máximo: %s" % str(maxed.get("message", "")))
	_check(gs.get_next_upgrade_required_map("detector") == "", "required_map vazio no máximo")
	_check(gs.team_money == 100000 - (300 + 600 + 700 + 2000 + 12000 + 25000), "saldo após 6 níveis: %d" % gs.team_money)

	# Trava aberta e saldo baixo: o motivo é o saldo (a trava vem antes, mas está satisfeita).
	gs.load_snapshot({"team_money": 100})
	_check(gs.get_upgrade_block_reason("pinpointer") == "Saldo insuficiente para Pinpointer de Precisão (Custo: R$" + MoneyFormat.NBSP + "500).", "motivo de saldo: %s" % gs.get_upgrade_block_reason("pinpointer"))
	# Trava fechada e saldo baixo: a trava vem antes do saldo.
	gs.load_snapshot({"unlocked_maps": [], "upgrade_levels": {"shovel": 1}})
	_check(gs.get_upgrade_block_reason("shovel") == "Desbloqueie Ruínas primeiro.", "trava antes do saldo: %s" % gs.get_upgrade_block_reason("shovel"))

	# #49: a mochila de 8 espaços (nível 5) pede a Geleira.
	gs.load_snapshot({"team_money": 100000, "unlocked_maps": ["campo", "ruinas"], "upgrade_levels": {"backpack": 4}})
	_check(gs.get_upgrade_block_reason("backpack") == "Desbloqueie Geleira Eterna primeiro.", "mochila nível 5 pede a Geleira: %s" % gs.get_upgrade_block_reason("backpack"))

	# Save antigo: nível comprado antes da trava continua valendo.
	gs.load_snapshot({"team_money": 0, "upgrade_levels": {"detector": 3}, "unlocked_maps": []})
	_check(gs.get_upgrade_level("detector") == 3, "save antigo mantém detector 3: %d" % gs.get_upgrade_level("detector"))
	_check(gs.get_next_upgrade_required_map("detector") == "ruinas", "save antigo: próximo exige ruinas")

	_check(gs.get_upgrade_block_reason("xyz") == "Upgrade desconhecido.", "upgrade desconhecido")
	_check(gs.get_next_upgrade_required_map("xyz") == "", "required_map de upgrade desconhecido vazio")

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
