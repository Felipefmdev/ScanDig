class_name PickupsRoot
extends Node3D

## Nó `Pickups` dos mapas (contrato #5, bloco E): todos os itens no chão (ItemPickup)
## nascem aqui por um MultiplayerSpawner filho (criado em _ready) com spawn_function e os
## dados {"n", "carried": CarriedItem.to_dict(), "pos", "impulse"}.
## - Só o host cria itens. Num cliente, largar (Q, morte, mochila cheia) vira request_drop.
## - Apanhar num cliente é request_pickup: o host confere se o item ainda existe e a
##   distância, tira-o do mundo (o desaparecimento replica) e manda _grant_item ao dono.
##   Se dois pedirem ao mesmo tempo, leva quem chegar primeiro; o outro recebe _pickup_denied.
## ItemPickup.spawn() encontra este nó sozinho (grupo GROUP), por isso quem cria itens
## (spots, morte, gaivota, chefe, detetor) não precisa de saber da rede.

const GROUP: StringName = &"pickups_root"
## Host: distância máxima jogador→item aceite num request_pickup (interact_range 2.5 + folga).
const MAX_PICKUP_DISTANCE: float = 4.0
## Host: um request_drop só pode largar o item até esta distância do jogador que pede.
const MAX_DROP_DISTANCE: float = 4.0

var _spawner: MultiplayerSpawner = null
var _counter: int = 0


static func find(tree: SceneTree) -> PickupsRoot:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as PickupsRoot


func _ready() -> void:
	add_to_group(GROUP)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "PickupNetSpawner"
	_spawner.spawn_path = NodePath("..")
	_spawner.spawn_function = _create_pickup
	add_child(_spawner)


## Cria um item no chão (posição global). Host: devolve o ItemPickup. Cliente: pede ao
## host e devolve null (o item aparece quando o spawn chegar).
func drop(carried: CarriedItem, pos: Vector3, impulse: Vector3 = Vector3.ZERO) -> ItemPickup:
	if carried == null:
		return null
	if multiplayer.is_server():
		return _spawn_item(carried.to_dict(), pos, impulse)
	request_drop.rpc_id(1, carried.to_dict(), pos, impulse)
	return null


## Apanhar `pickup` para a mochila de `player` (jogador local).
## Host: tira o item já e devolve-o. Cliente: pede ao host e devolve null; a resposta
## chega ao Player por receive_granted_item / on_pickup_denied.
func take(pickup: ItemPickup) -> CarriedItem:
	if pickup == null or not is_instance_valid(pickup) or pickup.carried == null:
		return null
	if multiplayer.is_server():
		return pickup.take()
	request_pickup.rpc_id(1, String(pickup.name))
	return null


func _spawn_item(dict: Dictionary, pos: Vector3, impulse: Vector3) -> ItemPickup:
	_counter += 1
	return _spawner.spawn({"n": _counter, "carried": dict, "pos": to_local(pos), "impulse": impulse}) as ItemPickup


## spawn_function: corre no host e em cada cliente com os mesmos dados.
func _create_pickup(data: Variant) -> Node:
	var d: Dictionary = data as Dictionary
	var raw: Variant = d.get("carried", {})
	var carried: CarriedItem = CarriedItem.from_dict(raw if raw is Dictionary else {})
	var pickup: ItemPickup = ItemPickup.create(carried)
	pickup.name = "Pickup%d" % int(d.get("n", 0))
	pickup.setup_network(d.get("pos", Vector3.ZERO), d.get("impulse", Vector3.ZERO))
	return pickup


# --- Pedidos (cliente → host) -------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func request_pickup(pickup_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var pickup: ItemPickup = get_node_or_null(NodePath(pickup_name)) as ItemPickup
	var who: Node3D = _player_of(sender)
	if pickup == null or pickup.carried == null or who == null \
			or who.global_position.distance_to(pickup.global_position) > MAX_PICKUP_DISTANCE:
		_pickup_denied.rpc_id(sender)
		return
	var c: CarriedItem = pickup.take()
	_grant_item.rpc_id(sender, c.to_dict())


@rpc("any_peer", "call_remote", "reliable")
func request_drop(dict: Dictionary, pos: Vector3, impulse: Vector3) -> void:
	if not multiplayer.is_server():
		return
	if CarriedItem.from_dict(dict) == null:
		return
	var who: Node3D = _player_of(multiplayer.get_remote_sender_id())
	if who == null:
		return
	var offset: Vector3 = pos - who.global_position
	if offset.length() > MAX_DROP_DISTANCE:
		pos = who.global_position + offset.normalized() * MAX_DROP_DISTANCE
	_spawn_item(dict, pos, impulse.limit_length(6.0))


# --- Respostas (host → cliente) ----------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _grant_item(dict: Dictionary) -> void:
	var me: Node = get_tree().get_first_node_in_group(Player.LOCAL_GROUP)
	if me != null and me.has_method("receive_granted_item"):
		me.call("receive_granted_item", CarriedItem.from_dict(dict))


@rpc("authority", "call_remote", "reliable")
func _pickup_denied() -> void:
	var me: Node = get_tree().get_first_node_in_group(Player.LOCAL_GROUP)
	if me != null and me.has_method("on_pickup_denied"):
		me.call("on_pickup_denied")


func _player_of(peer_id: int) -> Node3D:
	for n: Node in get_tree().get_nodes_in_group(Player.ALL_GROUP):
		if String(n.name) == str(peer_id):
			return n as Node3D
	return null
