class_name WorldFlags
extends Node

## Bandeiras do mapa partilhadas pela equipa (#39): "anzol_encontrado", "mare_baixa",
## "conchas_resolvidas"... Decididas no host e replicadas a todos (e a quem entra tarde).
## Um por mapa (vem na cena; WorldFlags.find()). Interativos, missões e gatilhos de chefe
## ligam-se umas às outras por bandeiras em vez de caminhos entre nós.

signal flag_changed(flag: StringName, value: bool)

const GROUP: StringName = &"world_flags"

var _flags: Dictionary = {}


static func find(tree: SceneTree) -> WorldFlags:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as WorldFlags


func _ready() -> void:
	add_to_group(GROUP)
	if HostSync.is_host(self):
		HostSync.on_peer_ready(self, _send_all)


func has_flag(flag: StringName) -> bool:
	return bool(_flags.get(flag, false))


## Host: liga/desliga uma bandeira e replica.
func set_flag(flag: StringName, value: bool = true) -> void:
	if not HostSync.is_host(self) or flag == &"":
		return
	if has_flag(flag) == value:
		return
	_apply(flag, value)
	HostSync.broadcast(self, &"_rpc_flag", [String(flag), value])


func get_all() -> Dictionary:
	return _flags.duplicate()


func _apply(flag: StringName, value: bool) -> void:
	_flags[flag] = value
	flag_changed.emit(flag, value)


@rpc("authority", "call_remote", "reliable")
func _rpc_flag(flag: String, value: bool) -> void:
	if has_flag(StringName(flag)) != value:
		_apply(StringName(flag), value)


func _send_all(peer_id: int) -> void:
	for flag: StringName in _flags:
		HostSync.send_to(self, peer_id, &"_rpc_flag", [String(flag), bool(_flags[flag])])


## Liga `callback()` para correr (uma vez) quando `flag` ficar verdadeira; se já estiver,
## corre já. Útil nos gatilhos que dependem de bandeiras.
func when_set(flag: StringName, callback: Callable) -> void:
	if has_flag(flag):
		callback.call()
		return
	var holder: Array = []
	var cb: Callable = func(f: StringName, v: bool) -> void:
		if f == flag and v:
			flag_changed.disconnect(holder[0])
			callback.call()
	holder.append(cb)
	flag_changed.connect(cb)
