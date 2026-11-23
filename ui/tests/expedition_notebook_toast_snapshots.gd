extends SceneTree

## QA planejado: --windowed --resolution 1280x720 (ou 1920x1080) --script este arquivo.
## Caderno instalado pelo Player real, com física/input suspensos. Não valida coop/input.
## RED esperado se o toast real da camada 50 cobrir o cabeçalho do caderno na camada 44.
## Não limpa fila, não cancela timer, não oculta toast e não implementa adiamento.
const KIND: String = "crab"
var _out_dir: String = ""
var _fails: int = 0
var _tag: String = ""
var _notebook: Node = null
var _ui: SessionUI = null
var _events: Array[String] = []
var _states: Array[Dictionary] = []
var _rects: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	print(("PASS " if value else "FAIL ") + message)
	if not value:
		_fails += 1


func _frames(count: int) -> void:
	for _frame: int in count:
		await process_frame


func _shot(label: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var path: String = _out_dir + label + "_" + _tag + ".png"
	_check(root.get_texture().get_image().save_png(path) == OK, "SHOT " + path)


func _on_creature_discovered(kind: String) -> void:
	_events.append(kind)


func _record(stage: String) -> void:
	var data: Dictionary = {
		"stage": stage, "ticks_ms": Time.get_ticks_msec(), "locale": TranslationServer.get_locale(),
		"toast_visible": _ui.toast_panel.is_visible_in_tree(), "toast_text": _ui.toast_label.text,
		"queue": _ui._toast_queue.duplicate(), "events": _events.duplicate(),
		"toast_layer": _ui.layer, "toast_mouse_filter": _ui.toast_panel.mouse_filter,
		"notebook_open": bool(_notebook.call("is_open_for", _notebook.get("_actor"))) if is_instance_valid(_notebook) else false,
	}
	_states.append(data)
	print("TOAST_STATE " + JSON.stringify(data))


func _rect_data(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _inspect_overlap() -> void:
	_check(_ui.toast_panel.is_visible_in_tree(), "toast ainda visível no instante da medição")
	var toast: Rect2 = _ui.toast_panel.get_global_rect()
	var tabs: TabContainer = _notebook.get("_tabs") as TabContainer
	var targets: Dictionary = {
		"title": _notebook.get("_title"), "hint": _notebook.get("_hint"),
		"tabbar": tabs.get_tab_bar(), "close": _notebook.get("_close_button"),
	}
	var notebook_layer: int = int(_notebook.get("layer"))
	for id: String in targets:
		var control: Control = targets[id] as Control
		var target: Rect2 = control.get_global_rect()
		var intersection: Rect2 = toast.intersection(target)
		# Interseção visual; mouse_filter IGNORE não impede o toast de cobrir texto.
		var covers: bool = _ui.toast_panel.is_visible_in_tree() and _ui.layer > notebook_layer and intersection.has_area()
		var record: Dictionary = {"target": id, "toast": _rect_data(toast), "rect": _rect_data(target),
			"intersection": _rect_data(intersection), "visually_covers": covers,
			"toast_layer": _ui.layer, "notebook_layer": notebook_layer}
		_rects.append(record)
		print("TOAST_RECT " + JSON.stringify(record))
		_check(not covers, "toast real não cobre " + id)


func _wait_real_toast() -> void:
	var started: int = Time.get_ticks_msec()
	# Mesmo domínio do timer da SessionUI: tempo real, inclusive com time_scale diferente.
	await create_timer(SessionUI.TOAST_SEC + 0.25, true, false, true).timeout
	_check(Time.get_ticks_msec() - started >= int(SessionUI.TOAST_SEC * 1000.0), "espera real de pelo menos 3 segundos")


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
	SaveManager.instance.use_test_save_dir("expedition_notebook_toast_snapshots")
	print("USERDATA %s" % OS.get_user_data_dir())
	_tag = "%dx%d" % [root.size.x, root.size.y]
	_ui = SessionUI.instance
	SessionManager.instance.set("_current_map", null)
	# Seed anterior à cena, sem criar o aviso sob teste. Nenhuma fila é limpa.
	GameState.instance.load_snapshot({"seen_creatures": [], "stats": {"creatures_defeated": 0}, "achievements": []})
	change_scene_to_file("res://world/map_praia.tscn")
	await _frames(90)
	SessionManager.instance.set("_current_map", load("res://items/maps/praia.tres"))
	var actors: Array[Node] = get_nodes_in_group(Player.LOCAL_GROUP)
	_check(not actors.is_empty(), "fixture encontra Player real local")
	_check(not _ui.loading_screen.visible, "sem carregamento ou modal mascarando o caderno")
	_check(not _ui.toast_panel.visible and _ui._toast_queue.is_empty(), "nenhum aviso anterior ao evento sob teste")
	if _fails != 0:
		await _finish()
		return
	var actor: Player = actors[0] as Player
	actor.set_physics_process(false)
	actor.set_process_unhandled_input(false)
	_notebook = actor.get_node_or_null(^"HUD/ExpeditionNotebook")
	_check(_notebook != null and _notebook == actor.expedition_notebook, "fixture reutiliza a instância instalada pelo Player")
	var notebook_count: int = 0
	for candidate: Node in get_nodes_in_group(&"expedition_notebooks"):
		if actor.is_ancestor_of(candidate):
			notebook_count += 1
	_check(notebook_count == 1, "uma única instância de caderno no ator: %d" % notebook_count)
	if _fails != 0:
		await _finish()
		return
	_notebook.call("open")
	_check(bool(_notebook.call("is_open_for", actor)) and not paused, "caderno aberto sem pausar sessão")
	_check(_ui._should_show_toast(), "caminho real de avisos da expedição habilitado")
	if _fails != 0:
		await _finish()
		return
	await _shot("before_event")
	_record("before_event")
	GameState.instance.creature_discovered.connect(_on_creature_discovered)
	GameState.instance.report_creature(KIND)
	await _frames(4)
	_check(_events.has(KIND) and GameState.instance.seen_creatures.has(KIND), "evento passou por GameState e sinal real")
	_check(bool(_notebook.call("is_open_for", actor)), "aviso não fechou caderno")
	_record("event_while_open")
	var immediate: bool = _ui.toast_panel.is_visible_in_tree()
	var retained: Array[String] = _ui._toast_queue.duplicate()
	var creature_name: String = tr(str(GameState.CREATURES[KIND]))
	if immediate:
		_check(_ui.toast_label.text.contains(creature_name), "toast visível conserva conteúdo da descoberta real")
		await _shot("real_toast_while_open")
		_inspect_overlap()
	else:
		_check(not retained.is_empty(), "aviso adiado permanece na fila real")
		_check("\n".join(retained).contains(creature_name), "fila adiada conserva conteúdo da descoberta")
		await _shot("queued_event_while_open")
	await _wait_real_toast()
	_record("after_3s_while_open")
	_check(bool(_notebook.call("is_open_for", actor)), "caderno continua aberto após timer real")
	if not immediate:
		_check(_ui._toast_queue == retained, "aviso adiado não foi descartado durante consulta")
	_notebook.call("close")
	await _frames(4)
	_record("after_close")
	if not immediate:
		_check(_ui.toast_panel.visible and _ui.toast_label.text.contains(creature_name), "aviso adiado aparece com conteúdo preservado após fechar")
	await _shot("after_close")
	await _finish()


func _finish() -> void:
	if is_instance_valid(_notebook):
		_notebook.call("close")
	# Permite terminar avisos reais (inclusive os que só aparecerem após fechar).
	# Nenhum _clear_toasts, token, visibilidade ou estado de WorldFlags é alterado.
	await _wait_real_toast()
	_record("cleanup_after_real_timer")
	_check(not _ui.toast_panel.visible and _ui._toast_queue.is_empty(), "avisos e fila terminaram sem supressão")
	if GameState.instance.creature_discovered.is_connected(_on_creature_discovered):
		GameState.instance.creature_discovered.disconnect(_on_creature_discovered)
	var report: FileAccess = FileAccess.open(_out_dir + "report_" + _tag + ".json", FileAccess.WRITE)
	_check(report != null, "relatório de fila/conteúdo/retângulos gravável")
	if report != null:
		report.store_string(JSON.stringify({"states": _states, "rects": _rects, "fails": _fails}, "\t"))
		report.close()
	SessionManager.instance.set("_current_map", null)
	if is_instance_valid(_notebook):
		_notebook = null
	unload_current_scene()
	await _frames(8)
	print("RESULT fails=%d" % _fails)
	quit(_fails)
