class_name SaveManager
extends Node

## Gerenciador de persistência de dados em JSON. No jogo, 3 slots (#100):
## user://scandig_save_1.json .. _3.json, cada um com o seu .backup.json e .tmp. Testes, bots e
## --script usam um arquivo só (use_test_save_dir/set_save_path, ou o caminho base), como antes.
##
## Política (ver docs/CORE_AND_NETWORK.md, "Save"):
## - O save no disco só é aplicado por continue_game()/start_new_game() ou, se ninguém
##   escolheu, sozinho ao abrir a sessão como host e ao começar a primeira expedição.
## - save_game() nunca grava por cima de um save que ainda não foi aplicado.
## - Cliente em sessão usa o estado do host; ao sair, volta ao próprio save.
## - Save corrompido vira scandig_save.corrupt-<unix>.json; versão mais nova bloqueia a gravação.

signal game_saved()
signal game_loaded()
signal save_failed(error_message: String)
## O save não pôde ser usado (corrompido ou de versão mais nova). Texto pronto para a UI.
signal save_load_failed(message: String)
signal new_game_started()
## Depois de carregar, começar jogo novo, gravar ou apagar: a UI recalcula o resumo.
signal save_state_changed()

const SAVE_FILE_PATH: String = "user://scandig_save.json"
## Slots do jogo (#100). Ficam na mesma pasta do caminho base (o real ou o dos testes).
const SLOT_COUNT: int = 3
const SLOT_FILE_FORMAT: String = "scandig_save_%d.json"
## O save de antes dos slots, depois de copiado para o slot 1.
const LEGACY_FILE_NAME: String = "scandig_save.legacy.json"
const SAVE_VERSION: int = 4
## Pasta dos saves isolados dos testes (use_test_save_dir).
const TEST_SAVES_DIR: String = "user://test_saves"
## Caminho base sob GUT/--script/bot, antes de use_test_save_dir/set_save_path.
const TEST_SAVE_FILE_PATH: String = "user://test_saves/scandig_save.json"
const MSG_CORRUPT: String = "O save estava corrompido e foi salvo como backup. Começando um jogo novo."
const MSG_NEWER: String = "Este save é de uma versão mais nova do jogo. Atualize o ScanDig para continuar."
## Campos que o apply_snapshot só aceita como Array.
const LIST_FIELDS: Array[String] = ["discovered_items", "unlocked_maps", "defeated_bosses", "completed_quests", "found_secrets", "seen_creatures", "intact_items", "rare_items", "map_fragments", "built_shortcuts"]
## Campos numéricos opcionais (team_money é obrigatório e conferido à parte).
const NUMBER_FIELDS: Array[String] = ["current_day", "equipped_detector_level", "saved_at"]

## Estado de leitura do arquivo, devolvido por _read_save().
enum ReadStatus { MISSING, OK, CORRUPT, NEWER }

static var instance: SaveManager = null

## Caminho do save em uso: o do slot ativo, ou o base (testes/bots/--script).
var save_path: String = SAVE_FILE_PATH
## Caminho base: define a pasta dos slots e o save antigo a migrar.
var _base_path: String = SAVE_FILE_PATH
## Slot ativo (1..SLOT_COUNT); 0 = sem slot, usa o caminho base.
var _slot: int = 0

## O progresso do disco já está no GameState (ou não há save). false para cliente em sessão.
var _progress_applied: bool = false
## Save de versão mais nova nesta sessão: nada é gravado até start_new_game().
var _write_blocked: bool = false


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	# Jogo de verdade: migra o save antigo e já entra num slot (o último usado, ou o 1). Testes,
	# bots e --script nunca tocam nos saves do jogador (ficam no caminho base, como antes).
	if not _running_tests():
		migrate_legacy_save()
		var last: int = last_used_slot()
		_activate_slot(last if last > 0 else 1)
	else:
		# Nem o caminho base fica na pasta real: sem use_test_save_dir, vai para test_saves/.
		DirAccess.make_dir_recursive_absolute(TEST_SAVES_DIR)
		save_path = TEST_SAVE_FILE_PATH
		_base_path = TEST_SAVE_FILE_PATH
	_reset_session_flags()
	var net: NetworkManager = NetworkManager.instance
	if net == null:
		push_warning("SaveManager: NetworkManager indisponível; o save não acompanha a sessão.")
		return
	net.player_connected.connect(_on_player_connected)
	net.connection_succeeded.connect(_on_joined_as_client)
	net.session_left.connect(_on_session_left)
	net.server_disconnected.connect(_restore_local_progress)


