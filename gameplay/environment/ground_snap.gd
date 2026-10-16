@tool
class_name GroundSnap
extends Node3D

## Põe cada filho direto à altura do chão (BeachTerrain/FieldTerrain.height_at) em _ready,
## mantendo x/z e a rotação. `sink` enterra ligeiramente (troncos, rochas).
##
## #47/#53: só em jogo. Os filhos são nós gravados na cena (owner = mapa) e nenhum @tool pode
## mexer nas transforms deles no editor: num separador em segundo plano a cena está fora da
## árvore, global_position devolve a identidade e uma gravação punha tudo na origem (e67f0e9).
## O script fica @tool só para ser a mesma classe no editor (os mapas usam-no); lá não faz nada.

const GlacierTerrain = preload("res://gameplay/environment/glacier_terrain.gd")
const CraterTerrain = preload("res://gameplay/environment/crater_terrain.gd")

@export var sink: float = 0.05
## Que chão usar: Praia (BeachTerrain), Campo (FieldTerrain), Ruinas, Geleira ou Cratera.
@export_enum("Praia", "Campo", "Ruinas", "Geleira", "Cratera") var terrain: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	snap()


## Assenta os filhos diretos no chão (x/z e rotação ficam).
func snap() -> void:
	if not is_inside_tree():
		return
	for c: Node in get_children():
		var n: Node3D = c as Node3D
		if n == null:
			continue
		var p: Vector3 = n.global_position
		n.global_position = Vector3(p.x, _height(p.x, p.z) - sink, p.z)


func _height(x: float, z: float) -> float:
	match terrain:
		1:
			return FieldTerrain.height_at(x, z)
		2:
			return RuinsTerrain.height_at(x, z)
		3:
			return GlacierTerrain.height_at(x, z)
		4:
			return CraterTerrain.height_at(x, z)
	return BeachTerrain.height_at(x, z)
