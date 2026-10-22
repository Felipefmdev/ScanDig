extends GutTest

## Relevo dos mapas 3-5 (estudo How to Fish): tudo o que se usa no chão tem de continuar assente
## nele (nada a flutuar nem enterrado). Carrega cada mapa e compara a altura de cada ponto
## interativo com height_at() do terreno. As ofertas da Banca ficam por cima do balcão.
## Os spots enterrados nascem por raycast na colisão (malha facetada de 1 m, que nas arestas
## pode afastar-se ~0.2 m da fórmula): esses comparam-se com o chão real, por raycast.

const MAPS: Array = [
	["res://world/map_ruinas.tscn", "res://gameplay/environment/ruins_terrain.gd"],
	["res://world/map_geleira.tscn", "res://gameplay/environment/glacier_terrain.gd"],
	["res://world/map_cratera.tscn", "res://gameplay/environment/crater_terrain.gd"],
]
## Classes que assentam no chão (por class_name do script ou de uma base).
const KINDS: Array[String] = [
	"BossAltar", "BuriedSpot", "SellPoint", "ShopOffer", "Interactable", "QuestNpc",
	"DetectorSpawn", "RuinasProp", "GeleiraProp", "CrateraProp", "TriggerDigSpot",
	"FlagInteractable", "CraterStructure", "GlacierStructure",
]
const MAX_GAP: float = 0.15
## Altura das ofertas da Banca acima do chão (em cima do balcão).
const OFFER_HEIGHT: float = 0.9


static func _kind(n: Node) -> String:
	var s: Script = n.get_script()
	while s != null:
		if s.get_global_name() in KINDS:
			return s.get_global_name()
		s = s.get_base_script()
	return ""


func test_interactive_points_sit_on_the_ground(params: Array = use_parameters(MAPS)) -> void:
	var scene: Node = _instantiate_map(params[0])
	add_child_autoqfree(scene)
	await wait_frames(10)
	var terrain: Script = load(params[1])
	var checked: int = 0
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var kind: String = _kind(n)
		if kind == "" or not n is Node3D:
			continue
		var semantic: Node3D = _supported_piece(n)
		if semantic != null:
			_assert_supported_piece(scene as Node3D, n as Node3D, semantic)
			checked += 1
			continue
		var p: Vector3 = (n as Node3D).global_position
		var ground: float = float(terrain.call(&"height_at", p.x, p.z))
		if kind == "BuriedSpot":
			ground = _collision_height(scene as Node3D, p, ground)
		var gap: float = p.y - ground
		if kind == "ShopOffer":
			gap -= OFFER_HEIGHT
		assert_lt(absf(gap), MAX_GAP, "%s %s (%s) a %.2f m do chão em (%.1f, %.1f)" % [
			params[0].get_file(), n.name, kind, gap, p.x, p.z])
		checked += 1
	assert_gt(checked, 40, "%s: pontos verificados" % params[0].get_file())


func _instantiate_map(path: String) -> Node3D:
	return (load(path) as PackedScene).instantiate()


func _supported_piece(node: Node) -> Node3D:
	var current: Node = node
	while current != null:
		if current is FlagInteractable and String(current.name) in ["RelicChalice", "RelicDagger", "OrbRelic", "Stalactite"]:
			return current as Node3D
		current = current.get_parent()
	return null


func _assert_supported_piece(scene: Node3D, checked_node: Node3D, piece: Node3D) -> void:
	var expected: float = 0.0
	match String(piece.name):
		"RelicChalice":
			var step: CollisionShape3D = piece.get_node("../NicheTower/Step3")
			expected = (step.global_transform * Vector3(0, (step.shape as BoxShape3D).size.y * 0.5, 0)).y
		"RelicDagger":
			var table: MeshInstance3D = piece.get_node("../TorchAltar/Model/Mesh")
			expected = _mesh_intersection_height(table, piece.global_position, true)
		"OrbRelic":
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(piece.global_position + Vector3.UP * 8, piece.global_position - Vector3.UP * 8, 1)
			var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(q)
			assert_false(hit.is_empty(), "Relic requires a real pillar support")
			if hit.is_empty():
				return
			assert_true(str((hit.collider as Node).get_parent().name).begins_with("CraterPillar"))
			expected = (hit.position as Vector3).y
		"Stalactite":
			var arch: MeshInstance3D = scene.get_node("Decor/Layout/IceArch3/Mesh")
			var ceiling: float = _mesh_intersection_height(arch, piece.global_position, false)
			var model: MeshInstance3D = piece.get_node("Model/Mesh")
			var top: float = model.mesh.get_aabb().end.y
			expected = ceiling - top
	assert_true(is_finite(expected), "%s has real semantic geometry support" % piece.name)
	# Same global tolerance: exceptions change the reference surface, not acceptable error.
	assert_lt(absf(checked_node.global_position.y - expected), MAX_GAP, "%s rests on/hangs from its actual support" % checked_node.name)


func _mesh_intersection_height(mi: MeshInstance3D, point: Vector3, highest: bool) -> float:
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	var count: int = vertices.size() if indices == null or indices.size() == 0 else indices.size()
	var selected: float = -INF if highest else INF
	for i: int in range(0, count, 3):
		var points: Array[Vector3] = []
		for j: int in range(3):
			var index: int = i + j if indices == null or indices.size() == 0 else indices[i + j]
			points.append(mi.global_transform * vertices[index])
		var hit: Variant = Geometry3D.segment_intersects_triangle(point + Vector3.UP * 8, point - Vector3.UP * 8, points[0], points[1], points[2])
		if hit != null:
			selected = maxf(selected, (hit as Vector3).y) if highest else minf(selected, (hit as Vector3).y)
	return selected


## Altura da colisão do chão (layer 1) por baixo de `p`; `fallback` se o raio não acertar.
func _collision_height(scene: Node3D, p: Vector3, fallback: float) -> float:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(p.x, fallback + 3.0, p.z), Vector3(p.x, fallback - 3.0, p.z), 1)
	var hit: Dictionary = space.intersect_ray(q)
	return float(hit["position"].y) if not hit.is_empty() else fallback
