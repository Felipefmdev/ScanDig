extends SceneTree
## Seleção, foco e visibilidade do catálogo durante atualizações do Museu.

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


func _select_item(list: ItemList, name: String) -> void:
	for index: int in list.item_count:
		if list.get_item_text(index).contains(name):
			list.select(index)
			list.item_selected.emit(index)
			return
	_check(false, "item não encontrado: " + name)


func _has_selected_item(list: ItemList, name: String) -> bool:
	var selected: PackedInt32Array = list.get_selected_items()
	return selected.size() == 1 and list.get_item_text(selected[0]).contains(name)


func _check_visible_row(list: ItemList, scroll: ScrollContainer) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.size() != 1:
		_check(false, "uma linha fica selecionada e visível após reordenar")
		return
	var row: Rect2 = list.get_item_rect(selected[0])
	row.position += list.global_position - Vector2(0.0, list.get_v_scroll_bar().value)
	_check(scroll.get_global_rect().encloses(row), "rolagem exibe a linha selecionada após reordenar")


func _capture() -> void:
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path: String = "user://museum229-%dx%d.png" % [root.size.x, root.size.y]
		_check(root.get_texture().get_image().save_png(path) == OK, "captura da seleção no Museu")


func _run() -> void:
	SaveManager.instance.use_test_save_dir("museum229")
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(15)
	TranslationServer.set_locale("pt_BR")
	var base: BaseStationUI = current_scene.get_node(^"UILayer/BaseStationUI") as BaseStationUI
	base.tab_container.current_tab = 1
	await _frames()
	var list: ItemList = base.museum_item_list
	var scroll: ScrollContainer = base.tab_container.get_current_tab_control() as ScrollContainer
	var filter: OptionButton = base.get_node(^"%MuseumCatalogFilter") as OptionButton
	var state: GameState = GameState.instance
	list.grab_focus()
	_select_item(list, "Anel do Poço")
	await _frames()
	_check(_has_selected_item(list, "Anel do Poço"), "seleção inicial do Anel do Poço")
	TranslationServer.set_locale("en")
	await _frames()
	_check(_has_selected_item(list, "Well Ring") and list.has_focus(), "troca de idioma mantém o item e o foco")
	_check_visible_row(list, scroll)
	await _capture()

	# Restaura o ponto de partida caso a primeira verificação falhe.
	if not _has_selected_item(list, "Well Ring"):
		_select_item(list, "Well Ring")
		await _frames()
	state.request_report_discovery("anel_do_poco", 0)
	await _frames()
	_check(_has_selected_item(list, "Well Ring") and list.has_focus(), "descoberta atualiza a linha sem perder seleção")
	_check_visible_row(list, scroll)

	# Há uma rolagem pendente quando o jogador sai da lista para usar o filtro.
	_select_item(list, "Signet Ring")
	filter.grab_focus()
	filter.select(2)
	filter.item_selected.emit(2)
	await _frames()
	_check(_has_selected_item(list, "Signet Ring") and filter.has_focus(), "filtro conserva a seleção e o foco do seletor")
	if DisplayServer.get_name() != "headless":
		_check(scroll.get_global_rect().encloses(filter.get_global_rect()), "rolagem pendente mantém o filtro visível")
	list.grab_focus()
	_select_item(list, "Signet Ring")
	await _frames()
	state.request_report_discovery("anel_sinete", 0)
	await _frames()
	_check(not list.is_anything_selected() and list.has_focus() and filter.selected == 2, "item descoberto sai de Pendentes sem selecionar outro")
	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
