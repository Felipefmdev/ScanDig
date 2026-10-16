extends GutTest

## Movimento com aceleração, corrida, coyote time, balanço de câmera, invulnerabilidade
## curta e retorno de acerto (hitmarker + número de dano).

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.action_release("sprint")


func _spawn_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	return player


func test_acceleration_ramps_instead_of_snapping() -> void:
	var player: Player = _spawn_player()
	player.velocity = Vector3.ZERO
	player._apply_horizontal_movement(Vector3.FORWARD, Vector2(0, -1), true, 1.0 / 60.0)
	var v: float = Vector2(player.velocity.x, player.velocity.z).length()
	assert_gt(v, 0.0, "começa a andar")
	assert_lt(v, player.speed * 0.5, "não chega à velocidade máxima num frame")
	for i: int in 120:
		player._apply_horizontal_movement(Vector3.FORWARD, Vector2(0, -1), true, 1.0 / 60.0)
	assert_almost_eq(Vector2(player.velocity.x, player.velocity.z).length(), player.speed, 0.05, "atinge o andar")


func test_air_control_is_weaker() -> void:
	var ground: Player = _spawn_player()
	var air: Player = _spawn_player()
	ground._apply_horizontal_movement(Vector3.FORWARD, Vector2(0, -1), true, 0.1)
	air._apply_horizontal_movement(Vector3.FORWARD, Vector2(0, -1), false, 0.1)
	assert_lt(absf(air.velocity.z), absf(ground.velocity.z), "no ar acelera menos")


func test_sprint_only_forward() -> void:
	var player: Player = _spawn_player()
	Input.action_press("sprint")
	assert_almost_eq(player.get_target_speed(Vector2(0, -1)), player.speed * player.sprint_multiplier, 0.001)
	assert_almost_eq(player.get_target_speed(Vector2(0, 1)), player.speed, 0.001, "de ré não corre")
	Input.action_release("sprint")
	assert_almost_eq(player.get_target_speed(Vector2(0, -1)), player.speed, 0.001)


func test_short_invulnerability_after_damage() -> void:
	var player: Player = _spawn_player()
	player.take_damage(10.0)
	player.take_damage(10.0)
	assert_almost_eq(player.health, player.max_health - 10.0, 0.001, "segundo acerto no mesmo instante ignorado")
	player._invulnerable_until_ms = 0
	player.take_damage(10.0)
	assert_almost_eq(player.health, player.max_health - 20.0, 0.001, "depois da janela volta a levar dano")


func test_head_bob_moves_camera_and_disables() -> void:
	var player: Player = _spawn_player()
	player._bob_weight = 1.0
	player._bob_phase = PI * 0.5
	player._apply_head_bob(player.speed)
	assert_false(player.camera.position.is_zero_approx(), "câmera balança andando")
	player.view_bobbing = false
	player._apply_head_bob(player.speed)
	assert_true(player.camera.position.is_zero_approx(), "opção desliga o balanço")


func test_hit_feedback_spawns_damage_number() -> void:
	var player: Player = _spawn_player()
	assert_not_null(player._hit_feedback, "feedback criado no jogador local")
	var target: Node3D = Node3D.new()
	add_child_autofree(target)
	var root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var before: int = _count_labels(root)
	player._register_hit(target, 25.0)
	assert_eq(_count_labels(root), before + 1, "número de dano no mundo")


func _count_labels(root: Node) -> int:
	if root == null:
		return 0
	var n: int = 0
	for c: Node in root.get_children():
		if c is Label3D:
			n += 1
	return n


# --- Comida escavada ---------------------------------------------------------

func test_each_map_has_dig_food() -> void:
	for map_id: String in ["praia", "campo", "ruinas", "geleira", "cratera"]:
		var foods: Array[ToolData] = Player.foods_for_map(map_id)
		assert_gt(foods.size(), 0, "%s tem comida no chão" % map_id)
		for td: ToolData in foods:
			assert_gt(td.heal_amount, 0.0, "%s cura" % td.id)
			assert_eq(td.price, 0, "%s não se compra" % td.id)
	assert_true(Player.foods_for_map("campo").any(func(t: ToolData) -> bool: return t.id == &"minhoca"),
		"minhoca no Campo")


func test_roll_dig_food_respects_chance() -> void:
	assert_not_null(Player.roll_dig_food("campo", false, 0.0), "rolagem baixa dá comida")
	assert_null(Player.roll_dig_food("campo", false, Player.FOOD_DIG_CHANCE + 0.01), "acima da chance: só terra")
	assert_not_null(Player.roll_dig_food("campo", true, Player.FOOD_DIG_CHANCE + 0.01), "cuidadosa tem mais chance")
	assert_null(Player.roll_dig_food("mapa_inexistente", true, 0.0))


