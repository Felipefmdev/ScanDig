extends SceneTree

## Regressões de fluxo real: eventos injetados no Viewport, não chamadas a notebook._input.
## Ator fake, sem prova de gameplay/coop ou captura de mouse em renderer headless.
## REDs planejados: ceder à pausa solo mesmo com árvore pausada; G remapeado não consumido.
const CONFLICT: StringName = &"notebook_modal_conflict"

class LocalActor extends Node:
	var marker_wheel: Control = null
	var is_downed: bool = false
	var remapped_presses: int = 0

	func is_local() -> bool:
		return true

	func is_alive() -> bool:
		return true

	func _unhandled_input(event: InputEvent) -> void:
		if InputMap.has_action(CONFLICT) and event.is_action_pressed(CONFLICT):
			remapped_presses += 1

var _fails: int = 0
var _scene: Node = null
var _actor: LocalActor = null
var _hud: CanvasLayer = null
var _notebook: Node = null
var _prior: Button = null
var _previous_map: MapData = null
var _previous_paused: bool = false
var _previous_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _previous_focus: WeakRef = null
var _pause_existed: bool = false
var _pause_events: Array[InputEvent] = []
var _conflict_existed: bool = false
var _conflict_events: Array[InputEvent] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	print(("PASS " if value else "FAIL ") + message)
	if not value:
		_fails += 1


func _frames() -> void:
	await process_frame
	await process_frame


