@tool
class_name GroundSnap
extends Node3D

## Põe cada filho direto à altura do chão (BeachTerrain/FieldTerrain.height_at) em _ready,
## mantendo x/z e a rotação. `sink` enterra ligeiramente (troncos, rochas).

@export var sink: float = 0.05
## Que chão usar: Praia (BeachTerrain) ou Campo (FieldTerrain).
@export_enum("Praia", "Campo") var terrain: int = 0


## #47 (editor): filho -> [y gravado na cena, y depois de assentar]. Antes de gravar repõe-se o y
## gravado (se ninguém mexeu no filho entretanto); depois de gravar volta a assentar.
var _saved_y: Dictionary = {}


func _ready() -> void:
	_snap()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		for key: Variant in _saved_y.keys():
			if not is_instance_valid(key):
				continue
			var n: Node3D = key as Node3D
			if is_equal_approx(n.position.y, float(_saved_y[key][1])):
				n.position.y = float(_saved_y[key][0])
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_snap()


func _snap() -> void:
	_saved_y.clear()
	for c: Node in get_children():
		var n: Node3D = c as Node3D
		if n == null:
			continue
		var saved: float = n.position.y
		var p: Vector3 = n.global_position
		n.global_position = Vector3(p.x, _height(p.x, p.z) - sink, p.z)
		_saved_y[n] = [saved, n.position.y]


func _height(x: float, z: float) -> float:
	return FieldTerrain.height_at(x, z) if terrain == 1 else BeachTerrain.height_at(x, z)
