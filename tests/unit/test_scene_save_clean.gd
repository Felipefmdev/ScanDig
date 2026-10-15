extends GutTest

## #47/#53: gravar um mapa no editor não pode embutir malhas geradas nem mexer em transforms de
## nós gravados na cena. Simula o Ctrl+S do editor: instancia a cena, deixa os @tool gerar, envia
## NOTIFICATION_EDITOR_PRE_SAVE, volta a empacotar (PackedScene.pack, o mesmo do editor), envia
## POST_SAVE e compara com o .tscn. Também com a cena FORA da árvore, como num separador de
## fundo do editor (o caso do e67f0e9: filhos dos GroundSnap foram parar à origem).
## (Teste real no editor na #47/#53: gravar duas vezes seguidas deixa o git diff vazio.)

const SCENES: Array[String] = ["res://world/map_praia.tscn", "res://world/map_campo.tscn", "res://world/lobby_base.tscn"]
## Recursos que só existem se forem gerados (nunca escritos à mão nos mapas).
const GENERATED_TYPES: Array[String] = ["ArrayMesh", "MultiMesh", "ConcavePolygonShape3D"]
const EPS: float = 0.0005


func _embedded(state: SceneState) -> Dictionary:
	var out: Dictionary = {}
	for i: int in state.get_node_count():
		for p: int in state.get_node_property_count(i):
			var v: Variant = state.get_node_property_value(i, p)
			if v is Resource and (v as Resource).resource_path.is_empty() and GENERATED_TYPES.has((v as Resource).get_class()):
				out["%s.%s" % [state.get_node_path(i), state.get_node_property_name(i, p)]] = (v as Resource).get_class()
	return out


## Caminhos dos nós com script GroundSnap.
func _snap_parents(state: SceneState) -> Dictionary:
	var out: Dictionary = {}
	for i: int in state.get_node_count():
		for p: int in state.get_node_property_count(i):
			var v: Variant = state.get_node_property_value(i, p)
			if state.get_node_property_name(i, p) == &"script" and v is Script and (v as Script).resource_path.ends_with("ground_snap.gd"):
				out[str(state.get_node_path(i))] = true
	return out


## caminho -> transform gravada (sem a propriedade = identidade, como o editor a omite).
func _transforms(state: SceneState) -> Dictionary:
	var out: Dictionary = {}
	for i: int in state.get_node_count():
		var props: Dictionary = {}
		for p: int in state.get_node_property_count(i):
			props[state.get_node_property_name(i, p)] = state.get_node_property_value(i, p)
		if props.get(&"transform") is Transform3D:
			out[str(state.get_node_path(i))] = props[&"transform"]
		elif not props.has(&"transform"):
			# Também se grava como position/rotation/scale (ex.: SunLight escrito à mão).
			var pos: Vector3 = props.get(&"position", Vector3.ZERO)
			var rot: Vector3 = props.get(&"rotation", Vector3.ZERO)
			var scl: Vector3 = props.get(&"scale", Vector3.ONE)
			out[str(state.get_node_path(i))] = Transform3D(Basis.from_euler(rot).scaled(scl), pos)
	return out


## Nós reais da cena. Fica de fora a entrada que só sobrepõe propriedades de um nó de uma cena
## instanciada (sem tipo nem instância própria, ex.: BaseStationUI/PanelContainer no lobby): em
## jogo o script da UI muda-lhe propriedades e a sobreposição deixa de ser gravada, mas não é @tool.
func _paths(state: SceneState) -> Dictionary:
	var out: Dictionary = {}
	for i: int in state.get_node_count():
		if state.get_node_type(i) == &"" and state.get_node_instance(i) == null:
			continue
		out[str(state.get_node_path(i))] = true
	return out


