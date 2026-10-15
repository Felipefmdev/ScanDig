class_name DropOnDeath
extends Node

## Os inimigos de um WaveEvent levam e largam interativos ao morrer (#41, as chaves da Dona
## Lurdes): enquanto houver nós livres em `pool` (Interactable escondido) e `while_flag` estiver
## ligada (vazio = sempre), cada inimigo novo recebe um (carries_key = true, se a cena tiver
## essa propriedade: o corvo mostra a chave no bico) e, quando morre, o nó aparece no chão onde
## caiu (Interactable.place_at + set_active, replicados). Corre no host.

@export var wave_path: NodePath = NodePath("")
@export var pool: Array[NodePath] = []
@export var while_flag: StringName = &""
@export_flags_3d_physics var ground_mask: int = 1

## Índices do pool ainda por entregar (um inimigo que desapareça sem morrer devolve o seu).
var _free: Array[int] = []


func _ready() -> void:
	for i: int in pool.size():
		_free.append(i)
	var wave: WaveEvent = get_node_or_null(wave_path) as WaveEvent
	if wave != null:
		wave.enemy_spawned.connect(_on_enemy_spawned)


## Quantos nós do pool estão entregues ou já no chão.
func get_assigned() -> int:
	return pool.size() - _free.size()


func _on_enemy_spawned(enemy: Node3D) -> void:
	if not HostSync.is_host(self) or not enemy.has_signal(&"died"):
		return
	if _free.is_empty() or not _flag_ok():
		return
	var index: int = _free.pop_front()
	if "carries_key" in enemy:
		enemy.set(&"carries_key", true)
	var died: Array[bool] = [false]
	enemy.connect(&"died", func() -> void: died[0] = true)
	# A posição final só se sabe quando sai da árvore (os voadores caem antes de desaparecer).
	enemy.tree_exiting.connect(func() -> void:
		if died[0]:
			_drop_at(enemy, index)
		else:
			_free.push_front(index), CONNECT_ONE_SHOT)


func _drop_at(enemy: Node3D, index: int) -> void:
	var it: Interactable = get_node_or_null(pool[index]) as Interactable
	if it == null:
		return
	it.place_at(_ground(enemy.global_position))
	it.set_active(true)


func _flag_ok() -> bool:
	if while_flag == &"":
		return true
	var flags: WorldFlags = WorldFlags.find(get_tree())
	return flags != null and flags.has_flag(while_flag)


func _ground(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return p
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 40.0, ground_mask)
	var hit: Dictionary = space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p
