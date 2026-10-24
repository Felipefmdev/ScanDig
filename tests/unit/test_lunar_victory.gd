extends GutTest

## Contrato literal do novo final; não usar FINAL_BOSS_ID como valor esperado.
const LUNAR: String = "lunar_warden"
const SLEEPER: String = "the_sleeper"
var gs: GameState
var save: SaveManager
var original_state: Dictionary
var original_save_path: String
var events: Array[String] = []
var applied: Array[Dictionary] = []
var victory_snapshots: Array[Dictionary] = []

func before_all() -> void:
	gs = GameState.instance
	save = SaveManager.instance
	original_save_path = save.save_path

func before_each() -> void:
	original_state = gs.get_snapshot().duplicate(true)
	# Só diretório de teste próprio; autosave existente da vitória também fica isolado.
	save.use_test_save_dir("lua120_victory_%d" % Time.get_ticks_usec())
	gs.reset_state()
	events.clear()
	applied.clear()
	victory_snapshots.clear()
	gs.state_synced.connect(_on_snapshot_applied)
	gs.game_victory.connect(_on_live_victory)
	watch_signals(gs)

func after_each() -> void:
	gs.state_synced.disconnect(_on_snapshot_applied)
	gs.game_victory.disconnect(_on_live_victory)
	# Limpa apenas efeitos existentes do sinal global; não testa ou altera VictoryUI.
	if VictoryScreen.instance != null: VictoryScreen.instance.close()
	gs.load_snapshot(original_state)
	await get_tree().process_frame
	await get_tree().process_frame

func after_all() -> void:
	save.set_save_path(original_save_path)

func _on_snapshot_applied() -> void:
	events.append("snapshot_applied")
	applied.append(gs.get_snapshot().duplicate(true))

func _on_live_victory() -> void:
	events.append("game_victory")
	victory_snapshots.append(gs.get_snapshot().duplicate(true))

func _legacy_progress(version: int = 6) -> Dictionary:
	var data: Dictionary = gs.get_snapshot().duplicate(true)
	data["version"] = version
	data["saved_at"] = 1760000000
	data["team_money"] = 4321
	data["current_day"] = 17
	data["discovered_items"] = ["alianca_ouro","moeda_antiga"]
	data["upgrade_levels"] = {"detector":5,"pinpointer":1,"shovel":1}
	data["unlocked_maps"] = ["campo","ruinas","geleira","cratera"]
	data["defeated_bosses"] = ["king_crab","giant_mole","ancient_guardian","frozen_mammoth",SLEEPER]
	data["completed_quests"] = ["vega_sinal","vega_foguete"]
	data["found_secrets"] = [GameState.SECRETS[0]]
	data["seen_creatures"] = ["crab","bat"]
	data["intact_items"] = ["alianca_ouro"]
	data["rare_items"] = ["moeda_antiga"]
	data["built_shortcuts"] = ["preserved_shortcut"]
	data["stats"] = {"items_found":12,"money_earned":900}
	data["achievements"] = ["first_find"]
	data["game_completed"] = true # Bool antigo não autoriza o novo final.
	return data

func _assert_progress_preserved(actual: Dictionary, expected: Dictionary) -> void:
	for key: String in ["team_money","current_day","discovered_items","unlocked_maps","defeated_bosses","completed_quests","found_secrets","seen_creatures","intact_items","rare_items","built_shortcuts","stats"]:
		if key=="team_money" or key=="current_day":
			# JSON representa números como float; o contrato desses campos é inteiro.
			assert_eq(int(actual[key]),int(expected[key]),"Preservar progresso legado: "+key)
		elif key == "stats":
			var actual_stats: Dictionary = actual[key]
			var expected_stats: Dictionary = expected[key]
			assert_eq(actual_stats.size(), expected_stats.size(), "Preservar todas as chaves stats")
			for stat_key: String in expected_stats:
				assert_true(actual_stats.has(stat_key), "Preservar chave stats: " + stat_key)
				if not actual_stats.has(stat_key): continue
				var actual_value: Variant = actual_stats[stat_key]
				var expected_value: Variant = expected_stats[stat_key]
				var actual_numeric: bool = actual_value is int or actual_value is float
				var expected_numeric: bool = expected_value is int or expected_value is float
				assert_true(actual_numeric, "Stats real numérico: " + stat_key)
				assert_true(expected_numeric, "Stats esperado numérico: " + stat_key)
				if actual_numeric and expected_numeric:
					assert_true(float(actual_value) == float(expected_value), "Preservar valor exato stats: " + stat_key)
		else:
			assert_eq(actual[key],expected[key],"Preservar progresso legado: "+key)
	var levels: Dictionary = actual["upgrade_levels"]
	var old_levels: Dictionary = expected["upgrade_levels"]
	for key: String in old_levels:
		assert_eq(int(levels.get(key,-1)),int(old_levels[key]),"Preservar upgrade: "+key)
	# load_snapshot pode conceder conquistas já cumpridas silenciosamente; não removê-las.
	for id: String in expected["achievements"]:
		assert_has(actual["achievements"],id)

