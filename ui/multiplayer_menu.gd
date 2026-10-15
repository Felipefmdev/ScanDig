class_name MultiplayerMenu
extends Control

## Menu de gerenciamento de sessão de rede (Nome / Host / Join / Lista de Jogadores).
## As APIs da #28 (nomes, UPnP, connection_error) são acessadas de forma dinâmica:
## com um core antigo o menu funciona como antes.

@onready var name_line_edit: LineEdit = _resolve_node("NameLineEdit", "PanelContainer/MarginContainer/VBoxContainer/NameLineEdit") as LineEdit
@onready var host_button: Button = _resolve_node("HostButton", "PanelContainer/MarginContainer/VBoxContainer/HostButton") as Button
@onready var join_button: Button = _resolve_node("JoinButton", "PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/JoinButton") as Button
@onready var ip_line_edit: LineEdit = _resolve_node("IPLineEdit", "PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/IPLineEdit") as LineEdit
@onready var leave_button: Button = _resolve_node("LeaveButton", "PanelContainer/MarginContainer/VBoxContainer/LeaveButton") as Button
@onready var status_label: Label = _resolve_node("StatusLabel", "PanelContainer/MarginContainer/VBoxContainer/StatusLabel") as Label
@onready var share_label: Label = _resolve_node("ShareLabel", "PanelContainer/MarginContainer/VBoxContainer/ShareLabel") as Label
@onready var copy_ip_button: Button = _resolve_node("CopyIPButton", "PanelContainer/MarginContainer/VBoxContainer/CopyIPButton") as Button
@onready var players_list: ItemList = _resolve_node("PlayersList", "PanelContainer/MarginContainer/VBoxContainer/PlayersList") as ItemList

var _net_manager: NetworkManager = null


func _resolve_node(unique_id: String, rel_path: String) -> Node:
	if has_node("%" + unique_id):
		return get_node("%" + unique_id)
	if has_node(rel_path):
		return get_node(rel_path)
	return find_child(unique_id, true, false)


func _ready() -> void:
	if ip_line_edit != null and ip_line_edit.text.is_empty():
		ip_line_edit.text = "127.0.0.1"

	if host_button != null:
		host_button.pressed.connect(_on_host_pressed)
	if join_button != null:
		join_button.pressed.connect(_on_join_pressed)
	if leave_button != null:
		leave_button.pressed.connect(_on_leave_pressed)
	if copy_ip_button != null:
		copy_ip_button.pressed.connect(_on_copy_ip_pressed)

	_resolve_network_manager()
	_setup_name_field()
	_hide_share()
	_refresh_session_buttons()


func _resolve_network_manager() -> void:
	if NetworkManager.instance != null:
		_net_manager = NetworkManager.instance
	elif get_tree().root.has_node("NetworkManager"):
		_net_manager = get_tree().root.get_node("NetworkManager") as NetworkManager

	if _net_manager != null:
		if not _net_manager.player_connected.is_connected(_on_player_connected):
			_net_manager.player_connected.connect(_on_player_connected)
		if not _net_manager.player_disconnected.is_connected(_on_player_disconnected):
			_net_manager.player_disconnected.connect(_on_player_disconnected)
		if not _net_manager.connection_succeeded.is_connected(_on_connection_succeeded):
			_net_manager.connection_succeeded.connect(_on_connection_succeeded)
		if not _net_manager.connection_failed.is_connected(_on_connection_failed):
			_net_manager.connection_failed.connect(_on_connection_failed)
		if not _net_manager.server_disconnected.is_connected(_on_server_disconnected):
			_net_manager.server_disconnected.connect(_on_server_disconnected)
		# Sinais que podem não existir em um core antigo.
		_connect_net_signal(&"session_left", _on_session_left)
		_connect_net_signal(&"players_changed", _refresh_players_list)
		_connect_net_signal(&"connection_error", _on_connection_error)
		_connect_net_signal(&"upnp_finished", _on_upnp_finished)
		_refresh_players_list()


func _connect_net_signal(signal_name: StringName, callable: Callable) -> void:
	if _net_manager.has_signal(signal_name) and not _net_manager.is_connected(signal_name, callable):
		_net_manager.connect(signal_name, callable)


## Com connection_error, as mensagens de falha vêm do core e têm a palavra final.
func _has_error_messages() -> bool:
	return _net_manager != null and _net_manager.has_signal(&"connection_error")


# --- Nome do jogador ------------------------------------------------------------

func _setup_name_field() -> void:
	if name_line_edit == null:
		return
	if _net_manager == null or not _net_manager.has_method(&"set_local_player_name"):
		# Core sem nomes: o campo não teria efeito.
		name_line_edit.visible = false
		return
	name_line_edit.text = _get_local_player_name()
	name_line_edit.text_submitted.connect(_apply_player_name.unbind(1))
	name_line_edit.focus_exited.connect(_apply_player_name)


func _get_local_player_name() -> String:
	if _net_manager != null and &"local_player_name" in _net_manager:
		return str(_net_manager.get(&"local_player_name"))
	return ""


## Grava o nome (persistido) e reescreve o campo com o valor sanitizado pelo core.
func _apply_player_name() -> void:
	if name_line_edit == null or _net_manager == null or not _net_manager.has_method(&"set_local_player_name"):
		return
	_net_manager.call(&"set_local_player_name", name_line_edit.text)
	name_line_edit.text = _get_local_player_name()


# --- Hospedar / entrar / sair ----------------------------------------------------

