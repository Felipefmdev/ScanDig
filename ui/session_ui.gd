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
const SAVE_TOAST_AVOID_GROUP: StringName = &"save_toast_avoid"
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
var _toast_icon: TextureRect = null
var _summary_title_icon: TextureRect = null
## Aviso de save: em qualquer tela (título, base, mapa) e por cima do carregamento.
var save_toast_panel: PanelContainer = null
var save_toast_label: Label = null
## Tela de morte (#244), montada junto da SessionUI (camada 47).
var death_screen: DeathScreen = null

var _session: Node = null
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _mouse_released: bool = false
var _mouse_gameplay_scene_id: int = 0
## Incrementado a cada troca de cena para descartar esperas antigas do carregamento.
var _loading_token: int = 0
## Falso ao entrar numa sessão até o primeiro state_synced: o snapshot inicial do host
## reemite quest_completed/secret_found de tudo já conquistado. O save só é carregado
## fora da expedição, onde nenhum aviso aparece, então solo começa em verdadeiro.
var _synced_once: bool = true
var _toast_queue: Array[String] = []
var _toast_token: int = 0
var _save_toast_token: int = 0
var _save_toast_active: bool = false
var _loading_tween: Tween = null
var _summary_money_tween: Tween = null
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
	# A quebra de linha é medida pelo Container após trocar texto/largura.
	toast_panel.minimum_size_changed.connect(func() -> void:
		if toast_panel.visible:
			_sync_toast_icon()
			_place_toast(), CONNECT_DEFERRED)
	toast_panel.visibility_changed.connect(func() -> void:
		if toast_panel.visible:
			_sync_toast_icon())
	get_viewport().size_changed.connect(func() -> void:
		if toast_panel.visible:
			_place_toast())
	_setup_death_screen()
	_build_save_toast()
	get_viewport().size_changed.connect(refresh_save_toast_layout, CONNECT_DEFERRED)
	_setup_visual_icons()
	# Mapa/dia sem cartão, como o resto do HUD de jogo (#122); o botão de sair segue do theme.
	expedition_bar.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	PlayerHudStyle.iconize(expedition_info_label, "map")
	leave_button.icon = UiIcons.get_icon("door", 16)
	# Encostado à direita, no canto: a largura vem do texto (sem reticências).
	expedition_info_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	expedition_info_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	leave_button.pressed.connect(_on_leave_pressed)
	leave_confirm_button.pressed.connect(_on_leave_confirm_pressed)
	leave_cancel_button.pressed.connect(_on_leave_cancel_pressed)
	summary_close_button.pressed.connect(_on_summary_close_pressed)
	host_lost_close_button.pressed.connect(_on_host_lost_close_pressed)
	for btn: Button in [leave_button, leave_confirm_button, leave_cancel_button, summary_close_button, host_lost_close_button]:
		UiMotion.attach_button(btn)
	for panel_root: Control in [expedition_bar, summary_panel, host_lost_panel, leave_confirm_panel]:
		if panel_root != null:
			UiFocus.follow_pointer(panel_root.get_node_or_null(^"Margin") as Control)
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

func _setup_death_screen() -> void:
	death_screen = DeathScreen.new()
	death_screen.name = "DeathScreen"
	add_child(death_screen)


func show_death_screen(context: Dictionary = {}) -> void:
	if death_screen != null:
		death_screen.open(context)


