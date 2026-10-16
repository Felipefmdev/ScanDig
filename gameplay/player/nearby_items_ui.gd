extends Control

## Pontinhos na tela sobre os itens caídos por perto (ItemPickup), para não perder o que
## saiu do chão ou caiu da mochila. Não mostra o que está enterrado: isso é do detector.

const MAX_DISTANCE: float = 14.0
const MAX_DOTS: int = 20
const REFRESH: float = 0.2
const DOT_RADIUS: float = 5.0
const COLOR_FIND: Color = UiPalette.GOLD
const COLOR_FOOD: Color = Color(0.6, 0.95, 0.45)
const COLOR_TOOL: Color = Color(0.5, 0.85, 1.0)

var player: Node3D = null
var _targets: Array[ItemPickup] = []
var _refresh_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH
		refresh_targets()
	queue_redraw()


## Os MAX_DOTS itens mais próximos dentro de MAX_DISTANCE.
func refresh_targets() -> void:
	_targets.clear()
	if player == null or not is_inside_tree():
		return
	var origin: Vector3 = player.global_position
	var near: Array = []
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var p: ItemPickup = n as ItemPickup
		if p == null or not is_instance_valid(p) or p.carried == null:
			continue
		var d: float = origin.distance_to(p.global_position)
		if d <= MAX_DISTANCE:
			near.append([d, p])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i: int in mini(near.size(), MAX_DOTS):
		_targets.append(near[i][1])


func get_target_count() -> int:
	return _targets.size()


static func color_for(c: CarriedItem) -> Color:
	if c.tool_data != null and c.tool_data.category == ToolData.Category.FOOD:
		return COLOR_FOOD
	if c.is_tool():
		return COLOR_TOOL
	return COLOR_FIND


func _draw() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or player == null:
		return
	for p: ItemPickup in _targets:
		if not is_instance_valid(p) or p.carried == null:
			continue
		var world: Vector3 = p.global_position + Vector3.UP * 0.35
		if cam.is_position_behind(world):
			continue
		var screen: Vector2 = cam.unproject_position(world)
		var d: float = player.global_position.distance_to(p.global_position)
		var fade: float = clampf(1.0 - d / MAX_DISTANCE, 0.25, 1.0)
		var col: Color = color_for(p.carried)
		col.a = fade
		draw_circle(screen, DOT_RADIUS + 2.0, Color(0, 0, 0, 0.75 * fade))
		draw_circle(screen, DOT_RADIUS, col)
