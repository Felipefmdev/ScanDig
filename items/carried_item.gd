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


func is_tool() -> bool:
	return tool_id != &""


func get_display_name() -> String:
	if is_tool():
		return tool_name
	if item == null:
		return "Artefato Misterioso"
	return ("✦ " + item.display_name) if is_rare_variant else item.display_name
