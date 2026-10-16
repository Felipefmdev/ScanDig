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


# --- 4. Diário de campo ------------------------------------------------------

func test_journal_records_each_creature_once() -> void:
	var gs: GameState = GameState.instance
	assert_not_null(gs)
	var before: Array = Array(gs.seen_creatures)
	gs.seen_creatures.clear()
	watch_signals(gs)
	gs.report_creature("snake")
	gs.report_creature("snake")
	gs.report_creature("dragao_inexistente")
	assert_eq(Array(gs.seen_creatures), ["snake"], "uma entrada, só criaturas conhecidas")
	assert_signal_emit_count(gs, "creature_discovered", 1)
	assert_true(gs.get_snapshot().has("seen_creatures"), "vai no snapshot (rede e save)")
	gs.seen_creatures.assign(before)


func test_enemy_death_reports_to_journal() -> void:
	var gs: GameState = GameState.instance
	var before: Array = Array(gs.seen_creatures)
	gs.seen_creatures.clear()
	var snake: EnemyBase = SNAKE_SCENE.instantiate() as EnemyBase
	add_child_autofree(snake)
	snake._die()
	assert_true(gs.seen_creatures.has("snake"), "a cobra entrou no diário")
	gs.seen_creatures.assign(before)


func test_every_spawner_kind_is_known_or_boss() -> void:
	for kind: StringName in EnemySpawner.KIND_SCENES:
		var k: String = String(kind)
		var is_boss: bool = GameState.EXTRA_BOSSES.has(k) or GameState.MAP_UNLOCK_BOSSES.values().any(
			func(e: Dictionary) -> bool: return e["boss_id"] == k)
		assert_true(GameState.CREATURES.has(k) or is_boss, "%s no diário ou é chefe" % k)


# --- 5. Chefe que vai embora -------------------------------------------------

func test_boss_leaves_after_time_limit_without_counting_as_defeat() -> void:
	var boss: EnemyBase = (load("res://gameplay/enemies/boss/king_crab.tscn") as PackedScene).instantiate() as EnemyBase
	add_child_autofree(boss)
	await get_tree().physics_frame
	assert_true(boss.is_in_group(&"bosses"))
	watch_signals(boss)
	boss.boss_time = EnemyBase.BOSS_TIME_LIMIT - 0.01
	boss._tick_boss_timer(0.1)
	assert_signal_emitted(boss, "left_fight")
	assert_signal_not_emitted(boss, "died", "fugir não é morrer")
	assert_true(boss.is_queued_for_deletion())


func test_altar_rearms_when_boss_leaves() -> void:
	var altar: BossAltar = BossAltar.new()
	add_child_autofree(altar)
	await get_tree().process_frame
	for i: int in BuriedSpot.MAX_DIRT_LAYERS:
		altar.dig(false)
	assert_true(altar._woken, "acordou ao cavar até ao fim")
	assert_false(altar.is_queued_for_deletion(), "o altar não some")
	altar.rearm()
	assert_false(altar._woken)
	assert_eq(altar.dirt_layers, BuriedSpot.MAX_DIRT_LAYERS, "terra de volta")
	assert_true(altar.is_in_group("buried_spots"), "volta ao radar")
	for n: Node in get_tree().get_nodes_in_group(&"bosses"):
		n.queue_free()


func test_trigger_rearms_and_fails_quest_event_when_boss_leaves() -> void:
	var trig: BossTrigger = BossTrigger.new()
	trig.boss_kind = &"octopus"
	add_child_autofree(trig)
	await get_tree().process_frame
	watch_signals(trig)
	trig.trigger()
	assert_true(trig.triggered)
	var boss: EnemyBase = trig.boss as EnemyBase
	assert_not_null(boss)
	boss.leave_fight()
	assert_false(trig.triggered, "pode ser acordado de novo")
	assert_signal_emitted_with_parameters(trig, "finished", [false])
