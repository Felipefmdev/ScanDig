class_name CoopMarkerHud
extends Control

## Indicador em tela e bordas dos marcadores do coop com distância (#107).
## Desenha os emblemas com ícone, cor e distância em metros para cada bandeirinha ativa.
## Quando o marcador está fora de visão, fixa-se na borda da tela com seta direcional.

var _player: Player = null
var _font: Font = null


func setup(player: Player) -> void:
	_player = player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null or _player.camera == null or not _player.is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var markers: Array[Node] = tree.get_nodes_in_group(&"coop_markers")
	if markers.is_empty():
		return

	if _font == null:
		_font = ThemeDB.fallback_font

	var cam: Camera3D = _player.camera
	var vp_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = vp_size * 0.5
	var padding: float = 38.0

	for node: Node in markers:
		if not is_instance_valid(node) or not node.is_inside_tree() or not (node is Node3D):
			continue
		var flag: Node3D = node as Node3D
		var world_pos: Vector3 = flag.global_position + Vector3(0.0, 1.5, 0.0)
		var dist: float = _player.global_position.distance_to(flag.global_position)

		# Alpha suave quando o jogador está muito perto (< 2.0m) para não atrapalhar
		var alpha: float = clampf((dist - 1.0) / 1.0, 0.2, 1.0)
		var cfg: Dictionary = flag.call("get_type_config") if flag.has_method("get_type_config") else {}
		var col: Color = cfg.get("color", Color.WHITE)
		var icon: String = cfg.get("icon", "🚩")
		var display_label: String = flag.call("get_display_label") if flag.has_method("get_display_label") else "Marcador"

		var is_behind: bool = cam.is_position_behind(world_pos)
		var unproj: Vector2 = cam.unproject_position(world_pos)

		var on_screen: bool = not is_behind \
				and unproj.x >= padding and unproj.x <= vp_size.x - padding \
				and unproj.y >= padding and unproj.y <= vp_size.y - padding

		var badge_pos: Vector2 = Vector2.ZERO
		var draw_arrow: bool = false
		var arrow_angle: float = 0.0

		if on_screen:
			badge_pos = unproj
		else:
			draw_arrow = true
			var dir: Vector2 = unproj - center
			if is_behind:
				dir = -dir
			if dir.length_squared() < 0.001:
				dir = Vector2.UP
			dir = dir.normalized()
			arrow_angle = dir.angle()

			var max_x: float = center.x - padding
			var max_y: float = center.y - padding
			var scale_x: float = absf(max_x / dir.x) if absf(dir.x) > 0.0001 else 99999.0
			var scale_y: float = absf(max_y / dir.y) if absf(dir.y) > 0.0001 else 99999.0
			var edge_dist: float = minf(scale_x, scale_y)
			badge_pos = center + dir * edge_dist

		_draw_marker_badge(badge_pos, icon, dist, col, alpha, draw_arrow, arrow_angle, display_label, on_screen)


func _draw_marker_badge(pos: Vector2, icon: String, dist: float, col: Color, alpha: float, draw_arrow: bool, arrow_angle: float, label_text: String, on_screen: bool) -> void:
	var dist_text: String = "%s %dm" % [icon, int(round(dist))]
	var font_size: int = 14
	var text_size: Vector2 = _font.get_string_size(dist_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	var pill_w: float = text_size.x + 18.0
	var pill_h: float = 24.0
	var pill_rect: Rect2 = Rect2(pos.x - pill_w * 0.5, pos.y - pill_h * 0.5, pill_w, pill_h)

	# Fundo do pill
	var bg_col: Color = Color(0.08, 0.08, 0.12, 0.85 * alpha)
	var border_col: Color = Color(col.r, col.g, col.b, 0.9 * alpha)
	draw_rect(pill_rect, bg_col, true, -1.0)
	draw_rect(pill_rect, border_col, false, 1.8)

	# Texto da distância
	var text_pos: Vector2 = Vector2(pill_rect.position.x + 9.0, pill_rect.position.y + 17.0)
	draw_string(_font, text_pos, dist_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.95 * alpha))

	# Seta direcional na borda quando fora de campo
	if draw_arrow:
		var arrow_len: float = 12.0
		var arrow_tip: Vector2 = pos + Vector2(cos(arrow_angle), sin(arrow_angle)) * (pill_w * 0.5 + 8.0)
		var left_pt: Vector2 = arrow_tip - Vector2(cos(arrow_angle - 0.5), sin(arrow_angle - 0.5)) * arrow_len
		var right_pt: Vector2 = arrow_tip - Vector2(cos(arrow_angle + 0.5), sin(arrow_angle + 0.5)) * arrow_len
		var arrow_pts: PackedVector2Array = PackedVector2Array([arrow_tip, left_pt, right_pt])
		draw_colored_polygon(arrow_pts, border_col)

	# Se estiver na tela e o jogador olhar diretamente para ele, exibe detalhe
	if on_screen:
		var center: Vector2 = get_viewport_rect().size * 0.5
		if pos.distance_to(center) < 70.0:
			var sub_size: Vector2 = _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			var sub_rect: Rect2 = Rect2(pos.x - sub_size.x * 0.5 - 6.0, pill_rect.end.y + 2.0, sub_size.x + 12.0, 18.0)
			draw_rect(sub_rect, Color(0.06, 0.06, 0.1, 0.8 * alpha), true)
			draw_string(_font, Vector2(sub_rect.position.x + 6.0, sub_rect.position.y + 13.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