# --- API para a UI -----------------------------------------------------------------

## Lê o arquivo SEM aplicar. Nunca dá erro.
## {exists, valid, version, day, money, museum_found, museum_total, saved_at (unix, 0 se não houver), error}
func get_save_summary() -> Dictionary:
	return _summary_from(_read_save())


func _summary_from(read: Dictionary) -> Dictionary:
	var data: Dictionary = read["data"]
	var state: GameState = _resolve_game_state()
	var found: Variant = data.get("discovered_items", [])
	return {
		"exists": read["status"] != ReadStatus.MISSING,
		"valid": read["status"] == ReadStatus.OK,
		"version": int(read["version"]),
		"day": int(data.get("current_day", 0)) if read["status"] == ReadStatus.OK else 0,
		"money": int(data.get("team_money", 0)) if read["status"] == ReadStatus.OK else 0,
		"museum_found": (found as Array).size() if read["status"] == ReadStatus.OK and found is Array else 0,
		"museum_total": state.get_total_catalog_items() if state != null else 0,
		"game_completed": _beat_final_boss(data),
		"saved_at": int(data.get("saved_at", 0)) if read["status"] == ReadStatus.OK else 0,
		"error": str(read["error"]),
	}


# --- Slots (#100) ------------------------------------------------------------------

## Arquivo do slot `n` (1..SLOT_COUNT), na pasta do caminho base.
func slot_path(n: int) -> String:
	return "%s/%s" % [_base_path.get_base_dir(), SLOT_FILE_FORMAT % n]


static func is_valid_slot(n: int) -> bool:
	return n >= 1 and n <= SLOT_COUNT


## Slot ativo (0 = sem slot: testes, bots, --script).
func current_slot() -> int:
	return _slot


## Resumo do slot `n` sem trocar nada (mesmo formato do get_save_summary, mais "slot").
func get_slot_summary(n: int) -> Dictionary:
	var summary: Dictionary = _summary_from(_read_save(slot_path(n)))
	summary["slot"] = n
	return summary


## O slot válido gravado por último (maior saved_at); -1 se nenhum.
func last_used_slot() -> int:
	var best: int = -1
	var best_at: int = -1
	for n: int in range(1, SLOT_COUNT + 1):
		var summary: Dictionary = get_slot_summary(n)
		if bool(summary["valid"]) and int(summary["saved_at"]) > best_at:
			best = n
			best_at = int(summary["saved_at"])
	return best


## Troca o save para o slot `n` (fora de expedição; só host/offline). Não aplica: depois vem
## continue_game() ou start_new_game(). Slot vazio começa do zero na hora.
func select_slot(n: int) -> Error:
	if not is_valid_slot(n):
		return ERR_INVALID_PARAMETER
	var check: Error = _check_can_change_progress()
	if check != OK:
		return check
	_activate_slot(n)
	_reset_session_flags()
	if not has_save_file():
		_resolve_game_state().reset_state()
	save_state_changed.emit()
	return OK