func _button(index: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event


func _key(code: Key, pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _send(press: InputEvent, release: InputEvent) -> void:
	Input.parse_input_event(press)
	await _frames()
	Input.parse_input_event(release)
	await _frames()


func _record(stage: String) -> void:
	var focus: Control = root.gui_get_focus_owner()
	print("MODAL_STATE " + JSON.stringify({"stage": stage, "paused": paused,
		"pause_open": PauseMenu.is_open(), "book_open": bool(_notebook.call("is_open_for", _actor)),
		"book_can_process": _notebook.can_process(), "book_process_mode": _notebook.process_mode,
		"focus": str(focus.get_path()) if focus != null else "", "remapped_presses": _actor.remapped_presses}))


func _prepare_book() -> void:
	PauseMenu.instance.close()
	paused = false
	_notebook.call("close")
	_prior.grab_focus()
	_notebook.call("open")
	_check(bool(_notebook.call("is_open_for", _actor)), "precondição: caderno aberto")


func _run() -> void:
	SaveManager.instance.use_test_save_dir("expedition_notebook_modal_test")
	print("USERDATA %s" % OS.get_user_data_dir())
	_previous_paused = paused
	_previous_mouse = Input.mouse_mode
	_previous_map = SessionManager.instance.get_current_map()
	var focus: Control = root.gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_pause_existed = InputMap.has_action(&"pause")
	if _pause_existed:
		_pause_events.assign(InputMap.action_get_events(&"pause"))
	_conflict_existed = InputMap.has_action(CONFLICT)
	if _conflict_existed:
		_conflict_events.assign(InputMap.action_get_events(CONFLICT))
	_check(not paused and not PauseMenu.is_open(), "início sem pausa prévia")
	_check(not SessionUI.instance.loading_screen.visible and not UiFocus.modal_open(), "início sem outro modal")
	_check(not SessionUI.instance.toast_panel.visible and SessionUI.instance._toast_queue.is_empty(), "início com fila de avisos vazia, sem supressão")
	if _fails != 0:
		await _finish()
		return
	if not _pause_existed:
		InputMap.add_action(&"pause")
	InputMap.action_erase_events(&"pause")
	InputMap.action_add_event(&"pause", _button(JOY_BUTTON_START, false))
	InputMap.action_add_event(&"pause", _key(KEY_ESCAPE, false))
	_check(InputMap.event_is_action(_button(JOY_BUTTON_START, true), &"pause"), "Start mapeado para ação pause real")
	_scene = Node.new()
	_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(_scene)
	current_scene = _scene
	_actor = LocalActor.new()
	_scene.add_child(_actor)
	_hud = CanvasLayer.new()
	_actor.add_child(_hud)
	_prior = Button.new()
	_hud.add_child(_prior)
	SessionManager.instance.set("_current_map", load("res://items/maps/praia.tres"))
	var nb_script: GDScript = load("res://ui/expedition_notebook.gd") as GDScript
	_notebook = nb_script.new()
	_hud.add_child(_notebook)
	_notebook.call("bind", _actor)
	await _frames()

	_prepare_book()
	await _send(_button(JOY_BUTTON_START, true), _button(JOY_BUTTON_START, false))
	_record("start_event")
	_check(PauseMenu.is_open() and paused, "Start abre pausa solo real e pausa árvore")
	_check(not bool(_notebook.call("is_open_for", _actor)), "caderno cede a Start mesmo com árvore pausada")
	_check(root.gui_get_focus_owner() == PauseMenu.instance.continue_button, "caderno não rouba foco da pausa aberta por Start")

	_prepare_book()
	_check(PauseMenu.instance.open(), "PauseMenu.open real aceitou abertura")
	await _frames()
	_record("direct_pause_open")
	_check(PauseMenu.is_open() and paused, "abertura direta da pausa realmente pausa árvore")
	_check(not bool(_notebook.call("is_open_for", _actor)), "caderno fecha para modal superveniente em pausa solo")
	_check(root.gui_get_focus_owner() == PauseMenu.instance.continue_button, "prioridade de foco da pausa direta preservada")

	_prepare_book()
	if not _conflict_existed:
		InputMap.add_action(CONFLICT)
	InputMap.action_erase_events(CONFLICT)
	InputMap.action_add_event(CONFLICT, _key(KEY_G, false))
	await _send(_key(KEY_G, true), _key(KEY_G, false))
	_record("remapped_g_while_open")
	_check(bool(_notebook.call("is_open_for", _actor)), "G conflitante não fecha caderno já aberto")
	_check(_actor.remapped_presses == 1, "G conflitante chega à ação remapeada sem ser consumido pelo caderno")

	_prepare_book()
	await _send(_key(KEY_ESCAPE, true), _key(KEY_ESCAPE, false))
	_check(not bool(_notebook.call("is_open_for", _actor)) and not PauseMenu.is_open() and not paused, "Esc fecha somente caderno, sem abrir pausa")
	_prepare_book()
	await _send(_button(JOY_BUTTON_B, true), _button(JOY_BUTTON_B, false))
	_check(not bool(_notebook.call("is_open_for", _actor)) and not PauseMenu.is_open() and not paused, "B fecha somente caderno, sem abrir pausa")
	await _finish()


func _restore_action(action: StringName, existed: bool, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	if existed:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for event: InputEvent in events:
			InputMap.action_add_event(action, event)
	elif InputMap.has_action(action):
		InputMap.erase_action(action)


func _finish() -> void:
	PauseMenu.instance.close()
	paused = false
	if is_instance_valid(_notebook):
		_notebook.call("close")
	_restore_action(&"pause", _pause_existed, _pause_events)
	_restore_action(CONFLICT, _conflict_existed, _conflict_events)
	SessionManager.instance.set("_current_map", _previous_map)
	if is_instance_valid(_scene):
		_scene.queue_free()
	await _frames()
	Input.mouse_mode = _previous_mouse
	var focus: Control = _previous_focus.get_ref() as Control if _previous_focus != null else null
	if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree():
		focus.grab_focus()
	_check(not PauseMenu.is_open() and not paused, "cleanup fechou pausa e despausou árvore")
	_check(InputMap.action_get_events(&"pause") == _pause_events if _pause_existed else not InputMap.has_action(&"pause"), "cleanup restaurou InputMap de pause")
	_check(InputMap.action_get_events(CONFLICT) == _conflict_events if _conflict_existed else not InputMap.has_action(CONFLICT), "cleanup restaurou InputMap da ação conflitante")
	paused = _previous_paused
	print("RESULT fails=%d" % _fails)
	quit(_fails)
