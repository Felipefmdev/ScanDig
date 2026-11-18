# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/expedition_bar_layout_test.gd
## ExpeditionBar no canto inferior direito: não cruza a barra do chefe (BossHud), a hotbar
## de 8 slots, a vida, o radar nem o painel de ameaça do HUD do jogador nas resoluções 16:9 alvo (1280x720 e 1920x1080).
extends SceneTree

const TARGET_RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait(frames: int) -> void:
	for _i: int in range(frames):
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


## Hotbar mais larga (mochila de 8): a conta da própria Hotbar (get_bar_rect), com a altura do
## player.tscn (offset_top -112, offset_bottom -16).
func _hotbar_rect() -> Rect2:
	var hotbar: Hotbar = Hotbar.new()
	hotbar.offset_top = -112.0
	hotbar.offset_bottom = -16.0
	root.add_child(hotbar)
	var r: Rect2 = hotbar.get_bar_rect(8)
	hotbar.queue_free()
	return r


func _run() -> void:
	# Em --headless, DisplayServerHeadless inicia com janela dummy 64x64 (1:1) e SettingsManager._apply_video
	# retorna cedo, o que faria stretch canvas_items/expand expandir a viewport lógica para 1152x1152 (1:1).
	# Fixamos explicitamente root.size nas resoluções 16:9 alvo (como passage_key_toast_test.gd e theme_test.gd).
	root.size = TARGET_RESOLUTIONS[0]
	SaveManager.instance.use_test_save_dir("expedition_bar_layout_test")
	var user_data_dir: String = OS.get_user_data_dir()
	var save_path_rel: String = SaveManager.instance.save_path
	var save_path_abs: String = ProjectSettings.globalize_path(save_path_rel)
	print("USERDATA %s save_path=%s abs=%s" % [user_data_dir, save_path_rel, save_path_abs])
	_check(save_path_rel == "user://test_saves/expedition_bar_layout_test/scandig_save.json", "SaveManager.save_path isolado (%s)" % save_path_rel)
	_check(save_path_abs.begins_with(user_data_dir), "save_path absoluto dentro de OS.get_user_data_dir (%s)" % save_path_abs)

	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	var ui: SessionUI = SessionUI.instance
	_check(ui != null, "SessionUI presente")
	if ui == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	var session: Node = root.get_node(^"CoreSession")
	session.set("_current_map", load("res://items/maps/praia.tres"))
	ui._refresh_expedition_bar()
	# Pior caso: host online, com o botão de sair (o "Voltar à base" fica na pausa, #122).
	ui.leave_button.visible = true
	await _wait(5)

	for resolution: Vector2i in TARGET_RESOLUTIONS:
		root.size = resolution
		await _wait(5)
		var tag: String = "%dx%d" % [resolution.x, resolution.y]
		var view: Vector2 = root.get_visible_rect().size
		var bar: Rect2 = ui.expedition_bar.get_global_rect()
		print("RES %s ROOT_SIZE %s VIEW %s BAR %s" % [tag, root.size, view, bar])
		_check(root.size == resolution, "%s: resolução física 16:9 aplicada (%s)" % [tag, root.size])
		_check(is_equal_approx(view.x / maxf(view.y, 1.0), 16.0 / 9.0), "%s: viewport lógica 16:9 sob stretch canvas_items/expand (%s)" % [tag, view])
		_check(ui.expedition_bar.visible, "%s: barra visível na expedição" % tag)
		_check(ui.expedition_info_label.text == "Praia  •  Dia %d" % GameState.instance.current_day, "%s: rótulo: %s" % [tag, ui.expedition_info_label.text])
		_check(bar.size.x >= 240.0 and bar.size.x <= 320.0, "%s: largura 240–320: %.0f" % [tag, bar.size.x])
		var expected_end: Vector2 = view * 0.95
		_check(absf(bar.end.x - expected_end.x) <= 1.0 and absf(bar.end.y - expected_end.y) <= 1.0, "%s: canto inferior direito com margem segura 5%% (esperado=%s): %s" % [tag, expected_end, bar])
		_check(Rect2(Vector2.ZERO, view).encloses(bar), "%s: dentro da tela" % tag)

		var boss: Rect2 = Rect2(view.x * 0.5 - 260.0, 70.0, 520.0, 50.0)
		var hud_rects: Dictionary = {
			"BossHud (chefe)": boss,
			"hotbar de 8": _hotbar_rect(),
			"vida": Rect2(24.0, view.y - 72.0, 280.0, 52.0),
			"radar": Rect2(24.0, view.y - 330.0, 220.0, 244.0),
			"ameaça": Rect2(view.x - 304.0, 20.0, 280.0, 52.0),
		}
		for key: String in hud_rects.keys():
			var r: Rect2 = hud_rects[key]
			_check(not bar.intersects(r), "%s: barra não cruza %s %s" % [tag, key, r])
		ui.toast_panel.visible = true
		await _wait(2)
		var toast: Rect2 = ui.toast_panel.get_global_rect()
		ui.toast_panel.visible = false
		_check(not toast.intersects(boss) and not toast.intersects(bar), "%s: aviso não cruza o chefe nem a barra: %s" % [tag, toast])

	session.set("_current_map", null)
	ui._refresh_expedition_bar()
	GameState.instance.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
