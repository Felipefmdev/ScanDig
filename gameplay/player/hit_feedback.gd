extends Node

## Retorno visual dos golpes do jogador local: marcador em X na mira e número de dano
## flutuando no ponto do acerto. Só existe no dono (é filho do player local).

const HITMARKER_TIME: float = 0.25
const NUMBER_TIME: float = 0.5
const NUMBER_RISE: float = 0.7
const MARK_SIZE: float = 9.0
const MARK_GAP: float = 4.0
const COLOR_HIT: Color = Color(1.0, 1.0, 1.0)
const COLOR_KILL: Color = UiPalette.RED_BURNT

var _marker: Control = null
var _marker_tween: Tween = null
var _marker_color: Color = COLOR_HIT


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_marker = Control.new()
	_marker.set_anchors_preset(Control.PRESET_CENTER)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.modulate.a = 0.0
	_marker.draw.connect(_draw_marker)
	layer.add_child(_marker)


## Registra um acerto em `world_pos`. `killed` troca a cor e engrossa o X.
func show_hit(world_pos: Vector3, damage: float, killed: bool = false) -> void:
	if damage <= 0.0:
		return
	_pop_marker(killed)
	_spawn_number(world_pos, damage, killed)


func _pop_marker(killed: bool) -> void:
	if _marker == null:
		return
	_marker_color = COLOR_KILL if killed else COLOR_HIT
	_marker.queue_redraw()
	if _marker_tween != null:
		_marker_tween.kill()
	_marker.modulate.a = 1.0
	_marker.scale = Vector2.ONE * (1.6 if killed else 1.3)
	_marker_tween = create_tween()
	_marker_tween.tween_property(_marker, "scale", Vector2.ONE, HITMARKER_TIME * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_marker_tween.tween_property(_marker, "modulate:a", 0.0, HITMARKER_TIME * 0.6)


func _draw_marker() -> void:
	var w: float = 3.0 if _marker_color == COLOR_KILL else 2.0
	for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var d: Vector2 = dir.normalized()
		_marker.draw_line(d * MARK_GAP, d * (MARK_GAP + MARK_SIZE), Color(0, 0, 0, 0.6), w + 2.0)
		_marker.draw_line(d * MARK_GAP, d * (MARK_GAP + MARK_SIZE), _marker_color, w)


func _spawn_number(world_pos: Vector3, damage: float, killed: bool) -> void:
	if get_tree() == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	var label: Label3D = Label3D.new()
	label.text = str(int(round(damage)))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 48 if killed else 36
	label.outline_size = 10
	label.modulate = COLOR_KILL if killed else UiPalette.GOLD
	scene_root.add_child(label)
	label.global_position = world_pos + Vector3(randf_range(-0.25, 0.25), 0.3, randf_range(-0.25, 0.25))
	var t: Tween = label.create_tween()
	t.tween_property(label, "global_position:y", label.global_position.y + NUMBER_RISE, NUMBER_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "modulate:a", 0.0, NUMBER_TIME).set_delay(NUMBER_TIME * 0.4)
	t.tween_callback(label.queue_free)
