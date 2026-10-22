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
## Que chão usar: Praia (BeachTerrain), Campo (FieldTerrain), Ruinas, Geleira, Cratera ou Ilha.
@export_enum("Praia", "Campo", "Ruinas", "Geleira", "Cratera", "Ilha") var terrain: int = 0

## Explicit semantic exceptions only; authored Y is never implicitly added.
## Keys are direct child names. Values are metres above terrain or the named support.
@export var height_offsets: Dictionary = {}
## Keys are direct child names; NodePaths are relative to this GroundSnap.
## Example: {"RelicChalice": NodePath("NicheTower/Step3")} with offset .3.
@export var support_paths: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	snap()


## Assenta os filhos diretos no chão (x/z e rotação ficam).
func snap() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	# First settle ordinary nodes/support roots; their dependents follow in a second pass.
	for c: Node in get_children():
		var n: Node3D = c as Node3D
		if n == null:
			continue
		if support_paths.has(String(n.name)):
			continue
		var p: Vector3 = n.global_position
		var offset: float = float(height_offsets.get(String(n.name), 0.0))
		n.global_position = Vector3(p.x, _height(p.x, p.z) - sink + offset, p.z)
	for c: Node in get_children():
		var n: Node3D = c as Node3D
		if n == null or not support_paths.has(String(n.name)):
			continue
		var path: NodePath = NodePath(str(support_paths[String(n.name)]))
		var support: Node3D = get_node_or_null(path) as Node3D
		if support == null:
			push_warning("GroundSnap: missing explicit support %s for %s" % [path, n.name])
			continue # Keep placement rather than silently dropping a relic into terrain.
		var p: Vector3 = n.global_position
		# sink belongs to the ground/support root; do not apply it twice on stacked pieces.
		var offset: float = float(height_offsets.get(String(n.name), 0.0))
		n.global_position = Vector3(p.x, support.global_position.y + offset, p.z)


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
