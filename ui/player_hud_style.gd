class_name PlayerHudStyle
extends RefCounted

## Visual do HUD do jogador (#119), no estilo dos chips (UiChip): a barra de Ameaça e o
## painel de vida/fome ganham uma moldura de papel e ícones de UiIcons no lugar dos emojis. Os
## nós de player.tscn (ThreatPanel/ThreatTitle/ThreatBar, HealthPanel/HealthLabel/HungerLabel)
## ficam onde estão: a moldura é um irmão desenhado atrás, que acompanha o retângulo do painel.

const ICON_SIDE: int = 20
const FRAME_MARGIN: Vector2 = Vector2(10.0, 6.0)


## Chamado pelo player depois de montar o HUD (a fome é criada por código).
static func apply(hud: Node) -> void:
	if hud == null:
		return
	for panel_name: String in ["ThreatPanel", "HealthPanel"]:
		var panel: Control = hud.get_node_or_null(panel_name) as Control
		if panel != null:
			add_frame(panel)
	var icons: Dictionary = {"ThreatPanel/ThreatTitle": "skull", "HealthPanel/HealthLabel": "heart",
		"HealthPanel/HungerLabel": "food"}
	for path: String in icons:
		var label: Label = hud.get_node_or_null(path) as Label
		if label != null:
			iconize(label, str(icons[path]))


## Moldura de papel atrás de `target` (mesmo pai, logo antes dele), seguindo posição,
## tamanho e visibilidade.
static func add_frame(target: Control) -> Panel:
	var parent: Node = target.get_parent()
	var frame: Panel = parent.get_node_or_null(NodePath(target.name + "Frame")) as Panel
	if frame != null:
		return frame
	frame = Panel.new()
	frame.name = target.name + "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = UiChip.make_style()
	style.set_corner_radius_all(10)
	frame.add_theme_stylebox_override(&"panel", style)
	parent.add_child(frame)
	parent.move_child(frame, target.get_index())
	var follow: Callable = func() -> void:
		if not is_instance_valid(frame) or not is_instance_valid(target):
			return
		frame.position = target.position - FRAME_MARGIN
		frame.size = target.size + FRAME_MARGIN * 2.0
		frame.visible = target.visible
	target.item_rect_changed.connect(follow)
	target.visibility_changed.connect(follow)
	follow.call()
	return frame


## Texto de tinta sobre o papel, alinhado à esquerda, com o ícone antes dele.
static func iconize(label: Label, icon_name: String) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override(&"font_color", UiPalette.INK)
	label.add_theme_color_override(&"font_outline_color", UiPalette.INK)
	label.add_theme_constant_override(&"outline_size", 0)
	var pad: StyleBoxEmpty = StyleBoxEmpty.new()
	pad.content_margin_left = ICON_SIDE + 6.0
	label.add_theme_stylebox_override(&"normal", pad)
	var icon: TextureRect = label.get_node_or_null(^"Icon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		label.add_child(icon)
	icon.texture = UiIcons.get_icon(icon_name, ICON_SIDE * 2)
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = 0.0
	icon.offset_right = ICON_SIDE
	icon.offset_top = -ICON_SIDE * 0.5
	icon.offset_bottom = ICON_SIDE * 0.5
