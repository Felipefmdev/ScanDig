extends GutTest

## #42, #57: testes do chefe escondido das Ruínas — Múmia do Ídolo.
## Cobre puxão de ligaduras, invocação de morcegos, tornado, tonta/exposta (2.5x dano), fase 2 e troféu.

const MUMMY_SCENE: PackedScene = preload("res://gameplay/enemies/boss/idol_mummy.tscn")

var arena: Node3D
var boss: IdolMummy


func before_each() -> void:
	QuestRewards.reset_session()
	arena = Node3D.new()
	add_child_autofree(arena)
	boss = MUMMY_SCENE.instantiate() as IdolMummy
	arena.add_child(boss)
	boss.wake_immediately()


func test_boss_stats_and_spawner_registration() -> void:
	assert_eq(boss.max_health, 1100.0)
	assert_eq(boss.health, 1100.0)
	assert_true(boss.is_in_group(&"enemies"))
	assert_true(boss.is_in_group(&"bosses"))
	assert_eq(IdolMummy.BOSS_ID, &"idol_mummy")
	assert_eq(boss.collision_layer, 8)
	assert_true(EnemySpawner.KIND_SCENES.has(&"idol_mummy"), "registado em KIND_SCENES do spawner")


func test_bandage_pull_drags_player_and_damages() -> void:
	var dummy: DamageDummy = DamageDummy.new()
	dummy.add_to_group(&"players")
	arena.add_child(dummy)
	dummy.global_position = boss.global_position + Vector3(0.0, 0.0, -8.0)

	boss.net_attack_dir = Vector3(0.0, 0.0, -1.0)
	boss._enter_state(IdolMummy.State.PULL_TELE)
	assert_eq(boss.state, IdolMummy.State.PULL_TELE)

	boss._enemy_physics(boss.pull_telegraph + 0.1)
	assert_eq(boss.state, IdolMummy.State.PULL)
	boss._enemy_physics(0.2)
	assert_gt(dummy.damage_taken, 0.0, "puxão de ligaduras causa dano")


func test_tornado_leads_to_dizzy_state_and_weak_point() -> void:
	boss._enter_state(IdolMummy.State.TORNADO)
	assert_eq(boss.state, IdolMummy.State.TORNADO)

	# Simula o término do tornado
	boss._enemy_physics(boss.tornado_time + 0.1)
	assert_eq(boss.state, IdolMummy.State.DIZZY, "tornado descontrolado deixa múmia tonta")
	assert_true(boss.is_weak_point_exposed(), "ponto fraco exposto quando tonta")

	# Quando tonta, recebe 2.5x de dano
	boss.take_damage(20.0)
	# 20 * 2.5 = 50 dano
	assert_almost_eq(boss.health, 1050.0, 0.01, "dano multiplicado por 2.5x quando tonta")


func test_summon_attack_cycles() -> void:
	var dummy: DamageDummy = DamageDummy.new()
	dummy.add_to_group(&"players")
	arena.add_child(dummy)
	dummy.global_position = boss.global_position + Vector3(2.0, 0.0, 0.0)

	boss._enter_state(IdolMummy.State.SUMMON_TELE)
	boss._enemy_physics(boss.summon_telegraph + 0.1)
	assert_eq(boss.state, IdolMummy.State.SUMMON)
	boss._enemy_physics(0.15)
	assert_gt(dummy.damage_taken, 0.0, "enxame causa dano na proximidade")


func test_phase_two_triggers_below_fifty_percent() -> void:
	assert_eq(boss.phase, 1)
	assert_false(boss.is_phase_two())

	boss.take_damage(600.0)
	assert_true(boss.is_phase_two(), "vida < 50% ativa fase 2")
	assert_eq(boss.phase, 2)


func test_defeat_emits_signal_and_drops_trophy() -> void:
	watch_signals(boss)
	boss.take_damage(2000.0)
	assert_true(boss.health <= 0.0)
	assert_eq(boss.state, IdolMummy.State.DYING)

	boss._process_dying()
	boss._state_time = 1.3
	boss._process_dying()

	assert_signal_emitted_with_parameters(boss, "boss_defeated", [IdolMummy.BOSS_ID])
	assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % IdolMummy.TROPHY_ITEM_ID), "trofeu ligaduras_mumia existe no catalogo")
