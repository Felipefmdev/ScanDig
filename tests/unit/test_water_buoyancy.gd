class_name TestWaterBuoyancy
extends GutTest

## Testes unitários para a flutuação e deriva de itens no mar (Issue #89 — How to Fish WaterManager/FloatInfos).


func _make_item_pickup(id: String, mat: ItemData.MaterialType, size: ItemData.SizeCategory = ItemData.SizeCategory.PEQUENO) -> ItemPickup:
	var data: ItemData = ItemData.new()
	data.id = id
	data.display_name = id
	data.material_type = mat
	data.size_category = size
	var carried: CarriedItem = CarriedItem.create(data, 50, 1.0, false)
	var pickup: ItemPickup = ItemPickup.create(carried)
	add_child_autofree(pickup)
	return pickup


func _make_tool_pickup(id: StringName, cat: ToolData.Category) -> ItemPickup:
	var td: ToolData = ToolData.new()
	td.id = id
	td.display_name = String(id)
	td.category = cat
	var carried: CarriedItem = CarriedItem.create_from_tool_data(td)
	var pickup: ItemPickup = ItemPickup.create(carried)
	add_child_autofree(pickup)
	return pickup


func test_is_buoyant_by_item_and_tool_type() -> void:
	var bottle: ItemPickup = _make_item_pickup("mapa_na_garrafa", ItemData.MaterialType.DESCONHECIDO)
	assert_true(bottle.is_buoyant(), "Garrafa deve flutuar")

	var shell: ItemPickup = _make_item_pickup("concha_dourada", ItemData.MaterialType.OURO)
	assert_true(shell.is_buoyant(), "Concha deve flutuar")

	var can: ItemPickup = _make_item_pickup("lata_enferrujada", ItemData.MaterialType.FERRO)
	assert_true(can.is_buoyant(), "Lata vazia deve flutuar")

	var organic: ItemPickup = _make_item_pickup("olho_do_polvo", ItemData.MaterialType.DESCONHECIDO, ItemData.SizeCategory.PEQUENO)
	assert_true(organic.is_buoyant(), "Item orgânico leve deve flutuar")

	var food: ItemPickup = _make_tool_pickup(&"coco_praia", ToolData.Category.FOOD)
	assert_true(food.is_buoyant(), "Comida deve flutuar")

	var slingshot: ItemPickup = _make_tool_pickup(&"estilingue", ToolData.Category.WEAPON)
	assert_true(slingshot.is_buoyant(), "Estilingue de madeira deve flutuar")

	var iron_key: ItemPickup = _make_item_pickup("chave_enferrujada", ItemData.MaterialType.FERRO)
	assert_false(iron_key.is_buoyant(), "Chave de ferro deve afundar")

	var gold_crown: ItemPickup = _make_item_pickup("coroa_caranguejo_rei", ItemData.MaterialType.OURO, ItemData.SizeCategory.GRANDE)
	assert_false(gold_crown.is_buoyant(), "Coroa de ouro pesada deve afundar")

	var heavy_idol: ItemPickup = _make_item_pickup("idolo_pedra", ItemData.MaterialType.DESCONHECIDO, ItemData.SizeCategory.GRANDE)
	assert_false(heavy_idol.is_buoyant(), "Rocha/ídolo grande deve afundar")

	var pitchfork: ItemPickup = _make_tool_pickup(&"forcado", ToolData.Category.WEAPON)
	assert_false(pitchfork.is_buoyant(), "Forcado de ferro pesado deve afundar")


func test_buoyant_pickup_floats_and_drifts_back_to_shore() -> void:
	var bottle: ItemPickup = _make_item_pickup("mapa_na_garrafa", ItemData.MaterialType.DESCONHECIDO)
	bottle.global_position = Vector3(23.5, -0.25, 2.0)

	assert_true(bottle.is_in_water(), "Item em x=23.5, y=-0.25 deve ser detetado na água")

	# Primeiros passos: sobe até à superfície da água (-0.02..0.04) e ativa amortecimento
	for _i: int in 15:
		bottle._apply_water_physics(0.05)
	assert_between(
		bottle.global_position.y,
		ItemPickup.WATER_FLOAT_MIN_Y,
		ItemPickup.WATER_FLOAT_MAX_Y,
		"Item flutuante deve manter-se na superfície com as ondas"
	)
	assert_eq(bottle.linear_damp, ItemPickup.WATER_BUOYANT_DAMP, "Deve aplicar linear_damp de flutuação na água")
	assert_lt(bottle.global_position.x, 23.5, "Item flutuante deve derivar na direção -X (para a praia)")

	# Continua a derivar até sair da água na areia (x < 19.5)
	for _i: int in 80:
		bottle._apply_water_physics(0.05)
	assert_lt(bottle.global_position.x, ItemPickup.WATER_SHORE_EXIT_X, "Item flutuante deve voltar à beira da areia (x < 19.5)")
	assert_false(bottle.is_in_water(), "Após chegar à areia em x < 19.5 já não está na água")


func test_heavy_pickup_sinks_to_shallow_seabed_and_stays_visible() -> void:
	var anchor_item: ItemPickup = _make_item_pickup("chave_enferrujada", ItemData.MaterialType.FERRO, ItemData.SizeCategory.MEDIO)
	anchor_item.global_position = Vector3(26.5, 0.0, -3.0)

	assert_false(anchor_item.is_buoyant(), "Item metálico pesado não deve boiar")
	assert_true(anchor_item.is_in_water(), "Item em x=26.5, y=0.0 deve estar na água")

	for _i: int in 60:
		anchor_item._apply_water_physics(0.05)

	assert_gte(anchor_item.global_position.y, ItemPickup.WATER_SHALLOW_FLOOR_Y, "Item pesado não deve afundar abaixo de y = -0.45")
	assert_lt(anchor_item.global_position.y, -0.2, "Item pesado deve afundar abaixo da superfície")
	assert_lte(anchor_item.global_position.x, ItemPickup.WATER_HEAVY_MAX_X, "Item pesado deve aproximar-se até x <= 23.0 no fundo raso")
	assert_eq(anchor_item.linear_damp, ItemPickup.WATER_SINK_DAMP, "Item pesado deve ter drag de água ativo")
