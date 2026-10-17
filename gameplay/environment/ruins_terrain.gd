@tool
class_name RuinsTerrain
extends StaticBody3D

## Chão das Ruínas (#42): templo antigo engolido pela selva. Malha low-poly facetada (normais e
## cor por face, toon sem contorno) com:
##   - pátio central em lajes (xadrez gasto, juntas escuras, musgo);
##   - plataforma do templo a norte (+TEMPLE_HEIGHT), com rampas de entrada;
##   - cripta afundada a oeste (CRYPT_DEPTH) com rampa;
##   - areia e terra de selva fora das lajes, colinas para lá das paredes.
## A colisão é a mesma malha (layer 1). height_at() é estático (GroundSnap terrain = Ruinas).

const SIZE: Vector2 = Vector2(-46.0, 46.0)
const CELL: float = 1.0
const PLAY_HALF: float = 31.0

const SAND: Color = Color(0.78, 0.68, 0.48)
const JUNGLE: Color = Color(0.3, 0.45, 0.2)
const JUNGLE_DRY: Color = Color(0.48, 0.5, 0.26)
const PAVE_LIGHT: Color = Color(0.72, 0.67, 0.58)
const PAVE_DARK: Color = Color(0.6, 0.55, 0.47)
const GROUT: Color = Color(0.42, 0.38, 0.33)
const MOSS: Color = Color(0.38, 0.5, 0.24)
const CRYPT: Color = Color(0.36, 0.33, 0.32)
const HILL: Color = Color(0.25, 0.4, 0.18)
## Terra escura que aparece nas lajes em falta e nas juntas abertas.
const SOIL: Color = Color(0.4, 0.31, 0.21)

## Pátio em lajes: círculo (x, z, raio) e corredor até ao templo.
const PLAZA: Vector3 = Vector3(0.0, -2.0, 11.0)
## Plataforma do templo (retângulo x0, z0, largura, profundidade) e altura.
const TEMPLE: Rect2 = Rect2(-12.0, -29.0, 24.0, 15.0)
const TEMPLE_HEIGHT: float = 0.9
## Rampas de entrada (x, z, largura): sobem do pátio para a plataforma.
const RAMP_Z: float = -14.0
const RAMP_LEN: float = 2.5
## Cripta afundada (x, z, raio) e profundidade; rampa para leste.
const CRYPT_CENTER: Vector2 = Vector2(-22.0, -6.0)
const CRYPT_RADIUS: float = 5.0
const CRYPT_DEPTH: float = 1.3
## Zonas planas (x, z, raio): spawn e base de entrega.
const FLAT_ZONES: Array[Vector3] = [Vector3(0.0, 0.0, 3.5), Vector3(3.5, 3.5, 4.0)]
const NOISE_AMP: float = 0.16
const TILE: float = 2.0
## Fração de lajes em falta e de lajes partidas (por laje, estável).
const MISSING_SLABS: float = 0.07
const CRACKED_SLABS: float = 0.18
## Fração de lajes com a junta aberta de cada lado (x e z), com terra/musgo na orla.
const OPEN_JOINTS: float = 0.1

static var _noise: FastNoiseLite = null
static var _broad: FastNoiseLite = null

@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if is_inside_tree():
			rebuild()


func _ready() -> void:
	rebuild()


static func _get_noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 4242
		_noise.frequency = 0.09
		_noise.fractal_octaves = 3
	return _noise


static func _get_broad() -> FastNoiseLite:
	if _broad == null:
		_broad = FastNoiseLite.new()
		_broad.seed = 777
		_broad.frequency = 0.03
		_broad.fractal_octaves = 2
	return _broad


## 1 no pátio/corredor/plataforma (chão em lajes), 0 fora.
static func paved_weight(x: float, z: float) -> float:
	var d: float = Vector2(x - PLAZA.x, z - PLAZA.y).length()
	var w: float = smoothstep(PLAZA.z + 0.5, PLAZA.z - 0.5, d)
	# corredor do pátio ao templo
	if absf(x) < 3.5 and z < 0.0 and z > TEMPLE.position.y:
		w = maxf(w, smoothstep(3.5, 2.8, absf(x)))
	return maxf(w, _temple_weight(x, z))


