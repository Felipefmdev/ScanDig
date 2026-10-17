extends GutTest

## Testes unitários para o sistema de corpo carregável ao morrer em coop (#79).
## Cobre: estado downed ao morrer em expedição, transporte (carregar/largar),
## penalidade de velocidade, impedimento de ações, reanimação na base e validações.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _spawn(node_name: String, pos: Vector3 = Vector3.ZERO) -> Player:
	var p: Player = PLAYER_SCENE.instantiate() as Player
	p.name = node_name
	p.position = pos
	_root.add_child(p)
	return p


func _create_sell_point(pos: Vector3 = Vector3.ZERO, radius: float = 3.0) -> SellPoint:
	var sp: SellPoint = SellPoint.new()
	sp.radius = radius
	sp.position = pos
	_root.add_child(sp)
	return sp


func test_solo_player_death_respawns_normally() -> void:
	var p: Player = _spawn("1")
	p.allow_downed = false
	p.take_damage(p.max_health)
	assert_false(p.is_downed, "Sem coop/allow_downed o jogador renasce normalmente")
	assert_eq(p.health, p.max_health)
	assert_true(p.is_alive())


func test_downed_state_on_death_in_coop() -> void:
	var p: Player = _spawn("1")
	p.allow_downed = true
	watch_signals(p)

	p.take_damage(p.max_health)

	assert_true(p.is_downed, "Ao morrer com allow_downed deve entrar em estado caído")
	assert_eq(p.health, 0.0)
	assert_false(p.is_alive())
	assert_signal_emitted(p, "player_downed")

	# Grupos de targeting de inimigos
	assert_false(p.is_in_group(Player.LOCAL_GROUP), "Jogador caído não deve estar no grupo local de aggro")
	assert_false(p.is_in_group(Player.ALL_GROUP), "Jogador caído sai de players para não ser perseguido")
	assert_true(p.is_in_group(Player.DOWNED_GROUP), "Jogador caído entra em downed_players")

	# Representação no Avatar
	assert_not_null(p.avatar)
	assert_true(p.avatar.is_downed())
	assert_almost_eq(p.avatar.rotation.x, deg_to_rad(-90.0), 0.01, "Avatar deve estar deitado no chão")


func test_downed_player_cannot_move_or_act() -> void:
	var p: Player = _spawn("1")
	p.allow_downed = true
	p.enter_downed()

	# Física do jogador caído: velocidade horizontal anula-se/desacelera
	p.velocity = Vector3(5.0, 0.0, 0.0)
	var initial_speed: float = p.velocity.length()
	p._physics_process(0.1)
	assert_lt(p.velocity.length(), initial_speed, "Velocidade horizontal deve desacelerar para parar")

	# Não pode cavar nem bater
	assert_true(p.is_downed)
	p.take_damage(20.0)
	assert_eq(p.health, 0.0, "Jogador já caído não recebe mais dano normal")


func test_carry_transport_mechanic() -> void:
	var carrier: Player = _spawn("1", Vector3(0, 0, 0))
	var downed: Player = _spawn("2", Vector3(1, 0, 0))
	downed.allow_downed = true
	downed.enter_downed()
	watch_signals(carrier)

	carrier.carry_player(downed)

	assert_eq(carrier.carried_player, downed, "Carrier deve referenciar o jogador caído")
	assert_eq(downed.carried_by, carrier, "Jogador caído deve referenciar o carrier")
	assert_eq(downed.collision_layer, 0, "Colisão do corpo carregado deve ser 0 para não colidir com o carrier")
	assert_signal_emitted(carrier, "player_carried")

	# Penalidade de velocidade
	var normal_speed: float = carrier.speed
	var carry_speed: float = carrier.get_target_speed(Vector2(0, -1))
	assert_almost_eq(carry_speed, normal_speed * carrier.carry_speed_multiplier, 0.01)

	# Ações bloqueadas enquanto carrega
	carrier._handle_dig_actions()
	assert_false(carrier.dig_animator.is_playing(), "Não pode cavar enquanto carrega um corpo")

	# Rastreio de posição no _physics_process
	carrier.global_position = Vector3(10, 0, 10)
	carrier._physics_process(0.016)
	assert_almost_eq(downed.global_position.x, 10.0, 0.5, "Corpo deve acompanhar a posição do transportador")
	assert_almost_eq(downed.global_position.z, 10.0, 0.5)


func test_drop_transport_mechanic() -> void:
	var carrier: Player = _spawn("1", Vector3(0, 0, 0))
	var downed: Player = _spawn("2", Vector3(1, 0, 0))
	downed.allow_downed = true
	downed.enter_downed()
	carrier.carry_player(downed)
	watch_signals(carrier)

	carrier.drop_carried_player()

	assert_null(carrier.carried_player)
	assert_null(downed.carried_by)
	assert_eq(downed.collision_layer, 1, "Colisão deve voltar a 1 ao ser largado no chão")
	assert_true(downed.is_downed, "Continua em estado caído após ser largado")
	assert_signal_emitted(carrier, "player_dropped")


