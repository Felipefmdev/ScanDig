extends GutTest

## Testes unitários para a aba Diário de Campo na BaseStationUI (Issue #86)

const BASE_STATION_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")


func test_journal_tab_lists_all_13_creatures_and_worn_panel_slots() -> void:
	var gs: GameState = GameState.instance
	assert_not_null(gs)
	var prev_seen: Array[String] = gs.seen_creatures.duplicate()
	var prev_bosses: Array[String] = gs.defeated_bosses.duplicate()
	gs.seen_creatures.clear()
	gs.defeated_bosses.clear()

	var ui: BaseStationUI = BASE_STATION_SCENE.instantiate() as BaseStationUI
	add_child_autofree(ui)

	assert_eq(ui.tab_container.get_tab_count(), 6, "BaseStationUI deve ter 6 abas (Diário e Mapa do Tesouro, #112; Conquistas, #141)")
	assert_eq(ui.tab_container.get_tab_title(3), "Diário", "4ª aba deve chamar-se Diário")
	assert_eq(ui.get_journal_creature_count(), GameState.CREATURES.size(), "Deve listar as 13 criaturas")

	# Todas por descobrir inicialmente -> mostram '???' e usam WornPanel + MiniIcon
	for child in ui.journal_grid.get_children():
		var card := child as PanelContainer
		assert_not_null(card)
		assert_eq(card.theme_type_variation, &"WornPanel", "Cada slot do diário deve usar WornPanel")
		var icon := card.find_child("MiniIcon", true, false) as TextureRect
		assert_not_null(icon, "Cada slot deve ter miniatura MiniIcon")
		assert_not_null(icon.texture, "MiniIcon deve ter textura gerada")

	assert_string_contains(ui.get_journal_slot_text("crab"), "???", "Criatura não vista mostra ???")
	assert_string_contains(ui.get_boss_slot_text("king_crab"), "???", "Chefe não vencido mostra ???")

	# Ao descobrir criaturas e vencer chefes, o diário atualiza com nome e miniatura
	gs.seen_creatures.append("crab")
	gs.seen_creatures.append("bat")
	gs.defeated_bosses.append("king_crab")
	gs.creature_discovered.emit("crab")

	assert_string_contains(ui.get_journal_slot_text("crab"), "Caranguejo", "Criatura avistada mostra o nome")
	assert_string_contains(ui.get_journal_slot_text("bat"), "Morcego", "Segunda criatura avistada mostra o nome")
	assert_string_contains(ui.get_journal_slot_text("floater"), "???", "Criatura ainda não avistada mantém ???")
	assert_string_contains(ui.get_boss_slot_text("king_crab"), "Caranguejo-Rei", "Chefe vencido mostra o nome")
	assert_string_contains(ui.journal_info_label.text, "2/13", "Cabeçalho do diário mostra contagem 2/13")

	gs.seen_creatures = prev_seen
	gs.defeated_bosses = prev_bosses
