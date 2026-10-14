class_name EnemySpawner
extends Node3D

## Faz surgir caranguejos perto da origem do barulho quando o DisturbanceMeter passa um limiar.

signal enemy_spawned(enemy: Node3D)

const DEFAULT_CRAB_SCENE: PackedScene = preload("res://gameplay/enemies/crab/crab.tscn")

@export var crab_scene: PackedScene = null
@export var max_alive: int = 6
## Quantos caranguejos surgem por nível de ameaça (índice 0 = nível 1).
@export var spawns_per_level: Array[int] = [1, 2, 4]
@export var min_spawn_radius: float = 4.0
@export var max_spawn_radius: float = 8.0
## Máscara de colisão usada para encontrar o chão.
@export_flags_3d_physics var ground_mask: int = 1

const RAY_HEIGHT: float = 10.0
const RAY_DEPTH: float = 20.0

var _alive: Array[Node3D] = []
var _connected: bool = false


func _ready() -> void:
	if crab_scene == null:
		crab_scene = DEFAULT_CRAB_SCENE
	_try_connect()


func _process(_delta: float) -> void:
	# O DisturbanceMeter pode entrar na árvore depois deste nó; tentamos até ligar.
	if not _connected:
		_try_connect()


func _try_connect() -> void:
	if DisturbanceMeter.instance == null:
		return
	DisturbanceMeter.instance.threshold_reached.connect(_on_threshold_reached)
	_connected = true
	set_process(false)


func _on_threshold_reached(level: int, origin: Vector3) -> void:
	if level <= 0 or spawns_per_level.is_empty():
		return
	var count: int = spawns_per_level[mini(level, spawns_per_level.size()) - 1]
	for i: int in range(count):
		if get_alive_count() >= max_alive:
			return
		_spawn_crab(origin, level)


func get_alive_count() -> int:
	# Caranguejos mortos ficam como referências libertadas; um lambda tipado (n: Node3D)
	# rebenta ao receber um objeto libertado, por isso limpamos com um ciclo.
	for i: int in range(_alive.size() - 1, -1, -1):
		if not is_instance_valid(_alive[i]):
			_alive.remove_at(i)
	return _alive.size()


func _spawn_crab(origin: Vector3, level: int) -> void:
	if crab_scene == null:
		return
	var crab: Node3D = crab_scene.instantiate() as Node3D
	if crab == null:
		return
	if crab is Crab:
		(crab as Crab).spawn_level = level

	var pos: Vector3 = _pick_spawn_position(origin)
	crab.position = to_local(pos)
	add_child(crab)
	_alive.append(crab)
	enemy_spawned.emit(crab)


func _pick_spawn_position(origin: Vector3) -> Vector3:
	var angle: float = randf() * TAU
	var radius: float = randf_range(min_spawn_radius, max_spawn_radius)
	var flat: Vector3 = origin + Vector3(cos(angle), 0.0, sin(angle)) * radius

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		flat + Vector3.UP * RAY_HEIGHT,
		flat + Vector3.DOWN * RAY_DEPTH,
		ground_mask
	)
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"] as Vector3
	return Vector3(flat.x, origin.y, flat.z)