func _setup_visual_icons() -> void:
	_toast_icon = get_node_or_null(^"%ToastIcon") as TextureRect
	var loading_card: PanelContainer = get_node_or_null(^"%LoadingCard") as PanelContainer
	if loading_card != null:
		var card_style: StyleBoxFlat = StyleBoxFlat.new()
		card_style.bg_color = Color(UiPalette.INK, 0.45)
		card_style.border_color = Color(UiPalette.GOLD, 0.55)
		card_style.set_border_width_all(2)
		card_style.set_corner_radius_all(8)
		card_style.shadow_color = Color(0, 0, 0, 0.35)
		card_style.shadow_size = 4
		card_style.shadow_offset = Vector2(0, 3)
		loading_card.add_theme_stylebox_override(&"panel", card_style)
	var medallion: PanelContainer = get_node_or_null(^"%LoadingMedallion") as PanelContainer
	if medallion != null:
		var med_style: StyleBoxFlat = StyleBoxFlat.new()
		med_style.bg_color = UiPalette.PAPER
		med_style.border_color = UiPalette.INK
		med_style.set_border_width_all(3)
		med_style.set_corner_radius_all(38)
		med_style.content_margin_left = 10.0
		med_style.content_margin_right = 10.0
		med_style.content_margin_top = 10.0
		med_style.content_margin_bottom = 10.0
		medallion.add_theme_stylebox_override(&"panel", med_style)
	var loading_icon: TextureRect = get_node_or_null(^"%LoadingIcon") as TextureRect
	if loading_icon != null:
		loading_icon.texture = UiIcons.get_icon("detector", 36)
		loading_screen.visibility_changed.connect(_sync_loading_anim.bind(loading_icon))
		_sync_loading_anim(loading_icon)
	var total_icon: TextureRect = get_node_or_null(^"%SummaryTotalIcon") as TextureRect
	if total_icon != null:
		total_icon.texture = UiIcons.get_icon("coin", 24)
	if summary_title_label != null and not (summary_title_label.get_parent() is HBoxContainer):
		var sum_vbox: Control = summary_title_label.get_parent() as Control
		var sum_idx: int = summary_title_label.get_index()
		var sum_header_row: HBoxContainer = HBoxContainer.new()
		sum_header_row.name = "SummaryTitleRow"
		sum_header_row.alignment = BoxContainer.ALIGNMENT_CENTER
		sum_header_row.add_theme_constant_override(&"separation", 8)
		sum_vbox.add_child(sum_header_row)
		sum_vbox.move_child(sum_header_row, sum_idx)
		_summary_title_icon = TextureRect.new()
		_summary_title_icon.name = "SummaryTitleIcon"
		_summary_title_icon.custom_minimum_size = Vector2(24, 24)
		_summary_title_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_summary_title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_summary_title_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_summary_title_icon.texture = UiIcons.get_icon("sun", 32)
		sum_header_row.add_child(_summary_title_icon)
		summary_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		summary_title_label.reparent(sum_header_row, false)
	summary_list.fixed_icon_size = Vector2i(20, 20)
	if leave_confirm_button != null:
		leave_confirm_button.icon = UiIcons.get_icon("door", 18)
		leave_confirm_button.custom_minimum_size = Vector2(148, 44)
	if leave_cancel_button != null:
		leave_cancel_button.custom_minimum_size = Vector2(148, 44)
	if summary_close_button != null:
		summary_close_button.icon = UiIcons.get_icon("check", 18)
		summary_close_button.custom_minimum_size = Vector2(180, 44)
	if host_lost_close_button != null:
		host_lost_close_button.icon = UiIcons.get_icon("check", 18)
		host_lost_close_button.custom_minimum_size = Vector2(148, 44)
	for emblem_path: NodePath in [^"%HostLostIcon", ^"%LeaveConfirmIcon"]:
		var emblem: TextureRect = get_node_or_null(emblem_path) as TextureRect
		if emblem != null:
			emblem.texture = UiIcons.get_icon("warning", 28)
	var backdrop: Control = get_node_or_null(^"%ModalBackdrop") as Control
	if backdrop != null:
		var sync_backdrop: Callable = func() -> void:
			var should_show: bool = summary_panel.visible or host_lost_panel.visible or leave_confirm_panel.visible
			var was_visible: bool = backdrop.visible
			backdrop.visible = should_show
			if should_show and not was_visible:
				UiMotion.fade_backdrop(backdrop, true)
			elif not should_show:
				UiMotion.stop(backdrop)
		for modal: Control in [summary_panel, host_lost_panel, leave_confirm_panel]:
			modal.visibility_changed.connect(sync_backdrop)
		sync_backdrop.call()


