extends GutTest

## #114: Colosso do Tesouro, o chefe disfarçado da Ilha do Tesouro.

const SCENE: PackedScene = preload("res://gameplay/enemies/boss/gold_colossus.tscn")


func _pile_at(pos: Vector3) -> TreasureModel:
	var t: TreasureModel = TreasureModel.new()
	t.add_to_group(&"island_treasures")
	add_child_autofree(t)
	t.global_position = pos
	return t


func test_registered_and_spawnable() -> void:
	assert_true(GameState.EXTRA_BOSSES.has(String(GoldColossus.BOSS_ID)), "id no GameState")
	assert_true(EnemySpawner.has_kind_scene(&"gold_colossus"), "kind no EnemySpawner (replica em coop)")
	assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % GoldColossus.TROPHY_ITEM_ID), "tesouro principal existe")
	for id: String in GoldColossus.LOOT_ITEM_IDS:
		assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % id), "achado %s existe" % id)


func test_assembles_from_the_disguised_pile_and_gives_it_back_when_leaving() -> void:
	var pile: TreasureModel = _pile_at(Vector3(5, 0, 5))
	var b: GoldColossus = SCENE.instantiate() as GoldColossus
	b.position = Vector3(5.3, 0, 5.2)
	add_child(b)
	assert_eq(b.state, GoldColossus.State.ASSEMBLE, "comeca a montar-se")
	assert_false(pile.visible, "a pilha disfarce some quando o ouro levanta voo")
	assert_false(b._can_take_damage(), "invulneravel enquanto se monta")
	b.wake_immediately()
	assert_eq(b.state, GoldColossus.State.WALK)
	b.free()
	assert_true(pile.visible, "fugiu: a pilha volta ao sitio")


func test_spent_exposes_ruby_core_and_phase_two_widens_spray() -> void:
	var b: GoldColossus = SCENE.instantiate() as GoldColossus
	add_child_autofree(b)
	b.wake_immediately()
	assert_eq(b.spray_dirs().size(), 1, "fase 1: um jorro")
	b._enter_state(GoldColossus.State.SPENT)
	assert_true(b.is_weak_point_exposed(), "gasto: nucleo exposto")
	assert_almost_eq(b._modify_damage(10.0, Vector3.ZERO), 25.0, 0.01, "dano 2,5x no nucleo")
	b._enter_state(GoldColossus.State.WALK)
	b.take_damage(b.max_health * 0.6)
	assert_eq(b.phase, 2, "fase 2 abaixo de metade")
	assert_eq(b.spray_dirs().size(), 3, "fase 2: leque de tres")


func test_spray_line_geometry() -> void:
	var b: GoldColossus = SCENE.instantiate() as GoldColossus
	add_child_autofree(b)
	b.net_attack_dir = Vector3.FORWARD
	assert_true(b._in_line(b.global_position + Vector3(0.3, 0, -6), Vector3.FORWARD), "na linha")
	assert_false(b._in_line(b.global_position + Vector3(3, 0, -6), Vector3.FORWARD), "fora da linha")
	assert_false(b._in_line(b.global_position + Vector3(0, 0, 4), Vector3.FORWARD), "atras")


func test_hoard_wake_spawns_boss_once_and_counts_finds() -> void:
	var w: HoardWake = HoardWake.new()
	w.finds_to_wake = 3
	add_child_autofree(w)
	assert_eq(w.prompt, "[E] Mexer no tesouro")
	w._on_find(null, 0, 1.0)
	w._on_find(null, 0, 1.0)
	assert_false(w.boss_trigger.triggered, "ainda nao")
	w._on_find(null, 0, 1.0)
	assert_true(w.boss_trigger.triggered, "acorda ao fim de N achados")
	assert_true(w.boss_trigger.boss is GoldColossus, "nasceu o colosso")
	assert_false(w.wake(), "nao nasce duas vezes")
	autofree(w.boss_trigger.boss)


func test_island_scene_has_the_disguised_treasure() -> void:
	var scene: Node = (load("res://world/map_ilha_tesouro.tscn") as PackedScene).instantiate()
	autofree(scene)
	var w: Node = scene.get_node_or_null(^"HoardWake")
	assert_true(w is HoardWake, "tesouro certo no mapa")
	var main: Vector3 = IslandLayout.main_treasure_position()
	assert_almost_eq(Vector2((w as Node3D).position.x, (w as Node3D).position.z), Vector2(main.x, main.z), Vector2(0.5, 0.5), "na pilha do planalto")
