extends GutTest

## Caos físico (estudo How to Fish): morte que voa, golpes que empurram itens, comida que
## se debate.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const SNAKE_SCENE: PackedScene = preload("res://gameplay/enemies/snake/snake.tscn")
const DEATH_FLING: Script = preload("res://gameplay/enemies/death_fling.gd")


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ground() -> StaticBody3D:
	var g: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	col.shape = box
	g.add_child(col)
	add_child_autofree(g)
	g.global_position = Vector3(0, -0.5, 0)
	return g


func test_enemy_death_flings_its_body() -> void:
	_ground()
	var crab: EnemyBase = SNAKE_SCENE.instantiate() as EnemyBase
	add_child_autofree(crab)
	crab.global_position = Vector3(0, 0.5, 0)
	await get_tree().physics_frame
	var visual_count: int = 0
	for c: Node in crab.get_children():
		if c is Node3D and not (c is CollisionShape3D or c is CollisionObject3D):
			visual_count += 1
	assert_gt(visual_count, 0, "a cobra tem visual")
	# Nasce a emergir (imune): o teste vai direto à morte, vinda da esquerda.
	crab._last_hit_from = Vector3(-3, 0.5, 0)
	crab._die()
	var body: RigidBody3D = null
	for n: Node in get_tree().root.find_children("DeathFling", "RigidBody3D", true, false):
		body = n as RigidBody3D
	assert_not_null(body, "corpo físico criado ao morrer")
	if body != null:
		assert_gt(body.linear_velocity.y, 3.0, "sai voando para cima")
		assert_gt(body.linear_velocity.x, 0.5, "para longe de quem bateu")
		assert_gt(body.get_child_count(), 1, "levou o visual do inimigo")
		assert_eq(body.collision_layer, 0, "não bloqueia jogadores")
		body.queue_free()


func test_swing_pushes_loose_pickups_in_cone() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var worm: ToolData = load("res://items/tools/batata_esquecida.tres") as ToolData
	var front: ItemPickup = ItemPickup.spawn(self, CarriedItem.create_from_tool_data(worm), player.global_position - player.global_basis.z * 1.2)
	var behind: ItemPickup = ItemPickup.spawn(self, CarriedItem.create_from_tool_data(worm), player.global_position + player.global_basis.z * 1.2)
	var fwd: Vector3 = -player.global_basis.z
	fwd.y = 0.0
	for i: int in 3:
		await get_tree().physics_frame
	front.linear_velocity = Vector3.ZERO
	behind.linear_velocity = Vector3.ZERO
	var n: int = player.push_pickups_in_cone(player.global_position, fwd.normalized(), 2.2, 0.5, 3.5)
	assert_eq(n, 1, "só o da frente")
	for i: int in 2:
		await get_tree().physics_frame
	assert_gt(front.linear_velocity.length(), 1.0, "o da frente voa")
	assert_lt(behind.linear_velocity.length(), 0.5, "o de trás fica")
	front.queue_free()
	behind.queue_free()


func test_push_is_capped() -> void:
	var td: ToolData = load("res://items/tools/batata_esquecida.tres") as ToolData
	var p: ItemPickup = ItemPickup.spawn(self, CarriedItem.create_from_tool_data(td), Vector3(0, 2, 0))
	for i: int in 3:
		await get_tree().physics_frame
	p.linear_velocity = Vector3.ZERO
	p.push(Vector3(500, 0, 0))
	for i: int in 2:
		await get_tree().physics_frame
	assert_lte(p.linear_velocity.length(), ItemPickup.MAX_PUSH / p.mass + 0.5, "teto de empurrão")
	p.queue_free()


func test_live_food_wriggles() -> void:
	_ground()
	var worm: ToolData = load("res://items/tools/minhoca.tres") as ToolData
	var potato: ToolData = load("res://items/tools/batata_esquecida.tres") as ToolData
	var w: ItemPickup = ItemPickup.spawn(self, CarriedItem.create_from_tool_data(worm), Vector3(0, 0.3, 0))
	var b: ItemPickup = ItemPickup.spawn(self, CarriedItem.create_from_tool_data(potato), Vector3(2, 0.3, 0))
	assert_true(w.is_wriggling_food(), "minhoca é viva")
	assert_false(b.is_wriggling_food(), "batata não")
	for i: int in 3:
		await get_tree().physics_frame
	w._wriggle_left = 0.0
	w.linear_velocity = Vector3.ZERO
	w._wriggle(0.01)
	for i: int in 2:
		await get_tree().physics_frame
	assert_gt(w.linear_velocity.y, 0.5, "a minhoca pula")
	w.queue_free()
	b.queue_free()
