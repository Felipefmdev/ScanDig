extends GutTest

func test_cratera_integrates_one_rocket_without_relocating_original_props() -> void:
	var scene: PackedScene = load("res://world/map_cratera.tscn") as PackedScene
	var state: SceneState = scene.get_state()
	var found: int = 0
	for index: int in state.get_node_count():
		if state.get_node_name(index) != &"CraterRocket": continue
		found += 1
		var properties: Dictionary = {}
		for prop: int in state.get_node_property_count(index):
			properties[String(state.get_node_property_name(index,prop))] = state.get_node_property_value(index,prop)
		var transform: Transform3D = properties.get("transform",Transform3D.IDENTITY)
		assert_eq(properties.get("position",transform.origin),Vector3(-23,0,21))
		assert_eq((properties.get("script") as Script).resource_path,"res://gameplay/environment/crater_rocket.gd")
	assert_eq(found,1,"The approved rocket must be authored once in the actual map")

func test_cratera_authors_one_repair_coordinator_after_the_visual() -> void:
	var scene: PackedScene = load("res://world/map_cratera.tscn") as PackedScene
	var state: SceneState = scene.get_state()
	var found: int = 0
	for index: int in state.get_node_count():
		if state.get_node_name(index) == &"RocketStation": found += 1
	assert_eq(found,1,"The real map must configure repair interactions, not only a visual rocket")
