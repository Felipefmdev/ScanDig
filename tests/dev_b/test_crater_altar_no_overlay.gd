extends GutTest

## #115: o CraterAltar não tem mais overlay de vitória/créditos próprio nem reporta/salva a
## derrota do the_sleeper (o próprio chefe reporta). Vitória e créditos: VictoryScreen, no
## gold_colossus.


func before_each() -> void:
	GameState.instance.reset_state()


func after_each() -> void:
	if VictoryScreen.instance != null:
		VictoryScreen.instance.close()
	GameState.instance.reset_state()


func _canvas_layers(node: Node) -> int:
	var count: int = 1 if node is CanvasLayer else 0
	for child: Node in node.get_children():
		count += _canvas_layers(child)
	return count


func test_altar_api_without_overlay() -> void:
	var altar: CraterAltar = CraterAltar.new()
	add_child_autofree(altar)
	assert_false(altar.has_method(&"show_victory_and_credits"))
	assert_null(altar.get(&"_victory_overlay"))
	assert_null(altar.get(&"_credits_shown"))
	assert_eq(altar.boss_scene.resource_path, CraterAltar.SLEEPER_SCENE_PATH, "spawn do chefe preservado")
	assert_not_null(altar.get_node_or_null(^"Totem"), "totem preservado")
	assert_eq(altar.label_text, CraterAltar.DEFAULT_LABEL)


func test_defeated_sleeper_shows_nothing() -> void:
	var gs: GameState = GameState.instance
	gs._host_report_boss_defeated("the_sleeper")
	var altar: CraterAltar = CraterAltar.new()
	add_child_autofree(altar)
	await wait_frames(3)
	assert_eq(_canvas_layers(altar), 0, "nenhum CanvasLayer no altar com o the_sleeper vencido")
	assert_null(get_tree().root.find_child("VictoryCreditsOverlay", true, false))
	assert_true(gs.is_game_completed())


func test_boss_spawned_has_no_overlay_hooks() -> void:
	var altar: CraterAltar = CraterAltar.new()
	add_child_autofree(altar)
	var own: int = 0
	for connection: Dictionary in altar.boss_spawned.get_connections():
		var target: Callable = connection["callable"]
		if target.get_object() == altar:
			own += 1
	assert_eq(own, 0, "o altar não escuta o próprio boss_spawned (só servia ao overlay)")
