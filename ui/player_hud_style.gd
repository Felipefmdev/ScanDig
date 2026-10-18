class_name PlayerHudStyle
extends RefCounted

## Visual do HUD do jogador (#119, #122): a barra de Ameaça e o painel de vida/fome ficam sem
## cartão, direto sobre o mundo: ícone de UiIcons + texto claro com contorno e sombra de tinta +
## barra com trilho escuro translúcido. Assim leem tanto na areia clara da Praia quanto na neve
## da Geleira. Os nós de player.tscn (ThreatPanel/ThreatTitle/ThreatBar,
## HealthPanel/HealthLabel/HealthBar; a fome é criada por código) ficam onde estão.

const ICON_SIDE: int = 20
const OUTLINE_SIZE: int = 6
const SHADOW_OFFSET: Vector2i = Vector2i(1, 2)
## Trilho das barras: tinta translúcida (o bege do theme sumia na areia) com contorno sólido.
const TRACK_COLOR: Color = Color(0.168627, 0.129412, 0.094118, 0.55)


## Chamado pelo player depois de montar o HUD (a fome é criada por código).
static func apply(hud: Node) -> void:
	if hud == null:
		return
	var icons: Dictionary = {"ThreatPanel/ThreatTitle": "skull", "HealthPanel/HealthLabel": "heart",
		"HealthPanel/HungerLabel": "food"}
	for path: String in icons:
		var label: Label = hud.get_node_or_null(path) as Label
		if label != null:
			iconize(label, str(icons[path]))
	for path: String in ["ThreatPanel/ThreatBar", "HealthPanel/HealthBar", "HealthPanel/HungerBar"]:
		var bar: ProgressBar = hud.get_node_or_null(path) as ProgressBar
		if bar != null:
			style_bar(bar)
	var chips: Node = hud.get_node_or_null(^"TopChips")
	if chips != null:
		for chip: Node in chips.get_children():
			if chip is UiChip:
				(chip as UiChip).add_theme_stylebox_override(&"panel", quiet_chip_style())


## Texto claro com contorno e sombra de tinta, legível sobre qualquer chão.
static func outline_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", UiPalette.PAPER_LIGHT)
	label.add_theme_color_override(&"font_outline_color", UiPalette.INK)
	label.add_theme_constant_override(&"outline_size", OUTLINE_SIZE)
	label.add_theme_color_override(&"font_shadow_color", Color(UiPalette.INK, 0.6))
	label.add_theme_constant_override(&"shadow_offset_x", SHADOW_OFFSET.x)
	label.add_theme_constant_override(&"shadow_offset_y", SHADOW_OFFSET.y)
	label.add_theme_constant_override(&"shadow_outline_size", OUTLINE_SIZE)


## Trilho escuro translúcido com contorno de tinta; o preenchimento continua o do theme.
static func style_bar(bar: ProgressBar) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = TRACK_COLOR
	track.border_color = UiPalette.INK
	track.set_border_width_all(2)
	track.set_corner_radius_all(3)
	bar.add_theme_stylebox_override(&"background", track)


## Chip do topo mais discreto que o da Base: papel translúcido, sem sombra.
static func quiet_chip_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = UiChip.make_style()
	style.bg_color.a = 0.8
	style.border_color = Color(UiPalette.INK, 0.7)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style


## Texto contornado, alinhado à esquerda, com o ícone antes dele.
static func iconize(label: Label, icon_name: String) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	outline_label(label)
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
