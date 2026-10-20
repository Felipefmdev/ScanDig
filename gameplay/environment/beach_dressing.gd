extends Node3D

## Passe de arte #150. Só Praia: construções e enquadramento cosméticos determinísticos.
## Não altera interativos, posições da missão, terreno físico ou estado de rede.

const WOOD: Color = Color("#8c6240")
const ROPE: Color = Color("#c7ab79")
const CREAM: Color = Color("#f2dfb6")
const TEAL: Color = Color("#398c87")
const ROCK: Color = Color("#ad9e79")

var _original_props: Dictionary = {}
var _grounded_props: Dictionary = {}
var _sea: MeshInstance3D = null
var _original_sea_mesh: Mesh = null
var _continuous_sea_mesh: Mesh = null


## #47/#150: packing deve guardar só recursos/transforms originais, inclusive fora da árvore.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		for prop: Node3D in _original_props:
			if is_instance_valid(prop):
				prop.transform = _original_props[prop]
		if is_instance_valid(_sea):
			_sea.mesh = _original_sea_mesh
			_sea.remove_meta(&"continuous_sea")
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		for prop: Node3D in _grounded_props:
			if is_instance_valid(prop):
				prop.transform = _grounded_props[prop]
		if is_instance_valid(_sea):
			_sea.mesh = _continuous_sea_mesh
			_sea.set_meta(&"continuous_sea", true)


func _ready() -> void:
	_snap_props()
	_build_camp()
	_build_waypoints()
	_build_arena()
	_build_groves()
	_build_headlands()
	_extend_sea()


func _surface() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _finish(st: SurfaceTool, mesh_name: String, outline: bool = true) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material(outline)
	add_child(mi)


func _at(x: float, z: float, offset: float = 0.0) -> Vector3:
	return Vector3(x, BeachTerrain.height_at(x, z) + offset, z)


func _snap_props() -> void:
	var props: Node3D = get_parent().get_node("Decor/Props") as Node3D
	for child: Node in props.get_children():
		var prop: Node3D = child as Node3D
		if prop == null:
			continue
		# Guardar o offset de garrafas deitadas e da caixa empilhada.
		_original_props[prop] = prop.transform
		var p: Vector3 = prop.position
		prop.position.y = BeachTerrain.height_at(p.x, p.z) + p.y - 0.015
		_grounded_props[prop] = prop.transform


func _build_camp() -> void:
	var st: SurfaceTool = _surface()
	# Banca original rodada 90 graus: cobertura acompanha o balcão, sem tapar o acesso.
	var frame: Transform3D = (get_parent().get_node("Banca") as Node3D).transform
	for x: float in [-2.0, 2.0]:
		for z: float in [-0.65, 1.1]:
			var foot: Vector3 = frame * Vector3(x, 0.0, z)
			LowPolyMesh.prism(st, foot, foot + Vector3.UP * 2.85, 0.065, 0.05, 6, WOOD)
		LowPolyMesh.prism(st, frame * Vector3(x, 2.75, -0.8), frame * Vector3(x, 2.75, 1.25), 0.055, 0.055, 6, WOOD)
	# Lona listrada com cumeeira e abas; modelada de ambos os lados.
	for i: int in 8:
		var x0: float = -2.2 + float(i) * 0.55
		var x1: float = x0 + 0.55
		var color: Color = CREAM if i % 2 == 0 else TEAL
		for z: float in [-0.95, 1.4]:
			var a: Vector3 = frame * Vector3(x0, 2.85, z)
			var b: Vector3 = frame * Vector3(x1, 2.85, z)
			var c: Vector3 = frame * Vector3(x1, 3.15, 0.2)
			var d: Vector3 = frame * Vector3(x0, 3.15, 0.2)
			LowPolyMesh.quad(st, a, b, c, d, (a + c) * 0.5 - Vector3.UP, color)
			LowPolyMesh.quad(st, d, c, b, a, (a + c) * 0.5 + Vector3.UP, color.darkened(0.12))
			LowPolyMesh.box(st, (a + b) * 0.5 - Vector3.UP * 0.09, Vector3(0.55, 0.18, 0.025), frame.basis, color)
	# Triagem lateral: corredor frontal da entrega e da banca permanece livre.
	for x: float in [8.2, 9.8]:
		for z: float in [6.75, 7.25]:
			LowPolyMesh.prism(st, _at(x, z), _at(x, z, 0.65), 0.045, 0.04, 5, WOOD)
	for i: int in 4:
		LowPolyMesh.box(st, _at(9.0, 6.73 + float(i) * 0.18, 0.69), Vector3(1.9, 0.08, 0.16), Basis.IDENTITY, WOOD.lightened(0.1))
	_block_box("TriagemCollision", _at(9.0, 7.0, 0.36), Vector3(1.9, 0.72, 0.7))
	# Mastro de pano no posto: marco de retorno visível sem outro texto flutuante.
	_pennant(st, _at(4.8, 5.0), 4.7, TEAL)
	_lantern(st, _at(4.8, 5.0, 2.25))
	_finish(st, "PostoExploracao")