func _write_save(data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(save.save_path,FileAccess.WRITE)
	assert_not_null(file,"Abrir somente save isolado lua120_victory")
	if file==null: return false
	file.store_string(JSON.stringify(data))
	file.close()
	save.set_save_path(save.save_path) # Mesmo caminho, agora arquivo ainda não aplicado.
	return true

func test_final_id_is_literal_lunar_warden_and_is_a_valid_boss() -> void:
	assert_eq(GameState.FINAL_BOSS_ID,LUNAR)
	assert_has(GameState.all_boss_ids(),LUNAR)
	assert_has(GameState.all_boss_ids(),SLEEPER,"Sleeper continua progresso válido")

func test_legitimate_host_sleeper_report_marks_progress_without_ending_campaign() -> void:
	assert_true(gs.is_authority())
	assert_eq(gs.multiplayer.get_unique_id(),1)
	gs.request_report_boss_defeated(SLEEPER)
	assert_true(gs.is_boss_defeated(SLEEPER))
	assert_eq(gs.defeated_bosses.count(SLEEPER),1)
	assert_false(gs.is_game_completed(),"Sleeper não conclui o novo final")
	assert_false(bool(gs.get_snapshot()["game_completed"]))
	assert_signal_not_emitted(gs,"game_victory")
	assert_true(victory_snapshots.is_empty())

func test_host_lunar_report_applies_mark_and_snapshot_before_one_live_victory() -> void:
	assert_true(gs.is_authority())
	assert_eq(gs.multiplayer.get_unique_id(),1)
	var money: int = gs.team_money
	var day: int = gs.current_day
	gs.request_report_boss_defeated(LUNAR)
	assert_true(gs.is_boss_defeated(LUNAR))
	assert_eq(gs.defeated_bosses.count(LUNAR),1)
	assert_true(gs.is_game_completed())
	assert_signal_emit_count(gs,"game_victory",1)
	assert_eq(gs.team_money,money)
	assert_eq(gs.current_day,day)
	assert_eq(victory_snapshots.size(),1)
	assert_false(applied.is_empty(),"Snapshot aplicado de verdade, não evento inventado")
	assert_has(events,"game_victory")
	if events.has("game_victory") and not applied.is_empty() and not victory_snapshots.is_empty():
		assert_lt(events.find("snapshot_applied"),events.find("game_victory"))
		assert_has(applied[0]["defeated_bosses"],LUNAR)
		assert_true(bool(applied[0]["game_completed"]))
		assert_has(victory_snapshots[0]["defeated_bosses"],LUNAR)
		assert_true(bool(victory_snapshots[0]["game_completed"]))
	var once: Dictionary = gs.get_snapshot().duplicate(true)
	var event_count: int = events.size()
	gs.request_report_boss_defeated(LUNAR)
	assert_eq(gs.get_snapshot(),once,"Report duplicado não reaplica progresso")
	assert_eq(events.size(),event_count,"Duplicado não aplica outro snapshot/vitória")
	assert_signal_emit_count(gs,"game_victory",1)

func test_loading_already_defeated_lunar_snapshot_is_state_not_live_victory() -> void:
	var data: Dictionary = gs.get_snapshot().duplicate(true)
	data["defeated_bosses"] = [LUNAR]
	data["game_completed"] = false
	gs.load_snapshot(data)
	assert_true(gs.is_boss_defeated(LUNAR))
	assert_true(gs.is_game_completed(),"Conclusão deriva do chefe lunar, não do bool gravado")
	assert_signal_emitted_with_parameters(gs,"game_completed_changed",[true])
	assert_signal_not_emitted(gs,"game_victory")
	gs.request_report_boss_defeated(LUNAR)
	assert_signal_not_emitted(gs,"game_victory","Derrota já carregada não vira vitória ao vivo")

func test_invalid_boss_ids_do_not_mutate_or_emit_victory() -> void:
	var before: Dictionary = gs.get_snapshot().duplicate(true)
	for id: String in ["","not_a_boss","../lunar_warden","LUNAR_WARDEN"]:
		gs.request_report_boss_defeated(id)
	assert_eq(gs.get_snapshot(),before)
	assert_signal_not_emitted(gs,"state_synced")
	assert_signal_not_emitted(gs,"game_victory")

func test_old_sleeper_completed_migration_recalculates_only_completion() -> void:
	for version: int in [5,6]:
		var legacy: Dictionary = _legacy_progress(version)
		var migrated: Dictionary = save._upgrade_save_data(legacy)
		assert_false(bool(migrated["game_completed"]),"Save v%d sem lunar não conclui novo final" % version)
		_assert_progress_preserved(migrated,legacy)
		assert_false((migrated["defeated_bosses"] as Array).has(LUNAR),"Migração não inventa derrota lunar")
	assert_signal_not_emitted(gs,"game_victory")

func test_legacy_sleeper_disk_load_save_load_preserves_other_progress_without_victory() -> void:
	var legacy: Dictionary = _legacy_progress(5)
	if not _write_save(legacy): return
	assert_eq(save.load_game(gs),OK)
	assert_false(gs.is_game_completed())
	assert_true(gs.is_boss_defeated(SLEEPER))
	assert_false(gs.is_boss_defeated(LUNAR))
	_assert_progress_preserved(gs.get_snapshot(),legacy)
	assert_signal_not_emitted(gs,"game_victory")
	assert_eq(save.save_game(gs),OK)
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save.save_path)) as Dictionary
	assert_eq(int(disk["version"]),SaveManager.SAVE_VERSION)
	assert_false(bool(disk["game_completed"]))
	_assert_progress_preserved(disk,legacy)
	gs.reset_state()
	assert_eq(save.load_game(gs),OK)
	assert_false(gs.is_game_completed())
	_assert_progress_preserved(gs.get_snapshot(),legacy)
	assert_signal_not_emitted(gs,"game_victory")

func test_loading_lunar_completed_disk_save_does_not_emit_live_victory() -> void:
	var data: Dictionary = _legacy_progress(6)
	data["defeated_bosses"] = [LUNAR]
	data["game_completed"] = false
	if not _write_save(data): return
	assert_eq(save.load_game(gs),OK)
	assert_true(gs.is_game_completed())
	assert_false(gs.is_boss_defeated(SLEEPER),"Load não inventa outras derrotas")
	assert_true(gs.is_boss_defeated(LUNAR))
	assert_signal_not_emitted(gs,"game_victory")
