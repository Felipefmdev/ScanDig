class_name DiscoveryBridge
extends RefCounted

## Ponto de ligação entre gameplay (Dev A) e core (Dev B).
## Mantido em res://items/ (pasta partilhada) para que nenhum lado edite a área do outro.


static func report_item_found(item: ItemData, final_value: int) -> void:
	if item == null or item.id.is_empty():
		return

	var state: GameState = GameState.instance
	if state == null:
		# Cena sem GameState (ex.: test_sandbox): apenas ignora.
		return

	if state.multiplayer.has_multiplayer_peer():
		state.register_museum_item.rpc(item.id)
		state.sell_found_item.rpc(item.id, final_value)
	else:
		state.register_museum_item(item.id)
		state.sell_found_item(item.id, final_value)
