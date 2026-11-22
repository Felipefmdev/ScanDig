extends SceneTree
## Verifica ordenação localizada usando os nomes reais nas três visões do Museu.

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


func _index_of(list: ItemList, name: String) -> int:
	for index: int in list.item_count:
		if list.get_item_text(index).contains(name):
			return index
	return -1


func _assert_order(list: ItemList, first: String, second: String) -> void:
	var first_index: int = _index_of(list, first)
	var second_index: int = _index_of(list, second)
	_check(first_index >= 0 and second_index > first_index, "%s vem antes de %s (%d, %d)" % [first, second, first_index, second_index])


func _capture() -> void:
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path: String = "user://museum227-%dx%d-en.png" % [root.size.x, root.size.y]
		_check(root.get_texture().get_image().save_png(path) == OK, "captura do catálogo em inglês")


func _run() -> void:
	SaveManager.instance.use_test_save_dir("museum227")
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(15)
	TranslationServer.set_locale("pt_BR")
	var base: BaseStationUI = current_scene.get_node(^"UILayer/BaseStationUI") as BaseStationUI
	base.tab_container.current_tab = 1
	var state: GameState = GameState.instance
	state.request_report_discovery("anel_do_poco", 0)
	state.request_report_discovery("coroa_caranguejo_rei", 0)
	await _frames()
	var list: ItemList = base.museum_item_list
	var total: int = list.item_count
	var filter: OptionButton = base.get_node(^"%MuseumCatalogFilter") as OptionButton
	var dev_select: OptionButton = base.item_select_box
	for index: int in dev_select.item_count:
		if dev_select.get_item_text(index).begins_with("Anel do Poço"):
			dev_select.select(index)
			break

	_assert_order(list, "Cálice de Prata", "Cenoura de Ouro")
	_assert_order(list, "Geodo Estrelar", "Ídolo de Jade")
	_assert_order(list, "Ídolo de Jade", "Lanterna da Expedição Perdida")
	TranslationServer.set_locale("en")
	await _frames()
	_assert_order(list, "Bronze Bell", "Ceremonial Dagger")
	_assert_order(list, "Signet Ring", "Well Ring")
	_check(filter.selected == 0 and list.item_count == total, "Todos e contagem sobrevivem à troca de idioma")
	_check(dev_select.selected >= 0 and dev_select.get_item_text(dev_select.selected).begins_with("Well Ring"), "simulação continua selecionando o mesmo item")
	await _capture()

	filter.select(1)
	filter.item_selected.emit(1)
	await _frames()
	_assert_order(list, "King Crab's Crown", "Well Ring")
	TranslationServer.set_locale("pt_BR")
	await _frames()
	_assert_order(list, "Anel do Poço", "Coroa do Caranguejo-Rei")
	_check(filter.selected == 1 and list.item_count == 2, "Descobertos permanece ativo com os mesmos itens")

	filter.select(2)
	filter.item_selected.emit(2)
	await _frames()
	_assert_order(list, "Cálice de Prata", "Cenoura de Ouro")
	TranslationServer.set_locale("en")
	await _frames()
	_assert_order(list, "Golden Carrot", "Silver Chalice")
	_check(filter.selected == 2 and list.item_count == total - 2, "Pendentes permanece ativo com os mesmos itens")
	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
