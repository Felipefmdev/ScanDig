class_name SaveManager
extends Node

## Gerenciador de persistência de dados em JSON (user://scandig_save.json).

signal game_saved()
signal game_loaded()
signal save_failed(error_message: String)

const SAVE_FILE_PATH: String = "user://scandig_save.json"

static var instance: SaveManager = null


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)


func delete_save_file() -> Error:
	if has_save_file():
		var dir: DirAccess = DirAccess.open("user://")
		if dir != null:
			var error: Error = dir.remove("scandig_save.json")
			if error != OK:
				push_error("SaveManager: Falha ao remover ficheiro de gravação. Erro: %d" % error)
			return error
	return OK


func save_to_file(data: Dictionary) -> Error:
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		var err: Error = FileAccess.get_open_error()
		push_error("SaveManager: Falha ao abrir %s para escrita. Erro: %d" % [SAVE_FILE_PATH, err])
		return err
	
	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return OK


func load_from_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return {}
	
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Falha ao abrir %s para leitura." % SAVE_FILE_PATH)
		return {}
	
	var content: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var error: Error = json.parse(content)
	if error != OK:
		push_error("SaveManager: Erro ao interpretar JSON em %s: %s (linha %d)" % [
			SAVE_FILE_PATH, json.get_error_message(), json.get_error_line()
		])
		return {}
	
	if json.data is Dictionary:
		return json.data as Dictionary
	
	return {}


func save_game(target_state: GameState = null) -> Error:
	var state: GameState = _resolve_game_state(target_state)
	if state == null:
		var err_msg: String = "SaveManager: Não foi possível encontrar uma instância de GameState para salvar."
		push_error(err_msg)
		save_failed.emit(err_msg)
		return ERR_DOES_NOT_EXIST
	
	if not state.is_authority():
		var not_host_msg: String = "SaveManager: Apenas o host pode salvar o jogo."
		push_warning(not_host_msg)
		save_failed.emit(not_host_msg)
		return ERR_UNAUTHORIZED
	
	var save_data: Dictionary = {
		"version": 4,
		"team_money": state.team_money,
		"current_day": state.current_day,
		"discovered_items": Array(state.discovered_items),
		"upgrade_levels": state.upgrade_levels.duplicate(),
		"unlocked_maps": Array(state.unlocked_maps),
		"defeated_bosses": Array(state.defeated_bosses),
		"completed_quests": Array(state.completed_quests),
		"found_secrets": Array(state.found_secrets),
	}
	
	var error: Error = save_to_file(save_data)
	if error == OK:
		game_saved.emit()
	else:
		save_failed.emit("Falha ao salvar ficheiro: código %d" % error)
	return error


func load_game(target_state: GameState = null) -> Error:
	var state: GameState = _resolve_game_state(target_state)
	if state == null:
		var err_msg: String = "SaveManager: Não foi possível encontrar uma instância de GameState para carregar dados."
		push_error(err_msg)
		save_failed.emit(err_msg)
		return ERR_DOES_NOT_EXIST
	
	if not has_save_file():
		var err_msg: String = "SaveManager: Ficheiro de gravação não encontrado em %s." % SAVE_FILE_PATH
		push_warning(err_msg)
		return ERR_FILE_NOT_FOUND
	
	var save_data: Dictionary = load_from_file()
	if save_data.is_empty():
		var err_msg: String = "SaveManager: Dados de gravação inválidos ou vazios."
		push_error(err_msg)
		save_failed.emit(err_msg)
		return ERR_INVALID_DATA
	
	if not state.is_authority():
		var err_msg: String = "SaveManager: Apenas o host pode carregar o save."
		push_warning(err_msg)
		save_failed.emit(err_msg)
		return ERR_UNAUTHORIZED
	
	# Save v1 guardava apenas o nível do detector.
	if not save_data.has("upgrade_levels") and save_data.has("equipped_detector_level"):
		save_data["upgrade_levels"] = {"detector": maxi(int(save_data["equipped_detector_level"]) - 1, 0)}
	
	# Saves v1/v2 não têm progressão de mapas: começam sem mapas pagos nem chefes vencidos.
	if not save_data.has("unlocked_maps"):
		save_data["unlocked_maps"] = []
	if not save_data.has("defeated_bosses"):
		save_data["defeated_bosses"] = []
	# Saves v1–v3 não têm missões nem segredos. Um ancient_guardian vindo de um save v3
	# continua em defeated_bosses e agora libera a Geleira (#45).
	if not save_data.has("completed_quests"):
		save_data["completed_quests"] = []
	if not save_data.has("found_secrets"):
		save_data["found_secrets"] = []
	
	state.load_snapshot(save_data)
	game_loaded.emit()
	return OK


func _resolve_game_state(target: GameState = null) -> GameState:
	if target != null:
		return target
	if GameState.instance != null:
		return GameState.instance
	if is_inside_tree() and get_tree().root.has_node("GameState"):
		return get_tree().root.get_node("GameState") as GameState
	return null
