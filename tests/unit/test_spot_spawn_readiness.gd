extends GutTest

## Regression for native SpotN/NetSync cache errors while a peer loads a map.
func test_real_spot_registers_its_ready_filter_before_synchronizer_enters() -> void:
	var spot: BuriedSpot = (load("res://items/buried_spot.tscn") as PackedScene).instantiate() as BuriedSpot
	var observed: Dictionary = {}
	spot.child_entered_tree.connect(func(child: Node) -> void:
		if child.name == &"NetSync":
			observed["parent_ready"] = spot.is_node_ready()
			observed["watched"] = child.is_in_group(NetVisibility.GROUP)
			observed["authority"] = child.get_multiplayer_authority()
	)
	add_child_autofree(spot)
	assert_true(observed.has("watched"), "actual production NetSync entered")
	assert_false(bool(observed.get("parent_ready", true)))
	assert_true(bool(observed.get("watched", false)), "ready visibility filter must be installed before NetSync registration")
	assert_eq(int(observed.get("authority", 0)), 1, "host-owned world state")
	var sync: MultiplayerSynchronizer = spot.get_node("NetSync") as MultiplayerSynchronizer
	assert_eq(sync.replication_config.get_properties().size(), 2)
	assert_true(sync.replication_config.property_get_spawn(NodePath(".:dirt_layers")))
	assert_true(sync.replication_config.property_get_spawn(NodePath(".:integrity")))
