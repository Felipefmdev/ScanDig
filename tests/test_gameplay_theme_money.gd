extends GutTest

## Testes para a Issue #52: Theme da UI nos HUDs de gameplay e formatação MoneyFormat.money

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const SCANDIG_THEME: Theme = preload("res://ui/theme/scandig_theme.tres")
const KING_CRAB_SCENE: PackedScene = preload("res://gameplay/enemies/boss/king_crab.tscn")
const GIANT_MOLE_SCENE: PackedScene = preload("res://gameplay/enemies/boss/giant_mole.tscn")


func test_player_hud_theme_and_variations() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var threat_panel: Control = player.get_node("HUD/ThreatPanel") as Control
	var health_panel: Control = player.get_node("HUD/HealthPanel") as Control
	var top_chips: Control = player.get_node("HUD/TopChips") as Control
	var session_label: Label = player.get_node("HUD/TopChips/MoneyChip/Box/Label") as Label
	var threat_title: Label = player.get_node("HUD/ThreatPanel/ThreatTitle") as Label
	var threat_bar: ProgressBar = player.get_node("HUD/ThreatPanel/ThreatBar") as ProgressBar
	var health_label: Label = player.get_node("HUD/HealthPanel/HealthLabel") as Label
	var health_bar: ProgressBar = player.get_node("HUD/HealthPanel/HealthBar") as ProgressBar
	var interact_prompt: Label = player.get_node("HUD/InteractPrompt") as Label
	var hotbar: Hotbar = player.get_node("HUD/Hotbar") as Hotbar

	assert_not_null(threat_panel.theme, "ThreatPanel deve ter theme definido")
	assert_not_null(health_panel.theme, "HealthPanel deve ter theme definido")
	assert_not_null(top_chips.theme, "TopChips (mochila e dinheiro) deve ter theme definido")
	assert_not_null(interact_prompt.theme, "InteractPrompt deve ter theme definido")
	assert_not_null(hotbar.theme, "Hotbar deve ter theme definido")

	assert_eq(threat_bar.theme_type_variation, &"ThreatBar", "ThreatBar deve usar variação ThreatBar")
	# #122: o trilho é o escuro translúcido do HUD sem cartão (PlayerHudStyle), legível na areia/neve.
	assert_true(threat_bar.get_theme_stylebox("background") is StyleBoxFlat and (threat_bar.get_theme_stylebox("background") as StyleBoxFlat).bg_color.is_equal_approx(PlayerHudStyle.TRACK_COLOR), "ThreatBar com o trilho do HUD")

	assert_eq(health_bar.theme_type_variation, &"", "HealthBar deve usar ProgressBar padrão")
	assert_true(health_bar.get_theme_stylebox("background") is StyleBoxFlat and (health_bar.get_theme_stylebox("background") as StyleBoxFlat).bg_color.is_equal_approx(PlayerHudStyle.TRACK_COLOR), "HealthBar com o trilho do HUD")
	assert_false(health_bar.has_theme_stylebox_override("fill"), "HealthBar não deve ter override de fill")

	assert_true(session_label.get_theme_color("font_outline_color").is_equal_approx(UiPalette.INK), "SessionInfoLabel deve usar contorno INK")
	assert_true(threat_title.get_theme_color("font_outline_color").is_equal_approx(UiPalette.INK), "ThreatTitle deve usar contorno INK")
	assert_true(health_label.get_theme_color("font_outline_color").is_equal_approx(UiPalette.INK), "HealthLabel deve usar contorno INK")
	assert_true(interact_prompt.get_theme_color("font_outline_color").is_equal_approx(UiPalette.INK), "InteractPrompt deve usar contorno INK")


