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


# --- Carne Crua (balanceada) -------------------------------------------------

func test_meat_is_weaker_than_dug_food() -> void:
	var meat: ToolData = load("res://items/tools/carne_crua.tres") as ToolData
	assert_eq(meat.category, ToolData.Category.FOOD)
	assert_eq(meat.dig_maps.size(), 0, "não sai do chão")
	assert_lte(meat.price, 0, "não se compra")
	for id: String in ["minhoca", "tatuira", "liquen_gelado"]:
		var food: ToolData = load("res://items/tools/%s.tres" % id) as ToolData
		assert_lt(meat.heal_amount, food.heal_amount, "cura menos que %s" % id)
		assert_lt(meat.hunger_restore, food.hunger_restore, "sacia menos que %s" % id)
	assert_gt(meat.spoil_seconds, 0.0, "estraga no chão")
	assert_gt(meat.nausea_chance, 0.0, "pode enjoar")


func test_only_flesh_enemies_drop_meat_rarely() -> void:
	var snake: EnemyBase = (load("res://gameplay/enemies/snake/snake.tscn") as PackedScene).instantiate() as EnemyBase
	var stone: EnemyBase = (load("res://gameplay/enemies/stone_guardian/stone_guardian.tscn") as PackedScene).instantiate() as EnemyBase
	add_child_autofree(snake)
	add_child_autofree(stone)
	assert_between(snake.meat_drop_chance(), 0.05, 0.25, "cobra: chance baixa")
	assert_eq(stone.meat_drop_chance(), 0.0, "guardião de pedra não tem carne")
	assert_false(snake.try_drop_meat(0.99), "rolagem alta: nada")
	assert_true(snake.try_drop_meat(0.0), "rolagem baixa: carne")
	assert_false(stone.try_drop_meat(0.0))


func test_meat_spoils_on_ground() -> void:
	var meat: ToolData = load("res://items/tools/carne_crua.tres") as ToolData
	var p: ItemPickup = ItemPickup.spawn(self, CarriedItem.create_from_tool_data(meat), Vector3(0, 1, 0))
	p._spoil_left = 0.01
	for i: int in 3:
		await get_tree().physics_frame
	assert_true(not is_instance_valid(p) or p.is_queued_for_deletion(), "estragou e sumiu")


func test_raw_meat_can_cause_nausea() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var meat: ToolData = load("res://items/tools/carne_crua.tres").duplicate() as ToolData
	meat.nausea_chance = 1.0
	var c: CarriedItem = CarriedItem.create_from_tool_data(meat)
	player.inventory.add_item(c)
	player.health = 50.0
	player.set_hunger(50.0)
	assert_true(player.eat(c))
	assert_almost_eq(player.health, 50.0, 0.001, "enjoado não cura")
	assert_lt(player.hunger, 50.0, "e perde saciedade")


# --- Ladrões mais ousados ----------------------------------------------------

func test_seagull_snatches_loose_items_but_not_tools() -> void:
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		n.free()  # sobras de outros testes
	var gull: Seagull = (load("res://gameplay/enemies/seagull/seagull.tscn") as PackedScene).instantiate() as Seagull
	add_child_autofree(gull)
	gull.global_position = Vector3(0, 3, 0)
	var detector: ItemPickup = ItemPickup.spawn(self, CarriedItem.create_tool(&"detector", "Detetor"), Vector3(0.5, 0.2, 0))
	var potato: ToolData = load("res://items/tools/batata_esquecida.tres") as ToolData
	var food: ItemPickup = ItemPickup.spawn(self, CarriedItem.create_from_tool_data(potato), Vector3(3, 0.2, 0))
	assert_eq(gull.find_ground_loot(Vector3.ZERO), food, "ignora o detetor, vai à comida")
	gull._ground_target = food
	gull.global_position = food.global_position + Vector3.UP * 0.2
	gull._process_ground_steal(0.016)
	assert_true(gull.has_stolen, "levou o item")
	assert_true(food.is_queued_for_deletion(), "sumiu do chão")
	detector.queue_free()


func test_backpack_thief_takes_food_when_no_finds() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var worm: ToolData = load("res://items/tools/minhoca.tres") as ToolData
	player.inventory.add_item(CarriedItem.create_from_tool_data(worm))
	var stolen: CarriedItem = player.steal_loot()
	assert_not_null(stolen, "sem achados, rouba a comida")
	assert_eq(stolen.tool_data.id, &"minhoca")


# --- AFK e cocô de gaivota -----------------------------------------------------

func test_hunger_pauses_while_afk() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	player.set_hunger(50.0)
	player._last_input_ms = Time.get_ticks_msec() - int((Player.AFK_SECONDS + 5.0) * 1000.0)
	assert_true(player.is_afk())
	player.tick_hunger(30.0)
	assert_almost_eq(player.hunger, 50.0, 0.001, "ausente: a fome não cai")
	player._last_input_ms = Time.get_ticks_msec()
	player.tick_hunger(10.0)
	assert_lt(player.hunger, 50.0, "de volta: cai")


func test_seagull_poop_hits_player_below() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var gull: Seagull = (load("res://gameplay/enemies/seagull/seagull.tscn") as PackedScene).instantiate() as Seagull
	add_child_autofree(gull)
	gull.global_position = player.global_position + Vector3(0, 6, 0)
	var blob: Node3D = gull.drop_poop()
	assert_not_null(blob)
	for i: int in 60:
		gull._update_poops(1.0 / 60.0)
	assert_not_null(player._splat_layer, "manchou a vista")
	assert_true(not is_instance_valid(blob) or blob.is_queued_for_deletion(), "o cocô sumiu ao acertar")


func test_eating_takes_time_and_damage_interrupts() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var worm: ToolData = load("res://items/tools/minhoca.tres") as ToolData
	var c: CarriedItem = CarriedItem.create_from_tool_data(worm)
	player.inventory.add_item(c)
	player.inventory.select(player.inventory.slots.find(c))
	player.health = 50.0
	player.start_eating(c)
	player.update_eating(0.5, true)
	assert_almost_eq(player.health, 50.0, 0.001, "ainda a mastigar")
	player._invulnerable_until_ms = 0
	player.take_damage(5.0)
	assert_false(player.is_eating(), "o golpe interrompe")
	player.start_eating(c)
	player.update_eating(0.6, true)
	player.update_eating(0.6, true)
	assert_gt(player.health, 45.0, "segurou o tempo todo: comeu")
	assert_eq(player.inventory.slots.find(c), -1)


func test_releasing_cancels_eating() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var worm: ToolData = load("res://items/tools/minhoca.tres") as ToolData
	var c: CarriedItem = CarriedItem.create_from_tool_data(worm)
	player.inventory.add_item(c)
	player.inventory.select(player.inventory.slots.find(c))
	player.health = 50.0
	player.start_eating(c)
	player.update_eating(0.3, false)
	assert_false(player.is_eating(), "largou o clique")
