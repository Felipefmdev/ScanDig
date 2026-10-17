extends RefCounted

## Peças partilhadas dos NPCs (#61): figura "chibi" low-poly facetada (cabeça grande, mãos de
## luva, botas) para as personagens das referências em C:\Users\felip\Pictures\scandig\.
## Convenção: a cara olha para -Z (o QuestNpc vira o -Z para o jogador); pés em y = 0.
## Uso: const NpcBody := preload("res://gameplay/quests/npc_body.gd")
## Cores com alfa 1 levam desgaste (sujidade do material), alfa 0 ficam limpas (olhos, metal).

const CrabModel := preload("res://gameplay/enemies/crab/crab_model.gd")

const EYE_WHITE: Color = Color(0.97, 0.96, 0.92, 0.0)
const PUPIL: Color = Color(0.08, 0.06, 0.05, 0.0)
const MOUTH: Color = Color(0.45, 0.16, 0.14, 0.0)
const TEETH: Color = Color(0.98, 0.97, 0.94, 0.0)


## Elipsoide facetado (bolha): raios r, `sides` lados e 4 anéis; jitter dá o ar talhado à mão.
static func blob(st: SurfaceTool, center: Vector3, r: Vector3, color: Color, sides: int = 8,
		jitter: float = 0.0, seed_value: int = 1, basis: Basis = Basis.IDENTITY) -> void:
	CrabModel.gem(st, Transform3D.IDENTITY, center, basis, [
		Vector3(-r.y * 0.62, r.x * 0.72, r.z * 0.72),
		Vector3(-r.y * 0.18, r.x * 0.98, r.z * 0.98),
		Vector3(r.y * 0.3, r.x * 0.94, r.z * 0.94),
		Vector3(r.y * 0.7, r.x * 0.62, r.z * 0.62),
	], sides, -r.y, r.y, color, jitter, seed_value)


## Membro (tronco de cone) de a para b.
static func limb(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, color: Color, sides: int = 6) -> void:
	LowPolyMesh.prism(st, a, b, r0, r1, sides, color)


## Mão de luva/punho (bolha achatada) com polegar.
static func hand(st: SurfaceTool, at: Vector3, size: float, color: Color, side: float) -> void:
	blob(st, at, Vector3(size, size * 1.1, size * 0.85), color, 6)
	blob(st, at + Vector3(-side * size * 0.75, size * 0.25, -size * 0.35), Vector3(size * 0.38, size * 0.5, size * 0.38), color, 5)


## Bota pesada: cano + biqueira mais larga para a frente (-Z) + sola escura.
static func boot(st: SurfaceTool, at: Vector3, color: Color, sole: Color, scale: float = 1.0, height: float = 0.22) -> void:
	var s: float = scale
	LowPolyMesh.prism(st, at + Vector3(0, 0.04, 0.02) * s, at + Vector3(0, height, 0.02) * s, 0.085 * s, 0.09 * s, 7, color)
	LowPolyMesh.box(st, at + Vector3(0, 0.06, -0.06) * s, Vector3(0.17, 0.11, 0.24) * s, Basis.IDENTITY, color)
	LowPolyMesh.box(st, at + Vector3(0, 0.015, -0.05) * s, Vector3(0.19, 0.03, 0.29) * s, Basis.IDENTITY, sole)


## Olhos (branco + pupila), sobrancelhas e boca para uma cabeça em `head` de raio `hr` (x).
## mood: 0 = neutro, 1 = sorriso aberto (dentes), 2 = sorriso fechado.
static func face(st: SurfaceTool, head: Vector3, hr: float, brow: Color, mood: int = 2,
		eye_y: float = 0.03, eye_gap: float = 0.36) -> void:
	var z: float = -hr * 0.93
	for sx: float in [-1.0, 1.0]:
		var e: Vector3 = head + Vector3(sx * hr * eye_gap, eye_y, z)
		LowPolyMesh.box(st, e, Vector3(hr * 0.24, hr * 0.26, 0.012), Basis.IDENTITY, EYE_WHITE)
		LowPolyMesh.box(st, e + Vector3(sx * -hr * 0.03, -hr * 0.02, -0.008), Vector3(hr * 0.12, hr * 0.16, 0.01), Basis.IDENTITY, PUPIL)
		LowPolyMesh.box(st, e + Vector3(0, hr * 0.2, 0.0), Vector3(hr * 0.3, hr * 0.06, 0.02), Basis(Vector3.FORWARD, sx * 0.18), brow)
	var m: Vector3 = head + Vector3(0, -hr * 0.42, z + 0.005)
	match mood:
		1:
			LowPolyMesh.box(st, m, Vector3(hr * 0.42, hr * 0.16, 0.014), Basis.IDENTITY, MOUTH)
			LowPolyMesh.box(st, m + Vector3(0, hr * 0.04, -0.006), Vector3(hr * 0.36, hr * 0.06, 0.01), Basis.IDENTITY, TEETH)
		2:
			LowPolyMesh.box(st, m, Vector3(hr * 0.34, hr * 0.06, 0.014), Basis(Vector3.FORWARD, 0.0), MOUTH)
			for sx: float in [-1.0, 1.0]:
				LowPolyMesh.box(st, m + Vector3(sx * hr * 0.19, hr * 0.04, 0), Vector3(hr * 0.08, hr * 0.05, 0.014), Basis(Vector3.FORWARD, sx * 0.6), MOUTH)
		_:
			LowPolyMesh.box(st, m, Vector3(hr * 0.3, hr * 0.05, 0.014), Basis.IDENTITY, MOUTH)


