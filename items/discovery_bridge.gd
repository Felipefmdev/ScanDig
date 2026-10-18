class_name DiscoveryBridge
extends RefCounted

## Ponto de ligação entre gameplay (Dev A) e core (Dev B).
## Mantido em res://items/ (pasta partilhada) para que nenhum lado edite a área do outro.


## `is_rare`: variante rara do achado (#111); o GameState só a registra se a peça for doada.
static func report_item_found(item: ItemData, final_value: int, is_rare: bool = false) -> void:
	if item == null or item.id.is_empty():
		return

	var state: GameState = GameState.instance
	if state == null:
		# Cena sem GameState (ex.: test_sandbox): apenas ignora.
		return

	# O host decide: inédito -> doado ao museu (recompensa parcial); repetido -> vendido.
	state.request_report_discovery(item.id, final_value, is_rare)
