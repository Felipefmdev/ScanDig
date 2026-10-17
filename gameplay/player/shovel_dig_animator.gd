class_name ShovelDigAnimator
extends Node

## Pá na mão do jogador: sacar, cavar, golpe e guardar.
##
## O `rig` é um Node3D sem escala, em top_level, com a origem na ponta da lâmina e +Y ao longo
## do cabo; dentro dele estão o modelo da pá (escalado) e a HandModel. A pá está guardada
## (invisível) por omissão. Cavar ou atacar saca-a (~0.15s); se não for usada durante
## `holster_delay` segundos, desce e esconde-se.
##
## Cavar = levantar → cravar no chão (ponto real) → alavancar → atirar a terra → repouso.
## O resultado do dig() é aplicado pelo Player no sinal `impact`.

## A lâmina cravou: é aqui que o resultado do dig() deve ser aplicado.
signal impact(ground_point: Vector3)
## A terra sai da lâmina: posição da lâmina e direção lateral do arremesso.
signal throw_dirt(blade_position: Vector3, side: Vector3)
## A pá chega à frente no golpe (F).
signal swing_hit
signal finished

enum Target { REST, HOLSTER, RAISE, PLANT, LEVER, THROW, SWING_BACK, SWING_HIT }

const DRAW_TIME: float = 0.15
const HOLSTER_TIME: float = 0.2
## Durações base (segundos): RAISE, PLANT, LEVER, THROW, RETURN.
const FAST_DURATIONS: Array[float] = [0.10, 0.08, 0.10, 0.10, 0.16]
const CAREFUL_DURATIONS: Array[float] = [0.22, 0.26, 0.24, 0.22, 0.26]
const SWING_DURATIONS: Array[float] = [0.08, 0.1, 0.18]
## Quanto a lâmina entra na areia.
const BLADE_DEPTH: float = 0.12

## Segundos sem usar a pá até ela ser guardada.
@export var holster_delay: float = 1.5
## Pose de repouso do rig no espaço da câmara (pá sacada, lado esquerdo do ecrã).
@export var rest_pose: Transform3D = Transform3D.IDENTITY
## Deslocamento (espaço da câmara) da pose guardada em relação ao repouso.
@export var holster_offset: Vector3 = Vector3(-0.1, -0.75, 0.25)

var rig: Node3D = null
var camera: Camera3D = null
var body: Node3D = null

var _drawn: bool = false
var _idle_time: float = 0.0
var _careful: bool = false
var _sequence: Array[Target] = []
var _durations: Array[float] = []
var _step: int = -1
var _time: float = 0.0
var _from: Transform3D = Transform3D.IDENTITY
var _ground: Vector3 = Vector3.ZERO
var _toward: Vector3 = Vector3.BACK
var _side: Vector3 = Vector3.LEFT
var _swing_side: float = 1.0


func setup(p_rig: Node3D, p_camera: Camera3D, p_body: Node3D) -> void:
	rig = p_rig
	camera = p_camera
	body = p_body
	if rig != null:
		rig.top_level = true
		rig.visible = false


func is_playing() -> bool:
	return _step >= 0


func is_drawn() -> bool:
	return _drawn


## Verdadeiro quando não está a tocar ou quando já está no último passo (Target.REST)
## do swing com >= 60% do passo concluído, permitindo emendar o próximo golpe.
func can_chain_swing() -> bool:
	if _step < 0:
		return true
	if _step == _sequence.size() - 1 and _sequence[_step] == Target.REST and _sequence.has(Target.SWING_HIT):
		return _durations[_step] > 0.0 and (_time / _durations[_step]) >= 0.6
	return false


## Inicia a animação de cavar. speed_factor > 1 acelera (pás melhores). Devolve a duração total.
func play(ground_point: Vector3, is_careful: bool, speed_factor: float = 1.0) -> float:
	if not _can_animate():
		return 0.0
	_careful = is_careful
	_ground = ground_point
	var to_player: Vector3 = body.global_position - ground_point
	to_player.y = 0.0
	_toward = to_player.normalized() if to_player.length() > 0.05 else body.global_basis.z
	_side = -body.global_basis.x  # atira para a esquerda, o lado da pá
	_side.y = 0.0
	_side = _side.normalized()

	var base: Array[float] = CAREFUL_DURATIONS if is_careful else FAST_DURATIONS
	var seq: Array[Target] = [Target.RAISE, Target.PLANT, Target.LEVER, Target.THROW, Target.REST]
	var durs: Array[float] = []
	for d: float in base:
		durs.append(d / maxf(speed_factor, 0.1))
	return _start(seq, durs)


## Golpe com a pá (F): saca se preciso, recua e bate à frente em curva alternando o lado.
func play_swing() -> float:
	if not _can_animate():
		return 0.0
	_careful = false
	_swing_side = -_swing_side
	var seq: Array[Target] = [Target.SWING_BACK, Target.SWING_HIT, Target.REST]
	return _start(seq, SWING_DURATIONS.duplicate())


## Interrompe tudo e guarda a pá de imediato (ex.: morte).
func cancel() -> void:
	_step = -1
	_drawn = false
	if rig != null:
		rig.visible = false


func _can_animate() -> bool:
	return rig != null and camera != null and body != null


