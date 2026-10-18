class_name DetectorSpawn
extends Marker3D

## Ponto do mapa onde o detetor de metais aparece no chão para ser apanhado (ItemPickup).
## Coop: os itens no chão são do host (#5 E), por isso só o host cria detetores: um para
## si e mais um por cada peer que carrega o mapa (cada jogador precisa do seu).

const TOOL_ID: StringName = &"detector"
const TOOL_NAME: String = "Detector de Metais"
const WORLD_MODEL: PackedScene = preload("res://gameplay/detector/detector_world_model.tscn")
## Distância entre detetores extra (um por jogador), ao longo do X local do marcador.
const EXTRA_SPACING: float = 0.6

## Altura acima do marcador a que o pickup nasce (cai até ao chão).
@export var drop_height: float = 0.3

var _spawned: int = 0


func _ready() -> void:
	if not multiplayer.is_server():
		return
	# Diferido: a cena-mãe ainda está a montar-se e a física tem de estar pronta.
	_spawn.call_deferred()
	var sm: SessionManager = SessionManager.instance
	if sm != null:
		sm.peer_scene_ready.connect(_on_peer_scene_ready)


func _on_peer_scene_ready(peer_id: int, _map_id: String) -> void:
	# O detetor do host já nasceu no _ready.
	if peer_id != multiplayer.get_unique_id():
		_spawn()


func _spawn() -> void:
	var parent: Node = get_parent()
	if parent == null or not is_inside_tree():
		return
	var offset: Vector3 = global_basis.x * EXTRA_SPACING * float(_spawned)
	_spawned += 1
	var pickup: ItemPickup = ItemPickup.spawn(
		parent,
		CarriedItem.create_tool(TOOL_ID, TOOL_NAME, WORLD_MODEL),
		global_position + offset + Vector3.UP * drop_height
	)
	if pickup != null:
		pickup.global_rotation = global_rotation
