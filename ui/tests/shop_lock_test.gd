# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/shop_lock_test.gd
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

func _snapshot(money: int, unlocked_maps: Array, levels: Dictionary = {"detector": 2, "backpack": 2}) -> Dictionary:
	return {
		"team_money": money,
		"current_day": 1,
		"discovered_items": [],
		"upgrade_levels": levels,
		"unlocked_maps": unlocked_maps,
		"defeated_bosses": [],
	}

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	# Save isolado: nada deste teste toca o user://scandig_save.json do jogador.
	SaveManager.instance.use_test_save_dir("shop_lock_test")
	await _wait(10)
	var gs: GameState = GameState.instance
	_check(gs != null, "GameState presente")
	var ui: BaseStationUI = current_scene.get_node("UILayer/BaseStationUI") as BaseStationUI
	_check(ui != null, "BaseStationUI presente")
	if gs == null or ui == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	var detector: Button = ui.buy_detector_btn
	var backpack: Button = ui.buy_backpack_btn
	var shovel: Button = ui.buy_shovel_btn

	# 1. Nenhum mapa aberto: detector Nv.3 sem trava; mochila Nv.3 travada pelo Campo.
	gs.load_snapshot(_snapshot(100000, []))
	await _wait(3)
	_check(not detector.disabled, "detector habilitado sem mapas: %s" % detector.tooltip_text)
	_check(not detector.text.contains("🔒"), "detector sem cadeado: %s" % detector.text)
	_check(detector.text.contains("Comprar nível 3 — R$\u00a0700") and detector.text.contains("radar Nv.3"), "detector compra 3: %s" % detector.text)
	_check(detector.tooltip_text == "Radar: Nv.3 → Nv.4", "tooltip radar: %s" % detector.tooltip_text)
	_check(backpack.text.contains("🔒 Requer Campo Antigo"), "mochila travada: %s" % backpack.text)
	_check(backpack.disabled, "mochila desabilitada")
	_check(backpack.tooltip_text == "Desbloqueie Campo Antigo primeiro.", "tooltip mochila: %s" % backpack.tooltip_text)
	_check(not shovel.disabled and shovel.text.contains("Comprar nível 1 — R$\u00a0800"), "pá liberada: %s" % shovel.text)

	# 2. Compra o nível 3: o 4 trava nas Ruínas.
	detector.pressed.emit()
	await _wait(5)
	_check(gs.get_upgrade_level("detector") == 3, "detector nível 3: %d" % gs.get_upgrade_level("detector"))
	_check(detector.text.contains("🔒 Requer Ruínas") and detector.text.contains("R$\u00a02.000"), "detector travado em Ruínas: %s" % detector.text)
	_check(detector.disabled, "detector desabilitado nas Ruínas")

	# 3. Saldo baixo com o Campo aberto: bloqueio por saldo, sem cadeado.
	gs.load_snapshot(_snapshot(100, ["campo"]))
	await _wait(3)
	_check(detector.disabled, "detector desabilitado sem saldo")
	_check(not detector.text.contains("🔒"), "sem cadeado no saldo: %s" % detector.text)
	_check(detector.tooltip_text.begins_with("Saldo insuficiente"), "tooltip de saldo: %s" % detector.tooltip_text)

	# 4. Detector e mochila no nível 4 com as Ruínas: o nível 5 dos dois trava na Geleira (#49).
	var levels_4: Dictionary = {"detector": 4, "backpack": 4}
	gs.load_snapshot(_snapshot(100000, ["campo", "ruinas"], levels_4))
	await _wait(3)
	_check(detector.text.contains("🔒 Requer Geleira Eterna") and detector.text.contains("R$ 12.000"), "detector travado na Geleira: %s" % detector.text)
	_check(detector.disabled, "detector desabilitado na Geleira")
	_check(detector.tooltip_text == "Desbloqueie Geleira Eterna primeiro.", "tooltip detector Geleira: %s" % detector.tooltip_text)
	_check(backpack.text.contains("🔒 Requer Geleira Eterna") and backpack.text.contains("R$ 6.000"), "mochila travada na Geleira: %s" % backpack.text)
	_check(backpack.disabled, "mochila desabilitada na Geleira")

	# 5. Com a Geleira aberta, o detector Nv.5 libera.
	gs.load_snapshot(_snapshot(100000, ["campo", "ruinas", "geleira"], levels_4))
	await _wait(3)
	_check(not detector.disabled, "detector habilitado com a Geleira: %s" % detector.tooltip_text)
	_check(not detector.text.contains("🔒"), "detector sem cadeado com a Geleira: %s" % detector.text)

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
