extends GutTest

## #18 parte 2: Campo Antigo jogável quando desbloqueado, com economia acima da Praia.

const CAMPO: MapData = preload("res://items/maps/campo.tres")
const PRAIA: MapData = preload("res://items/maps/praia.tres")

var _saved: Dictionary = {}


func before_each() -> void:
	_saved = GameState.instance.get_snapshot()


func after_each() -> void:
	GameState.instance.apply_snapshot(_saved)


func _set_progress(unlocked: Array, bosses: Array) -> void:
	var snap: Dictionary = GameState.instance.get_snapshot()
	snap["unlocked_maps"] = unlocked
	snap["defeated_bosses"] = bosses
	GameState.instance.apply_snapshot(snap)


func _pool_average(map: MapData) -> float:
	var total: int = 0
	for entry: Variant in map.item_pool:
		var item: ItemData = entry as ItemData
		total += item.base_value
	return float(total) / float(map.item_pool.size())


func test_scene_exists_and_loads() -> void:
	assert_true(ResourceLoader.exists("res://world/map_campo.tscn"))
	var scene: PackedScene = load("res://world/map_campo.tscn") as PackedScene
	assert_not_null(scene)
	var state: SceneState = scene.get_state()
	var names: Array[String] = []
	for i: int in state.get_node_count():
		names.append(String(state.get_node_name(i)))
	for required: String in ["SpotSpawner", "DisturbanceMeter", "BaseEntrega", "Player", "EnemySpawner", "Bounds"]:
		assert_has(names, required)


func test_can_start_only_when_unlocked() -> void:
	var sm: SessionManager = SessionManager.instance
	_set_progress([], [])
	assert_false(sm.can_start_map("campo"), "bloqueado sem desbloqueio")
	_set_progress(["campo"], ["king_crab"])
	assert_true(sm.can_start_map("campo"))
	var status: Dictionary = sm.get_map_status("campo")
	assert_true(status["has_scene"])
	assert_true(status["playable"])
	assert_ne(status["reason"], "Em breve.")


func test_economy_above_praia() -> void:
	assert_eq(CAMPO.id, "campo")
	assert_gt(CAMPO.item_pool.size(), 0)
	var ratio: float = _pool_average(CAMPO) / _pool_average(PRAIA)
	assert_gt(ratio, 1.5, "Campo paga mais por item do que a Praia (%.2fx)" % ratio)
	assert_gt(CAMPO.spot_count, PRAIA.spot_count)
	assert_gt(CAMPO.noise_multiplier, PRAIA.noise_multiplier)
	for entry: Variant in CAMPO.item_pool:
		var item: ItemData = entry as ItemData
		assert_false(PRAIA.item_pool.has(item), "%s nao deve repetir a Praia" % item.id)


func test_field_terrain_flat_zones() -> void:
	assert_almost_eq(FieldTerrain.height_at(0.0, 0.0), 0.0, 0.001, "spawn plano")
	assert_almost_eq(FieldTerrain.height_at(3.5, 3.5), 0.0, 0.001, "base plana")
	assert_almost_eq(FieldTerrain.height_at(-18.0, -18.0), 0.0, 0.001, "circulo de pedras plano")
	assert_gt(FieldTerrain.height_at(44.0, 0.0), 2.0, "colinas para la das paredes")
