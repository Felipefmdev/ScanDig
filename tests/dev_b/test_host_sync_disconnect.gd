extends GutTest

## #127: HostSync.on_peer_ready desfaz a ligação ao CoreSession.peer_scene_ready quando o nó sai
## da árvore (antes as lambdas se acumulavam a cada ida e davam "Lambda capture freed").


func _connections() -> int:
	return SessionManager.instance.peer_scene_ready.get_connections().size()


func test_connection_released_when_node_leaves_tree() -> void:
	var before: int = _connections()
	var node: Node = Node.new()
	add_child(node)
	var calls: Array[int] = []
	HostSync.on_peer_ready(node, func(peer_id: int) -> void: calls.append(peer_id))
	assert_eq(_connections(), before + 1, "liga enquanto o nó está na árvore")

	SessionManager.instance.peer_scene_ready.emit(7, "praia")
	assert_eq(calls, [7] as Array[int], "o host recebe o peer pronto")

	node.free()
	assert_eq(_connections(), before, "a ligação some quando o nó sai da árvore")


func test_repeated_maps_do_not_accumulate() -> void:
	var before: int = _connections()
	for i: int in 5:
		var node: Node = Node.new()
		add_child(node)
		HostSync.on_peer_ready(node, func(_peer_id: int) -> void: pass)
		node.queue_free()
		await wait_frames(1)
	assert_eq(_connections(), before, "5 mapas seguidos não deixam ligações para trás")