## Apaga o slot `n` e o backup dele. A confirmação é da UI. Fora de expedição, host/offline.
func delete_slot(n: int) -> Error:
	if not is_valid_slot(n):
		return ERR_INVALID_PARAMETER
	var check: Error = _check_can_change_progress()
	if check != OK:
		return check
	var path: String = slot_path(n)
	# .old/.tmp de uma gravação interrompida também: senão o .old voltaria como save.
	for file_path: String in [path, "%s.backup.json" % path.get_basename(), path + ".old", path + ".tmp"]:
		if FileAccess.file_exists(file_path):
			var error: Error = DirAccess.remove_absolute(file_path)
			if error != OK:
				push_error("SaveManager: falha ao apagar %s (erro %d)." % [file_path, error])
				return error
	if n == _slot:
		_reset_session_flags()
		_resolve_game_state().reset_state()
	save_state_changed.emit()
	return OK


## Uma vez: o save de antes dos slots (scandig_save.json na pasta base) vira o slot 1, com o
## backup, e o antigo é renomeado para scandig_save.legacy.json (nada é apagado). Não mexe se o
## slot 1 já existe. true se migrou.
func migrate_legacy_save() -> bool:
	var dir: String = _base_path.get_base_dir()
	var legacy: String = "%s/scandig_save.json" % dir
	var slot_one: String = slot_path(1)
	if not FileAccess.file_exists(legacy) or FileAccess.file_exists(slot_one):
		return false
	var error: Error = DirAccess.copy_absolute(legacy, slot_one)
	if error != OK:
		push_error("SaveManager: falha ao copiar %s para %s (erro %d); migração adiada." % [legacy, slot_one, error])
		return false
	var legacy_backup: String = "%s/scandig_save.backup.json" % dir
	var slot_backup: String = "%s.backup.json" % slot_one.get_basename()
	if FileAccess.file_exists(legacy_backup) and not FileAccess.file_exists(slot_backup):
		DirAccess.copy_absolute(legacy_backup, slot_backup)
	var kept: String = "%s/%s" % [dir, LEGACY_FILE_NAME]
	if FileAccess.file_exists(kept):
		kept = "%s/scandig_save.legacy-%d.json" % [dir, int(Time.get_unix_time_from_system())]
	if DirAccess.rename_absolute(legacy, kept) != OK:
		push_warning("SaveManager: %s copiado para o slot 1, mas não foi renomeado." % legacy)
	return true


func _activate_slot(n: int) -> void:
	_slot = n
	save_path = slot_path(n)


## GUT (gut_cmdln), testes headless e capturas (--script / -s) e bots (--bot=, só em build de
## debug, como o DebugBridge: no .exe release o --bot= não troca o save do jogador).
static func _running_tests() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg == "--script" or arg == "-s" or arg.contains("gut_cmdln"):
			return true
	for arg: String in OS.get_cmdline_user_args():
		if OS.is_debug_build() and arg.begins_with("--bot="):
			return true
	return false


## true depois de continue_game/start_new_game, ou se não há save. Cliente em sessão: false.
func is_progress_applied() -> bool:
	return _progress_applied


## Host/offline, fora de expedição: aplica o save do disco. Idempotente (a segunda chamada
## não recarrega). Corrompido/versão nova: emite save_load_failed e segue com jogo novo.
func continue_game() -> Error:
	var check: Error = _check_can_change_progress()
	if check != OK:
		return check
	if _progress_applied:
		return OK
	return _apply_saved_progress()


## Host/offline, fora de expedição: guarda o save atual em scandig_save.backup.json,
## apaga, volta ao estado inicial e grava já. A confirmação com o jogador é da UI.
func start_new_game() -> Error:
	var check: Error = _check_can_change_progress()
	if check != OK:
		return check
	if FileAccess.file_exists(save_path):
		var backup_error: Error = DirAccess.copy_absolute(save_path, get_backup_path())
		if backup_error != OK:
			var message: String = "SaveManager: não foi possível copiar o save para %s (erro %d); jogo novo cancelado." % [get_backup_path(), backup_error]
			push_error(message)
			save_failed.emit(message)
			return backup_error
		DirAccess.remove_absolute(save_path)
	_write_blocked = false
	_progress_applied = true
	_resolve_game_state().reset_state()
	var error: Error = save_game()
	new_game_started.emit()
	save_state_changed.emit()
	return error


