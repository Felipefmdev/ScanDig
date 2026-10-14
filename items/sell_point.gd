class_name SellPoint
extends Node3D

## Ponto de entrega na base: o jogador aproxima-se, carrega E e os itens da mochila
## são entregues ao GameState (o host decide doar ao museu ou vender).

signal items_delivered(count: int, total_value: int)

const GROUP: StringName = &"sell_points"

@export var radius: float = 2.5


func _ready() -> void:
	add_to_group(GROUP)


## Entrega os itens escavados e devolve o valor total. Ferramentas (is_tool) são
## ignoradas: quem chama deve mantê-las na mochila (ver can_deliver).
func deliver(items: Array[CarriedItem]) -> int:
	var total: int = 0
	var count: int = 0
	for c: CarriedItem in items:
		if not can_deliver(c):
			continue
		DiscoveryBridge.report_item_found(c.item, c.final_value)
		total += c.final_value
		count += 1
	items_delivered.emit(count, total)
	return total


static func can_deliver(c: CarriedItem) -> bool:
	return c != null and not c.is_tool() and c.item != null


## Atalho para o Player: verdadeiro se `pos` estiver dentro do raio deste ponto.
func is_in_range(pos: Vector3) -> bool:
	return global_position.distance_to(pos) <= radius
