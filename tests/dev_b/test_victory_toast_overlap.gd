extends GutTest

## Regressão #177: evento real de vitória/conquista, geometria e prazo do aviso.
## Requer renderer; captura opcional em SCANDIG_QA_CAPTURE_DIR.
var _state: Dictionary = {}
var _save_state: Dictionary = {}
var _old_map: MapData = null
var _old_locale: String = ""
var _old_size: Vector2i
var _old_scale: float = 1.0
var _old_mouse: Input.MouseMode
var _old_focus: Control = null
var _old_synced: bool = false
var _old_loading: bool = false
var _home_focus: Button = null
var _achievements: Array[String] = []
var _victories: int = 0
var _award_ms: int = 0


func before_each() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var gs: GameState = GameState.instance
	var save: SaveManager = SaveManager.instance
	_state = gs.get_snapshot().duplicate(true)
	for key: String in ["save_path", "_base_path", "_slot", "_progress_applied", "_write_blocked", "play_time_s", "last_map"]:
		_save_state[key] = save.get(key)
	_old_map = SessionManager.instance._current_map
	_old_locale = TranslationServer.get_locale()
	_old_size = get_tree().root.size
	_old_scale = get_tree().root.content_scale_factor
	_old_mouse = Input.mouse_mode
	_old_focus = get_viewport().gui_get_focus_owner()
	_old_synced = SessionUI.instance._synced_once
	_old_loading = SessionUI.instance.loading_screen.visible
	assert_false(VictoryScreen.is_open(), "run in isolated process without preexisting modal")
	assert_false(PauseMenu.is_open(), "no preexisting pause")
	assert_false(SessionUI.instance.toast_panel.visible, "no foreign active toast")
	assert_true(SessionUI.instance._toast_queue.is_empty(), "no foreign pending toast")
	assert_true(gs.is_authority(), "host/local real endpoint required")
	SessionManager.instance._current_map = null
	save.use_test_save_dir("toast177_%d" % Time.get_ticks_usec())
	assert_eq(save.start_new_game(), OK, "new game only in unique test save directory")
	SessionManager.instance._current_map = load("res://items/maps/lua.tres") as MapData
	SessionUI.instance._refresh_expedition_bar()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(SessionUI.instance._synced_once, "real state_synced/deferred initial-sync gate")
	assert_false(SessionUI.instance.loading_screen.visible, "loading must not obscure measured UI")
	_home_focus = Button.new()
	_home_focus.text = "Fixture focus return"
	_home_focus.position = Vector2(2, 2)
	add_child(_home_focus)
	_achievements.clear()
	_victories = 0
	_award_ms = 0
	gs.achievement_unlocked.connect(_on_achievement)
	gs.game_victory.connect(_on_victory)


func after_each() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var gs: GameState = GameState.instance
	gs.achievement_unlocked.disconnect(_on_achievement)
	gs.game_victory.disconnect(_on_victory)
	VictoryScreen.instance.close()
	# Invalidate only this test's toast timer after all deadline assertions.
	SessionUI.instance._clear_toasts()
	SessionManager.instance._current_map = _old_map
	gs.load_snapshot(_state)
	for key: String in _save_state:
		SaveManager.instance.set(key, _save_state[key])
	_save_state.clear()
	TranslationServer.set_locale(_old_locale)
	get_tree().root.content_scale_factor = _old_scale
	get_tree().root.size = _old_size
	Input.mouse_mode = _old_mouse
	if is_instance_valid(_home_focus):
		_home_focus.free()
	_home_focus = null
	await get_tree().process_frame
	await get_tree().process_frame
	SessionUI.instance._synced_once = _old_synced
	SessionUI.instance.loading_screen.visible = _old_loading
	SessionUI.instance._refresh_expedition_bar()
	if is_instance_valid(_old_focus) and _old_focus.is_visible_in_tree():
		_old_focus.grab_focus()


func _on_achievement(id: String) -> void:
	_achievements.append(id)
	if id == "final_boss":
		_award_ms = Time.get_ticks_msec()


func _on_victory() -> void:
	_victories += 1


func _frames() -> void:
	for index: int in 5:
		await get_tree().process_frame


