extends GutTest

func test_rocket_repair_is_registered_without_economy_cost() -> void:
	assert_true(GameState.QUESTS.has("vega_foguete"), "Repair completion must persist through the existing quest snapshot")
	if GameState.QUESTS.has("vega_foguete"):
		var quest: Dictionary = GameState.QUESTS.get("vega_foguete", {})
		assert_eq(int(quest.get("reward", -1)), 0)

func test_lua_is_locked_until_persisted_repair() -> void:
	var state: GameState = GameState.new()
	state.unlocked_maps = ["praia", "cratera", "lua"]
	assert_false(state.is_map_unlocked("lua"), "An unlocked-map list alone must not bypass the rocket")
	state.completed_quests = ["vega_foguete"]
	assert_true(state.is_map_unlocked("lua"))
	state.free()

func test_lua_cannot_be_purchased_as_a_free_excavation_map() -> void:
	var state: GameState = GameState.new()
	assert_false(state.get_map_unlock_block_reason("lua").is_empty(),"The Moon must always direct players to the rocket instead of a zero-price unlock")
	state.completed_quests = ["vega_foguete"]
	assert_false(state.get_map_unlock_block_reason("lua").is_empty())
	state.free()
