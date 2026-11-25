class_name DeathScreen
extends CanvasLayer

## Tela de morte (#244): exibida quando o jogador local desmaia fora do estado caído (downed)
## de coop. Em solo pausa a árvore enquanto aberta; oferece "Continuar expedição" (no ponto de
## partida) e "Voltar à base" (para o host em expedição). Camada 47: acima da pausa (45) e da
## vitória (46), abaixo da SessionUI (50) para o carregamento e a queda do host cobrirem.

signal open_changed(open: bool)

const THEME: Theme = preload("res://ui/theme/scandig_theme.tres")
const FADE_DURATION: float = 0.16

const TITLE_TEXT: String = "Você desmaiou!"
const SUBTITLE_TEXT: String = "Você acordou de volta no ponto de partida."
const BAG_EMPTY_TEXT: String = "Sua mochila estava vazia; nada foi perdido."
const BAG_ONE_TEXT: String = "A mochila caiu no local da morte (1 item) — volte para pegar!"
const BAG_MANY_TEXT: String = "A mochila caiu no local da morte (%d itens) — volte para pegar!"
const CONTINUE_TEXT: String = "Continuar expedição"
const RETURN_BASE_TEXT: String = "Voltar à base"

static var instance: DeathScreen = null

var root_control: Control = null
var card: PanelContainer = null
var skull_badge: PanelContainer = null
var info_card: PanelContainer = null
var title_label: Label = null
var subtitle_label: Label = null
var location_row: HBoxContainer = null
var location_label: Label = null
var bag_icon: TextureRect = null
var bag_label: Label = null
var continue_button: Button = null
var return_base_button: Button = null

var _open: bool = false
var _paused_by_me: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _focus_before: Control = null
var _tween: Tween = null
var _badge_tween: Tween = null
var _context: Dictionary = {}
var _connected_players: Dictionary = {}


static func is_open() -> bool:
	return instance != null and instance._open


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if _paused_by_me and is_inside_tree():
		get_tree().paused = false
		_paused_by_me = false


func _ready() -> void:
	layer = 47
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	root_control.visible = false
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.node_added.connect(_on_node_added)
		_scan_local_players.call_deferred()
	_connect_session_signals.call_deferred()


func _connect_session_signals() -> void:
	var sm: SessionManager = SessionManager.instance
	if sm != null:
		if not sm.scene_changing.is_connected(_on_close_trigger):
			sm.scene_changing.connect(_on_close_trigger)
		if not sm.expedition_ended.is_connected(_on_close_trigger):
			sm.expedition_ended.connect(_on_close_trigger)
		if not sm.host_lost.is_connected(_on_host_lost):
			sm.host_lost.connect(_on_host_lost)
		if not sm.scene_loaded.is_connected(_on_scene_loaded):
			sm.scene_loaded.connect(_on_scene_loaded)
	if NetworkManager.instance != null and NetworkManager.instance.has_signal(&"session_left"):
		if not NetworkManager.instance.is_connected(&"session_left", _on_close_trigger):
			NetworkManager.instance.connect(&"session_left", _on_close_trigger)


func _on_close_trigger(_arg: Variant = null) -> void:
	if _open:
		close(false)


func _on_host_lost() -> void:
	if _open:
		close(false)


func _on_scene_loaded(_path: String) -> void:
	_scan_local_players()


func _on_node_added(node: Node) -> void:
	_try_watch_player(node)


func _scan_local_players() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(Player.LOCAL_GROUP):
		_try_watch_player(node)


