extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_fails += 1


func _check_notice(ui: SessionUI, panel: Control, focus: Control, context: String) -> void:
	var notice: Rect2 = ui.save_toast_rect()
	_check(ui.save_toast_panel.visible and root.get_visible_rect().encloses(notice), context + " aviso inteiro na tela")
	_check(not notice.intersects(panel.get_global_rect()), context + " painel da Base livre")
	_check(ui.save_toast_label.get_visible_line_count() == ui.save_toast_label.get_line_count(), context + " texto inteiro")
	_check(focus.has_focus(), context + " foco preservado")


func _check_coop(ui: SessionUI) -> void:
	SessionManager.launch_mode = SessionManager.LAUNCH_COOP
	root.size = Vector2i(960, 540)
	root.content_scale_factor = 1.3
	TranslationServer.set_locale("pt_BR")
	change_scene_to_file(SessionManager.LOBBY_SCENE)
	await _frames(15)
	var menu: MultiplayerMenu = current_scene.get_node(^"UILayer/MultiplayerMenu") as MultiplayerMenu
	var panel: Control = current_scene.get_node(^"UILayer/BaseStationUI/PanelContainer") as Control
	menu.set_save_manager(SaveManager.instance)
	_check(menu.is_collapsed(), "menu coop começa recolhido em janela pequena")
	SaveManager.instance.save_load_failed.emit(SaveManager.MSG_NEWER)
	await _frames(5)
	var token: int = ui._save_toast_token
	_check(ui.save_toast_panel.visible, "aviso aparece com menu recolhido")
	root.content_scale_factor = 1.0
	await _frames(5)
	_check(not ui.save_toast_panel.visible and not menu.get_save_notice().is_empty(), "painel aberto mostra o mesmo aviso uma vez")
	root.content_scale_factor = 1.3
	await _frames(5)
	_check(ui.save_toast_panel.visible and ui._save_toast_token == token, "aviso reaparece no prazo original ao recolher o menu")

	menu._on_collapse_pressed()
	await _frames(5)
	_check(not ui.save_toast_panel.visible, "abrir o menu pelo botão evita aviso duplicado")
	menu._on_collapse_pressed()
	await _frames(5)
	_check(ui.save_toast_panel.visible and ui._save_toast_token == token, "recolher pelo botão devolve o aviso no prazo original")

	menu._on_collapse_pressed()
	ui.show_save_toast(SessionUI.SAVE_FAILED_TEXT)
	await _frames(5)
	var notice: Rect2 = ui.save_toast_rect()
	_check(ui.save_toast_panel.visible and root.get_visible_rect().encloses(notice), "aviso inteiro com menu coop expandido")
	_check(not notice.intersects(panel.get_global_rect()) and not notice.intersects(menu.get_save_notice_rect()), "aviso %s deixa livres a Base %s e o menu coop %s" % [notice, panel.get_global_rect(), menu.get_save_notice_rect()])
	ui.hide_save_toast()


func _run() -> void:
	SaveManager.instance.use_test_save_dir("base_save_toast_test")
	SessionManager.launch_mode = SessionManager.LAUNCH_SOLO
	await _frames(3)
	var ui: SessionUI = SessionUI.instance
	ui.show_save_toast(SessionUI.SAVE_FAILED_TEXT)
	var entering_token: int = ui._save_toast_token
	SessionManager.instance.scene_changing.emit(SessionManager.LOBBY_SCENE)
	_check(ui.loading_screen.visible, "retorno à Base mostra carregamento")
	change_scene_to_file(SessionManager.LOBBY_SCENE)
	await _frames(15)
	var base: BaseStationUI = current_scene.get_node(^"UILayer/BaseStationUI") as BaseStationUI
	var panel: Control = base.get_node(^"PanelContainer") as Control
	base.tab_container.current_tab = 2
	await create_timer(SessionUI.LOADING_MIN_SEC + 0.1, true, false, true).timeout
	_check(ui.save_toast_panel.visible and not ui.save_toast_rect().intersects(panel.get_global_rect()), "aviso acompanha o retorno à Base")
	_check(ui._save_toast_token == entering_token, "retorno à Base não reinicia o aviso")
	ui.hide_save_toast()
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		for locale: String in ["pt_BR", "en"]:
			TranslationServer.set_locale(locale)
			root.content_scale_factor = 1.0
			await _frames(5)
			base.depart_btn.grab_focus()
			ui.show_save_toast(SessionUI.SAVE_FAILED_TEXT)
			await _frames(5)
			var context: String = "%s %s" % [resolution, locale]
			_check_notice(ui, panel, base.depart_btn, context + " 100%")

			var token: int = ui._save_toast_token
			root.content_scale_factor = 1.3
			await _frames(6)
			_check_notice(ui, panel, base.depart_btn, context + " 130%")
			_check(ui._save_toast_token == token, context + " ajuste não reinicia o aviso")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var path: String = "user://base-save-toast-%s-%dx%d.png" % [locale, root.size.x, root.size.y]
				_check(root.get_texture().get_image().save_png(path) == OK, context + " captura")
			ui.hide_save_toast()
	await _check_coop(ui)
	print("RESULT fails=%d" % _fails)
	quit(_fails)
