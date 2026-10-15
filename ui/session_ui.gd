class_name SessionUI
extends CanvasLayer

## Overlay global do fluxo de sessão (autoload "CoreSessionUI").
## Tela de carregamento, barra de expedição (mapa/dia + "Voltar à base" para o host
## e "Sair da sessão" online), resumo do dia e aviso de queda do host. Acessa o
## SessionManager de forma dinâmica (autoload "CoreSession") para funcionar mesmo
## antes dele existir.

const SESSION_PATH: NodePath = ^"/root/CoreSession"
## Tempo mínimo da tela de carregamento, para não piscar.
const LOADING_MIN_SEC: float = 0.4
const LEAVE_HOST_TEXT: String = "Você é o host: todos os jogadores voltarão à base.\nO dinheiro e o museu até agora ficam salvos, mas o dia não avança."
const LEAVE_CLIENT_TEXT: String = "Sair da sessão e voltar à base?\nO que estiver na sua mochila será perdido."

static var instance: SessionUI = null

@onready var loading_screen: Control = %LoadingScreen
@onready var loading_label: Label = %LoadingLabel
@onready var expedition_bar: Control = %ExpeditionBar
@onready var expedition_info_label: Label = %ExpeditionInfoLabel
@onready var return_button: Button = %ReturnButton
@onready var leave_button: Button = %LeaveButton
@onready var summary_panel: Control = %SummaryPanel
@onready var summary_title_label: Label = %SummaryTitleLabel
@onready var summary_list: ItemList = %SummaryList
@onready var summary_total_label: Label = %SummaryTotalLabel
@onready var summary_close_button: Button = %SummaryCloseButton
@onready var host_lost_panel: Control = %HostLostPanel
@onready var host_lost_close_button: Button = %HostLostCloseButton
@onready var leave_confirm_panel: Control = %LeaveConfirmPanel
@onready var leave_confirm_label: Label = %LeaveConfirmLabel
@onready var leave_confirm_button: Button = %LeaveConfirmButton
@onready var leave_cancel_button: Button = %LeaveCancelButton

