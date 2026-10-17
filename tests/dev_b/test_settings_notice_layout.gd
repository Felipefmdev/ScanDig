extends GutTest

## Aviso "Configurações salvas" / "Dicas reativadas" (#77): não pode cobrir nenhum conteúdo do
## menu (título, abas e seus controles visíveis, linha de botões), em 960x540 e com o HUD a 150 %.
## Validação por retângulos. Nada é gravado (set_section com persist=false).

var _orig_size: Vector2i = Vector2i.ZERO
var _orig_gameplay: Dictionary = {}


func before_each() -> void:
	_orig_size = get_tree().root.size
	get_tree().root.size = Vector2i(960, 540)
	var sm: SettingsManager = SettingsManager.instance
	_orig_gameplay = sm.get_section(SettingsManager.GAMEPLAY)
	sm.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.5}, false)


func after_each() -> void:
	if PauseMenu.instance != null:
		PauseMenu.instance.close()
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, _orig_gameplay, false)
	get_tree().root.size = _orig_size


## Controles visíveis (folhas de layout) sob `root`, recortados pelo ScrollContainer da aba.
func _content_rects(root: Control, clip: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var control: Control = node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control is Label or control is BaseButton or control is Range:
			var rect: Rect2 = control.get_global_rect().intersection(clip)
			if rect.has_area():
				out.append(rect)
		stack.append_array(control.get_children())
	return out


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func test_saved_notice_never_covers_content() -> void:
	var pause: PauseMenu = PauseMenu.instance
	assert_not_null(pause)
	assert_true(pause.open())
	pause.settings_button.pressed.emit()
	var menu: SettingsMenu = pause.settings_menu
	for text: String in [SettingsMenu.SAVED_TEXT, SettingsMenu.HINTS_RESET_TEXT]:
		for tab: int in [SettingsMenu.TAB_VIDEO, SettingsMenu.TAB_AUDIO, SettingsMenu.TAB_CONTROLS, SettingsMenu.TAB_GAMEPLAY]:
			menu.tabs.current_tab = tab
			menu.show_saved_notice(text)
			await _frames(3)
			var notice: Rect2 = menu.saved_notice.get_global_rect()
			assert_true(menu.saved_notice.visible, "aviso visível")
			assert_true(menu.get_global_rect().encloses(notice), "aviso dentro do painel: %s em %s" % [notice, menu.get_global_rect()])
			assert_true(menu.get_viewport_rect().encloses(menu.get_global_rect()), "painel cabe na tela (aba %d): %s" % [tab, menu.get_global_rect()])
			var page: Control = menu.tabs.get_current_tab_control()
			var rects: Array[Rect2] = _content_rects(page, page.get_global_rect())
			rects.append_array(_content_rects(menu.tabs.get_tab_bar(), menu.tabs.get_global_rect()))
			rects.append(menu.buttons_row.get_global_rect())
			rects.append(menu.title_label.get_global_rect())
			rects.append(menu.tabs.get_global_rect())
			assert_gt(rects.size(), 2, "achou o conteúdo da aba %d" % tab)
			for rect: Rect2 in rects:
				assert_false(notice.intersects(rect), "aba %d '%s': aviso %s cobre %s" % [tab, text, notice, rect])
	menu.hide_saved_notice()
