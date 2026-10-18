class_name MuseumView
extends CanvasLayer

## "Ver museu" (aba Museu da Base): a câmera do lobby sai da tenda e vai, num Tween suave, até a
## frente da vitrine (MuseumDisplay). Enquanto isso os painéis da Base (UILayer) somem e fica só o
## botão "Voltar"; Voltar, Esc ou B (ui_cancel) levam a câmera de volta à tenda e os painéis voltam.
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
	back_button.text = "Voltar"
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
