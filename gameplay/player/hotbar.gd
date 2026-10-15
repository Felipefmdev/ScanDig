class_name Hotbar
extends HBoxContainer

## Hotbar da mochila no HUD do jogador. Constrói um quadrado por slot do Inventory
## (acompanha melhorias de capacidade) e destaca o slot selecionado.

const SLOT_SIZE: Vector2 = Vector2(92, 92)
## Com muitos slots (mochila até 8) encolhem até aqui para não tapar a vida (canto inferior esquerdo).
const MIN_SLOT_SIZE: float = 64.0
## Largura reservada em cada lado do ecrã (painel de vida: 24 + 280 px + margem).
const SIDE_RESERVED: float = 320.0
const COLOR_BG: Color = Color(0.05, 0.05, 0.06, 0.6)
const COLOR_BORDER: Color = Color(0.0, 0.0, 0.0, 0.85)
const COLOR_SELECTED: Color = Color(1.0, 0.85, 0.3, 1.0)
const COLOR_RARE: Color = Color(0.85, 0.55, 1.0)
const COLOR_TOOL: Color = Color(0.32, 0.8, 1.0)

var inventory: Inventory = null
var _slot_panels: Array[PanelContainer] = []
var _slot_size: Vector2 = SLOT_SIZE


func bind(inv: Inventory) -> void:
	inventory = inv
	inventory.inventory_changed.connect(_rebuild)
	inventory.selected_slot_changed.connect(_on_selected_slot_changed)
	_rebuild()


func _rebuild() -> void:
	if inventory == null:
		return
	if _slot_panels.size() != inventory.capacity:
		for p: PanelContainer in _slot_panels:
			p.queue_free()
		_slot_panels.clear()
		_slot_size = get_slot_size(inventory.capacity)
		for i: int in inventory.capacity:
			var panel: PanelContainer = _make_slot_panel()
			add_child(panel)
			_slot_panels.append(panel)
	for i: int in _slot_panels.size():
		_fill_slot(i)
	_on_selected_slot_changed(inventory.selected_slot)


## Quadrado por slot: SLOT_SIZE se couber entre as margens laterais, senão mais pequeno.
func get_slot_size(count: int) -> Vector2:
	var view_w: float = get_viewport_rect().size.x if is_inside_tree() else 1280.0
	var sep: float = float(get_theme_constant("separation"))
	var avail: float = view_w - 2.0 * SIDE_RESERVED - sep * float(maxi(count - 1, 0))
	var side: float = clampf(floorf(avail / float(maxi(count, 1))), MIN_SLOT_SIZE, SLOT_SIZE.x)
	return Vector2(side, side)


func _make_slot_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = _slot_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var key: Label = _make_label("Key", 11, Color(1, 1, 1, 0.55))
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(key)

	var swatch_holder: CenterContainer = CenterContainer.new()
	swatch_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(swatch_holder)
	var swatch: ColorRect = ColorRect.new()
	swatch.name = "Swatch"
	swatch.custom_minimum_size = Vector2(22, 22)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch_holder.add_child(swatch)

	box.add_child(_make_label("Name", 12, Color.WHITE))
	box.add_child(_make_label("Value", 12, Color(0.6, 1.0, 0.6)))
	return panel


func _make_label(label_name: String, size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.name = label_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(_slot_size.x - 10.0, 0.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _fill_slot(i: int) -> void:
	var box: VBoxContainer = _slot_panels[i].get_node("Box") as VBoxContainer
	var c: CarriedItem = inventory.get_item(i)
	(box.get_node("Key") as Label).text = str(i + 1)
	var swatch: ColorRect = box.find_child("Swatch", true, false) as ColorRect
	var name_label: Label = box.get_node("Name") as Label
	var value_label: Label = box.get_node("Value") as Label
	if c == null:
		swatch.color = Color(1, 1, 1, 0.08)
		name_label.text = "—"
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		value_label.text = ""
	elif c.is_tool():
		swatch.color = COLOR_TOOL
		name_label.text = c.get_display_name()
		name_label.add_theme_color_override("font_color", COLOR_TOOL)
		value_label.text = "🔧 ferramenta"
	else:
		swatch.color = ItemPickup.make_material(c.item, c.is_rare_variant).albedo_color
		name_label.text = c.get_display_name()
		name_label.add_theme_color_override("font_color", COLOR_RARE if c.is_rare_variant else Color.WHITE)
		value_label.text = "R$ %d" % c.final_value


func _on_selected_slot_changed(index: int) -> void:
	for i: int in _slot_panels.size():
		var selected: bool = (i == index)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.16, 0.05, 0.75) if selected else COLOR_BG
		style.border_color = COLOR_SELECTED if selected else COLOR_BORDER
		var w: int = 3 if selected else 1
		style.border_width_left = w
		style.border_width_top = w
		style.border_width_right = w
		style.border_width_bottom = w
		style.set_corner_radius_all(6)
		style.content_margin_left = 4.0
		style.content_margin_right = 4.0
		style.content_margin_top = 2.0
		style.content_margin_bottom = 4.0
		_slot_panels[i].add_theme_stylebox_override("panel", style)
