extends GutTest

## Packed-scene delivery contract. Does not claim runtime walkability or visual QA.
const EXPECTED: Dictionary = {
	"praia": ["campo"], "campo": ["campo", "ruinas"],
	"ruinas": ["ruinas", "geleira"], "geleira": ["geleira", "cratera"],
	"cratera": ["cratera"]
}

func test_all_terrestrial_routes_have_real_endpoints_and_matching_arrival_markers() -> void:
	for id: String in EXPECTED:
		var packed: PackedScene = load("res://world/map_%s.tscn" % id)
		var root: Node = packed.instantiate()
		var routes: Node = root.get_node_or_null("WorldRoutes")
		assert_not_null(routes, id + " must deliver physical routes")
		if routes != null:
			for route: String in EXPECTED[id]:
				var endpoint: Node3D = routes.get_node_or_null("Passage_" + route) as Node3D
				var arrival: Marker3D = routes.get_node_or_null("Arrival_" + route) as Marker3D
				assert_not_null(endpoint, id + " endpoint " + route)
				assert_not_null(arrival, id + " arrival " + route)
				if endpoint != null:
					assert_eq((endpoint.get_script() as Script).resource_path, "res://gameplay/environment/boss_passage.gd")
					assert_eq(str(endpoint.get("route_id")), route)
					assert_eq(str(endpoint.get("source_map")), id)
					if arrival != null:
						assert_gte(endpoint.position.distance_to(arrival.position), 3.0, "arrival outside interaction radius; no instant return")
		root.free()

func test_each_existing_banca_has_one_contextual_upgrade_counter() -> void:
	for id: String in EXPECTED:
		var root: Node = (load("res://world/map_%s.tscn" % id) as PackedScene).instantiate()
		var counter: Node3D = root.get_node_or_null("Banca/Upgrades") as Node3D
		assert_not_null(counter, id + " banca upgrades")
		if counter != null:
			assert_eq((counter.get_script() as Script).resource_path, "res://gameplay/environment/upgrade_counter.gd")
			assert_eq(str(counter.get("map_id")), id)
			assert_lte(counter.position.length(), 4.0, "commerce remains attached to existing banca")
		root.free()

func test_lua_remains_rocket_only_without_terrestrial_passages_or_shop() -> void:
	var root: Node = (load("res://world/map_lua.tscn") as PackedScene).instantiate()
	assert_null(root.get_node_or_null("WorldRoutes"))
	assert_null(root.get_node_or_null("Banca"))
	root.free()

func test_real_gate_reflects_saved_route_opening_without_creating_a_receipt() -> void:
	var state: GameState = GameState.instance
	var snapshot: Dictionary = state.get_snapshot().duplicate(true)
	state.unlocked_maps.clear()
	var gate: Node3D = (load("res://gameplay/environment/boss_passage.tscn") as PackedScene).instantiate()
	gate.set("route_id", "campo")
	gate.set("source_map", "praia")
	add_child_autofree(gate)
	await get_tree().physics_frame
	var collision: CollisionShape3D = gate.get_node("Gate/Collision") as CollisionShape3D
	var rail: MeshInstance3D = gate.get_node("Gate/HighRail") as MeshInstance3D
	assert_false(collision.disabled)
	assert_true(rail.visible)
	assert_false(state.unlocked_maps.has("campo"), "presentation never opens the route")
	state.unlocked_maps.append("campo")
	state.state_synced.emit()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(collision.disabled, "saved receipt opens the actual gate collision")
	assert_false(rail.visible, "open gate is visibly different from a locked barrier")
	assert_true((gate.get_node("Gate/LeftPost") as Node3D).visible)
	state.load_snapshot(snapshot)
