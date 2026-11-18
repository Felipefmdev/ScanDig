extends "res://ui/tests/hud_212_snapshots.gd"

## #212: integração do Player real, física ativa, hotbar e diário existente.
var _capture_access: bool = false
var _player: Player = null
var _book: Node = null


func _ticks(count: int) -> void:
	for _tick: int in count:
		await physics_frame


func _send_key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(3)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(3)


func _send_pad(button: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(3)
	event = event.duplicate() as InputEventJoypadButton
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(3)


func _access_shot(label: String) -> void:
	if _capture_access:
		await _shot(label)


func _record_access(stage: String) -> void:
	var focus: Control = root.gui_get_focus_owner()
	print("ACCESS_STATE " + JSON.stringify({"stage": stage,
		"scene": str(current_scene.get_path()) if current_scene != null else "",
		"local": _player.is_local(), "alive": _player.is_alive(),
		"context": bool(_book.call(&"_valid_context")), "other_modal": bool(_book.call(&"_other_modal")),
		"book_open": bool(_book.call(&"is_open_for", _player)), "paused": paused,
		"pause_open": PauseMenu.is_open(), "mouse": Input.mouse_mode,
		"focus": str(focus.get_path()) if focus != null else ""}))


func _slots(capacity: int, filled: bool, text_scale: float) -> void:
	_seed_game_state_quietly({"team_money": 82, "upgrade_levels": {"backpack": capacity - 3}})
	_player._apply_backpack_capacity()
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": text_scale}, false)
	_fill_inventory(_player, capacity if filled else 0)
	if filled:
		_player.inventory.remove_at(capacity - 1)
		_player.inventory.add_item(CarriedItem.create_from_tool_data(load("res://items/tools/dinamite.tres") as ToolData))
	_player.inventory.select(capacity - 1)
	await _frames(12)
	if filled and _capture_access:
		for _attempt: int in 120:
			var ready: bool = true
			for panel: PanelContainer in _player.hotbar._slot_panels:
				ready = ready and (panel.get_node(^"Box/Art/Icon") as TextureRect).texture != null
			if ready:
				break
			await process_frame
	_check(_player.hotbar._slot_panels.size() == capacity, "hotbar preserva %d slots" % capacity)
	var bar: Rect2 = _player.hotbar.get_global_rect()
	var max_side: float = 48.0 if is_equal_approx(text_scale, 1.0) else 64.0
	for index: int in capacity:
		var panel: PanelContainer = _player.hotbar._slot_panels[index]
		var style: StyleBoxFlat = panel.get_theme_stylebox(&"panel") as StyleBoxFlat
		_check(panel.size.x <= max_side + 0.5 and panel.size.y <= max_side + 0.5, "slot compacto %d: %s teto%.0f" % [index, panel.size, max_side])
		_check(style.shadow_size == 0 and panel.scale == Vector2.ONE, "slot sem glow ou zoom %d" % index)
		_check(style.content_margin_left <= 2.0 and style.content_margin_right <= 2.0, "padding compacto %d" % index)
		var key: Label = panel.get_node(^"Overlay/Key") as Label
		_check(key.text == str(index + 1) and key.is_visible_in_tree(), "tecla legivel %d" % index)
		_check(key.get_theme_font_size(&"font_size") == roundi(13.0 * text_scale), "tecla acompanha escala de texto %d" % index)
		if filled:
			var icon: TextureRect = panel.get_node(^"Box/Art/Icon") as TextureRect
			if _capture_access:
				_check(icon.is_visible_in_tree() and icon.texture != null and icon.size.x >= 24.0, "icone real legivel %d" % index)
			_check((panel.get_node(^"Overlay/TypeMark") as TextureRect).texture != null, "tipo do item preservado %d" % index)
		if index == capacity - 1:
			_check(style.border_color.is_equal_approx(UiPalette.GOLD) and style.border_width_left == 2, "selecao GOLD2 sem brilho")
			if filled:
				var count_label: Label = panel.get_node_or_null(^"Overlay/Count") as Label
				_check(count_label != null and count_label.text == str(_player.inventory.get_item(index).charges) and count_label.is_visible_in_tree(), "cargas do consumivel continuam legiveis")
	_check(_player.hotbar.get_theme_constant(&"separation") == 4, "gap4 entre slots")
	var vitals: Control = _player.get_node(^"HUD/HealthPanel") as Control
	print("HOTBAR_GEOMETRY " + JSON.stringify({"capacity": capacity, "filled": filled, "text_scale": text_scale,
		"viewport": str(root.get_visible_rect()), "bar": str(bar), "vitals": str(vitals.get_global_rect()),
		"expedition": str(SessionUI.instance.expedition_bar.get_global_rect()), "band": str(_player.hotbar._band())}))
	_check(not bar.intersects(vitals.get_global_rect()), "hotbar sem colisao com vitais")
	_check(not bar.intersects(SessionUI.instance.expedition_bar.get_global_rect()), "hotbar sem colisao com mapa/dia")
	_check(root.get_visible_rect().encloses(bar), "hotbar dentro da viewport")
	var hint: Label = _book.get_node_or_null(^"AccessHint") as Label
	_check(hint != null and hint.is_visible_in_tree(), "indicacao discreta Diario G disponivel")
	if hint != null:
		_check(not hint.get_global_rect().intersects(bar) and not hint.get_global_rect().intersects(vitals.get_global_rect()), "indicacao nao colide com hotbar/vitais")
	await _access_shot("slots%d_%s_s%d" % [capacity, "full" if filled else "empty", roundi(text_scale * 100)])


func _wear_indicator_case() -> void:
	_seed_game_state_quietly({"team_money": 82, "upgrade_levels": {"backpack": 0}})
	_player._apply_backpack_capacity()
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.5}, false)
	_player.inventory.take_all()
	var tool_data: ToolData = load("res://items/tools/arpao_corda.tres") as ToolData
	_check(tool_data != null and tool_data.durability >= 80, "ferramenta real com durabilidade carregada")
	if tool_data == null:
		return
	var worn_tool: CarriedItem = CarriedItem.create_from_tool_data(tool_data)
	worn_tool.wear = 50
	_check(_player.inventory.add_item(worn_tool), "arma com desgaste normal entra no slot compacto")
	_player.inventory.select(0)
	await _frames(12)
	var panel: PanelContainer = _player.hotbar._slot_panels[0]
	var bar_before: Rect2 = _player.hotbar.get_global_rect()
	var slot_before: Vector2 = panel.size
	var icon: TextureRect = panel.get_node(^"Box/Art/Icon") as TextureRect
	if _capture_access:
		for _attempt: int in 120:
			if icon.texture != null:
				break
			await process_frame
		_check(icon.is_visible_in_tree() and icon.texture != null and icon.size.x >= 24.0, "arma desgastada usa icone real legivel")
	var value_label: Label = panel.get_node(^"Box/Value") as Label
	var overlay_count: Label = panel.get_node(^"Overlay/Count") as Label
	_check(value_label != null and not value_label.is_visible_in_tree(), "nome/valor continuam ocultos no layout compacto")
	_check(overlay_count != null and overlay_count.is_visible_in_tree(), "indicador de desgaste fica visivel no overlay compacto")
	_check(overlay_count != null and overlay_count.text == "63%", "desgaste normal exibe percentual restante arredondado")
	if overlay_count != null:
		_check(overlay_count.get_theme_color(&"font_color") != UiPalette.RED_BURNT, "desgaste normal nao usa alerta vermelho")
	await _access_shot("weapon_wear_normal_s150")
	worn_tool.wear = 10
	_player.inventory.notify_changed()
	await _frames(3)
	_check(overlay_count != null and overlay_count.is_visible_in_tree(), "indicador de desgaste baixo permanece visivel")
	_check(overlay_count != null and overlay_count.text == "13%", "desgaste baixo atualiza percentual restante")
	if overlay_count != null:
		_check(overlay_count.get_theme_color(&"font_color").is_equal_approx(UiPalette.RED_BURNT), "desgaste baixo usa alerta vermelho")
	_check(_player.hotbar.get_global_rect().is_equal_approx(bar_before), "indicador nao altera a geometria da hotbar")
	_check(panel.size.is_equal_approx(slot_before) and panel.size.x <= 64.0, "indicador cabe no mesmo slot compacto")
	await _access_shot("weapon_wear_low_s150")


