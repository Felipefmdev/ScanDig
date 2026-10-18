class_name UiChip
extends PanelContainer

## Chip de informação (#119): ícone de UiIcons + texto num papel claro com contorno de tinta,
## no estilo dos painéis. Usado no HUD do topo (mochila e dinheiro) e no painel da base
## (Equipe / Detector / Museu). Os filhos são criados no _init, então caminhos como
## "MoneyChip/Box/Label" já existem no _ready de quem instancia a cena.

const ICON_SIDE: int = 22

@export var icon_name: String = "":
	set(value):
		icon_name = value
		if icon_rect != null:
			icon_rect.texture = UiIcons.get_icon(value, ICON_SIDE * 2)
			icon_rect.visible = icon_rect.texture != null

var icon_rect: TextureRect = null
var label: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override(&"panel", make_style())
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
	label.add_theme_font_size_override(&"font_size", 16)
	box.add_child(label)
	icon_name = icon_name


static func make(p_icon: String, p_text: String = "", chip_name: String = "") -> UiChip:
	var chip: UiChip = UiChip.new()
	chip.icon_name = p_icon
	chip.label.text = p_text
	if not chip_name.is_empty():
		chip.name = chip_name
	return chip


func set_text(text: String) -> void:
	label.text = text


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
