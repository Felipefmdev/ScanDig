@tool
class_name Backdrop
extends Node3D

## Fundo distante (horizonte) dos mapas (estudo How to Fish: ilhas cercadas de água e horizonte).
## Silhuetas low-poly a 60-140 m do centro, sem colisão e sem owner (#47): Campo colinas verdes,
## Ruínas mesas de arenito, Geleira picos nevados, Cratera paredes rochosas escuras. Na Praia o
## lado +X é mar aberto até ao horizonte (plano "Sea") e as colinas só ficam do lado de terra.
## Cores alinhadas com world/environment_<mapa>.tres (o nevoeiro funde-as no céu).

const THEMES: Array[String] = ["praia", "campo", "ruinas", "geleira", "cratera", "ilha"]
const MIN_RADIUS: float = 60.0
const MAX_RADIUS: float = 140.0
const SEA_COLOR: Color = Color(0.2, 0.5, 0.66)
const SEA_START_X: float = 36.0
const SEA_EXTENT: float = 600.0

## [base, topo, escala de altura min, max, largura min, max]
const PALETTE: Dictionary = {
	"praia": [Color(0.42, 0.56, 0.36), Color(0.62, 0.66, 0.5), 10.0, 22.0, 18.0, 30.0],
	"campo": [Color(0.32, 0.52, 0.24), Color(0.5, 0.66, 0.32), 9.0, 20.0, 20.0, 34.0],
	"ruinas": [Color(0.7, 0.5, 0.32), Color(0.84, 0.66, 0.44), 12.0, 24.0, 16.0, 28.0],
	"geleira": [Color(0.42, 0.5, 0.6), Color(0.95, 0.97, 1.0), 26.0, 48.0, 16.0, 26.0],
	"ilha": [Color(0.32, 0.52, 0.3), Color(0.5, 0.62, 0.4), 5.0, 12.0, 10.0, 18.0],
	"cratera": [Color(0.16, 0.12, 0.18), Color(0.3, 0.22, 0.34), 22.0, 40.0, 22.0, 34.0],
}

@export_enum("praia", "campo", "ruinas", "geleira", "cratera", "ilha") var theme: String = "campo":
	set(v):
		theme = v
		_queue()
@export var seed_value: int = 1:
	set(v):
		seed_value = v
		_queue()
@export_range(6, 64) var count: int = 22:
	set(v):
		count = v
		_queue()
@export var sea_level: float = -0.3:
	set(v):
		sea_level = v
		_queue()

var _queued: bool = false


func _ready() -> void:
	build()


func _queue() -> void:
	if is_inside_tree() and not _queued:
		_queued = true
		build.call_deferred()


