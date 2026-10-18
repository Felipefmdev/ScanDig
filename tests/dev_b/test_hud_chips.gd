extends GutTest

## HUD do topo com chips (#119): mochila e dinheiro viram dois UiChip com ícone; a barra de
## Ameaça e o painel de vida/fome ganham moldura de papel (irmã atrás do painel, seguindo o
## retângulo) e ícones no lugar dos emojis.

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


func test_threat_and_health_have_frames_and_icons() -> void:
	var player: Player = _player()
	await get_tree().process_frame
	for panel_name: String in ["ThreatPanel", "HealthPanel"]:
		var panel: Control = player.get_node("HUD/" + panel_name) as Control
		var frame: Panel = player.get_node_or_null("HUD/%sFrame" % panel_name) as Panel
		assert_not_null(frame, "moldura de %s" % panel_name)
		if frame == null:
			continue
		assert_lt(frame.get_index(), panel.get_index(), "moldura desenhada atrás")
		assert_true(frame.get_rect().encloses(panel.get_rect()), "moldura envolve %s" % panel_name)
		assert_eq(frame.visible, panel.visible, "segue a visibilidade")
	for path: String in ["HUD/ThreatPanel/ThreatTitle", "HUD/HealthPanel/HealthLabel", "HUD/HealthPanel/HungerLabel"]:
		var label: Label = player.get_node(path) as Label
		var icon: TextureRect = label.get_node_or_null(^"Icon") as TextureRect
		assert_true(icon != null and icon.texture != null, "ícone em %s" % path)
	var health: Label = player.get_node("HUD/HealthPanel/HealthLabel") as Label
	assert_false(health.text.contains("❤"), "vida sem emoji: %s" % health.text)
	assert_string_contains(health.text, "%d/%d" % [int(player.health), int(player.max_health)])


func test_frame_follows_panel_rect() -> void:
	var holder: Control = Control.new()
	add_child_autofree(holder)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = "Box"
	holder.add_child(panel)
	var frame: Panel = PlayerHudStyle.add_frame(panel)
	panel.position = Vector2(40, 30)
	panel.size = Vector2(100, 50)
	assert_eq(frame.position, Vector2(40, 30) - PlayerHudStyle.FRAME_MARGIN)
	assert_eq(frame.size, Vector2(100, 50) + PlayerHudStyle.FRAME_MARGIN * 2.0)
	panel.visible = false
	assert_false(frame.visible)
	assert_eq(PlayerHudStyle.add_frame(panel), frame, "não duplica")