func _run() -> void:
	_out_dir = "res://.bot_runs/qa212/access/shots/"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.trim_prefix("--out-dir=") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_tag = "%dx%d" % [root.size.x, root.size.y]
	SaveManager.instance.use_test_save_dir("notebook_access")
	await _frames(2)
	print("USERDATA %s SAVE %s" % [OS.get_user_data_dir(), ProjectSettings.globalize_path(SaveManager.instance.save_path)])
	var session: Node = root.get_node(^"CoreSession")
	session.set("_current_map", null)
	SessionUI.instance._synced_once = false
	GameState.instance.reset_state()
	SessionUI.instance._clear_toasts()
	var arena: Node3D = _build_arena()
	root.add_child(arena)
	current_scene = arena
	_player = PLAYER_SCENE.instantiate() as Player
	arena.add_child(_player)
	await _ticks(10)
	session.set("_current_map", load("res://items/maps/praia.tres"))
	SessionUI.instance.loading_screen.hide()
	SessionUI.instance._refresh_expedition_bar()
	_book = _player.get_node_or_null(^"HUD/ExpeditionNotebook")
	_check(_book != null, "Player instancia e vincula diario existente")
	if _book == null:
		# Baseline permite exercitar a UI preexistente, sem fingir integração do Player.
		_book = (load("res://ui/expedition_notebook.gd") as GDScript).new()
		_player.get_node(^"HUD").add_child(_book)
		_book.call(&"bind", _player)
		print("BASELINE notebook montado somente pela fixture; integracao continua RED")
	for text_scale: float in [1.0, 1.5]:
		for capacity: int in [3, 8]:
			await _slots(capacity, false, text_scale)
			await _slots(capacity, true, text_scale)
	await _wear_indicator_case()
	_player.inventory.select(0)
	_player.velocity = Vector3.ZERO
	var previous_mouse: Input.MouseMode = Input.mouse_mode
	if _capture_access:
		_check(previous_mouse == Input.MOUSE_MODE_CAPTURED, "renderer: Player iniciou com cursor capturado")
	else:
		print("LIMIT headless mede restauracao do modo anterior; nao comprova CAPTURED no sistema")
	_record_access("before_g")
	_check(bool(_book.call(&"_valid_context")) and not bool(_book.call(&"_other_modal")), "precondicao: contexto valido sem modal antes do G")
	await _send_key(KEY_G)
	_check(bool(_book.call(&"is_open_for", _player)), "G abre diario real")
	if not bool(_book.call(&"is_open_for", _player)):
		_book.call(&"open")
	_record_access("after_open_or_baseline")
	_check(bool(_book.call(&"is_open_for", _player)), "precondicao: diario aberto para medir gates")
	_check(not paused and _player.is_physics_processing(), "diario nao pausa arvore nem desliga fisica")
	_check(_player.is_settings_open(), "gate do Player reconhece diario aberto")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "diario libera cursor")
	var position_before: Vector3 = _player.global_position
	Input.action_press(&"move_forward")
	await _ticks(12)
	Input.action_release(&"move_forward")
	_check(Vector2(_player.global_position.x - position_before.x, _player.global_position.z - position_before.z).length() < 0.02, "movimento mantido bloqueado com tecla segurada")
	var selected_before: int = _player.inventory.selected_slot
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	_player._unhandled_input(wheel)
	_check(_player.inventory.selected_slot == selected_before and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "diario bloqueia hotbar e recaptura do mouse")
	var yaw_before: float = _player.rotation.y
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(40.0, 20.0)
	_player._unhandled_input(motion)
	_check(is_equal_approx(_player.rotation.y, yaw_before), "diario bloqueia olhar local")
	_player._jump_buffer_left = 0.1
	_player._coyote_left = 0.1
	_player._physics_process(0.016)
	_check(_player.velocity.y <= 0.0, "diario bloqueia salto previamente armazenado no buffer")
	_player.is_ziplining = true
	var jump: InputEventAction = InputEventAction.new()
	jump.action = &"jump"
	jump.pressed = true
	_player._unhandled_input(jump)
	_check(_player.is_ziplining, "gate de input antecede salto da tirolesa")
	_player._physics_process(0.016)
	_check(_player.is_ziplining, "gate de fisica antecede processamento da tirolesa")
	_player.is_ziplining = false
	await _access_shot("diary_open")
	_record_access("before_escape")
	var cancel_event: InputEventKey = InputEventKey.new()
	cancel_event.keycode = KEY_ESCAPE
	cancel_event.physical_keycode = KEY_ESCAPE
	cancel_event.pressed = true
	_check(cancel_event.is_action_pressed(&"ui_cancel", false, true), "precondicao: Esc injetado corresponde a ui_cancel real")
	await _send_key(KEY_ESCAPE)
	_record_access("after_escape")
	_check(not bool(_book.call(&"is_open_for", _player)) and not PauseMenu.is_open(), "Esc fecha diario sem abrir pausa")
	_check(Input.mouse_mode == previous_mouse, "fechar diario restaura modo de cursor anterior")
	await _send_key(KEY_G)
	await _send_key(KEY_G)
	_check(not bool(_book.call(&"is_open_for", _player)), "G tambem fecha diario")
	await _send_pad(JOY_BUTTON_BACK)
	_record_access("after_select_open")
	_check(bool(_book.call(&"is_open_for", _player)), "Select abre diario")
	await _send_pad(JOY_BUTTON_BACK)
	_check(not bool(_book.call(&"is_open_for", _player)), "Select fecha diario")
	var conflict: InputEventKey = InputEventKey.new()
	conflict.physical_keycode = KEY_G
	InputMap.add_action(&"access_test_conflict")
	InputMap.action_add_event(&"access_test_conflict", conflict)
	await _send_key(KEY_G)
	_check(not bool(_book.call(&"is_open_for", _player)), "G remapeado nao e consumido pelo diario")
	InputMap.erase_action(&"access_test_conflict")
	_book.call(&"open")
	PauseMenu.instance.open()
	await _frames(4)
	_check(not bool(_book.call(&"is_open_for", _player)) and root.gui_get_focus_owner() == PauseMenu.instance.continue_button, "modal superveniente conserva seu foco")
	PauseMenu.instance.close()
	paused = false
	session.set("_current_map", null)
	SessionUI.instance._synced_once = false
	SessionUI.instance._clear_toasts()
	SessionUI.instance._refresh_expedition_bar()
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.0}, false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arena.queue_free()
	await _frames(6)
	print("RESULT fails=%d" % _fails)
	quit(_fails)