func test_eating_heals_and_consumes() -> void:
	var player: Player = _spawn_player()
	var worm: ToolData = load("res://items/tools/minhoca.tres") as ToolData
	var c: CarriedItem = CarriedItem.create_from_tool_data(worm)
	player.inventory.add_item(c)
	assert_false(player.eat(c), "vida e fome cheias: não come")
	player.health = 50.0
	assert_true(player.eat(c))
	assert_almost_eq(player.health, 50.0 + worm.heal_amount, 0.001)
	assert_eq(player.inventory.slots.find(c), -1, "a minhoca sai da mochila")


func test_food_is_not_purchasable() -> void:
	var td: ToolData = load("res://items/tools/batata_esquecida.tres") as ToolData
	assert_eq(td.category, ToolData.Category.FOOD)
	assert_lte(td.price, 0, "GameState recusa compra com preço 0")


# --- Fome --------------------------------------------------------------------

func test_hunger_bar_exists_and_tracks_value() -> void:
	var player: Player = _spawn_player()
	assert_not_null(player._hunger_bar, "barra de fome no HUD")
	player.set_hunger(40.0)
	assert_almost_eq(player._hunger_bar.value, 40.0, 0.001)
	assert_string_contains(player._hunger_label.text, "40")


func test_hunger_decays_and_starving_hurts() -> void:
	var player: Player = _spawn_player()
	player.tick_hunger(10.0)
	assert_almost_eq(player.hunger, player.max_hunger - player.hunger_decay_per_sec * 10.0, 0.01, "cai com o tempo")
	player.set_hunger(0.0)
	var hp: float = player.health
	player.tick_hunger(player.starve_interval + 0.01)
	assert_lt(player.health, hp, "faminto perde vida")


func test_well_fed_regenerates_using_hunger() -> void:
	var player: Player = _spawn_player()
	player.health = 50.0
	player.set_hunger(90.0)
	player._last_damage_ms = -100000
	player.tick_hunger(player.regen_interval + 0.01)
	assert_gt(player.health, 50.0, "saciado regenera")
	assert_lt(player.hunger, 90.0 - player.hunger_decay_per_sec, "regenerar gasta fome")


func test_no_regen_when_hungry_or_recently_hit() -> void:
	var player: Player = _spawn_player()
	player.health = 50.0
	player.set_hunger(30.0)
	player._last_damage_ms = -100000
	player.tick_hunger(player.regen_interval + 0.01)
	assert_almost_eq(player.health, 50.0, 0.001, "com fome não regenera")
	player.set_hunger(90.0)
	player._last_damage_ms = Time.get_ticks_msec()
	player.tick_hunger(player.regen_interval + 0.01)
	assert_almost_eq(player.health, 50.0, 0.001, "logo depois de apanhar não regenera")


func test_eating_restores_hunger_even_at_full_health() -> void:
	var player: Player = _spawn_player()
	player.set_hunger(20.0)
	var potato: ToolData = load("res://items/tools/batata_esquecida.tres") as ToolData
	var c: CarriedItem = CarriedItem.create_from_tool_data(potato)
	player.inventory.add_item(c)
	assert_true(player.eat(c), "vida cheia mas com fome: come")
	assert_almost_eq(player.hunger, 20.0 + potato.hunger_restore, 0.001)


# --- Ferramenta na mão -------------------------------------------------------

func test_tool_sway_wraps_tool_view_and_hand() -> void:
	var player: Player = _spawn_player()
	assert_not_null(player.tool_sway, "pivô criado")
	assert_eq(player.tool_view.get_parent(), player.tool_sway, "ToolView dentro do pivô")
	assert_eq(player.detector.get_parent().get_parent(), player.tool_sway, "mão do detector dentro do pivô")


func test_tool_sway_lags_look_and_recovers() -> void:
	var player: Player = _spawn_player()
	player._sway_look = Vector2(200, 0)
	player.update_tool_sway(1.0 / 60.0)
	assert_lt(player.tool_sway.position.x, 0.0, "olhar pra direita deixa a ferramenta pra trás")
	assert_lte(absf(player.tool_sway.position.x), player.tool_sway_max + 0.001)
	for i: int in 120:
		player.update_tool_sway(1.0 / 60.0)
	assert_almost_eq(player.tool_sway.position.x, 0.0, 0.002, "volta ao centro")


func test_slot_change_dips_tool() -> void:
	var player: Player = _spawn_player()
	player._on_selected_slot_changed(0)
	player.update_tool_sway(0.01)
	assert_lt(player.tool_sway.position.y, -0.05, "mergulha ao trocar")