## Core: aplica o save se ninguém escolheu ainda (abrir a sessão como host, começar a
## primeira expedição). Só no host/offline; não faz nada se já foi aplicado.
func ensure_progress_applied() -> void:
	var state: GameState = _resolve_game_state()
	if _progress_applied or state == null or not state.is_authority():
		return
	_apply_saved_progress()


# --- Arquivo -----------------------------------------------------------------------

func has_save_file() -> bool:
	return FileAccess.file_exists(save_path)


func get_backup_path() -> String:
	return "%s.backup.json" % save_path.get_basename()


func delete_save_file() -> Error:
	if not has_save_file():
		return OK
	var error: Error = DirAccess.remove_absolute(save_path)
	if error != OK:
		push_error("SaveManager: Falha ao remover o arquivo do save. Erro: %d" % error)
		return error
	_progress_applied = true
	save_state_changed.emit()
	return OK


## Gravação atômica: escreve em <save>.tmp, confere o tamanho gravado e só então troca pelo
## save. Qualquer falha (disco cheio, sem permissão, rename recusado) deixa o save anterior
## intacto e apaga o .tmp.
func save_to_file(data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var tmp_path: String = save_path + ".tmp"
	var text: String = JSON.stringify(data, "	")
	var error: Error = _write_file(tmp_path, text)
	if error == OK and _file_size(tmp_path) != text.to_utf8_buffer().size():
		# Gravação incompleta sem erro (disco cheio no meio): nunca vai por cima do save.
		error = ERR_FILE_CANT_WRITE
	if error != OK:
		push_error("SaveManager: Falha ao gravar %s. Erro: %d" % [tmp_path, error])
		_remove_if_exists(tmp_path)
		return error
	error = _replace_file(tmp_path, save_path)
	if error != OK:
		push_error("SaveManager: Falha ao trocar %s por %s. Erro: %d" % [tmp_path, save_path, error])
		_remove_if_exists(tmp_path)
	return error


## Escreve `text` em `path`. Separado para os testes simularem disco cheio.
func _write_file(path: String, text: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	var error: Error = file.get_error()
	file.close()
	return error


## Renomeia `from` para `to`. Separado para os testes simularem falha no rename.
func _rename_file(from: String, to: String) -> Error:
	return DirAccess.rename_absolute(from, to)


## Troca `target` por `source`. Se o sistema não renomeia por cima, o antigo vira <target>.old
## (não é apagado) e volta para o lugar se a troca falhar.
func _replace_file(source: String, target: String) -> Error:
	var error: Error = _rename_file(source, target)
	if error == OK or not FileAccess.file_exists(target):
		return error
	var old_path: String = target + ".old"
	_remove_if_exists(old_path)
	if _rename_file(target, old_path) != OK:
		return error
	error = _rename_file(source, target)
	if error != OK:
		if _rename_file(old_path, target) != OK:
			push_error("SaveManager: o save anterior ficou em %s." % old_path)
		return error
	_remove_if_exists(old_path)
	return OK


static func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size


static func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func load_from_file() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Falha ao abrir %s para leitura." % save_path)
		return {}

	var content: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(content)
	if error != OK:
		push_error("SaveManager: Erro ao interpretar JSON em %s: %s (linha %d)" % [
			save_path, json.get_error_message(), json.get_error_line()
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

	if not _write_blocked and not _progress_applied and has_save_file():
		_write_blocked = _read_save()["status"] == ReadStatus.NEWER
		if not _write_blocked:
			var unapplied_msg: String = "SaveManager: o save em %s ainda não foi carregado; use continue_game() ou start_new_game() antes de gravar." % save_path
			push_warning(unapplied_msg)
			save_failed.emit(unapplied_msg)
			return ERR_UNAVAILABLE
	if _write_blocked:
		var blocked_msg: String = "SaveManager: gravação bloqueada; o save é de uma versão mais nova do jogo."
		push_warning(blocked_msg)
		save_failed.emit(blocked_msg)
		return ERR_UNAUTHORIZED

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"team_money": state.team_money,
		"current_day": state.current_day,
		"discovered_items": Array(state.discovered_items),
		"upgrade_levels": state.upgrade_levels.duplicate(),
		"unlocked_maps": Array(state.unlocked_maps),
		"defeated_bosses": Array(state.defeated_bosses),
		"completed_quests": Array(state.completed_quests),
		"found_secrets": Array(state.found_secrets),
		"seen_creatures": Array(state.seen_creatures),
		"intact_items": Array(state.intact_items),
		"rare_items": Array(state.rare_items),
		"map_fragments": Array(state.map_fragments),
		"built_shortcuts": Array(state.built_shortcuts),
		"game_completed": state.game_completed,
	}

	var error: Error = save_to_file(save_data)
	if error == OK:
		_progress_applied = true
		game_saved.emit()
		save_state_changed.emit()
	else:
		save_failed.emit("Falha ao salvar o arquivo: código %d" % error)
	return error


## Carrega o save cru no GameState (os testes usam). A UI usa continue_game().
func load_game(target_state: GameState = null) -> Error:
	var state: GameState = _resolve_game_state(target_state)
	if state == null:
		var err_msg: String = "SaveManager: Não foi possível encontrar uma instância de GameState para carregar dados."
		push_error(err_msg)
		save_failed.emit(err_msg)
		return ERR_DOES_NOT_EXIST

	if not has_save_file():
		var err_msg: String = "SaveManager: Arquivo do save não encontrado em %s." % save_path
		push_warning(err_msg)
		return ERR_FILE_NOT_FOUND

	var read: Dictionary = _read_save()
	if read["status"] != ReadStatus.OK:
		var err_msg: String = "SaveManager: Dados de gravação inválidos: %s" % read["error"]
		push_error(err_msg)
		save_failed.emit(err_msg)
		return ERR_FILE_UNRECOGNIZED if read["status"] == ReadStatus.NEWER else ERR_INVALID_DATA

	if not state.is_authority():
		var err_msg: String = "SaveManager: Apenas o host pode carregar o save."
		push_warning(err_msg)
		save_failed.emit(err_msg)
		return ERR_UNAUTHORIZED

	state.load_snapshot(_upgrade_save_data(read["data"]))
	_progress_applied = true
	game_loaded.emit()
	save_state_changed.emit()
	return OK


# --- Testes ------------------------------------------------------------------------

## Só testes: troca o caminho do save e recomeça a sessão do save (sem aplicar nada). Sai do
## slot: o caminho vira o base (os slots passam a ficar na pasta dele).
func set_save_path(path: String) -> void:
	save_path = path
	_base_path = path
	_slot = 0
	_reset_session_flags()
	save_state_changed.emit()


## Só testes: save isolado e vazio em user://test_saves/<test_name>/.
func use_test_save_dir(test_name: String) -> void:
	var dir_path: String = "%s/%s" % [TEST_SAVES_DIR, test_name]
	DirAccess.make_dir_recursive_absolute(dir_path)
	for file_name: String in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute("%s/%s" % [dir_path, file_name])
	set_save_path("%s/scandig_save.json" % dir_path)


# --- Internos ----------------------------------------------------------------------

func _reset_session_flags() -> void:
	_recover_interrupted_replace()
	_write_blocked = false
	_progress_applied = not FileAccess.file_exists(save_path)


## O jogo fechou no meio do _replace_file (save já em <save>.old, .tmp ainda não no lugar):
## o anterior volta a ser o save.
func _recover_interrupted_replace() -> void:
	var old_path: String = save_path + ".old"
	if not FileAccess.file_exists(save_path) and FileAccess.file_exists(old_path):
		if _rename_file(old_path, save_path) == OK:
			push_warning("SaveManager: gravação interrompida; save anterior restaurado de %s." % old_path)


## OK se dá para trocar o progresso agora: host/offline e fora de expedição.
func _check_can_change_progress() -> Error:
	var state: GameState = _resolve_game_state()
	if state == null:
		return ERR_DOES_NOT_EXIST
	if not state.is_authority():
		return ERR_UNAUTHORIZED
	var session: SessionManager = SessionManager.instance
	if session != null and session.is_in_expedition():
		return ERR_BUSY
	return OK


## Aplica o que estiver no disco. Sem save: nada muda. Corrompido: guarda como
## corrupt-<unix> e começa do zero. Versão nova: não aplica e bloqueia a gravação.
func _apply_saved_progress() -> Error:
	var state: GameState = _resolve_game_state()
	var read: Dictionary = _read_save()
	match read["status"]:
		ReadStatus.MISSING:
			_progress_applied = true
			save_state_changed.emit()
			return OK
		ReadStatus.OK:
			state.load_snapshot(_upgrade_save_data(read["data"]))
			_progress_applied = true
			game_loaded.emit()
			save_state_changed.emit()
			return OK
		ReadStatus.CORRUPT:
			push_warning("SaveManager: save corrompido (%s); salvo em %s." % [read["error"], _quarantine_corrupt_save()])
			_progress_applied = true
			state.reset_state()
			save_load_failed.emit(MSG_CORRUPT)
			save_state_changed.emit()
			return ERR_FILE_CORRUPT
		_:
			push_warning("SaveManager: %s; gravação bloqueada nesta sessão." % read["error"])
			_write_blocked = true
			_progress_applied = true
			state.reset_state()
			save_load_failed.emit(MSG_NEWER)
			save_state_changed.emit()
			return ERR_FILE_UNRECOGNIZED


## {"status": ReadStatus, "data": Dictionary, "version": int, "error": String}. Sem efeitos.
## `path` vazio = o save em uso.
func _read_save(path: String = "") -> Dictionary:
	if path.is_empty():
		path = save_path
	var result: Dictionary = {"status": ReadStatus.MISSING, "data": {}, "version": 0, "error": ""}
	if not FileAccess.file_exists(path):
		return result
	result["status"] = ReadStatus.CORRUPT
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		result["error"] = I18n.t("Não foi possível abrir o arquivo (erro %d).") % FileAccess.get_open_error()
		return result
	var content: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(content) != OK:
		result["error"] = I18n.t("JSON inválido na linha %d: %s.") % [json.get_error_line(), json.get_error_message()]
		return result
	if not (json.data is Dictionary):
		result["error"] = "A raiz do save não é um objeto."
		return result
	var data: Dictionary = json.data
	var version_value: Variant = data.get("version", 1)
	if not _is_number(version_value) or int(version_value) < 1:
		result["error"] = "Campo 'version' inválido."
		return result
	result["version"] = int(version_value)
	if int(version_value) > SAVE_VERSION:
		result["status"] = ReadStatus.NEWER
		result["error"] = I18n.t("Save da versão %d, mais nova que a suportada (%d).") % [int(version_value), SAVE_VERSION]
		return result
	var field_error: String = _validate_fields(data)
	if not field_error.is_empty():
		result["error"] = field_error
		return result
	result["status"] = ReadStatus.OK
	result["data"] = data
	return result


## "" se os campos têm os tipos que o apply_snapshot aceita; senão o motivo.
func _validate_fields(data: Dictionary) -> String:
	if not _is_number(data.get("team_money")):
		return "Campo 'team_money' ausente ou inválido."
	for key: String in NUMBER_FIELDS:
		if data.has(key) and not _is_number(data[key]):
			return I18n.t("Campo '%s' inválido.") % key
	for key: String in LIST_FIELDS:
		if data.has(key) and not (data[key] is Array):
			return I18n.t("Campo '%s' não é uma lista.") % key
	if data.has("upgrade_levels") and not (data["upgrade_levels"] is Dictionary):
		return "Campo 'upgrade_levels' inválido."
	if data.has("game_completed") and not (data["game_completed"] is bool):
		return "Campo 'game_completed' inválido."
	return ""


## Converte saves v1–v3 para o formato do snapshot (v4).
func _upgrade_save_data(source: Dictionary) -> Dictionary:
	var save_data: Dictionary = source.duplicate(true)
	# Ids são texto e níveis são números: o resto (null, objetos) seria "<null>" ou quebraria o int().
	for key: String in LIST_FIELDS:
		if save_data.get(key) is Array:
			save_data[key] = (save_data[key] as Array).filter(func(value: Variant) -> bool: return value is String)
	if save_data.get("upgrade_levels") is Dictionary:
		var levels: Dictionary = {}
		for key: Variant in save_data["upgrade_levels"]:
			if key is String and _is_number(save_data["upgrade_levels"][key]):
				levels[key] = save_data["upgrade_levels"][key]
		save_data["upgrade_levels"] = levels
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
	# Diário de campo: saves anteriores começam com o diário vazio.
	if not save_data.has("seen_creatures"):
		save_data["seen_creatures"] = []
	# Achados intactos (#93): saves anteriores começam sem coleção.
	if not save_data.has("intact_items"):
		save_data["intact_items"] = []
	# Doações raras (#111): saves anteriores não sabem quais foram; a vitrine as mostra comuns.
	if not save_data.has("rare_items"):
		save_data["rare_items"] = []
	if not save_data.has("map_fragments"):
		save_data["map_fragments"] = []
	# Conclusão do jogo (#81/#115): sempre pelos chefes vencidos, nunca pelo bool gravado. Saves
	# antigos concluídos pelo the_sleeper (o final antigo) voltam a "não concluído".
	save_data["game_completed"] = _beat_final_boss(save_data)
	return save_data


## Venceu o chefe final (GameState.FINAL_BOSS_ID) segundo os chefes do save.
static func _beat_final_boss(data: Dictionary) -> bool:
	var defeated: Variant = data.get("defeated_bosses", [])
	return defeated is Array and (defeated as Array).has(GameState.FINAL_BOSS_ID)


## Renomeia o save para <save>.corrupt-<unix>.json e devolve o caminho novo.
func _quarantine_corrupt_save() -> String:
	var target: String = "%s.corrupt-%d.json" % [save_path.get_basename(), int(Time.get_unix_time_from_system())]
	var suffix: int = 2
	while FileAccess.file_exists(target):
		target = "%s.corrupt-%d-%d.json" % [save_path.get_basename(), int(Time.get_unix_time_from_system()), suffix]
		suffix += 1
	if DirAccess.rename_absolute(save_path, target) != OK:
		push_error("SaveManager: não foi possível salvar o save corrompido em %s." % target)
	return target


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


# --- Sessão ------------------------------------------------------------------------

## host_game/host_online emitem player_connected(1) com o peer já aberto e antes de
## qualquer cliente: é a hora de aplicar o save, para o primeiro snapshot já levar o progresso.
func _on_player_connected(peer_id: int) -> void:
	if peer_id == NetworkManager.HOST_PEER_ID and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		ensure_progress_applied()


## Cliente entrou: o estado agora é do host, não deste save.
func _on_joined_as_client() -> void:
	_progress_applied = false
	save_state_changed.emit()


func _on_session_left(was_host: bool) -> void:
	if not was_host:
		_restore_local_progress()


## Cliente saiu ou perdeu o host: volta ao próprio save (ou ao jogo novo, sem save).
func _restore_local_progress() -> void:
	var state: GameState = _resolve_game_state()
	if state == null or not state.is_authority():
		return
	if not has_save_file():
		state.reset_state()
		_progress_applied = true
		save_state_changed.emit()
		return
	_apply_saved_progress()


func _resolve_game_state(target: GameState = null) -> GameState:
	if target != null:
		return target
	if GameState.instance != null:
		return GameState.instance
	if is_inside_tree() and get_tree().root.has_node("GameState"):
		return get_tree().root.get_node("GameState") as GameState
	return null
