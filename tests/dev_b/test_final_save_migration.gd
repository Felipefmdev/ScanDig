extends GutTest

## Final no gold_colossus (#115): saves antigos "concluídos" pelo the_sleeper deixam de estar
## concluídos (sem ★ no slot), o bool gravado não conta, e carregar um save nunca abre a
## VictoryScreen. Saves em user://test_saves/devb_final.

const DIR: String = "user://test_saves/devb_final"

var _orig_path: String = ""


func before_all() -> void:
	_orig_path = SaveManager.instance.save_path


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file_name])
	SaveManager.instance.set_save_path(DIR + "/scandig_save.json")
	GameState.instance.reset_state()


func after_each() -> void:
	if VictoryScreen.instance != null:
		VictoryScreen.instance.close()
	GameState.instance.reset_state()


func after_all() -> void:
	SaveManager.instance.set_save_path(_orig_path)


func _old_save(bosses: Array, completed: bool) -> Dictionary:
	return {"version": SaveManager.SAVE_VERSION, "saved_at": 1760000000, "team_money": 900, "current_day": 30,
		"discovered_items": [], "unlocked_maps": ["campo", "ruinas", "geleira", "cratera"],
		"defeated_bosses": bosses, "game_completed": completed}


func _write(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func test_upgrade_ignores_stored_bool() -> void:
	var save: SaveManager = SaveManager.instance
	var old: Dictionary = save._upgrade_save_data(_old_save(["king_crab", "the_sleeper"], true))
	assert_false(old["game_completed"], "the_sleeper + game_completed=true gravado: não concluído")
	var won: Dictionary = save._upgrade_save_data(_old_save(["king_crab", "gold_colossus"], false))
	assert_true(won["game_completed"], "venceu o colosso: concluído (mesmo com false gravado)")


func test_slot_summary_star_follows_final_boss() -> void:
	var save: SaveManager = SaveManager.instance
	_write(save.slot_path(1), _old_save(["the_sleeper"], true))
	_write(save.slot_path(2), _old_save(["the_sleeper", "gold_colossus"], true))
	assert_false(bool(save.get_slot_summary(1)["game_completed"]), "slot antigo do the_sleeper: sem ★")
	assert_true(bool(save.get_slot_summary(2)["game_completed"]), "slot que venceu o colosso: ★")
	assert_false(TitleScreen._slot_line(save.get_slot_summary(1)).contains("★"))
	assert_true(TitleScreen._slot_line(save.get_slot_summary(2)).contains("★"))


func test_apply_snapshot_derives_completion() -> void:
	var gs: GameState = GameState.instance
	var data: Dictionary = gs.get_snapshot()
	data["game_completed"] = true
	data["defeated_bosses"] = ["the_sleeper"]
	gs.apply_snapshot(data)
	assert_false(gs.is_game_completed(), "o bool do dicionário não conta")
	data["defeated_bosses"] = ["the_sleeper", "gold_colossus"]
	gs.apply_snapshot(data)
	assert_true(gs.is_game_completed())


func test_loading_old_completed_save_does_not_open_victory() -> void:
	var save: SaveManager = SaveManager.instance
	var gs: GameState = GameState.instance
	_write(save.slot_path(1), _old_save(["king_crab", "the_sleeper"], true))
	watch_signals(gs)
	assert_eq(save.select_slot(1), OK)
	assert_eq(save.continue_game(), OK)
	assert_true(gs.defeated_bosses.has("the_sleeper"), "carregou o save antigo")
	assert_false(gs.is_game_completed(), "não está concluído")
	assert_signal_not_emitted(gs, "game_completed_changed", "false -> false: nada muda")
	assert_signal_not_emitted(gs, "game_victory")
	assert_false(VictoryScreen.is_open(), "carregar nunca abre a tela de vitória")


func test_loading_colossus_save_is_completed_without_victory_screen() -> void:
	var save: SaveManager = SaveManager.instance
	var gs: GameState = GameState.instance
	_write(save.slot_path(2), _old_save(["gold_colossus"], false))
	watch_signals(gs)
	assert_eq(save.select_slot(2), OK)
	assert_eq(save.continue_game(), OK)
	assert_true(gs.is_game_completed(), "venceu o colosso: concluído")
	assert_signal_emitted_with_parameters(gs, "game_completed_changed", [true])
	assert_signal_not_emitted(gs, "game_victory", "estado, não vitória ao vivo")
	assert_false(VictoryScreen.is_open())
