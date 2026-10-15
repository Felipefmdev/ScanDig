class_name Crow
extends Seagull

## Corvo do Campo (#41): voa em círculos como a gaivota e mergulha, mas não rouba: bica
## (peck_damage) e volta a subir. Quem leva uma chave da Dona Lurdes no bico (carries_key,
## replicado) não desiste nem foge: só a larga quando é abatido (DropOnDeath põe a chave onde
## caiu). Abate-se no mergulho com a pá, ou no ar com o estilingue.

const BLACK: Color = Color(0.1, 0.1, 0.13)
const BLUE_BLACK: Color = Color(0.16, 0.18, 0.26)
const FEATHER_TIP: Color = Color(0.05, 0.05, 0.07)
const BEAK_GREY: Color = Color(0.32, 0.3, 0.3)
const EYE_WHITE: Color = Color(0.98, 0.97, 0.93)
const KEY_GOLD: Color = Color(1.0, 0.8, 0.2)

## Replicado: leva uma chave no bico.
var carries_key: bool = false:
	set(value):
		carries_key = value
		if value:
			max_dives = 9999
			_leave_timer = -1.0
		if is_node_ready():
			_refresh_key()

var _key_visual: Node3D = null


func _ready() -> void:
	super._ready()
	_refresh_key()


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:carries_key")


## Bica em vez de roubar.
func _grab(target: Node3D) -> void:
	_on_loot_reply(null, target)


## Quem leva chave nunca foge (nem com o repelente: só se afasta e volta).
func _start_escape(away_from: Vector3) -> void:
	if carries_key:
		_dives = 0
		_circle_left = randf_range(circle_time_min, circle_time_max)
		_enter_state(State.CIRCLE)
		return
	super._start_escape(away_from)


func _refresh_key() -> void:
	if _key_visual != null:
		_key_visual.visible = carries_key
		return
	if not carries_key:
		return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g: Color = Color(KEY_GOLD.r, KEY_GOLD.g, KEY_GOLD.b, 0.0)
	LowPolyMesh.prism(st, Vector3(0.0, -0.05, -0.47), Vector3(0.0, -0.2, -0.47), 0.012, 0.012, 4, g)
	LowPolyMesh.box(st, Vector3(0.025, -0.18, -0.47), Vector3(0.04, 0.015, 0.012), Basis.IDENTITY, g)
	LowPolyMesh.prism(st, Vector3(0.0, -0.02, -0.47), Vector3(0.0, -0.06, -0.47), 0.035, 0.035, 6, g)
	_key_visual = LowPolyMesh.commit(st, "Key", LowPolyMesh.make_material())
	add_child(_key_visual)


# ---------------------------------------------------------------------------
# Modelo: corvo preto-azulado, olhos grandes, bico cinzento
# ---------------------------------------------------------------------------

func _build_model() -> void:
	var mat: ShaderMaterial = LowPolyMesh.make_material()
	_register_flash_material(mat)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.24), Vector3(0.0, 0.02, -0.2), 0.11, 0.13, 6, BLACK)
	# Cauda em leque
	for k: int in 3:
		var a: float = (float(k) - 1.0) * 0.25
		LowPolyMesh.box(st, Vector3(sin(a) * 0.08, 0.02, 0.38), Vector3(0.07, 0.02, 0.22), Basis(Vector3.UP, a), FEATHER_TIP)
	# Cabeça, penacho, olhos esbugalhados, bico grosso
	LowPolyMesh.box(st, Vector3(0.0, 0.1, -0.27), Vector3(0.15, 0.15, 0.16), Basis.IDENTITY, BLUE_BLACK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.17, -0.25), Vector3(0.0, 0.26, -0.18), 0.04, 0.0, 4, BLACK)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.078 * side, 0.13, -0.3), Vector3(0.02, 0.06, 0.06), Basis.IDENTITY, EYE_WHITE)
		LowPolyMesh.box(st, Vector3(0.088 * side, 0.13, -0.31), Vector3(0.01, 0.03, 0.03), Basis.IDENTITY, EYE_BLACK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.08, -0.34), Vector3(0.0, 0.06, -0.5), 0.045, 0.0, 4, BEAK_GREY)
	LowPolyMesh.box(st, Vector3(-0.04, -0.11, 0.12), Vector3(0.03, 0.03, 0.08), Basis.IDENTITY, BEAK_GREY)
	LowPolyMesh.box(st, Vector3(0.04, -0.11, 0.12), Vector3(0.03, 0.03, 0.08), Basis.IDENTITY, BEAK_GREY)
	add_child(LowPolyMesh.commit(st, "Body", mat))
	_wing_left = _build_crow_wing(-1.0, mat)
	_wing_right = _build_crow_wing(1.0, mat)


func _build_crow_wing(side: float, mat: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "WingLeft" if side < 0.0 else "WingRight"
	pivot.position = Vector3(0.09 * side, 0.05, -0.02)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st, Vector3(0.2 * side, 0.0, 0.0), Vector3(0.4, 0.025, 0.22), Basis.IDENTITY, BLUE_BLACK)
	# Penas da ponta separadas (silhueta de corvo)
	for k: int in 3:
		LowPolyMesh.box(st, Vector3((0.47 + 0.03 * k) * side, 0.0, -0.06 + 0.07 * k), Vector3(0.2, 0.018, 0.05),
			Basis(Vector3.UP, (0.1 + 0.12 * k) * side), FEATHER_TIP)
	pivot.add_child(LowPolyMesh.commit(st, "Mesh", mat))
	add_child(pivot)
	return pivot
