extends GutTest

## Dinamite (estudo How to Fish): explosão que derruba, arremessa e desenterra.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const SNAKE_SCENE: PackedScene = preload("res://gameplay/enemies/snake/snake.tscn")
const DYNAMITE: Script = preload("res://gameplay/weapons/dynamite/dynamite.gd")


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_tool_data_is_a_paid_consumable() -> void:
	var td: ToolData = load("res://items/tools/dinamite.tres") as ToolData
	assert_eq(td.category, ToolData.Category.CONSUMABLE)
	assert_eq(td.charges, 3)
	assert_gt(td.price, 0)


func test_sold_from_ruins_onwards() -> void:
	for m: String in ["praia", "campo"]:
		assert_false(FileAccess.get_file_as_string("res://world/map_%s.tscn" % m).contains("dinamite.tres"), "%s não vende" % m)
	for m: String in ["ruinas", "geleira", "cratera"]:
		assert_true(FileAccess.get_file_as_string("res://world/map_%s.tscn" % m).contains("tool_data = ExtResource(\"t_dinamite\")"), "%s vende" % m)


func test_blast_hits_enemies_items_and_thrower() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	player.global_position = Vector3(2, 0, 0)
	var snake: EnemyBase = SNAKE_SCENE.instantiate() as EnemyBase
	add_child_autofree(snake)
	snake.global_position = Vector3(-1, 0, 0)
	var far: EnemyBase = SNAKE_SCENE.instantiate() as EnemyBase
	add_child_autofree(far)
	far.global_position = Vector3(30, 0, 0)
	var td: ToolData = load("res://items/tools/batata_esquecida.tres") as ToolData
	var item: ItemPickup = ItemPickup.spawn(self, CarriedItem.create_from_tool_data(td), Vector3(0, 0.5, 1))
	await get_tree().physics_frame
	snake.state = 1  # CHASE: fora do EMERGE (imune)
	var hp0: float = player.health
	var out: Dictionary = DYNAMITE.apply_blast(get_tree(), Vector3.ZERO, player)
	assert_eq(out["enemies"], 1, "só a cobra perto")
	assert_eq(out["items"], 1, "o item perto")
	assert_eq(out["players"], 1, "quem lançou também")
	assert_lt(player.health, hp0, "auto-dano")
	assert_gt(player.velocity.x, 3.0, "arremessado para longe da explosão")
	assert_gt(player.velocity.y, 2.0, "e para cima")
	item.queue_free()


func test_throw_creates_fused_stick() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var stick: RigidBody3D = player.throw_dynamite()
	assert_not_null(stick)
	assert_gt(stick.linear_velocity.length(), 5.0, "lançada")
	assert_eq(stick.get("thrower"), player)
	var res: Dictionary = stick.call("explode")
	assert_true(res.has("enemies"))
	assert_true(stick.is_queued_for_deletion(), "some ao explodir")


func test_blast_digs_nearby_spot() -> void:
	var spot_scene: PackedScene = load("res://items/buried_spot.tscn") as PackedScene
	var spot: BuriedSpot = spot_scene.instantiate() as BuriedSpot
	add_child_autofree(spot)
	spot.global_position = Vector3(1, 0, 0)
	await get_tree().process_frame
	var out: Dictionary = DYNAMITE.apply_blast(get_tree(), Vector3.ZERO, null)
	assert_eq(out["spots"], 1, "o buraco perto explodiu")
	assert_eq(spot.dirt_layers, 0, "todas as camadas de uma vez")
