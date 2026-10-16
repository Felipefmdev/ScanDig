class_name SessionUI
extends CanvasLayer

## Overlay global do fluxo de sessão (autoload "CoreSessionUI").
## Tela de carregamento, barra de expedição (mapa/dia + "Voltar à base" para o host
## e "Sair da sessão" online), avisos de missão/segredo, resumo do dia e aviso de
## queda do host. Acessa o
## SessionManager de forma dinâmica (autoload "CoreSession") para funcionar mesmo
## antes dele existir.

const SESSION_PATH: NodePath = ^"/root/CoreSession"
## Tempo mínimo da tela de carregamento, para não piscar.
const LOADING_MIN_SEC: float = 0.4
const LEAVE_HOST_TEXT: String = "Você é o host: todos os jogadores voltarão à base.\nO dinheiro e o museu até agora ficam salvos, mas o dia não avança."
## Tempo de cada aviso de missão/segredo na tela.
const TOAST_SEC: float = 3.0
const LEAVE_CLIENT_TEXT: String = "Sair da sessão e voltar à base?\nO que estiver na sua mochila será perdido."

static var instance: SessionUI = null

## Nós únicos (%Nome) exigidos pela cena; resolvidos em _bind_nodes().
const REQUIRED_NODES: Array[String] = [
	"LoadingScreen",
	"LoadingLabel",
	"ExpeditionBar",
	"ExpeditionInfoLabel",
	"ReturnButton",
	"LeaveButton",
	"SummaryPanel",
	"SummaryTitleLabel",
	"SummaryList",
	"SummaryTotalLabel",
	"SummaryCloseButton",
	"HostLostPanel",
	"HostLostCloseButton",
	"LeaveConfirmPanel",
	"LeaveConfirmLabel",
	"LeaveConfirmButton",
	"LeaveCancelButton",
	"ToastPanel",
	"ToastLabel",
]

var loading_screen: Control = null
var loading_label: Label = null
var expedition_bar: Control = null
var expedition_info_label: Label = null
var return_button: Button = null
var leave_button: Button = null
var summary_panel: Control = null
var summary_title_label: Label = null
var summary_list: ItemList = null
var summary_total_label: Label = null
var summary_close_button: Button = null
var host_lost_panel: Control = null
var host_lost_close_button: Button = null
var leave_confirm_panel: Control = null
var leave_confirm_label: Label = null
var leave_confirm_button: Button = null
var leave_cancel_button: Button = null
var toast_panel: Control = null
var toast_label: Label = null

var _session: Node = null
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _mouse_released: bool = false
## Incrementado a cada troca de cena para descartar esperas antigas do carregamento.
var _loading_token: int = 0
## Falso ao entrar numa sessão até o primeiro state_synced: o snapshot inicial do host
## reemite quest_completed/secret_found de tudo já conquistado. O save só é carregado
## fora da expedição, onde nenhum aviso aparece, então solo começa em verdadeiro.
var _synced_once: bool = true
var _toast_queue: Array[String] = []
var _toast_token: int = 0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _bind_nodes():
		# Cena incompleta: overlay fica inerte em vez de crashar o jogo inteiro.
		set_process(false)
		return
	loading_screen.visible = false
	summary_panel.visible = false
	host_lost_panel.visible = false
	leave_confirm_panel.visible = false
	expedition_bar.visible = false
	toast_panel.visible = false
	return_button.pressed.connect(_on_return_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	leave_confirm_button.pressed.connect(_on_leave_confirm_pressed)
	leave_cancel_button.pressed.connect(_on_leave_cancel_pressed)
	summary_close_button.pressed.connect(_on_summary_close_pressed)
	host_lost_close_button.pressed.connect(_on_host_lost_close_pressed)
	multiplayer.connected_to_server.connect(_refresh_expedition_bar)
	multiplayer.server_disconnected.connect(_refresh_expedition_bar)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_clear_toasts)
	# Garante que todos os autoloads já entraram na árvore antes de procurar o CoreSession.
	_connect_session.call_deferred()


