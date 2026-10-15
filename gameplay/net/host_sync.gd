class_name HostSync
extends RefCounted

## Ajudas para nós fixos do mapa cujo estado o host decide (contrato #5): interativos,
## missões, eventos de rondas, gatilhos de chefe (#39). O nó tem de existir com o mesmo
## caminho em todos os peers (vem na cena do mapa). Padrão:
##   - um cliente pede ao host com rpc_id(1, ...); em solo/offline chama-se direto;
##   - o host muda o estado e difunde-o com HostSync.broadcast() aos peers com o mapa pronto;
##   - quem entra mais tarde recebe o estado completo (HostSync.on_peer_ready).


## Verdadeiro onde o estado se decide: solo/offline, fora da árvore (testes) ou no host.
static func is_host(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return true
	var mp: MultiplayerAPI = node.multiplayer
	return not NetVisibility.is_online(mp) or mp.is_server()


## Peer id deste processo (1 em solo).
static func local_peer(node: Node) -> int:
	if node == null or not node.is_inside_tree() or not NetVisibility.is_online(node.multiplayer):
		return 1
	return node.multiplayer.get_unique_id()


## Host: chama `method(args...)` por RPC em todos os peers remotos com o mapa carregado.
## (O próprio host aplica o estado localmente antes de chamar isto.)
static func broadcast(node: Node, method: StringName, args: Array = []) -> void:
	if node == null or not node.is_inside_tree() or not NetVisibility.is_online(node.multiplayer):
		return
	if not node.multiplayer.is_server():
		return
	for peer_id: int in node.multiplayer.get_peers():
		if NetVisibility.is_peer_ready(node.multiplayer, peer_id):
			send_to(node, peer_id, method, args)


## Host: RPC para um peer (ignora o próprio host e o modo offline).
static func send_to(node: Node, peer_id: int, method: StringName, args: Array = []) -> void:
	if node == null or not node.is_inside_tree() or not NetVisibility.is_online(node.multiplayer):
		return
	if peer_id == node.multiplayer.get_unique_id():
		return
	var call_args: Array = [peer_id, method]
	call_args.append_array(args)
	node.callv(&"rpc_id", call_args)


## Host: `callback(peer_id)` sempre que um peer acaba de carregar o mapa (para lhe mandar o
## estado completo). Sem SessionManager (cena aberta direto, bot) não faz nada.
static func on_peer_ready(node: Node, callback: Callable) -> void:
	var sm: SessionManager = SessionManager.instance
	if sm == null:
		return
	sm.peer_scene_ready.connect(func(peer_id: int, _map_id: String) -> void:
		if is_instance_valid(node) and node.is_inside_tree() and node.multiplayer.is_server():
			callback.call(peer_id))


## Jogador (nó em "players") do peer `peer_id`; em solo (peer 1) cai no jogador local.
static func player_of(tree: SceneTree, peer_id: int) -> Node3D:
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group(&"players"):
		if String(n.name) == str(peer_id):
			return n as Node3D
	if peer_id == 1:
		return tree.get_first_node_in_group(&"player") as Node3D
	return null
