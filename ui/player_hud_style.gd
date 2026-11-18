class_name PlayerHudStyle
extends RefCounted

## Visual do HUD do jogador (#119, #122, #212):
## - Margem segura responsiva de 5% (anchors 0.05..0.95, docs/learning/AGENT_CONTEXT.md).
## - Canto inferior esquerdo: medidores curvos pequenos de vida/fome (VitalsArcs) com números em
##   Labels reais (participam de SettingsManager.apply_hud_text_scale / _settings_base_font_size),
##   lendo HealthBar/HungerBar (fontes de dados e A11y) e preservando os alertas de fome baixa e
##   sobrecarga/peso de HungerLabel. Dinheiro é o terceiro mostrador, com arco de saldo;
##   TopChips permanece oculto, preservando os caminhos que Player atualiza.
## - Canto superior direito: Ameaça do Subsolo compacta e contextual (ThreatPanel).
## - Canto inferior direito: mapa/dia menores (compact_expedition_bar em SessionUI).

const ICON_SIDE: int = 20
const COMPACT_ICON_SIDE: int = 16
const OUTLINE_SIZE: int = 6
const SHADOW_OFFSET: Vector2i = Vector2i(1, 2)
## Trilho das barras: tinta translúcida (o bege do theme sumia na areia) com contorno sólido.
const TRACK_COLOR: Color = Color(0.168627, 0.129412, 0.094118, 0.55)
const LOW_RATIO: float = 0.25
const SAFE_MARGIN_RATIO: float = 0.05
const CHIP_FONT_SIZE: int = 15
const THREAT_FONT_SIZE: int = 14
const EXPEDITION_FONT_SIZE: int = 15
const DIAL_BASE_FONT_SIZE: int = 13
## Referência visual provisória aprovada na #212; não limita o saldo econômico.
const MONEY_ARC_REFERENCE: float = 10000.0
const STATUS_BASE_FONT_SIZE: int = 13
## Mesma chave de meta usada por SettingsManager._scale_text_node (core/settings_manager.gd:57).
const SETTINGS_BASE_FONT_META: StringName = &"_settings_base_font_size"


## Chamado pelo player depois de montar o HUD (a fome e a ameaça já foram configuradas).
## Idempotente: pode ser chamado mais de uma vez sem duplicar nós auxiliares ou conexões.
static func apply(hud: Node) -> void:
	if hud == null:
		return
	var icons: Dictionary = {
		"ThreatPanel/ThreatTitle": "skull",
		"HealthPanel/HealthLabel": "heart",
		"HealthPanel/HungerLabel": "food",
	}
	for path: String in icons:
		var label: Label = hud.get_node_or_null(path) as Label
		if label != null:
			iconize(label, str(icons[path]))
	for path: String in ["ThreatPanel/ThreatBar", "HealthPanel/HealthBar", "HealthPanel/HungerBar"]:
		var bar: ProgressBar = hud.get_node_or_null(path) as ProgressBar
		if bar != null:
			style_bar(bar)
	var chips: HBoxContainer = hud.get_node_or_null(^"TopChips") as HBoxContainer
	var health_panel: VBoxContainer = hud.get_node_or_null(^"HealthPanel") as VBoxContainer
	if chips != null:
		_compact_top_chips(chips)
	if health_panel != null:
		_setup_compact_vitals(health_panel, chips)
	var threat_panel: VBoxContainer = hud.get_node_or_null(^"ThreatPanel") as VBoxContainer
	if threat_panel != null:
		_setup_contextual_threat(threat_panel)


## Define o tamanho base de um Label respeitando a meta _settings_base_font_size do SettingsManager,
## para nunca sobrescrever nem perder uma escala de HUD (hud_text_scale) já aplicada.
static func _set_base_font_size(label: Label, base_size: int) -> void:
	if label == null:
		return
	if label.has_meta(SETTINGS_BASE_FONT_META):
		var prev_base: int = maxi(int(label.get_meta(SETTINGS_BASE_FONT_META)), 1)
		var current_size: int = label.get_theme_font_size(&"font_size")
		var scale_ratio: float = float(current_size) / float(prev_base)
		label.set_meta(SETTINGS_BASE_FONT_META, base_size)
		label.add_theme_font_size_override(&"font_size", maxi(roundi(float(base_size) * scale_ratio), 1))
	else:
		label.add_theme_font_size_override(&"font_size", base_size)