static func _temple_weight(x: float, z: float) -> float:
	var ix: float = minf(x - TEMPLE.position.x, TEMPLE.end.x - x)
	var iz: float = minf(z - TEMPLE.position.y, TEMPLE.end.y - z)
	return clampf(minf(ix, iz) + 0.5, 0.0, 1.0)


static func _crypt_weight(x: float, z: float) -> float:
	var d: float = Vector2(x, z).distance_to(CRYPT_CENTER)
	var w: float = smoothstep(CRYPT_RADIUS, CRYPT_RADIUS - 1.5, d)
	# rampa a leste
	if z > CRYPT_CENTER.y - 1.2 and z < CRYPT_CENTER.y + 1.2 and x > CRYPT_CENTER.x:
		w = maxf(w, smoothstep(CRYPT_CENTER.x + CRYPT_RADIUS + 3.0, CRYPT_CENTER.x + CRYPT_RADIUS - 1.0, x))
	return w


## Altura do chão em (x, z) — determinística.
static func height_at(x: float, z: float) -> float:
	var paved: float = paved_weight(x, z)
	var h: float = _get_noise().get_noise_2d(x, z) * NOISE_AMP * (1.0 - paved * 0.85)
	h += (_get_broad().get_noise_2d(x, z) + 0.2) * 0.5 * (1.0 - paved)
	# plataforma do templo (com rampa de RAMP_LEN m a sul)
	var tw: float = _temple_weight(x, z)
	if tw > 0.0:
		h = lerpf(h, TEMPLE_HEIGHT, tw)
	elif z > TEMPLE.end.y and z < TEMPLE.end.y + RAMP_LEN and absf(x) < 3.0:
		var k: float = 1.0 - (z - TEMPLE.end.y) / RAMP_LEN
		h = lerpf(h, TEMPLE_HEIGHT, k * smoothstep(3.0, 2.4, absf(x)))
	h -= _crypt_weight(x, z) * CRYPT_DEPTH
	for f: Vector3 in FLAT_ZONES:
		var dist: float = Vector2(x - f.x, z - f.y).length()
		h = lerpf(h, 0.0, smoothstep(f.z, f.z * 0.6, dist))
	var edge: float = maxf(absf(x), absf(z))
	var rise: float = smoothstep(PLAY_HALF - 1.0, SIZE.y, edge)
	h += rise * rise * (6.0 + _get_broad().get_noise_2d(x * 2.0, z * 2.0) * 3.0)
	return h


static func color_at(x: float, z: float, h: float) -> Color:
	var n: float = _get_noise().get_noise_2d(z * 1.7 + 30.0, x * 1.7)
	var c: Color = JUNGLE.lerp(JUNGLE_DRY, clampf(0.5 + n * 1.5, 0.0, 1.0))
	# areia junto às lajes
	var paved: float = paved_weight(x, z)
	var sand_k: float = smoothstep(4.0, 0.0, absf(Vector2(x - PLAZA.x, z - PLAZA.y).length() - PLAZA.z))
	c = c.lerp(SAND, sand_k * 0.8)
	if paved > 0.5:
		c = _slab_color(x, z, n, TILE, PAVE_DARK, PAVE_LIGHT)
	var cw: float = _crypt_weight(x, z)
	if cw > 0.3:
		# chão da cripta: as mesmas lajes, mais escuras e húmidas
		c = _slab_color(x, z, n, TILE, CRYPT.darkened(0.2), CRYPT)
	else:
		c = c.lerp(CRYPT, cw)
	var edge: float = maxf(absf(x), absf(z))
	if edge > PLAY_HALF:
		c = c.lerp(HILL, clampf((edge - PLAY_HALF) / 6.0, 0.0, 1.0))
	return c.darkened(clampf(-h * 0.12, 0.0, 0.25))