func _pennant(st: SurfaceTool, base: Vector3, height: float, color: Color) -> void:
	LowPolyMesh.prism(st, base, base + Vector3.UP * height, 0.07, 0.035, 7, WOOD)
	var a: Vector3 = base + Vector3(0.0, height - 0.12, 0.0)
	var b: Vector3 = a + Vector3(1.15, -0.18, 0.12)
	var c: Vector3 = a + Vector3(0.0, -0.65, 0.0)
	LowPolyMesh.tri(st, a, b, c, a + Vector3.BACK, color)
	LowPolyMesh.tri(st, c, b, a, a + Vector3.FORWARD, color.darkened(0.12))


func _build_waypoints() -> void:
	var st: SurfaceTool = _surface()
	# Cordas baixas apenas de um lado do acesso ao cais, com vãos largos.
	var points: Array[Vector3] = [_at(12.0, 9.0), _at(16.5, 11.0), _at(21.0, 12.3)]
	for p: Vector3 in points:
		LowPolyMesh.prism(st, p, p + Vector3.UP * 0.8, 0.055, 0.045, 6, WOOD)
	for i: int in points.size() - 1:
		_rope(st, points[i] + Vector3.UP * 0.65, points[i + 1] + Vector3.UP * 0.65)
	_pennant(st, _at(25.2, 13.8), 3.3, Color("#d77b42"))
	_lantern(st, _at(25.2, 13.8, 1.65))
	# Madeira encalhada enquadra a enseada sem esconder as conchas interativas.
	for i: int in 5:
		var p: Vector3 = _at(23.7 + float(i) * 0.35, -17.0 - float(i) * 0.45, 0.08)
		LowPolyMesh.box(st, p, Vector3(1.6, 0.12, 0.2), Basis(Vector3.UP, 0.3 + float(i) * 0.17), WOOD.darkened(0.15))
	_finish(st, "AcessosCosta")