func _on_host_pressed() -> void:
	if _net_manager == null:
		_set_status("Erro: NetworkManager não encontrado.")
		return

	var err: Error = _net_manager.host_game()
	if err == OK:
		_refresh_players_list()
		if _net_manager.has_method(&"start_upnp"):
			_set_status("Hospedando na porta %d. Abrindo a porta no roteador (UPnP)..." % NetworkManager.DEFAULT_PORT)
			_net_manager.call(&"start_upnp")
		else:
			_set_status("Servidor iniciado (Host ativo).")
	elif not _has_error_messages():
		_set_status("Falha ao iniciar host: erro %d" % err)
	_refresh_session_buttons()


func _on_join_pressed() -> void:
	if _net_manager == null:
		_set_status("Erro: NetworkManager não encontrado.")
		return

	var ip: String = ip_line_edit.text.strip_edges() if ip_line_edit != null else "127.0.0.1"
	if ip.is_empty():
		ip = "127.0.0.1"

	_set_status("Conectando a %s..." % ip)
	var err: Error = _net_manager.join_game(ip)
	if err != OK and not _has_error_messages():
		_set_status("Erro ao tentar conectar: erro %d" % err)
	_refresh_session_buttons()


func _on_leave_pressed() -> void:
	# Sem confirmação: no lobby não há expedição a perder. Também cancela um "Conectando...".
	if _net_manager == null:
		_set_status("Erro: NetworkManager não encontrado.")
		return
	_net_manager.disconnect_game()
	_hide_share()
	_refresh_players_list()
	_refresh_session_buttons()


# --- IP para compartilhar (UPnP) ------------------------------------------------

func _on_upnp_finished(success: bool, public_ip: String, message: String) -> void:
	_set_status(message)
	var local_addresses: Array[String] = _get_local_addresses()
	var local_text: String = "Na mesma rede: %s" % ", ".join(local_addresses) if not local_addresses.is_empty() else "Sem IP de rede local."
	if share_label != null:
		share_label.text = "IP para os amigos: %s\n%s" % [public_ip, local_text] if success else local_text
		share_label.visible = true
	if copy_ip_button != null:
		copy_ip_button.visible = success


func _get_local_addresses() -> Array[String]:
	var result: Array[String] = []
	if _net_manager != null and _net_manager.has_method(&"get_local_addresses"):
		var raw: Variant = _net_manager.call(&"get_local_addresses")
		if raw is Array:
			for address: Variant in raw:
				result.append(str(address))
	return result


func _on_copy_ip_pressed() -> void:
	if _net_manager == null or not &"public_ip" in _net_manager:
		return
	DisplayServer.clipboard_set(str(_net_manager.get(&"public_ip")))
	_set_status("IP copiado!")


func _hide_share() -> void:
	if share_label != null:
		share_label.visible = false
	if copy_ip_button != null:
		copy_ip_button.visible = false


# --- Sinais do NetworkManager ---------------------------------------------------

func _on_player_connected(peer_id: int) -> void:
	_set_status("Jogador conectado: Peer %d" % peer_id)
	_refresh_players_list()


func _on_player_disconnected(peer_id: int) -> void:
	_set_status("Jogador desconectado: Peer %d" % peer_id)
	_refresh_players_list()


func _on_connection_succeeded() -> void:
	_set_status("Conectado com sucesso ao servidor!")
	_refresh_players_list()
	_refresh_session_buttons()


func _on_connection_failed() -> void:
	# Com core novo, a mensagem vem do connection_error (antes ou depois deste sinal).
	if not _has_error_messages():
		_set_status("Falha na conexão com o servidor.")
	_hide_share()
	_refresh_players_list()
	_refresh_session_buttons()


func _on_connection_error(message: String) -> void:
	_set_status(message)
	_refresh_session_buttons()


func _on_server_disconnected() -> void:
	_set_status("Servidor foi desconectado.")
	_hide_share()
	_refresh_players_list()
	_refresh_session_buttons()


func _on_session_left(was_host: bool) -> void:
	_set_status("Você encerrou a sessão (host)." if was_host else "Você saiu da sessão.")
	_hide_share()
	_refresh_players_list()
	_refresh_session_buttons()


## Mesmo critério de GameState._is_online() (privado).
func _is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


## Com sessão aberta (ou conectando), só "Sair" fica disponível; offline, só Host/Join.
func _refresh_session_buttons() -> void:
	var in_session: bool = _is_online() or (_net_manager != null and _net_manager.enet_peer != null)
	if leave_button != null:
		leave_button.visible = in_session
	if host_button != null:
		host_button.disabled = in_session
	if join_button != null:
		join_button.disabled = in_session
	if ip_line_edit != null:
		ip_line_edit.editable = not in_session


func _refresh_players_list() -> void:
	if players_list == null:
		return

	players_list.clear()
	if _net_manager == null:
		return

	if not _net_manager.has_method(&"get_player_name"):
		# Core antigo: linha com o id do peer.
		for peer_id in _net_manager.connected_players:
			var player_info: Dictionary = _net_manager.connected_players[peer_id]
			var player_name: String = str(player_info.get("name", "Jogador"))
			players_list.add_item("Peer ID %s: %s" % [str(peer_id), player_name])
		return

	var ids: Array[int] = []
	for peer_id: Variant in _net_manager.connected_players:
		ids.append(int(peer_id))
	# Host primeiro, depois por id.
	ids.sort_custom(func(a: int, b: int) -> bool:
		if a == 1 or b == 1:
			return a == 1 and b != 1
		return a < b
	)
	var my_id: int = multiplayer.get_unique_id()
	for peer_id: int in ids:
		var line: String = str(_net_manager.call(&"get_player_name", peer_id))
		if peer_id == 1:
			line += " (host)"
		if peer_id == my_id:
			line += " (você)"
		players_list.add_item(line)


func _set_status(msg: String) -> void:
	if status_label != null:
		status_label.text = msg
