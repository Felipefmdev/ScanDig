## Teste headless (#212): cliente do par coop ENet de 2 fases para o ExpeditionNotebook.
## Par: core/tests/net_notebook_host.gd (porta 7814). Save isolado em user://test_saves/net_notebook_client.
extends SceneTree

const PORT: int = 7814
const TEST_ACTIONS: Array[StringName] = [
	&"move_forward",
	&"move_backward",
	&"move_left",
	&"move_right",
	&"jump",
	&"attack",
	&"use_tool",
	&"drop",
	&"marker",
	&"slot_1",
	&"slot_2",
]


## Barreira dedicada de teste no canal reliable 0, idêntica à do host.
class NotebookBarrier extends Node:
	var marks: Dictionary = {}

	@rpc("any_peer", "call_remote", "reliable", 0)
	func notify_step(step: String, payload: Dictionary = {}) -> void:
		marks[step] = payload.duplicate(true)


var _barrier: NotebookBarrier = null
var _fails: int = 0
var _summary: Dictionary = {}


func _initialize() -> void:
	_barrier = NotebookBarrier.new()
	_barrier.name = "NetNotebookBarrier"
	root.add_child(_barrier)
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	print(("CLIENT PASS " if cond else "CLIENT FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait_frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _wait_physics(count: int) -> void:
	for _i: int in count:
		await physics_frame


func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var elapsed: float = 0.0
	while not bool(cond.call()):
		if elapsed >= timeout_s:
			return false
		await create_timer(0.05).timeout
		elapsed += 0.05
	return true


func _wait_mark(step: String, timeout_s: float) -> bool:
	return await _wait_until(func() -> bool: return _barrier.marks.has(step), timeout_s)


func _scene_name() -> String:
	return String(current_scene.name) if current_scene != null else "null"


func _key_event(code: Key, is_pressed: bool) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = is_pressed
	return ev


func _mouse_button_event(button: MouseButton, is_pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = is_pressed
	ev.position = pos
	ev.global_position = pos
	return ev


func _mouse_motion_event(rel: Vector2) -> InputEventMouseMotion:
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	ev.relative = rel
	ev.position = Vector2(360.0, 220.0)
	ev.global_position = Vector2(360.0, 220.0)
	return ev


func _tap_key(code: Key) -> void:
	Input.parse_input_event(_key_event(code, true))
	await _wait_frames(2)
	Input.parse_input_event(_key_event(code, false))
	await _wait_frames(2)


func _release_test_actions() -> void:
	for act: StringName in TEST_ACTIONS:
		if InputMap.has_action(act) and Input.is_action_pressed(act):
			Input.action_release(act)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _verify_blocked_while_open(actor: Player, book: Node, tag: String) -> void:
	var pos0: Vector3 = actor.global_position
	var yaw0: float = actor.rotation.y
	var pitch0: float = actor.head.rotation.x
	var slot0: int = actor.inventory.selected_slot
	var count0: int = actor.inventory.get_count()

	Input.parse_input_event(_mouse_motion_event(Vector2(48.0, -32.0)))
	Input.parse_input_event(_mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(8.0, 8.0)))
	await _wait_frames(1)
	Input.parse_input_event(_mouse_button_event(MOUSE_BUTTON_LEFT, false, Vector2(8.0, 8.0)))
	Input.parse_input_event(_mouse_button_event(MOUSE_BUTTON_WHEEL_DOWN, true, Vector2(8.0, 8.0)))
	Input.parse_input_event(_mouse_button_event(MOUSE_BUTTON_WHEEL_DOWN, false, Vector2(8.0, 8.0)))
	Input.parse_input_event(_key_event(KEY_T, true))
	await _wait_frames(1)
	Input.parse_input_event(_key_event(KEY_T, false))

	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	Input.action_press(&"attack")
	Input.action_press(&"use_tool")
	Input.action_press(&"drop")
	Input.action_press(&"slot_2")
	await _wait_physics(12)
	_release_test_actions()
	await _wait_physics(2)

	_check(not paused, "%s: get_tree().paused permanece false" % tag)
	_check(bool(book.call(&"is_open_for", actor)), "%s: caderno permanece aberto durante inputs locais" % tag)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "%s: clique não recaptura o cursor" % tag)
	_check(_flat_dist(actor.global_position, pos0) < 0.01, "%s: movimento horizontal bloqueado" % tag)
	_check(is_equal_approx(actor.rotation.y, yaw0) and is_equal_approx(actor.head.rotation.x, pitch0), "%s: olhar do mouse bloqueado" % tag)
	_check(actor.velocity.y <= 0.05 and is_equal_approx(float(actor.get("_jump_buffer_left")), 0.0), "%s: pulo e buffer de pulo bloqueados" % tag)
	_check(not actor.dig_animator.is_playing() and is_equal_approx(float(actor.get("_attack_cooldown")), 0.0) and is_equal_approx(float(actor.get("_attack_buffer_left")), 0.0), "%s: ataque e buffer de ataque bloqueados" % tag)
	_check(is_equal_approx(float(actor.get("_drop_hold")), 0.0) and not bool(actor.get("_drop_holding")) and actor.inventory.get_count() == count0, "%s: drop bloqueado" % tag)
	_check(actor.inventory.selected_slot == slot0, "%s: troca de slot/hotbar bloqueada" % tag)
	var wheel: Node = actor.marker_wheel
	_check(wheel == null or not bool(wheel.call(&"is_wheel_open")), "%s: menu radial de marcador bloqueado" % tag)


func _finish() -> void:
	_release_test_actions()
	if NetworkManager.instance != null:
		NetworkManager.instance.disconnect_game()
	print("CLIENT RESULT fails=%d" % _fails)
	quit(_fails)


func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	var in_lobby: bool = await _wait_until(func() -> bool: return _scene_name() == "LobbyBase", 8.0)
	_check(in_lobby, "lobby inicial carregado")
	if not in_lobby:
		_finish()
		return

	SaveManager.instance.use_test_save_dir("net_notebook_client")
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	var net: NetworkManager = NetworkManager.instance
	gs.reset_state()
	sm.expedition_ended.connect(func(summary_data: Dictionary) -> void: _summary = summary_data)

	var join_err: Error = net.join_game("127.0.0.1", PORT)
	print("CLIENT join=", join_err)
	_check(join_err == OK, "join_game na porta %d" % PORT)
	if join_err != OK:
		_finish()
		return

	var in_map: bool = await _wait_until(func() -> bool:
		return _scene_name() == "MapPraia" and sm.is_in_expedition(), 12.0)
	_check(in_map, "entrou em MapPraia em até 12 s")
	if not in_map:
		_finish()
		return

	var boot_ok: bool = await _wait_mark("boot_ready", 12.0)
	_check(boot_ok, "host sinalizou boot_ready")
	if not boot_ok:
		_finish()
		return

	var my_id: int = root.get_multiplayer().get_unique_id()
	var actors_settled: bool = await _wait_until(func() -> bool:
		var local_p: Player = HostSync.player_of(self, my_id) as Player
		var remote_p: Player = HostSync.player_of(self, 1) as Player
		var loading_hidden: bool = SessionUI.instance == null or SessionUI.instance.loading_screen == null or not SessionUI.instance.loading_screen.visible
		return local_p != null and remote_p != null and local_p.is_node_ready() and remote_p.is_node_ready() and local_p.is_on_floor() and loading_hidden, 8.0)
	_check(actors_settled, "atores local e remoto prontos no chão sem tela de carregamento")
	if not actors_settled:
		_finish()
		return

	var client_actor: Player = HostSync.player_of(self, my_id) as Player
	var remote_host: Player = HostSync.player_of(self, 1) as Player
	var client_book: Node = client_actor.get_node_or_null(^"HUD/ExpeditionNotebook")
	_check(client_book != null and client_actor.expedition_notebook == client_book, "cliente local montou HUD/ExpeditionNotebook")
	_check(remote_host.get_node_or_null(^"HUD/ExpeditionNotebook") == null and not remote_host.is_physics_processing(), "avatar remoto do host não monta caderno nem física local")
	if client_book == null:
		_finish()
		return

	# --- FASE 1: Cliente abre ExpeditionNotebook (Peer A); Host age livremente (Peer B) ---
	client_actor.inventory.take_all()
	var pitchfork_data: ToolData = gs.get_tool_data("forcado")
	_check(pitchfork_data != null, "fase 1: ToolData forcado disponível")
	if pitchfork_data != null:
		client_actor.inventory.add_item(CarriedItem.create_from_tool_data(pitchfork_data))
		client_actor.inventory.select(0)
	await _wait_physics(2)

	var hud_node: Node = client_actor.get_node(^"HUD")
	var prior_focus: Button = Button.new()
	prior_focus.name = "NotebookPriorFocusClient"
	hud_node.add_child(prior_focus)
	prior_focus.grab_focus()
	await _wait_frames(2)

	var prev_mouse: Input.MouseMode = Input.mouse_mode
	var remote_host_pos0: Vector3 = remote_host.global_position
	var open_key: InputEventKey = _key_event(KEY_G, true)
	_check(not bool(client_book.call(&"shortcut_conflicts", open_key)), "fase 1: atalho G sem conflito no cliente")
	await _tap_key(KEY_G)

	_check(bool(client_book.call(&"is_open_for", client_actor)) and client_actor.is_settings_open(), "fase 1: caderno abriu no cliente")
	_check(not paused and not PauseMenu.is_open(), "fase 1: abrir caderno no cliente não pausa a árvore nem abre PauseMenu")
	_check(not String(client_book.call(&"entry_text", "crab")).contains("Caranguejo"), "fase 1: criatura crab inicialmente oculta no Diário")
	_check(not String(client_book.call(&"entry_text", "king_crab")).contains("Caranguejo-Rei"), "fase 1: chefe king_crab inicialmente oculto no Diário")
	_check(String(client_book.call(&"entry_text", "item:moeda_antiga")).is_empty(), "fase 1: moeda_antiga inicialmente ausente na Coleção")
	var client_ach: AchievementsTab = client_book.get("_achievements") as AchievementsTab
	_check(client_ach != null and not client_ach.is_row_unlocked("boss_king_crab"), "fase 1: conquista boss_king_crab inicialmente bloqueada")

	await _verify_blocked_while_open(client_actor, client_book, "fase 1 (cliente)")

	var entries_before: Dictionary = client_book.get("_entries") as Dictionary
	var crab_btn_before: Button = entries_before.get("crab") as Button
	_check(crab_btn_before != null, "fase 1: linha crab presente para teste de foco")
	if crab_btn_before != null:
		crab_btn_before.grab_focus()
		await _wait_frames(1)

	_barrier.notify_step.rpc_id(1, "p1_client_open_verified", {"client_pos": client_actor.global_position})

	var p1_host_ok: bool = await _wait_mark("p1_host_acted", 15.0)
	_check(p1_host_ok, "fase 1: host caminhou e sincronizou descobertas")
	if not p1_host_ok:
		prior_focus.queue_free()
		_finish()
		return

	var live_synced: bool = await _wait_until(func() -> bool:
		return gs.discovered_items.has("moeda_antiga") and gs.seen_creatures.has("crab") and gs.is_boss_defeated("king_crab") and _flat_dist(remote_host.global_position, remote_host_pos0) > 0.6 and remote_host.held_tool_id == &"estilingue", 6.0)
	_check(live_synced, "fase 1: cliente com caderno aberto recebeu NetSync e state_synced do host")
	_check(bool(client_book.call(&"is_open_for", client_actor)) and not paused, "fase 1: caderno do cliente seguiu aberto e sem pausa durante sync")
	_check(String(client_book.call(&"entry_text", "crab")).contains("Caranguejo"), "fase 1: Diário atualizou criatura crab ao vivo")
	_check(String(client_book.call(&"entry_text", "king_crab")).contains("Caranguejo-Rei"), "fase 1: Diário atualizou chefe king_crab ao vivo")
	_check(String(client_book.call(&"entry_text", "item:moeda_antiga")).contains("Moeda Antiga"), "fase 1: Coleção atualizou item:moeda_antiga ao vivo")
	var collection_box: VBoxContainer = client_book.get("_collection") as VBoxContainer
	var museum_label: Label = null
	if collection_box != null and collection_box.get_child_count() > 0:
		museum_label = collection_box.get_child(0) as Label
	_check(museum_label != null and museum_label.text.contains("1/"), "fase 1: contador do Museu subiu para 1 item ao vivo")
	_check(client_ach != null and client_ach.is_row_unlocked("boss_king_crab"), "fase 1: conquista boss_king_crab desbloqueou ao vivo")
	var entries_after: Dictionary = client_book.get("_entries") as Dictionary
	var crab_btn_after: Button = entries_after.get("crab") as Button
	_check(crab_btn_after != null and root.gui_get_focus_owner() == crab_btn_after, "fase 1: refresh preservou foco na entrada crab")

	# --- Fechamento e restauração no Cliente ---
	await _tap_key(KEY_ESCAPE)
	_check(not bool(client_book.call(&"is_open_for", client_actor)) and not client_actor.is_settings_open(), "fase 1: Esc fechou o caderno do cliente")
	_check(not PauseMenu.is_open() and not paused, "fase 1: Esc consumido pelo caderno sem abrir PauseMenu")
	_check(Input.mouse_mode == prev_mouse, "fase 1: modo de cursor anterior restaurado no cliente")
	_check(root.gui_get_focus_owner() == prior_focus, "fase 1: foco anterior restaurado no cliente")
	prior_focus.queue_free()

	await _wait_physics(6)
	_check(client_actor.velocity.y <= 0.05 and not client_actor.dig_animator.is_playing() and is_equal_approx(float(client_actor.get("_attack_cooldown")), 0.0) and client_actor.inventory.get_count() == 1, "fase 1: nenhum pulo, golpe ou drop residual após fechar")

	Input.action_press(&"slot_2")
	await _wait_physics(2)
	Input.action_release(&"slot_2")
	_check(client_actor.inventory.selected_slot == 1, "fase 1: hotbar voltou a responder após fechar")

	var client_pos_before_resume: Vector3 = client_actor.global_position
	Input.action_press(&"move_forward")
	await _wait_physics(20)
	Input.action_release(&"move_forward")
	Input.action_press(&"attack")
	await _wait_physics(2)
	Input.action_release(&"attack")
	await _wait_physics(6)
	_check(_flat_dist(client_actor.global_position, client_pos_before_resume) > 0.6, "fase 1: cliente voltou a caminhar após fechar o caderno")
	_check(float(client_actor.get("_attack_cooldown")) > 0.0 or client_actor.dig_animator.is_playing(), "fase 1: cliente voltou a atacar após fechar o caderno")

	_barrier.notify_step.rpc_id(1, "p1_done", {"client_pos": client_actor.global_position})

	# --- FASE 2: Host abre ExpeditionNotebook (Peer A); Cliente age livremente (Peer B) ---
	var p2_open_ok: bool = await _wait_mark("p2_host_open_verified", 15.0)
	_check(p2_open_ok, "fase 2: host confirmou caderno aberto e bloqueio local")
	if not p2_open_ok:
		_finish()
		return

	var p2_host_info: Dictionary = _barrier.marks["p2_host_open_verified"] as Dictionary
	var p2_host_pos0: Vector3 = p2_host_info.get("host_pos", Vector3.ZERO) as Vector3
	_check(not paused, "fase 2: cliente permanece com get_tree().paused == false")
	_check(_flat_dist(remote_host.global_position, p2_host_pos0) < 0.08, "fase 2: avatar do host ficou imóvel no cliente")

	Input.action_press(&"slot_1")
	await _wait_physics(2)
	Input.action_release(&"slot_1")
	_check(client_actor.held_tool_id == &"forcado", "fase 2: cliente reequipou forcado para replicação NetSync")

	var client_p2_pos0: Vector3 = client_actor.global_position
	Input.action_press(&"move_right")
	await _wait_physics(24)
	Input.action_release(&"move_right")
	await _wait_physics(6)
	_check(_flat_dist(client_actor.global_position, client_p2_pos0) > 0.8, "fase 2: cliente caminhou livremente enquanto host consulta o caderno")

	gs.request_report_discovery("alianca_ouro", 400, true)
	gs.request_report_intact("alianca_ouro")
	var host_processed_rpc: bool = await _wait_until(func() -> bool:
		return gs.discovered_items.has("alianca_ouro") and gs.intact_items.has("alianca_ouro"), 6.0)
	_check(host_processed_rpc, "fase 2: autoridade do host processou request_report_discovery do cliente com caderno aberto")

	_barrier.notify_step.rpc_id(1, "p2_client_acted", {"client_pos": client_actor.global_position})

	# --- Retorno limpo ao LobbyBase ---
	var back_to_lobby: bool = await _wait_until(func() -> bool:
		return _scene_name() == "LobbyBase" and not _summary.is_empty() and not sm.is_in_expedition(), 15.0)
	var entries: Array = _summary.get("entries", []) as Array
	_check(back_to_lobby and gs.current_day == 2 and entries.size() == 2 and not paused, "cliente retornou ao LobbyBase no dia 2 com resumo de 2 entregas")
	_finish()