## Posiciona mochila e dinheiro compactos no canto inferior esquerdo, logo acima de vida/fome,
## respeitando a margem segura responsiva de 5% (anchors 0.05 / 0.95).
static func _compact_top_chips(chips: HBoxContainer) -> void:
	chips.anchor_left = SAFE_MARGIN_RATIO
	chips.anchor_right = SAFE_MARGIN_RATIO
	chips.anchor_top = 1.0 - SAFE_MARGIN_RATIO
	chips.anchor_bottom = 1.0 - SAFE_MARGIN_RATIO
	chips.grow_horizontal = Control.GROW_DIRECTION_END
	chips.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chips.offset_left = 0.0
	chips.offset_right = 240.0
	chips.offset_bottom = -64.0
	chips.offset_top = -92.0
	chips.add_theme_constant_override(&"separation", 6)
	for child: Node in chips.get_children():
		if child is UiChip:
			var chip: UiChip = child as UiChip
			chip.add_theme_stylebox_override(&"panel", quiet_chip_style())
			var box: HBoxContainer = chip.get_node_or_null(^"Box") as HBoxContainer
			if box != null:
				box.add_theme_constant_override(&"separation", 4)
			if chip.icon_rect != null:
				chip.icon_rect.custom_minimum_size = Vector2(COMPACT_ICON_SIDE, COMPACT_ICON_SIDE)
			if chip.label != null:
				_set_base_font_size(chip.label, CHIP_FONT_SIZE)
	# Mantém os dois Labels como fontes do Player, sem apresentar os chips antigos.
	# Reaplicação de estilo/escala nunca deve trazer a mochila de volta.
	for chip_name: String in ["BagChip", "MoneyChip"]:
		var source_chip: Control = chips.get_node_or_null(chip_name) as Control
		if source_chip != null:
			source_chip.hide()
	chips.hide()


static func _setup_compact_vitals(health_panel: VBoxContainer, chips: HBoxContainer) -> void:
	var health_label: Label = health_panel.get_node_or_null(^"HealthLabel") as Label
	var health_bar: ProgressBar = health_panel.get_node_or_null(^"HealthBar") as ProgressBar
	var hunger_label: Label = health_panel.get_node_or_null(^"HungerLabel") as Label
	var hunger_bar: ProgressBar = health_panel.get_node_or_null(^"HungerBar") as ProgressBar
	if health_bar == null:
		return
	health_panel.anchor_left = SAFE_MARGIN_RATIO
	health_panel.anchor_right = SAFE_MARGIN_RATIO
	health_panel.anchor_top = 1.0 - SAFE_MARGIN_RATIO
	health_panel.anchor_bottom = 1.0 - SAFE_MARGIN_RATIO
	health_panel.grow_horizontal = Control.GROW_DIRECTION_END
	health_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	health_panel.offset_left = 0.0
	health_panel.offset_right = 156.0
	health_panel.offset_bottom = 0.0
	health_panel.offset_top = -58.0
	health_panel.add_theme_constant_override(&"separation", 2)
	# Mantém os nós originais intactos no mesmo caminho para o Player, A11y e testes,
	# enquanto o medidor curvo compacto assume a apresentação visual no canto inferior esquerdo.
	for item: CanvasItem in [health_label, health_bar, hunger_label, hunger_bar]:
		if item != null:
			item.visible = false
	var arcs: VitalsArcs = health_panel.get_node_or_null(^"VitalsArcs") as VitalsArcs
	if arcs == null:
		arcs = VitalsArcs.new()
		arcs.name = "VitalsArcs"
		health_panel.add_child(arcs)
	arcs.bind(health_bar, hunger_bar, health_label, hunger_label, health_panel, chips)


