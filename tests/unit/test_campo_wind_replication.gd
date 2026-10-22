extends GutTest

var life: Node3D

func before_each() -> void:
	var path: String = "res://gameplay/quests/campo/campo_life.gd"
	life = (load(path) as Script).new()
	add_child_autofree(life)
	life.set_process(false)

func test_gust_uses_managed_networked_spawn_without_duplicate() -> void:
	var at: Vector3 = life.call("trigger_wind_gust", Vector3(16.4, 0, -11.8))
	var spot: BuriedSpot = life.get("_wheat_spot") as BuriedSpot
	assert_not_null(spot)
	if spot == null:
		return
	assert_true(spot.networked, "Client digging must use host arbitration")
	var spawners: Array[Node] = life.find_children("*", "MultiplayerSpawner", true, false)
	assert_eq(spawners.size(), 1, "Dedicated spawner owns creation/despawn and late join")
	if spawners.size() == 1:
		var spawner: MultiplayerSpawner = spawners[0] as MultiplayerSpawner
		assert_true(spawner.spawn_function.is_valid())
		assert_eq(spawner.get_node(spawner.spawn_path), spot.get_parent())
	assert_eq(spot.item.id, "medalha_militar")
	assert_eq(spot.global_position, at)
	life.call("trigger_wind_gust", Vector3(20.8, 0, -19.5))
	assert_same(life.get("_wheat_spot"), spot, "Another gust cannot duplicate the live target")
	assert_eq(spot.global_position, at, "An existing target must not move while another peer digs")
	assert_eq(life.call("get_glint_position"), at, "Glint follows the actual live target")

func test_reveal_replacement_starts_fresh_and_has_unique_path() -> void:
	life.call("trigger_wind_gust", Vector3(16.4, 0, -11.8))
	var previous: BuriedSpot = life.get("_wheat_spot") as BuriedSpot
	assert_not_null(previous)
	if previous == null:
		return
	var previous_path: NodePath = previous.get_path()
	# Despawn lifecycle, not an alternative implementation of dig.
	previous.queue_free()
	await get_tree().process_frame
	life.call("trigger_wind_gust", Vector3(20.8, 0, -19.5))
	var next: BuriedSpot = life.get("_wheat_spot") as BuriedSpot
	assert_not_null(next)
	if next != null:
		assert_true(next.networked)
		assert_ne(next.get_path(), previous_path, "Never reuse a path with stale network state")
		assert_gt(next.dirt_layers, 0)
		assert_false(next.get("_is_revealed"))
