extends GutTest

func test_owner_inventory_and_condition_survive_scene_replacement_once() -> void:
	var session: SessionManager = SessionManager.new()
	add_child_autofree(session)
	assert_true(session.has_method("capture_rocket_payload"))
	assert_true(session.has_method("restore_rocket_payload"))
	if not session.has_method("capture_rocket_payload"): return
	var first: Player = load("res://gameplay/player/player.tscn").instantiate() as Player
	first.name = "1"
	add_child_autofree(first)
	first.set_physics_process(false)
	var item: CarriedItem = CarriedItem.new()
	item.tool_id = "lanterna_magnesio"
	item.charges = 2
	item.wear = 37
	first.inventory.slots[1] = item
	first.inventory.selected_slot = 1
	first.health = 63
	first.hunger = 41
	first.session_money = 123
	first.session_items_count = 4
	assert_true(bool(session.call("capture_rocket_payload",first)))
	remove_child(first)
	first.free()
	var next: Player = load("res://gameplay/player/player.tscn").instantiate() as Player
	next.name = "1"
	add_child_autofree(next)
	next.set_physics_process(false)
	assert_true(bool(session.call("restore_rocket_payload",next)))
	assert_same(next.inventory.slots[1],item)
	assert_eq(item.charges,2)
	assert_eq(item.wear,37)
	assert_eq(next.inventory.selected_slot,1)
	assert_eq(next.health,63.0)
	assert_eq(next.hunger,41.0)
	assert_eq(next.session_money,123)
	assert_eq(next.session_items_count,4)
	assert_false(bool(session.call("restore_rocket_payload",next)),"Payload is consumed once, never duplicated")

func test_return_to_title_discards_pending_owner_payload() -> void:
	var session: SessionManager = SessionManager.new()
	session.scene_change_enabled = false
	add_child_autofree(session)
	session._current_map = load("res://items/maps/cratera.tres") as MapData
	var player: Player = load("res://gameplay/player/player.tscn").instantiate() as Player
	player.name = "1"
	add_child_autofree(player)
	player.set_physics_process(false)
	assert_true(session.capture_rocket_payload(player))
	session.return_to_title()
	assert_false(session.restore_rocket_payload(player),"Title abandons the transition and must release carried references")
