extends GutTest

## #42: testes do chefe principal das Ruínas — Guardião Ancestral.
## Cobre armadura de pedra, placas de jade, pisão, bowling, pião/tonto, fase 2 e troféu.

const GUARDIAN_SCENE: PackedScene = preload("res://gameplay/enemies/boss/ancient_guardian.tscn")

var arena: Node3D
var boss: AncientGuardian


func before_each() -> void:
	QuestRewards.reset_session()
	arena = Node3D.new()
	add_child_autofree(arena)
	boss = GUARDIAN_SCENE.instantiate() as AncientGuardian
	arena.add_child(boss)
	boss.wake_immediately()


func test_boss_stats_and_groups() -> void:
	assert_eq(boss.max_health, 1400.0)
	assert_eq(boss.health, 1400.0)
	assert_true(boss.is_in_group(&"enemies"))
	assert_true(boss.is_in_group(&"bosses"))
	assert_eq(AncientGuardian.BOSS_ID, &"ancient_guardian")
	assert_eq(boss.collision_layer, 8)
	assert_true(EnemySpawner.KIND_SCENES.has(&"ancient_guardian"))


func test_stone_armor_reduces_damage() -> void:
	boss.take_damage(40.0)
	# 40 * 0.25 = 10 dano
	assert_almost_eq(boss.health, 1390.0, 0.01, "armadura de pedra: apenas 25% de dano")


func test_stepping_on_lit_plate_exposes_weak_point() -> void:
	var dummy: DamageDummy = DamageDummy.new()
	dummy.add_to_group(&"players")
	arena.add_child(dummy)

	boss.lit_plate = 0
	var plate_pos: Vector3 = boss.plate_position(0)
	dummy.global_position = plate_pos

	boss._enemy_physics(0.1)
	assert_eq(boss.state, AncientGuardian.State.EXPOSED, "pisar a placa ativa ajoelha o colosso")
	assert_true(boss.is_exposed())

	boss.take_damage(40.0)
	# 40 * 2.5 = 100 dano no núcleo exposto
	assert_almost_eq(boss.health, 1300.0, 0.01, "exposto: 250% de dano")


func test_stomp_deals_damage_and_knockback() -> void:
	var dummy: DamageDummy = DamageDummy.new()
	dummy.add_to_group(&"players")
	arena.add_child(dummy)
	dummy.global_position = boss.global_position + Vector3(2.0, 0.0, 0.0)

	boss._enter_state(AncientGuardian.State.STOMP_TELE)
	assert_eq(boss.state, AncientGuardian.State.STOMP_TELE)

	boss._enemy_physics(boss.tele_time + 0.1)
	assert_eq(boss.state, AncientGuardian.State.STOMP)
	boss._enemy_physics(0.15)
	assert_gt(dummy.damage_taken, 0.0, "pisão fere o jogador próximo")


func test_spin_attack_leads_to_dizzy_state() -> void:
	boss._enter_state(AncientGuardian.State.SPIN)
	assert_eq(boss.state, AncientGuardian.State.SPIN)

	# Simula o tempo do pião terminar
	boss._enemy_physics(boss.spin_time + 0.1)
	assert_eq(boss.state, AncientGuardian.State.DIZZY, "após girar fica tonto")

	# Tonto: dano inteiro (1.0x), sem armadura
	boss.take_damage(40.0)
	assert_almost_eq(boss.health, 1360.0, 0.01, "tonto: dano total (1.0x)")


func test_phase_two_triggers_under_fifty_percent() -> void:
	assert_eq(boss.phase, 1)
	assert_false(boss.is_phase_two())

	boss.take_damage(3000.0) # 3000 * 0.25 = 750 dano -> 650 HP restante (< 50%)
	assert_true(boss.is_phase_two())
	assert_eq(boss.phase, 2)
	assert_eq(boss._bowl_dirs().size(), 2, "na fase 2 atira 2 pedregulhos em leque")


func test_defeat_emits_signal_and_drops_trophy() -> void:
	watch_signals(boss)
	boss.take_damage(6000.0)
	assert_true(boss.health <= 0.0)
	assert_eq(boss.state, AncientGuardian.State.DYING)

	# Avança tempo de morte
	boss._process_dying()
	boss._state_time = 1.3
	boss._process_dying()

	assert_signal_emitted_with_parameters(boss, "boss_defeated", [AncientGuardian.BOSS_ID])
	assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % AncientGuardian.TROPHY_ITEM_ID))
