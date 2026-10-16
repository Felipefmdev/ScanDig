extends GutTest

## #57: ataques caóticos dos chefes e inimigos da Praia e do Campo (empurrões, tinta, roubo,
## mola da cobra...). Os chefes correm passo a passo com _physics_process direto.

const KING_SCENE: PackedScene = preload("res://gameplay/enemies/boss/king_crab.tscn")
const OCTOPUS_SCENE: PackedScene = preload("res://gameplay/enemies/boss/octopus.tscn")
const MOLE_BOSS_SCENE: PackedScene = preload("res://gameplay/enemies/boss/giant_mole.tscn")
const CROW_KING_SCENE: PackedScene = preload("res://gameplay/enemies/boss/crow_king.tscn")
const SCARECROW_SCENE: PackedScene = preload("res://gameplay/enemies/boss/scarecrow.tscn")
const CRAB_SCENE: PackedScene = preload("res://gameplay/enemies/crab/crab.tscn")
const SEAGULL_SCENE: PackedScene = preload("res://gameplay/enemies/seagull/seagull.tscn")
const SNAKE_SCENE: PackedScene = preload("res://gameplay/enemies/snake/snake.tscn")
const MOLE_SCENE: PackedScene = preload("res://gameplay/enemies/mole/mole.tscn")
const CROW_SCENE: PackedScene = preload("res://gameplay/enemies/crow/crow.tscn")

const DT: float = 1.0 / 60.0


class ChaosDummy extends Node3D:
	var damage_taken: float = 0.0
	var knockbacks: Array[Vector3] = []
	var held_tool_id: StringName = &"forcado"
	var ink: float = 0.0
	var disarm: float = 0.0
	var disarm_ended: bool = false
	var snare: float = 0.0

	func _ready() -> void:
		add_to_group("player")
		add_to_group("players")

	func take_damage(amount: float) -> void:
		damage_taken += amount

	func apply_knockback(impulse: Vector3, _shake: float = 0.0) -> void:
		knockbacks.append(impulse)

	func apply_ink(seconds: float) -> void:
		ink = seconds

	func apply_disarm(seconds: float) -> void:
		disarm = seconds

	func end_disarm() -> void:
		disarm_ended = true

	func apply_snare(seconds: float) -> void:
		snare = seconds

	func biggest_knockback() -> Vector3:
		var best: Vector3 = Vector3.ZERO
		for k: Vector3 in knockbacks:
			if k.length() > best.length():
				best = k
		return best


var arena: Node3D
var dummy: ChaosDummy


func before_each() -> void:
	QuestRewards.reset_session()
	arena = Node3D.new()
	add_child_autofree(arena)
	dummy = ChaosDummy.new()
	arena.add_child(dummy)


