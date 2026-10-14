extends GutTest

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new()
	add_child_autofree(inv)


func _loot(value: int) -> CarriedItem:
	var item: ItemData = ItemData.new()
	item.id = "teste_%d" % value
	return CarriedItem.create(item, value, 1.0, false)


func test_starts_with_three_empty_slots() -> void:
	assert_eq(inv.capacity, 3)
	assert_true(inv.is_empty())


func test_full_after_three_items() -> void:
	for v: int in [10, 20, 30]:
		assert_true(inv.add_item(_loot(v)))
	assert_true(inv.is_full())
	assert_false(inv.add_item(_loot(40)), "a 4.a entrada deve ser recusada")
	assert_eq(inv.get_total_value(), 60)


func test_delivery_keeps_tools() -> void:
	inv.add_item(CarriedItem.create_tool(&"detector", "Detetor de Metais"))
	inv.add_item(_loot(50))
	var delivered: Array[CarriedItem] = inv.take_where(SellPoint.can_deliver)
	assert_eq(delivered.size(), 1)
	assert_eq(inv.get_count(), 1, "o detetor fica na mochila")
	assert_true(inv.get_item(0).is_tool())


func test_take_all_empties_backpack() -> void:
	inv.add_item(_loot(5))
	inv.add_item(CarriedItem.create_tool(&"detector", "Detetor de Metais"))
	assert_eq(inv.take_all().size(), 2)
	assert_true(inv.is_empty())
