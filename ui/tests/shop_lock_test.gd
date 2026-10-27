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

## Custos e mapas de trava vêm de GameState.UPGRADES (#64): o teste confere regras, não preços.
func _cost(upgrade_id: String, level: int) -> String:
	return UiFormat.money(int(GameState.UPGRADES[upgrade_id]["costs"][level]))

func _lock_name(upgrade_id: String, level: int) -> String:
	var map_id: String = str(GameState.UPGRADES[upgrade_id]["required_maps"][level])
	return (load("res://items/maps/%s.tres" % map_id) as MapData).display_name

## Linha da Loja (#119): nome, nível/detalhe e o botão Comprar com o preço.
func _row(ui: BaseStationUI, upgrade_id: String) -> String:
	var row: Dictionary = ui._shop_rows[upgrade_id]
	return "%s | %s | %s" % [(row["name"] as Label).text, (row["detail"] as Label).text, ui._get_shop_button(upgrade_id).text]

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
	_check(not _row(ui, "detector").contains("🔒"), "detector sem cadeado: %s" % _row(ui, "detector"))
	_check(detector.text == "Comprar\n" + _cost("detector", 2) and _row(ui, "detector").contains("Nível 2/") and _row(ui, "detector").contains("radar Nv.3"), "detector compra 3: %s" % _row(ui, "detector"))
	_check(detector.tooltip_text == "Radar: Nv.3 → Nv.4", "tooltip radar: %s" % detector.tooltip_text)
	_check(_row(ui, "backpack").contains("🔒 Requer " + _lock_name("backpack", 2)), "mochila travada: %s" % _row(ui, "backpack"))
	_check(backpack.disabled, "mochila desabilitada")
	_check(backpack.tooltip_text == "Desbloqueie %s primeiro." % _lock_name("backpack", 2), "tooltip mochila: %s" % backpack.tooltip_text)
	_check(not shovel.disabled and shovel.text == "Comprar\n" + _cost("shovel", 0), "pá liberada: %s" % _row(ui, "shovel"))

	# 2. A aba antiga não compra; snapshot do nível 3 exibe a trava das Ruínas.
	detector.pressed.emit()
	await _wait(5)
	_check(gs.get_upgrade_level("detector") == 2 and gs.team_money == 100000, "Loja oculta não autoriza compra remota")
	gs.load_snapshot(_snapshot(100000, [], {"detector": 3, "backpack": 2}))
	await _wait(3)
	_check(gs.get_upgrade_level("detector") == 3, "detector nível 3: %d" % gs.get_upgrade_level("detector"))
	_check(_row(ui, "detector").contains("🔒 Requer " + _lock_name("detector", 3)) and _row(ui, "detector").contains(_cost("detector", 3)), "detector travado em Ruínas: %s" % _row(ui, "detector"))
	_check(detector.disabled, "detector desabilitado nas Ruínas")

	# 3. Saldo baixo com o Campo aberto: bloqueio por saldo, sem cadeado.
	gs.load_snapshot(_snapshot(100, ["campo"]))
	await _wait(3)
	_check(detector.disabled, "detector desabilitado sem saldo")
	_check(not _row(ui, "detector").contains("🔒"), "sem cadeado no saldo: %s" % _row(ui, "detector"))
	_check(detector.tooltip_text.begins_with("Saldo insuficiente"), "tooltip de saldo: %s" % detector.tooltip_text)

	# 4. Detector e mochila no nível 4 com as Ruínas: o nível 5 dos dois trava na Geleira (#49).
	var levels_4: Dictionary = {"detector": 4, "backpack": 4}
	gs.load_snapshot(_snapshot(100000, ["campo", "ruinas"], levels_4))
	await _wait(3)
	_check(_row(ui, "detector").contains("🔒 Requer " + _lock_name("detector", 4)) and _row(ui, "detector").contains(_cost("detector", 4)), "detector travado na Geleira: %s" % _row(ui, "detector"))
	_check(detector.disabled, "detector desabilitado na Geleira")
	_check(detector.tooltip_text == "Desbloqueie %s primeiro." % _lock_name("detector", 4), "tooltip detector Geleira: %s" % detector.tooltip_text)
	_check(_row(ui, "backpack").contains("🔒 Requer " + _lock_name("backpack", 4)) and _row(ui, "backpack").contains(_cost("backpack", 4)), "mochila travada na Geleira: %s" % _row(ui, "backpack"))
	_check(backpack.disabled, "mochila desabilitada na Geleira")

	# 5. Com a Geleira aberta, o detector Nv.5 libera.
	gs.load_snapshot(_snapshot(100000, ["campo", "ruinas", "geleira"], levels_4))
	await _wait(3)
	_check(not detector.disabled, "detector habilitado com a Geleira: %s" % detector.tooltip_text)
	_check(not _row(ui, "detector").contains("🔒"), "detector sem cadeado com a Geleira: %s" % _row(ui, "detector"))

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
