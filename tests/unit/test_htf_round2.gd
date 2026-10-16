extends GutTest

## Segunda rodada do estudo How to Fish: arremesso que fere, peso dos achados, diário,
## chefe que vai embora, desgaste de ferramentas e bónus de estilo.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const SNAKE_SCENE: PackedScene = preload("res://gameplay/enemies/snake/snake.tscn")


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _food_pickup(pos: Vector3) -> ItemPickup:
	var td: ToolData = load("res://items/tools/batata_esquecida.tres") as ToolData
	return ItemPickup.spawn(self, CarriedItem.create_from_tool_data(td), pos)


# --- 1. Arremesso que fere ---------------------------------------------------

func test_impact_damage_curve() -> void:
	var p: ItemPickup = _food_pickup(Vector3(0, 5, 0))
	assert_eq(p.impact_damage(3.0), 0.0, "devagar não fere")
	assert_almost_eq(p.impact_damage(ItemPickup.IMPACT_MIN_SPEED), ItemPickup.IMPACT_DAMAGE.x, 0.01)
	assert_almost_eq(p.impact_damage(50.0), ItemPickup.IMPACT_DAMAGE.y, 0.01, "satura no máximo")
	p.queue_free()


func test_fast_item_hits_enemy_once() -> void:
	var snake: EnemyBase = SNAKE_SCENE.instantiate() as EnemyBase
	add_child_autofree(snake)
	snake.global_position = Vector3(0, 0, 0)
	await get_tree().physics_frame
	snake.state = 1  # CHASE: fora do EMERGE (imune)
	var hp: float = snake.health
	var p: ItemPickup = _food_pickup(snake.global_position + Vector3.UP * 0.4)
	p.linear_velocity = Vector3(12, 0, 0)
	p._check_impacts()
	assert_lt(snake.health, hp, "o item acertou")
	var hp2: float = snake.health
	p.global_position = snake.global_position + Vector3.UP * 0.4
	p.linear_velocity = Vector3(12, 0, 0)
	p._check_impacts()
	assert_eq(snake.health, hp2, "um impacto por arremesso")
	p.queue_free()


# --- 2. Peso dos achados -----------------------------------------------------

func _find(size: int) -> CarriedItem:
	var item: ItemData = ItemData.new()
	item.id = "teste_%d" % size
	item.size_category = size
	item.base_value = 10
	return CarriedItem.create(item, 10, 1.0, false)


func test_backpack_weight_slows_by_size() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	assert_eq(player.backpack_weight_multiplier(), 1.0, "mochila vazia")
	player.inventory.add_item(_find(ItemData.SizeCategory.PEQUENO))
	assert_eq(player.backpack_weight_multiplier(), 1.0, "pequeno não pesa")
	player.inventory.add_item(_find(ItemData.SizeCategory.MEDIO))
	assert_almost_eq(player.backpack_weight_multiplier(), 0.96, 0.001)
	assert_false(player.is_overloaded())
	player.inventory.add_item(_find(ItemData.SizeCategory.GRANDE))
	assert_true(player.is_overloaded(), "grande: sem correr")
	Input.action_press("sprint")
	assert_almost_eq(player.get_target_speed(Vector2(0, -1)), player.speed * player.backpack_weight_multiplier(), 0.001,
		"Shift não corre com peso")
	Input.action_release("sprint")


func test_backpack_slow_is_capped() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	player.inventory.capacity = 8
	for i: int in 3:
		player.inventory.add_item(_find(ItemData.SizeCategory.COLOSSAL))
	assert_almost_eq(player.backpack_weight_multiplier(), 1.0 - Player.BACKPACK_SLOW_MAX, 0.001)
