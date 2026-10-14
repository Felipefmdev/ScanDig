@tool
class_name GroundSnap
extends Node3D

## Põe cada filho direto à altura do chão (BeachTerrain/FieldTerrain.height_at) em _ready,
## mantendo x/z e a rotação. `sink` enterra ligeiramente (troncos, rochas).

@export var sink: float = 0.05
## Que chão usar: Praia (BeachTerrain) ou Campo (FieldTerrain).
@export_enum("Praia", "Campo") var terrain: int = 0


func _ready() -> void:
	for c: Node in get_children():
		var n: Node3D = c as Node3D
		if n == null:
			continue
		var p: Vector3 = n.global_position
		n.global_position = Vector3(p.x, _height(p.x, p.z) - sink, p.z)


func _height(x: float, z: float) -> float:
	return FieldTerrain.height_at(x, z) if terrain == 1 else BeachTerrain.height_at(x, z)
