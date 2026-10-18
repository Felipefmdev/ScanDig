class_name CrowNest
extends StaticBody3D

## Ninho de corvo (#106).
## Estrutura rústica feita de galhos entrelaçados onde os corvos ladrões do Campo
## guardam os achados e relíquias que roubam do chão.
## Jogadores podem vasculhar o ninho ([E]) para recuperar todos os achados guardados.

signal item_stored(item: CarriedItem)
signal nest_searched(count: int)

const GROUP: StringName = &"crow_nests"

const WOOD_DARK: Color = Color(0.28, 0.18, 0.10)
const WOOD_LIGHT: Color = Color(0.42, 0.28, 0.16)
const STRAW_BED: Color = Color(0.58, 0.50, 0.26)
const SHINY_GOLD: Color = Color(1.0, 0.82, 0.22)
const SHINY_SILVER: Color = Color(0.85, 0.88, 0.92)
const SHINY_RUBY: Color = Color(0.92, 0.22, 0.28)

var stored_items: Array[CarriedItem] = []

var _model_root: Node3D = null
var _trinkets_root: Node3D = null


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactive")


func _ready() -> void:
	collision_layer = 1 | (1 << 2) # camada do mundo e interativa
	collision_mask = 1

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.height = 0.45
	cyl.radius = 0.65
	col.shape = cyl
	col.position = Vector3(0.0, 0.22, 0.0)
	add_child(col)

	_build_model()
	_update_visuals()


func get_perch_point() -> Vector3:
	return global_position + Vector3(0.0, 0.40, 0.0)


func get_item_count() -> int:
	return stored_items.size()


func store_item(item: CarriedItem) -> void:
	if item == null:
		return
	stored_items.append(item)
	_update_visuals()
	item_stored.emit(item)
	SFX.play_at(SFX.ITEM_IMPACT_STONE, global_position, -2.0, 0.1)


func take_all_items() -> Array[CarriedItem]:
	var items: Array[CarriedItem] = stored_items.duplicate()
	stored_items.clear()
	_update_visuals()
	return items


func search_nest(player: Player) -> int:
	if stored_items.is_empty():
		return 0
	var count: int = stored_items.size()
	var parent_node: Node = get_parent() if get_parent() != null else self

	for item: CarriedItem in stored_items:
		if item == null:
			continue
		# Tenta colocar na mochila se o jogador tiver espaço
		var added: bool = false
		if player != null and is_instance_valid(player) and player.inventory != null:
			if not player.inventory.is_full():
				added = player.inventory.add_item(item)
		if not added:
			# Caso contrário, arremessa no chão em volta do ninho
			var drop_pos: Vector3 = global_position + Vector3(randf_range(-0.4, 0.4), 0.5, randf_range(-0.4, 0.4))
			var impulse: Vector3 = Vector3(randf_range(-1.2, 1.2), 2.8, randf_range(-1.2, 1.2))
			ItemPickup.spawn(parent_node, item, drop_pos, impulse)

	stored_items.clear()
	_update_visuals()
	nest_searched.emit(count)
	SFX.play_at(SFX.PICKUP, global_position, -1.0, 0.1)
	return count


