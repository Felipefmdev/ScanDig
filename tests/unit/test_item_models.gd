extends GutTest

## #61: modelos low-poly dos itens de museu (items/item_models.gd).

const CATALOG_DIR: String = "res://items/catalog/"
const REFERENCE_DIR: String = "res://docs/art/reference/"
## Os itens têm de caber, mais ou menos, na caixa de colisão do pickup (0.24 m).
const MAX_SIZE: float = 0.4


func _catalog_ids_with_reference() -> Array[String]:
	var ids: Array[String] = []
	for f: String in DirAccess.get_files_at(CATALOG_DIR):
		if not f.ends_with(".tres"):
			continue
		var item: ItemData = load(CATALOG_DIR + f) as ItemData
		if item != null and FileAccess.file_exists(REFERENCE_DIR + item.id + ".jpg"):
			ids.append(item.id)
	return ids


func test_every_referenced_catalog_item_has_a_model() -> void:
	var ids: Array[String] = _catalog_ids_with_reference()
	assert_gt(ids.size(), 20, "Há referências para a maioria do catálogo")
	for id: String in ids:
		var model: Node3D = ItemModels.build(id)
		assert_not_null(model, "Modelo para %s" % id)
		if model == null:
			continue
		var mesh_found: bool = false
		var box: AABB = AABB()
		for child: Node in model.get_children():
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi != null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
				box = mi.mesh.get_aabb() if not mesh_found else box.merge(mi.mesh.get_aabb())
				mesh_found = true
		assert_true(mesh_found, "%s tem geometria" % id)
		assert_lt(box.get_longest_axis_size(), MAX_SIZE, "%s cabe na mão (%.2f m)" % [id, box.get_longest_axis_size()])
		model.free()


func test_unknown_id_has_no_model() -> void:
	assert_null(ItemModels.build("nao_existe"))


func test_pickup_uses_model_instead_of_cube() -> void:
	var item: ItemData = load(CATALOG_DIR + "idolo_ouro.tres") as ItemData
	var pickup: ItemPickup = ItemPickup.create(CarriedItem.create(item, item.base_value, 1.0, false))
	add_child_autofree(pickup)
	assert_not_null(pickup.get_node_or_null(^"ItemModel"), "Pickup mostra o modelo do ídolo")
	assert_null(pickup.get(&"_mesh"), "Sem cubo de recurso")
