extends Node

## Põe os modelos importados (Kenney .glb) do mapa no estilo toon + contorno preto (#36):
## em _ready (adiado um frame, para apanhar tudo o que o mapa criou) percorre o pai e troca os
## materiais pelos do ToonKit. Um nó destes por mapa (world/map_*.tscn, nó "ToonOverride").

## Raiz a percorrer (vazio = o pai).
@export var root_path: NodePath = NodePath("")

var converted: int = 0


func _ready() -> void:
	_apply.call_deferred()


func _apply() -> void:
	var root: Node = get_node_or_null(root_path) if not root_path.is_empty() else get_parent()
	if root == null:
		return
	converted = ToonKit.apply_to_imported(root)