func _try_watch_player(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.has_signal(&"died") or not node.has_method(&"is_local"):
		return
	var id: int = node.get_instance_id()
	if _connected_players.has(id):
		return
	_connected_players[id] = true
	var on_died: Callable = _on_player_died.bind(node)
	node.connect(&"died", on_died)
	node.tree_exiting.connect(func() -> void: _connected_players.erase(id))


## Captura a contagem de itens ANTES de Player._drop_all_items() rodar no mesmo frame e aguarda
## call_deferred para respeitar o estado downed do coop (definido logo após died.emit()).
func _on_player_died(player: Node) -> void:
	if not is_instance_valid(player) or not bool(player.call(&"is_local")):
		return
	var dropped_items: int = 0
	var inv: Variant = player.get(&"inventory")
	if inv is Object and is_instance_valid(inv as Object) and (inv as Object).has_method(&"get_count"):
		dropped_items = int((inv as Object).call(&"get_count"))
	_open_after_die.call_deferred(player, dropped_items)


func _open_after_die(player: Node, dropped_items: int) -> void:
	if not is_inside_tree() or not is_instance_valid(player):
		return
	if not bool(player.call(&"is_local")):
		return
	if &"is_downed" in player and bool(player.get(&"is_downed")):
		return
	var sm: SessionManager = SessionManager.instance
	if sm == null or not sm.is_in_expedition():
		return
	if VictoryScreen.is_open():
		return
	var ui: SessionUI = SessionUI.instance
	if ui != null:
		for blocking: Control in [ui.loading_screen, ui.summary_panel, ui.host_lost_panel]:
			if blocking != null and blocking.visible:
				return
	var map: MapData = sm.get_current_map()
	var map_name: String = ""
	if map != null:
		map_name = map.display_name if not map.display_name.is_empty() else map.id
	var day: int = GameState.instance.current_day if GameState.instance != null else 1
	open({
		"dropped_items": dropped_items,
		"map_name": map_name,
		"day": day,
	})


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _open:
		_apply_texts()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(&"ui_cancel", false, true) or event.is_action_pressed(&"pause", false, true):
		close(true)
		get_viewport().set_input_as_handled()


# --- Abrir / fechar ------------------------------------------------------------

func open(context: Dictionary = {}) -> void:
	if root_control == null:
		return
	_context = context.duplicate()
	if PauseMenu.is_open() and PauseMenu.instance != null:
		PauseMenu.instance.close()
	var was_open: bool = _open
	_open = true
	_apply_texts()
	var can_return: bool = _can_return_to_base()
	return_base_button.visible = can_return
	root_control.visible = true
	if not was_open:
		_focus_before = get_viewport().gui_get_focus_owner()
		_previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if SessionUI.instance != null and SessionUI.instance.expedition_bar != null:
			SessionUI.instance.expedition_bar.visible = false
		if not _is_online() and not get_tree().paused:
			get_tree().paused = true
			_paused_by_me = true
		_animate_open()
		open_changed.emit(true)
	_link_focus()
	continue_button.grab_focus()


func close(restore_gameplay: bool = true) -> void:
	if not _open:
		return
	_open = false
	root_control.visible = false
	_reset_animation()
	if _paused_by_me and is_inside_tree():
		get_tree().paused = false
	_paused_by_me = false
	if restore_gameplay:
		var in_expedition: bool = SessionManager.instance != null and SessionManager.instance.is_in_expedition()
		Input.mouse_mode = _previous_mouse_mode if in_expedition and not UiFocus.modal_open() else Input.MOUSE_MODE_VISIBLE
		if SessionUI.instance != null and SessionUI.instance.expedition_bar != null:
			SessionUI.instance.call(&"_refresh_expedition_bar")
		var before: Control = _focus_before
		_focus_before = null
		if is_instance_valid(before) and before.is_visible_in_tree():
			before.grab_focus()
	else:
		_focus_before = null
		if not UiFocus.modal_open():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	open_changed.emit(false)


func _is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func _is_host() -> bool:
	return GameState.instance.is_authority() if GameState.instance != null else multiplayer.is_server()


func _can_return_to_base() -> bool:
	if not _is_host():
		return false
	var sm: SessionManager = SessionManager.instance
	return sm != null and sm.is_in_expedition()


# --- Montagem ------------------------------------------------------------------

func _build() -> void:
	root_control = Control.new()
	root_control.name = "Root"
	root_control.theme = THEME
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.18, 0.06, 0.05, 0.76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(dim)

	var center: FitCenterContainer = FitCenterContainer.new()
	center.margin = 20.0
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	UiFocus.follow_pointer(center)

	card = PanelContainer.new()
	card.name = "DeathCard"
	card.theme_type_variation = &"WornPanel"
	card.custom_minimum_size = Vector2(500, 0)
	center.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 24)
	margin.add_theme_constant_override(&"margin_right", 24)
	margin.add_theme_constant_override(&"margin_top", 22)
	margin.add_theme_constant_override(&"margin_bottom", 22)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 12)
	margin.add_child(vbox)

	# Emblema circular vermelho-queimado com a caveira em traço INK.
	skull_badge = PanelContainer.new()
	skull_badge.name = "SkullBadge"
	skull_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = UiPalette.RED_BURNT
	badge_style.border_color = UiPalette.INK
	badge_style.set_border_width_all(3)
	badge_style.set_corner_radius_all(34)
	badge_style.shadow_color = UiPalette.SHADOW
	badge_style.shadow_size = 1
	badge_style.shadow_offset = Vector2(2, 3)
	badge_style.content_margin_left = 12.0
	badge_style.content_margin_right = 12.0
	badge_style.content_margin_top = 12.0
	badge_style.content_margin_bottom = 12.0
	skull_badge.add_theme_stylebox_override(&"panel", badge_style)
	var skull: TextureRect = TextureRect.new()
	skull.name = "SkullIcon"
	skull.texture = UiIcons.get_icon("skull", 64)
	skull.custom_minimum_size = Vector2(40, 40)
	skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skull_badge.add_child(skull)
	vbox.add_child(skull_badge)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.theme_type_variation = &"TitleLabel"
	title_label.add_theme_color_override(&"font_color", UiPalette.RED_BURNT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle_label)

	vbox.add_child(HSeparator.new())

	# Cartão interno com mapa/dia e situação da mochila.
	info_card = PanelContainer.new()
	info_card.name = "InfoCard"
	info_card.theme_type_variation = &"InsetPanel"
	vbox.add_child(info_card)

	var info_margin: MarginContainer = MarginContainer.new()
	info_margin.add_theme_constant_override(&"margin_left", 6)
	info_margin.add_theme_constant_override(&"margin_right", 6)
	info_margin.add_theme_constant_override(&"margin_top", 4)
	info_margin.add_theme_constant_override(&"margin_bottom", 4)
	info_card.add_child(info_margin)

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.add_theme_constant_override(&"separation", 8)
	info_margin.add_child(info_box)

	location_row = HBoxContainer.new()
	location_row.alignment = BoxContainer.ALIGNMENT_CENTER
	location_row.add_theme_constant_override(&"separation", 6)
	var map_icon: TextureRect = TextureRect.new()
	map_icon.texture = UiIcons.get_icon("map", 24)
	map_icon.custom_minimum_size = Vector2(18, 18)
	map_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	location_row.add_child(map_icon)
	location_label = Label.new()
	location_label.name = "LocationLabel"
	location_label.theme_type_variation = &"HintLabel"
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_row.add_child(location_label)
	info_box.add_child(location_row)

	var bag_row: HBoxContainer = HBoxContainer.new()
	bag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bag_row.add_theme_constant_override(&"separation", 8)
	bag_icon = TextureRect.new()
	bag_icon.texture = UiIcons.get_icon("backpack", 24)
	bag_icon.custom_minimum_size = Vector2(20, 20)
	bag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bag_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bag_row.add_child(bag_icon)
	bag_label = Label.new()
	bag_label.name = "BagLabel"
	bag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bag_row.add_child(bag_label)
	info_box.add_child(bag_row)

	vbox.add_child(HSeparator.new())

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override(&"separation", 12)
	vbox.add_child(actions)

	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.theme_type_variation = &"PrimaryButton"
	continue_button.icon = UiIcons.get_icon("play", 20)
	continue_button.custom_minimum_size = Vector2(210, 46)
	continue_button.focus_mode = Control.FOCUS_ALL
	continue_button.pressed.connect(_on_continue_pressed)
	actions.add_child(continue_button)

	return_base_button = Button.new()
	return_base_button.name = "ReturnBaseButton"
	return_base_button.icon = UiIcons.get_icon("map", 20)
	return_base_button.custom_minimum_size = Vector2(180, 46)
	return_base_button.focus_mode = Control.FOCUS_ALL
	return_base_button.pressed.connect(_on_return_base_pressed)
	actions.add_child(return_base_button)


