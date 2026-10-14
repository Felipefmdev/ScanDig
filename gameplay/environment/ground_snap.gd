@tool
class_name GroundSnap
extends Node3D

## Põe cada filho direto à altura do chão da Praia (BeachTerrain.height_at) em _ready,
## mantendo x/z e a rotação. `sink` enterra ligeiramente (troncos, rochas).

@export var sink: float = 0.05


func _ready() -> void:
	for c: Node in get_children():
		var n: Node3D = c as Node3D
		if n == null:
			continue
		var p: Vector3 = n.global_position
		n.global_position = Vector3(p.x, BeachTerrain.height_at(p.x, p.z) - sink, p.z)