func _block_box(body_name: String, center: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	body.add_to_group(&"spot_blockers")
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _lantern(st: SurfaceTool, p: Vector3) -> void:
	var center: Vector3 = p + Vector3(0.16, 0.0, 0.0)
	LowPolyMesh.box(st, center, Vector3(0.2, 0.28, 0.2), Basis.IDENTITY, Color("#f6c573"))
	for y: float in [-0.16, 0.16]:
		LowPolyMesh.box(st, center + Vector3.UP * y, Vector3(0.27, 0.05, 0.27), Basis.IDENTITY, WOOD.darkened(0.25))
	var light: OmniLight3D = OmniLight3D.new()
	light.position = center + Vector3(0.3, 0.0, 0.0)
	light.light_color = Color(1.0, 0.7, 0.36)
	light.light_energy = 0.65
	light.omni_range = 5.0
	light.shadow_enabled = false
	add_child(light)


func _rope(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var prev: Vector3 = a
	for i: int in range(1, 7):
		var t: float = float(i) / 6.0
		var p: Vector3 = a.lerp(b, t) - Vector3.UP * sin(t * PI) * 0.2
		LowPolyMesh.prism(st, prev, p, 0.018, 0.018, 5, ROPE)
		prev = p


func _build_arena() -> void:
	var st: SurfaceTool = _surface()
	# Dois postes inclinados e pedras baixas fora do raio útil de combate.
	for xz: Vector2 in [Vector2(-14.0, -17.5), Vector2(-17.5, -14.0)]:
		_pennant(st, _at(xz.x, xz.y), 2.7, Color("#b76c44"))
	for i: int in 12:
		var angle: float = PI * 0.55 + float(i) * PI * 0.9 / 11.0
		var p: Vector3 = _at(-22.0 + cos(angle) * 8.9, -22.0 + sin(angle) * 8.9, -0.08)
		LowPolyMesh.prism(st, p, p + Vector3.UP * (0.35 + float(i % 3) * 0.13), 0.6, 0.35, 5, ROCK)
	_finish(st, "EntradaArena")


func _build_headlands() -> void:
	var st: SurfaceTool = _surface()
	# Liga o terreno jogável às colinas distantes: sem céu à vista sob a borda.
	for i: int in 30:
		var z0: float = -120.0 + float(i) * 8.0
		var z1: float = z0 + 8.0
		var a: Vector3 = Vector3(-31.0, BeachTerrain.height_at(-31.0, clampf(z0, -31.0, 31.0)) - 0.15, z0)
		var b: Vector3 = Vector3(-150.0, -1.0, z0)
		var c: Vector3 = Vector3(-150.0, -1.0, z1)
		var d: Vector3 = Vector3(-31.0, BeachTerrain.height_at(-31.0, clampf(z1, -31.0, 31.0)) - 0.15, z1)
		LowPolyMesh.quad(st, a, b, c, d, Vector3(-80.0, -10.0, z0), Color("#778968"))
	for side: float in [-1.0, 1.0]:
		for i: int in 12:
			var x0: float = -31.0 + float(i) * 5.5
			var x1: float = x0 + 5.5
			var a: Vector3 = _at(x0, side * 31.0, -0.12)
			var b: Vector3 = _at(x1, side * 31.0, -0.12)
			var c: Vector3 = Vector3(x1, -1.8, side * 125.0)
			var d: Vector3 = Vector3(x0, -1.8, side * 125.0)
			LowPolyMesh.quad(st, a, b, c, d, Vector3(x0, -10.0, side * 50.0), Color("#b8aa7c"))
	_finish(st, "ContinuidadeCosta", false)
	var stacks: SurfaceTool = _surface()
	# Pontas da enseada para quebrar a linha reta da costa; fora da área navegável.
	for spec: Vector4 in [Vector4(25.0, -34.0, 5.0, 3.0), Vector4(29.0, -36.0, 3.4, 2.8),
			Vector4(26.0, 35.0, 4.4, 3.5)]:
		var p: Vector3 = Vector3(spec.x, -1.6, spec.y)
		LowPolyMesh.prism(stacks, p, p + Vector3(-0.7, spec.z, 0.25), spec.w, spec.w * 0.6, 6, ROCK)
		LowPolyMesh.prism(stacks, p + Vector3(-0.7, spec.z, 0.25), p + Vector3(-0.5, spec.z + 0.8, 0.0), spec.w * 0.6, 0.4, 6, ROCK.lightened(0.08))
	_finish(stacks, "PontasEnseada")


func _build_groves() -> void:
	var st: SurfaceTool = _surface()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 150
	for center: Vector2 in [Vector2(-18.0, 10.0), Vector2(6.0, 18.0), Vector2(-26.0, 2.0), Vector2(16.0, -22.0)]:
		for i: int in 7:
			var a: float = float(i) * TAU / 7.0
			var p: Vector3 = _at(center.x + cos(a) * rng.randf_range(1.6, 3.0), center.y + sin(a) * rng.randf_range(1.6, 3.0), -0.04)
			var radius: float = rng.randf_range(0.35, 0.7)
			var green: Color = Color("#667a38").lightened(rng.randf_range(0.0, 0.15))
			LowPolyMesh.prism(st, p, p + Vector3.UP * 0.35, radius * 0.65, radius, 6, green.darkened(0.16))
			LowPolyMesh.prism(st, p + Vector3.UP * 0.35, p + Vector3.UP * 0.65, radius, radius * 0.3, 6, green)
	# Palmas escalonadas, agrupadas atrás das clareiras; deixam os caminhos e arena livres.
	for spec: Vector3 in [Vector3(-20.0, 12.0, 5.1), Vector3(-17.0, 14.0, 4.5),
			Vector3(8.0, 20.0, 5.6), Vector3(4.0, 21.5, 4.2), Vector3(18.5, -24.0, 5.0)]:
		var palm: PalmModel = PalmModel.new()
		palm.name = "PalmaGrupo%d" % get_child_count()
		palm.height = spec.z
		palm.bend = rng.randf_range(0.5, 1.2)
		palm.frond_length = 2.4
		palm.seed_value = rng.randi_range(1, 999)
		palm.position = _at(spec.x, spec.y, -0.05)
		palm.rotation.y = rng.randf_range(0.0, TAU)
		add_child(palm)
		_block_box("Tronco%d" % get_child_count(), palm.position + Vector3.UP * 1.3, Vector3(0.44, 2.6, 0.44))
	_finish(st, "MoitasDunas")


func _extend_sea() -> void:
	var sea: MeshInstance3D = get_parent().get_node("Sea") as MeshInstance3D
	_sea = sea
	_original_sea_mesh = sea.mesh
	sea.set_meta(&"continuous_sea", true)
	var material: Material = sea.mesh.surface_get_material(0)
	# Grelha fina junto à costa e progressivamente larga no horizonte; uma só superfície
	# acompanha TideCycle, sem sobreposição entre mar animado e plano toon distante.
	var xs: Array[float] = []
	var zs: Array[float] = [-600.0, -300.0, -160.0, -90.0]
	for i: int in range(20, 81, 2):
		xs.append(float(i))
	xs.append_array([100.0, 140.0, 220.0, 360.0, 600.0])
	for i: int in range(-60, 61, 2):
		zs.append(float(i))
	zs.append_array([90.0, 160.0, 300.0, 600.0])
	var st: SurfaceTool = _surface()
	for i: int in xs.size() - 1:
		for j: int in zs.size() - 1:
			var a: Vector3 = Vector3(xs[i] - sea.position.x, 0.0, zs[j])
			var b: Vector3 = Vector3(xs[i + 1] - sea.position.x, 0.0, zs[j])
			var c: Vector3 = Vector3(xs[i + 1] - sea.position.x, 0.0, zs[j + 1])
			var d: Vector3 = Vector3(xs[i] - sea.position.x, 0.0, zs[j + 1])
			LowPolyMesh.quad(st, a, b, c, d, a - Vector3.UP, Color.WHITE)
	sea.mesh = st.commit()
	sea.mesh.surface_set_material(0, material)
	_continuous_sea_mesh = sea.mesh
