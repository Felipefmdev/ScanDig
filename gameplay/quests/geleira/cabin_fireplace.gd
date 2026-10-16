class_name CabinFireplace
extends Area3D

## Lareira acolhedora da cabana do Velho Björn (#43).
## Cura lentamente os jogadores na área de conforto ao pé do fogo (~5 HP por segundo).

@export var heal_per_second: float = 5.0
@export var heal_radius: float = 3.5

var _timer: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2  # Jogadores (layer 2)


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		_apply_healing()


func _apply_healing() -> void:
	for body: Node3D in get_overlapping_bodies():
		if body.has_method("heal") and body.get("health") != null and body.get("max_health") != null:
			var h: float = float(body.get("health"))
			var mh: float = float(body.get("max_health"))
			if h < mh:
				body.call("heal", heal_per_second)
