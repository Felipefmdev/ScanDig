class_name RuneStone
extends Interactable

## Pedra que acende ao tocar (#41, os menires do Campo): põe-se em cima de um menir já
## existente e desenha um anel de runas à volta dele. state 1 = acesa (runas a brilhar e uma
## luz), 0 = apagada. Quem decide é o SequencePuzzle (light_inputs) no host.

const RUNE_OFF: Color = Color(0.3, 0.3, 0.33)
const RUNE_ON: Color = Color(1.0, 0.8, 0.35)

## Raio do anel de runas (≈ meia largura do menir + folga) e alturas das duas filas.
@export var ring_radius: float = 0.42
@export var ring_heights: PackedFloat32Array = PackedFloat32Array([0.9, 1.35])
@export var light_color: Color = Color(1.0, 0.75, 0.35)

var _mat: ShaderMaterial = null
var _light: OmniLight3D = null


func _ready() -> void:
	if prompt == "[E] Interagir":
		prompt = "[E] Tocar na pedra"
	super._ready()
	_build_runes()
	_apply_lit(false)


func _on_state_applied() -> void:
	super._on_state_applied()
	_apply_lit(state == 1)


func is_lit() -> bool:
	return state == 1


func _apply_lit(on: bool) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter(&"emission_color", Color(0.9, 0.62, 0.2) if on else Color.BLACK)
	_mat.set_shader_parameter(&"albedo_color", RUNE_ON if on else RUNE_OFF)
	_light.visible = on


func _build_runes() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in ring_heights.size():
		var count: int = 6
		for k: int in count:
			var ang: float = TAU * float(k) / float(count) + float(row) * 0.5
			var c: Vector3 = Vector3(cos(ang) * ring_radius, ring_heights[row], sin(ang) * ring_radius)
			var b: Basis = Basis(Vector3.UP, -ang + PI * 0.5)
			# Runa: barra vertical + traço em ângulo (low-poly)
			LowPolyMesh.box(st, c, Vector3(0.05, 0.16, 0.025), b, Color.WHITE)
			LowPolyMesh.box(st, c + Vector3(0.0, 0.03, 0.0), Vector3(0.1, 0.03, 0.025), b * Basis(Vector3.FORWARD, 0.6), Color.WHITE)
	_mat = ToonKit.vertex_material(true, true)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Runes"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = _mat
	add_child(mi)
	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_color = light_color
	_light.light_energy = 2.0
	_light.omni_range = 4.0
	_light.position = Vector3(0.0, 1.2, 0.0)
	_light.shadow_enabled = false
	add_child(_light)
