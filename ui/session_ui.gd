class_name SessionUI
extends CanvasLayer

## Overlay global do fluxo de sessão (autoload "CoreSessionUI").
## Tela de carregamento, barra de expedição (mapa/dia + "Sair da sessão" online; o
## "Voltar à base" fica no menu de pausa, #122), avisos de missão/segredo, resumo do dia e aviso de
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
## Aviso de save_failed do SaveManager (o texto do sinal é do dev, não do jogador).
const SAVE_FAILED_TEXT: String = "Não foi possível salvar — verifique o espaço em disco"
## save_failed por save de versão mais nova (a gravação fica bloqueada).
const SAVE_NEWER_TEXT: String = "Este save é de uma versão mais nova; o progresso não será salvo"
## Tempo do aviso de save na tela (mais que o de missão: é um problema a resolver).
const SAVE_TOAST_SEC: float = 6.0
## Largura do aviso de save e o mínimo antes de ir para baixo do menu (#137).
const SAVE_TOAST_WIDTH: float = 560.0
const SAVE_TOAST_MIN_WIDTH: float = 240.0
const SAVE_TOAST_TOP: float = 180.0
const SAVE_TOAST_GAP: float = 8.0
## Fora da expedição (Base) o aviso sobe para a faixa do topo, entre os chips do HUD e o menu
## Multiplayer, sem cobrir o título da Base (#146). Os nós desse grupo (Control) e os do
## MultiplayerMenu.SAVE_NOTICE_GROUP são evitados.
const TOAST_AVOID_GROUP: StringName = &"toast_avoid"
const TOAST_BASE_TOP: float = 12.0

static var instance: SessionUI = null
## Lugar do ToastPanel na cena (offsets), o da expedição.
var _toast_home: Rect2 = Rect2()

