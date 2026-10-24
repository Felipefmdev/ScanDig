extends GutTest

## Primeira etapa da #120: mapa independente antes de liberar a viagem.
const SCENE_PATH: String = "res://world/map_lua.tscn"


func test_scene_has_physical_terrain_and_multiplayer_contract() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "Cena lunar precisa existir")
	if not ResourceLoader.exists(SCENE_PATH):
		return
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var map: Node3D = packed.instantiate() as Node3D
	assert_not_null(map.get_node_or_null("Terrain/Ground") as StaticBody3D)
	assert_not_null(map.get_node_or_null("Players/PlayerSpawner") as MultiplayerSpawner)
	assert_not_null(map.get_node_or_null("Bounds") as StaticBody3D)
	assert_not_null(map.get_node_or_null("WorldEnvironment") as WorldEnvironment)
	assert_not_null(map.get_node_or_null("LunarArrival") as Node3D, "Chegada lunar integrada à cena")
	var players: Node3D = map.get_node("Players") as Node3D
	assert_almost_eq(players.position.x, 0.0, 0.001)
	assert_almost_eq(players.position.z, 18.0, 0.001)
	map.free()
