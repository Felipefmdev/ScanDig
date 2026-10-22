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
	collision_mask = 1  # Player.tscn uses layer 1.


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		_apply_healing()


func _apply_healing() -> void:
	# Health belongs to its player. Do not heal remote replicas on every peer.
	# Use the comfort radius directly: the authored Area overlap cache can be empty
	# after map setup even when a fresh shape query detects the same player.
	for body: Node3D in get_tree().get_nodes_in_group(&"player"):
		if not body.has_method(&"is_local") or not bool(body.call(&"is_local")):
			continue
		if not body.has_method(&"heal") or body.get("health") == null or body.get("max_health") == null:
			continue
		if bool(body.get("is_downed")) or float(body.get("health")) <= 0.0:
			continue
		if (body.global_position + Vector3.UP * 0.9).distance_to(global_position + Vector3.UP * 0.5) > heal_radius:
			continue
		if float(body.get("health")) < float(body.get("max_health")):
			body.call(&"heal", heal_per_second)
