extends GutTest

func test_pedestal_cannot_claim_placement_without_the_idol_and_never_consumes_it() -> void:
	var scene: Node3D = load("res://gameplay/quests/ruinas/ruinas_secrets.tscn").instantiate()
	add_child_autofree(scene)
	var pedestal: FlagInteractable = scene.get_node(^"Ground/CryptPedestal")
	var player: Player = load("res://gameplay/player/player.tscn").instantiate()
	player.name = "1"
	add_child_autofree(player)
	player.set_physics_process(false)
	player.global_position = pedestal.global_position + Vector3(1, 0, 0)
	var flags: WorldFlags = WorldFlags.find(get_tree())
	flags.set_flag(&"pedestal_idolo", false)
	var previous: Array[String] = GameState.instance.completed_quests.duplicate()
	GameState.instance.completed_quests.append("ines_camara")
	if pedestal.has_method(&"_finish_request"):
		pedestal.call(&"_finish_request", 234567)
		assert_eq(pedestal.state, 0, "Disconnected player cannot pass proximity validation")
	pedestal.request_interact()
	assert_eq(pedestal.state, 0, "Empty inventory cannot place an idol")
	assert_false(flags.has_flag(&"pedestal_idolo"))
	var idol: CarriedItem = CarriedItem.create(load("res://items/catalog/idolo_jade.tres"), 100, 1, false, false)
	player.inventory.add_item(idol)
	pedestal.request_interact()
	assert_eq(pedestal.state, 1)
	assert_true(flags.has_flag(&"pedestal_idolo"))
	assert_true(player.inventory.slots.has(idol), "Unique reward is still available for the museum")
	GameState.instance.completed_quests = previous
