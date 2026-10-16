extends GutTest

## Todo quest_id/secret_id usado nas cenas de segredos tem de existir no GameState: o host
## recusa ids desconhecidos em silêncio (missão sem pagamento, segredo que não fica no save).

const SCENES_GLOB_DIR: String = "res://gameplay/quests"


func _ids_in_scenes(key: String) -> Dictionary:
	var out: Dictionary = {}
	var re: RegEx = RegEx.create_from_string(key + ' = "([a-z0-9_]+)"')
	for map_dir: String in DirAccess.get_directories_at(SCENES_GLOB_DIR):
		var base: String = "%s/%s" % [SCENES_GLOB_DIR, map_dir]
		for f: String in DirAccess.get_files_at(base):
			if not f.ends_with(".tscn"):
				continue
			var text: String = FileAccess.get_file_as_string("%s/%s" % [base, f])
			for m: RegExMatch in re.search_all(text):
				out[m.get_string(1)] = f
	return out


func test_every_scene_quest_is_registered() -> void:
	var quests: Dictionary = _ids_in_scenes("quest_id")
	assert_gte(quests.size(), 5, "uma missão por mapa")
	for id: String in quests:
		assert_true(GameState.QUESTS.has(id), "missão %s (%s) no GameState.QUESTS" % [id, quests[id]])
		if GameState.QUESTS.has(id):
			assert_gt(int(GameState.QUESTS[id]["reward"]), 0, "%s paga algo" % id)


func test_every_scene_secret_is_registered() -> void:
	var secrets: Dictionary = _ids_in_scenes("secret_id")
	assert_gte(secrets.size(), 30, "segredos dos 5 mapas")
	for id: String in secrets:
		assert_true(GameState.SECRETS.has(id), "segredo %s (%s) no GameState.SECRETS" % [id, secrets[id]])
