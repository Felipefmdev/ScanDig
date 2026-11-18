## Teste headless (#212): par coop ENet de 2 fases para o ExpeditionNotebook.
## Par: core/tests/net_notebook_client.gd (porta 7814). Save isolado em user://test_saves/net_notebook_host.
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


## Barreira dedicada de teste no canal reliable 0, sem misturar estado de economia/gameplay.
class NotebookBarrier extends Node:
	var marks: Dictionary = {}

	@rpc("any_peer", "call_remote", "reliable", 0)
	func notify_step(step: String, payload: Dictionary = {}) -> void:
		marks[step] = payload.duplicate(true)


var _barrier: NotebookBarrier = null
var _fails: int = 0
var _client_id: int = 0


func _initialize() -> void:
	_barrier = NotebookBarrier.new()
	_barrier.name = "NetNotebookBarrier"
	root.add_child(_barrier)
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	print(("HOST PASS " if cond else "HOST FAIL ") + msg)
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
	print("HOST RESULT fails=%d" % _fails)
	quit(_fails)


func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	var in_lobby: bool = await _wait_until(func() -> bool: return _scene_name() == "LobbyBase", 8.0)
	_check(in_lobby, "lobby inicial carregado")
	if not in_lobby:
		_finish()
		return

	SaveManager.instance.use_test_save_dir("net_notebook_host")
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	var net: NetworkManager = NetworkManager.instance
	gs.reset_state()

	root.get_multiplayer().peer_connected.connect(func(peer_id: int) -> void:
		if peer_id != 1 and _client_id == 0:
			_client_id = peer_id)

	var host_err: Error = net.host_game(PORT)
	print("HOST host_game=", host_err)
	_check(host_err == OK, "host_game na porta %d" % PORT)
	if host_err != OK:
		_finish()
		return

	sm.request_start_expedition("praia")
	var joined: bool = await _wait_until(func() -> bool: return _client_id != 0, 20.0)
	_check(joined, "cliente conectou em até 20 s")
	if not joined:
		_finish()
		return

	var both_ready: bool = await _wait_until(func() -> bool:
		return sm.is_peer_scene_ready(1) and sm.is_peer_scene_ready(_client_id), 12.0)
	_check(both_ready, "host e cliente prontos em MapPraia")
	if not both_ready:
		_finish()
		return

	var actors_settled: bool = await _wait_until(func() -> bool:
		var local_p: Player = HostSync.player_of(self, 1) as Player
		var remote_p: Player = HostSync.player_of(self, _client_id) as Player
		var loading_hidden: bool = SessionUI.instance == null or SessionUI.instance.loading_screen == null or not SessionUI.instance.loading_screen.visible
		return local_p != null and remote_p != null and local_p.is_node_ready() and remote_p.is_node_ready() and local_p.is_on_floor() and loading_hidden, 8.0)
	_check(actors_settled, "atores local e remoto prontos no chão sem tela de carregamento")
	if not actors_settled:
		_finish()
		return

	var host_actor: Player = HostSync.player_of(self, 1) as Player
	var remote_client: Player = HostSync.player_of(self, _client_id) as Player
	var host_book: Node = host_actor.get_node_or_null(^"HUD/ExpeditionNotebook")
	_check(host_book != null and host_actor.expedition_notebook == host_book, "host local montou HUD/ExpeditionNotebook")
	_check(remote_client.get_node_or_null(^"HUD/ExpeditionNotebook") == null and not remote_client.is_physics_processing(), "avatar remoto do cliente não monta caderno nem física local")
	if host_book == null:
		_finish()
		return

	_barrier.notify_step.rpc_id(_client_id, "boot_ready", {"host_pos": host_actor.global_position})

	# --- FASE 1: Cliente abre ExpeditionNotebook (Peer A); Host age livremente (Peer B) ---
	var p1_open_ok: bool = await _wait_mark("p1_client_open_verified", 15.0)
	_check(p1_open_ok, "fase 1: cliente confirmou caderno aberto e bloqueio local")
	if not p1_open_ok:
		_finish()
		return

	var p1_client_info: Dictionary = _barrier.marks["p1_client_open_verified"] as Dictionary
	var p1_client_pos0: Vector3 = p1_client_info.get("client_pos", Vector3.ZERO) as Vector3
	_check(not paused, "fase 1: host permanece com get_tree().paused == false")
	_check(_flat_dist(remote_client.global_position, p1_client_pos0) < 0.08, "fase 1: avatar do cliente ficou imóvel no host")

	host_actor.inventory.take_all()
	var slingshot_data: ToolData = gs.get_tool_data("estilingue")
	_check(slingshot_data != null, "fase 1: ToolData estilingue disponível")
	if slingshot_data != null:
		host_actor.inventory.add_item(CarriedItem.create_from_tool_data(slingshot_data))
		host_actor.inventory.select(0)
	await _wait_physics(2)
	_check(host_actor.held_tool_id == &"estilingue", "fase 1: host equipou estilingue")

	var host_pos_before_walk: Vector3 = host_actor.global_position
	Input.action_press(&"move_forward")
	await _wait_physics(24)
	Input.action_release(&"move_forward")
	await _wait_physics(6)
	_check(_flat_dist(host_actor.global_position, host_pos_before_walk) > 0.8, "fase 1: host caminhou livremente enquanto cliente consulta o caderno")

	gs.request_report_discovery("moeda_antiga", 120)
	gs.report_creature("crab")
	gs.request_report_boss_defeated("king_crab")
	_barrier.notify_step.rpc_id(_client_id, "p1_host_acted", {"host_pos": host_actor.global_position})

	var p1_done_ok: bool = await _wait_mark("p1_done", 15.0)
	_check(p1_done_ok, "fase 1: cliente validou sync ao vivo, fechou caderno e retomou ações")
	if not p1_done_ok:
		_finish()
		return

	var p1_done_info: Dictionary = _barrier.marks["p1_done"] as Dictionary
	var p1_client_after: Vector3 = p1_done_info.get("client_pos", p1_client_pos0) as Vector3
	var client_walk_replicated: bool = await _wait_until(func() -> bool:
		return _flat_dist(remote_client.global_position, p1_client_pos0) > 0.5 and _flat_dist(remote_client.global_position, p1_client_after) < 0.35, 5.0)
	_check(client_walk_replicated, "fase 1: movimento pós-fechamento do cliente replicou ao host")

	# --- FASE 2: Host abre ExpeditionNotebook (Peer A); Cliente age livremente (Peer B) ---
	var hud_node: Node = host_actor.get_node(^"HUD")
	var prior_focus: Button = Button.new()
	prior_focus.name = "NotebookPriorFocusHost"
	hud_node.add_child(prior_focus)
	prior_focus.grab_focus()
	await _wait_frames(2)

	var prev_mouse: Input.MouseMode = Input.mouse_mode
	var host_p2_pos0: Vector3 = host_actor.global_position
	var remote_p2_pos0: Vector3 = remote_client.global_position
	var open_key: InputEventKey = _key_event(KEY_G, true)
	_check(not bool(host_book.call(&"shortcut_conflicts", open_key)), "fase 2: atalho G sem conflito no host")
	await _tap_key(KEY_G)

	_check(bool(host_book.call(&"is_open_for", host_actor)) and host_actor.is_settings_open(), "fase 2: caderno abriu no host")
	_check(not paused and not PauseMenu.is_open(), "fase 2: abrir caderno no host não pausa a árvore nem abre PauseMenu")
	_check(String(host_book.call(&"entry_text", "item:alianca_ouro")).is_empty(), "fase 2: aliança de ouro ainda não consta na Coleção")
	var host_ach: AchievementsTab = host_book.get("_achievements") as AchievementsTab
	_check(host_ach != null and not host_ach.is_row_unlocked("rare_find"), "fase 2: conquista rare_find inicialmente bloqueada")

	await _verify_blocked_while_open(host_actor, host_book, "fase 2 (host)")

	var entries_before: Dictionary = host_book.get("_entries") as Dictionary
	var boss_btn_before: Button = entries_before.get("king_crab") as Button
	_check(boss_btn_before != null, "fase 2: linha king_crab presente para teste de foco")
	if boss_btn_before != null:
		boss_btn_before.grab_focus()
		await _wait_frames(1)

	_barrier.notify_step.rpc_id(_client_id, "p2_host_open_verified", {"host_pos": host_p2_pos0})

	var p2_client_ok: bool = await _wait_mark("p2_client_acted", 15.0)
	_check(p2_client_ok, "fase 2: cliente moveu e enviou request_report_discovery")
	if not p2_client_ok:
		prior_focus.queue_free()
		_finish()
		return

	var live_synced: bool = await _wait_until(func() -> bool:
		return gs.discovered_items.has("alianca_ouro") and gs.intact_items.has("alianca_ouro") and _flat_dist(remote_client.global_position, remote_p2_pos0) > 0.6 and remote_client.held_tool_id == &"forcado", 6.0)
	_check(live_synced, "fase 2: host com caderno aberto processou RPCs e NetSync do cliente")
	_check(bool(host_book.call(&"is_open_for", host_actor)) and not paused, "fase 2: caderno do host seguiu aberto e sem pausa durante sync")
	_check(String(host_book.call(&"entry_text", "item:alianca_ouro")).contains("Aliança de Ouro"), "fase 2: Coleção do host atualizou item:alianca_ouro ao vivo")
	var collection_box: VBoxContainer = host_book.get("_collection") as VBoxContainer
	var museum_label: Label = null
	if collection_box != null and collection_box.get_child_count() > 0:
		museum_label = collection_box.get_child(0) as Label
	_check(museum_label != null and museum_label.text.contains("2/"), "fase 2: contador do Museu subiu para 2 itens ao vivo")
	_check(host_ach != null and host_ach.is_row_unlocked("rare_find"), "fase 2: conquista rare_find desbloqueou ao vivo no caderno do host")
	var entries_after: Dictionary = host_book.get("_entries") as Dictionary
	var boss_btn_after: Button = entries_after.get("king_crab") as Button
	_check(boss_btn_after != null and root.gui_get_focus_owner() == boss_btn_after, "fase 2: refresh preservou foco na entrada king_crab")

	# --- Fechamento e restauração no Host ---
	await _tap_key(KEY_ESCAPE)
	_check(not bool(host_book.call(&"is_open_for", host_actor)) and not host_actor.is_settings_open(), "fase 2: Esc fechou o caderno do host")
	_check(not PauseMenu.is_open() and not paused, "fase 2: Esc consumido pelo caderno sem abrir PauseMenu")
	_check(Input.mouse_mode == prev_mouse, "fase 2: modo de cursor anterior restaurado no host")
	_check(root.gui_get_focus_owner() == prior_focus, "fase 2: foco anterior restaurado no host")
	prior_focus.queue_free()

	await _wait_physics(6)
	_check(host_actor.velocity.y <= 0.05 and not host_actor.dig_animator.is_playing() and is_equal_approx(float(host_actor.get("_attack_cooldown")), 0.0) and host_actor.inventory.get_count() == 1, "fase 2: nenhum pulo, golpe ou drop residual após fechar")

	Input.action_press(&"slot_2")
	await _wait_physics(2)
	Input.action_release(&"slot_2")
	_check(host_actor.inventory.selected_slot == 1, "fase 2: hotbar voltou a responder após fechar")

	var host_pos_before_resume: Vector3 = host_actor.global_position
	Input.action_press(&"move_forward")
	await _wait_physics(16)
	Input.action_release(&"move_forward")
	Input.action_press(&"attack")
	await _wait_physics(2)
	Input.action_release(&"attack")
	await _wait_physics(4)
	_check(_flat_dist(host_actor.global_position, host_pos_before_resume) > 0.5, "fase 2: host voltou a caminhar após fechar o caderno")
	_check(float(host_actor.get("_attack_cooldown")) > 0.0 or host_actor.dig_animator.is_playing(), "fase 2: host voltou a atacar após fechar o caderno")

	# --- Encerramento limpo da expedição ---
	sm.request_end_expedition()
	var returned: bool = await _wait_until(func() -> bool:
		return _scene_name() == "LobbyBase" and not sm.is_in_expedition(), 15.0)
	_check(returned and gs.current_day == 2 and sm.get_ready_peers().is_empty() and not paused, "host retornou ao LobbyBase no dia 2 sem pausa")

	var client_left: bool = await _wait_until(func() -> bool: return net.connected_players.size() == 1, 12.0)
	_check(client_left, "cliente desconectou de forma limpa ao concluir")
	_finish()