func _start(seq: Array[Target], durs: Array[float]) -> float:
	_sequence = seq
	_durations = durs
	if not _drawn:
		# Sacar: sobe da pose guardada até ao repouso antes do movimento.
		_sequence.push_front(Target.REST)
		_durations.push_front(DRAW_TIME)
		_from = _pose(Target.HOLSTER)
		rig.visible = true
		_drawn = true
	else:
		_from = rig.global_transform
	_step = 0
	_time = 0.0
	_idle_time = 0.0
	var total: float = 0.0
	for d: float in _durations:
		total += d
	return total


func _process(delta: float) -> void:
	if rig == null or not _drawn:
		return
	if _step < 0:
		# Sacada e parada: segue a câmara; guarda-se depois de holster_delay.
		_idle_time += delta
		if _idle_time >= holster_delay:
			_sequence = [Target.HOLSTER]
			_durations = [HOLSTER_TIME]
			_from = rig.global_transform
			_step = 0
			_time = 0.0
		else:
			rig.global_transform = _pose(Target.REST)
		return

	_time += delta
	while _step >= 0 and _time >= _durations[_step]:
		_time -= _durations[_step]
		_from = _pose(_sequence[_step])
		_on_step_finished(_sequence[_step])
		_step += 1
		if _step >= _sequence.size():
			_step = -1
			_idle_time = 0.0
			finished.emit()
	if _step < 0:
		if _drawn:
			rig.global_transform = _pose(Target.REST)
		return
	var t: float = clampf(_time / _durations[_step], 0.0, 1.0)
	var pose: Transform3D = _from.interpolate_with(_pose(_sequence[_step]), _ease(_sequence[_step], t))
	if _sequence[_step] == Target.SWING_HIT and camera != null:
		var arc: float = sin(t * PI)
		pose.origin += camera.global_basis * Vector3(-0.08 * _swing_side * arc, 0.06 * arc, -0.12 * arc)
	rig.global_transform = pose


func _on_step_finished(target: Target) -> void:
	match target:
		Target.PLANT:
			impact.emit(_ground)
		Target.THROW:
			throw_dirt.emit(_pose(Target.THROW).origin, _side)
		Target.SWING_HIT:
			swing_hit.emit()
		Target.HOLSTER:
			_drawn = false
			rig.visible = false


func _ease(target: Target, t: float) -> float:
	if _careful:
		return smoothstep(0.0, 1.0, t)
	match target:
		Target.PLANT, Target.SWING_HIT:
			return ease(t, 2.6)  # acelera até ao impacto
		Target.HOLSTER:
			return ease(t, 2.0)
	return ease(t, 0.35)  # brusco a travar


## Pose-alvo (global) do rig.
func _pose(target: Target) -> Transform3D:
	var cam: Transform3D = camera.global_transform
	match target:
		Target.HOLSTER:
			return cam * Transform3D(rest_pose.basis, rest_pose.origin + holster_offset)
		Target.RAISE:
			# Sobe e inclina para trás, a preparar a pazada.
			return cam * Transform3D(Basis(Vector3.RIGHT, -0.55) * rest_pose.basis, rest_pose.origin + Vector3(0.08, 0.2, 0.06))
		Target.SWING_BACK:
			var back_rot: Basis = Basis(Vector3.UP, 0.35 * _swing_side) * Basis(Vector3.FORWARD, -0.5 * _swing_side) * Basis(Vector3.RIGHT, -0.7)
			return cam * Transform3D(back_rot * rest_pose.basis, rest_pose.origin + Vector3(-0.14 * _swing_side, 0.25, 0.1))
		Target.SWING_HIT:
			var hit_rot: Basis = Basis(Vector3.UP, -0.45 * _swing_side) * Basis(Vector3.FORWARD, 0.6 * _swing_side) * Basis(Vector3.RIGHT, 0.9)
			return cam * Transform3D(hit_rot * rest_pose.basis, rest_pose.origin + Vector3(0.3 * _swing_side, 0.05, -0.35))
		Target.PLANT:
			# O cabo inclina para o lado da pá: visto da câmara não fica "de topo".
			var shaft: Vector3 = (Vector3.UP * 0.85 + _toward * 0.35 + _side * 0.45).normalized()
			return _world_pose(_ground - shaft * BLADE_DEPTH, shaft, _toward)
		Target.LEVER:
			# Alavanca: o cabo desce na direção do jogador e a lâmina sobe um pouco.
			var shaft: Vector3 = (Vector3.UP * 0.45 + _toward * 0.75 + _side * 0.4).normalized()
			return _world_pose(_ground + Vector3.UP * 0.06 - shaft * 0.04, shaft, _toward)
		Target.THROW:
			var shaft: Vector3 = (Vector3.UP * 0.55 + _toward * 0.7 - _side * 0.45).normalized()
			var tip: Vector3 = _ground + Vector3.UP * 0.5 + _side * 0.45 + _toward * 0.25
			return _world_pose(tip, shaft, (_side + Vector3.UP * 0.5).normalized())
		_:
			return cam * rest_pose


## Origem = ponta da lâmina; +Y = cabo; `face` = para onde a face da lâmina aponta.
func _world_pose(tip: Vector3, shaft: Vector3, face: Vector3) -> Transform3D:
	var y: Vector3 = shaft.normalized()
	var x: Vector3 = y.cross(face)
	if x.length_squared() < 0.0001:
		x = y.cross(Vector3.FORWARD)
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), tip)