## Diferenças de transform entre o .tscn e o que seria gravado. Filhos de GroundSnap: em jogo o
## y é assentado no chão (comportamento normal); basis, x e z têm de ficar iguais.
func _changed(original: SceneState, saved: SceneState) -> Array[String]:
	var snaps: Dictionary = _snap_parents(original)
	var t0: Dictionary = _transforms(original)
	var t1: Dictionary = _transforms(saved)
	var parents: Dictionary = {}
	for i: int in original.get_node_count():
		parents[str(original.get_node_path(i))] = str(original.get_node_path(i, true))
	var out: Array[String] = []
	for key: String in t0:
		if not t1.has(key):
			continue
		var a: Transform3D = t0[key]
		var b: Transform3D = t1[key]
		var same_basis: bool = a.basis.x.is_equal_approx(b.basis.x) and a.basis.y.is_equal_approx(b.basis.y) and a.basis.z.is_equal_approx(b.basis.z)
		var same_xz: bool = absf(a.origin.x - b.origin.x) < EPS and absf(a.origin.z - b.origin.z) < EPS
		var same_y: bool = absf(a.origin.y - b.origin.y) < EPS or snaps.has(parents.get(key, ""))
		if not (same_basis and same_xz and same_y):
			out.append("%s %s -> %s" % [key, a.origin, b.origin])
	return out


func _save(inst: Node) -> PackedScene:
	inst.propagate_notification(Node.NOTIFICATION_EDITOR_PRE_SAVE)
	var repacked: PackedScene = PackedScene.new()
	assert_eq(repacked.pack(inst), OK)
	inst.propagate_notification(Node.NOTIFICATION_EDITOR_POST_SAVE)
	return repacked


func test_saving_scenes_keeps_generated_meshes_and_transforms() -> void:
	for path: String in SCENES:
		var ps: PackedScene = load(path) as PackedScene
		var inst: Node = ps.instantiate()
		add_child_autofree(inst)
		for f: int in 3:
			await get_tree().physics_frame
		var repacked: PackedScene = _save(inst)
		var before: Dictionary = _embedded(ps.get_state())
		var after: Dictionary = _embedded(repacked.get_state())
		for key: String in after:
			assert_true(before.has(key), "%s: %s (%s) não pode ir para o .tscn" % [path.get_file(), key, after[key]])
		var p0: Dictionary = _paths(ps.get_state())
		var p1: Dictionary = _paths(repacked.get_state())
		var added: Array = p1.keys().filter(func(k: Variant) -> bool: return not p0.has(k))
		var lost: Array = p0.keys().filter(func(k: Variant) -> bool: return not p1.has(k))
		assert_eq(lost.size(), 0, "%s: nós perdidos ao gravar: %s" % [path.get_file(), str(lost.slice(0, 5))])
		assert_eq(added.size(), 0, "%s: nós a mais ao gravar: %s" % [path.get_file(), str(added.slice(0, 5))])
		var changed: Array[String] = _changed(ps.get_state(), repacked.get_state())
		assert_eq(changed.size(), 0, "%s: transforms mudadas ao gravar (%d): %s" % [path.get_file(), changed.size(), str(changed.slice(0, 4))])


func test_saving_a_background_tab_keeps_transforms() -> void:
	# No editor só o separador ativo está na árvore; os outros mapas abertos ficam fora dela e
	# também recebem PRE/POST_SAVE quando são gravados. Duas gravações seguidas, fora da árvore.
	for path: String in SCENES:
		var ps: PackedScene = load(path) as PackedScene
		var inst: Node = ps.instantiate()
		add_child_autofree(inst)
		for f: int in 3:
			await get_tree().physics_frame
		remove_child(inst)
		_save(inst)
		var second: PackedScene = _save(inst)
		add_child(inst)
		var changed: Array[String] = _changed(ps.get_state(), second.get_state())
		assert_eq(changed.size(), 0, "%s (fora da árvore): transforms mudadas (%d): %s" % [path.get_file(), changed.size(), str(changed.slice(0, 4))])


func test_ground_snap_does_nothing_in_the_editor_tree_out() -> void:
	# Fora da árvore o GroundSnap não lê global_position (dava a identidade).
	var snap: GroundSnap = GroundSnap.new()
	var child: Node3D = Node3D.new()
	child.transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(5.0, 0.3, -7.0))
	snap.add_child(child)
	snap.snap()
	assert_eq(child.transform, Transform3D(Basis(Vector3.UP, 0.7), Vector3(5.0, 0.3, -7.0)))
	snap.free()


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
