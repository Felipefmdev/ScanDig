extends GutTest

const AVATAR: Script = preload("res://gameplay/player/player_avatar.gd")

func _avatar(peer: int = 1) -> Node3D:
	var avatar: Node3D = AVATAR.new()
	add_child_autofree(avatar)
	avatar.setup(peer, "Peer %d" % peer)
	return avatar

func _model(root: Node, path: String) -> Node3D:
	for child: Node in root.get_children():
		if child.get_script() != null and (child.get_script() as Script).resource_path == path:
			return child as Node3D
		var found: Node3D = _model(child, path)
		if found != null:
			return found
	return null

func test_tools_have_real_distinct_models_and_cache_across_frames() -> void:
	var avatar: Node3D = _avatar()
	avatar.set_tool(&"detector")
	var detector: Node3D = _model(avatar, "res://gameplay/detector/detector_model.gd")
	assert_not_null(detector, "Bobina/caixa reais do detector, não barra genérica")
	if detector == null:
		return
	assert_false(detector.get("show_hand"), "Sem mão local duplicada")
	var detector_id: int = detector.get_instance_id()
	for i: int in 120:
		avatar.set_tool(&"detector")
	assert_eq(_model(avatar, "res://gameplay/detector/detector_model.gd").get_instance_id(), detector_id, "Mesmo ID não reconstrói por frame")
	avatar.set_tool(&"forcado")
	var fork: Node3D = _model(avatar, "res://gameplay/weapons/pitchfork/pitchfork_model.gd")
	assert_not_null(fork, "Dentes reais do forcado")
	if fork == null:
		return
	assert_ne(fork.get_script(), detector.get_script())
	assert_false(detector.is_visible_in_tree())
	assert_true(fork.is_visible_in_tree())
	assert_false(fork.get("show_left_hand"))
	var fork_id: int = fork.get_instance_id()
	for i: int in 10:
		avatar.set_tool(&"detector")
		avatar.set_tool(&"forcado")
	assert_eq(_model(avatar, "res://gameplay/weapons/pitchfork/pitchfork_model.gd").get_instance_id(), fork_id, "Troca usa cache sem acumular")
	assert_eq(avatar.get_node("UpperBody/Tool").get_child_count(), 2, "Só duas ferramentas visitadas")
	avatar.set_tool(&"")
	assert_false(detector.is_visible_in_tree())
	assert_false(fork.is_visible_in_tree())

func test_downed_hides_tool_even_after_switch_and_restores_current_on_revive() -> void:
	var avatar: Node3D = _avatar()
	avatar.set_pitch(-1.2)
	avatar.set_tool(&"detector")
	avatar.set_downed(true)
	avatar.set_tool(&"forcado")
	assert_true(avatar.is_downed())
	assert_false(avatar.get_node("UpperBody/Tool").is_visible_in_tree())
	avatar.set_pitch(1.4)
	assert_almost_eq(avatar.get_node("UpperBody").rotation.x, 0.0, 0.0001)
	assert_almost_eq(avatar.get_node("UpperBody/HeadPivot").rotation.x, 0.0, 0.0001)
	avatar.set_downed(false)
	var fork: Node3D = _model(avatar, "res://gameplay/weapons/pitchfork/pitchfork_model.gd")
	assert_not_null(fork)
	if fork != null:
		assert_true(fork.is_visible_in_tree(), "Retorno recupera ferramenta atual sem depender de próximo frame")
	assert_almost_eq(avatar.rotation.x, 0.0, 0.0001)
	assert_eq(avatar.get_node("NameLabel").text, "Peer 1")

