extends SceneTree

class LocalActor extends Node:
	var marker_wheel: Control = null
	var alive: bool = true
	var local: bool = true
	# Mantém is_alive() independente para testar o contrato downed explicitamente.
	var is_downed: bool = false

	func is_local() -> bool:
		return local

	func is_alive() -> bool:
		return alive

var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	print(("PASS " if value else "FAIL ") + message)
	if not value:
		_fails += 1


func _run() -> void:
	SaveManager.instance.use_test_save_dir("expedition_notebook_test")
	print("USERDATA %s" % OS.get_user_data_dir())
	# Removing discovery filtering would expose names of unseen creatures/bosses.
	var path: String = "res://ui/expedition_notebook.gd"
	_check(ResourceLoader.exists(path), "caderno disponível durante expedição")
	if not ResourceLoader.exists(path):
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	var nb_script: GDScript = load(path) as GDScript
	var notebook: Node = nb_script.new()
	root.add_child(notebook)
	await process_frame
	var access_hint: Label = notebook.get_node_or_null(^"AccessHint") as Label
	var nb_root: Control = notebook.get_node_or_null(^"ExpeditionNotebook") as Control
	_check(access_hint != null and nb_root != null and access_hint.has_theme_font_override(&"font") and access_hint.get_theme_font(&"font") == nb_root.theme.default_font, "AccessHint usa font == theme.default_font")
	_check(access_hint != null and access_hint.get_theme_constant(&"outline_size") == 3, "AccessHint conserva outline_size == 3")
	_check(access_hint != null and access_hint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "AccessHint conserva mouse_filter == MOUSE_FILTER_IGNORE")
	var gs: GameState = GameState.instance
	gs.load_snapshot({"seen_creatures": ["crab"], "defeated_bosses": ["king_crab"], "discovered_items": ["lata_enferrujada"]})
	notebook.call("refresh")
	_check(str(notebook.call("entry_text", "crab")).contains("Caranguejo"), "criatura registrada mostra nome")
	_check(not str(notebook.call("entry_text", "snake")).contains("Cobra"), "criatura não vista preserva descoberta")
	_check(str(notebook.call("entry_text", "king_crab")).contains("Caranguejo-Rei"), "chefe derrotado usa registro real")
	_check(not str(notebook.call("entry_text", "giant_mole")).contains("Toupeira Gigante"), "chefe não registrado permanece desconhecido")
	gs.load_snapshot({"seen_creatures": [], "defeated_bosses": [], "discovered_items": []})
	notebook.call("refresh")
	_check(not str(notebook.call("entry_text", "crab")).contains("Caranguejo"), "reset do snapshot remove descoberta exibida")
	_check((notebook.get("_achievements") as AchievementsTab).get_row_count() > 0, "reutiliza conquistas reais")
	notebook.call("open")
	_check(not bool(notebook.call("is_open_for", null)), "sem jogador local não abre")
	var scene: Node = Node.new()
	root.add_child(scene)
	current_scene = scene
	var actor: LocalActor = LocalActor.new()
	scene.add_child(actor)
	SessionManager.instance.set("_current_map", load("res://items/maps/praia.tres"))
	SessionUI.instance.loading_screen.hide()
	notebook.call("bind", actor)
	var prior_focus: Button = Button.new()
	scene.add_child(prior_focus)
	prior_focus.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# DisplayServer headless mantém VISIBLE mesmo após pedido de CAPTURED.
	var previous_mouse: Input.MouseMode = Input.mouse_mode
	notebook.call("open")
	_check(bool(notebook.call("is_open_for", actor)), "abre apenas para ator vinculado")
	_check(not paused, "consulta não pausa sessão")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "consulta libera cursor")
	notebook.call("close")
	_check(Input.mouse_mode == previous_mouse, "fechar restaura modo de cursor anterior")
	_check(root.gui_get_focus_owner() == prior_focus, "fechar restaura foco anterior")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_G
	key.pressed = true
	InputMap.add_action("notebook_test_remap")
	InputMap.action_add_event("notebook_test_remap", key)
	_check(bool(notebook.call("shortcut_conflicts", key)), "remapeamento de G impede conflito")
	notebook.call("_input", key)
	_check(not bool(notebook.call("is_open_for", actor)), "atalho ocupado não abre")
	InputMap.erase_action("notebook_test_remap")
	notebook.call("_input", key)
	_check(bool(notebook.call("is_open_for", actor)), "G livre abre caderno")
	var cancel: InputEventJoypadButton = InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	notebook.call("_input", cancel)
	_check(not bool(notebook.call("is_open_for", actor)) and not PauseMenu.is_open(), "B fecha sem abrir pausa")
	notebook.call("open")
	SessionUI.instance.loading_screen.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	notebook.call("_process", 0.0)
	_check(not bool(notebook.call("is_open_for", actor)), "carregamento superveniente fecha consulta")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "modal superveniente mantém cursor próprio")
	notebook.call("open")
	_check(not bool(notebook.call("is_open_for", actor)), "não abre sobre carregamento")
	SessionUI.instance.loading_screen.hide()
	actor.local = false
	notebook.call("open")
	_check(not bool(notebook.call("is_open_for", actor)), "jogador remoto não abre caderno")
	actor.local = true
	actor.is_downed = true
	prior_focus.grab_focus()
	var downed_mouse: Input.MouseMode = Input.mouse_mode
	notebook.call("open")
	_check(not bool(notebook.call("is_open_for", actor)), "ator downed não abre mesmo com is_alive verdadeiro")
	_check(root.gui_get_focus_owner() == prior_focus and Input.mouse_mode == downed_mouse, "recusa downed preserva foco e cursor")
	actor.is_downed = false
	notebook.call("open")
	_check(bool(notebook.call("is_open_for", actor)), "contexto reanimado permite abrir novamente")
	actor.is_downed = true
	prior_focus.grab_focus()
	notebook.call("_process", 0.0)
	_check(not bool(notebook.call("is_open_for", actor)), "ficar downed fecha caderno no processamento")
	_check(root.gui_get_focus_owner() == prior_focus and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "perda de contexto downed não rouba foco nem captura")
	actor.is_downed = false
	prior_focus.grab_focus()
	Input.mouse_mode = previous_mouse
	notebook.call("open")
	notebook.call("close")
	_check(root.gui_get_focus_owner() == prior_focus and Input.mouse_mode == previous_mouse, "após reanimação fechar restaura foco e cursor anteriores")
	notebook.call("open")
	actor.is_downed = true
	notebook.call("_input", key)
	_check(not bool(notebook.call("is_open_for", actor)), "ficar downed fecha caderno antes de tratar input")
	actor.is_downed = false
	notebook.call("open")
	actor.alive = false
	notebook.call("_process", 0.0)
	_check(not bool(notebook.call("is_open_for", actor)), "morte fecha consulta")
	scene.queue_free()
	notebook.queue_free()
	await process_frame
	print("RESULT fails=%d" % _fails)
	quit(_fails)
