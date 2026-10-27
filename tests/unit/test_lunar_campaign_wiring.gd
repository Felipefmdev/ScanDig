extends GutTest

func test_lunar_guardian_is_registered_in_existing_enemy_spawner() -> void:
	assert_true(EnemySpawner.has_kind_scene(&"lunar_warden"),"Use the existing authoritative enemy spawner")
	assert_true(GameState.EXTRA_BOSSES.has("lunar_warden"),"Core must accept the new boss's report")
	var journal: Script = load("res://ui/base_station_ui.gd")
	assert_true(journal.BOSS_ORDER.has("lunar_warden"),"The field journal must include the final-map boss")
	assert_true(journal.BOSS_FIELD_META.has("lunar_warden"),"Use a localized name instead of exposing the internal boss id")

func test_moon_authors_an_altar_and_a_boss_only_enemy_spawner() -> void:
	var scene: PackedScene = load("res://world/map_lua.tscn") as PackedScene
	var state: SceneState = scene.get_state()
	var altar_count: int = 0
	var spawner_count: int = 0
	for index: int in state.get_node_count():
		if state.get_node_name(index) == &"LunarAltar": altar_count += 1
		if state.get_node_name(index) == &"EnemySpawner":
			spawner_count += 1
			var properties: Dictionary = {}
			for prop: int in state.get_node_property_count(index):
				properties[String(state.get_node_property_name(index,prop))] = state.get_node_property_value(index,prop)
			assert_eq(properties.get("ambient_enabled"),false)
			assert_eq(properties.get("primary_kind"),&"")
			assert_eq(properties.get("secondary_kind"),&"")
	assert_eq(altar_count,1)
	assert_eq(spawner_count,1)