static func _setup_contextual_threat(threat_panel: VBoxContainer) -> void:
	var title: Label = threat_panel.get_node_or_null(^"ThreatTitle") as Label
	var bar: ProgressBar = threat_panel.get_node_or_null(^"ThreatBar") as ProgressBar
	if bar == null:
		return
	threat_panel.anchor_left = 1.0 - SAFE_MARGIN_RATIO
	threat_panel.anchor_right = 1.0 - SAFE_MARGIN_RATIO
	threat_panel.anchor_top = SAFE_MARGIN_RATIO
	threat_panel.anchor_bottom = SAFE_MARGIN_RATIO
	threat_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	threat_panel.grow_vertical = Control.GROW_DIRECTION_END
	threat_panel.offset_left = -196.0
	threat_panel.offset_top = 0.0
	threat_panel.offset_right = 0.0
	threat_panel.offset_bottom = 34.0
	threat_panel.add_theme_constant_override(&"separation", 2)
	if title != null:
		_set_base_font_size(title, THREAT_FONT_SIZE)
		var icon: TextureRect = title.get_node_or_null(^"Icon") as TextureRect
		if icon != null:
			icon.offset_right = COMPACT_ICON_SIDE
			icon.offset_top = -COMPACT_ICON_SIDE * 0.5
			icon.offset_bottom = COMPACT_ICON_SIDE * 0.5
		var pad: StyleBoxEmpty = StyleBoxEmpty.new()
		pad.content_margin_left = COMPACT_ICON_SIDE + 5.0
		title.add_theme_stylebox_override(&"normal", pad)
	bar.custom_minimum_size = Vector2(188.0, 10.0)
	var sync_node: ThreatContextSync = threat_panel.get_node_or_null(^"ThreatContextSync") as ThreatContextSync
	if sync_node == null:
		sync_node = ThreatContextSync.new()
		sync_node.name = "ThreatContextSync"
		threat_panel.add_child(sync_node)
	sync_node.bind(threat_panel, title, bar)


## Chamado pela SessionUI para deixar o indicador de mapa/dia menor no canto inferior direito,
## aplicando margem segura responsiva de 5% (anchors 0.95) e preservando o botão online de saída.
static func compact_expedition_bar(bar: Control, info_label: Label, leave_btn: Button) -> void:
	if bar != null:
		bar.anchor_left = 1.0 - SAFE_MARGIN_RATIO
		bar.anchor_right = 1.0 - SAFE_MARGIN_RATIO
		bar.anchor_top = 1.0 - SAFE_MARGIN_RATIO
		bar.anchor_bottom = 1.0 - SAFE_MARGIN_RATIO
		bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
		bar.offset_left = -248.0
		bar.offset_top = -36.0
		bar.offset_right = 0.0
		bar.offset_bottom = 0.0
		var margin: MarginContainer = bar.get_node_or_null(^"Margin") as MarginContainer
		if margin != null:
			margin.add_theme_constant_override(&"margin_left", 6)
			margin.add_theme_constant_override(&"margin_top", 2)
			margin.add_theme_constant_override(&"margin_right", 6)
			margin.add_theme_constant_override(&"margin_bottom", 4)
		var vbox: VBoxContainer = bar.get_node_or_null(^"Margin/VBox") as VBoxContainer
		if vbox != null:
			vbox.add_theme_constant_override(&"separation", 3)
	if info_label != null:
		_set_base_font_size(info_label, EXPEDITION_FONT_SIZE)
		var pad: StyleBoxEmpty = StyleBoxEmpty.new()
		pad.content_margin_left = COMPACT_ICON_SIDE + 5.0
		info_label.add_theme_stylebox_override(&"normal", pad)
		var icon: TextureRect = info_label.get_node_or_null(^"Icon") as TextureRect
		if icon != null:
			icon.offset_right = COMPACT_ICON_SIDE
			icon.offset_top = -COMPACT_ICON_SIDE * 0.5
			icon.offset_bottom = COMPACT_ICON_SIDE * 0.5
	if leave_btn != null:
		leave_btn.add_theme_font_size_override(&"font_size", 14)


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