func _apply_texts() -> void:
	title_label.text = tr(TITLE_TEXT)
	subtitle_label.text = tr(SUBTITLE_TEXT)
	continue_button.text = tr(CONTINUE_TEXT)
	return_base_button.text = tr(RETURN_BASE_TEXT)

	var map_name: String = str(_context.get("map_name", ""))
	var day: int = int(_context.get("day", 0))
	if not map_name.is_empty():
		var shown_day: int = day if day > 0 else (GameState.instance.current_day if GameState.instance != null else 1)
		location_label.text = tr("%s  •  Dia %d") % [tr(map_name), shown_day]
		location_row.visible = true
	else:
		location_row.visible = false

	var dropped: int = int(_context.get("dropped_items", 0))
	var info_style: StyleBoxFlat = StyleBoxFlat.new()
	info_style.bg_color = UiPalette.PAPER_LIGHT
	info_style.set_border_width_all(2)
	info_style.border_width_left = 4
	info_style.set_corner_radius_all(4)
	info_style.content_margin_left = 8.0
	info_style.content_margin_right = 8.0
	info_style.content_margin_top = 6.0
	info_style.content_margin_bottom = 6.0
	if dropped > 1:
		bag_label.text = tr(BAG_MANY_TEXT) % dropped
		bag_label.add_theme_color_override(&"font_color", UiPalette.RED_BURNT)
		info_style.border_color = Color(UiPalette.RED_BURNT, 0.78)
		if bag_icon != null:
			bag_icon.texture = UiIcons.get_icon("backpack", 24)
	elif dropped == 1:
		bag_label.text = tr(BAG_ONE_TEXT)
		bag_label.add_theme_color_override(&"font_color", UiPalette.RED_BURNT)
		info_style.border_color = Color(UiPalette.RED_BURNT, 0.78)
		if bag_icon != null:
			bag_icon.texture = UiIcons.get_icon("backpack", 24)
	else:
		bag_label.text = tr(BAG_EMPTY_TEXT)
		bag_label.add_theme_color_override(&"font_color", UiPalette.GREEN_BOTTLE)
		info_style.border_color = Color(UiPalette.GREEN_BOTTLE, 0.78)
		if bag_icon != null:
			bag_icon.texture = UiIcons.get_icon("check", 24)
	if info_card != null:
		info_card.add_theme_stylebox_override(&"panel", info_style)


