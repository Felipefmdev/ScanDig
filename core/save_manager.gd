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
	
	var save_data: Dictionary = {
		"version": 1,
		"team_money": state.team_money,
		"current_day": state.current_day,
		"discovered_items": state.discovered_items.duplicate(),
		"equipped_detector_level": state.equipped_detector_level,
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
	
	if save_data.has("team_money"):
		state.team_money = int(save_data["team_money"])
	if save_data.has("current_day"):
		state.current_day = int(save_data["current_day"])
	if save_data.has("equipped_detector_level"):
		state.equipped_detector_level = int(save_data["equipped_detector_level"])
	if save_data.has("discovered_items"):
		var raw_items: Array = save_data["discovered_items"]
		var items: Array[String] = []
		for item in raw_items:
			items.append(str(item))
		state.discovered_items = items
	
	state.money_changed.emit(state.team_money)
	state.collection_updated.emit(state.discovered_items.size(), state.get_total_catalog_items())
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
