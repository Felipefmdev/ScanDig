extends GutTest

## ShopOffer.try_buy() compra pelo host (CoreGameState). Offline este processo é o host.

const SLINGSHOT: ToolData = preload("res://items/tools/estilingue.tres")
const PITCHFORK: ToolData = preload("res://items/tools/forcado.tres")

var offer: ShopOffer
var inv: Inventory
var state: GameState
var _saved_money: int = 0


func before_each() -> void:
	state = GameState.instance
	_saved_money = state.team_money
	offer = ShopOffer.new()
	offer.tool_data = SLINGSHOT
	add_child_autofree(offer)
	inv = Inventory.new()
	add_child_autofree(inv)


func after_each() -> void:
	state.team_money = _saved_money


func _loot() -> CarriedItem:
	var item: ItemData = ItemData.new()
	item.id = "teste"
	return CarriedItem.create(item, 10, 1.0, false)


func test_buy_debits_on_host_and_returns_tool() -> void:
	state.team_money = SLINGSHOT.price + 50
	var r: Dictionary = await offer.try_buy(inv)
	assert_true(r["ok"], r["message"])
	assert_eq(state.team_money, 50)
	var c: CarriedItem = r["carried"]
	assert_not_null(c)
	assert_true(c.is_tool())


func test_insufficient_money_keeps_balance() -> void:
	state.team_money = SLINGSHOT.price - 1
	var r: Dictionary = await offer.try_buy(inv)
	assert_false(r["ok"])
	assert_string_contains(r["message"], "Saldo insuficiente")
	assert_eq(state.team_money, SLINGSHOT.price - 1)
	assert_null(r["carried"])


func test_full_backpack_does_not_request() -> void:
	state.team_money = 1000
	for i: int in inv.capacity:
		inv.add_item(_loot())
	var r: Dictionary = await offer.try_buy(inv)
	assert_false(r["ok"])
	assert_eq(state.team_money, 1000)


func test_unknown_tool_is_unavailable() -> void:
	var fake: ToolData = ToolData.new()
	fake.id = &"nao_existe"
	fake.price = 10
	offer.tool_data = fake
	state.team_money = 1000
	var r: Dictionary = await offer.try_buy(inv)
	assert_false(r["ok"])
	assert_eq(state.team_money, 1000)


func test_world_scene_offer_does_not_add_fallback_box() -> void:
	var world_scene_offer: ShopOffer = ShopOffer.new()
	world_scene_offer.tool_data = PITCHFORK
	add_child_autofree(world_scene_offer)

	var fallback_boxes: Array[MeshInstance3D] = []
	var has_world_model: bool = false
	for child: Node in world_scene_offer.get_children():
		if child is MeshInstance3D:
			fallback_boxes.append(child as MeshInstance3D)
		if child.scene_file_path == PITCHFORK.world_scene.resource_path:
			has_world_model = true

	assert_true(has_world_model, "A oferta deve instanciar o modelo da ferramenta.")
	assert_eq(fallback_boxes.size(), 0, "Uma world_scene não deve deixar a caixa MeshInstance3D órfã.")
