extends SceneTree
## #214: retorno diferido real do CoreSession; nenhum fim de dia/save/RPC de compra.
const MAP: MapData = preload("res://items/maps/praia.tres")
const SUMMARY: Dictionary = {"day": 1, "map_id": "praia", "map_name": "Praia", "entries": [], "money_start": 100, "money_end": 100, "money_earned": 0}

var _checks: int = 0
var _fails: int = 0
var _ui: SessionUI
var _session: SessionManager


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	_fails += 0 if ok else 1
	print(("PASS " if ok else "FAIL ") + message)


func _click(point: Vector2) -> void:
	# Control rects are viewport-local. Do not apply window/stretch conversion twice.
	root.warp_mouse(point)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	var hovered: Control = root.gui_get_hovered_control()
	print("OBS click_local=%s viewport=%s window=%s hovered=%s" % [point, root.get_visible_rect().size, root.size, String(hovered.get_path()) if hovered != null else "none"])
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	root.push_input(event, true)
	await process_frame


func _escape() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _expedition() -> Node3D:
	# Controlled scene context, not a Player mock or a substitute SessionManager.
	var old: Node = current_scene
	var scene: Node3D = Node3D.new()
	scene.name = "MapPraia"
	scene.scene_file_path = "res://world/map_praia.tscn"
	root.add_child(scene)
	current_scene = scene
	if is_instance_valid(old):
		old.queue_free()
	_session.set("_current_map", MAP)
	return scene


func _wait_lobby() -> bool:
	for frame: int in 240:
		if is_instance_valid(current_scene) and current_scene.scene_file_path == SessionManager.LOBBY_SCENE and current_scene.is_node_ready():
			# Wait only for the existing loading curtain, never implement a cursor timer.
			await create_timer(SessionUI.LOADING_MIN_SEC + 0.1, true, false, true).timeout
			return true
		await process_frame
	return false


func _base_ui() -> BaseStationUI:
	for home: Node in get_nodes_in_group(UiFocus.HOME_GROUP):
		if home is BaseStationUI and home.is_inside_tree() and (home as BaseStationUI).is_visible_in_tree():
			return home as BaseStationUI
	return null


func _return_case(escape: bool) -> void:
	var scene: Node3D = _expedition()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# DisplayServer headless mantém VISIBLE mesmo após pedido de CAPTURED.
	var previous_mouse: Input.MouseMode = Input.mouse_mode
	_check(DisplayServer.get_name() == "headless" or previous_mouse == Input.MOUSE_MODE_CAPTURED, "janela real captura cursor antes do retorno")
	_check(PauseMenu.instance.open(), "pausa real abre antes do retorno")
	PauseMenu.instance.close()
	_check(Input.mouse_mode == previous_mouse, "fechar pausa devolve modo anterior antes de agendar lobby")
	# Exercise the actual return handler without request_end_expedition's save/day side effects.
	_session.call("_rpc_return_to_lobby", SUMMARY)
	_check(not _session.is_in_expedition() and current_scene == scene and _ui.summary_panel.visible, "CoreSession zera mapa e emite resumo antes da troca diferida")
	print("OBS cached_mouse=%s current_mouse=%s pending_scene=%s" % [_ui.get("_previous_mouse_mode"), Input.mouse_mode, _session.get("_pending_scene_path")])
	_check(await _wait_lobby(), "retorno agendado entra na Base real")
	_check(_ui.summary_panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "resumo na Base mantem cursor visivel")
	if escape:
		await _escape()
	else:
		await _click(_ui.summary_close_button.get_global_rect().get_center())
	_check(not _ui.summary_panel.visible and not PauseMenu.is_open(), "botao/Esc fecha somente resumo")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "fechar resumo apos retorno mantem cursor Visible na Base")
	var base: BaseStationUI = _base_ui()
	var focus: Control = root.gui_get_focus_owner()
	_check(base != null and focus != null and base.is_ancestor_of(focus), "fechar resumo restaura foco utilizavel na Base")
	if base != null:
		var bar: TabBar = base.tab_container.get_tab_bar()
		var target: int = (bar.current_tab + 1) % bar.tab_count
		var point: Vector2 = bar.get_global_transform() * bar.get_tab_rect(target).get_center()
		await _click(point)
		_check(base.tab_container.current_tab == target and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "clique GUI real troca aba sem recapturar cursor")


func _run() -> void:
	SaveManager.instance.use_test_save_dir("session_return_cursor214")
	await process_frame
	_ui = SessionUI.instance
	_session = SessionManager.instance
	_check(_ui != null and _session != null and _session.scene_change_enabled, "SessionUI e CoreSession reais com troca de cena habilitada")
	await _return_case(false)
	await _return_case(true)
	var scene: Node3D = _expedition()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# DisplayServer headless mantém VISIBLE mesmo após pedido de CAPTURED.
	var previous_mouse: Input.MouseMode = Input.mouse_mode
	_check(DisplayServer.get_name() == "headless" or previous_mouse == Input.MOUSE_MODE_CAPTURED, "janela real captura cursor em gameplay")
	_ui.call("_show_summary", SUMMARY)
	_ui.summary_close_button.pressed.emit()
	_check(_session.is_in_expedition() and current_scene == scene and Input.mouse_mode == previous_mouse, "resumo sem sair do gameplay restaura modo anterior")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ui.call("_show_summary", SUMMARY)
	_ui.summary_close_button.pressed.emit()
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "resumo em gameplay respeita anterior Visible arbitrario")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	PauseMenu.instance.open()
	_ui.call("_show_summary", SUMMARY)
	_ui.summary_close_button.pressed.emit()
	_check(PauseMenu.is_open() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pausa proprietaria nao perde cursor ao fechar resumo")
	PauseMenu.instance.close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ui.call("_show_summary", SUMMARY)
	_ui.call("_on_host_lost")
	_ui.summary_close_button.pressed.emit()
	_check(_ui.host_lost_panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "hostlost superveniente conserva cursor")
	_ui.host_lost_close_button.pressed.emit()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ui.call("_show_summary", SUMMARY)
	_ui.call("_on_leave_pressed")
	_ui.summary_close_button.pressed.emit()
	_check(_ui.leave_confirm_panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "confirmacao superveniente conserva cursor sem executar saida")
	_ui.leave_cancel_button.pressed.emit()
	_session.set("_current_map", null)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("RESULT checks=%d fails=%d" % [_checks, _fails])
	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
