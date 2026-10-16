@tool
class_name GrassField
extends MultiMeshInstance3D

## Relva densa em tufos (estilo How to Fish) com um único MultiMesh: cada tufo é um leque de
## lâminas facetadas com gradiente verde (cores por vértice), assente no chão via
## BeachTerrain.height_at(). Espalha os tufos em manchas à volta de `cluster_centers`.

const GREEN_DARK: Color = Color(0.12, 0.3, 0.08)
const GREEN_LIGHT: Color = Color(0.4, 0.62, 0.16)

## Centros das manchas: (x, z, raio) em coordenadas do mundo.
@export var cluster_centers: Array[Vector3] = []
@export var tufts_per_cluster: int = 90
@export var seed_value: int = 7
## Zonas sem relva (x, z, raio): base, banca, arena do chefe, praia molhada.
@export var exclusion_zones: Array[Vector3] = []
@export var max_x: float = 24.0
## Que chão usar: Praia (BeachTerrain) ou Campo (FieldTerrain).
@export_enum("Praia", "Campo", "Ruinas") var terrain: int = 0
@export var color_dark: Color = GREEN_DARK
@export var color_light: Color = GREEN_LIGHT

@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if is_inside_tree():
			rebuild()


## cast_shadow como está gravado na cena (o rebuild desliga-o; ao gravar volta a este valor).
var _saved_cast_shadow: GeometryInstance3D.ShadowCastingSetting = SHADOW_CASTING_SETTING_ON


func _ready() -> void:
	_saved_cast_shadow = cast_shadow
	rebuild()


## #47: o editor grava as propriedades do próprio nó; a MultiMesh e o cast_shadow gerados saem
## antes de gravar e voltam logo a seguir.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		multimesh = null
		cast_shadow = _saved_cast_shadow
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		rebuild()


func rebuild() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var xforms: Array[Transform3D] = []
	for c: Vector3 in cluster_centers:
		for k: int in tufts_per_cluster:
			# distribuição mais densa no centro da mancha
			var r: float = c.z * sqrt(rng.randf()) * rng.randf_range(0.6, 1.0)
			var a: float = rng.randf() * TAU
			var x: float = c.x + cos(a) * r
			var z: float = c.y + sin(a) * r
			if x > max_x or _excluded(x, z):
				continue
			var s: float = rng.randf_range(0.7, 1.35) * lerpf(1.15, 0.7, r / maxf(c.z, 0.01))
			var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
			xforms.append(Transform3D(basis, Vector3(x, _height(x, z) - 0.03, z)))

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _build_tuft_mesh()
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _height(x: float, z: float) -> float:
	match terrain:
		1:
			return FieldTerrain.height_at(x, z)
		2:
			return RuinsTerrain.height_at(x, z)
	return BeachTerrain.height_at(x, z)


func _excluded(x: float, z: float) -> bool:
	for e: Vector3 in exclusion_zones:
		if Vector2(x - e.x, z - e.y).length() < e.z:
			return true
	return false


## Tufo: 9 lâminas (cada uma = 2 triângulos afunilados), inclinadas para fora.
func _build_tuft_mesh() -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades: int = 9
	for i: int in blades:
		var a: float = TAU * float(i) / float(blades) + rng.randf_range(-0.3, 0.3)
		var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var h: float = rng.randf_range(0.28, 0.5)
		var lean: float = rng.randf_range(0.08, 0.2)
		var w: float = rng.randf_range(0.035, 0.055)
		var base: Vector3 = dir * rng.randf_range(0.0, 0.06)
		var mid: Vector3 = base + dir * lean * 0.45 + Vector3.UP * h * 0.55
		var tip: Vector3 = base + dir * lean + Vector3.UP * h
		var shade: float = rng.randf_range(0.0, 0.25)
		var c0: Color = color_dark.darkened(shade)
		var c1: Color = color_dark.lerp(color_light, 0.55).darkened(shade * 0.5)
		var c2: Color = color_light.darkened(shade * 0.3)
		# quad de baixo + triângulo da ponta (duas faces visíveis: material sem culling)
		_tri(st, base - side * w, base + side * w, mid + side * w * 0.6, c0, c0, c1)
		_tri(st, base - side * w, mid + side * w * 0.6, mid - side * w * 0.6, c0, c1, c1)
		_tri(st, mid - side * w * 0.6, mid + side * w * 0.6, tip, c1, c1, c2)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	# Toon de dupla face, sem contorno (#36): milhares de tufos, o contorno seria ruído
	mesh.surface_set_material(0, ToonKit.material(&"grass"))
	return mesh


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)
