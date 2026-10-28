extends SceneTree

## #204: o destino precisa ser legível, sem recorte, sem tomar foco ou mudar o prazo.
## Com renderer, grava as mesmas verificações em .bot_runs/204_ui/.
var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_fails += 1


func _frames() -> void:
	for index: int in 5:
		await process_frame


func _shot(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path: String = "res://.bot_runs/204_ui/%s.png" % tag
	_check(root.get_texture().get_image().save_png(path) == OK, "captura " + tag)


func _readable(ui: SessionUI) -> void:
	_check(ui.toast_label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "sem reticências")
	_check(ui.toast_label.get_line_count() > 1, "texto completo em múltiplas linhas")
	_check(ui.toast_label.get_visible_line_count() == ui.toast_label.get_line_count(), "todas as linhas visíveis")
	_check(ui.toast_label.size.y >= ui.toast_label.get_minimum_size().y, "altura contém texto completo")
	_check(ui.toast_panel.get_viewport_rect().encloses(ui.toast_panel.get_global_rect()), "toast dentro da viewport")
	print("TOAST204 text=", ui.toast_label.text, " rect=", ui.toast_panel.get_global_rect(), " lines=", ui.toast_label.get_line_count())


func _case(locale: String, resolution: Vector2i, focus: Button) -> void:
	root.size = resolution
	TranslationServer.set_locale(locale)
	await _frames()
	_check(root.size == resolution, "resolução física solicitada")
	var ui: SessionUI = SessionUI.instance
	ui._clear_toasts()
	ui.hide_save_toast()
	focus.grab_focus()
	var mouse: Input.MouseMode = Input.mouse_mode
	var started: int = Time.get_ticks_msec()
	ui._on_boss_key_available("campo")
	var text: String = ui.toast_label.text
	_check(text.contains("Campo Antigo") if locale == "pt_BR" else text.contains("Old Fields"), "destino localizado no aviso: " + text)
	var token: int = ui._toast_token
	ui._enqueue_toast("SEGUNDO AVISO", true)
	await _frames()
	_readable(ui)
	_check(focus.has_focus() and Input.mouse_mode == mouse, "aviso preserva foco e mouse")
	var tag: String = "%s_%dx%d" % [locale, resolution.x, resolution.y]
	await _shot(tag + "_passage_key")
	ui.show_save_toast(ui.tr(SessionUI.SAVE_FAILED_TEXT))
	await _frames()
	_readable(ui)
	_check(not ui.toast_panel.get_global_rect().intersects(ui.save_toast_rect()), "chave não sobrepõe save")
	_check(focus.has_focus(), "save e chave preservam foco")
	await _shot(tag + "_save")
	VictoryScreen.instance.open()
	await _frames()
	_check(not ui.toast_panel.get_global_rect().intersects(ui.save_toast_rect()), "chave não sobrepõe save com vitória aberta")
	_check(not ui.toast_panel.get_global_rect().intersects(VictoryScreen.instance.summary_view.get_global_rect()), "chave não sobrepõe vitória com save ativo")
	ui.hide_save_toast()
	await _frames()
	_readable(ui)
	_check(VictoryScreen.instance.continue_button.has_focus(), "foco inicial da vitória")
	_check(not ui.toast_panel.get_global_rect().intersects(VictoryScreen.instance.summary_view.get_global_rect()), "chave não sobrepõe vitória")
	await _shot(tag + "_victory")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	root.push_input(key)
	key.pressed = false
	root.push_input(key)
	await _frames()
	_check(VictoryScreen.instance.credits_button.has_focus(), "Tab navega sem ser interceptado pelo toast")
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_UP
	pad.pressed = true
	root.push_input(pad)
	pad.pressed = false
	root.push_input(pad)
	await _frames()
	_check(VictoryScreen.instance.continue_button.has_focus(), "D-pad navega sem ser interceptado pelo toast")
	VictoryScreen.instance.show_credits()
	await _frames()
	_check(VictoryScreen.instance.credits_view.scroll.has_focus(), "créditos mantêm foco de comando")
	_check(not ui.toast_panel.get_global_rect().intersects(VictoryScreen.instance.credits_view.get_global_rect()), "chave não sobrepõe créditos")
	VictoryScreen.instance.close()
	await _frames()
	_check(focus.has_focus(), "fechar vitória devolve foco")
	_check(ui._toast_token == token and ui._toast_queue == ["SEGUNDO AVISO"], "reposicionar preserva token e fila")
	var remaining: float = SessionUI.TOAST_SEC + 0.15 - float(Time.get_ticks_msec() - started) / 1000.0
	_check(remaining > 0.0, "verificações dentro do prazo original")
	if remaining > 0.0:
		await create_timer(remaining, true, false, true).timeout
	_check(ui.toast_label.text == "SEGUNDO AVISO" and ui._toast_queue.is_empty(), "fila avança no prazo original")
	ui._clear_toasts()


func _run() -> void:
	SaveManager.instance.use_test_save_dir("passage_key_toast_204")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.bot_runs/204_ui"))
	change_scene_to_file("res://world/map_praia.tscn")
	await _frames()
	SessionManager.instance._current_map = load("res://items/maps/praia.tres") as MapData
	SessionUI.instance._synced_once = true
	SessionUI.instance.loading_screen.hide()
	var focus: Button = Button.new()
	focus.text = "Focus fixture"
	focus.position = Vector2(20, 300)
	root.add_child(focus)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for locale: String in ["pt_BR", "en"]:
			await _case(locale, resolution, focus)
	focus.free()
	print("RESULT fails=%d" % _fails)
	quit(1 if _fails > 0 else 0)
