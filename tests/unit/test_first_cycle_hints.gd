extends GutTest

const HINTS: Script = preload("res://gameplay/player/player_hints.gd")
const PATH: String = "user://test_saves/first_cycle_hints.cfg"
var _settings_path: String = ""
var _show_hints: bool = true
var _mouse_mode: Input.MouseMode


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	HINTS.set_hints_path(PATH)
	HINTS.reset_all()
	_settings_path = SettingsManager.instance.settings_path
	_show_hints = bool(SettingsManager.instance.get_value(SettingsManager.GAMEPLAY, "show_hints"))
	_mouse_mode = Input.mouse_mode
	SettingsManager.instance.settings_path = "user://test_saves/first_cycle_settings.cfg"
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"show_hints": true})


func after_each() -> void:
	HINTS.reset_all()
	Engine.remove_meta(HINTS.PATH_META)
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"show_hints": _show_hints})
	SettingsManager.instance.settings_path = _settings_path
	Input.mouse_mode = _mouse_mode


func test_first_cycle_text_is_shown_once_and_uses_live_controls() -> void:
	assert_ne(HINTS.take("first_pickup"), "", "Arrival offers detector pickup guidance")
	assert_eq(HINTS.take("first_pickup"), "", "No repeated arrival hint")
	var text: String = HINTS.take("first_dig")
	assert_ne(text, "", "Dig guidance exists")
	assert_false(text.contains("{careful_dig}"), "Uses input labels, not raw placeholders")


func test_current_context_skips_completed_steps_and_does_not_regress() -> void:
	var hints: RefCounted = HINTS.new()
	assert_true(hints.has_method("first_cycle_hint"), "Context selector exists")
	if not hints.has_method("first_cycle_hint"):
		return
	assert_eq(hints.call("first_cycle_hint", false, false, false, false, 0, false), "first_pickup")
	assert_eq(hints.call("first_cycle_hint", true, false, false, false, 0, false), "first_equip")
	assert_eq(hints.call("first_cycle_hint", true, true, false, false, 0, false), "first_scan")
	assert_eq(hints.call("first_cycle_hint", true, true, true, false, 0, false), "first_signal")
	assert_eq(hints.call("first_cycle_hint", true, true, true, true, 0, false), "first_dig")
	assert_ne(HINTS.take("first_dig"), "")
	assert_eq(hints.call("first_cycle_hint", true, true, true, false, 0, false), "", "Do not regress after reaching dig range")
	assert_eq(hints.call("first_cycle_hint", false, false, false, false, 1, false), "first_delivery", "Loot has priority over detector")
	assert_eq(hints.call("first_cycle_hint", false, false, false, false, 0, true), "", "Completed session is silent")


func test_disabled_hints_do_not_consume_stage_and_review_restores_it() -> void:
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"show_hints": false})
	assert_eq(HINTS.take("first_delivery"), "")
	assert_false(HINTS.has_seen("first_delivery"))
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"show_hints": true})
	assert_ne(HINTS.take("first_delivery"), "")
	assert_eq(HINTS.first_cycle_hint(false, false, false, false, 0, false), "", "No backwards guidance after delivery advice")
	HINTS.reset_all()
	assert_eq(HINTS.first_cycle_hint(false, false, false, false, 0, false), "first_pickup")


func test_bot_user_arguments_isolate_hints_without_gut_or_test_script_name() -> void:
	# Child process has no GUT, /tests/ path or *_test.gd argument to hide the bug.
	var path: String = "user://test_saves/first_cycle_probe.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("extends SceneTree\nfunc _initialize() -> void:\n\tvar hints = load(\"res://gameplay/player/player_hints.gd\")\n\tquit(0 if hints.hints_path() == \"user://test_saves/hints_test.cfg\" else 1)\n")
	file.close()
	var output: Array = []
	var result: int = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", ProjectSettings.globalize_path(path), "--", "--bot="]), output, true)
	DirAccess.remove_absolute(path)
	assert_eq(result, 0, "Bot user args use test hints, never real player data: %s" % str(output))


func test_hint_translation_precedes_live_action_binding() -> void:
	var old_locale: String = TranslationServer.get_locale()
	var old_pad: bool = InputDevice.using_gamepad()
	var sm: SettingsManager = SettingsManager.instance
	var old_binding: Dictionary = sm.get_binding("careful_dig")
	var translation: Translation = Translation.new()
	translation.locale = "en"
	translation.add_message(HINTS.TEXTS["first_dig"], "Dig with [{careful_dig}], then collect with [{interact}].")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("en")
	InputDevice.instance.set_using_gamepad(false)
	assert_true(sm.set_binding("careful_dig", {"type": "key", "code": KEY_G}))
	var text: String = HINTS.take("first_dig")
	assert_string_contains(text, "Dig with [G]")
	assert_false(text.contains("{interact}"), "Translated placeholders are filled too")
	assert_false(text.contains("Está perto"), "No Portuguese leak in English")
	sm.set_binding("careful_dig", old_binding)
	TranslationServer.remove_translation(translation)
	TranslationServer.set_locale(old_locale)
	InputDevice.instance.set_using_gamepad(old_pad)


func test_local_player_process_shows_arrival_but_remote_does_not_consume_it() -> void:
	var session: SessionManager = SessionManager.instance
	var previous_map: MapData = session.get_current_map()
	session.set("_current_map", load("res://items/maps/praia.tres"))
	var scene: PackedScene = load("res://gameplay/player/player.tscn")
	var remote: Player = scene.instantiate() as Player
	remote.name = "424242"
	add_child_autofree(remote)
	remote.call("_update_first_cycle_hint", 3.1)
	assert_false(HINTS.has_seen("first_pickup"), "Remote cannot spend local hint")
	var player: Player = scene.instantiate() as Player
	player.name = "1"
	add_child_autofree(player)
	player.call("_update_first_cycle_hint", 3.1)
	assert_true(HINTS.has_seen("first_pickup"), "Real local player consumes arrival hint")
	assert_gt(player.get_hud_messages().size(), 0, "Hint reached actual HUD")
	session.set("_current_map", previous_map)