func _sync_loading_anim(loading_icon: TextureRect) -> void:
	if _loading_tween != null:
		_loading_tween.kill()
		_loading_tween = null
	var medallion: Control = get_node_or_null(^"%LoadingMedallion") as Control
	if medallion != null:
		medallion.scale = Vector2.ONE
	if loading_icon == null:
		return
	loading_icon.rotation_degrees = 0.0
	if loading_screen == null or not loading_screen.visible or not is_inside_tree():
		return
	loading_icon.pivot_offset = Vector2(28.0, 28.0)
	if UiMotion.is_instant():
		return
	if medallion != null:
		UiMotion.sync_center_pivot(medallion)
	_loading_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
	_loading_tween.tween_property(loading_icon, ^"rotation_degrees", 7.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if medallion != null:
		_loading_tween.parallel().tween_property(medallion, ^"scale", Vector2(1.038, 1.038), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loading_tween.tween_property(loading_icon, ^"rotation_degrees", -7.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if medallion != null:
		_loading_tween.parallel().tween_property(medallion, ^"scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _sync_toast_icon() -> void:
	if _toast_icon == null or toast_label == null:
		return
	var text: String = toast_label.text
	var icon_name: String = ""
	var show_icon: bool = not text.is_empty() and not text.begins_with("📖") and not text.begins_with("🏆")
	if show_icon:
		var low: String = text.to_lower()
		icon_name = "new"
		if low.contains("segredo") or low.contains("secret"):
			icon_name = "gem"
		elif low.contains("conquista") or low.contains("achievement"):
			icon_name = "trophy"
		elif low.contains("miss") or low.contains("quest") or low.contains("r$"):
			icon_name = "coin"
		elif low.contains("chave") or low.contains("key"):
			icon_name = "lock"
		_toast_icon.texture = UiIcons.get_icon(icon_name, 22)
		_toast_icon.visible = _toast_icon.texture != null
	else:
		_toast_icon.visible = false
	_apply_toast_accent(text.begins_with("🏆") or icon_name == "trophy" or icon_name == "lock", icon_name == "lock")
	_fit_toast_label_wrap()


func _apply_toast_accent(gold_border: bool, warm_fill: bool) -> void:
	if toast_panel == null:
		return
	if not gold_border:
		toast_panel.remove_theme_stylebox_override(&"panel")
		return
	var base: StyleBoxFlat = toast_panel.get_theme_stylebox(&"panel", &"ToastPanel") as StyleBoxFlat
	if base == null and toast_panel.theme != null:
		base = toast_panel.theme.get_stylebox(&"panel", &"ToastPanel") as StyleBoxFlat
	var box: StyleBoxFlat = base.duplicate() as StyleBoxFlat if base != null else StyleBoxFlat.new()
	if base == null:
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		box.content_margin_left = 14.0
		box.content_margin_right = 14.0
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
	box.bg_color = UiPalette.WOOD_DARK if warm_fill else UiPalette.GREEN_BOTTLE
	box.border_color = UiPalette.GOLD
	toast_panel.add_theme_stylebox_override(&"panel", box)


func _fit_toast_label_wrap() -> void:
	if toast_label == null or toast_panel == null:
		return
	var font: Font = toast_label.get_theme_font(&"font")
	var font_size: int = toast_label.get_theme_font_size(&"font_size")
	var rendered: String = toast_label.atr(toast_label.text)
	var text_w: float = font.get_string_size(rendered, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font != null else 0.0
	var icon_extra: float = 30.0 if (_toast_icon != null and _toast_icon.visible) else 0.0
	var panel_w: float = maxf(toast_panel.offset_right - toast_panel.offset_left, _toast_home.size.x)
	var avail_w: float = maxf(panel_w - 28.0 - icon_extra, 120.0)
	if text_w <= avail_w and not rendered.contains("\n"):
		toast_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		toast_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


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
	_connect_if_has(_session, &"expedition_start_failed", _dismiss_scene_loading.unbind(1))
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

func _is_world_shop_open() -> bool:
	if not is_inside_tree():
		return false
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	for shop: Node in tree.get_nodes_in_group(&"world_upgrade_shops"):
		if shop != null and is_instance_valid(shop) and shop.has_method(&"is_open") and bool(shop.call(&"is_open")):
			return true
	return false


func _refresh_expedition_bar() -> void:
	var was_visible: bool = expedition_bar.visible
	var in_expedition: bool = bool(_session_call(&"is_in_expedition", false)) \
			and not bool(_session_call(&"is_starting_expedition", false))
	var modal_blocking: bool = summary_panel.visible or host_lost_panel.visible or leave_confirm_panel.visible or _is_world_shop_open() or PauseMenu.is_open() or VictoryScreen.is_open() or DeathScreen.is_open()
	expedition_bar.visible = in_expedition and not loading_screen.visible and not modal_blocking
	var can_leave: bool = in_expedition and _is_online()
	# Solo/offline: "Voltar à base" (pausa) é o caminho; online, host e clientes podem sair.
	leave_button.visible = can_leave
	if not can_leave and leave_confirm_panel.visible:
		leave_confirm_panel.visible = false
		_update_mouse()
	if not in_expedition:
		return
	var night: bool = SessionManager.is_night()
	var bar_icon: TextureRect = expedition_info_label.get_node_or_null(^"Icon") as TextureRect
	if bar_icon != null:
		bar_icon.texture = UiIcons.get_icon("moon" if night else "map", 32)
	var map_name: String = tr("Mapa desconhecido")
	var map: MapData = _session_call(&"get_current_map") as MapData
	if map != null:
		map_name = tr(map.display_name) if not map.display_name.is_empty() else map.id
	if night:
		map_name = tr("%s (noite)") % map_name
	var day: int = GameState.instance.current_day if GameState.instance != null else 1
	expedition_info_label.text = tr("%s  •  Dia %d") % [map_name, day]
	leave_button.disabled = false
	if expedition_bar.visible and not was_visible:
		UiMotion.pop_in(expedition_bar, false, 0.96, 0.18)


## "Voltar à base" do menu de pausa (#122): só o host, em expedição. Retorna se pediu.
func request_return_to_base() -> bool:
	if not _is_host() or not bool(_session_call(&"is_in_expedition", false)) \
			or bool(_session_call(&"is_starting_expedition", false)):
		return false
	_session_call(&"request_end_expedition")
	return true


func _on_leave_pressed() -> void:
	leave_confirm_label.text = LEAVE_HOST_TEXT if _is_host() else LEAVE_CLIENT_TEXT
	leave_confirm_panel.visible = true
	UiMotion.pop_in(leave_confirm_panel, true)
	UiMotion.breathe_emblem(get_node_or_null(^"%LeaveConfirmIcon") as Control, 1.06, 2.5, 1.0, true)
	_update_mouse()
	_focus_panel([leave_cancel_button, leave_confirm_button], leave_cancel_button)
	expedition_bar.visible = false


func _on_leave_cancel_pressed() -> void:
	UiMotion.stop(get_node_or_null(^"%LeaveConfirmIcon") as Control, true)
	UiMotion.stop(leave_confirm_panel)
	leave_confirm_panel.visible = false
	_refresh_expedition_bar()
	_update_mouse()
	if summary_panel.visible and get_viewport().gui_get_focus_owner() == null:
		summary_close_button.grab_focus()
	_restore_focus()


func _on_leave_confirm_pressed() -> void:
	UiMotion.stop(get_node_or_null(^"%LeaveConfirmIcon") as Control, true)
	UiMotion.stop(leave_confirm_panel)
	leave_confirm_panel.visible = false
	_update_mouse()
	if NetworkManager.instance == null:
		push_warning("SessionUI: NetworkManager ausente; não foi possível sair da sessão.")
		return
	leave_button.disabled = true
	NetworkManager.instance.disconnect_game()


## O próprio peer saiu: o SessionManager volta ao lobby sozinho, sem host_lost nem resumo.
func _on_session_left(_was_host: bool) -> void:
	UiMotion.stop(get_node_or_null(^"%LeaveConfirmIcon") as Control, true)
	UiMotion.stop(leave_confirm_panel)
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
	var was_loading: bool = loading_screen.visible
	loading_screen.visible = true
	if not was_loading:
		UiMotion.pop_in(get_node_or_null(^"%LoadingCard") as Control, true, 0.95, 0.20)
	_refresh_expedition_bar()
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
	while is_inside_tree() and token == _loading_token:
		var session: SessionManager = _session as SessionManager
		if not is_instance_valid(session) or not session.is_starting_expedition():
			loading_screen.visible = false
			_refresh_expedition_bar()
			refresh_save_toast_layout()
			return
		await tree.process_frame


func _on_expedition_started(_map_id: String) -> void:
	_refresh_expedition_bar()


func _dismiss_scene_loading() -> void:
	_loading_token += 1
	loading_screen.hide()
	_refresh_expedition_bar()


func _on_passage_travel_failed(message: String) -> void:
	_dismiss_scene_loading()
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
	if _summary_money_tween != null:
		_summary_money_tween.kill()
		_summary_money_tween = null
	UiMotion.stop(summary_panel)
	UiMotion.stop(get_node_or_null(^"%LeaveConfirmIcon") as Control, true)
	UiMotion.stop(leave_confirm_panel)
	summary_panel.visible = false
	leave_confirm_panel.visible = false
	host_lost_panel.visible = true
	UiMotion.pop_in(host_lost_panel, true)
	UiMotion.breathe_emblem(get_node_or_null(^"%HostLostIcon") as Control, 1.06, 2.5, 1.0, true)
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
	UiMotion.stop(toast_panel)
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
		UiMotion.stop(toast_panel)
		toast_panel.visible = false
		return
	toast_label.text = _toast_queue.pop_front()
	_sync_toast_icon()
	toast_panel.visible = true
	_place_toast()
	UiMotion.toast_enter(toast_panel, _toast_icon, true)
	_toast_token += 1
	var token: int = _toast_token
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if UiMotion.is_instant():
		await tree.create_timer(TOAST_SEC, true, false, true).timeout
		if not is_inside_tree() or token != _toast_token:
			return
		_show_next_toast()
		return
	await tree.create_timer(maxf(TOAST_SEC - UiMotion.TOAST_OUT_DURATION, 0.1), true, false, true).timeout
	if not is_inside_tree() or token != _toast_token:
		return
	var exit_tw: Tween = toast_panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	exit_tw.tween_property(toast_panel, ^"modulate:a", 0.0, UiMotion.TOAST_OUT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	toast_panel.set_meta(UiMotion.META_TWEEN, exit_tw)
	await exit_tw.finished
	if not is_inside_tree() or token != _toast_token:
		return
	_show_next_toast()


## Na expedição o aviso fica no lugar da cena; na Base sobe para o topo, centrado no vão livre
## entre o que está à esquerda (chips) e à direita (menu Multiplayer), e estreita se faltar espaço.
func _place_toast() -> void:
	var home: Rect2 = _toast_home
	var view: Rect2 = toast_panel.get_viewport_rect()
	var safe_width: float = minf(home.size.x, view.size.x * 0.9)
	toast_panel.offset_left = -safe_width * 0.5
	toast_panel.offset_right = safe_width * 0.5
	toast_panel.offset_top = home.position.y
	toast_panel.offset_bottom = home.end.y
	# A conquista chega antes de game_victory. Ao abrir, a vitória reposiciona
	# esse mesmo aviso, sem tocar na fila, token ou prazo de expiração.
	if VictoryScreen.is_open():
		toast_panel.offset_top = TOAST_BASE_TOP
		_fit_toast_height()
		return
	if bool(_session_call(&"is_in_expedition", false)):
		_fit_toast_height()
		return
	var strip_bottom: float = TOAST_BASE_TOP + maxf(home.size.y, toast_panel.get_combined_minimum_size().y)
	var strip: Vector2 = _free_toast_strip(view, TOAST_BASE_TOP, strip_bottom)
	var width: float = minf(safe_width, strip.y - strip.x)
	var center: float = (strip.x + strip.y) * 0.5 - view.size.x * 0.5
	toast_panel.offset_left = center - width * 0.5
	toast_panel.offset_right = center + width * 0.5
	toast_panel.offset_top = TOAST_BASE_TOP
	_fit_toast_height()


func _free_toast_strip(view: Rect2, top: float, bottom: float) -> Vector2:
	var free_left: float = 0.0
	var free_right: float = view.size.x
	for rect: Rect2 in _toast_avoid_rects():
		if not rect.has_area() or rect.position.y > bottom + SAVE_TOAST_GAP or rect.end.y < top:
			continue
		if rect.get_center().x < view.size.x * 0.5:
			free_left = maxf(free_left, rect.end.x + SAVE_TOAST_GAP)
		else:
			free_right = minf(free_right, rect.position.x - SAVE_TOAST_GAP)
	return Vector2(free_left, free_right)


## Altura do texto completo; nenhum reposicionamento reinicia a fila ou o timer.
func _fit_toast_height() -> void:
	_fit_toast_label_wrap()
	var height: float = maxf(_toast_home.size.y, toast_panel.get_combined_minimum_size().y)
	toast_panel.offset_bottom = toast_panel.offset_top + height
	if save_toast_panel != null and save_toast_panel.visible:
		var save_rect: Rect2 = save_toast_rect()
		if toast_panel.get_global_rect().intersects(save_rect):
			toast_panel.offset_top = save_rect.end.y + SAVE_TOAST_GAP
			toast_panel.offset_bottom = toast_panel.offset_top + height
	if VictoryScreen.is_open():
		VictoryScreen.instance.reserve_notice_space(toast_panel.offset_bottom + SAVE_TOAST_GAP)


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
	var err_base: StyleBoxFlat = toast_panel.theme.get_stylebox(&"panel", &"ToastPanel") as StyleBoxFlat if toast_panel.theme != null else null
	var err_box: StyleBoxFlat = err_base.duplicate() as StyleBoxFlat if err_base != null else StyleBoxFlat.new()
	if err_base == null:
		err_box.set_border_width_all(2)
		err_box.border_color = UiPalette.INK
		err_box.set_corner_radius_all(6)
		err_box.content_margin_left = 14.0
		err_box.content_margin_right = 14.0
		err_box.content_margin_top = 8.0
		err_box.content_margin_bottom = 8.0
	err_box.bg_color = UiPalette.RED_BURNT
	err_box.border_color = UiPalette.INK
	save_toast_panel.add_theme_stylebox_override(&"panel", err_box)
	save_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_reset_save_toast_place()
	save_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	save_toast_panel.visible = false
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "SaveToastRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	save_toast_panel.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.name = "SaveToastIcon"
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = UiIcons.get_icon("warning", 22)
	row.add_child(icon)
	save_toast_label = Label.new()
	save_toast_label.theme_type_variation = &"ToastLabel"
	save_toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	save_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(save_toast_label)
	add_child(save_toast_panel)
	for changed: Signal in [save_toast_panel.resized, save_toast_panel.visibility_changed]:
		changed.connect(func() -> void:
			if toast_panel.visible:
				_place_toast(), CONNECT_DEFERRED)


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
	_save_toast_active = true
	save_toast_label.text = text
	save_toast_panel.visible = true
	_reset_save_toast_place()
	var save_icon: Control = save_toast_panel.find_child("SaveToastIcon", true, false) as Control
	UiMotion.toast_enter(save_toast_panel, save_icon, true)
	# Depois dos outros ouvintes do sinal: o painel do menu já tem o aviso dele.
	refresh_save_toast_layout.call_deferred()
	_save_toast_token += 1
	var token: int = _save_toast_token
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if UiMotion.is_instant():
		await tree.create_timer(SAVE_TOAST_SEC, true, false, true).timeout
		if is_inside_tree() and token == _save_toast_token:
			hide_save_toast()
		return
	await tree.create_timer(maxf(SAVE_TOAST_SEC - UiMotion.TOAST_OUT_DURATION, 0.1), true, false, true).timeout
	if not is_inside_tree() or token != _save_toast_token:
		return
	var exit_tw: Tween = save_toast_panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	exit_tw.tween_property(save_toast_panel, ^"modulate:a", 0.0, UiMotion.TOAST_OUT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	save_toast_panel.set_meta(UiMotion.META_TWEEN, exit_tw)
	await exit_tw.finished
	if is_inside_tree() and token == _save_toast_token:
		hide_save_toast()


func _reset_save_toast_place() -> void:
	save_toast_panel.offset_left = -SAVE_TOAST_WIDTH * 0.5
	save_toast_panel.offset_right = SAVE_TOAST_WIDTH * 0.5
	save_toast_panel.offset_top = SAVE_TOAST_TOP
	save_toast_panel.offset_bottom = SAVE_TOAST_TOP


## No título o MultiplayerMenu mostra o aviso no painel dele (#137): o mesmo texto lá = some o
## toast (o painel fica com ele, perto de Continuar/Novo jogo); outro texto = o toast vai para o
## lado livre do menu e, sem largura, para baixo dele. Na Base, aproveita a faixa acima do painel.
func refresh_save_toast_layout() -> void:
	if save_toast_panel == null or not _save_toast_active:
		return
	_reset_save_toast_place()
	var text: String = save_toast_label.atr(save_toast_label.text)
	var view: Rect2 = save_toast_panel.get_viewport_rect()
	var menu_rects: Array[Rect2] = []
	for node: Node in get_tree().get_nodes_in_group(MultiplayerMenu.SAVE_NOTICE_GROUP):
		if not node.has_method(&"get_save_notice_rect"):
			continue
		if str(node.call(&"get_save_notice")) == text:
			# O mesmo aviso pode voltar ao toast se o menu recolher antes do prazo.
			save_toast_panel.hide()
			return
		menu_rects.append(node.call(&"get_save_notice_rect"))
	save_toast_panel.show()
	for node: Node in get_tree().get_nodes_in_group(SAVE_TOAST_AVOID_GROUP):
		var panel: Control = node as Control
		if panel == null or not panel.is_visible_in_tree():
			continue
		var avoid: Rect2 = panel.get_global_rect()
		if not save_toast_rect().intersects(avoid):
			continue
		if not _place_save_toast_above_base(avoid, view):
			_place_save_toast_beside(avoid, view)
	for avoid: Rect2 in menu_rects:
		if avoid.has_area() and save_toast_rect().intersects(avoid):
			_place_save_toast_beside(avoid, view)
	if toast_panel.visible:
		_place_toast()


func _place_save_toast_above_base(base: Rect2, view: Rect2) -> bool:
	var strip: Vector2 = _free_toast_strip(view, TOAST_BASE_TOP, base.position.y - SAVE_TOAST_GAP)
	var width: float = minf(SAVE_TOAST_WIDTH, strip.y - strip.x)
	if width < SAVE_TOAST_MIN_WIDTH:
		return false
	var center: float = (strip.x + strip.y) * 0.5 - view.size.x * 0.5
	save_toast_panel.offset_left = center - width * 0.5
	save_toast_panel.offset_right = center + width * 0.5
	save_toast_panel.offset_top = TOAST_BASE_TOP
	save_toast_panel.offset_bottom = TOAST_BASE_TOP
	return true


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
	_save_toast_active = false
	if save_toast_panel != null:
		UiMotion.stop(save_toast_panel)
		save_toast_panel.visible = false


# --- Resumo do dia ------------------------------------------------------------

## Idioma trocado (#131): a barra da expedição e o resumo aberto são montados por código.
func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready() or expedition_bar == null:
		return
	refresh_save_toast_layout.call_deferred()
	_refresh_expedition_bar()
	if summary_panel.visible and not _last_summary.is_empty():
		_show_summary(_last_summary)


## O resumo vem do host com os nomes em PT-BR (as chaves): a tradução é aqui, na tela de cada um.
func _show_summary(summary: Dictionary) -> void:
	_last_summary = summary
	var day: int = int(summary.get("day", 0))
	var is_night: bool = bool(summary.get("night", false))
	var map_name: String = tr(str(summary.get("map_name", summary.get("map_id", ""))))
	if is_night:
		map_name = tr("%s (noite)") % map_name
	if _summary_title_icon != null:
		_summary_title_icon.texture = UiIcons.get_icon("moon" if is_night else "sun", 32)
	summary_title_label.text = tr("Resumo do Dia %d — %s") % [day, map_name]
	var title_font: Font = summary_title_label.get_theme_font(&"font")
	var title_size: int = summary_title_label.get_theme_font_size(&"font_size")
	var title_w: float = title_font.get_string_size(summary_title_label.atr(summary_title_label.text), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x if title_font != null else 0.0
	if title_w > 480.0:
		summary_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		summary_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		summary_title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	summary_list.clear()
	var entries: Array = []
	if summary.get("entries") is Array:
		entries = summary["entries"] as Array
	summary_list.fixed_icon_size = Vector2i(20, 20)
	var sold: int = 0
	var donated: int = 0
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var e: Dictionary = entry as Dictionary
		var amount: int = int(e.get("value", 0))
		var action_text: String
		var is_donated: bool = false
		match e.get("action"):
			"sold":
				sold += amount
				action_text = tr("Vendido")
			"donated":
				donated += amount
				action_text = tr("Doado ao museu")
				is_donated = true
			_:
				continue
		var icon: Texture2D = UiIcons.get_icon("museum" if is_donated else "coin", 24)
		var row_idx: int = summary_list.add_item("%s — %s (+%s)" % [tr(str(e.get("name", "?"))), action_text, UiFormat.money(amount)], icon)
		summary_list.set_item_custom_bg_color(row_idx, Color(UiPalette.GREEN_BOTTLE, 0.08) if is_donated else Color(UiPalette.GOLD, 0.08))
	if summary_list.item_count == 0:
		var empty_idx: int = summary_list.add_item(tr("Nenhum item vendido ou doado nesta expedição."), UiIcons.get_icon("compass", 24))
		summary_list.set_item_custom_fg_color(empty_idx, UiPalette.WOOD)
	if _summary_money_tween != null:
		_summary_money_tween.kill()
		_summary_money_tween = null
	summary_total_label.text = _format_summary_total(sold, donated, summary, 1.0)
	var already_open: bool = summary_panel.visible
	summary_panel.visible = true
	if not already_open:
		UiMotion.pop_in(summary_panel, true)
		UiMotion.switch_tab_page(summary_list, true, 0.16)
		var total_icon_ctrl: Control = get_node_or_null(^"%SummaryTotalIcon") as Control
		UiMotion.pulse(total_icon_ctrl, 1.18, 0.24, true)
		if total_icon_ctrl != null and total_icon_ctrl.get_parent() != null:
			UiMotion.pulse(total_icon_ctrl.get_parent().get_parent() as Control, 1.022, 0.20, true)
		if not UiMotion.is_instant() and int(summary.get("money_earned", 0)) > 0 and is_inside_tree():
			summary_total_label.text = _format_summary_total(sold, donated, summary, 0.0)
			_summary_money_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_summary_money_tween.tween_method(func(ratio: float) -> void:
				if summary_total_label != null:
					summary_total_label.text = _format_summary_total(sold, donated, summary, ratio),
				0.0, 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_summary_money_tween.tween_callback(func() -> void:
				if summary_total_label != null:
					summary_total_label.text = _format_summary_total(sold, donated, summary, 1.0)
				_summary_money_tween = null)
	_update_mouse()
	_focus_panel([summary_list, summary_close_button], summary_close_button)
	expedition_bar.visible = false


func _format_summary_total(sold_val: int, donated_val: int, summary: Dictionary, ratio: float) -> String:
	var cur_sold: int = roundi(float(sold_val) * ratio)
	var cur_donated: int = roundi(float(donated_val) * ratio)
	var money_end: int = int(summary.get("money_end", 0))
	var earned: int = int(summary.get("money_earned", 0))
	var money_start: int = int(summary.get("money_start", money_end - earned))
	var balance: String = UiFormat.money(money_end)
	if summary.has("money_start"):
		balance = "%s → %s" % [UiFormat.money(money_start), balance]
	var total_line: String = tr("Saldo da equipe: %s") % balance
	if earned > 0:
		var shown_end: int = roundi(lerpf(float(money_start), float(money_end), ratio))
		total_line = tr("Total ganho: %s  (saldo: %s → %s)") % [
			UiFormat.money(roundi(float(earned) * ratio)), UiFormat.money(money_start), UiFormat.money(shown_end),
		]
	return "\n".join(PackedStringArray([
		"%s  +%s" % [tr("Vendido"), UiFormat.money(cur_sold)],
		"%s  +%s" % [tr("Doado ao museu"), UiFormat.money(cur_donated)],
		total_line,
	]))


func _on_summary_close_pressed() -> void:
	if _summary_money_tween != null:
		_summary_money_tween.kill()
		_summary_money_tween = null
	UiMotion.stop(summary_panel)
	summary_panel.visible = false
	if not leave_confirm_panel.visible:
		_refresh_expedition_bar()
	_update_mouse()
	if leave_confirm_panel.visible:
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus == null or not leave_confirm_panel.is_ancestor_of(focus):
			leave_cancel_button.grab_focus()
	_restore_focus()


func _on_host_lost_close_pressed() -> void:
	UiMotion.stop(get_node_or_null(^"%HostLostIcon") as Control, true)
	UiMotion.stop(host_lost_panel)
	host_lost_panel.visible = false
	_update_mouse()
	_restore_focus()


# --- Mouse --------------------------------------------------------------------

func _update_mouse() -> void:
	var any_open: bool = summary_panel.visible or host_lost_panel.visible or leave_confirm_panel.visible
	if any_open and not _mouse_released:
		_previous_mouse_mode = Input.mouse_mode
		var scene: Node = get_tree().current_scene
		_mouse_gameplay_scene_id = scene.get_instance_id() if is_instance_valid(scene) and bool(_session_call(&"is_in_expedition", false)) else 0
		_mouse_released = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not any_open and _mouse_released:
		_mouse_released = false
		var scene: Node = get_tree().current_scene
		var same_gameplay: bool = is_instance_valid(scene) and scene.get_instance_id() == _mouse_gameplay_scene_id and bool(_session_call(&"is_in_expedition", false))
		# A return clears the map before the deferred scene change; its old cursor is stale.
		Input.mouse_mode = _previous_mouse_mode if same_gameplay and not UiFocus.modal_open() else Input.MOUSE_MODE_VISIBLE
		_mouse_gameplay_scene_id = 0


func _process(_delta: float) -> void:
	# O player recaptura o mouse ao clicar; mantém visível enquanto houver painel aberto.
	if _mouse_released and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
