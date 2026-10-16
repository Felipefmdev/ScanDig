class_name ShopOffer
extends Node3D

## Um produto exposto na banca da base. O jogador olha para ele e carrega E (ver Player).
## O dinheiro vem do GameState (Dev B): a compra é validada e debitada no host
## (request_purchase_item / item_purchase_result), por isso funciona offline e em coop.

signal purchased(tool_data: ToolData)

const GROUP: StringName = &"shop_offers"
## Tempo máximo à espera de item_purchase_result (igual à aba Loja).
const PURCHASE_TIMEOUT: float = 5.0

@export var tool_data: ToolData = null

var _label: Label3D = null
var _pending: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	if tool_data == null:
		return
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.22, 0.22, 0.22)
	mesh.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = tool_data.color
	mesh.material_override = mat
	mesh.position.y = 0.15
	if tool_data.world_scene != null:
		add_child(tool_data.world_scene.instantiate())
	else:
		add_child(mesh)

	_label = Label3D.new()
	_label.text = "%s\n%s" % [tool_data.display_name, MoneyFormat.money(tool_data.price)]
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 0.55
	_label.font_size = 24
	# Quebra nomes longos em várias linhas (largura ~0,8 m) para não colidir com o vizinho.
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.width = 200.0
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.pixel_size = 0.004
	_label.outline_size = 6
	_label.outline_modulate = UiPalette.INK
	add_child(_label)


func set_highlighted(on: bool) -> void:
	if _label != null:
		_label.modulate = Color(1.0, 0.9, 0.3) if on else Color.WHITE


func get_prompt() -> String:
	if tool_data == null:
		return ""
	return "[E] Comprar %s (%s)" % [tool_data.display_name, MoneyFormat.money(tool_data.price)]


## Tenta comprar pelo host (GameState.request_purchase_item). É uma corrotina: use
## `await offer.try_buy(inventory)`. Devolve {"ok": bool, "message": String, "carried": CarriedItem}.
## A mochila é verificada ANTES do pedido (o core não sabe de mochilas); o débito é só no host.
func try_buy(inventory: Inventory) -> Dictionary:
	var result: Dictionary = {"ok": false, "message": "", "carried": null}
	if tool_data == null:
		result["message"] = "Produto indisponível."
		return result
	if inventory != null and inventory.is_full():
		result["message"] = "Mochila cheia! Liberte um slot antes de comprar."
		return result
	var state: GameState = GameState.instance
	if state == null:
		result["message"] = "Loja fechada (sem GameState nesta cena)."
		return result
	if _pending:
		result["message"] = "Compra em curso..."
		return result

	_pending = true
	var item_id: String = String(tool_data.id)
	var reply: Dictionary = {}
	var on_result: Callable = func(id: String, success: bool, message: String) -> void:
		if id == item_id and reply.is_empty():
			reply["success"] = success
			reply["message"] = message
	# Liga antes do pedido: no host/offline a resposta é emitida dentro da própria chamada.
	state.item_purchase_result.connect(on_result)
	state.request_purchase_item(item_id)
	var deadline: int = Time.get_ticks_msec() + int(PURCHASE_TIMEOUT * 1000.0)
	while reply.is_empty() and Time.get_ticks_msec() < deadline and is_inside_tree():
		await get_tree().process_frame
	if is_instance_valid(state) and state.item_purchase_result.is_connected(on_result):
		state.item_purchase_result.disconnect(on_result)
	_pending = false

	if reply.is_empty():
		result["message"] = "Sem resposta do anfitrião. Tente de novo."
		return result
	result["message"] = reply["message"]
	if not reply["success"]:
		return result
	result["ok"] = true
	result["carried"] = CarriedItem.create_from_tool_data(tool_data)
	purchased.emit(tool_data)
	return result
