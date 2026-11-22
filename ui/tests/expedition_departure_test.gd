extends SceneTree
## Partida rejeitada pela regra do host depois de aplicar um save ainda não carregado.

const FIELD_LOCK_REASON: String = "Vença o chefe Caranguejo-Rei (Praia) para liberar."

var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if not condition:
		_fails += 1
		print("FAIL " + description)


func _frames(count: int = 6) -> void:
	for frame: int in count:
		await process_frame


func _select_map(list: ItemList, index: int) -> void:
	list.select(index)
	list.item_selected.emit(index)


func _capture() -> void:
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path: String = "user://expedition231-%dx%d.png" % [root.size.x, root.size.y]
		_check(root.get_texture().get_image().save_png(path) == OK, "captura da recusa de partida")


func _run() -> void:
	var save: SaveManager = SaveManager.instance
	save.use_test_save_dir("expedition231")
	_check(save.save_to_file({"version": SaveManager.SAVE_VERSION, "team_money": 600}) == OK, "save isolado gravado")
	save.set_save_path(save.save_path)
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(15)
	TranslationServer.set_locale("pt_BR")
	var base: BaseStationUI = current_scene.get_node(^"UILayer/BaseStationUI") as BaseStationUI
	var session: SessionManager = SessionManager.instance
	var state: GameState = GameState.instance
	# O Campo aparece aberto no estado inicial da Base, mas o host aplica o slot pendente no pedido.
	state.load_snapshot({"team_money": 1500, "unlocked_maps": ["campo"], "defeated_bosses": ["king_crab"]})
	base.tab_container.current_tab = 2
	_select_map(base.map_list, 1)
	await _frames()
	_check(not base.depart_btn.disabled and base.depart_btn.text.contains("Campo Antigo"), "Campo disponível antes do pedido")
	base.depart_btn.grab_focus()
	base.depart_btn.pressed.emit()
	await _frames()
	_check(current_scene.scene_file_path == "res://world/lobby_base.tscn" and not session.is_in_expedition(), "recusa mantém a equipe na Base")
	_check(state.team_money == 600 and not state.is_map_unlocked("campo"), "o pedido realmente aplicou o slot")
	_check(base.depart_btn.disabled and base.map_status_label.is_visible_in_tree() and base.map_status_label.text.contains(FIELD_LOCK_REASON), "estado do destino revalidado")
	_check(base.expedition_feedback_label.text.is_empty(), "interface encerra preparação e mostra a recusa uma vez")
	await _capture()

	_select_map(base.map_list, 0)
	_check(not base.depart_btn.disabled and base.expedition_feedback_label.text.is_empty(), "destino válido permite tentar novamente sem mensagem obsoleta")
	base.depart_btn.pressed.emit()
	await _frames(30)
	_check(session.is_in_expedition() and current_scene.scene_file_path == "res://world/map_praia.tscn", "nova tentativa parte para a Praia")
	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
