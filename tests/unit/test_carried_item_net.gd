extends GutTest

## #22 / contrato #5 bloco C: CarriedItem.to_dict() / from_dict().

const MOEDA: ItemData = preload("res://items/catalog/moeda_antiga.tres")
const REPELENTE: ToolData = preload("res://items/tools/repelente.tres")
const ESTILINGUE: ToolData = preload("res://items/tools/estilingue.tres")


func test_item_round_trip() -> void:
	var c: CarriedItem = CarriedItem.create(MOEDA, 120, 0.8, true)
	var d: Dictionary = c.to_dict()
	assert_eq(d, {"kind": "item", "item_id": "moeda_antiga", "final_value": 120, "integrity": 0.8,
		"rare": true, "clean": false, "tool_id": "", "charges": -1})
	var back: CarriedItem = CarriedItem.from_dict(d)
	assert_not_null(back)
	assert_eq(back.item, MOEDA)
	assert_eq(back.final_value, 120)
	assert_almost_eq(back.integrity, 0.8, 0.0001)
	assert_true(back.is_rare_variant)
	assert_false(back.is_clean)
	assert_false(back.is_tool())


func test_clean_item_round_trip() -> void:
	var c: CarriedItem = CarriedItem.create(MOEDA, 120, 1.0, false, true)
	var d: Dictionary = c.to_dict()
	assert_true(d["clean"])
	var back: CarriedItem = CarriedItem.from_dict(d)
	assert_not_null(back)
	assert_true(back.is_clean)
	assert_eq(back.final_value, 120)


func test_round_trip_survives_json() -> void:
	# Pela rede/JSON os inteiros podem chegar como float.
	var d: Variant = JSON.parse_string(JSON.stringify(CarriedItem.create(MOEDA, 90, 1.0, false, true).to_dict()))
	var back: CarriedItem = CarriedItem.from_dict(d)
	assert_not_null(back)
	assert_eq(back.final_value, 90)
	assert_true(back.is_clean)


func test_tool_round_trips() -> void:
	var rep: CarriedItem = CarriedItem.create_from_tool_data(REPELENTE)
	rep.consume_charge()
	var back: CarriedItem = CarriedItem.from_dict(rep.to_dict())
	assert_not_null(back)
	assert_eq(back.tool_id, REPELENTE.id)
	assert_eq(back.tool_data, REPELENTE)
	assert_eq(back.charges, rep.charges)

	var sling: CarriedItem = CarriedItem.from_dict(CarriedItem.create_from_tool_data(ESTILINGUE).to_dict())
	assert_not_null(sling)
	assert_eq(sling.charges, -1)

	var det: CarriedItem = CarriedItem.create_tool(DetectorSpawn.TOOL_ID, DetectorSpawn.TOOL_NAME, DetectorSpawn.WORLD_MODEL)
	var det_back: CarriedItem = CarriedItem.from_dict(det.to_dict())
	assert_not_null(det_back)
	assert_eq(det_back.tool_id, &"detector")
	assert_not_null(det_back.world_scene)


func test_rejects_invalid() -> void:
	var good: Dictionary = CarriedItem.create(MOEDA, 100, 1.0, false).to_dict()
	var cases: Array[Dictionary] = [
		{},
		{"kind": "outro"},
		_with(good, "item_id", "nao_existe"),
		_with(good, "item_id", "../tools/repelente"),
		_with(good, "item_id", 5),
		_with(good, "final_value", -1),
		_with(good, "final_value", "100"),
		_with(good, "final_value", 999999),  # acima do teto get_max_item_value
		_with(good, "integrity", 1.5),
		_with(good, "rare", "sim"),
		_with(good, "clean", "sim"),
		{"kind": "tool", "tool_id": "nao_existe", "charges": -1},
		{"kind": "tool", "tool_id": "../catalog/moeda_antiga", "charges": -1},
		{"kind": "tool", "tool_id": "repelente", "charges": 0},
		{"kind": "tool", "tool_id": "repelente", "charges": REPELENTE.charges + 1},
	]
	for d: Dictionary in cases:
		assert_null(CarriedItem.from_dict(d), "deveria rejeitar %s" % str(d))


func _with(base: Dictionary, key: String, value: Variant) -> Dictionary:
	var d: Dictionary = base.duplicate()
	d[key] = value
	return d