## Remonta o fundo; devolve o número de silhuetas colocadas.
func build() -> int:
	_queued = false
	for c: Node in get_children():
		if c.owner == null:
			c.free()
	var pal: Array = PALETTE.get(theme, PALETTE["campo"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(theme) ^ seed_value
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var placed: int = 0
	for i: int in count:
		var ang: float = TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(count)
		var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		# Praia: o lado +X é mar aberto.
		if theme == "praia" and dir.x > -0.15:
			continue
		# Ilha: mar aberto a toda a volta, só uns ilhéus raros e longe no horizonte.
		if theme == "ilha" and i % 4 != 0:
			continue
		var r: float = rng.randf_range(MIN_RADIUS + 15.0, MAX_RADIUS - 15.0)
		var center: Vector3 = dir * r
		var h: float = rng.randf_range(pal[2], pal[3])
		var w: float = rng.randf_range(pal[4], pal[5])
		match theme:
			"ruinas":
				_mesa(st, center, h, w, pal[0], pal[1], rng)
			"cratera":
				_wall(st, center, dir, h, w, pal[0], pal[1], rng)
			_:
				_peak(st, center, h, w, pal[0], pal[1], theme == "geleira", rng)
		placed += 1
	var hills: MeshInstance3D = MeshInstance3D.new()
	hills.name = "Hills"
	hills.mesh = ToonKit.commit(st)
	hills.material_override = ToonKit.vertex_material(true, true)
	_far(hills)
	add_child(hills)
	if theme == "praia" or theme == "ilha":
		add_child(_sea(SEA_START_X if theme == "praia" else -SEA_EXTENT))
	return placed


func _far(mi: MeshInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED


## Anel irregular de n vértices a altura y.
func _ring(center: Vector3, y: float, radius: float, n: int, phase: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var ring: PackedVector3Array = PackedVector3Array()
	for k: int in n:
		var a: float = phase + TAU * float(k) / float(n) + rng.randf_range(-0.2, 0.2)
		var rr: float = radius * rng.randf_range(0.8, 1.15)
		ring.append(center + Vector3(cos(a) * rr, y, sin(a) * rr))
	return ring


func _band(st: SurfaceTool, lo: PackedVector3Array, hi: PackedVector3Array, inside: Vector3, color: Color) -> void:
	var n: int = lo.size()
	for k: int in n:
		var j: int = (k + 1) % n
		LowPolyMesh.quad(st, lo[k], lo[j], hi[j], hi[k], inside, color)


## Colina / pico: base enterrada, anel a meia altura, cume. snow = calota branca.
func _peak(st: SurfaceTool, c: Vector3, h: float, w: float, base: Color, top: Color, snow: bool, rng: RandomNumberGenerator) -> void:
	var n: int = 7
	var phase: float = rng.randf() * TAU
	var lo: PackedVector3Array = _ring(c, -6.0, w, n, phase, rng)
	var mid: PackedVector3Array = _ring(c, h * 0.55, w * (0.35 if snow else 0.6), n, phase, rng)
	var tip: Vector3 = c + Vector3(rng.randf_range(-0.2, 0.2) * w, h, rng.randf_range(-0.2, 0.2) * w)
	var inside: Vector3 = c + Vector3.UP * h * 0.3
	_band(st, lo, mid, inside, base)
	for k: int in n:
		var j: int = (k + 1) % n
		LowPolyMesh.tri(st, mid[k], mid[j], tip, inside, top if snow else base.lerp(top, 0.6 + 0.4 * rng.randf()))


## Mesa de arenito: lados quase verticais, faixa mais escura e topo plano.
func _mesa(st: SurfaceTool, c: Vector3, h: float, w: float, base: Color, top: Color, rng: RandomNumberGenerator) -> void:
	var n: int = 6
	var phase: float = rng.randf() * TAU
	var lo: PackedVector3Array = _ring(c, -6.0, w, n, phase, rng)
	var mid: PackedVector3Array = _ring(c, h * 0.6, w * 0.82, n, phase, rng)
	var hi: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in mid:
		hi.append(c + (p - c) * Vector3(0.92, 0.0, 0.92) + Vector3.UP * h)
	var inside: Vector3 = c + Vector3.UP * h * 0.4
	_band(st, lo, mid, inside, base.darkened(0.12))
	_band(st, mid, hi, inside, base)
	var cap: Vector3 = c + Vector3.UP * h
	for k: int in n:
		LowPolyMesh.tri(st, hi[k], hi[(k + 1) % n], cap, inside, top)


## Parede rochosa escura da cratera: laje larga, tangente ao anel, com topo serrilhado.
func _wall(st: SurfaceTool, c: Vector3, dir: Vector3, h: float, w: float, base: Color, top: Color, rng: RandomNumberGenerator) -> void:
	var tangent: Vector3 = Vector3(-dir.z, 0.0, dir.x)
	var depth: float = w * 0.35
	var segs: int = 4
	for s: int in segs:
		var t0: float = (float(s) / segs - 0.5) * w * 2.0
		var t1: float = (float(s + 1) / segs - 0.5) * w * 2.0
		var hs: float = h * rng.randf_range(0.7, 1.1)
		var p: Vector3 = c + tangent * (t0 + t1) * 0.5
		LowPolyMesh.prism(st, p + Vector3.DOWN * 6.0, p + Vector3.UP * hs, (t1 - t0) * 0.75 + depth * 0.3, (t1 - t0) * 0.25, 5, base.lerp(top, rng.randf()))


func _sea(start_x: float = SEA_START_X) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y: float = sea_level
	var a: Vector3 = Vector3(start_x, y, -SEA_EXTENT)
	var b: Vector3 = Vector3(SEA_EXTENT, y, -SEA_EXTENT)
	var c: Vector3 = Vector3(SEA_EXTENT, y, SEA_EXTENT)
	var d: Vector3 = Vector3(start_x, y, SEA_EXTENT)
	LowPolyMesh.quad(st, a, b, c, d, Vector3(start_x + 1.0, y - 1.0, 0.0), SEA_COLOR)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material(false, true)
	_far(mi)
	return mi
