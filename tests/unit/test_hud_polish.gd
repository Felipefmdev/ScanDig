extends GutTest

## #32 (pilha de mensagens do HUD por baixo do chefe), #34 (texto da pazada vazia por mapa) e
## #35 (cabeça do avatar remoto não se descola ao olhar para baixo).

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _spawn_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	return player


func test_messages_stack_below_boss_bar_and_cap_at_three() -> void:
	var player: Player = _spawn_player()
	var stack: Control = player.message_stack
	# BossHud: painel em offset_top 70..125 (king_crab/giant_mole). A pilha começa por baixo.
	assert_gt(stack.offset_top, 125.0, "pilha por baixo da barra do chefe")
	assert_eq(stack.anchor_top, 0.0, "presa ao topo, longe do prompt [E] (centro)")
	for i: int in 4:
		player._show_temporary_message("msg %d" % i)
	assert_eq(player.get_hud_messages(), PackedStringArray(["msg 1", "msg 2", "msg 3"]), "só as 3 mais recentes")


func test_stack_caps_total_lines() -> void:
	var player: Player = _spawn_player()
	player._show_temporary_message("Golpe com a pá!")
	player._show_temporary_message("DESCOBERTA\nIntegridade\n[E] apanhar")
	player._show_temporary_message("Só areia")
	assert_eq(player.get_hud_messages().size(), 2, "4 linhas no máximo: sai a mais antiga")
	assert_eq(player.get_hud_messages()[1], "Só areia")


func test_repeated_message_refreshes_instead_of_stacking() -> void:
	var player: Player = _spawn_player()
	for i: int in 3:
		player._show_temporary_message("Só areia")
	assert_eq(player.get_hud_messages(), PackedStringArray(["Só areia"]))


func test_threat_message_uses_the_same_stack() -> void:
	var player: Player = _spawn_player()
	player._show_temporary_message("Golpe com a pá!")
	player._show_threat_message(Player.THREAT_MESSAGES[0], 1.0)
	assert_eq(player.get_hud_messages(), PackedStringArray(["Golpe com a pá!", Player.THREAT_MESSAGES[0]]))
	assert_null(player.get_node_or_null(^"HUD/ThreatMessageLabel"), "sem label solto no meio do ecrã")
	assert_null(player.get_node_or_null(^"HUD/FeedbackLabel"))


func test_empty_dig_message_matches_the_map_ground() -> void:
	assert_string_contains(Player.empty_dig_message_for("praia"), "Só areia")
	assert_string_contains(Player.empty_dig_message_for("campo"), "Só terra")
	assert_false(Player.empty_dig_message_for("campo").contains("areia"), "#34: no Campo não há areia")
	assert_string_contains(Player.empty_dig_message_for(""), "Nada aqui")


func test_avatar_head_stays_on_the_neck_when_looking_down() -> void:
	for pitch: float in [-1.5, -1.2, -0.9, -0.3, 0.0, 0.6, 1.4]:
		var lean: float = PlayerAvatar.get_torso_lean(pitch)
		var head: float = PlayerAvatar.get_head_pitch(pitch, lean)
		assert_lte(absf(head), PlayerAvatar.HEAD_PITCH_MAX + 0.0001, "cabeça dentro do limite (pitch %.1f)" % pitch)
		assert_lte(absf(lean), PlayerAvatar.TORSO_LEAN_MAX + 0.0001, "tronco dentro do limite (pitch %.1f)" % pitch)
		assert_true(signf(lean) == signf(pitch) or is_zero_approx(lean), "o tronco inclina para o mesmo lado")
	assert_almost_eq(PlayerAvatar.get_torso_lean(-0.3), 0.0, 0.0001, "pitch pequeno: só a cabeça roda")
	var avatar: PlayerAvatar = PlayerAvatar.new()
	add_child_autofree(avatar)
	avatar.set_pitch(-1.2)
	var pivot: Node3D = avatar.get_node(^"UpperBody/HeadPivot") as Node3D
	var torso: MeshInstance3D = avatar.get_node(^"UpperBody/Torso") as MeshInstance3D
	assert_not_null(torso)
	# Base do pescoço = topo do tronco: o pivô fica colado ao tronco mesmo com o tronco inclinado.
	var torso_top: Vector3 = torso.position + Vector3(0.0, 0.31, 0.0)
	assert_almost_eq(pivot.position.distance_to(torso_top), 0.0, 0.001)
	assert_lt(avatar.get_node(^"UpperBody").rotation.x, 0.0, "a olhar para baixo inclina o tronco")
