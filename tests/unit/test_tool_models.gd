extends GutTest

## #37: modelos toon das ferramentas (pá, kit médico, repelente, estilingue) na mão, na banca e
## no chão. Regra da #47: as peças geradas não têm owner (o editor nunca as grava no .tscn).

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const MODELS: Dictionary = {
	"res://gameplay/player/shovel_model.gd": ["Metal", "Wood"],
	"res://gameplay/weapons/medkit/medkit_model.gd": ["Case", "Iron", "Decals"],
	"res://gameplay/weapons/repellent/repellent_model.gd": ["Can", "Rims", "Label", "LabelText"],
	"res://gameplay/weapons/slingshot/slingshot_model.gd": ["Body", "Wraps", "Band"],
}
const TOOLS: Array[String] = ["estilingue", "repelente", "kit_medico"]


func _make(path: String) -> Node3D:
	var model: Node3D = Node3D.new()
	model.set_script(load(path) as Script)
	add_child_autofree(model)
	return model


func test_models_build_toon_parts_without_owner() -> void:
	for path: String in MODELS:
		var model: Node3D = _make(path)
		for part_name: String in MODELS[path]:
			var part: Node = model.get_node_or_null(NodePath(part_name))
			assert_not_null(part, "%s tem %s" % [path.get_file(), part_name])
			if part == null:
				continue
			assert_null(part.owner, "%s/%s sem owner (#47)" % [path.get_file(), part_name])
			var mi: MeshInstance3D = part as MeshInstance3D
			if mi != null:
				assert_true(mi.material_override is ShaderMaterial, "%s/%s com material toon" % [path.get_file(), part_name])
				assert_gt(mi.mesh.get_surface_count(), 0)
				assert_not_null(mi.material_override.next_pass, "%s/%s com contorno" % [path.get_file(), part_name])


func test_rebuild_does_not_duplicate_parts() -> void:
	var model: Node3D = _make("res://gameplay/weapons/medkit/medkit_model.gd")
	var before: int = model.get_child_count()
	model._ready()
	await get_tree().process_frame
	assert_eq(model.get_child_count(), before, "o _ready repetido (editor) limpa as peças antigas")


func test_shovel_blade_tip_at_origin_and_shaft_along_y() -> void:
	var model: Node3D = _make("res://gameplay/player/shovel_model.gd")
	var aabb: AABB = (model.get_node("Metal") as MeshInstance3D).mesh.get_aabb()
	aabb = aabb.merge((model.get_node("Wood") as MeshInstance3D).mesh.get_aabb())
	assert_almost_eq(aabb.position.y, 0.0, 0.01, "ponta da lâmina na origem do rig")
	assert_between(aabb.end.y, 0.95, 1.1, "pá com ~1 m ao longo de +Y")
	assert_lt(aabb.size.x, 0.3)


func test_slingshot_pull_rebuilds_band() -> void:
	var model: SlingshotModel = _make("res://gameplay/weapons/slingshot/slingshot_model.gd") as SlingshotModel
	var band: MeshInstance3D = model.get_node("Band") as MeshInstance3D
	var rest_z: float = band.mesh.get_aabb().end.z
	model.pull = 1.0
	assert_gt(band.mesh.get_aabb().end.z, rest_z + 0.1, "a bolsa recua ao puxar")


func test_tool_data_world_scene_poses() -> void:
	for id: String in TOOLS:
		var td: ToolData = load("res://items/tools/%s.tres" % id) as ToolData
		assert_not_null(td.world_scene, "%s tem world_scene" % id)
		# Banca: o modelo assenta no tampo (origem); chão: desce para a base da caixa do pickup.
		var shop: Node3D = Node3D.new()
		add_child_autofree(shop)
		var on_shop: Node3D = td.world_scene.instantiate() as Node3D
		shop.add_child(on_shop)
		var pickup: ItemPickup = ItemPickup.create(CarriedItem.create_from_tool_data(td))
		add_child_autofree(pickup)
		var on_ground: Node3D = null
		for child: Node in pickup.get_children():
			if child.scene_file_path == td.world_scene.resource_path:
				on_ground = child as Node3D
		assert_not_null(on_ground, "%s no chão usa o modelo" % id)
		if on_ground == null:
			continue
		var shop_pose: Transform3D = (on_shop.get_node("Model") as Node3D).transform
		var ground_pose: Transform3D = (on_ground.get_node("Model") as Node3D).transform
		assert_ne(shop_pose, ground_pose, "%s: pose da banca e do chão diferentes" % id)
		assert_lt(ground_pose.origin.y, 0.0, "%s: no chão desce para a base do pickup" % id)


func test_player_shows_held_tool_model() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	for id: String in TOOLS:
		var td: ToolData = load("res://items/tools/%s.tres" % id) as ToolData
		player.inventory.slots[0] = null
		player.inventory.add_item(CarriedItem.create_from_tool_data(td))
		player.inventory.select(0)
		player._update_tool_in_hand()
		assert_true(player.tool_view.visible, "%s na mão" % id)
		var shown: int = 0
		for child: Node in player.tool_view.get_children():
			if child is Node3D and child.name != &"ToolHand" and (child as Node3D).visible:
				shown += 1
				assert_null(child.owner if child.name.begins_with("Held") else null, "modelo da mão sem owner")
		assert_eq(shown, 1, "%s: só um modelo visível" % id)
	player.inventory.slots[0] = null
	player.inventory.notify_changed()
	player._update_tool_in_hand()
	assert_false(player.tool_view.visible, "mão vazia")


func test_has_own_interact_target_without_targets() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	assert_false(player.has_own_interact_target(), "sem banca, item no chão nem entrega")
