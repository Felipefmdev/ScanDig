extends GutTest

## #186 geometry budget for the Campo prototype. Images, not these thresholds,
## decide whether the landscape feels open; these checks prevent the old tall ring.
const BACKDROP: Script = preload("res://gameplay/environment/backdrop.gd")


func test_exterior_terrain_is_low_instead_of_a_tall_perimeter_ridge() -> void:
	var highest: float = -INF
	for axis: float in [-46.0, -42.0, -36.0, 36.0, 42.0, 46.0]:
		for along: int in range(-46, 47, 2):
			highest = maxf(highest, FieldTerrain.height_at(axis, float(along)))
			highest = maxf(highest, FieldTerrain.height_at(float(along), axis))
	assert_lt(highest, 2.0, "Exterior should be low meadow, not the former 5-8m ring")


func test_far_campo_landforms_are_low_and_in_separate_groups() -> void:
	var backdrop: Node3D = BACKDROP.new()
	backdrop.set("theme", "campo")
	autofree(backdrop)
	var placed: int = int(backdrop.call("build"))
	assert_gt(placed, 4, "Keep a landscape beyond the play area")
	assert_lte(placed, 10, "Leave large sectors between landform groups")
	var hills: MeshInstance3D = backdrop.get_node("Hills") as MeshInstance3D
	assert_not_null(hills.mesh)
	assert_lte(hills.mesh.get_aabb().end.y, 6.0, "Distant low hills replace towering tips")
	assert_eq(backdrop.find_children("*", "CollisionObject3D", true, false).size(), 0)


func test_playable_ground_at_spawn_and_quest_landmarks_is_unchanged() -> void:
	# Exterior shaping must not flatten the actual play/quest terrain.
	assert_almost_eq(FieldTerrain.height_at(0, 0), 0.0, 0.0001)
	assert_almost_eq(FieldTerrain.height_at(3.5, 3.5), 0.0, 0.0001)
	assert_almost_eq(FieldTerrain.height_at(-18, -18), 0.0, 0.0001)
	assert_gt(FieldTerrain.height_at(15, -20), -1.0, "Farm is not turned into a pit")
