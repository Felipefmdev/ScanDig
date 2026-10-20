extends GutTest

## Regressão #150: o raycast dos adereços acertava o topo das paredes invisíveis.
func test_border_rocks_follow_sand_instead_of_invisible_walls() -> void:
	var scene: Node3D = (load("res://world/map_praia.tscn") as PackedScene).instantiate() as Node3D
	add_child_autoqfree(scene)
	await wait_frames(10)
	var scatter: Node3D = scene.get_node("DecorationScatter") as Node3D
	var wall_hit: Vector3 = scatter.call("_ground_at", Vector3(-30.5, 0.0, 10.0))
	assert_lt(wall_hit.y, 2.0, "Não apoiar no topo da parede invisível de 6 m")
	var checked: int = 0
	var unsupported: int = 0
	for child: Node in scatter.get_children():
		if not String(child.name).begins_with("Deco_border_"):
			continue
		var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
		for i: int in mm.instance_count:
			var p: Vector3 = mm.get_instance_transform(i).origin
			if p.y > BeachTerrain.height_at(p.x, p.z) + 0.2:
				unsupported += 1
			checked += 1
	assert_gt(checked, 50, "Borda efetivamente construída")
	assert_eq(unsupported, 0, "Nenhuma rocha apoiada no topo de Bounds")


func test_coastal_barrel_and_bottle_rest_on_the_sloping_beach() -> void:
	var scene: Node3D = (load("res://world/map_praia.tscn") as PackedScene).instantiate() as Node3D
	add_child_autoqfree(scene)
	await wait_frames(4)
	for path: String in ["Decor/Props/Barrel1", "Decor/Props/Barrel2", "Decor/Props/Bottle1"]:
		var prop: Node3D = scene.get_node(path) as Node3D
		var p: Vector3 = prop.global_position
		assert_lt(absf(p.y - BeachTerrain.height_at(p.x, p.z)), 0.12, "%s assente" % path)