## Cria componentes animados de cara para o How to Fish (olhos móveis + boca articulada na fala)
static func build_animated_face(parent: Node3D, head: Vector3, hr: float, brow: Color, mood: int = 2,
		eye_y: float = 0.03, eye_gap: float = 0.36) -> Node3D:
	var head_node: Node3D = Node3D.new()
	head_node.name = "NpcHead"
	head_node.position = head
	parent.add_child(head_node)
	
	var mat: ShaderMaterial = cloth_material(0.0)
	
	# Esclerótica e sobrancelhas
	var st_eyes: SurfaceTool = SurfaceTool.new()
	st_eyes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z: float = -hr * 0.93
	for sx: float in [-1.0, 1.0]:
		var e: Vector3 = Vector3(sx * hr * eye_gap, eye_y, z)
		LowPolyMesh.box(st_eyes, e, Vector3(hr * 0.24, hr * 0.26, 0.012), Basis.IDENTITY, EYE_WHITE)
		LowPolyMesh.box(st_eyes, e + Vector3(0, hr * 0.2, 0.0), Vector3(hr * 0.3, hr * 0.06, 0.02), Basis(Vector3.FORWARD, sx * 0.18), brow)
	var eyes_mesh: MeshInstance3D = MeshInstance3D.new()
	eyes_mesh.name = "EyesWhite"
	eyes_mesh.mesh = ToonKit.commit(st_eyes)
	eyes_mesh.material_override = mat
	head_node.add_child(eyes_mesh)

	# Pupilas (nó separado NpcPupils para rastreamento visual do jogador)
	var pupils_node: Node3D = Node3D.new()
	pupils_node.name = "NpcPupils"
	var st_pupils: SurfaceTool = SurfaceTool.new()
	st_pupils.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx: float in [-1.0, 1.0]:
		var e: Vector3 = Vector3(sx * hr * eye_gap, eye_y, z)
		LowPolyMesh.box(st_pupils, e + Vector3(sx * -hr * 0.03, -hr * 0.02, -0.008), Vector3(hr * 0.12, hr * 0.16, 0.01), Basis.IDENTITY, PUPIL)
	var pupils_mesh: MeshInstance3D = MeshInstance3D.new()
	pupils_mesh.name = "PupilsMesh"
	pupils_mesh.mesh = ToonKit.commit(st_pupils)
	pupils_mesh.material_override = mat
	pupils_node.add_child(pupils_mesh)
	head_node.add_child(pupils_node)

	# Boca articulada (nó separado NpcMouth para escala na fala)
	var mouth_node: Node3D = Node3D.new()
	mouth_node.name = "NpcMouth"
	var m_pos: Vector3 = Vector3(0, -hr * 0.42, z + 0.005)
	mouth_node.position = m_pos
	var st_mouth: SurfaceTool = SurfaceTool.new()
	st_mouth.begin(Mesh.PRIMITIVE_TRIANGLES)
	match mood:
		1:
			LowPolyMesh.box(st_mouth, Vector3.ZERO, Vector3(hr * 0.42, hr * 0.16, 0.014), Basis.IDENTITY, MOUTH)
			LowPolyMesh.box(st_mouth, Vector3(0, hr * 0.04, -0.006), Vector3(hr * 0.36, hr * 0.06, 0.01), Basis.IDENTITY, TEETH)
		2:
			LowPolyMesh.box(st_mouth, Vector3.ZERO, Vector3(hr * 0.34, hr * 0.06, 0.014), Basis(Vector3.FORWARD, 0.0), MOUTH)
			for sx: float in [-1.0, 1.0]:
				LowPolyMesh.box(st_mouth, Vector3(sx * hr * 0.19, hr * 0.04, 0), Vector3(hr * 0.08, hr * 0.05, 0.014), Basis(Vector3.FORWARD, sx * 0.6), MOUTH)
		_:
			LowPolyMesh.box(st_mouth, Vector3.ZERO, Vector3(hr * 0.3, hr * 0.05, 0.014), Basis.IDENTITY, MOUTH)
	var mouth_mesh: MeshInstance3D = MeshInstance3D.new()
	mouth_mesh.name = "MouthMesh"
	mouth_mesh.mesh = ToonKit.commit(st_mouth)
	mouth_mesh.material_override = mat
	mouth_node.add_child(mouth_mesh)
	head_node.add_child(mouth_node)

	return head_node


## Nariz facetado.
static func nose(st: SurfaceTool, head: Vector3, hr: float, color: Color, size: float = 1.0) -> void:
	LowPolyMesh.prism(st, head + Vector3(0, -hr * 0.05, -hr * 0.9), head + Vector3(0, -hr * 0.2, -hr * (1.05 + 0.12 * size)),
		hr * 0.13 * size, hr * 0.07 * size, 5, color)


## Material das roupas: cor por vértice com sujidade/lascas leves (cores com alfa 1).
static func cloth_material(chip: float = 0.25, chip_color: Color = Color(0.45, 0.35, 0.25)) -> ShaderMaterial:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	mat.set_shader_parameter(&"chip_amount", chip)
	mat.set_shader_parameter(&"chip_color", chip_color)
	mat.set_shader_parameter(&"chip_scale", 6.0)
	return mat
