## Fixture de consulta: reutiliza o caderno instalado pelo Player de produção.
## Não comprova fluxo humano, controle físico ou coop.
## --path . --windowed --resolution 1280x720 --script res://ui/tests/expedition_notebook_snapshots.gd -- --out-dir=res://.bot_runs/<nova-rodada>/notebook720
extends SceneTree

var _out_dir: String = ""
var _fails: int = 0
var _tag: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, text: String) -> void:
	print(("PASS " if value else "FAIL ") + text)
	if not value:
		_fails += 1


func _shot(label: String) -> void:
	for _frame: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = _out_dir + label + "_" + _tag + ".png"
	_check(root.get_texture().get_image().save_png(path) == OK, "SHOT " + path)


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = ProjectSettings.globalize_path(arg.trim_prefix("--out-dir=")).simplify_path().trim_suffix("/") + "/"
	var evidence_root: String = ProjectSettings.globalize_path("res://.bot_runs/").simplify_path().trim_suffix("/") + "/"
	_check(not _out_dir.is_empty() and _out_dir.begins_with(evidence_root) and _out_dir != evidence_root, "--out-dir obrigatório dentro de .bot_runs")
	_check(not _out_dir.is_empty() and not DirAccess.dir_exists_absolute(_out_dir), "saída nova, sem sobrescrever evidências")
	var actual_size: Vector2i = DisplayServer.window_get_size()
	_check((actual_size == Vector2i(1280, 720) or actual_size == Vector2i(1920, 1080)) and root.size == actual_size, "dimensões efetivas alvo: janela=%s root=%s" % [actual_size, root.size])
	if _fails != 0:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	_check(DirAccess.make_dir_recursive_absolute(_out_dir) == OK, "diretório novo de evidências gravável")
	if _fails != 0:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	SaveManager.instance.use_test_save_dir("expedition_notebook_snapshots")
	print("USERDATA %s" % OS.get_user_data_dir())
	_tag = "%dx%d" % [root.size.x, root.size.y]
	SessionManager.instance.set("_current_map", null)
	_check(not SessionUI.instance._should_show_toast(), "seed fora de expedição bloqueia toast")
	GameState.instance.load_snapshot({"seen_creatures": ["crab", "snake"], "defeated_bosses": ["king_crab"], "discovered_items": ["moeda_antiga", "alianca_ouro"], "achievements": ["first_find"]})
	_check(not SessionUI.instance._should_show_toast(), "seed mantém toast de expedição bloqueado")
	_check(not SessionUI.instance.toast_panel.visible and SessionUI.instance._toast_queue.is_empty(), "seed não iniciou toast nem fila")
	change_scene_to_file("res://world/map_praia.tscn")
	for _frame: int in 90:
		await process_frame
	SessionManager.instance.set("_current_map", load("res://items/maps/praia.tres"))
	SessionUI.instance.loading_screen.hide()
	SessionUI.instance._clear_toasts()
	var actors: Array[Node] = get_nodes_in_group(Player.LOCAL_GROUP)
	_check(not actors.is_empty(), "fixture usa jogador local real")
	if actors.is_empty():
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	var actor: Player = actors[0] as Player
	actor.set_physics_process(false)
	actor.set_process_unhandled_input(false)
	var notebook: Node = actor.get_node_or_null(^"HUD/ExpeditionNotebook")
	_check(notebook != null and notebook == actor.expedition_notebook, "fixture reutiliza a instância instalada pelo Player")
	var notebook_count: int = 0
	for candidate: Node in get_nodes_in_group(&"expedition_notebooks"):
		if actor.is_ancestor_of(candidate):
			notebook_count += 1
	_check(notebook_count == 1, "uma única instância de caderno no ator: %d" % notebook_count)
	if _fails != 0:
		unload_current_scene()
		for _frame: int in 8:
			await process_frame
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	await process_frame
	SessionUI.instance._clear_toasts()
	await _shot("before_consulta")
	var prior: Button = Button.new()
	prior.position = Vector2(-500, -500)
	actor.get_node("HUD").add_child(prior)
	prior.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "renderer permite CAPTURED")
	notebook.call("open")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "CAPTURED -> VISIBLE")
	_check(bool(notebook.call("is_open_for", actor)) and not paused, "consulta aberta sem pausar árvore")
	await _shot("diario")
	var journal: VBoxContainer = notebook.get("_journal") as VBoxContainer
	for row: Node in journal.get_children():
		var control: Control = row as Control
		_check(control.size.y <= 140.0, "ficha de diário legível: altura %.0f" % control.size.y)
	var tabs: TabContainer = notebook.get("_tabs") as TabContainer
	var shoulder: InputEventJoypadButton = InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	shoulder.pressed = true
	notebook.call("_input", shoulder)
	await _shot("conquistas")
	_check(tabs.current_tab == 1, "RB troca para Conquistas")
	notebook.call("_input", shoulder)
	await _shot("colecao")
	_check(tabs.current_tab == 2, "RB troca para Coleção")
	notebook.call("close")
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "VISIBLE -> CAPTURED")
	_check(root.gui_get_focus_owner() == prior, "restaura foco anterior")
	await _shot("after_consulta")
	notebook.call("open")
	SessionUI.instance.loading_screen.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	prior.grab_focus()
	notebook.call("_process", 0.0)
	_check(not bool(notebook.call("is_open_for", actor)), "modal superveniente fecha caderno")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and root.gui_get_focus_owner() == prior, "modal superveniente conserva cursor e foco")
	SessionUI.instance.loading_screen.hide()
	SessionManager.instance.set("_current_map", null)
	prior.queue_free()
	unload_current_scene()
	for _frame: int in 8:
		await process_frame
	print("RESULT fails=%d" % _fails)
	quit(_fails)
