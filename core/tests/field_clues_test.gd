extends SceneTree

const NOTEBOOK: Script = preload("res://ui/expedition_notebook.gd")
const FIRST: String = "praia_diario_capitao_1"
const SECOND: String = "praia_diario_capitao_2"
const MAP_PATH: String = "res://world/map_praia.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state: GameState = GameState.instance
	var session: SessionManager = SessionManager.instance
	var saves: SaveManager = SaveManager.instance
	saves.use_test_save_dir("field_clues_test")
	_check(saves.select_slot(1) == OK and _clues(state).is_empty(), "first test slot starts without clues")
	session.request_start_expedition("praia")
	for frame: int in range(300):
		await process_frame
		if session.is_peer_scene_ready(1):
			break
	if current_scene == null or current_scene.scene_file_path != MAP_PATH:
		_check(false, "Praia loaded through SessionManager")
		_finish()
		return

	var first: FlagInteractable = current_scene.get_node(^"PraiaSecrets/Ground/BottleA") as FlagInteractable
	var second: FlagInteractable = current_scene.get_node(^"PraiaSecrets/Ground/BottleB") as FlagInteractable
	var player: Node3D = HostSync.player_of(self, 1)
	if player == null:
		_check(false, "local player is present in the expedition")
		_finish()
		return

	var notebook: Node = NOTEBOOK.new()
	root.add_child(notebook)
	TranslationServer.set_locale("pt_BR")
	_check(_note(notebook, FIRST).is_empty() and _note(notebook, SECOND).is_empty(), "unread notes are hidden")
	player.global_position = second.global_position
	second.request_interact()
	await process_frame
	_check(_clues(state) == [SECOND], "reading the second bottle unlocks only the second note")
	_check(_note(notebook, FIRST).is_empty() and _note(notebook, SECOND).contains(second.say_text), "journal shows the authentic second note alone")
	TranslationServer.set_locale("en")
	await process_frame
	_check(_note(notebook, SECOND).contains("then the BLUE"), "journal uses the current locale")
	second.request_interact()
	await process_frame
	_check(_clues(state) == [SECOND], "repeated reads only record one discovery")

	player.global_position = first.global_position + Vector3(0, 0, 30)
	first.request_interact()
	await process_frame
	_check(_clues(state) == [SECOND], "distance rejection cannot reveal the first note")
	player.global_position = first.global_position
	first.request_interact()
	session.request_end_expedition()
	for frame: int in range(300):
		await process_frame
		if current_scene != null and current_scene.scene_file_path == SessionManager.LOBBY_SCENE:
			break
	_check(current_scene != null and current_scene.scene_file_path == SessionManager.LOBBY_SCENE, "return through the normal expedition flow")
	_check(saves.has_save_file() and _clues(state) == [FIRST, SECOND], "expedition return saves the discoveries")
	_check(saves.select_slot(2) == OK and _clues(state).is_empty(), "another slot starts without clues")
	_check(saves.select_slot(1) == OK and saves.load_game() == OK and _clues(state) == [FIRST, SECOND], "a read immediately before return is saved in journal order")

	var migrated: Dictionary = saves.call(&"_upgrade_save_data", {"version": 6})
	_check(migrated.get("found_field_clues", null) == [], "older save begins with no notes")
	state.apply_snapshot({"found_field_clues": ["invalid", SECOND, SECOND]})
	_check(_clues(state) == [SECOND], "only known unique IDs are restored")
	notebook.queue_free()
	await _check_late_read(session, saves, state)
	_finish()


func _check_late_read(session: SessionManager, saves: SaveManager, state: GameState) -> void:
	_check(saves.select_slot(2) == OK, "select the empty slot for the late-read scenario")
	session.request_start_expedition("praia")
	for frame: int in range(300):
		await process_frame
		if session.is_peer_scene_ready(1):
			break
	if current_scene == null or current_scene.scene_file_path != MAP_PATH:
		_check(false, "reentered the Praia for the late-read scenario")
		return
	var bottle: FlagInteractable = current_scene.get_node(^"PraiaSecrets/Ground/BottleA") as FlagInteractable
	var player: Node3D = HostSync.player_of(self, 1)
	if player == null:
		_check(false, "local player is present for the late-read scenario")
		return
	player.global_position = bottle.global_position
	var reads: Array[int] = []
	bottle.interacted.connect(func(peer: int) -> void: reads.append(peer))
	session.expedition_ending.connect(func(_map: String) -> void: bottle.request_interact(), CONNECT_ONE_SHOT)
	session.request_end_expedition()
	bottle.request_interact()
	await process_frame
	_check(reads.size() == 2, "both interactions reached the old map before it was freed")
	_check(_clues(state).is_empty(), "end-of-expedition callbacks cannot add discoveries after the save")


func _note(notebook: Node, id: String) -> String:
	return str(notebook.call(&"entry_text", "clue:" + id))


func _clues(state: GameState) -> Array:
	return state.get_snapshot().get("found_field_clues", [])


func _check(passed: bool, description: String) -> void:
	print(("PASS " if passed else "FAIL ") + description)
	if not passed:
		_failures += 1


func _finish() -> void:
	print("RESULT fails=%d" % _failures)
	quit(_failures)