func _until_award_elapsed(seconds: float) -> void:
	var remaining: float = seconds - float(Time.get_ticks_msec() - _award_ms) / 1000.0
	if remaining > 0.0:
		await get_tree().create_timer(remaining, true, false, true).timeout
	await get_tree().process_frame


func _label(node: Node, source: String) -> Label:
	if node is Label and (node as Label).text == source:
		return node as Label
	for child: Node in node.get_children():
		var found: Label = _label(child, source)
		if found != null:
			return found
	return null


func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _capture(stage: String, locale: String, physical_size: Vector2i, ui_scale: float) -> void:
	var directory: String = OS.get_environment("SCANDIG_QA_CAPTURE_DIR")
	if directory.is_empty():
		return
	assert_eq(DirAccess.make_dir_recursive_absolute(directory), OK)
	# Só o painel do runner é ocultado; os widgets reais medidos permanecem visíveis.
	var runner_ui: CanvasItem = get_tree().root.get_node_or_null(^"GutRunner/GutLayer/GutScene") as CanvasItem
	assert_not_null(runner_ui, "painel do GUT identificado para captura sem obstrução")
	var runner_visible: bool = runner_ui != null and runner_ui.visible
	if runner_ui != null:
		runner_ui.visible = false
	await RenderingServer.frame_post_draw
	var filename: String = "%s_%dx%d_%s_%s.png" % [locale, physical_size.x, physical_size.y, str(ui_scale).replace(".", "_"), stage]
	assert_eq(get_viewport().get_texture().get_image().save_png(directory.path_join(filename)), OK)
	if runner_ui != null:
		runner_ui.visible = runner_visible


func _no_overlap(stage: String, controls: Array[Control]) -> void:
	var ui: SessionUI = SessionUI.instance
	assert_true(ui.toast_panel.is_visible_in_tree(), stage + ": real toast visible")
	assert_gt(ui.toast_panel.modulate.a, 0.0)
	var toast: Rect2 = _rect(ui.toast_panel)
	var view: Rect2 = get_viewport().get_visible_rect()
	assert_true(view.encloses(toast), stage + ": toast inside logical viewport " + str(toast))
	for control: Control in controls:
		assert_not_null(control, stage + ": real widget required")
		if control == null:
			continue
		assert_true(control.is_visible_in_tree())
		var target: Rect2 = _rect(control)
		print("TOAST177 ", stage, " view=", view, " toast=", toast, " target=", target)
		assert_false(toast.intersects(target), stage + ": toast overlaps " + str(control.name))
		assert_true(view.encloses(target), stage + ": widget remains inside viewport")