## Resolve os nós únicos; retorna falso (com erro listando os ausentes) se faltar algum.
func _bind_nodes() -> bool:
	var missing: Array[String] = []
	for node_name in REQUIRED_NODES:
		if get_node_or_null("%" + node_name) == null:
			missing.append(node_name)
	if not missing.is_empty():
		push_error("SessionUI: nós ausentes na cena (%s); overlay de sessão desativado." % ", ".join(missing))
		return false
	loading_screen = get_node_or_null(^"%LoadingScreen") as Control
	loading_label = get_node_or_null(^"%LoadingLabel") as Label
	expedition_bar = get_node_or_null(^"%ExpeditionBar") as Control
	expedition_info_label = get_node_or_null(^"%ExpeditionInfoLabel") as Label
	return_button = get_node_or_null(^"%ReturnButton") as Button
	leave_button = get_node_or_null(^"%LeaveButton") as Button
	summary_panel = get_node_or_null(^"%SummaryPanel") as Control
	summary_title_label = get_node_or_null(^"%SummaryTitleLabel") as Label
	summary_list = get_node_or_null(^"%SummaryList") as ItemList
	summary_total_label = get_node_or_null(^"%SummaryTotalLabel") as Label
	summary_close_button = get_node_or_null(^"%SummaryCloseButton") as Button
	host_lost_panel = get_node_or_null(^"%HostLostPanel") as Control
	host_lost_close_button = get_node_or_null(^"%HostLostCloseButton") as Button
	leave_confirm_panel = get_node_or_null(^"%LeaveConfirmPanel") as Control
	leave_confirm_label = get_node_or_null(^"%LeaveConfirmLabel") as Label
	leave_confirm_button = get_node_or_null(^"%LeaveConfirmButton") as Button
	leave_cancel_button = get_node_or_null(^"%LeaveCancelButton") as Button
	toast_panel = get_node_or_null(^"%ToastPanel") as Control
	toast_label = get_node_or_null(^"%ToastLabel") as Label
	return true


func _connect_session() -> void:
	_session = get_node_or_null(SESSION_PATH)
	if GameState.instance != null and not GameState.instance.state_synced.is_connected(_refresh_expedition_bar):
		GameState.instance.state_synced.connect(_refresh_expedition_bar)
	if GameState.instance != null:
		_connect_if_has(GameState.instance, &"state_synced", _on_state_synced)
		_connect_if_has(GameState.instance, &"quest_completed", _on_quest_completed)
		_connect_if_has(GameState.instance, &"secret_found", _on_secret_found)
		_connect_if_has(GameState.instance, &"creature_discovered", _on_creature_discovered)
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
	expedition_info_label.text = "%s  •  Dia %d" % [map_name, day]
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
	_clear_toasts()
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
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(LOADING_MIN_SEC, true, false, true).timeout
	if not is_inside_tree() or token != _loading_token:
		return
	tree = get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_inside_tree() or token != _loading_token:
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


# --- Avisos de missão e segredo ------------------------------------------------

## Deferido: os sinais do mesmo apply_snapshot (leva inicial) chegam antes da flag.
func _on_state_synced() -> void:
	_mark_synced.call_deferred()


func _mark_synced() -> void:
	_synced_once = true


## O próximo snapshot (estado completo do host) é a leva inicial.
func _on_connected_to_server() -> void:
	_synced_once = false
	_clear_toasts()


func _clear_toasts() -> void:
	_toast_queue.clear()
	_toast_token += 1
	toast_panel.visible = false


func _should_show_toast() -> bool:
	return _synced_once and bool(_session_call(&"is_in_expedition", false))


func _on_quest_completed(quest_id: String, reward: int) -> void:
	var quest: Dictionary = GameState.QUESTS.get(quest_id, {})
	var quest_name: String = str(quest.get("name", "Missão"))
	_enqueue_toast("Missão concluída: %s (+%s)" % [quest_name, UiFormat.money(reward)])


## "Segredo encontrado! (Praia 3/6)": a contagem é do mapa do segredo, não da expedição.
func _on_secret_found(secret_id: String) -> void:
	var found: Array = Array(GameState.instance.found_secrets) if GameState.instance != null else []
	var map_id: String = UiFormat.secret_map_id(secret_id)
	var counts: Dictionary = UiFormat.secret_counts_by_map(found)
	var maps: Variant = _session_call(&"get_available_maps", [])
	var map_list: Array = maps as Array if maps is Array else []
	_enqueue_toast("Segredo encontrado! (%s)" % UiFormat.secret_count_text(map_id, counts.get(map_id, {}), map_list))


## Primeira vez que se derrota um tipo de criatura (Diário de campo).
func _on_creature_discovered(kind: String) -> void:
	var total: int = GameState.CREATURES.size()
	var seen: int = GameState.instance.seen_creatures.size() if GameState.instance != null else 0
	_enqueue_toast("📖 Nova criatura no diário: %s (%d/%d)" % [GameState.CREATURES.get(kind, kind), seen, total])


func _enqueue_toast(text: String) -> void:
	if not _should_show_toast():
		return
	_toast_queue.append(text)
	if not toast_panel.visible:
		_show_next_toast()


## Um aviso por vez; cada um fica TOAST_SEC na tela.
func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		toast_panel.visible = false
		return
	toast_label.text = _toast_queue.pop_front()
	toast_panel.visible = true
	_toast_token += 1
	var token: int = _toast_token
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(TOAST_SEC, true, false, true).timeout
	if not is_inside_tree() or token != _toast_token:
		return
	_show_next_toast()


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
		summary_list.add_item("%s — %s (+%s)" % [str(e.get("name", "?")), action_text, UiFormat.money(int(e.get("value", 0)))])
	summary_total_label.text = "Total ganho: %s  (saldo: %s → %s)" % [
		UiFormat.money(int(summary.get("money_earned", 0))),
		UiFormat.money(int(summary.get("money_start", 0))),
		UiFormat.money(int(summary.get("money_end", 0))),
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