## Chip mais discreto e compacto que o da Base: papel translúcido, sem sombra (#122, #212).
static func quiet_chip_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = UiChip.make_style()
	style.bg_color.a = 0.8
	style.border_color = Color(UiPalette.INK, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 6.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
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


static func _bar_fill_color(bar: ProgressBar, fallback_role: StringName) -> Color:
	if bar != null:
		var fill: StyleBoxFlat = bar.get_theme_stylebox(&"fill") as StyleBoxFlat
		if fill != null:
			return fill.bg_color
	return A11y.color(fallback_role)


## Medidores curvos compactos de vida e fome no canto inferior esquerdo (#212).
## Observa HealthBar e HungerBar (valor, min/max e cor A11y), usa Labels reais para os
## números e alertas (escalando automaticamente com SettingsManager.apply_hud_text_scale)
## e lê o saldo do Label original de MoneyChip, sem alterar economia ou inventário.
class VitalsArcs extends Control:
	const START_ANGLE: float = PI * 0.75
	const END_ANGLE: float = PI * 2.25
	const BASE_ARC_RADIUS: float = 20.0
	const BASE_DIAL_ICON_SIDE: float = 14.0
	const CHIPS_GAP: float = 6.0

	var _health_bar: ProgressBar = null
	var _hunger_bar: ProgressBar = null
	var _hunger_label: Label = null
	var _health_panel: VBoxContainer = null
	var _chips_box: HBoxContainer = null
	var _money_source: Label = null

	var _status_label: Label = null
	var _hp_value_label: Label = null
	var _food_value_label: Label = null
	var _money_value_label: Label = null
	var _heart_tex: Texture2D = null
	var _food_tex: Texture2D = null
	var _coin_tex: Texture2D = null
	var _money_center: Vector2 = Vector2.ZERO
	var _last_money_text: String = "__init__"

	var _hp_val: float = -1.0
	var _hp_min: float = 0.0
	var _hp_max: float = 100.0
	var _hp_color: Color = Color.TRANSPARENT
	var _food_val: float = -1.0
	var _food_min: float = 0.0
	var _food_max: float = 100.0
	var _food_color: Color = Color.TRANSPARENT
	var _last_hunger_text: String = "__init__"
	var _last_dial_font_size: int = -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_heart_tex = UiIcons.get_icon("heart", 32)
		_food_tex = UiIcons.get_icon("food", 32)
		_coin_tex = UiIcons.get_icon("coin", 32)

		_status_label = Label.new()
		_status_label.name = "StatusLabel"
		_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PlayerHudStyle.outline_label(_status_label)
		PlayerHudStyle._set_base_font_size(_status_label, PlayerHudStyle.STATUS_BASE_FONT_SIZE)
		_status_label.visible = false
		add_child(_status_label)

		_hp_value_label = Label.new()
		_hp_value_label.name = "HpValueLabel"
		_hp_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PlayerHudStyle.outline_label(_hp_value_label)
		PlayerHudStyle._set_base_font_size(_hp_value_label, PlayerHudStyle.DIAL_BASE_FONT_SIZE)
		add_child(_hp_value_label)

		_food_value_label = Label.new()
		_food_value_label.name = "FoodValueLabel"
		_food_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_food_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PlayerHudStyle.outline_label(_food_value_label)
		PlayerHudStyle._set_base_font_size(_food_value_label, PlayerHudStyle.DIAL_BASE_FONT_SIZE)
		add_child(_food_value_label)

		_money_value_label = Label.new()
		_money_value_label.name = "MoneyValueLabel"
		_money_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_money_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PlayerHudStyle.outline_label(_money_value_label)
		PlayerHudStyle._set_base_font_size(_money_value_label, PlayerHudStyle.DIAL_BASE_FONT_SIZE)
		add_child(_money_value_label)

	func bind(
		health_bar: ProgressBar,
		hunger_bar: ProgressBar,
		_health_label: Label,
		hunger_label: Label,
		health_panel: VBoxContainer = null,
		chips_box: HBoxContainer = null
	) -> void:
		_disconnect_bars()
		_health_bar = health_bar
		_hunger_bar = hunger_bar
		_hunger_label = hunger_label
		_health_panel = health_panel
		_chips_box = chips_box
		_money_source = chips_box.get_node_or_null(^"MoneyChip/Box/Label") as Label if chips_box != null else null
		for bar: ProgressBar in [_health_bar, _hunger_bar]:
			if bar != null:
				if not bar.value_changed.is_connected(_on_bar_value_changed):
					bar.value_changed.connect(_on_bar_value_changed)
				if not bar.changed.is_connected(_on_bar_changed):
					bar.changed.connect(_on_bar_changed)
		_sync(true)

	func _exit_tree() -> void:
		_disconnect_bars()
		_health_bar = null
		_hunger_bar = null
		_hunger_label = null
		_health_panel = null
		_chips_box = null
		_money_source = null

	func _disconnect_bars() -> void:
		for bar: ProgressBar in [_health_bar, _hunger_bar]:
			if bar != null and is_instance_valid(bar):
				if bar.value_changed.is_connected(_on_bar_value_changed):
					bar.value_changed.disconnect(_on_bar_value_changed)
				if bar.changed.is_connected(_on_bar_changed):
					bar.changed.disconnect(_on_bar_changed)

	func _on_bar_value_changed(_value: float) -> void:
		_sync(false)

	func _on_bar_changed() -> void:
		_sync(false)

	func _process(_delta: float) -> void:
		_sync(false)

	func text_scale_factor() -> float:
		if _hp_value_label == null:
			return 1.0
		var cur_font: int = _hp_value_label.get_theme_font_size(&"font_size")
		if cur_font <= 0:
			return 1.0
		return clampf(float(cur_font) / float(PlayerHudStyle.DIAL_BASE_FONT_SIZE), 0.8, 1.8)

	func hp_value_label() -> Label:
		return _hp_value_label

	func food_value_label() -> Label:
		return _food_value_label

	func _sync(force: bool) -> void:
		if _health_bar == null or not is_instance_valid(_health_bar):
			return
		var hp_val: float = _health_bar.value
		var hp_min: float = _health_bar.min_value
		var hp_max: float = _health_bar.max_value
		var hp_col: Color = PlayerHudStyle._bar_fill_color(_health_bar, &"bar_health")

		var has_food: bool = _hunger_bar != null and is_instance_valid(_hunger_bar)
		var food_val: float = _hunger_bar.value if has_food else 0.0
		var food_min: float = _hunger_bar.min_value if has_food else 0.0
		var food_max: float = _hunger_bar.max_value if has_food else 100.0
		var food_col: Color = PlayerHudStyle._bar_fill_color(_hunger_bar, &"bar_hunger") if has_food else Color.TRANSPARENT
		var hunger_txt: String = _hunger_label.text if (_hunger_label != null and is_instance_valid(_hunger_label)) else ""
		var dial_font: int = _hp_value_label.get_theme_font_size(&"font_size") if _hp_value_label != null else PlayerHudStyle.DIAL_BASE_FONT_SIZE
		var money_text: String = _money_source.text if is_instance_valid(_money_source) else ""

		var changed: bool = force \
			or not is_equal_approx(hp_val, _hp_val) \
			or not is_equal_approx(hp_min, _hp_min) \
			or not is_equal_approx(hp_max, _hp_max) \
			or not hp_col.is_equal_approx(_hp_color) \
			or not is_equal_approx(food_val, _food_val) \
			or not is_equal_approx(food_min, _food_min) \
			or not is_equal_approx(food_max, _food_max) \
			or not food_col.is_equal_approx(_food_color) \
			or hunger_txt != _last_hunger_text \
			or dial_font != _last_dial_font_size \
			or money_text != _last_money_text
		if not changed:
			return
		_hp_val = hp_val
		_hp_min = hp_min
		_hp_max = hp_max
		_hp_color = hp_col
		_food_val = food_val
		_food_min = food_min
		_food_max = food_max
		_food_color = food_col
		_last_hunger_text = hunger_txt
		_last_dial_font_size = dial_font
		_last_money_text = money_text
		_update_labels_and_layout(has_food, hunger_txt)
		queue_redraw()

	func health_ratio() -> float:
		return clampf((_hp_val - _hp_min) / maxf(_hp_max - _hp_min, 0.001), 0.0, 1.0)

	func hunger_ratio() -> float:
		return clampf((_food_val - _food_min) / maxf(_food_max - _food_min, 0.001), 0.0, 1.0)

	func money_ratio() -> float:
		# MoneyFormat usa R$ e agrupamento PT (.) ou EN (,). Lê a mesma fonte do
		# número visível, sem alterar o saldo nem depender do prefixo traduzido.
		var currency_start: int = _last_money_text.find("R$")
		if currency_start < 0:
			return 0.0
		var digits: String = _last_money_text.substr(currency_start + 2).replace(MoneyFormat.NBSP, "").replace(".", "").replace(",", "").strip_edges()
		return clampf(float(digits.to_int()) / PlayerHudStyle.MONEY_ARC_REFERENCE, 0.0, 1.0)

	func status_text() -> String:
		return _status_label.text if _status_label != null else ""

	static func _format_dial_value(cur_val: float, max_val: float, low: bool) -> String:
		var cur_int: int = int(ceilf(cur_val))
		var max_int: int = int(roundf(max_val))
		var text: String = ("!%d" if low else "%d") % cur_int
		if max_int != 100 and max_int > 0:
			text += "/%d" % max_int
		return text

	func _update_labels_and_layout(has_food: bool, hunger_txt: String) -> void:
		var ui_scale: float = text_scale_factor()
		var radius: float = BASE_ARC_RADIUS * ui_scale
		var hp_low: bool = health_ratio() <= PlayerHudStyle.LOW_RATIO
		var food_low: bool = has_food and hunger_ratio() <= PlayerHudStyle.LOW_RATIO

		if _status_label != null:
			var parts: PackedStringArray = PackedStringArray()
			if hp_low:
				parts.append("!♥")
			var paren_idx: int = hunger_txt.find("(")
			var bag_idx: int = hunger_txt.find("🎒")
			var suffix_start: int = -1
			if paren_idx >= 0 and bag_idx >= 0:
				suffix_start = mini(paren_idx, bag_idx)
			elif paren_idx >= 0:
				suffix_start = paren_idx
			elif bag_idx >= 0:
				suffix_start = bag_idx
			if suffix_start >= 0:
				var suffix: String = hunger_txt.substr(suffix_start).strip_edges()
				if not suffix.is_empty():
					parts.append(suffix)
			elif food_low:
				parts.append("!")
			var joined: String = "  ".join(parts)
			_status_label.text = joined
			_status_label.visible = not joined.is_empty()

		var status_h: float = 0.0
		if _status_label != null and _status_label.visible:
			_status_label.position = Vector2.ZERO
			status_h = maxf(_status_label.get_combined_minimum_size().y, 18.0 * ui_scale) + 2.0

		var hp_center: Vector2 = Vector2((radius + 8.0), status_h + radius + 6.0)
		var spacing: float = (radius * 2.0) + 24.0 * ui_scale
		var food_center: Vector2 = Vector2(hp_center.x + spacing, hp_center.y)
		var dial_span: float = (radius + 8.0) * 2.0

		if _hp_value_label != null:
			_hp_value_label.text = _format_dial_value(_hp_val, _hp_max, hp_low)
			var hp_min_sz: Vector2 = _hp_value_label.get_combined_minimum_size()
			var hp_w: float = maxf(dial_span, hp_min_sz.x + 4.0)
			_hp_value_label.size = Vector2(hp_w, hp_min_sz.y)
			_hp_value_label.position = Vector2(hp_center.x - hp_w * 0.5, hp_center.y + radius * 0.35)

		if _food_value_label != null:
			_food_value_label.visible = has_food
			if has_food:
				_food_value_label.text = _format_dial_value(_food_val, _food_max, food_low)
				var food_min_sz: Vector2 = _food_value_label.get_combined_minimum_size()
				var food_w: float = maxf(dial_span, food_min_sz.x + 4.0)
				_food_value_label.size = Vector2(food_w, food_min_sz.y)
				_food_value_label.position = Vector2(food_center.x - food_w * 0.5, food_center.y + radius * 0.35)

		var label_bottom: float = hp_center.y + radius + 16.0 * ui_scale
		if _hp_value_label != null:
			label_bottom = maxf(label_bottom, _hp_value_label.position.y + _hp_value_label.size.y)
		var total_w: float = (food_center.x if has_food else hp_center.x) + radius + 12.0
		_money_value_label.visible = is_instance_valid(_money_source)
		if _money_value_label.visible:
			# A fonte original contém um prefixo traduzido (Dinheiro/Entregue).
			# Reutiliza a moeda e os dígitos já formatados pelo Player, inclusive locale.
			var currency_start: int = _last_money_text.find("R$")
			_money_value_label.text = _last_money_text.substr(currency_start) if currency_start >= 0 else MoneyFormat.money(0)
			var money_min: Vector2 = _money_value_label.get_combined_minimum_size()
			var money_width: float = maxf(dial_span, money_min.x + 4.0)
			var previous_center: Vector2 = food_center if has_food else hp_center
			var previous_label: Label = _food_value_label if has_food else _hp_value_label
			# Saldos longos ampliam o espaço do terceiro mostrador, sem encolher a fonte
			# nem invadir o número da fome. Os centros de vida/fome ficam intactos.
			var money_x: float = maxf(previous_center.x + spacing, previous_label.position.x + previous_label.size.x + 8.0 * ui_scale + money_width * 0.5)
			_money_center = Vector2(money_x, hp_center.y)
			_money_value_label.size = Vector2(money_width, money_min.y)
			_money_value_label.position = Vector2(money_x - money_width * 0.5, hp_center.y + radius * 0.35)
			total_w = maxf(money_x + radius + 12.0, _money_value_label.position.x + money_width)
			label_bottom = maxf(label_bottom, _money_value_label.position.y + money_min.y)
		if _status_label != null and _status_label.visible:
			total_w = maxf(total_w, _status_label.get_combined_minimum_size().x + 4.0)
		custom_minimum_size = Vector2(total_w, label_bottom)

		if _health_panel != null and is_instance_valid(_health_panel):
			_health_panel.offset_left = 0.0
			_health_panel.offset_right = total_w
			_health_panel.offset_bottom = 0.0
			_health_panel.offset_top = -label_bottom
		if _chips_box != null and is_instance_valid(_chips_box):
			var chips_h: float = maxf(_chips_box.get_combined_minimum_size().y, 28.0 * ui_scale)
			_chips_box.offset_left = 0.0
			_chips_box.offset_bottom = -(label_bottom + CHIPS_GAP)
			_chips_box.offset_top = _chips_box.offset_bottom - chips_h

	func _draw() -> void:
		if _health_bar == null or not is_instance_valid(_health_bar):
			return
		var ui_scale: float = text_scale_factor()
		var radius: float = BASE_ARC_RADIUS * ui_scale
		var status_h: float = 0.0
		if _status_label != null and _status_label.visible:
			status_h = maxf(_status_label.get_combined_minimum_size().y, 18.0 * ui_scale) + 2.0
		var hp_center: Vector2 = Vector2(radius + 8.0, status_h + radius + 6.0)
		var spacing: float = (radius * 2.0) + 24.0 * ui_scale
		var food_center: Vector2 = Vector2(hp_center.x + spacing, hp_center.y)
		_draw_dial(hp_center, radius, ui_scale, health_ratio(), _hp_color, _heart_tex)
		if _hunger_bar != null and is_instance_valid(_hunger_bar):
			_draw_dial(food_center, radius, ui_scale, hunger_ratio(), _food_color, _food_tex)
		if is_instance_valid(_money_source):
			_draw_dial(_money_center, radius, ui_scale, money_ratio(), UiPalette.GOLD, _coin_tex, false)

	func _draw_dial(center: Vector2, radius: float, ui_scale: float, ratio: float, fill_color: Color, icon_tex: Texture2D, warn_if_low: bool = true) -> void:
		var low: bool = warn_if_low and ratio <= PlayerHudStyle.LOW_RATIO
		var stroke_out: float = 9.0 * ui_scale
		var stroke_in: float = 5.5 * ui_scale
		draw_circle(center, radius + 4.5 * ui_scale, Color(UiPalette.INK, 0.42))
		draw_arc(center, radius, START_ANGLE, END_ANGLE, 28, UiPalette.INK, stroke_out, true)
		draw_arc(center, radius, START_ANGLE, END_ANGLE, 28, PlayerHudStyle.TRACK_COLOR.lightened(0.1), stroke_in, true)
		# Saldo preenche o arco até a referência visual, sem alerta de saldo baixo.
		if ratio > (0.005 if warn_if_low else 0.0):
			var active_end: float = lerpf(START_ANGLE, END_ANGLE, ratio)
			draw_arc(center, radius, START_ANGLE, active_end, 28, fill_color, stroke_in, true)
		# Indicador não dependente apenas de cor para vida/fome baixa: anel tracejado externo.
		if low:
			for seg: int in 4:
				var a0: float = START_ANGLE + float(seg) * (END_ANGLE - START_ANGLE) * 0.25 + 0.08
				var a1: float = a0 + 0.38
				draw_arc(center, radius + 5.5 * ui_scale, a0, a1, 8, UiPalette.PAPER_LIGHT, 2.0 * ui_scale, true)
		if icon_tex != null:
			var icon_side: float = BASE_DIAL_ICON_SIDE * ui_scale
			var icon_rect: Rect2 = Rect2(center - Vector2(icon_side * 0.5, icon_side * 0.5 + 2.0 * ui_scale), Vector2(icon_side, icon_side))
			draw_texture_rect(icon_tex, icon_rect, false)


## Controle contextual da barra de Ameaça (#212):
## - Preserva ThreatPanel oculto quando não há DisturbanceMeter na cena.
## - Em expedição, mantém ThreatPanel oculto enquanto o ruído é zero e exibe ao subir.
## - Usa sincronização deferida além da imediata porque Player._on_noise_changed atualiza
##   threat_bar.value antes de _update_threat_color() / A11y.tint_bar().
class ThreatContextSync extends Node:
	var _panel: Control = null
	var _bar: ProgressBar = null
	var _had_meter_at_bind: bool = false
	var _last_fill_color: Color = Color.TRANSPARENT

	func bind(panel: Control, _title: Label, bar: ProgressBar) -> void:
		_disconnect_bar()
		_panel = panel
		_bar = bar
		_had_meter_at_bind = DisturbanceMeter.instance != null
		if _bar != null:
			if not _bar.value_changed.is_connected(_on_bar_value_changed):
				_bar.value_changed.connect(_on_bar_value_changed)
			if not _bar.changed.is_connected(_on_bar_changed):
				_bar.changed.connect(_on_bar_changed)
		_apply_visibility()
		_sync_color_deferred.call_deferred()

	func _exit_tree() -> void:
		_disconnect_bar()
		_panel = null
		_bar = null

	func _disconnect_bar() -> void:
		if _bar != null and is_instance_valid(_bar):
			if _bar.value_changed.is_connected(_on_bar_value_changed):
				_bar.value_changed.disconnect(_on_bar_value_changed)
			if _bar.changed.is_connected(_on_bar_changed):
				_bar.changed.disconnect(_on_bar_changed)

	func _on_bar_value_changed(_value: float) -> void:
		_apply_visibility()
		_sync_color_deferred.call_deferred()

	func _on_bar_changed() -> void:
		_apply_visibility()
		_sync_color_deferred.call_deferred()

	func _apply_visibility() -> void:
		if _panel == null or _bar == null or not is_instance_valid(_panel) or not is_instance_valid(_bar):
			return
		var has_meter: bool = _had_meter_at_bind or DisturbanceMeter.instance != null
		var allow_preview: bool = bool(_panel.get_meta(&"allow_contextual_threat_without_meter", false))
		if not has_meter and not allow_preview:
			_panel.visible = false
			return
		_panel.visible = _bar.value > _bar.min_value + 0.001

	func _sync_color_deferred() -> void:
		if _bar == null or not is_instance_valid(_bar):
			return
		_apply_visibility()
		_last_fill_color = PlayerHudStyle._bar_fill_color(_bar, &"threat_0")

	func current_fill_color() -> Color:
		if _bar != null and is_instance_valid(_bar):
			return PlayerHudStyle._bar_fill_color(_bar, &"threat_0")
		return _last_fill_color
