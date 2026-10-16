class_name LanternFlash
extends RefCounted

## Lanterna de Magnésio (#42): flash em cone que atordoa os inimigos à frente e faz os morcegos
## fugir. O Player chama fire() no jogador local; o efeito (luz + som) é local. O stun/fuga
## usam EnemyBase.stun()/flee_from(): num cliente esses métodos já viram request_stun/
## request_flee ao host (contrato #5), por isso funciona em coop sem mais nada.

const RANGE: float = 9.0
## Cosseno do meio-ângulo do cone (0.8 ≈ ±37°).
const CONE_DOT: float = 0.8
const STUN_SECONDS: float = 2.5
const FLEE_SECONDS: float = 6.0
const GROUP_FLEES: StringName = &"flees_from_light"
const SOUND: String = "res://assets/audio/kenney_interface-sounds/maximize_006.ogg"


## Dispara o flash. Devolve quantos inimigos apanhou (>= 0). shooter = jogador (para o raio
## de visibilidade não bater nele).
static func fire(origin: Vector3, forward: Vector3, shooter: Node) -> int:
	var tree: SceneTree = shooter.get_tree() if shooter != null and shooter.is_inside_tree() else null
	if tree == null:
		return 0
	var fwd: Vector3 = forward.normalized()
	_show_flash(tree, origin, fwd)
	var hits: int = 0
	for n: Node in tree.get_nodes_in_group(EnemyBase.GROUP):
		var e: EnemyBase = n as EnemyBase
		if e == null or not e.is_alive():
			continue
		var target: Vector3 = e.global_position + Vector3.UP * 0.5
		var to: Vector3 = target - origin
		var dist: float = to.length()
		if dist > RANGE or dist < 0.01 or fwd.dot(to / dist) < CONE_DOT:
			continue
		if not _visible(shooter, origin, target, e):
			continue
		hits += 1
		if e.is_in_group(GROUP_FLEES):
			e.flee_from(origin, FLEE_SECONDS)
		e.stun(STUN_SECONDS)
	return hits


static func _visible(shooter: Node, from: Vector3, to: Vector3, enemy: EnemyBase) -> bool:
	var world: World3D = (shooter as Node3D).get_world_3d() if shooter is Node3D else null
	if world == null:
		return true
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	var ex: Array[RID] = [enemy.get_rid()]
	if shooter is CollisionObject3D:
		ex.append((shooter as CollisionObject3D).get_rid())
	q.exclude = ex
	return world.direct_space_state.intersect_ray(q).is_empty()


## Clarão local: uma luz forte que se apaga em 0,35 s e um som.
static func _show_flash(tree: SceneTree, origin: Vector3, fwd: Vector3) -> void:
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var light: SpotLight3D = SpotLight3D.new()
	light.light_color = Color(1.0, 0.97, 0.85)
	light.light_energy = 16.0
	light.spot_range = RANGE + 2.0
	light.spot_angle = 40.0
	parent.add_child(light)
	light.global_position = origin
	light.look_at(origin + fwd, Vector3.UP if absf(fwd.y) < 0.99 else Vector3.RIGHT)
	var tw: Tween = light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.tween_callback(light.queue_free)
	SFX.play_at(SOUND, origin, 2.0)
