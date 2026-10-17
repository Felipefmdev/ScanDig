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


func test_attack_pressed_during_cooldown_is_buffered() -> void:
	var player: Player = _spawn_player()
	player._attack_cooldown = 0.2
	Input.action_press("attack")
	player._handle_attack_action()
	Input.action_release("attack")
	assert_gt(player._attack_buffer_left, 0.0, "guardado durante a recarga")
	player._attack_cooldown = 0.0
	player._handle_attack_action()
	assert_eq(player._attack_buffer_left, 0.0, "sai assim que a recarga acaba")
	assert_gt(player._attack_cooldown, 0.0, "golpe executado")


# --- Arremesso e itens próximos ----------------------------------------------

func test_tap_drop_vs_charged_throw() -> void:
	var player: Player = _spawn_player()
	var tap: Vector3 = player.get_throw_impulse(0.0)
	var full: Vector3 = player.get_throw_impulse(1.0)
	assert_gt(full.length(), tap.length() * 3.0, "carregado voa bem mais longe")
	player._drop_holding = true
	player._drop_hold = player.throw_charge_delay * 0.5
	assert_eq(player.get_throw_charge(), 0.0, "toque rápido não carrega")
	player._drop_hold = player.throw_charge_delay + player.throw_charge_time * 2.0
	assert_eq(player.get_throw_charge(), 1.0, "satura no máximo")
	player._drop_holding = false
	player._drop_hold = 0.0


func test_nearby_items_ui_tracks_close_pickups() -> void:
	var player: Player = _spawn_player()
	assert_not_null(player.nearby_items_ui, "camada dos pontinhos no HUD")
	var worm: ToolData = load("res://items/tools/minhoca.tres") as ToolData
	var near: ItemPickup = ItemPickup.spawn(self, CarriedItem.create_from_tool_data(worm), player.global_position + Vector3(0, 0, -3))
	var far: ItemPickup = ItemPickup.spawn(self, CarriedItem.create_from_tool_data(worm), player.global_position + Vector3(0, 0, -40))
	player.nearby_items_ui.call("refresh_targets")
	assert_eq(player.nearby_items_ui.call("get_target_count"), 1, "só o perto entra")
	near.queue_free()
	far.queue_free()


func test_held_models_for_food_dynamite_and_museum_item() -> void:
	var player: Player = _spawn_player()
	for i: int in player.inventory.slots.size():
		if player.inventory.slots[i] != null:
			player.inventory.remove_at(i)

	# 1. Dinamite na mão
	var dyn_data: ToolData = load("res://items/tools/dinamite.tres") as ToolData
	player.inventory.add_item(CarriedItem.create_from_tool_data(dyn_data))
	player.inventory.select(0)
	assert_true(player.tool_view.visible, "ToolView visível com dinamite")
	var dyn_model: Node3D = player._held_models.get(&"dinamite") as Node3D
	assert_not_null(dyn_model, "modelo da dinamite registado")
	assert_true(dyn_model.visible, "modelo da dinamite visível")

	# 2. Comida escavada na mão e subida à boca ao comer
	var worm_data: ToolData = load("res://items/tools/minhoca.tres") as ToolData
	var worm_carried: CarriedItem = CarriedItem.create_from_tool_data(worm_data)
	player.inventory.add_item(worm_carried)
	player.inventory.select(1)
	assert_true(player.tool_view.visible, "ToolView visível com minhoca")
	var worm_model: Node3D = player._held_models.get(&"minhoca") as Node3D
	assert_not_null(worm_model, "modelo da minhoca registado")
	assert_true(worm_model.visible, "modelo da minhoca visível")
	assert_false(dyn_model.visible, "modelo da dinamite escondido ao trocar")
	assert_not_null(worm_model.get_node_or_null(^"FoodMesh"), "FoodModel gerou malha")
	player._equip_left = 0.0
	player.health = 50.0
	player.start_eating(worm_carried)
	player.update_eating(0.5, true)
	player.update_tool_sway(0.01)
	assert_gt(player.tool_sway.position.y, 0.03, "comida sobe em direção à boca ao comer")
	player.cancel_eating()

	# 3. Achado do museu no HeldMuseumItem e recuo ao carregar arremesso [Q]
	var coin_data: ItemData = load("res://items/catalog/moeda_antiga.tres") as ItemData
	var coin_carried: CarriedItem = CarriedItem.create(coin_data, 50, 1.0, false)
	player.inventory.add_item(coin_carried)
	player.inventory.select(2)
	var held_museum: Node3D = player.tool_view.get_node_or_null(^"HeldMuseumItem") as Node3D
	assert_not_null(held_museum, "contentor HeldMuseumItem existe no ToolView")
	assert_true(player.tool_view.visible, "ToolView visível com achado do museu")
	assert_true(held_museum.visible, "HeldMuseumItem visível com moeda_antiga")
	assert_eq(held_museum.get_child_count(), 1, "malha do achado instanciada dentro de HeldMuseumItem")
	assert_false(worm_model.visible, "modelo da comida escondido ao selecionar achado")

	# Trocar de volta para ferramenta limpa HeldMuseumItem
	player.inventory.select(0)
	assert_false(held_museum.visible, "HeldMuseumItem escondido ao voltar para ferramenta")
	assert_eq(held_museum.get_child_count(), 0, "HeldMuseumItem limpo ao sair do achado")


