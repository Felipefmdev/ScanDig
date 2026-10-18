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
	assert_true(ui.buy_shovel_btn.disabled, "sem saldo: desativado")
	assert_string_contains(ui.buy_shovel_btn.text, UiFormat.money(GameState.instance.get_next_upgrade_cost("shovel")), "o preço continua visível")


## #122 (E6): sem saldo é um estado claro (papel claro, "Sem saldo" e preço em RED_BURNT), não o
## bege apagado; com saldo volta ao PrimaryButton; máximo em verde.
func test_no_money_state_is_explicit() -> void:
	GameState.instance.load_snapshot({"team_money": 0, "upgrade_levels": {"backpack": 5}})
	var ui: BaseStationUI = _base()
	ui._refresh_shop_buttons()
	var btn: Button = ui.buy_shovel_btn
	assert_true(btn.text.begins_with(BaseStationUI.SHOP_NO_MONEY_TEXT + "
"), "texto: %s" % btn.text)
	assert_eq(btn.get_theme_color(&"font_disabled_color"), UiPalette.RED_BURNT, "preço em vermelho")
	var style: StyleBoxFlat = btn.get_theme_stylebox(&"disabled") as StyleBoxFlat
	assert_true(style != null and style.bg_color == UiPalette.PAPER_LIGHT and style.border_color == UiPalette.RED_BURNT, "papel claro com borda vermelha")
	assert_eq(ui.buy_backpack_btn.get_theme_color(&"font_disabled_color"), UiPalette.GREEN_BOTTLE, "máximo em verde")
	GameState.instance.load_snapshot({"team_money": 100000})
	ui._refresh_shop_buttons()
	assert_false(btn.disabled)
	assert_true(btn.text.begins_with("Comprar
"))
	assert_false(btn.has_theme_stylebox_override(&"disabled"), "comprável: volta ao theme")


## #122 (E6): sem o vazio embaixo da lista (a altura vem da aba atual) e a borda de foco só fora
## do mouse.
func test_shop_height_by_content_and_focus_only_with_keyboard() -> void:
	InputDevice.instance.set_using_pointer(true)
	var ui: BaseStationUI = _base()
	ui.tab_container.current_tab = 0
	await wait_frames(4)
	var scroll: ScrollContainer = ui.tab_container.get_tab_control(0) as ScrollContainer
	var content_h: float = ui.get_page(0).get_combined_minimum_size().y
	assert_almost_eq(scroll.custom_minimum_size.y, content_h, 1.0, "altura da Loja = conteúdo")
	ui.tab_container.current_tab = 1
	await wait_frames(4)
	assert_almost_eq(scroll.custom_minimum_size.y, ui.get_page(1).get_combined_minimum_size().y, 1.0, "outra aba: altura dela")
	var btn: Button = ui.buy_detector_btn
	assert_eq(btn.get_theme_stylebox(&"focus").get_class(), "StyleBoxEmpty", "mouse: sem borda de foco")
	InputDevice.instance.set_using_pointer(false)
	assert_ne(btn.get_theme_stylebox(&"focus").get_class(), "StyleBoxEmpty", "teclado: borda de foco")
	InputDevice.instance.set_using_pointer(true)


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


## #122 (E7): rótulos 3D das bancas com altura alternada entre vizinhos e abaixo da placa.
func test_stall_labels_alternate_height() -> void:
	var stall: Node3D = Node3D.new()
	add_child_autofree(stall)
	var labels: Array[Label3D] = []
	for id: String in ["estilingue", "repelente", "armadilha_rede"]:
		var offer: ShopOffer = ShopOffer.new()
		offer.tool_data = load("res://items/tools/%s.tres" % id) as ToolData
		stall.add_child(offer)
		labels.append(offer.find_children("*", "Label3D", false, false)[0] as Label3D)
	assert_eq(labels[0].position.y, labels[2].position.y, "alternados: 1º e 3º na mesma altura")
	assert_almost_eq(labels[1].position.y - labels[0].position.y, ShopOffer.LABEL_STAGGER, 0.001, "2º mais alto")
	assert_almost_eq(labels[0].pixel_size, ShopOffer.LABEL_PIXEL_SIZE, 0.00001)
	assert_lt(0.54 + labels[1].position.y + 2.0 * 1.3 * labels[1].font_size * labels[1].pixel_size, 2.1 - 0.15, "abaixo da placa LOJA")
