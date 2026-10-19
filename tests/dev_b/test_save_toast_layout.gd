extends GutTest

## Q3 (#137): no título o MultiplayerMenu mostra o aviso do save no painel dele. O toast da
## SessionUI não repete o mesmo texto e, com outro texto, vai para o lado livre sem cobrir o
## painel. Retângulos em 960x540 com ui_scale 1.0 e 1.3.

const LOBBY_SCENE: PackedScene = preload("res://world/lobby_base.tscn")

var _lobby: Node = null
var _menu: MultiplayerMenu = null
var _old_size: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_old_size = get_tree().root.size
	get_tree().root.size = Vector2i(960, 540)
	SessionManager.launch_mode = SessionManager.LAUNCH_COOP
	_lobby = LOBBY_SCENE.instantiate()
	add_child_autofree(_lobby)
	await wait_frames(3)
	_menu = _lobby.get_node(^"UILayer/MultiplayerMenu") as MultiplayerMenu
	_menu.set_save_manager(_save())
	_ui().hide_save_toast()


func after_each() -> void:
	get_tree().root.content_scale_factor = 1.0
	get_tree().root.size = _old_size
	SessionManager.launch_mode = ""
	_ui().hide_save_toast()


func test_toast_beside_menu_at_ui_1_0() -> void:
	await _check_layout(1.0)


func test_toast_beside_menu_at_ui_1_3() -> void:
	await _check_layout(1.3)


func _check_layout(scale: float) -> void:
	get_tree().root.content_scale_factor = scale
	await wait_frames(3)
	if _menu.is_collapsed():
		_menu._on_collapse_pressed()
		await wait_frames(2)
	var ui: SessionUI = _ui()
	assert_true(_menu.progress_box.is_visible_in_tree(), "%.1f: painel do progresso aberto" % scale)

	# Mesmo aviso no painel: só o painel mostra.
	_save().save_load_failed.emit(SaveManager.MSG_NEWER)
	await wait_frames(2)
	assert_true(_menu.progress_warning_label.is_visible_in_tree(), "%.1f: aviso no painel" % scale)
	assert_eq(_menu.get_save_notice(), TranslationServer.translate(SaveManager.MSG_NEWER))
	assert_false(ui.save_toast_panel.visible, "%.1f: o toast não repete o painel" % scale)

	# Outro aviso: o toast aparece fora do menu e dentro da tela.
	_save().save_failed_with_reason.emit(SaveManager.FailReason.WRITE, "msg do dev")
	await wait_frames(2)
	assert_true(ui.save_toast_panel.visible, "%.1f: toast de disco visível" % scale)
	var toast: Rect2 = ui.save_toast_rect()
	var menu_rect: Rect2 = _menu.get_save_notice_rect()
	var warning: Rect2 = _menu.progress_warning_label.get_global_rect()
	assert_true(menu_rect.has_area(), "%.1f: menu desenhado" % scale)
	assert_false(toast.intersects(menu_rect), "%.1f: toast %s fora do menu %s" % [scale, toast, menu_rect])
	assert_false(toast.intersects(warning), "%.1f: toast %s não cobre o aviso %s" % [scale, toast, warning])
	var view: Rect2 = ui.save_toast_panel.get_viewport_rect()
	assert_true(view.encloses(toast), "%.1f: toast %s dentro da tela %s" % [scale, toast, view])
	assert_gte(toast.size.x, SessionUI.SAVE_TOAST_MIN_WIDTH, "%.1f: largura legível" % scale)


func _ui() -> SessionUI:
	return get_node_or_null(^"/root/CoreSessionUI") as SessionUI


func _save() -> SaveManager:
	return get_node_or_null(^"/root/CoreSave") as SaveManager
