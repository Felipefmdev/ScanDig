class_name DetectorSpawn
extends Marker3D

## Ponto do mapa onde o detetor de metais aparece no chão para ser apanhado (ItemPickup).

const TOOL_ID: StringName = &"detector"
const TOOL_NAME: String = "Detetor de Metais"
const WORLD_MODEL: PackedScene = preload("res://gameplay/detector/detector_world_model.tscn")

## Altura acima do marcador a que o pickup nasce (cai até ao chão).
@export var drop_height: float = 0.3


func _ready() -> void:
	# Diferido: a cena-mãe ainda está a montar-se e a física tem de estar pronta.
	_spawn.call_deferred()


func _spawn() -> void:
	var parent: Node = get_parent()
	if parent == null or not is_inside_tree():
		return
	var pickup: ItemPickup = ItemPickup.spawn(
		parent,
		CarriedItem.create_tool(TOOL_ID, TOOL_NAME, WORLD_MODEL),
		global_position + Vector3.UP * drop_height
	)
	pickup.global_rotation = global_rotation