## Inteiro pseudo-aleatório estável por laje (ix, iz) e canal -> [0, 1).
static func tile_rand(ix: int, iz: int, channel: int) -> float:
	var k: int = (ix * 73856093) ^ (iz * 19349663) ^ (channel * 83492791)
	k = (k ^ (k >> 13)) * 1274126177
	k = k ^ (k >> 16)
	return float(k & 0xFFFF) / 65536.0


## Cor de uma face dentro das lajes (estudo How to Fish: chão variado). As faces têm 1 m e a
## laje TILE m, por isso o detalhe é por triângulo: tom próprio de cada laje, lajes partidas na
## diagonal (as duas metades com tons diferentes), lajes em falta (terra e musgo à vista) e a
## orla de algumas lajes tomada por terra/musgo (as "juntas" largas entre lajes levantadas).
static func _slab_color(x: float, z: float, n: float, tile: float, dark: Color, light: Color) -> Color:
	var ix: int = int(floorf(x / tile))
	var iz: int = int(floorf(z / tile))
	var tx: float = fposmod(x, tile) / tile
	var tz: float = fposmod(z, tile) / tile
	var tone: float = tile_rand(ix, iz, 0)
	var c: Color = dark.lerp(light, tone)
	# laje mais quente ou mais fria (pedras de pedreiras diferentes)
	var tint: float = tile_rand(ix, iz, 1) - 0.5
	c = Color(c.r + tint * 0.06, c.g, c.b - tint * 0.06)
	var kind: float = tile_rand(ix, iz, 2)
	if kind < MISSING_SLABS:
		# laje em falta: terra com musgo pelo meio
		return c.lerp(SOIL.lerp(MOSS, clampf(0.5 + n * 2.0, 0.0, 0.8)), 0.75)
	if kind < MISSING_SLABS + CRACKED_SLABS:
		# laje partida: a metade de um lado da diagonal assentou e escureceu
		var flip: bool = tile_rand(ix, iz, 3) < 0.5
		var side: float = (tx + tz) if flip else (tx + 1.0 - tz)
		if side > 1.0:
			c = c.darkened(0.16)
	# orla de terra/musgo: só em algumas lajes e só do lado onde a junta está aberta
	var edge_side: float = tile_rand(ix, iz, 4)
	var near_edge: bool = (tx < 0.25 and edge_side < OPEN_JOINTS) or (tz < 0.25 and edge_side > 1.0 - OPEN_JOINTS)
	if near_edge:
		c = c.lerp(SOIL.lerp(MOSS, clampf(0.4 + n * 2.0, 0.0, 0.9)), 0.6)
	elif n > 0.22:
		# manchas de musgo por cima das lajes
		c = c.lerp(MOSS, clampf((n - 0.22) * 4.0, 0.0, 0.7))
	return c


func rebuild() -> void:
	for child: Node in get_children():
		if child.owner == null:
			child.free()
	if not Engine.is_editor_hint():
		collision_layer = 1
		collision_mask = 0
	var cells: int = int((SIZE.y - SIZE.x) / CELL)
	var pts: Array[PackedVector3Array] = []
	for i: int in cells + 1:
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in cells + 1:
			var x: float = SIZE.x + i * CELL
			var z: float = SIZE.x + j * CELL
			row.append(Vector3(x, height_at(x, z), z))
		pts.append(row)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: PackedVector3Array = PackedVector3Array()
	for i: int in cells:
		for j: int in cells:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i + 1][j]
			var c: Vector3 = pts[i + 1][j + 1]
			var d: Vector3 = pts[i][j + 1]
			var tris: Array = [[a, d, c], [a, c, b]] if (i + j) % 2 == 0 else [[a, d, b], [b, d, c]]
			for t: Array in tris:
				faces.append_array(_face(st, t[0], t[1], t[2]))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = st.commit()
	mi.material_override = ToonKit.material(&"terrain")
	add_child(mi)
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	add_child(cs)


func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> PackedVector3Array:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
		n = -n
	var center: Vector3 = (a + b + c) / 3.0
	var col: Color = color_at(center.x, center.z, center.y)
	for v: Vector3 in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)
	return PackedVector3Array([a, c, b])
