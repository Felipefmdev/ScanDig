class_name QuestCounter
extends Node

## Objetivo "apanhar N" (#41): conta as interações dos `inputs` (cada um conta uma vez) e,
## ao chegar a `required`, liga `success_flag` no WorldFlags. Ex.: as 3 chaves que os corvos
## largam. Corre no host; o progresso aparece por cima do último apanhado ("Chaves: 2/3").

signal progressed(count: int, required: int)
signal completed()

@export var inputs: Array[NodePath] = []
@export var required: int = 3
@export var success_flag: StringName = &""
## Texto do progresso (%d/%d), dito a quem apanhou.
@export var progress_text: String = "%d/%d"

var count: int = 0
var _counted: Array[int] = []


func _ready() -> void:
	for i: int in inputs.size():
		var it: Interactable = get_node_or_null(inputs[i]) as Interactable
		if it != null:
			it.interacted.connect(_on_input.bind(i))


func _on_input(peer_id: int, index: int) -> void:
	if not HostSync.is_host(self) or _counted.has(index) or count >= required:
		return
	_counted.append(index)
	count += 1
	progressed.emit(count, required)
	var it: Interactable = get_node_or_null(inputs[index]) as Interactable
	if it != null and not progress_text.is_empty():
		it.say_to(peer_id, I18n.fmt(progress_text, [count, required]), 3.0)
	if count >= required:
		var flags: WorldFlags = WorldFlags.find(get_tree())
		if flags != null and success_flag != &"":
			flags.set_flag(success_flag)
		completed.emit()
