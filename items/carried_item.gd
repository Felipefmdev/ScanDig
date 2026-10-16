class_name CarriedItem
extends RefCounted

## Um item desenterrado: o que está no chão (ItemPickup) e o que vai na mochila do jogador.

var item: ItemData = null
var final_value: int = 0
var integrity: float = 1.0
var is_rare_variant: bool = false
var is_clean: bool = false
## Ferramentas (ex.: &"detector") ocupam um slot mas não se vendem. Vazio = item escavado.
var tool_id: StringName = &""
var tool_name: String = ""
## Cena opcional usada como visual quando o item está no chão (ItemPickup).
var world_scene: PackedScene = null
## Ferramentas compradas na loja (armas/consumíveis). null para o detetor e itens escavados.
var tool_data: ToolData = null
## Cargas restantes de consumíveis (-1 = infinito).
var charges: int = -1


static func create(p_item: ItemData, p_value: int, p_integrity: float, p_rare: bool, p_clean: bool = false) -> CarriedItem:
	var c: CarriedItem = CarriedItem.new()
	c.item = p_item
	c.final_value = p_value
	c.integrity = p_integrity
	c.is_rare_variant = p_rare
	c.is_clean = p_clean
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


## Formato de rede (contrato #5, bloco C). Só ids e números: nada de recursos ou cenas.
func to_dict() -> Dictionary:
	return {
		"kind": "tool" if is_tool() else "item",
		"item_id": item.id if item != null else "",
		"final_value": final_value,
		"integrity": integrity,
		"rare": is_rare_variant,
		"clean": is_clean,
		"tool_id": String(tool_id),
		"charges": charges,
	}


## Reconstrói um CarriedItem vindo da rede; null se o dicionário for inválido.
## Revalida tudo: o item tem de existir no catálogo e o valor não pode passar do teto do
## GameState; a ferramenta tem de existir (detetor ou res://items/tools/) e as cargas
## não podem passar das iniciais.
static func from_dict(d: Dictionary) -> CarriedItem:
	var kind: Variant = d.get("kind")
	if kind is String and kind == "item":
		return _item_from_dict(d)
	if kind is String and kind == "tool":
		return _tool_from_dict(d)
	return null


static func _item_from_dict(d: Dictionary) -> CarriedItem:
	var item_id: Variant = d.get("item_id")
	var value: Variant = d.get("final_value")
	var integ: Variant = d.get("integrity", 1.0)
	var rare: Variant = d.get("rare", false)
	var clean: Variant = d.get("clean", d.get("is_clean", false))
	if not item_id is String or not _is_safe_id(item_id):
		return null
	if not (value is int or value is float) or not (integ is int or integ is float) or not rare is bool or not clean is bool:
		return null
	var path: String = "res://items/catalog/%s.tres" % item_id
	if not ResourceLoader.exists(path):
		return null
	var data: ItemData = load(path) as ItemData
	if data == null or data.id != item_id:
		return null
	var final: int = int(value)
	if final < 0 or float(integ) < 0.0 or float(integ) > 1.0:
		return null
	if GameState.instance != null and final > GameState.instance.get_max_item_value(data):
		return null
	return create(data, final, float(integ), rare, bool(clean))


static func _tool_from_dict(d: Dictionary) -> CarriedItem:
	var id: Variant = d.get("tool_id")
	var ch: Variant = d.get("charges", -1)
	if not id is String or not _is_safe_id(id) or not (ch is int or ch is float):
		return null
	if id == String(DetectorSpawn.TOOL_ID):
		return create_tool(DetectorSpawn.TOOL_ID, DetectorSpawn.TOOL_NAME, DetectorSpawn.WORLD_MODEL)
	var td: ToolData = null
	if GameState.instance != null:
		td = GameState.instance.get_tool_data(id)
	elif ResourceLoader.exists("res://items/tools/%s.tres" % id):
		td = load("res://items/tools/%s.tres" % id) as ToolData
	if td == null or String(td.id) != id:
		return null
	var c: CarriedItem = create_from_tool_data(td)
	if td.charges >= 0:
		var left: int = int(ch)
		if left < 1 or left > td.charges:
			return null
		c.charges = left
	return c


static func _is_safe_id(id: String) -> bool:
	return not id.is_empty() and id.is_valid_filename() and not id.contains("..") \
		and not id.contains("/") and not id.contains("\\")


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
	var dname: String = ("✦ " + item.display_name) if is_rare_variant else item.display_name
	if is_clean:
		return "✨ " + dname
	return dname
