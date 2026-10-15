extends GutTest

## #47: gravar um mapa no editor não pode embutir malhas geradas nem mudar alturas/propriedades.
## Simula o Ctrl+S do editor: instancia a cena, deixa os @tool gerar, envia
## NOTIFICATION_EDITOR_PRE_SAVE, volta a empacotar (PackedScene.pack, o mesmo do editor) e compara.
## (Teste real feito no editor na #47: 2.ª gravação seguida com git diff vazio.)

const MAPS: Array[String] = ["res://world/map_praia.tscn", "res://world/map_campo.tscn"]
## Recursos que só existem se forem gerados (nunca escritos à mão nos mapas).
const GENERATED_TYPES: Array[String] = ["ArrayMesh", "MultiMesh", "ConcavePolygonShape3D"]


func _embedded(state: SceneState) -> Dictionary:
	var out: Dictionary = {}
	for i: int in state.get_node_count():
		for p: int in state.get_node_property_count(i):
			var v: Variant = state.get_node_property_value(i, p)
			if v is Resource and (v as Resource).resource_path.is_empty() and GENERATED_TYPES.has((v as Resource).get_class()):
				out["%s.%s" % [state.get_node_path(i), state.get_node_property_name(i, p)]] = (v as Resource).get_class()
	return out


func _snap_heights(state: SceneState) -> Dictionary:
	# Filhos de nós GroundSnap: o y gravado de cada um.
	var snaps: Dictionary = {}
	for i: int in state.get_node_count():
		for p: int in state.get_node_property_count(i):
			var v: Variant = state.get_node_property_value(i, p)
			if state.get_node_property_name(i, p) == &"script" and v is Script and (v as Script).resource_path.ends_with("ground_snap.gd"):
				snaps[str(state.get_node_path(i))] = true
	var out: Dictionary = {}
	for i: int in state.get_node_count():
		if not snaps.has(str(state.get_node_path(i, true))):
			continue
		for p: int in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"transform":
				out[str(state.get_node_path(i))] = (state.get_node_property_value(i, p) as Transform3D).origin.y
	return out


func test_saving_maps_keeps_generated_meshes_out() -> void:
	for path: String in MAPS:
		var ps: PackedScene = load(path) as PackedScene
		var inst: Node = ps.instantiate()
		add_child_autofree(inst)
		for f: int in 3:
			await get_tree().physics_frame
		inst.propagate_notification(Node.NOTIFICATION_EDITOR_PRE_SAVE)
		var repacked: PackedScene = PackedScene.new()
		assert_eq(repacked.pack(inst), OK)
		inst.propagate_notification(Node.NOTIFICATION_EDITOR_POST_SAVE)
		var before: Dictionary = _embedded(ps.get_state())
		var after: Dictionary = _embedded(repacked.get_state())
		for key: String in after:
			assert_true(before.has(key), "%s: %s (%s) não pode ir para o .tscn" % [path.get_file(), key, after[key]])
		assert_eq(repacked.get_state().get_node_count(), ps.get_state().get_node_count(),
			"%s: mesmos nós depois de gravar" % path.get_file())
		# Alturas dos filhos de GroundSnap: o valor gravado volta ao .tscn tal como estava.
		var h0: Dictionary = _snap_heights(ps.get_state())
		var h1: Dictionary = _snap_heights(repacked.get_state())
		var moved: Array[String] = []
		for key: String in h0:
			if h1.has(key) and absf(float(h0[key]) - float(h1[key])) > 0.0005:
				moved.append(key)
		assert_eq(moved.size(), 0, "%s: transforms mudados ao gravar: %s" % [path.get_file(), str(moved.slice(0, 5))])


func test_rebuild_keeps_children_saved_in_the_scene() -> void:
	# Um nó gravado na cena (owner = raiz) debaixo de um gerador não pode desaparecer no rebuild.
	for script_path: String in [
		"res://gameplay/environment/palm_model.gd", "res://gameplay/environment/menhir_model.gd",
		"res://gameplay/environment/field_tree_model.gd", "res://gameplay/environment/fence_line.gd",
	]:
		var root: Node3D = Node3D.new()
		add_child_autofree(root)
		var gen: Node3D = Node3D.new()
		gen.set_script(load(script_path) as Script)
		root.add_child(gen)
		gen.owner = root
		var kept: Node3D = Node3D.new()
		kept.name = "SavedChild"
		gen.add_child(kept)
		kept.owner = root
		gen.call(&"rebuild")
		assert_true(is_instance_valid(kept) and kept.get_parent() == gen, "%s: rebuild não apaga filhos com owner" % script_path.get_file())
