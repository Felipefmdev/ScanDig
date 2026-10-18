extends GutTest

## Loja em linhas (#119): cada melhoria tem ícone, nome, pips de nível (cheios = nível atual) e
## o botão Comprar com o preço à direita, desabilitado sem saldo; o painel do lobby usa UiChip.

const BASE_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")


func before_each() -> void:
	SaveManager.instance.use_test_save_dir("devb_shop_rows")
	GameState.instance.reset_state()


func after_each() -> void:
	GameState.instance.reset_state()


func _base() -> BaseStationUI:
	var ui: BaseStationUI = BASE_SCENE.instantiate() as BaseStationUI
	add_child_autofree(ui)
	return ui


func test_rows_have_icon_pips_and_buy_button_on_the_right() -> void:
	GameState.instance.load_snapshot({"team_money": 100000, "upgrade_levels": {"detector": 2}})
	var ui: BaseStationUI = _base()
	ui._refresh_shop_buttons()
	for upgrade_id: String in BaseStationUI.SHOP_BUTTONS:
		var row: Dictionary = ui._shop_rows[upgrade_id]
		var row_box: Control = row["row"] as Control
		var btn: Button = ui._get_shop_button(upgrade_id)
		assert_true(row_box.is_ancestor_of(btn), "%s: botão dentro da linha" % upgrade_id)
		assert_eq(btn.get_index(), btn.get_parent().get_child_count() - 1, "%s: botão à direita" % upgrade_id)
		assert_not_null((row_box.find_child("Icon", true, false) as TextureRect).texture, "%s: ícone" % upgrade_id)
		var pips: HBoxContainer = row["pips"] as HBoxContainer
		assert_eq(pips.get_child_count(), GameState.instance.get_upgrade_max_level(upgrade_id), "%s: um pip por nível" % upgrade_id)
	var det_pips: HBoxContainer = ui._shop_rows["detector"]["pips"] as HBoxContainer
	var filled: int = 0
	for pip: Node in det_pips.get_children():
		if ((pip as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color == UiPalette.ORANGE:
			filled += 1
	assert_eq(filled, 2, "pips cheios = nível 2")
	assert_eq(ui.buy_detector_btn.text, "Comprar\n" + UiFormat.money(GameState.instance.get_next_upgrade_cost("detector")))
	assert_false(ui.buy_detector_btn.disabled)
	assert_eq((ui._shop_rows["detector"]["name"] as Label).text, GameState.UPGRADES["detector"]["name"])


func test_buy_button_disabled_without_money() -> void:
	GameState.instance.load_snapshot({"team_money": 0})
	var ui: BaseStationUI = _base()
	ui._refresh_shop_buttons()
	assert_true(ui.buy_shovel_btn.disabled, "sem saldo: cinza")
	assert_string_contains(ui.buy_shovel_btn.text, UiFormat.money(GameState.instance.get_next_upgrade_cost("shovel")), "o preço continua visível")


func test_lobby_panel_uses_chips() -> void:
	GameState.instance.load_snapshot({"team_money": 777})
	var hud: HUD = HUD_SCENE.instantiate() as HUD
	add_child_autofree(hud)
	for chip_name: String in ["MoneyChip", "DetectorChip", "MuseumChip"]:
		var chip: UiChip = hud.get_node("%" + chip_name) as UiChip
		assert_not_null(chip, chip_name)
		if chip != null:
			assert_not_null(chip.icon_rect.texture, "%s com ícone" % chip_name)
	assert_eq(hud.money_label.text, "Dinheiro  " + UiFormat.money(777))
	assert_string_contains(hud.detector_label.text, "Detector")
	assert_string_contains(hud.museum_label.text, "Museu")
