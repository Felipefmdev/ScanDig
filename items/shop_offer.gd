class_name ShopOffer
extends Node3D

## Um produto exposto na banca da base. O jogador olha para ele e carrega E (ver Player).
## O dinheiro vem do GameState (Dev B). Enquanto o GameState não tiver uma compra genérica
## (request_purchase_item), a compra só é feita localmente e apenas fora de uma partida online.

signal purchased(tool_data: ToolData)

const GROUP: StringName = &"shop_offers"

@export var tool_data: ToolData = null

var _label: Label3D = null


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
	_label.text = "%s\nR$ %d" % [tool_data.display_name, tool_data.price]
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 0.55
	_label.font_size = 24
	# Quebra nomes longos em várias linhas (largura ~0,8 m) para não colidir com o vizinho.
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.width = 200.0
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.pixel_size = 0.004
	_label.outline_size = 6
	add_child(_label)


func set_highlighted(on: bool) -> void:
	if _label != null:
		_label.modulate = Color(1.0, 0.9, 0.3) if on else Color.WHITE


func get_prompt() -> String:
	if tool_data == null:
		return ""
	return "[E] Comprar %s (R$ %d)" % [tool_data.display_name, tool_data.price]


## Tenta comprar. Devolve {"ok": bool, "message": String, "carried": CarriedItem}.
## O chamador garante que a mochila tem espaço ANTES de chamar.
func try_buy() -> Dictionary:
	var result: Dictionary = {"ok": false, "message": "", "carried": null}
	if tool_data == null:
		result["message"] = "Produto indisponível."
		return result

	var state: GameState = GameState.instance
	if state == null:
		result["message"] = "Loja fechada (sem GameState nesta cena)."
		return result

	# TODO(Dev B): trocar por uma compra validada no host (request_purchase_item + sinal de
	# resultado). Até lá, só se compra fora de uma partida online.
	# O peer por omissão (OfflineMultiplayerPeer) conta como CONNECTED: só bloqueia rede real.
	var peer: MultiplayerPeer = state.multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer) and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		result["message"] = "Compras em coop ainda não suportadas."
		return result

	if state.team_money < tool_data.price:
		result["message"] = "Saldo insuficiente (R$ %d)." % tool_data.price
		return result

	# Provisório (só offline): debita localmente.
	state.team_money -= tool_data.price
	state.money_changed.emit(state.team_money)
	result["ok"] = true
	result["message"] = "Comprado: %s" % tool_data.display_name
	result["carried"] = CarriedItem.create_from_tool_data(tool_data)
	purchased.emit(tool_data)
	return result
