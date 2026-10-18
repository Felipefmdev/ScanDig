extends GutTest

## Testes da Issue #81: Final do jogo (salvar 'jogo concluído' e Modo Museu completo).

const BASE_STATION_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")


func before_each() -> void:
	if GameState.instance != null:
		GameState.instance.reset_state()


func test_game_completed_initial_and_reset() -> void:
	var gs: GameState = GameState.instance
	assert_not_null(gs, "GameState presente")
	assert_false(gs.is_game_completed(), "inicialmente falso")
	gs.game_completed = true
	assert_true(gs.is_game_completed(), "marcado como true")
	gs.reset_state()
	assert_false(gs.is_game_completed(), "reset_state limpa para false")


func test_defeating_sleeper_marks_game_completed() -> void:
	var gs: GameState = GameState.instance
	assert_not_null(gs)
	watch_signals(gs)
	gs._host_report_boss_defeated(GameState.FINAL_BOSS_ID)
	assert_true(gs.is_game_completed(), "derrotar o chefe final (gold_colossus, #115) marca game_completed")
	assert_signal_emitted_with_parameters(gs, "game_completed_changed", [true])


func test_snapshot_roundtrip_preserves_game_completed() -> void:
	var gs: GameState = GameState.instance
	assert_not_null(gs)
	gs.defeated_bosses = [GameState.FINAL_BOSS_ID]  # #115: concluído = venceu o chefe final
	gs.game_completed = true
	var snapshot: Dictionary = gs.get_snapshot()
	assert_true(snapshot.has("game_completed"), "snapshot possui chave game_completed")
	assert_true(snapshot["game_completed"], "snapshot game_completed é true")

	gs.game_completed = false
	gs.apply_snapshot(snapshot)
	assert_true(gs.is_game_completed(), "apply_snapshot restaura game_completed")


func test_save_manager_saves_and_loads_game_completed() -> void:
	var sm: SaveManager = SaveManager.instance
	var gs: GameState = GameState.instance
	assert_not_null(sm)
	assert_not_null(gs)

	sm.use_test_save_dir("game_completion_test")
	gs.game_completed = true
	gs.defeated_bosses = [GameState.FINAL_BOSS_ID]
	var err: Error = sm.save_game()
	assert_eq(err, OK, "salvou com sucesso")

	var summary: Dictionary = sm.get_save_summary()
	assert_true(summary.has("game_completed"), "resumo do save expõe game_completed")
	assert_true(summary["game_completed"], "resumo indica game_completed = true")

	gs.reset_state()
	assert_false(gs.is_game_completed(), "resetado para false")
	err = sm.load_game()
	assert_eq(err, OK, "carregou save")
	assert_true(gs.is_game_completed(), "carregamento restaurou game_completed")


func test_save_migration_infers_game_completed_from_final_boss() -> void:
	var sm: SaveManager = SaveManager.instance
	assert_not_null(sm)

	# Save sem game_completed, mas com o chefe final (#115) nos chefes derrotados:
	var legacy_complete: Dictionary = {
		"version": 4,
		"team_money": 5000,
		"current_day": 10,
		"discovered_items": [],
		"upgrade_levels": {},
		"unlocked_maps": ["cratera"],
		"defeated_bosses": ["king_crab", GameState.FINAL_BOSS_ID],
	}
	var upgraded_complete: Dictionary = sm._upgrade_save_data(legacy_complete)
	assert_true(upgraded_complete.has("game_completed"), "migração adiciona game_completed")
	assert_true(upgraded_complete["game_completed"], "chefe final em defeated_bosses infere true")

	# Save sem game_completed e sem o chefe final:
	var legacy_incomplete: Dictionary = {
		"version": 4,
		"team_money": 200,
		"current_day": 2,
		"discovered_items": [],
		"upgrade_levels": {},
		"unlocked_maps": [],
		"defeated_bosses": ["king_crab"],
	}
	var upgraded_incomplete: Dictionary = sm._upgrade_save_data(legacy_incomplete)
	assert_false(upgraded_incomplete["game_completed"], "sem o chefe final infere false")


# #115: o overlay do CraterAltar saiu (VictoryScreen); ver tests/dev_b/test_crater_altar_no_overlay.gd.


func test_base_station_ui_reflects_game_completed() -> void:
	var gs: GameState = GameState.instance
	assert_not_null(gs)
	gs.game_completed = true

	var ui: BaseStationUI = BASE_STATION_SCENE.instantiate() as BaseStationUI
	add_child_autofree(ui)

	assert_string_contains(ui.secrets_label.text, "Jogo concluído", "secrets_label avisa jogo concluído")
	assert_string_contains(ui.secrets_label.text, "Modo Museu completo", "secrets_label menciona Modo Museu completo")
	assert_eq(ui.tab_container.get_tab_title(1), "Museu ★", "aba do museu exibe estrela de conclusão (rótulo curto)")