## Nós únicos (%Nome) exigidos pela cena; resolvidos em _bind_nodes().
const REQUIRED_NODES: Array[String] = [
	"LoadingScreen",
	"LoadingLabel",
	"ExpeditionBar",
	"ExpeditionInfoLabel",
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
## Foco antes de abrir um painel (#135), devolvido ao fechar.
var _focus_before: Control = null
var toast_label: Label = null
## Aviso de save: em qualquer tela (título, base, mapa) e por cima do carregamento.
var save_toast_panel: PanelContainer = null
var save_toast_label: Label = null

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
var _save_toast_token: int = 0
## Último resumo do dia mostrado (refeito ao trocar o idioma com ele aberto).
var _last_summary: Dictionary = {}


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
	_toast_home = Rect2(toast_panel.offset_left, toast_panel.offset_top,
		toast_panel.offset_right - toast_panel.offset_left, toast_panel.offset_bottom - toast_panel.offset_top)
	get_viewport().size_changed.connect(func() -> void:
		if toast_panel.visible:
			_place_toast())
	_build_save_toast()
	# Mapa/dia sem cartão, como o resto do HUD de jogo (#122); o botão de sair segue do theme.
	expedition_bar.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	PlayerHudStyle.iconize(expedition_info_label, "map")
	# Encostado à direita, no canto: a largura vem do texto (sem reticências).
	expedition_info_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	expedition_info_label.size_flags_horizontal = Control.SIZE_SHRINK_END
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


## B/Esc (ui_cancel ou pausa) fecha o painel aberto (#135): confirmação de sair, resumo do dia ou
## queda do host. Em _input, antes da pausa, que não abre por cima deles e engoliria o Esc.
func _input(event: InputEvent) -> void:
	if summary_panel == null or not (event.is_action_pressed(&"ui_cancel", false, true) or event.is_action_pressed(&"pause", false, true)):
		return
	if leave_confirm_panel.visible:
		_on_leave_cancel_pressed()
	elif summary_panel.visible:
		_on_summary_close_pressed()
	elif host_lost_panel.visible:
		_on_host_lost_close_pressed()
	else:
		return
	get_viewport().set_input_as_handled()


## Painel modal com teclado/comando (#135): o foco anda em anel só entre `controls` (as quatro
## setas e Tab), sem escapar para a Base por baixo, e começa em `first`. Guarda o foco de antes.
func _focus_panel(controls: Array, first: Control) -> void:
	var current: Control = get_viewport().gui_get_focus_owner()
	if current != null and not _is_panel_control(current):
		_focus_before = current
	UiFocus.link_chain(controls)
	for c: Variant in controls:
		var control: Control = c as Control
		control.focus_neighbor_left = control.focus_previous
		control.focus_neighbor_right = control.focus_next
	first.grab_focus()


func _is_panel_control(control: Control) -> bool:
	for panel: Control in [summary_panel, host_lost_panel, leave_confirm_panel]:
		if panel.is_ancestor_of(control):
			return true
	return false


## Painel fechado: o foco volta aonde estava; sem isso (cena trocada), à Base (UiFocus.HOME_GROUP),
## para o comando não ficar sem foco nenhum.
func _restore_focus() -> void:
	if summary_panel.visible or host_lost_panel.visible or leave_confirm_panel.visible:
		return
	var before: Control = _focus_before
	_focus_before = null
	if is_instance_valid(before) and before.is_visible_in_tree():
		before.grab_focus()
	elif is_inside_tree():
		var current: Control = get_viewport().gui_get_focus_owner()
		if current == null or not current.is_visible_in_tree():
			get_tree().call_group(UiFocus.HOME_GROUP, &"focus_home")


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
		_connect_if_has(GameState.instance, &"achievement_unlocked", _on_achievement_unlocked)
		_connect_if_has(GameState.instance, &"boss_key_available", _on_boss_key_available)
	if NetworkManager.instance != null:
		_connect_if_has(NetworkManager.instance, &"session_left", _on_session_left)
	if SaveManager.instance != null:
		_connect_if_has(SaveManager.instance, &"save_failed_with_reason", _on_save_failed)
		_connect_if_has(SaveManager.instance, &"save_load_failed", _on_save_load_failed)
	if _session == null:
		push_warning("SessionUI: CoreSession não encontrado; overlay de sessão inativo.")
		return
	_connect_if_has(_session, &"scene_changing", _on_scene_changing)
	_connect_if_has(_session, &"expedition_started", _on_expedition_started)
	_connect_if_has(_session, &"expedition_ended", _on_expedition_ended)
	_connect_if_has(_session, &"host_lost", _on_host_lost)
	_connect_if_has(_session, &"passage_travel_failed", _on_passage_travel_failed)
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
	# Solo/offline: "Voltar à base" (pausa) é o caminho; online, host e clientes podem sair.
	leave_button.visible = can_leave
	if not can_leave and leave_confirm_panel.visible:
		leave_confirm_panel.visible = false
		_update_mouse()
	if not in_expedition:
		return
	var map_name: String = tr("Mapa desconhecido")
	var map: MapData = _session_call(&"get_current_map") as MapData
	if map != null:
		map_name = tr(map.display_name) if not map.display_name.is_empty() else map.id
	var day: int = GameState.instance.current_day if GameState.instance != null else 1
	expedition_info_label.text = tr("%s  •  Dia %d") % [map_name, day]
	leave_button.disabled = false


## "Voltar à base" do menu de pausa (#122): só o host, em expedição. Retorna se pediu.
func request_return_to_base() -> bool:
	if not _is_host() or not bool(_session_call(&"is_in_expedition", false)):
		return false
	_session_call(&"request_end_expedition")
	return true


func _on_leave_pressed() -> void:
	leave_confirm_label.text = LEAVE_HOST_TEXT if _is_host() else LEAVE_CLIENT_TEXT
	leave_confirm_panel.visible = true
	_update_mouse()
	_focus_panel([leave_cancel_button, leave_confirm_button], leave_cancel_button)


func _on_leave_cancel_pressed() -> void:
	leave_confirm_panel.visible = false
	_update_mouse()
	_restore_focus()


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


func _on_passage_travel_failed(message: String) -> void:
	_loading_token += 1
	loading_screen.hide()
	_refresh_expedition_bar()
	show_save_toast(tr(message))


func _on_boss_key_available(route_id: String) -> void:
	var route: Dictionary = GameState.MAP_UNLOCK_BOSSES.get(route_id, {})
	if route.is_empty(): return
	var item: ItemData = load("res://items/catalog/%s.tres" % str(route["item_id"])) as ItemData
	var map_data: MapData = load("res://items/maps/%s.tres" % route_id) as MapData
	if item != null and map_data != null:
		_enqueue_toast(tr("Chave disponível: %s. Use na passagem para %s.") % [tr(item.display_name), tr(map_data.display_name)])


func _on_expedition_ended(summary: Dictionary) -> void:
	expedition_bar.visible = false
	_show_summary(summary)


func _on_host_lost() -> void:
	expedition_bar.visible = false
	summary_panel.visible = false
	leave_confirm_panel.visible = false
	host_lost_panel.visible = true
	_update_mouse()
	_focus_panel([host_lost_close_button], host_lost_close_button)


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
	var quest_name: String = tr(str(quest.get("name", "Missão")))
	_enqueue_toast(tr("Missão concluída: %s (+%s)") % [quest_name, UiFormat.money(reward)])


## "Segredo encontrado! (Praia 3/6)": a contagem é do mapa do segredo, não da expedição.
func _on_secret_found(secret_id: String) -> void:
	var found: Array = Array(GameState.instance.found_secrets) if GameState.instance != null else []
	var map_id: String = UiFormat.secret_map_id(secret_id)
	var counts: Dictionary = UiFormat.secret_counts_by_map(found)
	var maps: Variant = _session_call(&"get_available_maps", [])
	var map_list: Array = maps as Array if maps is Array else []
	_enqueue_toast(tr("Segredo encontrado! (%s)") % UiFormat.secret_count_text(map_id, counts.get(map_id, {}), map_list))


## Primeira vez que se derrota um tipo de criatura (Diário de campo).
func _on_creature_discovered(kind: String) -> void:
	var total: int = GameState.CREATURES.size()
	var seen: int = GameState.instance.seen_creatures.size() if GameState.instance != null else 0
	_enqueue_toast(tr("📖 Nova criatura no diário: %s (%d/%d)") % [tr(str(GameState.CREATURES.get(kind, kind))), seen, total])


## Conquista nova (#141): avisa também na Base (doar ao Museu desbloqueia). O save carregado no
## host não emite achievement_unlocked, e a leva inicial de quem entra fica de fora (_synced_once).
func _on_achievement_unlocked(achievement_id: String) -> void:
	var def: Dictionary = Achievements.get_definition(achievement_id)
	if def.is_empty():
		return
	_enqueue_toast(tr("🏆 Conquista desbloqueada: %s") % tr(str(def["name"])), true)


## `anywhere`: fora da expedição também (senão o aviso é só de expedição).
func _enqueue_toast(text: String, anywhere: bool = false) -> void:
	if not (_should_show_toast() or (anywhere and _synced_once)):
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
	_place_toast()
	_toast_token += 1
	var token: int = _toast_token
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(TOAST_SEC, true, false, true).timeout
	if not is_inside_tree() or token != _toast_token:
		return
	_show_next_toast()


## Na expedição o aviso fica no lugar da cena; na Base sobe para o topo, centrado no vão livre
## entre o que está à esquerda (chips) e à direita (menu Multiplayer), e estreita se faltar espaço.
func _place_toast() -> void:
	var home: Rect2 = _toast_home
	toast_panel.offset_left = home.position.x
	toast_panel.offset_right = home.end.x
	toast_panel.offset_top = home.position.y
	toast_panel.offset_bottom = home.end.y
	# A conquista chega antes de game_victory. Ao abrir, a vitória reposiciona
	# esse mesmo aviso, sem tocar na fila, token ou prazo de expiração.
	if VictoryScreen.is_open():
		var height: float = maxf(home.size.y, toast_panel.get_combined_minimum_size().y)
		toast_panel.offset_top = TOAST_BASE_TOP
		toast_panel.offset_bottom = TOAST_BASE_TOP + height
		VictoryScreen.instance.reserve_notice_space(TOAST_BASE_TOP + height + SAVE_TOAST_GAP)
		return
	if bool(_session_call(&"is_in_expedition", false)):
		return
	var view: Rect2 = toast_panel.get_viewport_rect()
	var strip_bottom: float = TOAST_BASE_TOP + maxf(home.size.y, toast_panel.get_combined_minimum_size().y)
	var free_left: float = 0.0
	var free_right: float = view.size.x
	for rect: Rect2 in _toast_avoid_rects():
		if not rect.has_area() or rect.position.y > strip_bottom + SAVE_TOAST_GAP or rect.end.y < TOAST_BASE_TOP:
			continue
		if rect.get_center().x < view.size.x * 0.5:
			free_left = maxf(free_left, rect.end.x + SAVE_TOAST_GAP)
		else:
			free_right = minf(free_right, rect.position.x - SAVE_TOAST_GAP)
	var width: float = minf(home.size.x, free_right - free_left)
	var center: float = (free_left + free_right) * 0.5 - view.size.x * 0.5
	toast_panel.offset_left = center - width * 0.5
	toast_panel.offset_right = center + width * 0.5
	toast_panel.offset_top = TOAST_BASE_TOP
	toast_panel.offset_bottom = TOAST_BASE_TOP + home.size.y


func _toast_avoid_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node: Node in get_tree().get_nodes_in_group(MultiplayerMenu.SAVE_NOTICE_GROUP):
		if node.has_method(&"get_save_notice_rect"):
			out.append(node.call(&"get_save_notice_rect"))
	for node: Node in get_tree().get_nodes_in_group(TOAST_AVOID_GROUP):
		var c: Control = node as Control
		if c != null and c.is_visible_in_tree():
			out.append(c.get_global_rect())
	return out


# --- Aviso de save -------------------------------------------------------------

## Mesmo estilo do ToastPanel, logo abaixo dele; último filho para ficar por cima do carregamento.
## O texto é a chave: o auto_translate do Label acompanha a troca de idioma.
func _build_save_toast() -> void:
	save_toast_panel = PanelContainer.new()
	save_toast_panel.name = "SaveToast"
	save_toast_panel.theme = toast_panel.theme
	save_toast_panel.theme_type_variation = &"ToastPanel"
	save_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_reset_save_toast_place()
	save_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	save_toast_panel.visible = false
	save_toast_label = Label.new()
	save_toast_label.theme_type_variation = &"ToastLabel"
	save_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	save_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_toast_panel.add_child(save_toast_label)
	add_child(save_toast_panel)


func _on_save_failed(reason: SaveManager.FailReason, _error_message: String) -> void:
	var text: String = save_failed_text(reason)
	if not text.is_empty():
		show_save_toast(text)


## Texto do jogador para cada motivo; "" = não é falha para ele (não-host, save não aplicado,
## sem GameState): o SaveManager já deixou no log.
static func save_failed_text(reason: SaveManager.FailReason) -> String:
	match reason:
		SaveManager.FailReason.WRITE, SaveManager.FailReason.READ:
			return SAVE_FAILED_TEXT
		SaveManager.FailReason.NEWER_VERSION:
			return SAVE_NEWER_TEXT
	return ""


## O SaveManager já manda o texto do jogador (MSG_CORRUPT / MSG_NEWER, chaves do CSV).
func _on_save_load_failed(message: String) -> void:
	show_save_toast(message)


## Mostra o aviso por SAVE_TOAST_SEC; um aviso novo troca o texto e reinicia o tempo.
func show_save_toast(text: String) -> void:
	if save_toast_panel == null:
		return
	save_toast_label.text = text
	save_toast_panel.visible = true
	_reset_save_toast_place()
	# Depois dos outros ouvintes do sinal: o painel do menu já tem o aviso dele.
	_fit_save_toast.call_deferred()
	_save_toast_token += 1
	var token: int = _save_toast_token
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(SAVE_TOAST_SEC, true, false, true).timeout
	if is_inside_tree() and token == _save_toast_token:
		save_toast_panel.visible = false


func _reset_save_toast_place() -> void:
	save_toast_panel.offset_left = -SAVE_TOAST_WIDTH * 0.5
	save_toast_panel.offset_right = SAVE_TOAST_WIDTH * 0.5
	save_toast_panel.offset_top = SAVE_TOAST_TOP
	save_toast_panel.offset_bottom = SAVE_TOAST_TOP


## No título o MultiplayerMenu mostra o aviso no painel dele (#137): o mesmo texto lá = some o
## toast (o painel fica com ele, perto de Continuar/Novo jogo); outro texto = o toast vai para o
## lado livre do menu e, sem largura, para baixo dele. Nunca cobre o painel.
func _fit_save_toast() -> void:
	if save_toast_panel == null or not save_toast_panel.visible:
		return
	var text: String = save_toast_label.atr(save_toast_label.text)
	var view: Rect2 = save_toast_panel.get_viewport_rect()
	for node: Node in get_tree().get_nodes_in_group(MultiplayerMenu.SAVE_NOTICE_GROUP):
		if not node.has_method(&"get_save_notice_rect"):
			continue
		if str(node.call(&"get_save_notice")) == text:
			hide_save_toast()
			return
		var avoid: Rect2 = node.call(&"get_save_notice_rect")
		if avoid.has_area() and save_toast_rect().intersects(avoid):
			_place_save_toast_beside(avoid, view)


## Retângulo do aviso (o tamanho mínimo vale antes do container ajustar a altura).
func save_toast_rect() -> Rect2:
	var rect: Rect2 = save_toast_panel.get_global_rect()
	rect.size.y = maxf(rect.size.y, save_toast_panel.get_combined_minimum_size().y)
	return rect


func _place_save_toast_beside(avoid: Rect2, view: Rect2) -> void:
	var center: float = view.size.x * 0.5
	var left_room: float = avoid.position.x - SAVE_TOAST_GAP * 2.0
	var right_room: float = view.end.x - avoid.end.x - SAVE_TOAST_GAP * 2.0
	if maxf(left_room, right_room) >= SAVE_TOAST_MIN_WIDTH:
		var width: float = minf(SAVE_TOAST_WIDTH, maxf(left_room, right_room))
		var left: float = avoid.position.x - SAVE_TOAST_GAP - width if left_room >= right_room else avoid.end.x + SAVE_TOAST_GAP
		save_toast_panel.offset_left = left - center
		save_toast_panel.offset_right = left + width - center
	else:
		save_toast_panel.offset_top = avoid.end.y + SAVE_TOAST_GAP
		save_toast_panel.offset_bottom = save_toast_panel.offset_top


func hide_save_toast() -> void:
	_save_toast_token += 1
	if save_toast_panel != null:
		save_toast_panel.visible = false


# --- Resumo do dia ------------------------------------------------------------

## Idioma trocado (#131): a barra da expedição e o resumo aberto são montados por código.
func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready() or expedition_bar == null:
		return
	_refresh_expedition_bar()
	if summary_panel.visible and not _last_summary.is_empty():
		_show_summary(_last_summary)


## O resumo vem do host com os nomes em PT-BR (as chaves): a tradução é aqui, na tela de cada um.
func _show_summary(summary: Dictionary) -> void:
	_last_summary = summary
	var day: int = int(summary.get("day", 0))
	var map_name: String = tr(str(summary.get("map_name", summary.get("map_id", ""))))
	if bool(summary.get("night", false)):
		map_name = tr("%s (noite)") % map_name
	summary_title_label.text = tr("Resumo do Dia %d — %s") % [day, map_name]
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
		var action_text: String = tr("Doado ao museu") if str(e.get("action", "")) == "donated" else tr("Vendido")
		summary_list.add_item("%s — %s (+%s)" % [tr(str(e.get("name", "?"))), action_text, UiFormat.money(int(e.get("value", 0)))])
	summary_total_label.text = tr("Total ganho: %s  (saldo: %s → %s)") % [
		UiFormat.money(int(summary.get("money_earned", 0))),
		UiFormat.money(int(summary.get("money_start", 0))),
		UiFormat.money(int(summary.get("money_end", 0))),
	]
	summary_panel.visible = true
	_update_mouse()
	_focus_panel([summary_list, summary_close_button], summary_close_button)


func _on_summary_close_pressed() -> void:
	summary_panel.visible = false
	_update_mouse()
	_restore_focus()


func _on_host_lost_close_pressed() -> void:
	host_lost_panel.visible = false
	_update_mouse()
	_restore_focus()


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
