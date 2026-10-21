extends GutTest

const DRESSING: Script = preload("res://gameplay/environment/campo_dressing.gd")


func test_routes_and_objectives_have_clear_cosmetics() -> void:
	var dressing: Node3D = DRESSING.new()
	autofree(dressing)
	for p: Vector2 in [Vector2(-12.5, -16.9), Vector2(-23.5, -17.2), Vector2(20.5, -3.3), Vector2(-4.9, -5), Vector2(6.4, -15), Vector2(12, -16), Vector2(-15, 19), Vector2(5, -5)]:
		assert_true(dressing.is_clear(p), "Zona de uso livre: %s" % p)
	assert_false(dressing.is_clear(Vector2(25, 25)), "Vegetação distante preservada")


func test_filter_removes_only_cosmetics_inside_corridor() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var dressing: Node3D = DRESSING.new()
	root.add_child(dressing)
	var poses: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(5, 0, -5)), Transform3D(Basis.IDENTITY, Vector3(25, 0, 25))]
	var kept: Array[Transform3D] = dressing.kept_poses(poses, Transform3D.IDENTITY)
	assert_eq(kept.size(), 1)
	assert_eq(kept[0].origin, Vector3(25, 0, 25))
	for child: Node in dressing.get_children():
		assert_false(child is CollisionObject3D, "Dressing não cria colisão")
	await wait_frames(5)



func test_exterior_roots_use_analytic_support_without_collision() -> void:
	var script: Script = DRESSING
	assert_not_null(script)
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var dressing: Node3D = script.new()
	root.add_child(dressing)
	await wait_frames(5)
	var roots: Array[Node] = []
	_collect_roots(dressing, roots)
	assert_gt(roots.size(), 20, "Faixa externa deve existir e incluir árvores e lavoura")
	for node: Node in roots:
		var p: Vector3 = (node as Node3D).global_position
		var edge: float = maxf(absf(p.x), absf(p.z))
		assert_true(edge >= 33.0 and edge <= 45.0, "Raiz fora da área jogável e dentro do terreno: %s" % p)
		assert_almost_eq(p.y, FieldTerrain.height_at(p.x, p.z) - 0.04, 0.001, "Apoio analítico: %s" % node.name)
		assert_false(dressing.is_clear(Vector2(p.x, p.z)), "Não invadir rotas/objetivos")
	_check_no_collision(dressing)

func _collect_roots(node: Node, roots: Array[Node]) -> void:
	if node.is_in_group("campo_exterior_roots"):
		roots.append(node)
	for child: Node in node.get_children():
		_collect_roots(child, roots)

func _check_no_collision(node: Node) -> void:
	assert_false(node is CollisionObject3D or node is CollisionShape3D, "Cosmético sem colisão: %s" % node.name)
	for child: Node in node.get_children():
		_check_no_collision(child)


func test_outer_crops_are_batched_and_every_instance_is_supported() -> void:
	# Godot 4.3 dummy não preserva leitura dos transforms de MultiMesh.
	# Executar este contrato com janela; o teste de raízes roda também em headless.
	if DisplayServer.get_name() == "headless":
		pending("MultiMesh requer renderer real; validar com janela")
		return
	var script: Script = DRESSING
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var dressing: Node3D = script.new()
	root.add_child(dressing)
	await wait_frames(5)
	var batches: Array[Node] = dressing.find_children("*", "MultiMeshInstance3D", true, false)
	assert_gt(batches.size(), 0, "Lavoura externa agrupada em MultiMesh")
	var total: int = 0
	for node: Node in batches:
		var batch: MultiMeshInstance3D = node as MultiMeshInstance3D
		assert_not_null(batch.multimesh)
		if batch.multimesh == null:
			continue
		for i: int in batch.multimesh.instance_count:
			var p: Vector3 = batch.global_transform * batch.multimesh.get_instance_transform(i).origin
			assert_true(maxf(absf(p.x), absf(p.z)) >= 33.0 and maxf(absf(p.x), absf(p.z)) <= 45.0, "Instância exterior apoiada dentro do terreno")
			assert_almost_eq(p.y, FieldTerrain.height_at(p.x, p.z) - 0.04, 0.001, "Apoio global da touceira")
			total += 1
	assert_gt(total, 20, "Instâncias de lavoura presentes sem fixar distribuição")
