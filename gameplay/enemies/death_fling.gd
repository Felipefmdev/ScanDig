extends RefCounted

## Morte "caótica" (estudo How to Fish): o visual do inimigo sai voando como um corpo
## físico, girando e quicando pelo chão, e só some depois. Puramente cosmético: corre em
## cada peer (host no _die, cliente quando a vida replicada chega a 0) e não tem rede.

const LIFETIME: float = 1.8
const UP_SPEED: Vector2 = Vector2(4.5, 7.0)
const PUSH_SPEED: Vector2 = Vector2(3.0, 5.5)
const SPIN: float = 9.0
const SHRINK_TIME: float = 0.25
const MAX_LIVE: int = 12

static var _live: Array[RigidBody3D] = []


## Move os visuais de `enemy` para um RigidBody3D lançado para longe de `from`
## (Vector3.INF = direção aleatória). Devolve o corpo, ou null se não havia o que lançar.
static func fling(enemy: Node3D, from: Vector3 = Vector3.INF) -> RigidBody3D:
	if enemy == null or not enemy.is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else enemy.get_parent()
	if parent == null:
		return null
	var visuals: Array[Node3D] = []
	var shape: Shape3D = null
	for child: Node in enemy.get_children():
		if child is CollisionShape3D:
			if shape == null and (child as CollisionShape3D).shape != null:
				shape = (child as CollisionShape3D).shape.duplicate() as Shape3D
		elif child is Node3D and not (child is Area3D or child is CollisionObject3D or child is AudioStreamPlayer3D):
			visuals.append(child as Node3D)
	if visuals.is_empty():
		return null
	_trim()
	var body: RigidBody3D = RigidBody3D.new()
	body.name = "DeathFling"
	body.collision_layer = 0
	body.collision_mask = 1  # só o chão/cenário: não empurra jogadores nem itens
	body.mass = 2.0
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.bounce = 0.45
	body.physics_material_override.friction = 0.6
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape if shape != null else SphereShape3D.new()
	body.add_child(col)
	parent.add_child(body)
	body.global_transform = enemy.global_transform
	for v: Node3D in visuals:
		v.reparent(body, true)
	var dir: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if from != Vector3.INF:
		dir = enemy.global_position - from
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	body.linear_velocity = dir * randf_range(PUSH_SPEED.x, PUSH_SPEED.y) + Vector3.UP * randf_range(UP_SPEED.x, UP_SPEED.y)
	body.angular_velocity = Vector3(randf_range(-SPIN, SPIN), randf_range(-SPIN, SPIN), randf_range(-SPIN, SPIN))
	_live.append(body)
	var t: Tween = body.create_tween()
	t.tween_interval(LIFETIME)
	t.tween_property(body, "scale", Vector3.ONE * 0.01, SHRINK_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(body.queue_free)
	return body


static func live_count() -> int:
	_trim()
	return _live.size()


## Muitas mortes juntas (ondas, explosões): os corpos mais antigos saem já.
static func _trim() -> void:
	var alive: Array[RigidBody3D] = []
	for b: RigidBody3D in _live:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			alive.append(b)
	_live = alive
	while _live.size() >= MAX_LIVE:
		_live.pop_front().queue_free()
