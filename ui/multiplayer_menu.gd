class_name MultiplayerMenu
extends Control

## Menu de gerenciamento de sessão de rede (Host / Join / Lista de Jogadores).

@onready var host_button: Button = _resolve_node("HostButton", "PanelContainer/MarginContainer/VBoxContainer/HostButton") as Button
@onready var join_button: Button = _resolve_node("JoinButton", "PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/JoinButton") as Button
@onready var ip_line_edit: LineEdit = _resolve_node("IPLineEdit", "PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/IPLineEdit") as LineEdit
@onready var leave_button: Button = _resolve_node("LeaveButton", "PanelContainer/MarginContainer/VBoxContainer/LeaveButton") as Button
@onready var status_label: Label = _resolve_node("StatusLabel", "PanelContainer/MarginContainer/VBoxContainer/StatusLabel") as Label
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
	
	_resolve_network_manager()
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
		# session_left pode não existir em um core antigo.
		if _net_manager.has_signal(&"session_left") and not _net_manager.is_connected(&"session_left", _on_session_left):
			_net_manager.connect(&"session_left", _on_session_left)
		_refresh_players_list()


func _on_host_pressed() -> void:
	if _net_manager == null:
		_set_status("Erro: NetworkManager não encontrado.")
		return
	
	var err: Error = _net_manager.host_game()
	if err == OK:
		_set_status("Servidor iniciado (Host ativo).")
		_refresh_players_list()
	else:
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
	if err != OK:
		_set_status("Erro ao tentar conectar: erro %d" % err)
	_refresh_session_buttons()


func _on_leave_pressed() -> void:
	# Sem confirmação: no lobby não há expedição a perder. Também cancela um "Conectando...".
	if _net_manager == null:
		_set_status("Erro: NetworkManager não encontrado.")
		return
	_net_manager.disconnect_game()
	_refresh_players_list()
	_refresh_session_buttons()


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
	_set_status("Falha na conexão com o servidor.")
	_refresh_players_list()
	_refresh_session_buttons()


func _on_server_disconnected() -> void:
	_set_status("Servidor foi desconectado.")
	_refresh_players_list()
	_refresh_session_buttons()


func _on_session_left(was_host: bool) -> void:
	_set_status("Você encerrou a sessão (host)." if was_host else "Você saiu da sessão.")
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
	
	for peer_id in _net_manager.connected_players:
		var player_info: Dictionary = _net_manager.connected_players[peer_id]
		var player_name: String = str(player_info.get("name", "Jogador"))
		players_list.add_item("Peer ID %s: %s" % [str(peer_id), player_name])


func _set_status(msg: String) -> void:
	if status_label != null:
		status_label.text = msg
