class_name CoopMarkerWheel
extends Control

## Menu radial rápido para seleção do tipo de marcador no coop (#107).
## Permite escolher rapidamente entre Sinal aqui (🚩), Perigo (⚠️) e Ajuda (🆘).

signal marker_selected(type: int)

const RADIUS: float = 95.0
const INNER_RADIUS: float = 38.0
const SECTOR_COUNT: int = 3
const COOP_MARKER_FLAG_SCRIPT: Script = preload("res://gameplay/player/coop_marker_flag.gd")

var _is_open: bool = false
var _selected_type: int = 0
var _center: Vector2 = Vector2.ZERO
var _label_title: Label = null
var _label_desc: Label = null
var _panel_info: PanelContainer = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func is_wheel_open() -> bool:
	return _is_open


func get_selected_type() -> int:
	return _selected_type


func open() -> void:
	_is_open = true
	visible = true
	queue_redraw()
	_update_info()


func close() -> void:
	_is_open = false
	visible = false


func update_selection_from_input(input_vec: Vector2) -> void:
	if not _is_open:
		return
	if input_vec.length_squared() > 0.04: # zona morta leve (0.2)
		var angle: float = input_vec.angle() # radianos [-PI, PI]
		# Ângulo normalizado [0, TAU] com offset de topo
		# Topo = -PI/2 (-90°)
		# Sector 0 (SIGNAL - Topo): -150° a -30°
		# Sector 1 (DANGER - Direita/Baixo): -30° a 90°
		# Sector 2 (HELP - Esquerda/Baixo): 90° a 210°
		var deg: float = rad_to_deg(angle)
		if deg < -180.0:
			deg += 360.0
		elif deg > 180.0:
			deg -= 360.0

		var new_type: int = _selected_type
		if deg >= -150.0 and deg < -30.0:
			new_type = COOP_MARKER_FLAG_SCRIPT.MarkerType.SIGNAL
		elif deg >= -30.0 and deg < 90.0:
			new_type = COOP_MARKER_FLAG_SCRIPT.MarkerType.DANGER
		else:
			new_type = COOP_MARKER_FLAG_SCRIPT.MarkerType.HELP

		if new_type != _selected_type:
			_selected_type = new_type
			_update_info()
			queue_redraw()


func _get_wheel_center() -> Vector2:
	if size.x > 10.0 and size.y > 10.0:
		return size * 0.5
	var vp: Viewport = get_viewport()
	if vp != null:
		return vp.get_visible_rect().size * 0.5
	return Vector2(640.0, 360.0)


func _draw() -> void:
	if not _is_open:
		return
	_center = _get_wheel_center()
	# Fundo circular translúcido
	draw_circle(_center, RADIUS + 12.0, Color(0.08, 0.08, 0.1, 0.75))
	draw_arc(_center, RADIUS + 12.0, 0, TAU, 32, Color(0.25, 0.25, 0.3, 0.8), 2.0)
	draw_arc(_center, INNER_RADIUS, 0, TAU, 24, Color(0.2, 0.2, 0.25, 0.6), 1.5)

	# Fatias
	var slice_angles: Array[Vector2] = [
		Vector2(deg_to_rad(-150.0), deg_to_rad(-30.0)), # SIGNAL (Topo)
		Vector2(deg_to_rad(-30.0), deg_to_rad(90.0)),   # DANGER (Direita)
		Vector2(deg_to_rad(90.0), deg_to_rad(210.0)),   # HELP (Esquerda)
	]

	for i: int in SECTOR_COUNT:
		var cfg: Dictionary = COOP_MARKER_FLAG_SCRIPT.TYPE_CONFIG[i]
		var col: Color = cfg.get("color", Color.WHITE)
		var is_sel: bool = (i == _selected_type)
		var arc_range: Vector2 = slice_angles[i]

		# Preenchimento da fatia selecionada
		if is_sel:
			var points: PackedVector2Array = PackedVector2Array()
			points.append(_center)
			for step: int in 13:
				var a: float = lerpf(arc_range.x, arc_range.y, float(step) / 12.0)
				points.append(_center + Vector2(cos(a), sin(a)) * (RADIUS + 8.0))
			draw_colored_polygon(points, Color(col.r, col.g, col.b, 0.35))
			# Borda de destaque
			draw_arc(_center, RADIUS + 8.0, arc_range.x, arc_range.y, 16, col, 3.5)

		# Ícone desenhado na posição média da fatia
		var mid_a: float = (arc_range.x + arc_range.y) * 0.5
		var icon_pos: Vector2 = _center + Vector2(cos(mid_a), sin(mid_a)) * ((RADIUS + INNER_RADIUS) * 0.5)
		draw_circle(icon_pos, 16.0, Color(0.12, 0.12, 0.16, 0.9) if not is_sel else col)
		if is_sel:
			draw_arc(icon_pos, 18.0, 0, TAU, 20, Color.WHITE, 2.0)


func _build_ui() -> void:
	_panel_info = PanelContainer.new()
	_panel_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_info.theme_type_variation = &"WornPanel"

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)

	_label_title = Label.new()
	_label_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_title.add_theme_font_size_override("font_size", 18)
	_label_title.add_theme_color_override("font_color", UiPalette.GOLD)
	vbox.add_child(_label_title)

	_label_desc = Label.new()
	_label_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_desc.add_theme_font_size_override("font_size", 13)
	_label_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_label_desc)

	_panel_info.add_child(vbox)
	add_child(_panel_info)


func _update_info() -> void:
	if _label_title == null or _label_desc == null or _panel_info == null:
		return
	var cfg: Dictionary = COOP_MARKER_FLAG_SCRIPT.TYPE_CONFIG.get(_selected_type, {})
	var icon: String = cfg.get("icon", "🚩")
	var title: String = cfg.get("name", "Marcador")
	var col: Color = cfg.get("color", Color.WHITE)
	var desc: String = cfg.get("desc", "")

	_label_title.text = "%s %s" % [icon, title]
	_label_title.add_theme_color_override("font_color", col)
	_label_desc.text = desc

	# Posiciona o painel ligeiramente abaixo do círculo
	var c: Vector2 = _get_wheel_center()
	_panel_info.position = Vector2(c.x - 140.0, c.y + RADIUS + 24.0)
	_panel_info.custom_minimum_size = Vector2(280.0, 50.0)
