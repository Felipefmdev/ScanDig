# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/expedition_bar_layout_test.gd
## ExpeditionBar no canto inferior direito: não cruza a barra do chefe (BossHud), a hotbar
## de 8 slots, a vida, o radar nem o painel de ameaça do HUD do jogador.
extends SceneTree

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


## Hotbar mais larga (mochila de 8): mesma conta de Hotbar.get_slot_size, separação 8 do player.tscn.
func _hotbar_rect(view: Vector2) -> Rect2:
	var hotbar: Hotbar = Hotbar.new()
	hotbar.add_theme_constant_override(&"separation", 8)
	root.add_child(hotbar)
	var side: float = hotbar.get_slot_size(8).x
	hotbar.queue_free()
	var width: float = side * 8.0 + 8.0 * 7.0
	return Rect2(view.x * 0.5 - width * 0.5, view.y - 112.0, width, 96.0)


func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	SaveManager.instance.use_test_save_dir("expedition_bar_layout_test")
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
	# Pior caso: host online, com os dois botões.
	ui.return_button.visible = true
	ui.leave_button.visible = true
	await _wait(5)

	var view: Vector2 = root.get_visible_rect().size
	var bar: Rect2 = ui.expedition_bar.get_global_rect()
	print("VIEW %s BAR %s" % [view, bar])
	_check(ui.expedition_bar.visible, "barra visível na expedição")
	_check(ui.expedition_info_label.text == "Praia  •  Dia %d" % GameState.instance.current_day, "rótulo: %s" % ui.expedition_info_label.text)
	_check(bar.size.x >= 240.0 and bar.size.x <= 320.0, "largura 240–320: %.0f" % bar.size.x)
	_check(is_equal_approx(bar.end.x, view.x - 16.0) and is_equal_approx(bar.end.y, view.y - 16.0), "canto inferior direito com margem 16: %s" % bar)
	_check(Rect2(Vector2.ZERO, view).encloses(bar), "dentro da tela")

	var boss: Rect2 = Rect2(view.x * 0.5 - 260.0, 70.0, 520.0, 50.0)
	var hud_rects: Dictionary = {
		"BossHud (chefe)": boss,
		"hotbar de 8": _hotbar_rect(view),
		"vida": Rect2(24.0, view.y - 72.0, 280.0, 52.0),
		"radar": Rect2(24.0, view.y - 330.0, 220.0, 244.0),
		"ameaça": Rect2(view.x - 304.0, 20.0, 280.0, 52.0),
	}
	for key: String in hud_rects.keys():
		var r: Rect2 = hud_rects[key]
		_check(not bar.intersects(r), "barra não cruza %s %s" % [key, r])
	ui.toast_panel.visible = true
	await _wait(2)
	var toast: Rect2 = ui.toast_panel.get_global_rect()
	ui.toast_panel.visible = false
	_check(not toast.intersects(boss) and not toast.intersects(bar), "aviso não cruza o chefe nem a barra: %s" % toast)

	session.set("_current_map", null)
	ui._refresh_expedition_bar()
	GameState.instance.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
