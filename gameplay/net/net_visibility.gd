class_name NetVisibility
extends RefCounted

## Visibilidade da replicação para nós do mundo que o host controla (spots, itens no chão):
## um peer só recebe o spawn/sync depois de ter o mapa carregado (CoreSession
## `peer_scene_ready`), senão aparece "Node not found" a meio do carregamento.
## Os synchronizers registados aqui são reavaliados com `refresh()` quando um peer fica
## pronto (o PlayersRoot chama-o no host).

const GROUP: StringName = &"net_ready_syncs"


## Liga o filtro "só peers prontos" a um MultiplayerSynchronizer.
static func watch(sync: MultiplayerSynchronizer) -> void:
	sync.add_visibility_filter(func(peer_id: int) -> bool: return is_peer_ready(sync.multiplayer, peer_id))
	sync.add_to_group(GROUP)


## Host: o peer já carregou o mapa? Fora de uma expedição (cena aberta direto, bot,
## testes) não há handshake de cena e conta como pronto.
static func is_peer_ready(mp: MultiplayerAPI, peer_id: int) -> bool:
	if mp == null or not mp.is_server():
		return peer_id == 1
	var sm: SessionManager = SessionManager.instance
	if sm == null or not sm.is_in_expedition():
		return true
	return sm.is_peer_scene_ready(peer_id)


## Reavalia todos os synchronizers registados (ex.: um peer acabou de carregar o mapa).
static func refresh(tree: SceneTree) -> void:
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group(GROUP):
		var sync: MultiplayerSynchronizer = n as MultiplayerSynchronizer
		if sync != null and sync.is_inside_tree():
			sync.update_visibility()


## Há uma ligação real (não offline)? Em solo os pedidos ao host são chamadas diretas.
static func is_online(mp: MultiplayerAPI) -> bool:
	return mp != null and mp.multiplayer_peer != null and not (mp.multiplayer_peer is OfflineMultiplayerPeer)
