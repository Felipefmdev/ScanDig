extends GutTest

## #68: Testes de regressão para validação precoce de BossTrigger sem cena e EnemySpawner com dados inválidos.


func test_boss_trigger_can_spawn_boss_and_trigger_invalid_kind() -> void:
	var trigger: BossTrigger = BossTrigger.new()
	trigger.boss_kind = &"chefe_inexistente_999"
	trigger.night = true
	add_child_autoqfree(trigger)

	assert_false(trigger.can_spawn_boss(), "can_spawn_boss tem de devolver false para kind sem cena")
	assert_false(trigger.start(), "start() tem de recusar iniciar se nao ha cena valida")
	assert_false(trigger.triggered, "triggered nao pode ficar true quando falha validacao")
	assert_false(trigger.is_night, "is_night nao pode ser ativado se o chefe nao existe")

	trigger.trigger()
	assert_null(trigger.boss, "boss deve continuar null apos trigger() com kind invalido")
	assert_false(trigger.triggered, "triggered continua false")
	assert_false(trigger.is_night, "is_night continua false")


func test_boss_trigger_empty_kind_no_fallback() -> void:
	var trigger: BossTrigger = BossTrigger.new()
	trigger.boss_kind = &""
	add_child_autoqfree(trigger)

	assert_false(trigger.can_spawn_boss(), "kind vazio sem fallback devolve false")
	assert_false(trigger.start(), "start() devolve false")
	assert_null(trigger.boss, "boss nulo")


func test_boss_trigger_spawn_boss_null_owner_or_invalid_kind() -> void:
	assert_null(BossTrigger.spawn_boss(null, &"octopus", Vector3.ZERO, 0.0), "owner_node nulo devolve null")

	var dummy: Node3D = Node3D.new()
	add_child_autoqfree(dummy)

	assert_null(BossTrigger.spawn_boss(dummy, &"", Vector3.ZERO, 0.0), "kind vazio devolve null")
	assert_null(BossTrigger.spawn_boss(dummy, &"monstro_alien_inexistente", Vector3.ZERO, 0.0), "kind sem cena devolve null")


func test_enemy_spawner_is_valid_spawn_data() -> void:
	assert_false(EnemySpawner.is_valid_spawn_data(null), "null nao e spawn data valido")
	assert_false(EnemySpawner.is_valid_spawn_data("string"), "string nao e spawn data valido")
	assert_false(EnemySpawner.is_valid_spawn_data(1234), "int nao e spawn data valido")
	assert_false(EnemySpawner.is_valid_spawn_data({}), "dicionario vazio nao e spawn data valido")
	assert_false(EnemySpawner.is_valid_spawn_data({"pos": "nao_vetor", "kind": "crab"}), "pos invalido rejeitado")
	assert_false(EnemySpawner.is_valid_spawn_data({"pos": Vector3.ZERO, "kind": ""}), "kind vazio rejeitado")
	assert_true(EnemySpawner.is_valid_spawn_data({"pos": Vector3.ZERO, "kind": "crab"}), "string kind valido aceite")
	assert_true(EnemySpawner.is_valid_spawn_data({"pos": Vector3.ZERO, "kind": &"crab"}), "StringName kind valido aceite")


func test_enemy_spawner_spawn_from_data_invalid_data_returns_null() -> void:
	var spawner: EnemySpawner = EnemySpawner.new()
	add_child_autoqfree(spawner)

	assert_null(spawner.spawn_from_data({}), "dados vazios devolvem null")
	assert_null(spawner.spawn_from_data(null), "dados nulos devolvem null")
	assert_null(spawner.spawn_from_data({"pos": Vector3.ZERO, "kind": "criatura_sem_cena_xyz"}), "kind sem cena devolve null")


func test_enemy_spawner_create_from_data_handles_variants_cleanly() -> void:
	var spawner: EnemySpawner = EnemySpawner.new()
	add_child_autoqfree(spawner)

	assert_null(spawner._create_from_data(null), "_create_from_data(null) devolve null sem SCRIPT ERROR")
	assert_null(spawner._create_from_data(42), "_create_from_data(int) devolve null sem SCRIPT ERROR")
	assert_null(spawner._create_from_data("texto"), "_create_from_data(String) devolve null sem SCRIPT ERROR")
	assert_null(spawner._create_from_data({}), "_create_from_data({}) devolve null sem SCRIPT ERROR")


func test_enemy_spawner_has_scene_for_kind() -> void:
	var spawner: EnemySpawner = EnemySpawner.new()
	add_child_autoqfree(spawner)

	assert_true(spawner.has_scene_for_kind(&"crab"), "crab tem de ter cena")
	assert_true(spawner.has_scene_for_kind(&"octopus"), "octopus tem de ter cena")
	assert_false(spawner.has_scene_for_kind(&"monstro_inexistente"), "monstro inexistente devolve false")
	assert_false(spawner.has_scene_for_kind(&""), "kind vazio devolve false")
