extends GutTest

## #113: Ilha do Tesouro (6.º mapa). MapData só com o mapa completo, terreno de ilha cercada de
## mar, tesouros à vista, barco na Praia que lê os fragmentos.

const MAP: String = "res://items/maps/ilha_tesouro.tres"
const SCENE: String = "res://world/map_ilha_tesouro.tscn"
const BOAT: Script = preload("res://gameplay/quests/praia/island_boat.gd")


func test_map_data_requires_fragments_and_has_top_finds() -> void:
	var md: MapData = load(MAP) as MapData
	assert_not_null(md)
	assert_eq(md.id, "ilha_tesouro")
	assert_true(md.requires_map_fragments, "so com o mapa do tesouro completo")
	assert_gt(md.unlock_cost, 100000000, "nao se compra com dinheiro")
	var praia: MapData = load("res://items/maps/praia.tres") as MapData
	var avg: Callable = func(m: MapData) -> float:
		var total: int = 0
		for it: ItemData in m.item_pool:
			total += it.base_value
		return float(total) / maxf(m.item_pool.size(), 1.0)
	assert_gt(avg.call(md), avg.call(praia) * 10.0, "pool de achados de topo")
	assert_true(ResourceLoader.exists(SCENE), "cena do mapa existe")


func test_island_terrain_is_land_in_the_middle_and_sea_around() -> void:
	assert_gt(IslandTerrain.height_at(0, 0), -0.1, "chegada em terra")
	assert_almost_eq(IslandTerrain.height_at(0, 0), 0.0, 0.05, "chegada plana")
	assert_gt(IslandTerrain.height_at(IslandTerrain.HILL.x, IslandTerrain.HILL.z), 2.0, "Monte do Tesouro")
	for a: int in 8:
		var ang: float = TAU * float(a) / 8.0
		var p: Vector2 = Vector2(cos(ang), sin(ang)) * 31.0
		assert_lt(IslandTerrain.height_at(p.x, p.y), -1.0, "mar a toda a volta (%d)" % a)


func test_layout_places_visible_treasures_and_main_on_the_hill() -> void:
	var layout: Node3D = IslandLayout.new()
	add_child_autofree(layout)
	var treasures: int = 0
	for c: Node in layout.get_children():
		if c is TreasureModel:
			treasures += 1
			assert_not_null(c.get_node_or_null(^"Body"), "tesouro solido")
	assert_gte(treasures, 8, "tesouros a vista")
	var main: Vector3 = IslandLayout.main_treasure_position()
	assert_gt(main.y, 2.0, "o maior tesouro fica no planalto do monte")


func test_treasure_models_build_every_kind() -> void:
	for k: int in 3:
		var t: TreasureModel = TreasureModel.new()
		t.kind = k
		add_child_autofree(t)
		var mi: MeshInstance3D = t.get_node_or_null(^"Mesh") as MeshInstance3D
		assert_not_null(mi, "malha do tipo %d" % k)
		assert_gt(mi.mesh.get_faces().size(), 30, "tem detalhe")


func test_boat_reads_fragment_progress_safely() -> void:
	var p: Vector2i = BOAT.fragment_progress()
	assert_gt(p.y, 0, "total de fragmentos conhecido")
	assert_lte(p.x, p.y)


func test_scene_has_hoard_layout_and_open_sea() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	autofree(scene)
	assert_not_null(scene.get_node_or_null(^"TreasureHoard"), "tesouros espalhados pelo host")
	assert_true(scene.get_node(^"Decor/Layout") is IslandLayout, "layout da ilha")
	var deco: Node = scene.get_node(^"DecorationScatter")
	assert_eq(deco.get("theme"), "ilha")
	assert_eq((deco.get("open_sides") as PackedInt32Array).size(), 4, "mar aberto nos 4 lados")
	var praia: Node = (load("res://gameplay/quests/praia/praia_secrets.tscn") as PackedScene).instantiate()
	autofree(praia)
	assert_true(praia.get_node_or_null(^"Ground/IslandBoat") is IslandBoat, "barco no cais da Praia")
