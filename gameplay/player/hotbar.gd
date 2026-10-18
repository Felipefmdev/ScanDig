class_name Hotbar
extends HBoxContainer

## Hotbar da mochila no HUD do jogador. Constrói um quadrado por slot do Inventory
## (acompanha melhorias de capacidade) e destaca o slot selecionado (borda dourada e leve
## escala). Cada slot mostra o ícone 3D do item (ItemIcons, #119); até o ícone ficar pronto, e
## sempre no headless, fica o quadrado na cor do item. No canto, a marca do tipo (ferramenta ou
## achado de museu).

const SLOT_SIZE: Vector2 = Vector2(92, 92)
## Com muitos slots (mochila até 8) encolhem até aqui para não tapar a vida (canto inferior esquerdo).
const MIN_SLOT_SIZE: float = 64.0
## Largura reservada em cada lado do ecrã (painel de vida: 24 + 280 px + margem).
const SIDE_RESERVED: float = 320.0
const COLOR_BG: Color = Color(0.169, 0.129, 0.094, 0.65)
const COLOR_BORDER: Color = UiPalette.INK
const COLOR_SELECTED: Color = UiPalette.GOLD
const COLOR_RARE: Color = Color(0.85, 0.55, 1.0)
const COLOR_TOOL: Color = Color(0.32, 0.8, 1.0)
const SELECTED_SCALE: float = 1.08
const MARK_SIDE: float = 16.0

var inventory: Inventory = null
var _slot_panels: Array[PanelContainer] = []
var _slot_size: Vector2 = SLOT_SIZE


func bind(inv: Inventory) -> void:
	inventory = inv
	inventory.inventory_changed.connect(_rebuild)
	inventory.selected_slot_changed.connect(_on_selected_slot_changed)
	if ItemIcons.can_render() and is_inside_tree():
		var icons: ItemIcons = ItemIcons.renderer(get_tree())
		if not icons.icon_ready.is_connected(_on_icon_ready):
			icons.icon_ready.connect(_on_icon_ready)
	_rebuild()


func _on_icon_ready(_key: String) -> void:
	if inventory != null and is_inside_tree():
		for i: int in _slot_panels.size():
			_fill_slot(i)


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
	panel.theme = preload("res://ui/theme/scandig_theme.tres")
	panel.custom_minimum_size = _slot_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	# Ícone 3D do item; o quadrado colorido fica no lugar enquanto ele não existe.
	var art: CenterContainer = CenterContainer.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(art)
	var swatch: ColorRect = ColorRect.new()
	swatch.name = "Swatch"
	swatch.custom_minimum_size = Vector2(22, 22)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(swatch)
	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	var icon_side: float = roundf(_slot_size.x * 0.5)
	icon.custom_minimum_size = Vector2(icon_side, icon_side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	art.add_child(icon)

	box.add_child(_make_label("Name", 13, Color.WHITE))
	box.add_child(_make_label("Value", 12, UiPalette.GREEN_BOTTLE.lightened(0.4)))

	# Por cima da caixa: número do slot (canto superior esquerdo) e marca do tipo (direito).
	var overlay: Control = Control.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(overlay)
	var key: Label = _make_label("Key", 11, Color(1, 1, 1, 0.6))
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	key.custom_minimum_size = Vector2.ZERO
	key.position = Vector2(2.0, -2.0)
	overlay.add_child(key)
	var mark: TextureRect = TextureRect.new()
	mark.name = "TypeMark"
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.anchor_left = 1.0
	mark.anchor_right = 1.0
	mark.offset_left = -MARK_SIDE
	mark.offset_right = 0.0
	mark.offset_top = 0.0
	mark.offset_bottom = MARK_SIDE
	overlay.add_child(mark)
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
	l.add_theme_color_override("font_outline_color", UiPalette.INK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _fill_slot(i: int) -> void:
	var box: VBoxContainer = _slot_panels[i].get_node("Box") as VBoxContainer
	var c: CarriedItem = inventory.get_item(i)
	(_slot_panels[i].get_node("Overlay/Key") as Label).text = str(i + 1)
	var swatch: ColorRect = box.find_child("Swatch", true, false) as ColorRect
	var icon: TextureRect = box.find_child("Icon", true, false) as TextureRect
	var mark: TextureRect = _slot_panels[i].get_node("Overlay/TypeMark") as TextureRect
	var name_label: Label = box.get_node("Name") as Label
	var value_label: Label = box.get_node("Value") as Label
	var texture: Texture2D = ItemIcons.get_icon(c, get_tree() if is_inside_tree() else null) if c != null else null
	icon.texture = texture
	icon.visible = texture != null
	swatch.visible = texture == null
	mark.texture = null
	if c == null:
		swatch.color = Color(1, 1, 1, 0.08)
		name_label.text = "—"
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		value_label.text = ""
	elif c.is_tool():
		swatch.color = COLOR_TOOL
		mark.texture = UiIcons.get_icon("wrench", 32)
		# O desgaste já aparece embaixo: o nome fica sem o "[80%]".
		name_label.text = c.tool_name if c.wear >= 0 else c.get_display_name()
		name_label.add_theme_color_override("font_color", COLOR_TOOL)
		if c.wear >= 0:
			# Desgaste (armas): % que falta, vermelho quando está acabando.
			var ratio: float = c.wear_ratio()
			value_label.text = "%d%%" % int(ceilf(ratio * 100.0))
			value_label.add_theme_color_override("font_color", UiPalette.RED_BURNT if ratio <= 0.2 else Color(0.9, 0.9, 0.9))
		else:
			value_label.text = ""
			value_label.remove_theme_color_override("font_color")
	else:
		swatch.color = ItemPickup.make_material(c.item, c.is_rare_variant).albedo_color
		mark.texture = UiIcons.get_icon("gem" if c.is_rare_variant else "museum", 32)
		# Rara: a marca de gema no canto substitui o "✦" do nome.
		name_label.text = c.get_display_name().replace("✦ ", "")
		name_label.add_theme_color_override("font_color", COLOR_RARE if c.is_rare_variant else Color.WHITE)
		value_label.text = MoneyFormat.money(c.final_value)


func _on_selected_slot_changed(index: int) -> void:
	for i: int in _slot_panels.size():
		var selected: bool = (i == index)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(UiPalette.INK.r, UiPalette.INK.g, UiPalette.INK.b, 0.85) if selected else COLOR_BG
		style.border_color = COLOR_SELECTED if selected else COLOR_BORDER
		var w: int = 3 if selected else 1
		if selected:
			style.shadow_color = Color(UiPalette.ORANGE, 0.55)
			style.shadow_size = 6
		style.border_width_left = w
		style.border_width_top = w
		style.border_width_right = w
		style.border_width_bottom = w
		style.set_corner_radius_all(6)
		style.content_margin_left = 4.0
		style.content_margin_right = 4.0
		style.content_margin_top = 2.0
		style.content_margin_bottom = 4.0
		var panel: PanelContainer = _slot_panels[i]
		panel.add_theme_stylebox_override("panel", style)
		# Escala só no desenho (o HBox não reorganiza): cresce a partir do centro.
		panel.pivot_offset = _slot_size * 0.5
		panel.scale = Vector2.ONE * (SELECTED_SCALE if selected else 1.0)
		panel.z_index = 1 if selected else 0
