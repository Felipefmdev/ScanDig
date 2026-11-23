# Teste unitário de fronteira (#212):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --verbose --path . --script res://ui/tests/expedition_notebook_toast_boundary_test.gd
#
# Alcance estritamente UNITÁRIO: suspende SessionUI._process na fixture para isolar a fronteira exata
# em que o timeout de TOAST_SEC em SessionUI._show_next_toast() dispara com a fila antes vazia e o
# NotebookProbe público aberto sem gui_focus_changed prévio. NÃO afirma reachability no loop normal
# de Player real (onde _process e gui_focus_changed rodam antes do timeout).
# Discriminante sem alterar asserts:
# - Snapshot B75C8734: RED (descarta o aviso ativo no timeout quando _toast_queue estava vazia).
# - Snapshot 6B8137D8: GREEN (recolhe o aviso ativo exatamente 1 vez e o retoma íntegro ao fechar).
extends SceneTree

class NotebookProbe extends Node:
	var _actor: Node = null
	var _opened: bool = false

	func _ready() -> void:
		add_to_group(SessionUI.EXPEDITION_NOTEBOOK_GROUP)

	func is_open_for(player: Node) -> bool:
		return _opened and is_instance_valid(player) and _actor == player

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait(frames: int) -> void:
	for _i: int in range(frames):
		await process_frame


func _wait_real_toast() -> void:
	var started_ms: int = Time.get_ticks_msec()
	await create_timer(SessionUI.TOAST_SEC + 0.25, true, false, true).timeout
	_check(Time.get_ticks_msec() - started_ms >= int(SessionUI.TOAST_SEC * 1000.0), "espera real >= TOAST_SEC")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveManager.instance.use_test_save_dir("expedition_notebook_toast_boundary_test")
	print("USERDATA %s save_path=%s" % [OS.get_user_data_dir(), SaveManager.instance.save_path])
	await _wait(6)
	var gs: GameState = GameState.instance
	var ui: SessionUI = SessionUI.instance
	var session: Node = root.get_node_or_null(^"CoreSession")
	_check(gs != null and ui != null and session != null, "GameState, SessionUI e CoreSession presentes")
	if gs == null or ui == null or session == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return

	gs.reset_state()
	await _wait(3)
	ui._clear_toasts()
	session.set("_current_map", load("res://items/maps/praia.tres"))
	_check(ui._should_show_toast(), "avisos de expedição habilitados após sync")

	var local_actor: Node = Node.new()
	local_actor.add_to_group(Player.LOCAL_GROUP)
	root.add_child(local_actor)
	var probe: NotebookProbe = NotebookProbe.new()
	probe._actor = local_actor
	probe._opened = false
	root.add_child(probe)
	await _wait(2)

	var expected_text: String = "Missão concluída: O anzol de ouro (+R$\u00a0600)"
	gs.quest_completed.emit("ze_anzol", 600)
	_check(ui.toast_panel.visible and ui.toast_label.text == expected_text, "aviso A ativo real exibido antes do timeout")
	_check(ui._toast_queue.is_empty(), "fila vazia enquanto aviso A está ativo na tela")

	# Isola a fronteira de timeout de _show_next_toast() sem _process e sem gui_focus_changed,
	# e sem manipular _toast_queue, _toast_token ou toast_panel.visible.
	ui.set_process(false)
	probe._opened = true
	await _wait_real_toast()

	_check(not ui.toast_panel.visible, "timeout com caderno aberto oculta ToastPanel")
	_check(ui._toast_queue.size() == 1, "aviso A retido exatamente 1 vez na fila (size=%d)" % ui._toast_queue.size())
	_check(ui._toast_queue == [expected_text], "aviso A retido conserva conteúdo íntegro na fila")

	# Ao fechar o caderno e reativar o processamento normal, o aviso A retido deve reaparecer íntegro.
	probe._opened = false
	ui.set_process(true)
	await _wait(2)
	_check(ui.toast_panel.visible and ui.toast_label.text == expected_text, "fechar caderno retoma aviso A íntegro na tela")
	_check(ui._toast_queue.is_empty(), "retomada consome a fila sem duplicação")

	# Cleanup real do timer retomado: aguarda expirar naturalmente sem _clear_toasts().
	await _wait_real_toast()
	_check(not ui.toast_panel.visible and ui._toast_queue.is_empty(), "timer retomado expira naturalmente e limpa ToastPanel/fila")

	session.set("_current_map", null)
	probe.queue_free()
	local_actor.queue_free()
	await _wait(2)
	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