func test_reanimation_at_sell_point_base() -> void:
	var sp: SellPoint = _create_sell_point(Vector3(0, 0, 0), 4.0)
	var carrier: Player = _spawn("1", Vector3(1, 0, 0))
	var downed: Player = _spawn("2", Vector3(1.5, 0, 0))
	downed.allow_downed = true
	downed.enter_downed()
	carrier.carry_player(downed)
	watch_signals(downed)

	# Reanima na base
	carrier.revive_player(downed)

	assert_false(downed.is_downed, "Jogador não deve mais estar em estado caído")
	assert_true(downed.is_alive())
	assert_gt(downed.health, 0.0)
	assert_almost_eq(downed.health, downed.max_health * 0.5, 0.1)
	assert_null(carrier.carried_player)
	assert_null(downed.carried_by)
	assert_eq(downed.collision_layer, 1)

	# Retorno aos grupos de jogo
	assert_false(downed.is_in_group(Player.DOWNED_GROUP))
	assert_true(downed.is_in_group(Player.ALL_GROUP))

	# Avatar de pé
	assert_false(downed.avatar.is_downed())
	assert_almost_eq(downed.avatar.rotation.x, 0.0, 0.01)
	assert_signal_emitted(downed, "player_revived")


func test_cannot_revive_outside_base_in_host_validation() -> void:
	var carrier: Player = _spawn("1", Vector3(50, 0, 50))
	var downed: Player = _spawn("2", Vector3(51, 0, 50))
	downed.allow_downed = true
	downed.enter_downed()
	carrier.carry_player(downed)

	# Tentar reanimar fora de um SellPoint via validação de host não reanima
	carrier._host_validate_and_revive(carrier, downed)
	assert_true(downed.is_downed, "Não pode reanimar fora da base")


func test_cannot_carry_alive_player_or_if_already_carrying() -> void:
	var p1: Player = _spawn("1", Vector3(0, 0, 0))
	var p2: Player = _spawn("2", Vector3(1, 0, 0))
	var p3: Player = _spawn("3", Vector3(2, 0, 0))

	# Não pode carregar jogador vivo
	p1.carry_player(p2)
	assert_null(p1.carried_player, "Não pode carregar jogador vivo")

	# Derruba p2
	p2.allow_downed = true
	p2.enter_downed()
	p1.carry_player(p2)
	assert_eq(p1.carried_player, p2)

	# Derruba p3; p1 já está a carregar p2 e não pode carregar p3
	p3.allow_downed = true
	p3.enter_downed()
	p1.carry_player(p3)
	assert_eq(p1.carried_player, p2, "Não pode carregar dois jogadores ao mesmo tempo")


func test_carrier_death_drops_carried_body() -> void:
	var carrier: Player = _spawn("1", Vector3(0, 0, 0))
	var downed: Player = _spawn("2", Vector3(1, 0, 0))
	downed.allow_downed = true
	downed.enter_downed()
	carrier.carry_player(downed)

	# Se o carrier morrer, larga o colega
	carrier.allow_downed = true
	carrier.take_damage(carrier.max_health)

	assert_null(carrier.carried_player, "Morte do carregador deve largar o corpo transportado")
	assert_null(downed.carried_by)
	assert_true(downed.is_downed)
	assert_true(carrier.is_downed)


func test_interaction_prompt_when_carrying_and_targeting() -> void:
	var sp: SellPoint = _create_sell_point(Vector3(0, 0, 0), 5.0)
	var carrier: Player = _spawn("1", Vector3(1, 0, 0))
	var downed: Player = _spawn("2", Vector3(1.5, 0, 0))
	downed.allow_downed = true
	downed.enter_downed()

	# Pega no corpo enquanto próximo
	carrier.carry_player(downed)
	assert_eq(carrier.carried_player, downed)

	# Fora da base
	carrier.global_position = Vector3(100, 0, 100)
	carrier._update_interaction_target()
	assert_true(carrier.interact_prompt.text.contains("Largar"), "Prompt fora da base deve indicar largar corpo")

	# Dentro da base
	carrier.global_position = Vector3(1, 0, 0)
	carrier._update_interaction_target()
	assert_true(carrier.interact_prompt.text.contains("Reanimar"), "Prompt dentro da base deve indicar reanimar colega")


