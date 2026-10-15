@tool
extends Node3D

## Raiz das cenas `world_scene` das ferramentas (ToolData, #37): o mesmo modelo serve na banca
## (ShopOffer: origem = tampo da mesa) e no chão (ItemPickup: origem = centro da caixa de
## colisão, 0,125 m acima do chão). O filho "Model" recebe a pose certa para cada caso.

@export var shop_pose: Transform3D = Transform3D.IDENTITY
@export var ground_pose: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	var model: Node3D = get_node_or_null(^"Model") as Node3D
	if model != null:
		model.transform = ground_pose if get_parent() is ItemPickup else shop_pose
