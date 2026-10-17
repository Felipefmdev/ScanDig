extends GutTest

## Testes unitários para os 7 modelos 3D low-poly de comidas escavadas (#83).

const FOODS: Array[String] = [
	"minhoca",
	"tatuira",
	"marisco",
	"batata_esquecida",
	"cogumelo_cripta",
	"liquen_gelado",
	"larva_termica",
]


func test_every_food_has_valid_world_scene() -> void:
	for id: String in FOODS:
		var res_path: String = "res://items/tools/%s.tres" % id
		var td: ToolData = load(res_path) as ToolData
		assert_not_null(td, "ToolData carregado para %s" % id)
		assert_not_null(td.world_scene, "world_scene definida para %s" % id)
		if td.world_scene == null:
			continue
		var instance: Node3D = td.world_scene.instantiate() as Node3D
		assert_not_null(instance, "Instancia criada para %s" % id)
		add_child_autofree(instance)
		var model: Node3D = instance.get_node_or_null(^"Model") as Node3D
		assert_not_null(model, "No Model presente para %s" % id)
		var food_mesh: MeshInstance3D = model.get_node_or_null(^"FoodMesh") as MeshInstance3D
		assert_not_null(food_mesh, "MeshInstance FoodMesh presente para %s" % id)
		assert_not_null(food_mesh.mesh, "Mesh gerada para %s" % id)
		assert_gt(food_mesh.mesh.get_surface_count(), 0, "Superficie gerada para %s" % id)
		var aabb: AABB = food_mesh.mesh.get_aabb()
		assert_lt(aabb.get_longest_axis_size(), 0.35, "%s cabe na mao (%.2f m)" % [id, aabb.get_longest_axis_size()])


func test_pickup_with_food_uses_world_scene() -> void:
	var td: ToolData = load("res://items/tools/minhoca.tres") as ToolData
	var carried: CarriedItem = CarriedItem.create_from_tool_data(td)
	var pickup: ItemPickup = ItemPickup.create(carried)
	add_child_autofree(pickup)
	assert_not_null(pickup.get_node_or_null(^"minhoca_world"), "Pickup usa a world_scene da minhoca")
	assert_null(pickup.get(&"_mesh"), "Sem cubo gerado de fallback")