func test_peer_identity_has_geometric_signal_and_preserves_palette_mapping() -> void:
	var counts: Array[int] = []
	for peer: int in [1, 3, 4, 2]:
		var avatar: Node3D = _avatar(peer)
		var mark: Node = avatar.get_node_or_null("UpperBody/PeerMarks")
		assert_not_null(mark, "Identidade não depende só da cor")
		if mark == null:
			continue
		counts.append(mark.get_child_count())
		var label: Label3D = avatar.get_node("NameLabel") as Label3D
		var slot: int = 0 if peer == 1 else 1 + absi(peer) % 3
		assert_eq(label.modulate, AVATAR.SHIRTS[slot].lightened(0.35), "Mesma identidade de cor pública")
		var geometry: Array[PackedVector3Array] = []
		for child: Node in mark.get_children():
			geometry.append((child as MeshInstance3D).mesh.get_faces())
		avatar.setup(peer, "Novo nome")
		assert_eq(mark.get_child_count(), counts[-1], "Setup repetido não acumula marcas")
		for i: int in mark.get_child_count():
			assert_eq((mark.get_child(i) as MeshInstance3D).mesh.get_faces(), geometry[i])
	assert_eq(counts.size(), 4)
	if counts.size() == 4:
		assert_eq(counts, [1, 2, 3, 4], "Quatro padrões visíveis em escala de equipe")

func test_neck_contract_pitch_and_cosmetic_only() -> void:
	var avatar: Node3D = _avatar()
	var torso: MeshInstance3D = avatar.get_node("UpperBody/Torso") as MeshInstance3D
	var pivot: Node3D = avatar.get_node("UpperBody/HeadPivot") as Node3D
	assert_almost_eq(pivot.position.distance_to(torso.position + Vector3(0, 0.31, 0)), 0.0, 0.001)
	for pitch: float in [-1.5, -1.2, -0.3, 0.0, 0.6, 1.4]:
		avatar.set_pitch(pitch)
		assert_lte(absf(pivot.rotation.x), 0.4501)
		assert_lte(absf(avatar.get_node("UpperBody").rotation.x), 0.3001)
	var found: Array[Node] = avatar.find_children("*", "", true, false)
	for node: Node in found:
		assert_false(node is CollisionObject3D or node is CollisionShape3D, "Visual não altera cápsula")
	assert_true(torso.material_override is ShaderMaterial, "Toon coerente com NPC")

func test_all_known_remote_tools_are_supported_without_local_hands() -> void:
	var avatar: Node3D = _avatar()
	for tool_id: StringName in [&"pa", &"estilingue", &"repelente", &"armadilha_rede", &"kit_medico", &"lanterna_magnesio", &"arpao_corda", &"pulso_magnetico", &"dinamite"]:
		avatar.set_tool(tool_id)
		var holder: Node3D = avatar.get_node("UpperBody/Tool") as Node3D
		assert_true(holder.is_visible_in_tree(), "Ferramenta reconhecida: %s" % tool_id)
		assert_gt(holder.get_child_count(), 0, "Modelo real de %s" % tool_id)
		for child: Node in holder.find_children("*", "", true, false):
			assert_false(child.name in ["LeftHand", "RightHand", "Hand"], "Não duplicar mãos locais")
	avatar.set_tool(&"id_desconhecido")
	assert_false(avatar.get_node("UpperBody/Tool").is_visible_in_tree(), "Sem silhueta falsa para ID desconhecido")


func test_shovel_and_medkit_grips_match_palm_without_ground_penetration() -> void:
	var avatar: Node3D = _avatar()
	var palm: Vector3 = avatar.to_global(Vector3(0.37, 0.84, -0.035))
	avatar.set_tool(&"pa")
	var shovel: Node3D = _model(avatar, "res://gameplay/player/shovel_model.gd")
	assert_not_null(shovel)
	if shovel != null:
		assert_lt(shovel.to_global(Vector3(0, 1.012, 0)).distance_to(palm), 0.025, "Travessa do punho encontra a palma")
		for child: Node in shovel.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = child as MeshInstance3D
			assert_gte((mesh.global_transform * mesh.get_aabb()).position.y, 0.0, "Lâmina erguida acima do solo")
	avatar.set_tool(&"kit_medico")
	var kit: Node3D = _model(avatar, "res://gameplay/weapons/medkit/medkit_model.gd")
	assert_not_null(kit)
	if kit != null:
		assert_lt(kit.to_global(Vector3(0, 0.232, 0)).distance_to(palm), 0.025, "Alça encontra a palma")
		assert_gt((kit.global_basis * Vector3.BACK).normalized().dot(Vector3.FORWARD), 0.99, "Cruz olha para frente do explorador")