var _session: Node = null
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _mouse_released: bool = false
## Incrementado a cada troca de cena para descartar esperas antigas do carregamento.
var _loading_token: int = 0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	loading_screen.visible = false
	summary_panel.visible = false
	host_lost_panel.visible = false
	leave_confirm_panel.visible = false
	expedition_bar.visible = false
	return_button.pressed.connect(_on_return_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	leave_confirm_button.pressed.connect(_on_leave_confirm_pressed)
	leave_cancel_button.pressed.connect(_on_leave_cancel_pressed)
	summary_close_button.pressed.connect(_on_summary_close_pressed)
	host_lost_close_button.pressed.connect(_on_host_lost_close_pressed)
	multiplayer.connected_to_server.connect(_refresh_expedition_bar)
	multiplayer.server_disconnected.connect(_refresh_expedition_bar)
	# Garante que todos os autoloads já entraram na árvore antes de procurar o CoreSession.
	_connect_session.call_deferred()


func _connect_session() -> void:
	_session = get_node_or_null(SESSION_PATH)
	if GameState.instance != null and not GameState.instance.state_synced.is_connected(_refresh_expedition_bar):
		GameState.instance.state_synced.connect(_refresh_expedition_bar)
	if NetworkManager.instance != null:
		_connect_if_has(NetworkManager.instance, &"session_left", _on_session_left)
	if _session == null:
		push_warning("SessionUI: CoreSession não encontrado; overlay de sessão inativo.")
		return
	_connect_if_has(_session, &"scene_changing", _on_scene_changing)
	_connect_if_has(_session, &"expedition_started", _on_expedition_started)
	_connect_if_has(_session, &"expedition_ended", _on_expedition_ended)
	_connect_if_has(_session, &"host_lost", _on_host_lost)
	_refresh_expedition_bar()


func _connect_if_has(source: Object, signal_name: StringName, callable: Callable) -> void:
	if not source.has_signal(signal_name):
		push_warning("SessionUI: sinal '%s' ausente em %s." % [signal_name, source.get_class()])
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _session_call(method: StringName, default_value: Variant = null) -> Variant:
	if _session != null and is_instance_valid(_session) and _session.has_method(method):
		return _session.call(method)
	return default_value


func _is_host() -> bool:
	if GameState.instance != null:
		return GameState.instance.is_authority()
	return multiplayer.is_server()


## Mesmo critério de GameState._is_online() (privado).
func _is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


# --- Barra de expedição -------------------------------------------------------

func _refresh_expedition_bar() -> void:
	var in_expedition: bool = bool(_session_call(&"is_in_expedition", false))
	expedition_bar.visible = in_expedition and not loading_screen.visible
	var can_leave: bool = in_expedition and _is_online()
	# Solo/offline: "Voltar à base" é o caminho; online, host e clientes podem sair.
	leave_button.visible = can_leave
	if not can_leave and leave_confirm_panel.visible:
		leave_confirm_panel.visible = false
		_update_mouse()
	if not in_expedition:
		return
	var map_name: String = "Mapa desconhecido"
	var map: MapData = _session_call(&"get_current_map") as MapData
	if map != null:
		map_name = map.display_name if not map.display_name.is_empty() else map.id
	var day: int = GameState.instance.current_day if GameState.instance != null else 1
	expedition_info_label.text = "Expedição: %s  •  Dia %d" % [map_name, day]
	return_button.visible = _is_host()
	return_button.disabled = false
	leave_button.disabled = false


func _on_return_pressed() -> void:
	if not _is_host():
		return
	return_button.disabled = true
	_session_call(&"request_end_expedition")


func _on_leave_pressed() -> void:
	leave_confirm_label.text = LEAVE_HOST_TEXT if _is_host() else LEAVE_CLIENT_TEXT
	leave_confirm_panel.visible = true
	_update_mouse()


func _on_leave_cancel_pressed() -> void:
	leave_confirm_panel.visible = false
	_update_mouse()


func _on_leave_confirm_pressed() -> void:
	leave_confirm_panel.visible = false
	_update_mouse()
	if NetworkManager.instance == null:
		push_warning("SessionUI: NetworkManager ausente; não foi possível sair da sessão.")
		return
	leave_button.disabled = true
	NetworkManager.instance.disconnect_game()


## O próprio peer saiu: o SessionManager volta ao lobby sozinho, sem host_lost nem resumo.
func _on_session_left(_was_host: bool) -> void:
	leave_confirm_panel.visible = false
	expedition_bar.visible = false
	_update_mouse()


# --- Sinais do SessionManager -------------------------------------------------

func _on_scene_changing(target_scene: String) -> void:
	var text: String = "Carregando..."
	if target_scene.contains("lobby"):
		text = "Voltando à base..."
	elif target_scene.contains("map_"):
		text = "Partindo para a expedição..."
	loading_label.text = text
	loading_screen.visible = true
	expedition_bar.visible = false
	_loading_token += 1
	var token: int = _loading_token
	# Esconde o carregamento depois que a nova cena entrar (com tempo mínimo na tela).
	await get_tree().create_timer(LOADING_MIN_SEC, true, false, true).timeout
	await get_tree().process_frame
	if token != _loading_token:
		return
	loading_screen.visible = false
	_refresh_expedition_bar()


func _on_expedition_started(_map_id: String) -> void:
	_refresh_expedition_bar()


func _on_expedition_ended(summary: Dictionary) -> void:
	expedition_bar.visible = false
	_show_summary(summary)


func _on_host_lost() -> void:
	expedition_bar.visible = false
	summary_panel.visible = false
	leave_confirm_panel.visible = false
	host_lost_panel.visible = true
	_update_mouse()


# --- Resumo do dia ------------------------------------------------------------

func _show_summary(summary: Dictionary) -> void:
	var day: int = int(summary.get("day", 0))
	var map_name: String = str(summary.get("map_name", summary.get("map_id", "")))
	summary_title_label.text = "Resumo do Dia %d — %s" % [day, map_name]
	summary_list.clear()
	var entries: Array = []
	if summary.get("entries") is Array:
		entries = summary["entries"] as Array
	if entries.is_empty():
		summary_list.add_item("Nenhum item vendido ou doado nesta expedição.")
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var e: Dictionary = entry as Dictionary
		var action_text: String = "Doado ao museu" if str(e.get("action", "")) == "donated" else "Vendido"
		summary_list.add_item("%s — %s (+R$ %d)" % [str(e.get("name", "?")), action_text, int(e.get("value", 0))])
	summary_total_label.text = "Total ganho: R$ %d  (saldo: R$ %d → R$ %d)" % [
		int(summary.get("money_earned", 0)),
		int(summary.get("money_start", 0)),
		int(summary.get("money_end", 0)),
	]
	summary_panel.visible = true
	_update_mouse()


func _on_summary_close_pressed() -> void:
	summary_panel.visible = false
	_update_mouse()


func _on_host_lost_close_pressed() -> void:
	host_lost_panel.visible = false
	_update_mouse()


# --- Mouse --------------------------------------------------------------------

func _update_mouse() -> void:
	var any_open: bool = summary_panel.visible or host_lost_panel.visible or leave_confirm_panel.visible
	if any_open and not _mouse_released:
		_previous_mouse_mode = Input.mouse_mode
		_mouse_released = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not any_open and _mouse_released:
		_mouse_released = false
		Input.mouse_mode = _previous_mouse_mode


func _process(_delta: float) -> void:
	# O player recaptura o mouse ao clicar; mantém visível enquanto houver painel aberto.
	if _mouse_released and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
