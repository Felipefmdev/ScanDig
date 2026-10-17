extends GutTest

## #93 Achados intactos: o cuidado continua depois de cavar; o Museu guarda a coleção.


func _find(fragile: float = 0.6) -> CarriedItem:
	var item: ItemData = load("res://items/catalog/moeda_antiga.tres") as ItemData
	var c: CarriedItem = CarriedItem.create(item, item.base_value, 1.0, false, true)
	return c


func test_damage_after_digging_loses_seal_and_value() -> void:
	var c: CarriedItem = _find()
	var v0: int = c.final_value
	assert_true(c.is_clean)
	assert_true(c.damage_integrity(0.3), "perdeu o selo agora")
	assert_false(c.is_clean)
	assert_almost_eq(c.integrity, 0.7, 0.001)
	assert_lt(c.final_value, v0, "vale menos")
	assert_false(c.damage_integrity(0.1), "já não era intacto")
	c.damage_integrity(5.0)
	assert_almost_eq(c.integrity, CarriedItem.MIN_INTEGRITY, 0.001, "nunca chega a zero")


func test_tools_are_not_damaged() -> void:
	var td: ToolData = load("res://items/tools/forcado.tres") as ToolData
	var c: CarriedItem = CarriedItem.create_from_tool_data(td)
	assert_false(c.damage_integrity(0.5))


func test_host_records_each_intact_piece_once() -> void:
	var gs: GameState = GameState.instance
	var before: Array = Array(gs.intact_items)
	gs.intact_items.clear()
	gs.request_report_intact("moeda_antiga")
	gs.request_report_intact("moeda_antiga")
	gs.request_report_intact("nao_existe")
	assert_eq(Array(gs.intact_items), ["moeda_antiga"])
	assert_true(gs.get_snapshot().has("intact_items"), "vai no snapshot e no save")
	gs.intact_items.assign(before)


func test_museum_line_shows_seal() -> void:
	var item: ItemData = load("res://items/catalog/moeda_antiga.tres") as ItemData
	assert_string_contains(BaseStationUI.museum_line(item, true, true), "intacto")
	assert_false(BaseStationUI.museum_line(item, true, false).contains("intacto"))
