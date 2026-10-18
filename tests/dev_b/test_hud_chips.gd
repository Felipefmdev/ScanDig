extends GutTest

## HUD do topo com chips (#119): mochila e dinheiro viram dois UiChip com ícone (discretos no
## jogo, #122); a barra de Ameaça e o painel de vida/fome ficam sem cartão, com ícones no lugar
## dos emojis e texto contornado (#122).

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")


func _player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	return player


func test_top_chips_show_bag_and_team_money() -> void:
	var player: Player = _player()
	var bag: UiChip = player.get_node("HUD/TopChips/BagChip") as UiChip
	var money: UiChip = player.get_node("HUD/TopChips/MoneyChip") as UiChip
	assert_not_null(bag, "chip da mochila")
	assert_not_null(money, "chip do dinheiro")
	assert_eq(bag.icon_name, "backpack")
	assert_eq(money.icon_name, "coin")
	assert_not_null(bag.icon_rect.texture, "ícone da mochila rasterizado")
	assert_eq(player.session_info_label, money.label, "session_info_label é o texto do chip do dinheiro")
	GameState.instance.load_snapshot({"team_money": 5400})
	player._update_session_hud()
	assert_eq(money.label.text, "Dinheiro  " + MoneyFormat.money(5400))
	assert_string_contains(bag.label.text, "%d/%d" % [player.inventory.get_count(), player.inventory.capacity])
	assert_false(money.label.text.contains("💰") or bag.label.text.contains("🎒"), "sem emojis")
	GameState.instance.reset_state()


func test_threat_and_health_have_no_card_and_outlined_text() -> void:
	# #122 (E3): sem cartão/moldura atrás; ícone + texto claro com contorno e sombra + trilho escuro.
	var player: Player = _player()
	await get_tree().process_frame
	for panel_name: String in ["ThreatPanel", "HealthPanel"]:
		assert_null(player.get_node_or_null("HUD/%sFrame" % panel_name), "sem moldura em %s" % panel_name)
	for path: String in ["HUD/ThreatPanel/ThreatTitle", "HUD/HealthPanel/HealthLabel", "HUD/HealthPanel/HungerLabel"]:
		var label: Label = player.get_node(path) as Label
		var icon: TextureRect = label.get_node_or_null(^"Icon") as TextureRect
		assert_true(icon != null and icon.texture != null, "ícone em %s" % path)
		assert_eq(label.get_theme_color(&"font_color"), UiPalette.PAPER_LIGHT, "texto claro em %s" % path)
		assert_eq(label.get_theme_constant(&"outline_size"), PlayerHudStyle.OUTLINE_SIZE, "contorno em %s" % path)
		assert_gt(label.get_theme_constant(&"shadow_offset_y"), 0, "sombra em %s" % path)
	for path: String in ["HUD/ThreatPanel/ThreatBar", "HUD/HealthPanel/HealthBar", "HUD/HealthPanel/HungerBar"]:
		var track: StyleBoxFlat = (player.get_node(path) as ProgressBar).get_theme_stylebox(&"background") as StyleBoxFlat
		assert_true(track != null and track.bg_color.is_equal_approx(PlayerHudStyle.TRACK_COLOR), "trilho escuro em %s" % path)
	var bag: UiChip = player.get_node("HUD/TopChips/BagChip") as UiChip
	var chip_style: StyleBoxFlat = bag.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_true(chip_style.bg_color.a < 0.9 and chip_style.shadow_size == 0, "chips do topo discretos")
	var health: Label = player.get_node("HUD/HealthPanel/HealthLabel") as Label
	assert_false(health.text.contains("❤"), "vida sem emoji: %s" % health.text)
	assert_string_contains(health.text, "%d/%d" % [int(player.health), int(player.max_health)])

