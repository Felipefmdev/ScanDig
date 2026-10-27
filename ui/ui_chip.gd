class_name UiChip
extends PanelContainer

## Chip de informação (#119): ícone de UiIcons + texto num papel claro com contorno de tinta,
## no estilo dos painéis. Usado no HUD do topo (mochila e dinheiro) e no painel da base
## (Dinheiro / Detector / Museu). Os filhos são criados no _init, então caminhos como
## "MoneyChip/Box/Label" já existem no _ready de quem instancia a cena.

const ICON_SIDE: int = 22
const SECONDARY_ICON_SIDE: int = 18
const PRIMARY_FONT_SIZE: int = 18
const SECONDARY_FONT_SIZE: int = 15

@export var primary: bool = true:
	set(value):
		primary = value
		_apply_hierarchy()

@export var icon_name: String = "":
	set(value):
		icon_name = value
		_apply_hierarchy()

var icon_rect: TextureRect = null
var label: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box: HBoxContainer = HBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	add_child(box)
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon_rect)
	label = Label.new()
	label.name = "Label"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", UiPalette.INK)
	label.add_theme_color_override(&"font_outline_color", UiPalette.INK)
	label.add_theme_constant_override(&"outline_size", 0)
	box.add_child(label)
	_apply_hierarchy()


func _apply_hierarchy() -> void:
	var side: int = ICON_SIDE if primary else SECONDARY_ICON_SIDE
	add_theme_stylebox_override(&"panel", make_style() if primary else make_secondary_style())
	if icon_rect != null:
		icon_rect.custom_minimum_size = Vector2(side, side)
		icon_rect.texture = UiIcons.get_icon(icon_name, side * 2)
		icon_rect.visible = icon_rect.texture != null
	if label != null:
		label.add_theme_font_size_override(&"font_size", PRIMARY_FONT_SIZE if primary else SECONDARY_FONT_SIZE)


## Papel claro, contorno de tinta de 2 px, cantos de 8 e a sombra dura dos painéis.
static func make_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(UiPalette.PAPER_LIGHT, 0.94)
	style.border_color = UiPalette.INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = UiPalette.SHADOW
	style.shadow_size = 2
	style.shadow_offset = Vector2(2, 3)
	style.content_margin_left = 8.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


## Chip secundário (#180 F6): papel bege discreto, borda de 1 px, sem sombra e margens mais compactas.
static func make_secondary_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(UiPalette.PAPER, 0.88)
	style.border_color = UiPalette.INK
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = UiPalette.SHADOW
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 6.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style