func test_shovel_swing_alternates_sides() -> void:
	var player: Player = _spawn_player()
	var anim: ShovelDigAnimator = player.dig_animator
	var side_before: float = anim._swing_side

	anim.play_swing()
	var side_first: float = anim._swing_side
	assert_eq(side_first, -side_before, "1.º golpe inverte _swing_side")
	var back_first_dx: float = (anim.camera.global_transform.affine_inverse() * anim._pose(ShovelDigAnimator.Target.SWING_BACK)).origin.x - anim.rest_pose.origin.x
	var hit_first_dx: float = (anim.camera.global_transform.affine_inverse() * anim._pose(ShovelDigAnimator.Target.SWING_HIT)).origin.x - anim.rest_pose.origin.x

	anim.play_swing()
	var side_second: float = anim._swing_side
	assert_eq(side_second, -side_first, "2.º golpe volta a inverter _swing_side")
	var back_second_dx: float = (anim.camera.global_transform.affine_inverse() * anim._pose(ShovelDigAnimator.Target.SWING_BACK)).origin.x - anim.rest_pose.origin.x
	var hit_second_dx: float = (anim.camera.global_transform.affine_inverse() * anim._pose(ShovelDigAnimator.Target.SWING_HIT)).origin.x - anim.rest_pose.origin.x

	assert_lt(back_first_dx * back_second_dx, 0.0, "SWING_BACK espelha o deslocamento X entre golpes")
	assert_lt(hit_first_dx * hit_second_dx, 0.0, "SWING_HIT espelha o deslocamento X entre golpes")


func test_shovel_swing_chains_at_sixty_percent_of_return() -> void:
	var player: Player = _spawn_player()
	var anim: ShovelDigAnimator = player.dig_animator
	assert_true(anim.can_chain_swing(), "pode iniciar golpe quando parado")

	# Pré-saca a pá para a sequência do swing ser apenas [SWING_BACK(0.08), SWING_HIT(0.10), REST(0.18)]
	anim._drawn = true
	anim.rig.visible = true
	anim.play_swing()
	var first_side: float = anim._swing_side
	assert_false(anim.can_chain_swing(), "não encadeia no início do golpe (SWING_BACK)")

	# Avança até metade do passo final Target.REST (0.08 + 0.10 + 0.18 * 0.5 = 0.27s < 60% do regresso)
	anim._process(0.08 + 0.10 + 0.18 * 0.5)
	assert_true(anim.is_playing(), "ainda a regressar ao repouso")
	assert_false(anim.can_chain_swing(), "ainda não encadeia aos 50% da volta")

	# Avança até >= 60% do passo final Target.REST (+0.03s -> ~66% da volta)
	anim._process(0.03)
	assert_true(anim.is_playing(), "ainda no passo final REST")
	assert_true(anim.can_chain_swing(), "permite encadear aos >= 60% da volta")

	# _handle_attack_action permite iniciar novo ataque emendado mesmo durante o fim do swing
	Input.action_press("attack")
	player._handle_attack_action()
	Input.action_release("attack")
	assert_eq(anim._swing_side, -first_side, "novo golpe emendado inverteu o lado")
	assert_eq(anim._step, 0, "reiniciou a sequência de swing no passo 0")