func test_boss_huds_theme_and_variation() -> void:
	var crab: Node = KING_CRAB_SCENE.instantiate()
	add_child_autofree(crab)
	var crab_panel: Control = crab.get_node("BossHud/Panel") as Control
	var crab_bar: ProgressBar = crab.get_node("BossHud/Panel/HealthBar") as ProgressBar
	var crab_name: Label = crab.get_node("BossHud/Panel/Name") as Label

	assert_not_null(crab_panel.theme, "KingCrab BossHud Panel deve ter theme")
	assert_eq(crab_bar.theme_type_variation, &"BossBar", "KingCrab HealthBar deve usar BossBar")
	assert_true(crab_name.get_theme_color("font_outline_color").is_equal_approx(UiPalette.INK), "KingCrab Name deve ter contorno INK")

	var mole: Node = GIANT_MOLE_SCENE.instantiate()
	add_child_autofree(mole)
	var mole_panel: Control = mole.get_node("BossHud/Panel") as Control
	var mole_bar: ProgressBar = mole.get_node("BossHud/Panel/HealthBar") as ProgressBar
	assert_not_null(mole_panel.theme, "GiantMole BossHud Panel deve ter theme")
	assert_eq(mole_bar.theme_type_variation, &"BossBar", "GiantMole HealthBar deve usar BossBar")

	var dynamic_hud: BossHud = BossHud.create("Polvo", 400.0, Color.BLUE)
	add_child_autofree(dynamic_hud)
	assert_eq(dynamic_hud.bar.theme_type_variation, &"BossBar", "BossHud.create deve configurar BossBar")
	var dyn_panel: Control = dynamic_hud.get_child(0) as Control
	assert_not_null(dyn_panel.theme, "BossHud.create deve aplicar scandig_theme no painel")


func test_wave_event_hud_theme() -> void:
	var wave: WaveEvent = WaveEvent.new()
	add_child_autofree(wave)
	wave.event_name = "Defesa do Farol"
	wave._build_hud()

	var hud: CanvasLayer = wave.get_node("WaveHud") as CanvasLayer
	assert_not_null(hud, "WaveHud deve existir")
	var box: Control = hud.get_child(0) as Control
	assert_not_null(box.theme, "WaveHud Box deve ter theme")
	assert_eq(wave._hud_defend.theme_type_variation, &"ThreatBar", "Barra de defesa da wave usa ThreatBar")
	assert_true(wave._hud_title.get_theme_color("font_outline_color").is_equal_approx(UiPalette.INK), "WaveHud Title contorno INK")
	assert_true(wave._hud_round.get_theme_color("font_outline_color").is_equal_approx(UiPalette.INK), "WaveHud Round contorno INK")


func test_shop_offer_money_format_and_ink_outline() -> void:
	var offer: ShopOffer = ShopOffer.new()
	var tool_data: ToolData = ToolData.new()
	tool_data.id = &"test_tool"
	tool_data.display_name = "Picareta"
	tool_data.price = 1500
	offer.tool_data = tool_data
	add_child_autofree(offer)

	var label: Label3D = null
	for c: Node in offer.get_children():
		if c is Label3D:
			label = c as Label3D
			break
	assert_not_null(label, "ShopOffer deve criar Label3D")
	assert_true(label.text.contains(MoneyFormat.money(1500)), "Texto da banca deve conter MoneyFormat.money: " + label.text)
	assert_false(label.text.contains("R$ 1500"), "Não deve conter formatação manual sem milhar")
	assert_true(label.outline_modulate.is_equal_approx(UiPalette.INK), "Label3D deve ter contorno INK")

	var prompt: String = offer.get_prompt()
	assert_true(prompt.contains(MoneyFormat.money(1500)), "Prompt de compra deve usar MoneyFormat: " + prompt)


func test_hotbar_money_format_and_ink_outline() -> void:
	var hotbar: Hotbar = Hotbar.new()
	var inv: Inventory = Inventory.new()
	inv.capacity = 3
	add_child_autofree(inv)
	add_child_autofree(hotbar)
	hotbar.bind(inv)

	var item: ItemData = ItemData.new()
	item.id = "moeda_ouro"
	item.display_name = "Moeda Antiga"
	item.base_value = 1200
	var carried: CarriedItem = CarriedItem.create(item, 1200, 1.0, false)
	inv.add_item(carried)

	var slot0: PanelContainer = hotbar._slot_panels[0]
	var val_label: Label = slot0.get_node("Box/Value") as Label
	assert_eq(val_label.text, MoneyFormat.money(1200), "Valor do slot na hotbar deve usar MoneyFormat.money")
	assert_true(val_label.get_theme_color("font_outline_color").is_equal_approx(UiPalette.INK), "Valor do slot deve ter contorno INK")


func test_player_messages_money_format() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	if GameState.instance != null:
		GameState.instance.team_money = 5400
	else:
		player.session_money = 5400
	player._update_session_hud()
	assert_true(player.session_info_label.text.contains(MoneyFormat.money(5400)), "SessionInfoLabel deve formatar com MoneyFormat: " + player.session_info_label.text)
	assert_false(player.session_info_label.text.contains("R$ 5400"), "Não deve conter formatação manual sem milhar")
