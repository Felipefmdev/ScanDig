extends GutTest

## #75: todo BOSS_ID de gameplay/enemies/boss precisa ser aceito pelo GameState.

const BOSS_DIR: String = "res://gameplay/enemies/boss"


func _known_ids() -> Array[String]:
	var ids: Array[String] = GameState.EXTRA_BOSSES.duplicate()
	for entry: Dictionary in GameState.MAP_UNLOCK_BOSSES.values():
		ids.append(str(entry["boss_id"]))
	return ids


func test_every_boss_script_id_is_known() -> void:
	var known: Array[String] = _known_ids()
	var dir: DirAccess = DirAccess.open(BOSS_DIR)
	assert_not_null(dir, "pasta de chefes abre")
	var checked: int = 0
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var script: Script = load("%s/%s" % [BOSS_DIR, file_name]) as Script
		var consts: Dictionary = script.get_script_constant_map()
		if not consts.has("BOSS_ID"):
			continue
		checked += 1
		var boss_id: String = str(consts["BOSS_ID"])
		assert_true(known.has(boss_id), "%s (%s) registrado no GameState" % [boss_id, file_name])
	assert_gt(checked, 10, "achou os scripts de chefe")


func test_defeated_bosses_accepts_and_stores_all_bosses() -> void:
	var gs: GameState = GameState.new()
	add_child_autoqfree(gs)
	gs.defeated_bosses.clear()

	var all_bosses: Array[String] = _known_ids()
	for boss_id: String in all_bosses:
		gs._host_report_boss_defeated(boss_id)
		assert_true(gs.is_boss_defeated(boss_id), "GameState aceita e armazena '%s'" % boss_id)
		assert_true(gs.defeated_bosses.has(boss_id), "defeated_bosses contem '%s'" % boss_id)

	assert_eq(gs.defeated_bosses.size(), all_bosses.size(), "todos os chefes conhecidos armazenados")

	# Nao duplica chamadas repetidas
	gs._host_report_boss_defeated("the_sleeper")
	assert_eq(gs.defeated_bosses.size(), all_bosses.size(), "nao duplica chefe ja derrotado")

	# Rejeita chefe desconhecido
	gs._host_report_boss_defeated("chefe_desconhecido_xyz")
	assert_false(gs.is_boss_defeated("chefe_desconhecido_xyz"), "chefe desconhecido nao e aceito")
	assert_false(gs.defeated_bosses.has("chefe_desconhecido_xyz"))