func _case(locale: String, physical_size: Vector2i, ui_scale: float) -> void:
	if DisplayServer.get_name() == "headless":
		pending("#177 requires real renderer/window; do not claim visual acceptance from dummy")
		return
	get_tree().root.size = physical_size
	# Existing Window API used by SettingsManager video.ui_scale; no settings disk write.
	get_tree().root.content_scale_factor = ui_scale
	TranslationServer.set_locale(locale)
	await _frames()
	assert_eq(get_tree().root.size, physical_size, "physical window size")
	assert_almost_eq(get_tree().root.content_scale_factor, ui_scale, 0.001)
	var ui: SessionUI = SessionUI.instance
	var screen: VictoryScreen = VictoryScreen.instance
	ui._place_toast()
	var ordinary_rect: Rect2 = _rect(ui.toast_panel)
	_home_focus.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var before_mouse: Input.MouseMode = Input.mouse_mode
	assert_eq(before_mouse, Input.MOUSE_MODE_CAPTURED, "real renderer must capture mouse")
	var money: int = GameState.instance.team_money
	var day: int = GameState.instance.current_day
	assert_false(GameState.instance.achievements.has("final_boss"))
	assert_false(GameState.instance.is_boss_defeated("lunar_warden"))
	GameState.instance.request_report_boss_defeated("lunar_warden")
	await _frames()
	assert_eq(_achievements.count("final_boss"), 1)
	assert_eq(_victories, 1)
	assert_gt(_award_ms, 0)
	assert_eq(GameState.instance.achievements.count("final_boss"), 1)
	assert_eq(GameState.instance.defeated_bosses.count("lunar_warden"), 1)
	assert_eq(GameState.instance.team_money, money)
	assert_eq(GameState.instance.current_day, day)
	assert_true(VictoryScreen.is_open())
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	var expected: String = tr("🏆 Conquista desbloqueada: %s") % tr(str(Achievements.get_definition("final_boss")["name"]))
	assert_eq(ui.toast_label.text, expected, "real registered locale and real achievement toast")
	assert_true(ui._toast_queue.is_empty(), "fresh fixture: one achievement notification")
	var token: int = ui._toast_token
	var title: Label = _label(screen.summary_view, VictoryScreen.TITLE_TEXT)
	var subtitle: Label = _label(screen.summary_view, VictoryScreen.SUBTITLE_TEXT)
	_no_overlap(locale + str(physical_size) + " scale=" + str(ui_scale), [title, subtitle, screen.continue_button, screen.credits_button])
	# Native label measurement: the actual string must fit without ellipsis.
	var font: Font = ui.toast_label.get_theme_font(&"font")
	var text_width: float = font.get_string_size(ui.toast_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.toast_label.get_theme_font_size(&"font_size")).x
	assert_lte(text_width, ui.toast_label.size.x + 1.0, "achievement text is not ellipsized")
	await _capture("summary", locale, physical_size, ui_scale)
	await _until_award_elapsed(0.65)
	screen.credits_button.pressed.emit()
	await _frames()
	assert_true(screen.credits_view.is_visible_in_tree())
	assert_true(screen.credits_view.scroll.has_focus(), "real CreditsView.focus_start focuses scroll")
	_no_overlap("credits", [screen.credits_back_button, screen.credits_view])
	await _capture("credits", locale, physical_size, ui_scale)
	screen.credits_back_button.pressed.emit()
	await _frames()
	assert_true(screen.summary_view.is_visible_in_tree())
	assert_eq(ui._toast_token, token, "credits must not reset notification deadline")
	assert_eq(ui.toast_label.text, expected)
	await _until_award_elapsed(1.5)
	assert_lt(float(Time.get_ticks_msec() - _award_ms) / 1000.0, 2.6, "renderer timing budget before early close")
	screen.continue_button.pressed.emit()
	await _frames()
	assert_false(VictoryScreen.is_open())
	assert_eq(Input.mouse_mode, before_mouse)
	assert_true(_home_focus.has_focus(), "previous real focus restored")
	assert_true(ui.toast_panel.is_visible_in_tree(), "continue must not hide active notification")
	assert_eq(ui._toast_token, token, "closing victory must not restart timer")
	assert_eq(ui.toast_label.text, expected)
	assert_true(_rect(ui.toast_panel).is_equal_approx(ordinary_rect), "normal placement restored on close")
	await _until_award_elapsed(SessionUI.TOAST_SEC + 0.25)
	assert_false(ui.toast_panel.visible, "expires at original deadline, not close+3 seconds")
	assert_true(ui._toast_queue.is_empty())
	GameState.instance.request_report_boss_defeated("lunar_warden")
	await _frames()
	assert_eq(_achievements.count("final_boss"), 1)
	assert_eq(_victories, 1)
	assert_false(VictoryScreen.is_open())
	assert_false(ui.toast_panel.visible)
	assert_eq(GameState.instance.team_money, money)
	assert_eq(GameState.instance.current_day, day)


func test_pt_648_scale1() -> void:
	await _case("pt_BR", Vector2i(1152, 648), 1.0)

func test_en_648_scale1() -> void:
	await _case("en", Vector2i(1152, 648), 1.0)

func test_pt_720_scale1() -> void:
	await _case("pt_BR", Vector2i(1280, 720), 1.0)

func test_en_720_scale1() -> void:
	await _case("en", Vector2i(1280, 720), 1.0)

func test_pt_648_scale13() -> void:
	await _case("pt_BR", Vector2i(1152, 648), 1.3)

func test_en_648_scale13() -> void:
	await _case("en", Vector2i(1152, 648), 1.3)

func test_pt_720_scale13() -> void:
	await _case("pt_BR", Vector2i(1280, 720), 1.3)

func test_en_720_scale13() -> void:
	await _case("en", Vector2i(1280, 720), 1.3)
