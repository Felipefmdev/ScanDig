class_name MuseumView
extends CanvasLayer

## "Ver museu" (aba Museu da Base): a câmera do lobby sai da tenda e vai, num Tween suave, até a
## frente da vitrine (MuseumDisplay). Os painéis da Base e o HUD dão lugar ao cabeçalho do museu
## e ao botão "Voltar". Voltar, Esc ou B (ui_cancel) restauram a câmera e a interface da Base.
## Um nó destes no lobby_base; a BaseStationUI o acha pelo grupo GROUP.

signal opened
signal closed

const GROUP: StringName = &"museum_view"
const TWEEN_TIME: float = 0.9
## Câmera na frente da estante, em coordenadas do MuseumDisplay (frente = +Z): perto o bastante
## para ler as plaquinhas em 960x540, com a estante inteira e o pedestal do ídolo à vista.
const VIEW_OFFSET: Vector3 = Vector3(0.0, 1.55, 3.6)
const VIEW_TARGET: Vector3 = Vector3(0.0, 1.05, 0.0)
const BACK_MARGIN: float = 24.0

@export var camera_path: NodePath = ^"../Camera3D"
@export var museum_path: NodePath = ^"../MuseumDisplay"
## Camadas escondidas durante a vista (os painéis da Base e o menu de rede).
@export var hide_paths: Array[NodePath] = [^"../UILayer"]

var back_button: Button = null
var _header: PanelContainer = null
var _header_title: Label = null
var _header_progress: Label = null
var _open: bool = false
var _tent_transform: Transform3D = Transform3D.IDENTITY
var _tween: Tween = null
## Nó escondido -> visibilidade anterior.
var _hidden: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	layer = 5
	var camera: Camera3D = get_node_or_null(camera_path) as Camera3D
	if camera != null:
		_tent_transform = camera.transform
	_build_back_button()
	_build_header()
	_refresh_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _header_progress != null:
		_refresh_text()


func _refresh_text() -> void:
	back_button.text = tr("Voltar")
	_header_title.text = tr("Museu de Achados")
	var game_state: GameState = GameState.instance
	var discovered: int = game_state.discovered_items.size() if game_state != null else 0
	var total: int = game_state.get_total_catalog_items() if game_state != null else 0
	_header_progress.text = tr("Museu  %d/%d") % [discovered, total]


func is_open() -> bool:
	return _open


func is_available() -> bool:
	return get_node_or_null(camera_path) is Camera3D and get_node_or_null(museum_path) is Node3D


## Transform (global) da câmera olhando a vitrine.
func get_view_transform() -> Transform3D:
	var museum: Node3D = get_node(museum_path) as Node3D
	var local: Transform3D = Transform3D(Basis.IDENTITY, VIEW_OFFSET).looking_at(VIEW_TARGET, Vector3.UP)
	return museum.global_transform * local


## Transform (local, como na cena) da câmera na tenda.
func get_tent_transform() -> Transform3D:
	return _tent_transform


func open() -> void:
	if _open or not is_available():
		return
	_open = true
	_hidden.clear()
	for path: NodePath in hide_paths:
		var node: Node = get_node_or_null(path)
		if node != null and "visible" in node:
			_hidden[node] = node.get(&"visible")
			node.set(&"visible", false)
	var hud: Node = get_parent().get_node_or_null(^"HUD") if get_parent() != null else null
	if hud != null and "visible" in hud and not _hidden.has(hud):
		_hidden[hud] = hud.get(&"visible")
		hud.set(&"visible", false)
	_refresh_text()
	_header.show()
	back_button.visible = true
	back_button.grab_focus.call_deferred()
	var camera: Camera3D = get_node(camera_path) as Camera3D
	var target: Transform3D = get_view_transform()
	var parent: Node3D = camera.get_parent_node_3d()
	if parent != null:
		target = parent.global_transform.affine_inverse() * target
	_move_camera(camera, target)
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	_header.hide()
	back_button.visible = false
	if back_button.has_focus():
		back_button.release_focus()
	for node: Node in _hidden:
		if is_instance_valid(node):
			node.set(&"visible", _hidden[node])
	_hidden.clear()
	var camera: Camera3D = get_node_or_null(camera_path) as Camera3D
	if camera != null:
		_move_camera(camera, _tent_transform)
	closed.emit()


func _move_camera(camera: Camera3D, target: Transform3D) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(camera, "transform", target, TWEEN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _unhandled_input(event: InputEvent) -> void:
	# Antes do menu de pausa (autoload): Esc/B aqui só voltam para a tenda.
	if _open and event.is_action_pressed(&"ui_cancel", false, true):
		close()
		get_viewport().set_input_as_handled()


func _build_back_button() -> void:
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.icon = UiIcons.get_icon("door", 48)
	back_button.add_theme_constant_override(&"icon_max_width", 20)
	back_button.theme = load("res://ui/theme/scandig_theme.tres") as Theme
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.custom_minimum_size = Vector2(200, 44)
	# Canto de baixo à esquerda: no meio ficaria em cima da plaquinha do ídolo.
	back_button.anchor_left = 0.0
	back_button.anchor_right = 0.0
	back_button.anchor_top = 1.0
	back_button.anchor_bottom = 1.0
	back_button.offset_left = BACK_MARGIN
	back_button.offset_right = BACK_MARGIN + 200.0
	back_button.offset_top = -44.0 - BACK_MARGIN
	back_button.offset_bottom = -BACK_MARGIN
	back_button.grow_horizontal = Control.GROW_DIRECTION_END
	back_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	back_button.visible = false
	back_button.pressed.connect(close)
	add_child(back_button)


func _build_header() -> void:
	_header = PanelContainer.new()
	_header.name = "MuseumHeader"
	_header.theme = back_button.theme
	_header.theme_type_variation = &"WornPanel"
	_header.anchor_left = 0.5
	_header.anchor_right = 0.5
	_header.anchor_top = 0.0
	_header.anchor_bottom = 0.0
	_header.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_header.offset_left = 0.0
	_header.offset_right = 0.0
	_header.offset_top = 16.0
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.hide()
	add_child(_header)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override(&"margin_left", 12)
	margin.add_theme_constant_override(&"margin_right", 12)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	_header.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	margin.add_child(row)

	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = UiIcons.get_icon("museum", 48)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	_header_title = Label.new()
	_header_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_title.theme_type_variation = &"SubtitleLabel"
	row.add_child(_header_title)

	var separator: VSeparator = VSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(separator)

	_header_progress = Label.new()
	_header_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_header_progress)