func _build_model() -> void:
	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	add_child(_model_root)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = WOOD_DARK
	mat.roughness = 0.9

	var straw_mat: StandardMaterial3D = StandardMaterial3D.new()
	straw_mat.albedo_color = STRAW_BED
	straw_mat.roughness = 0.85

	# Base e cama interior de palha/musgo
	var bed: MeshInstance3D = MeshInstance3D.new()
	var bed_mesh: CylinderMesh = CylinderMesh.new()
	bed_mesh.top_radius = 0.50
	bed_mesh.bottom_radius = 0.38
	bed_mesh.height = 0.16
	bed.mesh = bed_mesh
	bed.material_override = straw_mat
	bed.position = Vector3(0.0, 0.10, 0.0)
	_model_root.add_child(bed)

	# Borda de galhos entrelaçados em anel
	var twigs_parent: Node3D = Node3D.new()
	twigs_parent.name = "Twigs"
	_model_root.add_child(twigs_parent)

	var twig_mesh: BoxMesh = BoxMesh.new()
	twig_mesh.size = Vector3(0.38, 0.08, 0.08)

	for i: int in 16:
		var ang: float = float(i) * (TAU / 16.0)
		var twig: MeshInstance3D = MeshInstance3D.new()
		twig.mesh = twig_mesh
		twig.material_override = mat if (i % 2 == 0) else straw_mat
		var r: float = randf_range(0.48, 0.54)
		twig.position = Vector3(cos(ang) * r, randf_range(0.16, 0.26), sin(ang) * r)
		twig.rotation = Vector3(randf_range(-0.15, 0.15), -ang + randf_range(-0.3, 0.3), randf_range(-0.15, 0.15))
		twigs_parent.add_child(twig)

	# Camada extra de galhos finos inclinados
	for i: int in 8:
		var ang: float = float(i) * (TAU / 8.0) + 0.2
		var twig2: MeshInstance3D = MeshInstance3D.new()
		twig2.mesh = twig_mesh
		twig2.material_override = mat
		twig2.position = Vector3(cos(ang) * 0.52, 0.28, sin(ang) * 0.52)
		twig2.rotation = Vector3(0.1, -ang, 0.15)
		twigs_parent.add_child(twig2)

	# Nó para os tesouros e achados brilhantes dentro do ninho
	_trinkets_root = Node3D.new()
	_trinkets_root.name = "TrinketsRoot"
	_trinkets_root.position = Vector3(0.0, 0.18, 0.0)
	_model_root.add_child(_trinkets_root)


func _update_visuals() -> void:

	if _trinkets_root == null:
		return

	for child: Node in _trinkets_root.get_children():
		child.queue_free()

	var count: int = stored_items.size()
	if count == 0:
		return

	# Cria representações brilhantes facetadas dos achados guardados
	var colors: Array[Color] = [SHINY_GOLD, SHINY_SILVER, SHINY_RUBY, SHINY_GOLD, SHINY_SILVER]
	var offsets: Array[Vector3] = [
		Vector3(-0.12, 0.02, -0.08),
		Vector3(0.14, 0.04, -0.06),
		Vector3(0.02, 0.05, 0.12),
		Vector3(-0.08, 0.06, 0.08),
		Vector3(0.08, 0.03, -0.14),
	]

	var shiny_mat: StandardMaterial3D = StandardMaterial3D.new()
	shiny_mat.metallic = 0.85
	shiny_mat.roughness = 0.25

	for i: int in mini(count, 5):
		var m: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.14, 0.09, 0.14)
		m.mesh = box
		var c_mat: StandardMaterial3D = shiny_mat.duplicate() as StandardMaterial3D
		c_mat.albedo_color = colors[i % colors.size()]
		m.material_override = c_mat
		m.position = offsets[i % offsets.size()]
		m.rotation = Vector3(randf_range(-0.3, 0.3), float(i) * 0.8, randf_range(-0.3, 0.3))
		_trinkets_root.add_child(m)


static func get_nearest_nest(tree: SceneTree, pos: Vector3) -> Node3D:
	if tree == null:
		return null
	var best: Node3D = null
	var best_dist: float = 99999.0
	for node: Node in tree.get_nodes_in_group(GROUP):
		var nest: Node3D = node as Node3D
		if nest == null or not is_instance_valid(nest):
			continue
		var dist: float = nest.global_position.distance_to(pos)
		if dist < best_dist:
			best = nest
			best_dist = dist
	return best


static func ensure_nest_in_scene(parent: Node, default_pos: Vector3 = Vector3(12.0, 0.2, -10.0)) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var existing: Node3D = get_nearest_nest(parent.get_tree(), default_pos)
	if existing != null:
		return existing
	var nest_script: Script = load("res://gameplay/enemies/crow/crow_nest.gd") as Script
	var new_nest: Node3D = nest_script.new() as Node3D
	parent.add_child(new_nest)
	new_nest.global_position = default_pos
	return new_nest
