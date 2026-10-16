class_name HermitCrab
extends Crab

## Caranguejo-ermitão: variante lenta e resistente do Crab, com uma concha grande às costas.
## Anda de frente (pinças para o jogador); golpes vindos da frente só fazem FRONT_DAMAGE_FACTOR
## do dano, por trás ou de lado fazem dano normal. Surge a partir do nível 2 de ameaça.

## Fração do dano que passa quando o golpe vem pela frente (a concha/pinças protegem).
const FRONT_DAMAGE_FACTOR: float = 0.25
## Cosseno do meio-ângulo do cone frontal (0.35 ≈ ±70°).
const FRONT_CONE_DOT: float = 0.35

## Cores da concha em sRGB (material toon do corpo, com pintas/manchas).
const SHELL_LIGHT: Color = Color(0.9, 0.86, 0.78)
const SHELL_MID: Color = Color(0.82, 0.76, 0.68)
const SHELL_DARK: Color = Color(0.6, 0.48, 0.4)
const SPOT: Color = Color(0.86, 0.5, 0.3)
const BARNACLE: Color = Color(0.62, 0.62, 0.6)
const NpcBodyShell := preload("res://gameplay/quests/npc_body.gd")

var _shell: MeshInstance3D = null


func _ready() -> void:
	super._ready()
	_build_shell()


func _palette() -> Dictionary:
	return CrabModel.PALETTE_HERMIT


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
		SFX.play_at(SFX.SHELL_KNOCK, global_position)
		return amount * FRONT_DAMAGE_FACTOR
	return amount


func is_front_hit(from: Vector3) -> bool:
	return _modify_damage(1.0, from) < 1.0


## Concha (#61, fiel a ermitao.jpg): búzio deitado às costas, volta grande à frente e espiral a
## afinar para trás e para cima, com cristas em anel, pintas cor de laranja e cracas. A boca
## (anel escuro) abraça o corpo.
func _build_shell() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	# Espiral: cada volta mais pequena, a rodar à volta de um eixo inclinado para trás (+Z) e cima
	var axis_o: Vector3 = Vector3(0.0, 0.36, 0.18)
	var axis_d: Vector3 = Vector3(0.0, 0.45, 0.89).normalized()
	var turns: int = 11
	var prev: Vector3 = Vector3.ZERO
	for i: int in turns:
		var t: float = float(i) / float(turns - 1)
		var ang: float = t * TAU * 2.2
		var r_spiral: float = lerpf(0.14, 0.0, t)
		var side: Vector3 = Vector3(cos(ang), 0.0, 0.0) + axis_d.cross(Vector3.RIGHT) * sin(ang)
		var c: Vector3 = axis_o + axis_d * t * 0.42 + side * r_spiral
		var r: float = lerpf(0.27, 0.04, pow(t, 0.8))
		NpcBodyShell.blob(st, c, Vector3(r, r * 0.95, r), SHELL_LIGHT if i % 2 == 0 else SHELL_MID, 9, 0.01, i)
		if i > 0:
			LowPolyMesh.prism(st, prev, c, r * 1.02, r * 0.98, 9, SHELL_DARK)
		prev = c
		# Pintas cor de laranja à superfície
		for k: int in 3:
			var dir: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
			var up_ref: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
			LowPolyMesh.box(st, c + dir * r * 0.96, Vector3(r * 0.34, r * 0.28, r * 0.08), Basis.looking_at(dir, up_ref), SPOT)
	# Cracas (pequenos cones cinzentos) na volta grande
	for k: int in 5:
		var a: float = rng.randf_range(0.0, TAU)
		var p: Vector3 = axis_o + Vector3(cos(a) * 0.26, absf(sin(a)) * 0.2 + 0.08, sin(a) * 0.1)
		LowPolyMesh.prism(st, p, p + (p - axis_o).normalized() * 0.05, 0.035, 0.015, 6, BARNACLE)
	# Boca da concha (anel escuro onde o corpo entra)
	LowPolyMesh.prism(st, Vector3(0.0, 0.18, 0.06), Vector3(0.0, 0.26, 0.16), 0.24, 0.29, 9, SHELL_DARK)

	_shell = LowPolyMesh.commit(st, "Shell", body_material)
	body_root.add_child(_shell)