func _link_focus() -> void:
	var buttons: Array = [continue_button]
	if return_base_button.visible:
		buttons.append(return_base_button)
	UiFocus.link_chain(buttons)
	UiFocus.link_row(buttons)


func _animate_open() -> void:
	_reset_animation()
	root_control.modulate.a = 0.78
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(root_control, ^"modulate:a", 1.0, FADE_DURATION)
	_start_badge_pulse.call_deferred()


func _start_badge_pulse() -> void:
	if not _open or skull_badge == null or not is_inside_tree():
		return
	skull_badge.pivot_offset = skull_badge.size * 0.5
	if _badge_tween != null:
		_badge_tween.kill()
	_badge_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
	_badge_tween.tween_property(skull_badge, ^"scale", Vector2(1.045, 1.045), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_badge_tween.tween_property(skull_badge, ^"scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _reset_animation() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if _badge_tween != null:
		_badge_tween.kill()
		_badge_tween = null
	if skull_badge != null:
		skull_badge.scale = Vector2.ONE
	if root_control != null:
		root_control.modulate.a = 1.0


func _on_continue_pressed() -> void:
	close(true)


func _on_return_base_pressed() -> void:
	close(false)
	var ui: SessionUI = SessionUI.instance
	if ui != null:
		ui.request_return_to_base()
