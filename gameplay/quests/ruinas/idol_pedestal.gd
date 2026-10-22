extends FlagInteractable

## The unique reward is shown for the ritual, then kept for the museum.
## Inventories belong to their player; ask that owner instead of inspecting the
## host's empty remote inventory replica. Quest/proximity/state remain host-owned.
const IDOL: String = "idolo_jade"
const MISSING_LINE: String = "Traga o Ídolo de Jade na mochila para despertar o pedestal."
const LOCKED_LINE: String = "Ajude Inês a abrir a câmara selada antes de despertar o pedestal."
var _requests: Dictionary = {}
var _next_nonce: int = 0
var _confirmed_peer: int = 0

func _on_interact(peer_id: int) -> void:
	if state == STATE_USED:
		return
	if not QuestRewards.is_quest_completed("ines_camara"):
		say_to(peer_id, LOCKED_LINE)
		return
	if peer_id == HostSync.local_peer(self):
		if not _local_has_idol():
			say_to(peer_id, MISSING_LINE)
			return
	elif _confirmed_peer != peer_id:
		_next_nonce += 1
		_requests[peer_id] = {"nonce":_next_nonce,"expires":Time.get_ticks_msec() + 3000}
		HostSync.send_to(self, peer_id, &"_rpc_check_idol", [_next_nonce])
		return
	super._on_interact(peer_id)

func _local_has_idol() -> bool:
	var player: Player = get_tree().get_first_node_in_group(Player.LOCAL_GROUP) as Player
	if player == null or player.inventory == null:
		return false
	for item: CarriedItem in player.inventory.slots:
		if item != null and item.item != null and item.item.id == IDOL:
			return true
	return false

@rpc("authority", "call_remote", "reliable")
func _rpc_check_idol(nonce: int) -> void:
	_rpc_idol_answer.rpc_id(1, nonce, _local_has_idol())

@rpc("any_peer", "call_remote", "reliable")
func _rpc_idol_answer(nonce: int, has_idol: bool) -> void:
	if not HostSync.is_host(self):
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	var request: Dictionary = _requests.get(peer_id, {})
	if request.is_empty() or int(request["nonce"]) != nonce:
		return
	_requests.erase(peer_id)
	if Time.get_ticks_msec() > int(request["expires"]):
		return
	if not has_idol:
		say_to(peer_id, MISSING_LINE)
		return
	_finish_request.call_deferred(peer_id)

func _finish_request(peer_id: int) -> void:
	# Recheck range/active state after the owner's round trip.
	var player: Node3D = HostSync.player_of(get_tree(), peer_id)
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	_confirmed_peer = peer_id
	_host_interact(peer_id)
	_confirmed_peer = 0
