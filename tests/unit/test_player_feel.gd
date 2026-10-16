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
