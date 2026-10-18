extends GutTest

## Pergaminho desenhado do Mapa do Tesouro (#117): TreasureMapParchment (subclasse do
## TreasureMapScroll do Dev A). Peça achada = trecho do mapa recortado; peça em falta = papel
## rasgado; a arte continua entre peças vizinhas; o X da Ilha só com o mapa completo.

const BASE_STATION_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")


func before_each() -> void:
	GameState.instance.reset_state()


func after_each() -> void:
	GameState.instance.reset_state()


func _parchment(found: Array[String]) -> TreasureMapParchment:
	var p: TreasureMapParchment = TreasureMapParchment.new()
	add_child_autofree(p)
	p.size = Vector2(540.0, 180.0)
	p.found = found
	return p


## O _draw roda no frame seguinte ao queue_redraw.
func _drawn(p: TreasureMapParchment) -> void:
	p.queue_redraw()
	await wait_frames(2)


func _cell(id: String) -> Vector2i:
	return GameState.MAP_FRAGMENTS[id]["piece"]


func _tags(p: TreasureMapParchment, cell: Vector2i) -> Array:
	return p.debug_ops[cell]["tags"]


func test_is_a_treasure_map_scroll() -> void:
	var p: TreasureMapParchment = _parchment([])
	assert_true(p is TreasureMapScroll, "o teste do Dev A (as TreasureMapScroll) continua valendo")
	assert_eq(p.custom_minimum_size.y, TreasureMapParchment.MIN_HEIGHT)
	assert_eq(p.focus_mode, Control.FOCUS_NONE, "só visual: o foco da aba não fica preso nele")
	assert_eq(p.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_piece_state() -> void:
	var p: TreasureMapParchment = _parchment(["praia_frag_1", "cratera_frag_2"])
	assert_eq(p.piece_state(_cell("praia_frag_1")), "found")
	assert_eq(p.piece_state(_cell("cratera_frag_2")), "found")
	assert_eq(p.piece_state(_cell("campo_frag_1")), "missing")


func test_found_and_missing_draw_differently() -> void:
	var p: TreasureMapParchment = _parchment(["praia_frag_1", "ruinas_frag_1"])
	await _drawn(p)
	assert_eq(p.debug_ops.size(), 8, "as 8 peças desenhadas")
	for row: int in TreasureMapScroll.ROWS:
		for col: int in TreasureMapScroll.COLS:
			var cell: Vector2i = Vector2i(col, row)
			var ops: Dictionary = p.debug_ops[cell]
			assert_eq(ops["state"], p.piece_state(cell))
			if ops["state"] == "missing":
				assert_eq(ops["tags"], ["torn"], "peça em falta: só o papel rasgado %s" % cell)
			else:
				assert_gt(int(ops["polygons"]) + int(ops["lines"]), 3, "peça achada tem desenho %s" % cell)
				assert_true(_tags(p, cell).has("route"), "o caminho passa por %s" % cell)
	assert_true(_tags(p, _cell("praia_frag_1")).has("sea"), "a Praia tem mar")
	assert_true(_tags(p, _cell("praia_frag_1")).has("praia"))
	assert_true(_tags(p, _cell("ruinas_frag_1")).has("ruinas"))


func test_complete_map_art_continues_between_pieces() -> void:
	var p: TreasureMapParchment = _parchment(GameState.MAP_FRAGMENT_IDS.duplicate())
	await _drawn(p)
	for id: String in GameState.MAP_FRAGMENT_IDS:
		assert_true(_tags(p, _cell(id)).has("route"), "caminho em %s" % id)
	# O cone da Cratera e o pico do meio da Geleira atravessam a linha entre as duas fileiras.
	assert_true(_tags(p, Vector2i(3, 0)).has("cratera") and _tags(p, Vector2i(3, 1)).has("cratera"))
	assert_true(_tags(p, Vector2i(2, 0)).has("geleira") and _tags(p, Vector2i(2, 1)).has("geleira"))
	# As Ruínas ocupam as duas peças de cima à esquerda.
	assert_true(_tags(p, Vector2i(0, 0)).has("ruinas") and _tags(p, Vector2i(1, 0)).has("ruinas"))
	assert_true(_tags(p, TreasureMapParchment.COMPASS_CELL).has("compass"))
	for cell: Vector2i in p.debug_ops:
		if cell != TreasureMapParchment.ISLAND_CELL:
			assert_false(_tags(p, cell).has("island"), "a Ilha só na peça %s" % TreasureMapParchment.ISLAND_CELL)
		if cell != TreasureMapParchment.COMPASS_CELL:
			assert_false(_tags(p, cell).has("compass"))
	for label: String in ["Praia", "Campo", "Ruínas", "Geleira", "Cratera", "Ilha"]:
		var shown: bool = false
		for cell: Vector2i in p.debug_ops:
			shown = shown or _tags(p, cell).has("label:" + label)
		assert_true(shown, "nome %s cabe numa peça" % label)


func test_island_cell_is_the_last_piece() -> void:
	assert_eq(_cell("cratera_frag_2"), TreasureMapParchment.ISLAND_CELL, "a Ilha fica na última peça")
	var last: Vector2 = TreasureMapScroll.ROUTE_POINTS[TreasureMapScroll.ROUTE_POINTS.size() - 1]
	var cell: Vector2i = Vector2i(int(last.x * TreasureMapScroll.COLS), int(last.y * TreasureMapScroll.ROWS))
	assert_eq(cell, TreasureMapParchment.ISLAND_CELL, "e no fim do caminho")


func test_treasure_x_only_when_complete() -> void:
	var all_but_one: Array[String] = GameState.MAP_FRAGMENT_IDS.duplicate()
	all_but_one.erase("campo_frag_1")
	var p: TreasureMapParchment = _parchment(all_but_one)
	await _drawn(p)
	assert_false(p.has_treasure_x())
	assert_true(_tags(p, TreasureMapParchment.ISLAND_CELL).has("island"), "a Ilha já aparece")
	assert_false(_tags(p, TreasureMapParchment.ISLAND_CELL).has("x"), "sem o X")
	p.found = GameState.MAP_FRAGMENT_IDS.duplicate()
	await _drawn(p)
	assert_true(p.has_treasure_x())
	assert_true(_tags(p, TreasureMapParchment.ISLAND_CELL).has("x"), "X vermelho com o mapa completo")


func test_drawing_is_stable_between_redraws() -> void:
	var p: TreasureMapParchment = _parchment(GameState.MAP_FRAGMENT_IDS.duplicate())
	await _drawn(p)
	var first: Array = p._art.map(func(item: Dictionary) -> PackedVector2Array: return item["points"])
	var ops: Dictionary = p.debug_ops.duplicate(true)
	p.found = ["praia_frag_1"]
	await _drawn(p)
	p.found = GameState.MAP_FRAGMENT_IDS.duplicate()
	await _drawn(p)
	var second: Array = p._art.map(func(item: Dictionary) -> PackedVector2Array: return item["points"])
	assert_eq(second, first, "seed fixa: o traço não treme")
	assert_eq(p.debug_ops, ops)


func test_base_station_uses_parchment() -> void:
	var ui: BaseStationUI = BASE_STATION_SCENE.instantiate() as BaseStationUI
	add_child_autofree(ui)
	var page: Node = ui.tab_container.get_node_or_null(BaseStationUI.TREASURE_TAB_TITLE)
	assert_not_null(page)
	var scroll: Node = page.find_child("TreasureMapScroll", true, false)
	assert_true(scroll is TreasureMapParchment, "o nó TreasureMapScroll é o pergaminho desenhado")
	GameState.instance._host_complete_quest("ze_anzol")
	assert_true((scroll as TreasureMapParchment).found.has("praia_frag_1"))
