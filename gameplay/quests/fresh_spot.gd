class_name FreshSpot
extends RefCounted

## Pontos de escavação "frescos" abertos por eventos do mapa (#96 meteorito, #97 nicho de coluna).
## Só no host: usa o MultiplayerSpawner do SpotSpawner do mapa, que replica para os clientes,
## com um achado do item_pool do mapa. `n` deve ser único (os nomes dos spots não podem repetir).


## SpotSpawner do mapa: sobe a partir de `from` até um antepassado que o tenha como filho.
static func find_spawner(from: Node) -> Node:
	var n: Node = from.get_parent() if from != null else null
	while n != null:
		var s: Node = n.get_node_or_null(^"SpotSpawner")
		if s != null:
			return s
		n = n.get_parent()
	return null


## Cria o spot em `world_pos`; devolve-o (ou null se não houver spawner/achado).
static func spawn(from: Node, world_pos: Vector3, n: int, group: StringName = &"") -> Node:
	var spawner: Node = find_spawner(from)
	if spawner == null:
		return null
	var net: MultiplayerSpawner = spawner.get("_net_spawner") as MultiplayerSpawner
	var item: ItemData = spawner.call("_pick_item") as ItemData if spawner.has_method("_pick_item") else null
	if net == null or item == null:
		return null
	var map_data: MapData = spawner.get("map_data") as MapData
	var spot: Node = net.spawn({
		"n": n,
		"item_id": item.id,
		"rare": map_data != null and randf() < map_data.rare_variant_chance,
		"pos": (spawner as Node3D).to_local(world_pos),
	})
	if spot != null:
		if group != &"":
			spot.add_to_group(group)
		print("[FreshSpot] %s (%s) em %s" % [spot.name, item.id, world_pos])
	return spot
