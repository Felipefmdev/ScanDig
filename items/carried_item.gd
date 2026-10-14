class_name CarriedItem
extends RefCounted

## Um item desenterrado: o que está no chão (ItemPickup) e o que vai na mochila do jogador.

var item: ItemData = null
var final_value: int = 0
var integrity: float = 1.0
var is_rare_variant: bool = false
## Ferramentas (ex.: &"detector") ocupam um slot mas não se vendem. Vazio = item escavado.
var tool_id: StringName = &""
var tool_name: String = ""
## Cena opcional usada como visual quando o item está no chão (ItemPickup).
var world_scene: PackedScene = null
## Ferramentas compradas na loja (armas/consumíveis). null para o detetor e itens escavados.
var tool_data: ToolData = null
## Cargas restantes de consumíveis (-1 = infinito).
var charges: int = -1


static func create(p_item: ItemData, p_value: int, p_integrity: float, p_rare: bool) -> CarriedItem:
	var c: CarriedItem = CarriedItem.new()
	c.item = p_item
	c.final_value = p_value
	c.integrity = p_integrity
	c.is_rare_variant = p_rare
	return c


static func create_tool(p_tool_id: StringName, p_name: String, p_world_scene: PackedScene = null) -> CarriedItem:
	var c: CarriedItem = CarriedItem.new()
	c.tool_id = p_tool_id
	c.tool_name = p_name
	c.world_scene = p_world_scene
	return c


static func create_from_tool_data(td: ToolData) -> CarriedItem:
	var c: CarriedItem = create_tool(td.id, td.display_name, td.world_scene)
	c.tool_data = td
	c.charges = td.charges
	return c


## Gasta uma carga. Devolve true se o item acabou (o chamador remove-o da mochila).
func consume_charge() -> bool:
	if charges < 0:
		return false
	charges -= 1
	return charges <= 0


func is_tool() -> bool:
	return tool_id != &""


func get_display_name() -> String:
	if is_tool():
		return tool_name if charges < 0 else "%s (x%d)" % [tool_name, charges]
	if item == null:
		return "Artefato Misterioso"
	return ("✦ " + item.display_name) if is_rare_variant else item.display_name
