class_name SequencePuzzle
extends Node

## Puzzle de sequência (#39): os interativos `inputs` têm de ser usados pela ordem de
## `solution` (índices em `inputs`). Ex.: as 3 conchas da Praia (abre o Polvo), os menires do
## Campo pela ordem do sol. Corre no host; ao acertar liga `success_flag` no WorldFlags
## (o BossTrigger/relíquia escuta essa bandeira). Um erro recomeça a sequência.
## Com ordered = false basta usar todos, por qualquer ordem.

signal progressed(step: int, total: int)
signal failed()
signal solved()

@export var inputs: Array[NodePath] = []
@export var solution: PackedInt32Array = PackedInt32Array()
@export var ordered: bool = true
@export var success_flag: StringName = &""
## Mensagem dita pelo interativo ao errar / acertar (vazio = nada).
@export var fail_text: String = ""
@export var success_text: String = ""

var progress: int = 0
var is_solved: bool = false
var _used: Array[int] = []
var _nodes: Array[Interactable] = []


func _ready() -> void:
	for i: int in inputs.size():
		var it: Interactable = get_node_or_null(inputs[i]) as Interactable
		_nodes.append(it)
		if it != null:
			it.interacted.connect(_on_input.bind(i))


func _on_input(peer_id: int, index: int) -> void:
	if is_solved or not HostSync.is_host(self):
		return
	if ordered:
		var expected: int = solution[progress] if progress < solution.size() else -1
		if index != expected:
			_fail(peer_id, index)
			return
		progress += 1
	else:
		if not _used.has(index):
			_used.append(index)
		progress = _used.size()
	var total: int = solution.size() if ordered else _nodes.size()
	progressed.emit(progress, total)
	if progress >= total:
		_solve(index)


func _fail(peer_id: int, index: int) -> void:
	# O erro só recomeça; se este input for o primeiro da solução, conta já como passo 1.
	progress = 1 if solution.size() > 0 and index == solution[0] else 0
	failed.emit()
	if not fail_text.is_empty() and _nodes[index] != null:
		_nodes[index].say_to(peer_id, fail_text, 2.5)


func _solve(index: int) -> void:
	is_solved = true
	if success_flag != &"":
		var flags: WorldFlags = WorldFlags.find(get_tree())
		if flags != null:
			flags.set_flag(success_flag)
	if not success_text.is_empty() and _nodes[index] != null:
		_nodes[index].say_all(success_text, 4.0)
	solved.emit()
