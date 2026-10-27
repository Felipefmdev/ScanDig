class_name ShopOffer
extends Node3D

## Um produto exposto na banca da base. O jogador olha para ele e carrega E (ver Player).
## O dinheiro vem do GameState (Dev B): a compra é validada e debitada no host
## (request_world_item / world_item_result), por isso funciona offline e em coop.

signal purchased(tool_data: ToolData)

const GROUP: StringName = &"shop_offers"
## Tempo máximo à espera da autorização e entrega na mochila.
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
static var _request_sequence: int = 0
var _pending: bool = false
## Um timeout conserva a identidade da compra para repetir sem novo débito.
var _intent_request: int = 0


func host_can_purchase(peer_id: int) -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not multiplayer.is_server() or not is_multiplayer_authority() or multiplayer.get_remote_sender_id() != 0:
		return false
	var scene: Node = get_tree().current_scene
	var session: SessionManager = SessionManager.instance
	if scene == null or not scene.is_ancestor_of(self) or session == null or not session.is_peer_scene_ready(peer_id):
		return false
	if session.get_current_map() == null or not SessionManager.MAP_ORDER.has(session.get_current_map().id) or str(session.get_rocket_transition()["phase"]) != "IDLE":
		return false
	var actor: Player = HostSync.player_of(get_tree(), peer_id) as Player
	if actor == null or not actor.is_node_ready() or actor.is_queued_for_deletion() or not scene.is_ancestor_of(actor) or actor.multiplayer != multiplayer:
		return false
	if String(actor.name) != str(peer_id) or actor.get_multiplayer_authority() != peer_id or not actor.is_alive() or actor.is_downed:
		return false
	if actor.global_position.distance_to(global_position) > 2.5 or not is_instance_valid(actor.head):
		return false
	var excluded: Array[RID] = [actor.get_rid()]
	for child: Node in actor.find_children("*", "CollisionObject3D", true, false):
		excluded.append((child as CollisionObject3D).get_rid())
	for child: Node in find_children("*", "CollisionObject3D", true, false):
		excluded.append((child as CollisionObject3D).get_rid())
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(actor.head.global_position, global_position + Vector3.UP * .15, 1, excluded)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _ready() -> void:
	add_to_group(GROUP)
	if tool_data == null:
		return
	if tool_data.world_scene != null:
		add_child(tool_data.world_scene.instantiate())
	else:
		# Caixa só quando não há modelo (#128: antes ficava órfã nas ofertas com world_scene).
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.22, 0.22, 0.22)
		mesh.mesh = box
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = tool_data.color
		mesh.material_override = mat
		mesh.position.y = 0.15
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


## Tenta comprar pelo host (GameState.request_world_item). É uma corrotina: use
## `await offer.try_buy(inventory)`. Devolve {"ok": bool, "message": String, "carried": CarriedItem}.
## O broker do core entrega uma vez; repetir após timeout conserva o pedido pago.
func try_buy(inventory: Inventory) -> Dictionary:
	var result: Dictionary = {"ok": false, "message": "", "carried": null}
	if tool_data == null:
		result["message"] = "Produto indisponível."
		return result
	if _intent_request == 0 and inventory != null and inventory.is_full():
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
	if _intent_request == 0:
		_request_sequence += 1
		_intent_request = _request_sequence
	var request_id: int = _intent_request
	var on_result: Callable = func(received_id: int, id: String, success: bool, message: String) -> void:
		if received_id == request_id and id == item_id and reply.is_empty():
			reply["success"] = success
			reply["message"] = message
	# Liga antes do pedido: no host/offline a resposta é emitida dentro da própria chamada.
	state.world_item_result.connect(on_result)
	state.request_world_item(item_id, get_path(), request_id)
	var deadline: int = Time.get_ticks_msec() + int(PURCHASE_TIMEOUT * 1000.0)
	while (reply.is_empty() or (bool(reply.get("success", false)) and not state.is_world_item_delivered(request_id))) and Time.get_ticks_msec() < deadline and is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree == null:
			break
		await tree.process_frame
		if not is_inside_tree():
			break
	if is_instance_valid(state) and state.world_item_result.is_connected(on_result):
		state.world_item_result.disconnect(on_result)
	_pending = false
	if not is_inside_tree():
		result["message"] = "Cancelado."
		return result

	if reply.is_empty() or (bool(reply.get("success", false)) and not state.is_world_item_delivered(request_id)):
		result["message"] = "Sem resposta do anfitrião. Tente de novo."
		return result
	_intent_request = 0
	result["message"] = reply["message"]
	if not reply["success"]:
		return result
	result["ok"] = true
	# O broker entrega na mochila; o Player não deve adicionar outro item.
	purchased.emit(tool_data)
	return result