func _spawn(scene: PackedScene, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n: Node3D = scene.instantiate() as Node3D
	arena.add_child(n)
	n.global_position = pos
	return n


## Chão plano (layer 1) para quem anda com move_and_slide.
func _add_floor() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	arena.add_child(floor_body)


func _step(e: EnemyBase, seconds: float) -> void:
	for i: int in int(seconds / DT):
		e._physics_process(DT)
		if e.has_method(&"_process"):
			e._process(DT)


func _step_until(e: EnemyBase, state_value: int, max_seconds: float) -> bool:
	for i: int in int(max_seconds / DT):
		e._physics_process(DT)
		if e.has_method(&"_process"):
			e._process(DT)
		if int(e.get("state")) == state_value:
			return true
	return false


# ---------------------------------------------------------------------------
# Caranguejo-Rei
# ---------------------------------------------------------------------------

func test_king_crab_chaos_cycle_rotates() -> void:
	var king: KingCrab = _spawn(KING_SCENE) as KingCrab
	king.wake_immediately()
	assert_eq(king.next_chaos_attack(), KingCrab.State.SPIN_TELEGRAPH)
	assert_eq(king.next_chaos_attack(), KingCrab.State.BELLY_TELEGRAPH)
	assert_eq(king.next_chaos_attack(), KingCrab.State.THROW_TELEGRAPH)


func test_king_crab_spin_knocks_player_and_ends_dizzy() -> void:
	var king: KingCrab = _spawn(KING_SCENE) as KingCrab
	king.wake_immediately()
	dummy.global_position = Vector3(4.0, 0.0, 0.0)
	king.call("_enter_state", KingCrab.State.SPIN_TELEGRAPH)
	assert_true(_step_until(king, KingCrab.State.SPIN, 2.0), "telegrafa e depois gira")
	assert_true(_step_until(king, KingCrab.State.DIZZY, king.spin_time + 1.0), "acaba tonto")
	assert_gt(dummy.damage_taken, 0.0)
	assert_gt(dummy.biggest_knockback().y, 5.0, "o pião atira o jogador ao ar")
	assert_true(king.is_weak_point_exposed(), "tonto = ponto fraco")


func test_king_crab_belly_flop_lands_on_marked_point() -> void:
	var king: KingCrab = _spawn(KING_SCENE) as KingCrab
	king.wake_immediately()
	dummy.global_position = Vector3(5.0, 0.0, 0.0)
	king.call("_enter_state", KingCrab.State.BELLY_TELEGRAPH)
	var mark: Vector3 = king.net_attack_point
	assert_almost_eq(mark.x, 5.0, 0.01, "o círculo fica onde o jogador estava")
	assert_true(_step_until(king, KingCrab.State.DIZZY, 3.0))
	assert_almost_eq(king.global_position.x, 5.0, 0.1, "aterrou no círculo")
	assert_gt(dummy.biggest_knockback().length(), 10.0)


func test_king_crab_throws_three_crabs() -> void:
	var king: KingCrab = _spawn(KING_SCENE) as KingCrab
	king.wake_immediately()
	dummy.global_position = Vector3(0.0, 0.0, -6.0)
	king.call("_enter_state", KingCrab.State.THROW_TELEGRAPH)
	assert_eq(king.throw_points().size(), KingCrab.THROW_COUNT)
	assert_true(_step_until(king, KingCrab.State.RECOVER, 3.0))
	var crabs: int = 0
	for c: Node in arena.get_children():
		if c is Crab:
			crabs += 1
	assert_eq(crabs, KingCrab.THROW_COUNT, "os pequenos ficam a lutar onde caem")
	assert_gt(dummy.damage_taken, 0.0, "o do meio cai em cima do jogador")


# ---------------------------------------------------------------------------
# Polvo do Naufrágio
# ---------------------------------------------------------------------------

func test_octopus_cycle_has_spin_grab_and_ink() -> void:
	var octo: Octopus = _spawn(OCTOPUS_SCENE) as Octopus
	octo.wake_immediately()
	var seen: Array[int] = []
	for i: int in Octopus.ATTACK_CYCLE.size():
		seen.append(octo.next_attack())
	assert_has(seen, Octopus.State.SPIN_TELEGRAPH)
	assert_has(seen, Octopus.State.GRAB_TELEGRAPH)
	assert_has(seen, Octopus.State.INK_TELEGRAPH)


func test_octopus_spins_out_and_comes_back_home() -> void:
	var octo: Octopus = _spawn(OCTOPUS_SCENE) as Octopus
	octo.wake_immediately()
	var home: Vector3 = octo.global_position
	dummy.global_position = Vector3(6.0, 0.0, 0.0)
	octo.net_attack_dir = Vector3.RIGHT
	octo.call("_enter_state", Octopus.State.SPIN_TELEGRAPH)
	assert_true(_step_until(octo, Octopus.State.STUCK, 6.0), "roda e fica tonto")
	assert_gt(octo.global_position.distance_to(home), 3.0, "saiu a rodar pela praia")
	assert_gt(dummy.biggest_knockback().length(), 8.0)
	assert_true(octo.is_weak_point_exposed())
	assert_true(_step_until(octo, Octopus.State.IDLE, 10.0), "volta para casa")
	assert_lt(octo.global_position.distance_to(home), 0.5)


func test_octopus_grab_throws_player_to_sea() -> void:
	var octo: Octopus = _spawn(OCTOPUS_SCENE) as Octopus
	octo.wake_immediately()
	dummy.global_position = Vector3(0.0, 0.0, 6.0)
	octo.net_attack_point = dummy.global_position
	octo.call("_enter_state", Octopus.State.GRAB_TELEGRAPH)
	assert_true(_step_until(octo, Octopus.State.STUCK, 3.0))
	var k: Vector3 = dummy.biggest_knockback()
	assert_lt(k.z, -5.0, "atirado por cima do polvo, para o lado da água")
	assert_gt(k.y, 8.0)


func test_octopus_ink_blinds_players_in_strip() -> void:
	var octo: Octopus = _spawn(OCTOPUS_SCENE) as Octopus
	octo.wake_immediately()
	dummy.global_position = Vector3(0.0, 0.0, -5.0)
	octo.net_attack_dir = Vector3.FORWARD
	octo.call("_enter_state", Octopus.State.INK_TELEGRAPH)
	assert_true(_step_until(octo, Octopus.State.IDLE, 3.0))
	assert_almost_eq(dummy.ink, Octopus.INK_SECONDS, 0.01, "tinta no ecrã")


# ---------------------------------------------------------------------------
# Toupeira Gigante
# ---------------------------------------------------------------------------

func test_giant_mole_erupt_launches_and_gets_stuck() -> void:
	var boss: GiantMole = _spawn(MOLE_BOSS_SCENE) as GiantMole
	boss.wake_immediately()
	dummy.global_position = Vector3(0.3, 0.0, 0.0)
	boss._erupts_left = 1
	boss.call("_enter_state", GiantMole.State.ERUPT_TELEGRAPH)
	assert_true(_step_until(boss, GiantMole.State.DAZED, 3.0))
	assert_gt(dummy.biggest_knockback().y, 10.0, "irrompe e atira ao ar")
	assert_true(boss.is_stuck_in_hole())
	_step(boss, 0.5)
	assert_lt(boss.body_root.position.y, -0.5, "entalada: meio corpo dentro do buraco")


func test_giant_mole_surf_wave_pushes_sideways() -> void:
	var boss: GiantMole = _spawn(MOLE_BOSS_SCENE) as GiantMole
	boss.wake_immediately()
	# Debaixo de terra a ir para -Z; o jogador está mesmo ao lado do monte (à direita).
	boss.call("_enter_state", GiantMole.State.TUNNEL)
	var bystander: ChaosDummy = dummy
	bystander.global_position = boss.global_position + Vector3(0.6, 0.0, 0.0)
	boss._surf_wave(Vector3.FORWARD, 8.0)
	assert_gt(bystander.knockbacks.size(), 0, "a onda de terra apanhou quem estava no caminho")
	assert_gt(bystander.biggest_knockback().x, 4.0, "atirado para o lado")


func test_giant_mole_bowling_rock_rolls_along_strip() -> void:
	var boss: GiantMole = _spawn(MOLE_BOSS_SCENE) as GiantMole
	boss.wake_immediately()
	dummy.global_position = Vector3(0.0, 0.0, -8.0)
	boss.call("_enter_state", GiantMole.State.ROCK_TELEGRAPH)
	assert_true(_step_until(boss, GiantMole.State.ROCK, 2.0))
	assert_true(_step_until(boss, GiantMole.State.RECOVER, 3.0))
	assert_gt(dummy.damage_taken, 0.0, "strike!")
	assert_lt(dummy.biggest_knockback().z, -8.0, "empurrado na direção da rocha")


# ---------------------------------------------------------------------------
# Corvo-Rei
# ---------------------------------------------------------------------------

func test_crow_king_steals_tool_and_drops_it_when_hit() -> void:
	var ck: CrowKing = _spawn(CROW_KING_SCENE) as CrowKing
	ck.wake_immediately()
	dummy.global_position = Vector3(3.0, 0.0, 0.0)
	ck._cycle_index = 1  # o próximo é o roubo
	ck.call("_start_attack")
	assert_eq(ck.state, CrowKing.State.STEAL_TELEGRAPH)
	assert_true(_step_until(ck, CrowKing.State.CARRY, 4.0), "rasante e foge com ela")
	assert_almost_eq(dummy.disarm, CrowKing.DISARM_SECONDS, 0.01)
	assert_eq(ck.net_stolen_tool, &"forcado")
	ck.take_damage(5.0)
	assert_false(ck.is_carrying_tool(), "acertar-lhe faz largar a ferramenta")
	assert_true(dummy.disarm_ended, "o dono recupera-a logo")


func test_crow_king_tornado_pulls_then_grounded() -> void:
	var ck: CrowKing = _spawn(CROW_KING_SCENE) as CrowKing
	ck.wake_immediately()
	dummy.global_position = Vector3(3.0, 0.0, 0.0)
	ck.net_attack_point = Vector3.ZERO
	ck.call("_enter_state", CrowKing.State.TORNADO_TELEGRAPH)
	assert_true(_step_until(ck, CrowKing.State.TORNADO, 3.0))
	_step(ck, 1.0)
	assert_gt(dummy.knockbacks.size(), 1, "puxa várias vezes")
	assert_lt(dummy.knockbacks[0].x, 0.0, "para o centro")
	assert_true(_step_until(ck, CrowKing.State.GROUNDED, 4.0), "exausto no chão")
	assert_true(ck.is_weak_point_exposed())


func test_crow_king_screw_dive_knocks_back() -> void:
	var ck: CrowKing = _spawn(CROW_KING_SCENE) as CrowKing
	ck.wake_immediately()
	dummy.global_position = Vector3(0.5, 0.0, 0.0)
	ck.net_attack_point = Vector3.ZERO
	ck.call("_enter_state", CrowKing.State.TELEGRAPH)
	assert_true(_step_until(ck, CrowKing.State.GROUNDED, 4.0))
	assert_gt(dummy.biggest_knockback().y, 8.0)


# ---------------------------------------------------------------------------
# Espantalho Desperto
# ---------------------------------------------------------------------------

func test_scarecrow_pumpkin_bounces_then_explodes() -> void:
	var sc: Scarecrow = _spawn(SCARECROW_SCENE) as Scarecrow
	sc.wake_immediately()
	sc.net_attack_point = Vector3(0.0, 0.0, -6.0)
	var bounce: Vector3 = Vector3.ZERO
	sc.call("_enter_state", Scarecrow.State.THROW_TELEGRAPH)
	bounce = sc.bounce_point()
	assert_lt(bounce.z, -8.0, "salta para a frente, na direção do lançamento")
	dummy.global_position = bounce
	assert_true(_step_until(sc, Scarecrow.State.WALK, 4.0))
	assert_gt(dummy.damage_taken, 0.0, "rebenta no 2.º círculo")
	assert_gt(dummy.biggest_knockback().length(), 5.0)


func test_scarecrow_straw_reassembles_elsewhere() -> void:
	var sc: Scarecrow = _spawn(SCARECROW_SCENE) as Scarecrow
	sc.wake_immediately()
	sc.net_attack_point = Vector3(4.0, 0.0, 0.0)
	dummy.global_position = Vector3(4.5, 0.0, 0.0)
	sc.call("_enter_state", Scarecrow.State.STRAW_OUT)
	assert_false(sc._can_take_damage(), "desfeito em palha não leva dano")
	assert_true(_step_until(sc, Scarecrow.State.WALK, 3.0))
	assert_almost_eq(sc.global_position.x, 4.0, 0.3, "remontou no círculo")
	assert_gt(dummy.biggest_knockback().length(), 5.0, "e atira quem lá estava")


func test_scarecrow_whirl_runs_and_ends_dizzy() -> void:
	var sc: Scarecrow = _spawn(SCARECROW_SCENE) as Scarecrow
	sc.wake_immediately()
	dummy.global_position = Vector3(0.0, 0.0, -3.0)
	sc.call("_enter_state", Scarecrow.State.WHIRL_TELEGRAPH)
	assert_true(_step_until(sc, Scarecrow.State.DIZZY, 6.0))
	assert_gt(dummy.knockbacks.size(), 0)
	assert_true(sc.is_weak_point_exposed())


# ---------------------------------------------------------------------------
# Inimigos
# ---------------------------------------------------------------------------

func test_crab_side_rush_hits_player_and_crashes_into_crab() -> void:
	_add_floor()
	var crab: Crab = _spawn(CRAB_SCENE) as Crab
	_step(crab, 1.0)
	var other: Crab = _spawn(CRAB_SCENE, Vector3(5.0, 0.0, 0.0)) as Crab
	_step(other, 1.0)
	other.global_position = Vector3(5.0, 0.0, 0.0)
	dummy.global_position = Vector3(2.5, 0.0, 0.0)
	crab.start_rush(Vector3.RIGHT)
	assert_eq(crab.state, Crab.State.RUSH_TELEGRAPH)
	_step(crab, Crab.RUSH_TELEGRAPH_TIME + 1.0)
	assert_gt(dummy.biggest_knockback().x, 5.0, "atirado na direção da corrida")
	assert_true(other.is_stunned(), "o outro caranguejo ficou tonto com o choque")


func test_seagull_kamikaze_miss_sticks_beak() -> void:
	var gull: Seagull = _spawn(SEAGULL_SCENE, Vector3(0.0, 7.0, 0.0)) as Seagull
	dummy.global_position = Vector3(8.0, 0.0, 0.0)
	gull.net_dive_point = Vector3.ZERO  # ninguém lá
	gull.call("_enter_state", Seagull.State.KAMIKAZE_TELEGRAPH)
	assert_true(_step_until(gull, Seagull.State.STUCK, 4.0))
	assert_true(gull.is_beak_stuck())
	assert_eq(dummy.knockbacks.size(), 0)


func test_seagull_kamikaze_hit_knocks_player() -> void:
	var gull: Seagull = _spawn(SEAGULL_SCENE, Vector3(0.0, 7.0, 0.0)) as Seagull
	dummy.global_position = Vector3.ZERO
	gull.net_dive_point = Vector3.ZERO
	gull.call("_enter_state", Seagull.State.KAMIKAZE_TELEGRAPH)
	_step(gull, 2.5)
	assert_gt(dummy.knockbacks.size(), 0)
	assert_false(gull.is_beak_stuck(), "acertou: não se espeta")


func test_snake_spring_wraps_player_and_snares() -> void:
	var snake: Snake = _spawn(SNAKE_SCENE) as Snake
	_step(snake, 0.6)
	dummy.global_position = Vector3(0.0, 0.0, -4.0)
	snake.start_spring(dummy.global_position)
	assert_true(_step_until(snake, Snake.State.WRAP, 3.0), "salta como mola e enrola-se")
	assert_almost_eq(dummy.snare, Snake.WRAP_TIME, 0.01)
	# O jogador soltou-se e afastou-se: a cobra é sacudida e fica tonta.
	dummy.global_position = Vector3(0.0, 0.0, -8.0)
	_step(snake, 0.1)
	assert_false(snake.is_wrapping())
	assert_true(snake.is_stunned())


func test_mole_launches_player_up() -> void:
	var mole: Mole = _spawn(MOLE_SCENE) as Mole
	dummy.global_position = Vector3(0.2, 0.0, 0.0)
	mole.call("_enter_state", Mole.State.TELEGRAPH)
	_step(mole, mole.telegraph_time + 0.1)
	assert_gt(dummy.biggest_knockback().y, 8.0)


func test_crow_spiral_ends_with_peck_and_lift() -> void:
	var crow: Crow = _spawn(CROW_SCENE, Vector3(3.0, 2.5, 0.0)) as Crow
	dummy.global_position = Vector3.ZERO
	crow._update_target(1.0)
	crow.net_dive_point = Vector3.ZERO
	crow.call("_enter_state", Seagull.State.SPIRAL_TELEGRAPH)
	assert_true(_step_until(crow, Seagull.State.SPIRAL, 2.0))
	assert_true(_step_until(crow, Seagull.State.CIRCLE, Crow.SPIRAL_TIME + 1.0))
	assert_gt(dummy.biggest_knockback().y, 5.0, "bicada no fim da espiral atira ao ar")
