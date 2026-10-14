class_name HermitCrab
extends Crab

## Caranguejo-ermitão: variante lenta e resistente do Crab, com uma concha grande às costas.
## Anda de frente (pinças para o jogador); golpes vindos da frente só fazem FRONT_DAMAGE_FACTOR
## do dano, por trás ou de lado fazem dano normal. Surge a partir do nível 2 de ameaça.

## Fração do dano que passa quando o golpe vem pela frente (a concha/pinças protegem).
const FRONT_DAMAGE_FACTOR: float = 0.25
## Cosseno do meio-ângulo do cone frontal (0.35 ≈ ±70°).
const FRONT_CONE_DOT: float = 0.35

const SHELL_LIGHT: Color = Color(0.93, 0.84, 0.66)
const SHELL_DARK: Color = Color(0.62, 0.42, 0.28)
const BODY_TINT: Color = Color(0.78, 0.3, 0.38)

var _shell: MeshInstance3D = null


func _ready() -> void:
	super._ready()
	if carapace.material is StandardMaterial3D:
		var mat: StandardMaterial3D = carapace.material as StandardMaterial3D
		mat.albedo_color = BODY_TINT
		# A cor base do flash foi registada antes da tinta; atualizamos.
		var idx: int = _flash_mats.find(mat)
		if idx >= 0:
			_flash_base_colors[idx] = BODY_TINT
	_build_shell()


## Dano reduzido se a origem do golpe estiver no cone da frente (-Z local).
func _modify_damage(amount: float, from: Vector3) -> float:
	if not from.is_finite():
		return amount
	var to_attacker: Vector3 = from - global_position
	to_attacker.y = 0.0
	if to_attacker.length_squared() < 0.0001:
		return amount
	var facing: Vector3 = -global_transform.basis.z
	facing.y = 0.0
	if facing.normalized().dot(to_attacker.normalized()) >= FRONT_CONE_DOT:
		spawn_particles(global_position + Vector3.UP * 0.4, Color(0.8, 0.85, 0.95), 8, 2.5)
		return amount * FRONT_DAMAGE_FACTOR
	return amount


func is_front_hit(from: Vector3) -> bool:
	return _modify_damage(1.0, from) < 1.0


## Concha em espiral low-poly facetada (troncos de cone empilhados num eixo curvo).
func _build_shell() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = [
		Vector3(0.0, 0.2, 0.22),
		Vector3(0.0, 0.46, 0.3),
		Vector3(0.0, 0.66, 0.24),
		Vector3(0.0, 0.79, 0.11),
		Vector3(0.0, 0.86, -0.02),
	]
	var radii: Array[float] = [0.33, 0.27, 0.19, 0.11, 0.0]
	for i: int in range(pts.size() - 1):
		var color: Color = SHELL_LIGHT if i % 2 == 0 else SHELL_DARK
		LowPolyMesh.prism(st, pts[i], pts[i + 1], radii[i], radii[i + 1], 8, color)
	# Boca da concha (anel escuro onde o corpo entra)
	LowPolyMesh.prism(st, Vector3(0.0, 0.16, 0.1), Vector3(0.0, 0.22, 0.2), 0.24, 0.3, 8, SHELL_DARK)

	var mat: StandardMaterial3D = LowPolyMesh.make_material()
	_shell = LowPolyMesh.commit(st, "Shell", mat)
	body_root.add_child(_shell)
	_register_flash_material(mat)