func test_downed_orbital_camera_rotates_and_zooms_without_affecting_carrier() -> void:
	var p: Player = _spawn("1", Vector3(0, 0, 0))
	var carrier: Player = _spawn("2", Vector3(1, 0, 0))
	p.allow_downed = true
	p.enter_downed()

	assert_true(p.avatar.visible, "Avatar local visível em 3.ª pessoa quando caído")
	var initial_angles: Vector2 = p.get_downed_orbit_angles()
	var initial_dist: float = p.get_downed_orbit_distance()
	var initial_cam_pos: Vector3 = p.camera.global_position

	# Movimento do rato roda yaw/pitch orbital sem rodar o corpo caído
	var body_rot_before: float = p.rotation.y
	p.apply_mouse_look(Vector2(120.0, -60.0))
	var angles_after: Vector2 = p.get_downed_orbit_angles()
	assert_ne(angles_after.x, initial_angles.x, "Yaw orbital rodou com o rato")
	assert_ne(angles_after.y, initial_angles.y, "Pitch orbital rodou com o rato")
	assert_eq(p.rotation.y, body_rot_before, "Corpo caído não roda ao mover a câmara orbital")
	assert_ne(p.camera.global_position, initial_cam_pos, "Posição global da câmara orbital mudou")

	# Zoom com limites [DOWNED_ORBIT_MIN_DIST, DOWNED_ORBIT_MAX_DIST]
	p.zoom_downed_orbit(-0.5)
	assert_lt(p.get_downed_orbit_distance(), initial_dist, "Zoom in aproxima a câmara")
	p.zoom_downed_orbit(-10.0)
	assert_almost_eq(p.get_downed_orbit_distance(), Player.DOWNED_ORBIT_MIN_DIST, 0.001, "Zoom mínimo respeitado")
	p.zoom_downed_orbit(20.0)
	assert_almost_eq(p.get_downed_orbit_distance(), Player.DOWNED_ORBIT_MAX_DIST, 0.001, "Zoom máximo respeitado")

	# Carregar não altera a câmara em 1.ª pessoa do colega que carrega
	carrier.carry_player(p)
	assert_almost_eq(carrier.head.position.y, 1.6, 0.01, "Câmara de quem carrega mantém altura de 1.ª pessoa")


func test_downed_give_up_hold_progress_and_emergency_rescue_to_base() -> void:
	var p: Player = _spawn("1", Vector3(0, 0, 0))
	p.allow_downed = true
	# Afasta o jogador da base e adiciona um item na mochila antes de cair
	p.global_position = Vector3(25.0, 0.0, -18.0)
	p.enter_downed()
	var coin: ItemData = load("res://items/catalog/moeda_antiga.tres") as ItemData
	p.inventory.add_item(CarriedItem.create(coin, 50, 1.0, false))
	assert_eq(p.inventory.get_count(), 1)
	assert_true(p.give_up_bar.visible, "Barra de desistência visível quando caído")
	assert_true(p.interact_prompt.text.contains("resgate de emergência na base"), "Prompt ScanDig visível quando caído")

	# Segurar 0.5 s (< 1.0 s) avança a barra a 50% mas não desiste
	p.update_downed_give_up(0.5, true)
	assert_true(p.is_downed, "Com 0.5s ainda continua caído")
	assert_almost_eq(p.give_up_progress_ratio(), 0.5, 0.01, "Progresso aos 50%")
	assert_almost_eq(p.give_up_bar.value, 50.0, 1.0, "Barra de progresso em 50%")
	assert_true(p.interact_prompt.text.contains("50%"), "Prompt mostra percentagem do hold")

	# Largar o botão zera o progresso
	p.update_downed_give_up(0.1, false)
	assert_eq(p.give_up_progress_ratio(), 0.0, "Soltar [E] reinicia o progresso")
	assert_true(p.is_downed)

	# Segurar >= 1.0 s conclui o resgate de emergência na base e larga a mochila onde caiu
	p.update_downed_give_up(0.5, true)
	p.update_downed_give_up(0.55, true)
	assert_false(p.is_downed, "Aos >= 1.0s deixa de estar caído")
	assert_true(p.is_alive(), "Jogador está vivo após resgate na base")
	assert_eq(p.health, p.max_health, "Vida restaurada na base")
	assert_almost_eq(p.global_position.distance_to(Vector3.ZERO), 0.0, 0.05, "Reapareceu no ponto de partida (base)")
	assert_eq(p.inventory.get_count(), 0, "Mochila largada no local onde caiu")
	assert_false(p.give_up_bar.visible, "Barra de desistência escondida ao regressar à base")


func test_downed_camera_and_hud_cleanup_on_revive() -> void:
	var _sp: SellPoint = _create_sell_point(Vector3(0, 0, 0), 4.0)
	var p: Player = _spawn("1", Vector3(1, 0, 0))
	p.allow_downed = true
	p.enter_downed()
	p.apply_mouse_look(Vector2(80.0, -40.0))
	p.update_downed_give_up(0.4, true)
	assert_true(p.give_up_bar.visible)
	assert_true(p.avatar.visible)

	# Reanimação limpa HUD de caído e restaura câmara em 1.ª pessoa
	p.revive()
	assert_false(p.is_downed)
	assert_eq(p.give_up_progress_ratio(), 0.0, "Progresso de desistir limpo ao reviver")
	assert_false(p.give_up_bar.visible, "Barra de desistir escondida ao reviver")
	assert_eq(p.interact_prompt.text, "", "Prompt limpo ao reviver")
	assert_false(p.avatar.visible, "Avatar local volta a ficar invisível em 1.ª pessoa")
	assert_almost_eq(p.head.position.y, 1.6, 0.01, "Head volta à altura de 1.ª pessoa")
	assert_almost_eq(p.camera.position.length(), 0.0, 0.01, "Câmara volta à origem da Head")

