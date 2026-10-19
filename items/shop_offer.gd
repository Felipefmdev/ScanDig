class_name ShopOffer
extends Node3D

## Um produto exposto na banca da base. O jogador olha para ele e carrega E (ver Player).
## O dinheiro vem do GameState (Dev B): a compra é validada e debitada no host
## (request_purchase_item / item_purchase_result), por isso funciona offline e em coop.

signal purchased(tool_data: ToolData)

const GROUP: StringName = &"shop_offers"
## Tempo máximo à espera de item_purchase_result (igual à aba Loja).
const PURCHASE_TIMEOUT: float = 5.0
## Rótulo 3D (#122): fonte grande com pixel pequeno (nítido de perto e legível a uns metros) e,
## entre vizinhos da mesma banca, alturas alternadas para os rótulos não se cruzarem
## quando a banca é vista de lado. Com a altura alternada, cada rótulo pode ser mais largo que o
## vão entre ofertas (0,9 m): o nome cabe numa linha (nome + preço) e o alto fica abaixo da placa
## "LOJA" (2,1 m).
const LABEL_HEIGHT: float = 0.45
const LABEL_STAGGER: float = 0.32
const LABEL_FONT_SIZE: int = 48
const LABEL_PIXEL_SIZE: float = 0.0022
const LABEL_WIDTH_M: float = 1.4

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
	# Texto já traduzido aqui e refeito na troca de idioma (_notification).
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.text = _label_text()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = LABEL_HEIGHT + (LABEL_STAGGER if _stall_order() % 2 == 1 else 0.0)
	_label.font_size = LABEL_FONT_SIZE
	# Só nomes muito longos quebram (largura LABEL_WIDTH_M); a altura alternada separa os vizinhos.
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.width = LABEL_WIDTH_M / LABEL_PIXEL_SIZE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.pixel_size = LABEL_PIXEL_SIZE
	_label.outline_size = 14
	_label.outline_modulate = UiPalette.INK
	add_child(_label)


func _label_text() -> String:
	return "%s\n%s" % [tr(tool_data.display_name), MoneyFormat.money(tool_data.price)]


## Idioma trocado ao vivo (#131): o rótulo montado por código se refaz.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _label != null and tool_data != null:
		_label.text = _label_text()


## Posição desta oferta entre as ShopOffer irmãs (a ordem na banca).
func _stall_order() -> int:
	var parent: Node = get_parent()
	if parent == null:
		return 0
	var order: int = 0
	for sibling: Node in parent.get_children():
		if sibling == self:
			return order
		if sibling is ShopOffer:
			order += 1
	return order


func set_highlighted(on: bool) -> void:
	if _label != null:
		_label.modulate = Color(1.0, 0.9, 0.3) if on else Color.WHITE


func get_prompt() -> String:
	if tool_data == null:
		return ""
	return tr("[E] Comprar %s (%s)") % [tr(tool_data.display_name), MoneyFormat.money(tool_data.price)]


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
		var tree: SceneTree = get_tree()
		if tree == null:
			break
		await tree.process_frame
		if not is_inside_tree():
			break
	if is_instance_valid(state) and state.item_purchase_result.is_connected(on_result):
		state.item_purchase_result.disconnect(on_result)
	_pending = false
	if not is_inside_tree():
		result["message"] = "Cancelado."
		return result

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
